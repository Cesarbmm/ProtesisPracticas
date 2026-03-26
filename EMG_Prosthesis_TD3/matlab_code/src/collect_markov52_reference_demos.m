function results = collect_markov52_reference_demos(options)
%collect_markov52_reference_demos collects offline demos with a reference controller.

arguments
    options = struct()
end

options = normalizeDemoOptions(options);

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

clearConfigurablesOverride();

baseConfigs = configurables();
override = buildMarkov52BaselineOverride(baseConfigs, struct( ...
    "run_training", false, ...
    "newTraining", false, ...
    "flagSaveTraining", false, ...
    "plotEpisodeOnTest", false, ...
    "verbose", false));

setConfigurablesOverride(override);
evalin('base', 'clear classes');
clear configurables
cleanup = onCleanup(@() clearConfigurablesOverride()); %#ok<NASGU>

configs = configurables();
[emgSet, gloveSet] = getDataset(configs.dataset, configs.dataset_folder);

resultsRoot = resolveResultsRoot(options.resultsRoot, repoRoot, "markov52_reference_demos");
episodesDir = fullfile(resultsRoot, "episodes");
mkdir(resultsRoot);
mkdir(episodesDir);

env = Env("", true, emgSet, gloveSet);
controllerOptions = struct( ...
    "deadband", options.deadband, ...
    "errorBins", options.errorBins, ...
    "actionMagnitudes", options.actionMagnitudes, ...
    "maxDelta", options.maxDelta);

rows = cell(options.numEpisodes, 1);
for episodeIdx = 1:options.numEpisodes
    rows{episodeIdx} = runReferenceEpisode(env, episodesDir, episodeIdx, controllerOptions);
end

episodeTable = struct2table(vertcat(rows{:}));
datasetSummary = summarizeDemoTable(episodeTable, options.sanityEpisodes);
datasetSummary.acceptedBySanityGate = ...
    datasetSummary.trackingMseSanityMean <= options.sanityTrackingMseMax && ...
    datasetSummary.saturationFractionSanityMean <= options.sanitySaturationMax && ...
    datasetSummary.deltaActionL2SanityMean <= options.sanityDeltaActionMax;

results = struct( ...
    "resultsRoot", string(resultsRoot), ...
    "episodesDir", string(episodesDir), ...
    "controllerOptions", controllerOptions, ...
    "episodeTable", episodeTable, ...
    "datasetSummary", datasetSummary);

writetable(episodeTable, fullfile(resultsRoot, "reference_demo_episodes.csv"));
writeTextFile(fullfile(resultsRoot, "reference_demo_summary.txt"), ...
    buildDemoSummaryText(datasetSummary, controllerOptions, options));
save(fullfile(resultsRoot, "reference_demo_results.mat"), ...
    "results", "episodeTable", "datasetSummary", "controllerOptions", "options");
end

function options = normalizeDemoOptions(options)
defaults = struct( ...
    "numEpisodes", 200, ...
    "sanityEpisodes", 20, ...
    "deadband", 0.03, ...
    "errorBins", [0.06 0.12 0.20], ...
    "actionMagnitudes", [0.376 0.627 0.878 1.0], ...
    "maxDelta", 0.251, ...
    "resultsRoot", "", ...
    "sanityTrackingMseMax", 0.10, ...
    "sanitySaturationMax", 0.10, ...
    "sanityDeltaActionMax", 0.10);

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
end

function row = runReferenceEpisode(env, episodesDir, episodeIdx, controllerOptions)
obs = reset(env);
done = false;
stepIdx = 0;
prevControllerAction = zeros(4, 1);
experiences = repmat(struct( ...
    "Observation", [], ...
    "Action", [], ...
    "Reward", [], ...
    "NextObservation", [], ...
    "IsDone", false), 0, 1);

while ~done
    [target, pred] = getCurrentTrackingSignals(env);
    [action, ~] = referenceQuantizedController(target, pred, prevControllerAction, controllerOptions);

    [nextObs, reward, done, ~] = step(env, action);

    stepIdx = stepIdx + 1;
    experiences(stepIdx).Observation = obs; %#ok<AGROW>
    experiences(stepIdx).Action = action;
    experiences(stepIdx).Reward = reward;
    experiences(stepIdx).NextObservation = nextObs;
    experiences(stepIdx).IsDone = done;

    obs = nextObs;
    prevControllerAction = action;
end

episodeSummary = summarizeCurrentEpisode(env);
episodeData = struct( ...
    "Experience", experiences, ...
    "EpisodeSummary", episodeSummary, ...
    "ControllerOptions", controllerOptions);
save(fullfile(episodesDir, sprintf("demo_episode_%05d.mat", episodeIdx)), "episodeData");

row = episodeSummary;
row.episodeIdx = episodeIdx;
row.numExperiences = numel(experiences);
row.filePath = string(fullfile(episodesDir, sprintf("demo_episode_%05d.mat", episodeIdx)));
end

function [target, pred] = getCurrentTrackingSignals(env)
target = env.flexJoined_scaler(reduceFlexDimension(env.flexData));
pred = env.flexJoined_scaler(encoder2Flex(env.motorData));
target = double(target(end, :));
pred = double(pred(end, :));
end

