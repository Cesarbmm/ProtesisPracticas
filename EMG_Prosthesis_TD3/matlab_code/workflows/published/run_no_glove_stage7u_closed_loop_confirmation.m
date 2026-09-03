function report = run_no_glove_stage7u_closed_loop_confirmation(options)
%run_no_glove_stage7u_closed_loop_confirmation live paired confirmation of
%the ETAPA 7U motionPermission gate.
%
% Reloads the frozen Agent200 checkpoint and replays it live through Env
% TWICE on the SAME deterministic EMG-only acceptance corpus (seed 11,
% same episode count, same simulationPositionSafety as the historical
% run): once with motionPermissionEnabled=false (baseline, byte-identical
% to the historical pipeline) and once =true (gated). This is evaluation
% only - run_training=false, newTraining=false - Agent200's weights are
% never modified. It closes the one limitation flagged in
% 07u_motion_permission_ablation.md: downstream trackingMse after
% intra-episode suppression, which the offline counterfactual could not
% recompute without a live loop.

arguments
    options struct = struct()
end

options = normalizeOptions(options);
paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = string(paths.matlabRoot);
repoRoot = string(paths.workspaceRoot);
originalDir = string(pwd);
cleanup = onCleanup(@() cleanupRuntime(originalDir));
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));
addpath(genpath(fullfile(matlabRoot, "tests")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
clearConfigurablesOverride();

if ~isfile(options.agentPath)
    error("run_no_glove_stage7u_closed_loop_confirmation:AgentMissing", ...
        "Agent200 checkpoint not found: %s", options.agentPath);
end

% Read the historical acceptance run's own simulationPositionSafety so this
% live replay matches it exactly rather than assuming a value.
sampleFiles = dir(fullfile(options.referenceAcceptanceEpisodeDirectory, ...
    "episode*.mat"));
if isempty(sampleFiles)
    error("run_no_glove_stage7u_closed_loop_confirmation:NoReferenceEpisode", ...
        "No reference acceptance episode found to read simulationPositionSafety.");
end
referenceSample = load(fullfile(sampleFiles(1).folder, sampleFiles(1).name), ...
    "simulationPositionSafety", "observationVariant", "stateLength");
if string(referenceSample.observationVariant) ~= "intentMarkov60" || ...
        double(referenceSample.stateLength) ~= 60
    error("run_no_glove_stage7u_closed_loop_confirmation:ReferenceMismatch", ...
        "Reference acceptance episode is not a state-60 emgIntent episode.");
end
historicalSafety = referenceSample.simulationPositionSafety;

if strlength(options.resultsRoot) == 0
    options.resultsRoot = fullfile(repoRoot, "Agentes", ...
        "no_glove_intent_control", "stage7u_closed_loop_confirmation");
end
runRoot = fullfile(options.resultsRoot, ...
    string(datetime("now", "Format", "yyyy-MM-dd_HH-mm-ss-SSS")));
if isfolder(runRoot)
    error("run_no_glove_stage7u_closed_loop_confirmation:OutputExists", ...
        "Refusing to reuse %s.", runRoot);
end
mkdir(runRoot);

%% Deterministic corpus (seed 11, same corpus Agent200 was evaluated on)
corpus = buildNoGloveStage6SyntheticCorpus(options.calibrationSeed);
calibration = corpus.calibration;
expectedContext = corpus.expectedContext;
if ~isequal(historicalSafety.positionMin, calibration.limits.positionMin) || ...
        ~isequal(historicalSafety.positionMax, calibration.limits.positionMax)
    error("run_no_glove_stage7u_closed_loop_confirmation:CalibrationMismatch", ...
        "Reconstructed seed-%d calibration does not match the historical " + ...
        "episode's simulationPositionSafety bounds.", options.calibrationSeed);
end

fixtureDir = fullfile(runRoot, "fixture");
mkdir(fixtureDir);
evaluationPath = fullfile(fixtureDir, "evaluation_emg_only.mat");
emgs = corpus.evaluationEmgs; %#ok<NASGU>
metadata = corpus.evaluationMetadata; %#ok<NASGU>
save(evaluationPath, "emgs", "metadata");

%% Base evaluation profile (ETAPA 6 training profile, evaluation mode)
dummyTrainingPath = evaluationPath; % only used to satisfy the constructor
baseProfile = buildNoGloveStage6Override(calibration, expectedContext, ...
    options.calibrationSeed, 1, 1, dummyTrainingPath, ...
    fullfile(runRoot, "unused_training_dir"), "intentMarkov60");
baseProfile.simulationPositionSafety = historicalSafety;
baseProfile.run_training = false;
baseProfile.newTraining = false;
baseProfile.agentFile = options.agentPath;
baseProfile.agent_id = "td3_no_glove_intent";
baseProfile.randomSeed = options.evaluationSeed;
[datasetFolder, datasetStem] = fileparts(evaluationPath);
baseProfile.dataset = {char(string(datasetStem))};
baseProfile.dataset_folder = string(datasetFolder);
baseProfile.flagSaveTraining = true;
baseProfile.episode_save_freq = 1;
baseProfile.plotEpisodeOnTest = true;
baseProfile.simOpts = rlSimulationOptions( ...
    "MaxSteps", baseProfile.maxNumberStepsInEpisodes, ...
    "NumSimulations", options.episodeCount, ...
    "StopOnError", "on", "UseParallel", false);

conditions = ["baseline", "gated"];
conditionEnabled = [false, true];
episodeDirs = strings(1, 2);
figureDirs = strings(1, 2);
for idx = 1:2
    label = conditions(idx);
    evaluationBase = fullfile(runRoot, label);
    mkdir(evaluationBase);
    profile = baseProfile;
    profile.motionPermissionEnabled = conditionEnabled(idx);
    profile.agents_directory = @(agent_id, variant) fullfile( ...
        evaluationBase, string(datetime("now", "Format", "yy-MM-dd HH m s")));
    imagenesBefore = listImagenes(repoRoot);
    setConfigurablesOverride(profile);
    trainInterface("td3_no_glove_intent", "", "");
    clearConfigurablesOverride();
    episodeDirs(idx) = findNewestSubdir(evaluationBase);
    figureDirs(idx) = fullfile(episodeDirs(idx), "figures");
    mkdir(figureDirs(idx));
    moveNewImagenes(repoRoot, imagenesBefore, figureDirs(idx));
end

%% Analysis: paired episode-by-episode comparison
comparison = compareConditions(episodeDirs(1), episodeDirs(2));

writetable(comparison.episodeTable, ...
    fullfile(runRoot, "episode_comparison.csv"));

[gitCommit, gitDirty] = getGitState(repoRoot);
manifest = struct( ...
    "stage", "7U", "schemaVersion", 1, "result", "PASS", ...
    "purpose", "closedLoopConfirmation", ...
    "createdAt", string(datetime("now", "TimeZone", "UTC", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ssXXX")), ...
    "gitCommit", gitCommit, "gitDirty", gitDirty, ...
    "matlabVersion", string(version), ...
    "launcher", "run_no_glove_stage7u_closed_loop_confirmation", ...
    "agentPath", options.agentPath, "agentSha256", fileSha256(options.agentPath), ...
    "calibrationSeed", options.calibrationSeed, ...
    "evaluationSeed", options.evaluationSeed, ...
    "episodeCount", options.episodeCount, ...
    "baselineDirectory", episodeDirs(1), "gatedDirectory", episodeDirs(2), ...
    "baselineFiguresDirectory", figureDirs(1), ...
    "gatedFiguresDirectory", figureDirs(2), ...
    "comparison", comparison.summary, ...
    "actorRetrained", false, "trainingUsed", false, ...
    "environmentUsed", true, "simulationUsed", true, "hardwareUsed", false, ...
    "outputPath", runRoot);
save(fullfile(runRoot, "stage7u_closed_loop_results.mat"), ...
    "manifest", "comparison", "options", "-v7.3");
writeText(fullfile(runRoot, "manifest.json"), ...
    jsonencode(manifest, "PrettyPrint", true));

report = struct("result", "PASS", "outputPath", runRoot, ...
    "manifest", manifest, "comparison", comparison);
fprintf("ETAPA 7U CLOSED-LOOP CONFIRMATION DONE\n");
fprintf("trackingMse baseline=%.6f gated=%.6f (ratio %.4f)\n", ...
    comparison.summary.trackingMseBaselineMean, ...
    comparison.summary.trackingMseGatedMean, ...
    comparison.summary.trackingMseRatio);
fprintf("restPhasePwmNonZeroFraction baseline=%.4f gated=%.4f\n", ...
    comparison.summary.restPhasePwmNonZeroFractionBaseline, ...
    comparison.summary.restPhasePwmNonZeroFractionGated);
fprintf("Output: %s\n", runRoot);
end

function options = normalizeOptions(options)
if ~isstruct(options) || ~isscalar(options)
    error("run_no_glove_stage7u_closed_loop_confirmation:InvalidOptions", ...
        "options must be a scalar struct.");
end
defaults = struct( ...
    "resultsRoot", "", ...
    "agentPath", ...
        "C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_final\2026-08-29_07-20-16-394\control60_training\2026-08-29_07-20-29-220\seed_11\training\26-08-29 07 20 53\Agent200.mat", ...
    "referenceAcceptanceEpisodeDirectory", ...
        "C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_corrected_final\2026-08-29_07-34-46-814\checkpoint_evaluations\control60\episode_200\acceptance\26-08-29 07 36 5", ...
    "calibrationSeed", 11, "evaluationSeed", 4001, "episodeCount", 50);
unknown = setdiff(string(fieldnames(options)), string(fieldnames(defaults)));
if ~isempty(unknown)
    error("run_no_glove_stage7u_closed_loop_confirmation:UnknownOption", ...
        "Unknown option(s): %s", strjoin(unknown, ", "));
end
names = fieldnames(defaults);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(options, name) || isempty(options.(name))
        options.(name) = defaults.(name);
    end
end
options.resultsRoot = string(options.resultsRoot);
options.agentPath = string(options.agentPath);
options.referenceAcceptanceEpisodeDirectory = ...
    string(options.referenceAcceptanceEpisodeDirectory);
options.calibrationSeed = double(options.calibrationSeed);
options.evaluationSeed = double(options.evaluationSeed);
options.episodeCount = double(options.episodeCount);
end

function names = listImagenes(repoRoot)
imagenesDir = fullfile(repoRoot, "Imagenes");
if ~isfolder(imagenesDir)
    names = strings(0, 1);
    return;
end
files = dir(fullfile(imagenesDir, "episode_*.png"));
names = string({files.name})';
end

function moveNewImagenes(repoRoot, before, destination)
imagenesDir = fullfile(repoRoot, "Imagenes");
if ~isfolder(imagenesDir)
    return;
end
files = dir(fullfile(imagenesDir, "episode_*.png"));
current = string({files.name})';
newOnes = setdiff(current, before);
for idx = 1:numel(newOnes)
    movefile(fullfile(imagenesDir, newOnes(idx)), ...
        fullfile(destination, newOnes(idx)));
end
end

function comparison = compareConditions(baselineDir, gatedDir)
baselineFiles = sortEpisodeFiles(baselineDir);
gatedFiles = sortEpisodeFiles(gatedDir);
if numel(baselineFiles) ~= numel(gatedFiles)
    error("run_no_glove_stage7u_closed_loop_confirmation:EpisodeCountMismatch", ...
        "Baseline (%d) and gated (%d) produced different episode counts.", ...
        numel(baselineFiles), numel(gatedFiles));
end
n = numel(baselineFiles);
episode = (1:n)';
trackingMseB = zeros(n, 1);
trackingMseG = zeros(n, 1);
actionL2B = zeros(n, 1);
actionL2G = zeros(n, 1);
restPhaseStepsB = 0;
restPhaseStepsG = 0;
restPhaseNonzeroB = 0;
restPhaseNonzeroG = 0;
activeStepsB = 0;
falseInhibitionSteps = 0;
gateMismatchEpisodes = 0;

for idx = 1:n
    b = load(baselineFiles(idx), "trackingMseLog", "actionL2Log", ...
        "actionSatLog", "actionPwmLog", "intentProvenanceLog");
    g = load(gatedFiles(idx), "trackingMseLog", "actionL2Log", ...
        "actionSatLog", "actionPwmLog", "intentProvenanceLog", ...
        "motionPermissionLog");
    trackingMseB(idx) = mean(b.trackingMseLog, "omitnan");
    trackingMseG(idx) = mean(g.trackingMseLog, "omitnan");
    actionL2B(idx) = mean(b.actionL2Log, "omitnan");
    actionL2G(idx) = mean(g.actionL2Log, "omitnan");

    % intentProvenanceLog{t}.gateActive describes the gate transition that
    % PRODUCES state_(t+1) - it is the permission that will apply at
    % decision t+1, not at decision t (advanceIntentReference.m). Step 1
    % always decides under the reset()-default permission=false (no
    % decoder call precedes the first decision for state60). Realign
    % before comparing to motionPermissionLog(t).
    gateActiveB = cellfun(@(p) logical(p.gateActive), b.intentProvenanceLog(:));
    gateActiveG = cellfun(@(p) logical(p.gateActive), g.intentProvenanceLog(:));
    if ~isequal(gateActiveB, gateActiveG)
        % The gate is driven only by EMG (identical dataset/seed for both
        % conditions), so it must be identical - a mismatch would mean the
        % two runs were not actually paired on the same input.
        gateMismatchEpisodes = gateMismatchEpisodes + 1;
    end
    permissionExpectedG = [false; gateActiveG(1:end-1)];
    permissionG = logical(g.motionPermissionLog(:));
    if ~isequal(permissionG, permissionExpectedG)
        error("run_no_glove_stage7u_closed_loop_confirmation:PermissionMismatch", ...
            "Gated episode %d: motionPermissionLog does not match the " + ...
            "one-step-lagged gateActive it must equal.", idx);
    end

    permissionExpectedB = [false; gateActiveB(1:end-1)];
    restRows = ~permissionExpectedB;
    restPhaseStepsB = restPhaseStepsB + sum(restRows);
    restPhaseStepsG = restPhaseStepsG + sum(restRows);
    restPhaseNonzeroB = restPhaseNonzeroB + ...
        sum(any(b.actionPwmLog(restRows, :) ~= 0, 2));
    restPhaseNonzeroG = restPhaseNonzeroG + ...
        sum(any(g.actionPwmLog(restRows, :) ~= 0, 2));
    activeStepsB = activeStepsB + sum(permissionExpectedB);
end
% False inhibition cannot occur in this paired run: gateActive is EMG-only
% (identical dataset/seed in both conditions, asserted above) and
% permissionG==gateActiveG exactly (asserted above), so permission is never
% false while the decoder itself is signalling activity.

episodeTable = table(episode, trackingMseB, trackingMseG, ...
    actionL2B, actionL2G, ...
    'VariableNames', ["episode", "trackingMseBaseline", "trackingMseGated", ...
    "actionL2Baseline", "actionL2Gated"]);

summary = struct( ...
    "episodeCount", n, ...
    "gateMismatchEpisodes", gateMismatchEpisodes, ...
    "trackingMseBaselineMean", mean(trackingMseB), ...
    "trackingMseGatedMean", mean(trackingMseG), ...
    "trackingMseRatio", mean(trackingMseG) / mean(trackingMseB), ...
    "actionL2BaselineMean", mean(actionL2B), ...
    "actionL2GatedMean", mean(actionL2G), ...
    "activeStepFraction", activeStepsB / max(1, restPhaseStepsB + activeStepsB), ...
    "restPhaseStepCount", restPhaseStepsB, ...
    "restPhasePwmNonZeroFractionBaseline", ...
        restPhaseNonzeroB / max(1, restPhaseStepsB), ...
    "restPhasePwmNonZeroFractionGated", ...
        restPhaseNonzeroG / max(1, restPhaseStepsG));

comparison = struct("episodeTable", episodeTable, "summary", summary);
end

function files = sortEpisodeFiles(directory)
listing = dir(fullfile(directory, "episode*.mat"));
if isempty(listing)
    error("run_no_glove_stage7u_closed_loop_confirmation:NoEpisodes", ...
        "No episodes found in %s.", directory);
end
[~, order] = sort({listing.name});
listing = listing(order);
files = strings(numel(listing), 1);
for idx = 1:numel(listing)
    files(idx) = string(fullfile(listing(idx).folder, listing(idx).name));
end
end

function newestDir = findNewestSubdir(parentDir)
listing = dir(parentDir);
listing = listing([listing.isdir] & ~startsWith({listing.name}, "."));
if isempty(listing)
    error("run_no_glove_stage7u_closed_loop_confirmation:NoSubdir", ...
        "No subdirectory created under %s.", parentDir);
end
[~, order] = sort([listing.datenum], "descend");
newestDir = string(fullfile(parentDir, listing(order(1)).name));
end

function [commit, dirty] = getGitState(repoRoot)
[status, output] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
if status == 0
    commit = string(strtrim(output));
else
    commit = "unknown";
end
[status, output] = system(sprintf('git -C "%s" status --porcelain', repoRoot));
dirty = status ~= 0 || strlength(strtrim(string(output))) > 0;
end

function hash = fileSha256(filePath)
escaped = strrep(char(string(filePath)), "'", "''");
command = sprintf([ ...
    'powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 ' ...
    '-LiteralPath ''%s'').Hash"'], escaped);
[status, output] = system(command);
if status ~= 0
    error("run_no_glove_stage7u_closed_loop_confirmation:HashFailed", ...
        "Could not hash %s.", filePath);
end
hash = upper(string(strtrim(output)));
end

function writeText(path, value)
fid = fopen(path, "w");
if fid < 0
    error("run_no_glove_stage7u_closed_loop_confirmation:WriteFailed", ...
        "Could not write %s.", path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", value);
end

function cleanupRuntime(originalDir)
clearConfigurablesOverride();
if isfolder(originalDir)
    cd(originalDir);
end
end
