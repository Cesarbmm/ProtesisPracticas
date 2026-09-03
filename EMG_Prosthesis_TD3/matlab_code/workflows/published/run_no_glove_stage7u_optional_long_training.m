function run_no_glove_stage7u_optional_long_training(options)
%run_no_glove_stage7u_optional_long_training OPTIONAL, NOT AUTHORIZED TO
%RUN AUTOMATICALLY. Trains a fresh TD3 actor with motionPermissionEnabled
%active DURING training (not just at inference, unlike the validated
%ETAPA 7U result which keeps Agent200 frozen). This tests a different,
%unvalidated hypothesis: does an actor that never receives gradient from
%gated-away rest-phase actions converge to something even better than
%Agent200+external gate? The already-closed ETAPA 7U result does NOT
%require this - it works with a frozen actor. Run manually:
%
%   run_no_glove_stage7u_optional_long_training()
%
% or with a shorter budget to sanity-check first:
%
%   run_no_glove_stage7u_optional_long_training(struct("trainingMaxEpisodes", 500))
%
% Saves, every options.trainingSaveAgentEvery episodes, an Agent<N>.mat
% checkpoint (MATLAB RL toolbox default), and full per-episode logs every
% options.episodeSaveFreq episodes (both under the training directory
% printed at the end). After training, automatically evaluates the FINAL
% checkpoint on options.testEpisodeCount (default 50, matching the
% project's historical convention) fresh episodes with figures saved,
% exactly like every other checkpoint evaluation in this repo
% (plot_episode.m -> repoRoot/Imagenes, moved into the run folder).
%
% Nothing here is invoked by any other script. No push happens.

arguments
    options.trainingMaxEpisodes (1, 1) double {mustBeInteger, mustBePositive} = 10000
    options.trainingSaveAgentEvery (1, 1) double {mustBeInteger, mustBePositive} = 500
    options.episodeSaveFreq (1, 1) double {mustBeInteger, mustBePositive} = 10
    options.testEpisodeCount (1, 1) double {mustBeInteger, mustBePositive} = 50
    options.calibrationSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 11
    options.trainingSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 11
    options.testSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 4001
    options.resultsRoot (1, 1) string = ""
    % ETAPA 7U campaign audit (2026-09-03): the original 10000-episode run
    % used the unchanged ETAPA 6 exploration decay (rate 1e-4), tuned for
    % Agent200's 200-episode/~12200-step horizon. Over a 10000-episode/
    % ~610000-step horizon that decays to the floor (0.02) almost
    % immediately, leaving ~98% of training with negligible exploration -
    % a documented contributor to the actor saturating against tanh's
    % bounds. Default here reproduces that same proportional decay
    % (reaches ~0.295x std, same as Agent200 at its own final episode)
    % scaled to trainingMaxEpisodes*61 steps; explicitly override to 1e-4
    % to reproduce the original (unfixed) run exactly.
    options.explorationStdDecayRate (:, 1) double {mustBeNonnegative} = []
end
if ~isempty(options.explorationStdDecayRate) && ...
        (~isscalar(options.explorationStdDecayRate) || ...
        options.explorationStdDecayRate <= 0)
    error("run_no_glove_stage7u_optional_long_training:InvalidDecayRate", ...
        "explorationStdDecayRate must be a positive scalar when given.");
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = string(paths.matlabRoot);
repoRoot = string(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));
clearConfigurablesOverride();

if strlength(options.resultsRoot) == 0
    options.resultsRoot = fullfile(repoRoot, "Agentes", ...
        "no_glove_intent_control", "stage7u_optional_long_training");
end
runRoot = fullfile(options.resultsRoot, ...
    string(datetime("now", "Format", "yyyy-MM-dd_HH-mm-ss-SSS")));
mkdir(runRoot);
fixtureDir = fullfile(runRoot, "fixture");
mkdir(fixtureDir);

%% Deterministic corpus (same seed-11 fixture used throughout ETAPA 6-7U)
corpus = buildNoGloveStage6SyntheticCorpus(options.calibrationSeed);
trainingPath = fullfile(fixtureDir, "training_emg_only.mat");
emgs = corpus.trainingEmgs; %#ok<NASGU>
metadata = corpus.trainingMetadata; %#ok<NASGU>
save(trainingPath, "emgs", "metadata");
evaluationPath = fullfile(fixtureDir, "evaluation_emg_only.mat");
emgs = corpus.evaluationEmgs; %#ok<NASGU>
metadata = corpus.evaluationMetadata; %#ok<NASGU>
save(evaluationPath, "emgs", "metadata");

%% Training: the ONLY manipulated factor vs the ETAPA 6 profile that
%% produced Agent200 is motionPermissionEnabled=true, active from episode 1.
trainingDir = fullfile(runRoot, "training");
mkdir(trainingDir);
profile = buildNoGloveStage6Override(corpus.calibration, ...
    corpus.expectedContext, options.trainingSeed, ...
    options.trainingMaxEpisodes, options.trainingSaveAgentEvery, ...
    trainingPath, trainingDir, "intentMarkov60");
