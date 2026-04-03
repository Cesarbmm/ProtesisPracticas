function results = run_td3_longrun(options)
%run_td3_longrun continues a plain TD3 checkpoint for long exploratory training.
%
% This launcher is the base-policy analogue of run_residual_lift_longrun.
% It resumes TD3 training from an existing checkpoint, uses sparse saves,
% and records a lightweight summary so the run can later be audited
% against Agent7250 and residual references.

arguments
    options = struct()
end

options = normalizeLongrunOptions(options);

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));

cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

clearConfigurablesOverride();
cleanup = onCleanup(@() clearConfigurablesOverride());

baseConfigs = configurables();
resultsRoot = resolveResultsRoot(options.resultsRoot, repoRoot);
mkdir(resultsRoot);

override = buildLongrunOverride(baseConfigs, options, resultsRoot);
protocolInfo = buildProtocolInfo(options);

try
    setConfigurablesOverride(override);
    trainInterface("td3", "", "");
    clearConfigurablesOverride();

    trainingResult = analyzeExperimentRun(string(resultsRoot));
    trainingResult.randomSeed = options.randomSeed;

    results = struct( ...
        "resultsRoot", string(resultsRoot), ...
        "trainingRunDir", string(resultsRoot), ...
        "options", options, ...
        "protocolInfo", protocolInfo, ...
        "trainingResult", trainingResult);

    save(fullfile(resultsRoot, "td3_longrun_results.mat"), ...
        "results", "protocolInfo", "trainingResult", "options");
    writeTextFile(fullfile(resultsRoot, "td3_longrun_summary.txt"), ...
        buildSummaryText(results));
catch ME
    clearConfigurablesOverride();
    rethrow(ME);
end
end

function options = normalizeLongrunOptions(options)
td3 = configurables("td3");
defaults = struct( ...
    "baseCheckpointPath", getAgent7250CheckpointPath(), ...
    "baseLabel", "Agent7250", ...
    "trainingEpisodes", 50000, ...
    "trainingSaveEvery", 500, ...
    "trainingPlots", "none", ...
    "flagSaveTraining", true, ...
    "episodeSaveFreq", 500, ...
    "randomSeed", NaN, ...
    "explorationStd", td3.explorationStd, ...
    "explorationStdMin", td3.explorationStdMin, ...
    "explorationStdDecayRate", td3.explorationStdDecayRate, ...
    "resetExperienceBufferBeforeTraining", td3.resetExperienceBufferBeforeTraining, ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.baseCheckpointPath = string(options.baseCheckpointPath);
options.baseLabel = string(options.baseLabel);
options.trainingPlots = string(options.trainingPlots);
end

function override = buildLongrunOverride(baseConfigs, options, resultsRoot)
override = buildMarkov52BaselineOverride(baseConfigs, struct( ...
    "run_training", true, ...
    "newTraining", false, ...
    "agent_id", "td3", ...
    "agentFile", string(options.baseCheckpointPath), ...
    "trainingMaxEpisodes", options.trainingEpisodes, ...
    "trainingSaveAgentEvery", options.trainingSaveEvery, ...
    "trainingPlots", string(options.trainingPlots), ...
    "flagSaveTraining", logical(options.flagSaveTraining), ...
    "episode_save_freq", double(options.episodeSaveFreq), ...
    "plotEpisodeOnTest", false));

override.randomSeed = options.randomSeed;
override.td3.useRecurrent = false;
override.td3.explorationStd = options.explorationStd;
override.td3.explorationStdMin = options.explorationStdMin;
override.td3.explorationStdDecayRate = options.explorationStdDecayRate;
override.td3.resetExperienceBufferBeforeTraining = ...
    logical(options.resetExperienceBufferBeforeTraining);
override.agents_directory = @(varargin) char(resultsRoot);
end

function protocolInfo = buildProtocolInfo(options)
protocolInfo = struct( ...
    "baseCheckpointPath", string(options.baseCheckpointPath), ...
    "baseLabel", string(options.baseLabel), ...
    "trainingEpisodes", double(options.trainingEpisodes), ...
    "trainingSaveEvery", double(options.trainingSaveEvery), ...
    "episodeSaveFreq", double(options.episodeSaveFreq), ...
    "randomSeed", double(options.randomSeed), ...
    "explorationStd", double(options.explorationStd), ...
    "explorationStdMin", double(options.explorationStdMin), ...
    "explorationStdDecayRate", double(options.explorationStdDecayRate), ...
    "resetExperienceBufferBeforeTraining", logical(options.resetExperienceBufferBeforeTraining));
end

function resultsRoot = resolveResultsRoot(requestedRoot, repoRoot)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    resultsRoot = char(requestedRoot);
else
    resultsRoot = fullfile( ...
        repoRoot, "Agentes", "td3_longrun", ...
        string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end
end

function textValue = buildSummaryText(results)
protocolInfo = results.protocolInfo;
trainingSummary = results.trainingResult.trainingSummary;

lines = strings(0, 1);
lines(end+1) = "TD3 long-run";
lines(end+1) = "============";
lines(end+1) = "";
lines(end+1) = sprintf("Base checkpoint: %s", protocolInfo.baseCheckpointPath);
lines(end+1) = sprintf("Base label: %s", protocolInfo.baseLabel);
lines(end+1) = sprintf("Training episodes: %d", round(protocolInfo.trainingEpisodes));
lines(end+1) = sprintf("Checkpoint save every: %d", round(protocolInfo.trainingSaveEvery));
lines(end+1) = sprintf("Episode save freq: %d", round(protocolInfo.episodeSaveFreq));
if isfinite(protocolInfo.randomSeed)
    lines(end+1) = sprintf("Random seed = %d", round(protocolInfo.randomSeed));
else
    lines(end+1) = "Random seed = historical rng('default')";
end
lines(end+1) = sprintf("Exploration std/min/decay = %.4f / %.4f / %.6g", ...
    protocolInfo.explorationStd, protocolInfo.explorationStdMin, protocolInfo.explorationStdDecayRate);
lines(end+1) = sprintf("Reset experience buffer before training = %d", ...
    protocolInfo.resetExperienceBufferBeforeTraining);
lines(end+1) = "";
lines(end+1) = sprintf("Episodes completed: %d", trainingSummary.numEpisodes);
lines(end+1) = sprintf("AverageReward final: %.6f", trainingSummary.averageRewardFinal);
lines(end+1) = sprintf("Best AverageReward: %.6f (episode %d)", ...
    trainingSummary.bestAverageReward, trainingSummary.bestAverageRewardEpisode);
textValue = strjoin(lines, newline);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textValue);
end
