function result = e4GenerateFinalEvaluation(outDir)
% e4GenerateFinalEvaluation ejecuta la inferencia causal de evaluacion para E4_FINAL:
% - Inferencia sobre CategoricalStep000500000.mat para los 200 episodios DEVELOPMENT
% - 200 figuras COMPACT (PNG + FIG)
% - 200 figuras PRO (PNG + FIG)
% - 200 figuras CLASSIC (PNG + FIG)
% - 9 figuras ANNOTATED (PNG, FIG, CSV, MAT)
% - 3 figuras globales de publicacion (MOTOR_TRACKING, OPENING_CLOSING, PWM_USAGE)
% - 200 trazas numericas CSV y MAT
% - Generacion de TEST_COMPORTAMENTAL.html

arguments
    outDir (1, 1) string
end

finalDir = fullfile(outDir, "evaluation", "final_checkpoint");
if ~isfolder(finalDir), mkdir(finalDir); end
metricsDir = fullfile(finalDir, "metrics");
if ~isfolder(metricsDir), mkdir(metricsDir); end
figDir = fullfile(finalDir, "figures");
if ~isfolder(figDir), mkdir(figDir); end
tracesDir = fullfile(finalDir, "traces");
if ~isfolder(tracesDir), mkdir(tracesDir); end

% 1. Configuracion y bloqueo de entrenamiento
sCfg = load(fullfile(outDir, "config.mat"), "cfg", "o");
cfg = sCfg.cfg;
o = sCfg.o;
o.run_training = false;
o.newTraining = false;
setConfigurablesOverride(o);

% 2. Cargar datos de los 10 sujetos
data = e4LoadData(cfg, outDir);
assert(numel(data.evaluation) == 200, "E4:EvalDataCount", "Se esperaban 200 episodios de evaluacion.");

% 3. Cargar actor del checkpoint final 500,000
cpFile = fullfile(outDir, "checkpoints", "CategoricalStep000500000.mat");
assert(isfile(cpFile), "E4:MissingCheckpoint", "Falta CategoricalStep000500000.mat.");
aData = load(cpFile, "saved_actor");
actor = aData.saved_actor;

% 4. Ejecutar o recuperar evaluacion de los 200 episodios
trajPath = fullfile(metricsDir, "trajectories.mat");
if isfile(trajPath)
    fprintf("Recuperando trazas existentes de %s...\n", trajPath);
    sTraj = load(trajPath, "traces", "runtimeTraces");
    traces = sTraj.traces;
    runtimeTraces = sTraj.runtimeTraces;
else
    fprintf("Evaluando deterministamente 200 episodios con FINAL_AGENT Step500000...\n");
    traces = cell(200, 1);
    runtimeTraces = cell(200, 1);
    metricRows = cell(200, 1);
    motorRows = {};
    stepRows = {};

    levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];

    for e = 1:200
        ep = data.evaluation{e};
        [t, r] = e3axRollout(actor, ep);
        t.metadata.controller = "E4_FINAL";
        r.metadata.controller = "E4_FINAL";

        nSteps = size(t.pwm, 1);
        [p, h] = actor.distribution(r.state(1:nSteps, :)');

        selectedProb = zeros(nSteps, 4);
        headEnt = zeros(nSteps, 4);
        for m = 1:4
            headEnt(:, m) = h(m, :)';
            for k = 1:nSteps
                cIdx = find(levels == t.pwm(k, m), 1);
                if isempty(cIdx), cIdx = 1; end
                selectedProb(k, m) = p(cIdx, m, k);
            end
        end
        t.selectedProbability = selectedProb;
        t.headEntropy = headEnt;

        traces{e} = t;
        runtimeTraces{e} = r;

        [mot, met] = e2bControlMetrics(t);
        md = t.metadata;
        key = struct("controller", "E4_FINAL", "subject", md.subject, ...
            "repetition", md.repetition, "side", md.side, "steps", size(t.reference, 1));
        metricRows{e} = mergeStructs(key, met);
        for m = 1:4
            motorRows{end+1} = mergeStructs(key, mot(m)); %#ok<AGROW>
        end
        stepRows{e} = e2fTraceTable(t);

        if mod(e, 50) == 0 || e == 200
            fprintf("Progreso rollout: %d/200 episodios evaluados.\n", e);
        end
    end

    E = struct2table([metricRows{:}]);
    M = struct2table([motorRows{:}]);
    [macro, subjects, directions, motors, groups] = e2fAggregate(E, M);
    splits = repelem("TRAIN", 200, 1);
    E.split = splits;
    M.split = repelem(splits, 4);
    macro.m3Reversals = sum(cellfun(@(t) nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0), traces));
    macro.persistentTwoCycle = sum(E.persistentTwoCycle);

    names = ["episode_metrics", "episode_motor_metrics", "summary", "subject_summary", ...
             "direction_summary", "motor_summary", "subject_side_summary", "step_traces"];
    values = {E, M, macro, subjects, directions, motors, groups, vertcat(stepRows{:})};
    for i = 1:numel(names)
        writetable(values{i}, fullfile(metricsDir, names(i) + ".csv"));
    end
    save(trajPath, "traces", "runtimeTraces", "-v7.3");

    % Diagnosticos categoricos
    e4EvaluateCategorical(outDir, traces, runtimeTraces, actor);