function summary = summarizeCurrentEpisode(env)
c = env.c;
actionLog = env.actionLog(1:c, :);
actionWarpLog = env.actionWarpLog(1:c, :);
actionSatLog = env.actionSatLog(1:c, :);
actionPwmLog = env.actionPwmLog(1:c, :);
targetLog = env.flexConvertedLog(1:c);
predLog = env.encoderAdjustedLog(1:c);
diagnostics = computeEpisodeActionDiagnostics( ...
    actionLog, actionSatLog, actionPwmLog, ...
    targetLog, predLog, ...
    env.actionCommandActivationThreshold, env.actionCommandLevels, ...
    false, true, actionWarpLog, ...
    configurables("actionWarpOutputLevels"), ...
    configurables("actionWarpDeadzone"));

summary = struct( ...
    "trackingMseMean", mean(env.trackingMseLog(1:c), "omitnan"), ...
    "trackingMaeMean", mean(env.trackingMaeLog(1:c), "omitnan"), ...
    "actionL2Mean", mean(env.actionL2Log(1:c), "omitnan"), ...
    "saturationFractionMean", mean(env.saturationFractionLog(1:c), "omitnan"), ...
    "deltaActionL2Mean", mean(env.deltaActionL2Log(1:c), "omitnan"), ...
    "episodeRewardMean", mean(env.rewardLog(1:c), "omitnan"), ...
    "absPwmMean", mean(abs(actionPwmLog), "all", "omitnan"), ...
    "thresholdNullFractionMean", diagnostics.thresholdNullFraction, ...
    "rawEffectiveActionErrorMean", diagnostics.meanRawEffectiveActionError, ...
    "rawToWarpedActionErrorMean", diagnostics.rawToWarpedActionErrorMean, ...
    "signFlipFractionMean", diagnostics.signFlipFractionMean, ...
    "saturationRunLengthMean", diagnostics.saturationRunMean, ...
    "saturationRunLengthMax", diagnostics.saturationRunMax, ...
    "stepsPerEpisode", c);
end

function summary = summarizeDemoTable(episodeTable, sanityEpisodes)
sanityRows = min(sanityEpisodes, height(episodeTable));
summary = struct( ...
    "numEpisodes", height(episodeTable), ...
    "trackingMseMean", mean(episodeTable.trackingMseMean, "omitnan"), ...
    "trackingMaeMean", mean(episodeTable.trackingMaeMean, "omitnan"), ...
    "actionL2Mean", mean(episodeTable.actionL2Mean, "omitnan"), ...
    "saturationFractionMean", mean(episodeTable.saturationFractionMean, "omitnan"), ...
    "deltaActionL2Mean", mean(episodeTable.deltaActionL2Mean, "omitnan"), ...
    "absPwmMean", mean(episodeTable.absPwmMean, "omitnan"), ...
    "trackingMseSanityMean", mean(episodeTable.trackingMseMean(1:sanityRows), "omitnan"), ...
    "saturationFractionSanityMean", mean(episodeTable.saturationFractionMean(1:sanityRows), "omitnan"), ...
    "deltaActionL2SanityMean", mean(episodeTable.deltaActionL2Mean(1:sanityRows), "omitnan"));
end

function resultsRoot = resolveResultsRoot(requestedRoot, repoRoot, folderName)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    resultsRoot = char(requestedRoot);
else
    resultsRoot = fullfile(repoRoot, "Agentes", folderName, ...
        string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end
end

function textValue = buildDemoSummaryText(datasetSummary, controllerOptions, options)
lines = strings(0, 1);
lines(end+1) = "markov52 reference demo collection";
lines(end+1) = "================================";
lines(end+1) = "";
lines(end+1) = sprintf("Episodes: %d", datasetSummary.numEpisodes);
lines(end+1) = sprintf("trackingMSE mean: %.6f", datasetSummary.trackingMseMean);
lines(end+1) = sprintf("saturationFraction mean: %.6f", datasetSummary.saturationFractionMean);
lines(end+1) = sprintf("deltaActionL2 mean: %.6f", datasetSummary.deltaActionL2Mean);
lines(end+1) = sprintf("actionL2 mean: %.6f", datasetSummary.actionL2Mean);
lines(end+1) = sprintf("absPWM mean: %.6f", datasetSummary.absPwmMean);
lines(end+1) = sprintf("Sanity gate accepted: %d", datasetSummary.acceptedBySanityGate);
lines(end+1) = "";
lines(end+1) = "Controller:";
lines(end+1) = sprintf("deadband = %.4f", controllerOptions.deadband);
lines(end+1) = sprintf("errorBins = [%s]", join(string(controllerOptions.errorBins), ", "));
lines(end+1) = sprintf("actionMagnitudes = [%s]", join(string(controllerOptions.actionMagnitudes), ", "));
lines(end+1) = sprintf("maxDelta = %.4f", controllerOptions.maxDelta);
lines(end+1) = "";
lines(end+1) = "Sanity thresholds:";
lines(end+1) = sprintf("trackingMSE <= %.4f", options.sanityTrackingMseMax);
lines(end+1) = sprintf("saturationFraction <= %.4f", options.sanitySaturationMax);
lines(end+1) = sprintf("deltaActionL2 <= %.4f", options.sanityDeltaActionMax);
textValue = strjoin(lines, newline);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end