profile.motionPermissionEnabled = true;
profile.episode_save_freq = options.episodeSaveFreq;
profile.simulationPositionSafety = ...
    buildNoGloveSimulationPositionSafety(corpus.calibration, true);
% Audit finding (2026-09-03, campaign 2026-09-03_00-49-48-172): with the
% ETAPA 6 default decay rate (1e-4), exploration std collapses to its
% floor (0.02) within the first ~1-2% of a 10000-episode/~610000-step
% campaign (it only reached ~0.06 across Agent200's whole 200-episode/
% ~12200-step run). Combined with a tanh-bounded actor, this measurably
% coincided with the actor saturating to near +-1 raw output - including
% during gated-off rest steps - for most of training. Default here keeps
% the SAME proportional decay Agent200 experienced (ending at the same
% ~0.295x multiplier), scaled to this run's actual horizon, so exploration
% stays meaningfully non-floored throughout. Pass the historical 1e-4
% explicitly to exactly reproduce the original (unfixed) run.
if isempty(options.explorationStdDecayRate)
    profile.td3.explorationStdDecayRate = ...
        computeNoGloveStage7uExplorationDecayRate(options.trainingMaxEpisodes);
else
    profile.td3.explorationStdDecayRate = options.explorationStdDecayRate;
end
setConfigurablesOverride(profile);
fprintf("Starting ETAPA 7U training: %d episodes, checkpoint every %d, " + ...
    "motionPermissionEnabled=true, explorationStdDecayRate=%.6g.\n", ...
    options.trainingMaxEpisodes, options.trainingSaveAgentEvery, ...
    profile.td3.explorationStdDecayRate);
% train()'s return value carries EpisodeReward/EpisodeSteps/EpisodeQ0 (the
% critic's value estimate at each episode's initial state) per episode -
% available with zero training changes, but trainInterface's caller must
% capture and save it or it is lost when the function returns.
trainingInfo = trainInterface("td3_no_glove_intent", "", ""); %#ok<NASGU>
clearConfigurablesOverride();
trainingRunDir = findNewestSubdir(trainingDir);
save(fullfile(trainingRunDir, "training_info.mat"), "trainingInfo");
runMetadata = struct( ...
    "trainingMaxEpisodes", options.trainingMaxEpisodes, ...
    "trainingSaveAgentEvery", options.trainingSaveAgentEvery, ...
    "trainingSeed", options.trainingSeed, "testSeed", options.testSeed, ...
    "calibrationSeed", options.calibrationSeed, ...
    "explorationStdDecayRate", profile.td3.explorationStdDecayRate, ...
    "explorationStd", profile.td3.explorationStd, ...
    "explorationStdMin", profile.td3.explorationStdMin, ...
    "motionPermissionEnabled", true, ...
    "createdAt", string(datetime("now", "TimeZone", "UTC", ...
        "Format", "yyyy-MM-dd'T'HH:mm:ssXXX")));
save(fullfile(trainingRunDir, "run_metadata.mat"), "runMetadata");
% trainingInfo is an rl.train.rlTrainingResult OBJECT (properties, not a
% struct) - isfield() always returns false on it; use isprop() instead.
if isprop(trainingInfo, "EpisodeReward")
    trainingMetricsTable = table( ...
        (1:numel(trainingInfo.EpisodeReward))', ...
        trainingInfo.EpisodeReward(:), trainingInfo.EpisodeSteps(:), ...
        'VariableNames', ["episode", "episodeReward", "episodeSteps"]);
    if isprop(trainingInfo, "EpisodeQ0") && ~isempty(trainingInfo.EpisodeQ0)
        trainingMetricsTable.episodeQ0 = trainingInfo.EpisodeQ0(:);
    end
    writetable(trainingMetricsTable, ...
        fullfile(trainingRunDir, "training_metrics_per_episode.csv"));
end

%% Test: evaluate EVERY saved checkpoint (not just the final one - do not
%% assume Agent<max> is best) on the SAME testEpisodeCount fresh episodes,
%% same seed, figures saved (matching the historical convention).
checkpoints = dir(fullfile(trainingRunDir, "Agent*.mat"));
if isempty(checkpoints)
    error("run_no_glove_stage7u_optional_long_training:NoCheckpoints", ...
        "Training produced no checkpoints in %s.", trainingRunDir);
end
episodeNumbers = regexp({checkpoints.name}, '^Agent(\d+)\.mat$', "tokens");
episodeNumbers = cellfun(@(t) str2double(t{1}{1}), episodeNumbers);
[episodeNumbers, order] = sort(episodeNumbers);
checkpoints = checkpoints(order);