end

% Cargar tablas de metricas
episodeTable = readtable(fullfile(metricsDir, "episode_metrics.csv"), TextType="string", Delimiter=",");
motorTable = readtable(fullfile(metricsDir, "episode_motor_metrics.csv"), TextType="string", Delimiter=",");
catTable = readtable(fullfile(metricsDir, "categorical_episode_motor.csv"), TextType="string", Delimiter=",");

% 5. Generar figuras COMPACT, PRO, CLASSIC y trazas
fprintf("Generando figuras COMPACT, PRO, CLASSIC y trazas numericas...\n");
compactFolder = fullfile(figDir, "compact", "TRAIN");
proFolder = fullfile(figDir, "pro", "TRAIN");
classicFolder = fullfile(figDir, "classic", "TRAIN");
tracesSubFolder = fullfile(tracesDir, "TRAIN");

invRows = cell(200, 1);
directions = ["closing", "opening"];

for e = 1:200
    t = traces{e};
    r = runtimeTraces{e};
    md = t.metadata;
    spl = "TRAIN";

    if isfield(md, "repetition"), row = double(md.repetition); else, row = double(md.row); end
    safeSub = regexprep(string(md.subject), "[^A-Za-z0-9_-]", "_");
    dirStr = directions(md.side);
    stem = safeSub + compose("_row%04d_", row) + dirStr;

    % Compact
    compPng = fullfile(compactFolder, stem + "_compact.png");
    compFig = fullfile(compactFolder, stem + "_compact.fig");
    if ~isfile(compPng) || ~isfile(compFig)
        compFiles = e3fPlotCompact(t, compactFolder);
    else
        compFiles = struct("png", string(compPng), "fig", string(compFig));
    end

    % Pro
    proPng = fullfile(proFolder, stem + "_pro.png");
    proFig = fullfile(proFolder, stem + "_pro.fig");
    if ~isfile(proPng) || ~isfile(proFig)
        proFiles = e3fPlotPro(t, proFolder, spl);
    else
        proFiles = struct("png", string(proPng), "fig", string(proFig));
    end

    % Classic
    classicPng = fullfile(classicFolder, stem + "_classic.png");
    classicFig = fullfile(classicFolder, stem + "_classic.fig");
    if ~isfile(classicPng) || ~isfile(classicFig)
        classicFiles = e3fPlotClassic(t, classicFolder);
    else
        classicFiles = struct("png", string(classicPng), "fig", string(classicFig));
    end

    % Traces CSV y MAT
    trCsv = fullfile(tracesDir, spl, stem + "_trace.csv");
    trMat = fullfile(tracesDir, spl, stem + "_trace.mat");
    if ~isfile(trCsv) || ~isfile(trMat)
        trFiles = e3fExportEpisodeTraces(t, r, tracesDir, spl);
    else
        trFiles = struct("csv", string(trCsv), "mat", string(trMat));
    end

    invRows{e} = struct("subject", string(md.subject), "row", double(row), ...
        "side", double(md.side), "direction", dirStr, "split", spl, ...
        "trackingMSE", episodeTable.trackingMSE(e), "reward", mean(t.reward), ...
        "compactPng", replace(string(compFiles.png), outDir + filesep, ""), ...
        "compactFig", replace(string(compFiles.fig), outDir + filesep, ""), ...
        "proPng", replace(string(proFiles.png), outDir + filesep, ""), ...
        "proFig", replace(string(proFiles.fig), outDir + filesep, ""), ...
        "classicPng", replace(string(classicFiles.png), outDir + filesep, ""), ...
        "classicFig", replace(string(classicFiles.fig), outDir + filesep, ""), ...
        "traceCsv", replace(string(trFiles.csv), outDir + filesep, ""), ...
        "traceMat", replace(string(trFiles.mat), outDir + filesep, ""));

    if mod(e, 25) == 0 || e == 200
        fprintf("Progreso figuras: %d/200 episodios procesados.\n", e);
    end
