function summary = runSandboxS1CanonicalReplay(options)
%runSandboxS1CanonicalReplay FASE S1: replay canonico reproducible.
%
%   Reproduce un episodio development con el pipeline REAL y auditado:
%       EMG -> WMoos -> markov52 -> Agent7250 congelado -> baselineQuantized
%            -> PWM -> patternCurveCanonical
%
%   No reconstruye markov52 a mano: reutiliza GloveFreePolicyRuntime, que es la
%   ruta que E2A audito y contrasto contra Env. No entrena, no lee guante, no
%   toca src/@Env, no abre sujetos sellados y no modifica configuracion global
%   de forma permanente (el override se restaura al salir).
%
%   Uso:
%       summary = runSandboxS1CanonicalReplay();                       % DENIS cierre
%       summary = runSandboxS1CanonicalReplay(subject="BLANCA", side=2);
%       summary = runSandboxS1CanonicalReplay(subjects=["DENIS"], sides=[1 2]);
%
%   Gate G1 (preregistrado): si existe e2a_results/causal_trajectories.mat, la
%   ruta B de E2A debe reproducirse con igualdad EXACTA en estado, accion raw,
%   accion efectiva, PWM y q. Si no existe, el resultado queda etiquetado
%   REFERENCE_ABSENT y NO se declara G1 aprobado.

arguments
    options.subject (1, 1) string = "DENIS"
    options.subjects (1, :) string = string.empty(1, 0)
    options.repetition (1, 1) double {mustBeInteger, mustBePositive} = 1
    options.side (1, 1) double {mustBeMember(options.side, [1 2])} = 1
    options.sides (1, :) double = []
    options.outputDir (1, 1) string = ""
    options.seed (1, 1) double = 20260905
    options.referencePath (1, 1) string = ""
end

here = string(fileparts(mfilename("fullpath")));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
if options.outputDir == ""
    options.outputDir = fullfile(sandboxRoot, "results", "s1_canonical_replay");
end
if ~isfolder(options.outputDir)
    mkdir(options.outputDir);
end
if options.referencePath == ""
    options.referencePath = string(fullfile(matlabRoot, "analysis", "paired_reference", ...
        "e2a_results", "causal_trajectories.mat"));
end

subjects = options.subjects;
if isempty(subjects)
    subjects = options.subject;
end
sides = options.sides;
if isempty(sides)
    sides = options.side;
end