testDir = fullfile(runRoot, "test");
mkdir(testDir);
[datasetFolder, datasetStem] = fileparts(evaluationPath);
summaryRows = cell(numel(checkpoints), 1);
for ckIdx = 1:numel(checkpoints)
    checkpointPath = fullfile(checkpoints(ckIdx).folder, checkpoints(ckIdx).name);
    checkpointEpisode = episodeNumbers(ckIdx);
    checkpointTestDir = fullfile(testDir, sprintf("episode_%d", checkpointEpisode));
    mkdir(checkpointTestDir);
    imagenesBefore = listImagenes(repoRoot);
    testProfile = profile;
    testProfile.run_training = false;
    testProfile.newTraining = false;
    testProfile.agentFile = checkpointPath;
    testProfile.agent_id = "td3_no_glove_intent";
    testProfile.randomSeed = options.testSeed;
    testProfile.dataset = {char(string(datasetStem))};
    testProfile.dataset_folder = string(datasetFolder);
    testProfile.flagSaveTraining = true;
    testProfile.episode_save_freq = 1;
    testProfile.plotEpisodeOnTest = true;
    testProfile.simOpts = rlSimulationOptions( ...
        "MaxSteps", testProfile.maxNumberStepsInEpisodes, ...
        "NumSimulations", options.testEpisodeCount, ...
        "StopOnError", "on", "UseParallel", false);
    testProfile.agents_directory = @(agent_id, variant) fullfile( ...
        checkpointTestDir, string(datetime("now", "Format", "yy-MM-dd HH m s")));
    setConfigurablesOverride(testProfile);
    fprintf("Testing checkpoint Agent%d (%d/%d) on %d fresh episodes.\n", ...
        checkpointEpisode, ckIdx, numel(checkpoints), options.testEpisodeCount);
    trainInterface("td3_no_glove_intent", "", "");
    clearConfigurablesOverride();
    checkpointRunDir = findNewestSubdir(checkpointTestDir);
    figureDir = fullfile(checkpointRunDir, "figures");
    mkdir(figureDir);
    moveNewImagenes(repoRoot, imagenesBefore, figureDir);
    summaryRows{ckIdx} = summarizeCheckpointTest( ...
        checkpointEpisode, checkpointPath, checkpointRunDir);
end
checkpointSummary = vertcat(summaryRows{:});
writetable(checkpointSummary, fullfile(runRoot, "checkpoint_comparison.csv"));

fprintf("\nDone.\n");
fprintf("Training checkpoints: %s\n", trainingRunDir);
fprintf("Per-checkpoint test episodes/logs/figures: %s\\episode_<N>\\...\n", testDir);
fprintf("Checkpoint comparison table: %s\n", ...
    fullfile(runRoot, "checkpoint_comparison.csv"));
disp(checkpointSummary);
fprintf("%s\n%s\n%s\n%s\n", ...
    "Compare each row against Agent200+motionPermission's closed-loop", ...
    "numbers from run_no_glove_stage7u_closed_loop_confirmation before", ...
    "concluding whether training with the gate baked in helped, and do", ...
    "not assume the highest-numbered checkpoint is the best one.");
end

function row = summarizeCheckpointTest(checkpointEpisode, checkpointPath, testRunDir)
files = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(files)
    error("run_no_glove_stage7u_optional_long_training:NoTestEpisodes", ...
        "No test episodes found in %s.", testRunDir);
end
n = numel(files);
trackingMse = zeros(n, 1);
actionL2Raw = zeros(n, 1);
actionL2Eff = zeros(n, 1);
restPwmNonZero = zeros(n, 1);
restSteps = zeros(n, 1);
activeSteps = zeros(n, 1);
safetyCount = zeros(n, 1);
for idx = 1:n
    e = load(fullfile(files(idx).folder, files(idx).name), ...
        "motionPermissionLog", "actionLog", "actionSatLog", ...
        "actionPwmLog", "trackingMseLog", "positionSafetyInterventionLog");
    permission = logical(e.motionPermissionLog(:));
    trackingMse(idx) = mean(e.trackingMseLog, "omitnan");
    actionL2Raw(idx) = mean(e.actionLog.^2, "all");
    actionL2Eff(idx) = mean(e.actionSatLog.^2, "all");
    restPwmNonZero(idx) = sum(any(e.actionPwmLog(~permission, :) ~= 0, 2));
    restSteps(idx) = sum(~permission);
    activeSteps(idx) = sum(permission);
    safetyCount(idx) = sum(e.positionSafetyInterventionLog, "all");
end
row = table(checkpointEpisode, string(checkpointPath), n, ...
    mean(trackingMse), mean(actionL2Raw), mean(actionL2Eff), ...
    sum(restPwmNonZero) / max(1, sum(restSteps)), ...
    sum(activeSteps) / max(1, sum(activeSteps) + sum(restSteps)), ...
    sum(safetyCount), ...
    'VariableNames', ["checkpointEpisode", "checkpointPath", ...
    "testEpisodeCount", "trackingMseMean", "actionL2RawMean", ...
    "actionL2EffectiveMean", "restPwmNonZeroFraction", ...
    "activeStepFraction", "safetyInterventionTotal"]);
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

function newestDir = findNewestSubdir(parentDir)
listing = dir(parentDir);
listing = listing([listing.isdir] & ~startsWith({listing.name}, "."));
if isempty(listing)
    error("run_no_glove_stage7u_optional_long_training:NoSubdir", ...
        "No subdirectory created under %s.", parentDir);
end
[~, order] = sort([listing.datenum], "descend");
newestDir = string(fullfile(parentDir, listing(order(1)).name));
end