end
inventory = struct2table([invRows{:}]);
writetable(inventory, fullfile(finalDir, "episode_inventory.csv"));

% 6. Seleccion y generacion ANNOTATED
fprintf("Seleccionando y generando subconjunto ANNOTATED...\n");
annotFolder = fullfile(figDir, "annotated");
annotatedRecords = e4SelectAndPlotAnnotated(traces, episodeTable, annotFolder);

% 7. Generar las 3 figuras globales
fprintf("Generando figuras globales de publicacion...\n");
globalFigs = e4PlotGlobalSummaries(outDir, episodeTable, motorTable, catTable);

% 8. Resumen cientifico congelado
sciSum = struct( ...
    "status", "COMPLETE", ...
    "stage", "E4_FINAL_DEVELOPMENT", ...
    "algorithm", "FACTORIZED_MULTICATEGORICAL_PPO", ...
    "finalAgentStep", 500000, ...
    "finalAgentSHA256", fileread(fullfile(outDir, "FINAL_AGENT_SHA256.txt")), ...
    "developmentEpisodes", 200, ...
    "developmentMacroMSE", mean(episodeTable.trackingMSE), ...
    "developmentMedianMSE", median(episodeTable.trackingMSE), ...
    "developmentMinMSE", min(episodeTable.trackingMSE), ...
    "developmentMaxMSE", max(episodeTable.trackingMSE), ...
    "m3ReversalsTotal", sum(cellfun(@(t) nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0), traces)), ...
    "cyclesTotal", sum(catTable.cycles), ...
    "periodicTotal", sum(catTable.periodic), ...
    "sealedSubjectsProtected", true);

e2cWriteJSON(fullfile(outDir, "E4_SCIENTIFIC_SUMMARY.json"), sciSum);

% 9. Actualizar TEST_COMPORTAMENTAL.html
fprintf("Actualizando galeria TEST_COMPORTAMENTAL.html...\n");
htmlPath = e4BuildHtmlGallery(outDir, sciSum, inventory, annotatedRecords);

result = struct("status", "SUCCESS", "episodes", 200, "html", htmlPath, ...
    "macroMSE", sciSum.developmentMacroMSE, "globalFigs", globalFigs);
end

function e4EvaluateCategorical(outDir, traces, runtimeTraces, actor)
finalDir = fullfile(outDir, "evaluation", "final_checkpoint");
metricsDir = fullfile(finalDir, "metrics");
rows = {};
levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];

for e = 1:numel(traces)
    t = traces{e};
    r = runtimeTraces{e};
    n = size(t.pwm, 1);
    [p, h] = actor.distribution(r.state(1:n, :)');
    [~, cats] = max(p, [], 1);
    cats = reshape(cats, 4, []);
    mask = e2dCycleScan(t.q, t.pwm);
    md = t.metadata;
    for m = 1:4
        row = struct("controller", "E4_FINAL", "subject", string(md.subject), ...
            "row", md.repetition, "side", md.side, "split", "TRAIN", ...
            "motor", m, "steps", n, "headEntropy", mean(h(m, :)), ...
            "fraction255", mean(abs(t.pwm(:, m)) == 255), ...
            "cycles", double(mask(end, m)), "cycleWindows", sum(mask(:, m)), ...
            "periodic", double(e2fPeriodicTrace(t.q, t.pwm, m, false) > 0), ...
            "m3Reversals", double(m == 3) * nnz(t.pwm(:, m) > 0 & diff(t.q(:, m)) < 0));
        for c = 1:15, row.("category" + c) = nnz(cats(m, :) == c); end
        rows{end+1} = row; %#ok<AGROW>
    end
end
D = struct2table([rows{:}]);
writetable(D, fullfile(metricsDir, "categorical_episode_motor.csv"));

G = {}; F = {};
for dim = ["motor", "subject_motor", "direction_motor"]
    values = "ALL";
    if dim == "subject_motor", values = unique(D.subject)';
    elseif dim == "direction_motor", values = string(1:2); end
    for val = values
        for m = 1:4
            A = D(D.motor == m, :);
            if dim == "subject_motor", A = A(A.subject == val, :);
            elseif dim == "direction_motor", A = A(A.side == str2double(val), :); end
            if isempty(A), continue; end
            cnt = zeros(1, 15);
            for c = 1:15, cnt(c) = sum(A.("category" + c)); end
            tot = sum(cnt);
            row = struct("split", "TRAIN", "dimension", dim, "value", val, "motor", m, "commands", tot, ...
                "headEntropy", sum(A.headEntropy .* A.steps) / tot, "fraction255", (cnt(14) + cnt(15)) / tot, ...
                "maxCategoryFraction", max(cnt) / tot, "cycles", sum(A.cycles), "cycleWindows", sum(A.cycleWindows), ...
                "periodic", sum(A.periodic), "m3Reversals", sum(A.m3Reversals));
            G{end+1} = row; %#ok<AGROW>
            for c = 1:15
                cr = row; cr.category = c; cr.pwm = levels(c);
                cr.count = cnt(c); cr.fraction = cnt(c) / tot; F{end+1} = cr; %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table([G{:}]), fullfile(metricsDir, "categorical_grouped.csv"));