% --- contexto: override temporal, identico al de E2A, restaurado al salir ---
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
oldRng = rng;
cleanup = onCleanup(@() restoreContext(oldOverride, oldRng)); %#ok<NASGU>
override = struct("run_training", false, "flagSaveTraining", false, ...
    "plotEpisodeOnTest", false, "verbose", false, "usePrerecorded", true, ...
    "simMotors", true, "observationVariant", "markov52", ...
    "simPlantSource", "patternCurveCanonical", "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(override);

[actor, policyManifest] = loadE2AFrozenActor();
beforeParameters = getLearnableParameters(actor);
plantManifest = pairedReferencePlantManifest(plantSource = "patternCurveCanonical", ...
    outputPath = fullfile(options.outputDir, "plant_manifest.json"));

reference = loadReferenceTrajectories(options.referencePath);

episodes = struct("subject", {}, "side", {}, "steps", {}, "trace", {}, ...
    "initialProvenance", {}, "episodeProvenance", {}, "match", {});
rows = {};
index = 0;

for subject = subjects
    for side = sides
        index = index + 1;
        [emg, unusedTeacher, episodeProvenance] = loadE2ADevelopmentEpisode( ...
            subject, options.repetition, side);
        assert(isempty(unusedTeacher), "Sandbox:TeacherLeak", ...
            "El replay S1 no debe recibir datos de guante.");

        [q0, initialProvenance] = sandboxInitialPosition(side);
        trace = rolloutGloveFree(actor, emg, q0, options.seed);

        match = compareWithReference(trace, reference, subject, side);
        episodes(index) = struct("subject", subject, "side", side, ...
            "steps", size(trace.rawAction, 1), "trace", trace, ...
            "initialProvenance", initialProvenance, ...
            "episodeProvenance", episodeProvenance, "match", match);

        rows{end + 1} = traceTable(trace, subject, side); %#ok<AGROW>
        fprintf("  %s lado %d: %d pasos, q0=[%.1f %.1f %.1f %.1f], referencia=%s\n", ...
            subject, side, size(trace.rawAction, 1), q0(1), q0(2), q0(3), q0(4), match.status);
    end
end

assert(isequaln(getLearnableParameters(actor), beforeParameters), ...
    "Sandbox:PolicyModified", "El actor cambio durante el replay S1.");

writetable(vertcat(rows{:}), fullfile(options.outputDir, "s1_replay_traces.csv"));
save(fullfile(options.outputDir, "s1_replay_trajectories.mat"), "episodes", "-v7");

statuses = arrayfun(@(e) string(e.match.status), episodes);
if all(statuses == "EXACT")
    gate = "PASS";
elseif any(statuses == "MISMATCH")
    gate = "FAIL";
else
    gate = "UNVERIFIED";
end

summary = struct( ...
    "stage", "S1_CANONICAL_REPLAY", ...
    "episodes", numel(episodes), ...
    "subjects", strjoin(subjects, ","), ...
    "sides", mat2str(sides), ...
    "seed", options.seed, ...
    "simPlantSource", "patternCurveCanonical", ...
    "policySHA256", policyManifest.checkpointSHA256, ...
    "plantManifest", plantManifest, ...
    "referencePath", options.referencePath, ...
    "referenceAvailable", ~isempty(reference), ...
    "CANONICAL_REPLAY_MATCH", strjoin(unique(statuses), ","), ...
    "maxStateDiff", maxField(episodes, "state"), ...
    "maxRawActionDiff", maxField(episodes, "rawAction"), ...
    "maxEffectiveActionDiff", maxField(episodes, "effectiveAction"), ...
    "maxPwmDiff", maxField(episodes, "pwm"), ...
    "maxQDiff", maxField(episodes, "q"), ...
    "GLOVE_USED_AS_PLANT_STATE", false, ...
    "MATEO_SANDRA_USED", false, ...
    "RL_EXECUTED", false, ...
    "actorParametersUnchanged", true, ...
    "S1_GATE", gate);

writeJson(fullfile(options.outputDir, "s1_summary.json"), summary);
disp(summary);
end

% =======================================================================
function trace = rolloutGloveFree(actor, emg, q0, seed)
rng(seed, "twister");
runtime = GloveFreePolicyRuntime(emg, q0, purpose = "causalEvaluation");
state = runtime.state;
trace = struct("state", state', "q", runtime.q, "rawAction", zeros(0, 4), ...
    "effectiveAction", zeros(0, 4), "pwm", zeros(0, 4));
while ~runtime.exhausted
    raw = getAction(actor, {state});
    if iscell(raw)
        raw = cell2mat(raw);
    end
    raw = double(raw(:));
    [state, ~, record] = runtime.advance(raw);
    trace.state(end + 1, :) = state';
    trace.q(end + 1, :) = record.q;
    trace.rawAction(end + 1, :) = record.rawAction';
    trace.effectiveAction(end + 1, :) = record.effectiveAction';
    trace.pwm(end + 1, :) = record.pwm';
    assert(runtime.c < 100, "Sandbox:Horizon", "Horizonte inesperado; detener replay.");
end
trace.emgExhausted = runtime.exhausted;
trace.steps = size(trace.rawAction, 1);
end

% =======================================================================
function reference = loadReferenceTrajectories(referencePath)
reference = [];
if isfile(referencePath)
    loaded = load(referencePath, "trajectories");
    if isfield(loaded, "trajectories")
        reference = loaded.trajectories;
    end
end
end

% =======================================================================
function match = compareWithReference(trace, reference, subject, side)
match = struct("status", "REFERENCE_ABSENT", "state", nan, "q", nan, ...
    "rawAction", nan, "effectiveAction", nan, "pwm", nan, "referenceSteps", nan);
if isempty(reference)
    return
end
for k = 1:numel(reference)
    entry = reference{k};
    if string(entry.subject) == subject && entry.side == side
        b = entry.B;
        match.referenceSteps = size(b.rawAction, 1);
        exact = true;
        for field = ["state", "q", "rawAction", "effectiveAction", "pwm"]
            x = trace.(field);
            y = b.(field);
            if ~isequal(size(x), size(y))
                match.status = "MISMATCH";
                match.(field) = inf;
                return
            end
            match.(field) = max(abs(x - y), [], "all");
            exact = exact && isequal(x, y);
        end
        if exact
            match.status = "EXACT";
        else
            match.status = "MISMATCH";
        end
        return
    end
end
end

% =======================================================================
function value = maxField(episodes, field)
value = 0;
found = false;
for k = 1:numel(episodes)
    v = episodes(k).match.(field);
    if ~isnan(v)
        value = max(value, v);
        found = true;
    end
end
if ~found
    value = nan;
end
end

% =======================================================================
function tableRows = traceTable(trace, subject, side)
n = size(trace.rawAction, 1);
metadata = table(repmat(subject, n, 1), repmat(side, n, 1), (1:n)', ...
    VariableNames = ["subject", "side", "step"]);
values = [trace.rawAction, trace.effectiveAction, trace.pwm, ...
    trace.q(1:n, :), trace.q(2:n + 1, :)];
names = ["raw_" + (1:4), "effective_" + (1:4), "pwm_" + (1:4), ...
    "qBefore_" + (1:4), "qAfter_" + (1:4)];
tableRows = [metadata, array2table(values, VariableNames = names)];
end

% =======================================================================
function writeJson(path, value)
fid = fopen(path, "w", "n", "UTF-8");
assert(fid >= 0, "Sandbox:WriteFailed", "No se pudo escribir %s", path);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s\n", jsonencode(value, PrettyPrint = true));
end

% =======================================================================
function restoreContext(override, rngState)
setConfigurablesOverride(override);
rng(rngState);
end
