function data = e4LoadData(cfg, out)
% e4LoadData carga los 10 sujetos DEVELOPMENT para TRAIN y garantiza que
% MATEO y SANDRA permanecen estrictamente sellados y no son leidos.

arguments
    cfg (1, 1) struct
    out (1, 1) string = ""
end

allowed = cfg.trainSubjects;
assert(numel(unique(allowed)) == 10, "E4:LoadData:Count", "Se esperaban exactamente 10 sujetos en TRAIN.");
assert(~any(ismember(allowed, ["MATEO", "SANDRA"])), "E4:LoadData:SealedViolation", "MATEO o SANDRA no deben abrirse.");
assert(isempty(cfg.validationSubjects), "E4:LoadData:ValidationNotEmpty", "E4 no debe tener sujetos de validacion.");

folder = fullfile(cfg.root, "data", "datasets", "Denis Dataset");
emgs = {};
gloves = {};
rows = {};
evalEmgs = struct();

for sIdx = 1:numel(allowed)
    subject = allowed(sIdx);
    file = fullfile(folder, subject + ".mat");
    assert(isfile(file), "E4:LoadData:MissingSubjectFile", "Falta archivo para sujeto %s.", subject);
    d = load(file, "emgs", "gloves");
    assert(isequal(size(d.emgs), size(d.gloves)) && size(d.emgs, 2) == 2, ...
        "E4:LoadData:ShapeMismatch", "Formato invalido en %s.", subject);

    for r = 1:size(d.emgs, 1)
        for side = 1:2
            e = d.emgs{r, side};
            g = d.gloves{r, side};
            assert(size(e, 2) == 8 && size(e, 1) >= 40 && numel(g) >= 2 && all(isfinite(e), "all"), ...
                "E4:LoadData:InvalidSamples", "Datos no validos en %s fila %d lado %d.", subject, r, side);
            teacherSteps = ceil((numel(g) - 1) / 2) - 1;
            emgSteps = ceil((size(e, 1) - 1) / 40) - 1;
            assert(min(teacherSteps, emgSteps) <= cfg.maxSteps, "E4:Horizon", "Teacher excede 50 pasos.");
            rows{end+1} = struct("subject", subject, "row", r, "side", side, ...
                "datasetIndex", size(emgs, 1) + r, "emgSamples", size(e, 1), "gloveSamples", numel(g)); %#ok<AGROW>
        end
    end
    emgs = [emgs; d.emgs]; %#ok<AGROW>
    gloves = [gloves; d.gloves]; %#ok<AGROW>
    evalEmgs.(subject) = d.emgs;
end

inventory = struct2table([rows{:}]);
if strlength(out) > 0
    if ~isfolder(out), mkdir(out); end
    writetable(inventory, fullfile(out, "training_inventory.csv"));
end

% Para modo smoke: seleccionar 3 filas (6 episodios) de diferentes sujetos
if cfg.mode == "smoke"
    % Tomar filas representativas de 3 sujetos distintos
    subjList = unique(inventory.subject, "stable");
    chosenRows = [];
    accum = 0;
    for sIdx = 1:3
        sName = subjList(sIdx);
        sRows = find(inventory.subject == sName);
        % Elegir una fila con muestras suficientes
        firstEligible = sRows(1);
        rIdx = inventory.row(firstEligible);
        chosenRows(end+1) = accum + rIdx; %#ok<AGROW>
        accum = accum + max(inventory.row(sRows));
    end
    emgs = emgs(chosenRows, :);
    gloves = gloves(chosenRows, :);
    if strlength(out) > 0
        writematrix(chosenRows, fullfile(out, "smoke_training_rows.csv"));
    end
end

% Cargar trazas base de los 200 episodios DEVELOPMENT (para evaluacion descriptiva final)
d = load(fullfile(cfg.root, "analysis", "paired_reference", "e2f_results", "trajectories.mat"), "trajectories");
base = d.trajectories(:, 2);
mask = true(200, 1);

if cfg.mode == "smoke"
    mask = false(200, 1);
    for sIdx = 1:3
        s = cfg.trainSubjects(sIdx);
        for side = 1:2
            idx = find(cellfun(@(t) t.metadata.subject == s && t.metadata.side == side, base), 1);
            if ~isempty(idx), mask(idx) = true; end
        end
    end
end

base = base(mask);
comparators = d.trajectories(mask, [1 3 2 7]);
evalData = cell(numel(base), 1);
selection = {};

for j = 1:numel(base)
    t = base{j};
    md = t.metadata;
    split = "TRAIN"; % En E4 todos los 10 sujetos son TRAIN
    evalData{j} = struct("base", t, "emg", evalEmgs.(md.subject){md.repetition, md.side}, "split", split);
    selection{j} = struct("subject", md.subject, "row", md.repetition, "side", md.side, ...
        "split", split, "teacherSteps", size(t.reference, 1));
end

if strlength(out) > 0
    writetable(struct2table([selection{:}]), fullfile(out, "evaluation_selection.csv"));
end

data = struct("emgs", {emgs}, "gloves", {gloves}, "evaluation", {evalData}, ...
    "comparators", {comparators}, "trainingInventory", inventory);
end