writetable(struct2table([F{:}]), fullfile(metricsDir, "category_distribution.csv"));
end

function annotatedRecords = e4SelectAndPlotAnnotated(traces, episodeTable, annotFolder)
% Seleccion automatica determinista de episodios representativos sobre DEVELOPMENT:
% - peor DEVELOPMENT por MSE
% - mejor DEVELOPMENT por MSE
% - mediana DEVELOPMENT por MSE
% - peor APERTURA DEVELOPMENT
% - mejor APERTURA DEVELOPMENT
% - peor CIERRE DEVELOPMENT
% - mejor CIERRE DEVELOPMENT
% - representativo JOE
% - representativo JONATHAN
% - representativo KHAROL

[~, sortAll] = sort(episodeTable.trackingMSE);
worstIdx = sortAll(end);
bestIdx = sortAll(1);
medIdx = sortAll(round(end/2));

openIdxs = find(episodeTable.side == 2);
[~, sortOpen] = sort(episodeTable.trackingMSE(openIdxs));
worstOpenIdx = openIdxs(sortOpen(end));
bestOpenIdx = openIdxs(sortOpen(1));

closeIdxs = find(episodeTable.side == 1);
[~, sortClose] = sort(episodeTable.trackingMSE(closeIdxs));
worstCloseIdx = closeIdxs(sortClose(end));
bestCloseIdx = closeIdxs(sortClose(1));

joeIdxs = find(episodeTable.subject == "JOE");
[~, sortJoe] = sort(episodeTable.trackingMSE(joeIdxs));
joeRepIdx = joeIdxs(sortJoe(round(end/2)));

jonIdxs = find(episodeTable.subject == "JONATHAN");
[~, sortJon] = sort(episodeTable.trackingMSE(jonIdxs));
jonRepIdx = jonIdxs(sortJon(round(end/2)));

candidates = { ...
    struct("idx", worstIdx, "reason", "Peor DEVELOPMENT MSE"), ...
    struct("idx", bestIdx, "reason", "Mejor DEVELOPMENT MSE"), ...
    struct("idx", medIdx, "reason", "Mediana DEVELOPMENT MSE"), ...
    struct("idx", worstOpenIdx, "reason", "Peor APERTURA DEVELOPMENT"), ...
    struct("idx", bestOpenIdx, "reason", "Mejor APERTURA DEVELOPMENT"), ...
    struct("idx", worstCloseIdx, "reason", "Peor CIERRE DEVELOPMENT"), ...
    struct("idx", bestCloseIdx, "reason", "Mejor CIERRE DEVELOPMENT"), ...
    struct("idx", joeRepIdx, "reason", "Representativo JOE"), ...
    struct("idx", jonRepIdx, "reason", "Representativo JONATHAN") ...
};

selectedIdxs = [];
annotatedRecords = {};
directions = ["closing", "opening"];

for c = 1:numel(candidates)
    cand = candidates{c};
    if ismember(cand.idx, selectedIdxs), continue; end
    selectedIdxs(end+1) = cand.idx; %#ok<AGROW>

    t = traces{cand.idx};
    files = e3fPlotAnnotated(t, annotFolder, cand.reason);

    md = t.metadata;
    annotatedRecords{end+1} = struct("reason", cand.reason, ...
        "subject", string(md.subject), "row", double(md.repetition), ...
        "direction", directions(md.side), "mse", episodeTable.trackingMSE(cand.idx), ...
        "png", replace(string(files.png), fileparts(fileparts(annotFolder)) + filesep, ""), ...
        "fig", replace(string(files.fig), fileparts(fileparts(annotFolder)) + filesep, ""), ...
        "csv", replace(string(files.csv), fileparts(fileparts(annotFolder)) + filesep, ""), ...
        "mat", replace(string(files.mat), fileparts(fileparts(annotFolder)) + filesep, ""));
end
end

function c = mergeStructs(a, b)
c = a;
for f = string(fieldnames(b))'
    c.(f) = b.(f);
end
end
