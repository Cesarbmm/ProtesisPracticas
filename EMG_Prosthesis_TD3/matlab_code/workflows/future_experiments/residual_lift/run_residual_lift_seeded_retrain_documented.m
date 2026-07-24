function results = run_residual_lift_seeded_retrain_documented(options)
%run_residual_lift_seeded_retrain_documented retrains Residual Lift by seed.
%
% This workflow keeps Agent7250 frozen as the base policy, trains only the
% residual branch, audits saved checkpoints, runs a final visual test for
% the selected checkpoint of each seed, and writes figures plus summaries
% under a fresh Agentes/ campaign directory.

arguments
    options = struct()
end

options = normalizeOptions(options);

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);

cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

resultsRoot = resolveResultsRoot(options.resultsRoot, workspaceRoot);
ensureDirectoryExists(resultsRoot);
summaryRoot = fullfile(resultsRoot, "summary");
figuresRoot = fullfile(resultsRoot, "figures");
ensureDirectoryExists(summaryRoot);
ensureDirectoryExists(figuresRoot);

benchmark = getAgent7250Benchmark();
seedRows = cell(numel(options.seeds), 1);
seedResults = cell(numel(options.seeds), 1);

for i = 1:numel(options.seeds)
    seedValue = double(options.seeds(i));
    [seedRows{i}, seedResults{i}] = runSeedRetrain( ...
        seedValue, options, resultsRoot, figuresRoot, benchmark);
end

perSeedTable = struct2table(vertcat(seedRows{:}));
aggregateSummary = summarizeCampaign(perSeedTable, benchmark);
referenceTable = buildReferenceComparisonTable( ...
    perSeedTable, aggregateSummary, options, resultsRoot, benchmark);

trainingOverviewPath = fullfile(figuresRoot, "residual_retrain_training_overview.png");
comparisonFigurePath = fullfile(figuresRoot, "residual_retrain_comparison.png");
if logical(options.generateTrainingFigure)
    createTrainingOverviewFigure(perSeedTable, trainingOverviewPath);
else
    trainingOverviewPath = "";
end
createComparisonFigure(referenceTable, comparisonFigurePath);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.options = options;
results.benchmark = benchmark;
results.perSeedTable = perSeedTable;
results.aggregateSummary = aggregateSummary;
results.referenceTable = referenceTable;
results.seedResults = seedResults;
results.figurePaths = struct( ...
    "trainingOverview", string(trainingOverviewPath), ...
    "comparison", string(comparisonFigurePath));

writetable(perSeedTable, fullfile(summaryRoot, "residual_retrain_summary.csv"));
writetable(referenceTable, fullfile(summaryRoot, "residual_retrain_reference_comparison.csv"));
writeTextFile(fullfile(summaryRoot, "residual_retrain_summary.txt"), ...
    buildSummaryText(results));
writeTextFile(fullfile(summaryRoot, "residual_retrain_figures.md"), ...
    buildFigureIndexMarkdown(results));
results.figureIndexPath = string(fullfile(summaryRoot, "residual_retrain_figures.md"));

save(fullfile(summaryRoot, "residual_retrain_results.mat"), ...
    "results", "perSeedTable", "aggregateSummary", "referenceTable", ...
    "options", "seedResults");
end

function options = normalizeOptions(options)
defaults = struct( ...
    "baseCheckpointPath", getAgent7250CheckpointPath(), ...
    "baseLabel", "Agent7250", ...
    "residualScale", 0.20, ...
    "residualHiddenUnits", 32, ...
    "seeds", [11 22 33 44 55], ...
    "trainingEpisodes", 3500, ...
    "trainingSaveEvery", 100, ...
    "episodeSaveFreq", 100, ...
    "trainingPlots", "none", ...
    "flagSaveTraining", true, ...
    "explorationStd", 0.02, ...
    "explorationStdMin", 0.002, ...
    "explorationStdDecayRate", 1e-4, ...
    "resetExperienceBufferBeforeTraining", false, ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 5, ...
    "auditSamplingPolicy", struct("mode", "all"), ...
    "finalTestEpisodes", 50, ...
    "plotEpisodeOnTest", true, ...
    "generateTrainingFigure", true, ...
    "generateVisualTestFigure", true, ...
    "useStopBandSelection", true, ...
    "stopBandWindow", [1750 2250], ...
    "evaluateReferenceCheckpoints", true, ...
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
options.seeds = double(options.seeds(:))';
options.trainingEpisodes = double(options.trainingEpisodes);
options.trainingSaveEvery = double(options.trainingSaveEvery);
options.episodeSaveFreq = double(options.episodeSaveFreq);
options.auditFastSimulations = max(2, double(options.auditFastSimulations));
options.auditFullSimulations = max(2, double(options.auditFullSimulations));
options.auditTopK = max(1, double(options.auditTopK));
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.plotEpisodeOnTest = logical(options.plotEpisodeOnTest);
options.generateTrainingFigure = logical(options.generateTrainingFigure);
options.generateVisualTestFigure = logical(options.generateVisualTestFigure);
options.useStopBandSelection = logical(options.useStopBandSelection);
options.stopBandWindow = double(options.stopBandWindow);
options.evaluateReferenceCheckpoints = logical(options.evaluateReferenceCheckpoints);
options.resultsRoot = string(options.resultsRoot);

if ~isstruct(options.auditSamplingPolicy)
    error("options.auditSamplingPolicy must be a struct.");
end
if numel(options.stopBandWindow) ~= 2
    error("options.stopBandWindow must be a two-element episode range.");
end
end

function [seedRow, seedResult] = runSeedRetrain(seedValue, options, resultsRoot, figuresRoot, benchmark)
seedLabel = sprintf("seed_%03d", round(seedValue));
seedRoot = fullfile(resultsRoot, seedLabel);
ensureDirectoryExists(seedRoot);

phaseBIncludePolicy = struct();
if options.useStopBandSelection
    phaseBIncludePolicy = struct("mode", "episode_window", "window", options.stopBandWindow);
end

pilotOptions = struct( ...
    "baseCheckpointPath", options.baseCheckpointPath, ...
    "baseLabel", options.baseLabel, ...
    "residualScale", options.residualScale, ...
    "residualHiddenUnits", options.residualHiddenUnits, ...
    "explorationStd", options.explorationStd, ...
    "explorationStdMin", options.explorationStdMin, ...
    "explorationStdDecayRate", options.explorationStdDecayRate, ...
    "resetExperienceBufferBeforeTraining", options.resetExperienceBufferBeforeTraining, ...
    "trainingEpisodes", options.trainingEpisodes, ...
    "trainingSaveEvery", options.trainingSaveEvery, ...
    "trainingPlots", options.trainingPlots, ...
    "flagSaveTraining", options.flagSaveTraining, ...
    "episodeSaveFreq", options.episodeSaveFreq, ...
    "randomSeed", seedValue, ...
    "auditFastSimulations", options.auditFastSimulations, ...
    "auditFullSimulations", options.auditFullSimulations, ...
    "auditTopK", options.auditTopK, ...
    "auditSamplingPolicy", options.auditSamplingPolicy, ...
    "auditPhaseBIncludePolicy", phaseBIncludePolicy, ...
    "alwaysRunVisualTest", false, ...
    "resultsRoot", string(seedRoot));

pilotResults = run_residual_lift_pilot(pilotOptions);

trainingFigurePath = fullfile(figuresRoot, string(seedLabel) + "_training_progress.png");
if logical(options.generateTrainingFigure)
    trainingAnalysis = analyzeExperimentRun( ...
        string(pilotResults.trainingRunDir), string(trainingFigurePath));
    createTrainingProgressFigureFromRun( ...
        string(pilotResults.trainingRunDir), string(trainingFigurePath));
else
    trainingAnalysis = analyzeExperimentRun(string(pilotResults.trainingRunDir));
    trainingFigurePath = "";
end

[selectedAuditRow, selectionMeta] = selectCheckpointForSeed( ...
    pilotResults.auditResults.phaseBTable, options);

finalTestRoot = fullfile(seedRoot, "selected_checkpoint_final_test");
ensureDirectoryExists(finalTestRoot);
visualCopyStartedAt = now;
runCheckpointTest(string(selectedAuditRow.checkpointPath), ...
    options.finalTestEpisodes, options.plotEpisodeOnTest, struct( ...
    "resultsRoot", finalTestRoot));
finalTestRunDir = findNewestSubdir(finalTestRoot);
finalAnalysis = analyzeExperimentRun(string(finalTestRunDir));
finalDecision = classifyBenchmarkAcceptance(finalAnalysis.episodeSummary, benchmark);

visualTestFigurePath = "";
if logical(options.generateVisualTestFigure)
    visualTestFigurePath = fullfile(figuresRoot, sprintf( ...
        "%s_selected_checkpoint_episode_%d_visual_test.png", ...
        seedLabel, round(options.finalTestEpisodes)));
    visualTestFigurePath = copyOrCreateVisualTestFigure( ...
        string(finalTestRunDir), string(visualTestFigurePath), ...
        round(options.finalTestEpisodes), visualCopyStartedAt);
end

trainingSummary = getTrainingSummaryOrEmpty(trainingAnalysis);

seedRow = struct( ...
    "seed", double(seedValue), ...
    "seedLabel", string(seedLabel), ...
    "trainingRunDir", string(pilotResults.trainingRunDir), ...
    "selectedCheckpointPath", string(selectedAuditRow.checkpointPath), ...
    "selectedCheckpointEpisode", double(selectedAuditRow.checkpointEpisode), ...
    "finalTestRunDir", string(finalTestRunDir), ...
    "trainingFigurePath", string(trainingFigurePath), ...
    "visualTestFigurePath", string(visualTestFigurePath), ...
    "trackingMSE", double(finalAnalysis.episodeSummary.trackingMseMean), ...
    "trackingMAE", double(finalAnalysis.episodeSummary.trackingMaeMean), ...
    "actionL2", double(finalAnalysis.episodeSummary.actionL2Mean), ...
    "saturationFraction", double(finalAnalysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2", double(finalAnalysis.episodeSummary.deltaActionL2Mean), ...
    "finalStatus", string(finalDecision.status), ...
    "selectionReason", string(selectionMeta.reason), ...
    "selectedInStopBandWindow", logical(selectionMeta.selectedInStopBandWindow), ...
    "auditStatus", string(selectedAuditRow.benchmarkStatus), ...
    "auditTrackingMSE", double(selectedAuditRow.trackingMseMean), ...
    "auditTrackingMAE", double(selectedAuditRow.trackingMaeMean), ...
    "auditActionL2", double(selectedAuditRow.actionL2Mean), ...
    "auditSaturationFraction", double(selectedAuditRow.saturationFractionMean), ...
    "auditDeltaActionL2", double(selectedAuditRow.deltaActionL2Mean), ...
    "trainingAverageRewardFinal", getStructField(trainingSummary, "averageRewardFinal", NaN), ...
    "trainingBestAverageReward", getStructField(trainingSummary, "bestAverageReward", NaN), ...
    "trainingBestAverageRewardEpisode", getStructField(trainingSummary, "bestAverageRewardEpisode", NaN));

seedResult = struct( ...
    "pilotResults", pilotResults, ...
    "trainingAnalysis", trainingAnalysis, ...
    "selectedAuditRow", selectedAuditRow, ...
    "selectionMeta", selectionMeta, ...
    "finalAnalysis", finalAnalysis, ...
    "finalDecision", finalDecision, ...
    "trainingFigurePath", string(trainingFigurePath), ...
    "visualTestFigurePath", string(visualTestFigurePath));
end

function [selectedRow, meta] = selectCheckpointForSeed(phaseBTable, options)
rows = table2struct(phaseBTable);
rankedRows = rankRows(rows);
topRow = rankedRows(1);

meta = struct( ...
    "reason", "best_ranked_phaseB_checkpoint", ...
    "selectedInStopBandWindow", false);

if ~logical(options.useStopBandSelection)
    selectedRow = topRow;
    return;
end

windowValue = double(options.stopBandWindow);
episodes = double([rows.checkpointEpisode]);
statuses = string({rows.benchmarkStatus});
inWindow = episodes >= windowValue(1) & episodes <= windowValue(2);
accepted = statuses == "ConditionA" | statuses == "ConditionB";

acceptedWindowIdx = find(inWindow & accepted);
if ~isempty(acceptedWindowIdx)
    [~, order] = sort(episodes(acceptedWindowIdx), "ascend");
    selectedRow = rows(acceptedWindowIdx(order(1)));
    meta.reason = "earliest_accepted_checkpoint_inside_stopband_window";
    meta.selectedInStopBandWindow = true;
    return;
end

windowIdx = find(inWindow);
if isempty(windowIdx)
    selectedRow = topRow;
    meta.reason = "no_checkpoint_inside_stopband_window";
    return;
end

windowBest = rankRows(rows(windowIdx));
windowBest = windowBest(1);
topInsideWindow = double(topRow.checkpointEpisode) >= windowValue(1) && ...
    double(topRow.checkpointEpisode) <= windowValue(2);
if topInsideWindow
    selectedRow = topRow;
    meta.reason = "best_ranked_checkpoint_inside_stopband_window";
    meta.selectedInStopBandWindow = true;
    return;
end

improvesTracking = double(topRow.trackingMseMean) < double(windowBest.trackingMseMean);
notWorseEffort = double(topRow.actionL2Mean) <= double(windowBest.actionL2Mean);
notWorseSaturation = double(topRow.saturationFractionMean) <= double(windowBest.saturationFractionMean);

if improvesTracking && notWorseEffort && notWorseSaturation
    selectedRow = topRow;
    meta.reason = "outside_window_promoted_by_tracking_without_effort_or_saturation_regression";
else
    selectedRow = windowBest;
    meta.reason = "fallback_to_best_checkpoint_inside_stopband_window";
    meta.selectedInStopBandWindow = true;
end
end

function rankedRows = rankRows(rows)
statusRank = arrayfun(@mapStatusToRank, string({rows.benchmarkStatus}));
metricMatrix = [ ...
    -statusRank(:), ...
    double([rows.trackingMseMean])', ...
    double([rows.saturationFractionMean])', ...
    double([rows.actionL2Mean])', ...
    double([rows.deltaActionL2Mean])'];
[~, order] = sortrows(metricMatrix);
rankedRows = rows(order);
end

function rank = mapStatusToRank(status)
switch string(status)
    case "ConditionA"
        rank = 2;
    case "ConditionB"
        rank = 1;
    otherwise
        rank = 0;
end
end

function createTrainingProgressFigureFromRun(runDir, figurePath)
trainingInfoPath = fullfile(runDir, "training_info.mat");
if ~isfile(trainingInfoPath)
    createEmptyFigure(figurePath, "training_info.mat not found");
    return;
end

data = load(trainingInfoPath, "trainingInfo");
if ~isfield(data, "trainingInfo")
    createEmptyFigure(figurePath, "trainingInfo not found");
    return;
end

trainingInfo = data.trainingInfo;
episodeIndex = getTrainingInfoVector(trainingInfo, "EpisodeIndex");
series = { ...
    "EpisodeReward", [0.45 0.80 1.00], 0.8; ...
    "AverageReward", [0.00 0.45 0.74], 2.0; ...
    "EpisodeQ0", [0.93 0.69 0.13], 0.9};

if isempty(episodeIndex)
    maxLength = 0;
    for i = 1:size(series, 1)
        maxLength = max(maxLength, numel(getTrainingInfoVector(trainingInfo, series{i, 1})));
    end
    episodeIndex = (1:maxLength)';
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
hold on
legendLabels = strings(0, 1);
for i = 1:size(series, 1)
    values = getTrainingInfoVector(trainingInfo, series{i, 1});
    if isempty(values)
        continue;
    end
    x = episodeIndex(1:min(numel(episodeIndex), numel(values)));
    y = values(1:numel(x));
    plot(x, y, "Color", series{i, 2}, "LineWidth", series{i, 3});
    legendLabels(end+1, 1) = series{i, 1}; %#ok<AGROW>
end
hold off
grid on
xlabel("Episode")
ylabel("Reward")
title("Residual Lift training progress")
if ~isempty(legendLabels)
    legend(cellstr(legendLabels), "Location", "best", "Box", "off");
else
    text(0.5, 0.5, "No plottable training fields found", ...
        "HorizontalAlignment", "center", "Units", "normalized");
end

ensureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function values = getTrainingInfoVector(trainingInfo, fieldName)
values = [];
fieldName = char(string(fieldName));
try
    if isstruct(trainingInfo) && isfield(trainingInfo, fieldName)
        values = trainingInfo.(fieldName);
    elseif any(strcmp(fieldName, properties(trainingInfo)))
        values = trainingInfo.(fieldName);
    end
catch
    values = [];
end

if ~isempty(values)
    values = double(values(:));
end
end

function createTrainingOverviewFigure(perSeedTable, figurePath)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
tiledlayout(f, 2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile;
hold on
for i = 1:height(perSeedTable)
    trainingInfoPath = fullfile(perSeedTable.trainingRunDir(i), "training_info.mat");
    if ~isfile(trainingInfoPath)
        continue;
    end
    data = load(trainingInfoPath, "trainingInfo");
    if ~isfield(data, "trainingInfo")
        continue;
    end
    episodeIndex = getTrainingInfoVector(data.trainingInfo, "EpisodeIndex");
    averageReward = getTrainingInfoVector(data.trainingInfo, "AverageReward");
    if isempty(averageReward)
        averageReward = getTrainingInfoVector(data.trainingInfo, "EpisodeReward");
    end
    if isempty(averageReward)
        continue;
    end
    if isempty(episodeIndex)
        episodeIndex = (1:numel(averageReward))';
    end
    n = min(numel(episodeIndex), numel(averageReward));
    plot(episodeIndex(1:n), averageReward(1:n), "LineWidth", 1.4, ...
        "DisplayName", sprintf("seed %d", perSeedTable.seed(i)));
end
hold off
grid on
xlabel("Episode")
ylabel("AverageReward")
title("Training trajectory by seed")
legend("Location", "bestoutside", "Box", "off");

nexttile;
bar(categorical(string(perSeedTable.seed)), double(perSeedTable.selectedCheckpointEpisode), ...
    "FaceColor", [0.12 0.47 0.71], "FaceAlpha", 0.85);
grid on
xlabel("Seed")
ylabel("Selected checkpoint episode")
title("Selected checkpoint by seed")

ensureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function visualPath = copyOrCreateVisualTestFigure(runDir, targetPath, targetEpisode, startDatenum)
visualPath = "";
sourcePath = findVisualEpisodeImage(runDir, targetEpisode, startDatenum);
if strlength(sourcePath) > 0 && isfile(sourcePath)
    ensureParentDirectoryExists(targetPath);
    copyfile(char(sourcePath), char(targetPath));
    visualPath = string(targetPath);
    return;
end

visualPath = createRepresentativeEpisodeFigure(runDir, targetPath, targetEpisode);
end

function sourcePath = findVisualEpisodeImage(runDir, targetEpisode, startDatenum)
sourcePath = "";
visualDir = fullfile(runDir, "visual_episodes");
exactName = sprintf("episode_%d.png", targetEpisode);

if isfolder(visualDir)
    exactPath = fullfile(visualDir, exactName);
    if isfile(exactPath)
        sourcePath = string(exactPath);
        return;
    end
    imageInfo = dir(fullfile(visualDir, "episode_*.png"));
    if ~isempty(imageInfo)
        [~, idx] = max([imageInfo.datenum]);
        sourcePath = string(fullfile(imageInfo(idx).folder, imageInfo(idx).name));
        return;
    end
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
legacyImageRoot = fullfile(char(paths.workspaceRoot), "Imagenes");
if ~isfolder(legacyImageRoot)
    return;
end

exactPath = fullfile(legacyImageRoot, exactName);
if isfile(exactPath)
    exactInfo = dir(exactPath);
    if exactInfo.datenum >= double(startDatenum) - 1 / 86400
        sourcePath = string(exactPath);
        return;
    end
end

imageInfo = dir(fullfile(legacyImageRoot, "episode_*.png"));
imageInfo = imageInfo([imageInfo.datenum] >= double(startDatenum) - 1 / 86400);
if isempty(imageInfo)
    return;
end
[~, idx] = max([imageInfo.datenum]);
sourcePath = string(fullfile(imageInfo(idx).folder, imageInfo(idx).name));
end

function figurePath = createRepresentativeEpisodeFigure(runDir, targetPath, targetEpisode)
figurePath = "";
episodeFile = fullfile(runDir, sprintf("episode%05d.mat", targetEpisode));

if ~isfile(episodeFile)
    episodeFiles = dir(fullfile(runDir, "episode*.mat"));
    if isempty(episodeFiles)
        return;
    end
    [~, idx] = max([episodeFiles.datenum]);
    episodeFile = fullfile(episodeFiles(idx).folder, episodeFiles(idx).name);
end

data = load(episodeFile);
if ~isfield(data, "encoderAdjustedLog") || ~isfield(data, "flexConvertedLog")
    return;
end

prosthesisPosition = cat(1, data.encoderAdjustedLog{:});
glovePosition = cat(1, data.flexConvertedLog{:});
actions = [];
if isfield(data, "effectiveActionLog")
    actions = data.effectiveActionLog;
elseif isfield(data, "actionSatLog")
    actions = data.actionSatLog;
elseif isfield(data, "actionLog")
    actions = data.actionLog;
end

nGlove = size(glovePosition, 1);
nProsthesis = size(prosthesisPosition, 1);
if nProsthesis ~= nGlove
    xProsthesis = linspace(1, nGlove, nProsthesis);
    xGlove = 1:nGlove;
    prosthesisInterp = interp1(xProsthesis, prosthesisPosition, xGlove);
else
    prosthesisInterp = prosthesisPosition;
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
motorNames = ["Pulgar", "Indice", "Medio", "Pulgar rotacion"];

for i = 1:4
    nexttile;
    plot(prosthesisInterp(:, i), "-", "LineWidth", 2.0, "Color", [0.00 0.45 0.74]);
    hold on
    plot(glovePosition(:, i), "--", "LineWidth", 2.0, "Color", [0.85 0.33 0.10]);
    if ~isempty(actions)
        actionIdx = linspace(1, size(glovePosition, 1), size(actions, 1));
        scatter(actionIdx, prosthesisInterp(round(actionIdx), i), 24, actions(:, i), "filled");
        colormap(gca, parula);
    end
    hold off
    grid on
    title(string(motorNames(i)))
    xlabel("Step")
    ylabel("Normalized position")
end

ensureParentDirectoryExists(targetPath);
exportgraphics(f, targetPath, "Resolution", 220);
close(f);
figurePath = string(targetPath);
end

function referenceTable = buildReferenceComparisonTable(perSeedTable, aggregateSummary, options, resultsRoot, benchmark)
rows = {};
rows{end+1, 1} = struct( ...
    "candidateLabel", "Agent7250", ...
    "candidateKind", "benchmark", ...
    "trackingMSE", double(benchmark.trackingMse), ...
    "trackingMAE", double(benchmark.trackingMae), ...
    "actionL2", double(benchmark.actionL2), ...
    "saturationFraction", double(benchmark.saturationFraction), ...
    "deltaActionL2", double(benchmark.deltaActionL2), ...
    "finalStatus", "Reference");

if logical(options.evaluateReferenceCheckpoints)
    rows = appendReferenceIfAvailable(rows, "Seed22", "reproducible_seed", ...
        @getResidualSeed22CheckpointPath, options, resultsRoot, benchmark);
    rows = appendReferenceIfAvailable(rows, "Agent1850", "single_run", ...
        @getResidualFinalCheckpointPath, options, resultsRoot, benchmark);
end

meanMetrics = struct( ...
    "trackingMseMean", aggregateSummary.trackingMSEMean, ...
    "trackingMaeMean", aggregateSummary.trackingMAEMean, ...
    "actionL2Mean", aggregateSummary.actionL2Mean, ...
    "saturationFractionMean", aggregateSummary.saturationFractionMean, ...
    "deltaActionL2Mean", aggregateSummary.deltaActionL2Mean);
meanDecision = classifyBenchmarkAcceptance(meanMetrics, benchmark);
rows{end+1, 1} = struct( ...
    "candidateLabel", "CampaignMean", ...
    "candidateKind", "new_campaign_mean", ...
    "trackingMSE", double(aggregateSummary.trackingMSEMean), ...
    "trackingMAE", double(aggregateSummary.trackingMAEMean), ...
    "actionL2", double(aggregateSummary.actionL2Mean), ...
    "saturationFraction", double(aggregateSummary.saturationFractionMean), ...
    "deltaActionL2", double(aggregateSummary.deltaActionL2Mean), ...
    "finalStatus", string(meanDecision.status));

bestIdx = findBestSeedIndex(perSeedTable);
rows{end+1, 1} = struct( ...
    "candidateLabel", "BestCampaignSeed", ...
    "candidateKind", "new_campaign_best_seed", ...
    "trackingMSE", double(perSeedTable.trackingMSE(bestIdx)), ...
    "trackingMAE", double(perSeedTable.trackingMAE(bestIdx)), ...
    "actionL2", double(perSeedTable.actionL2(bestIdx)), ...
    "saturationFraction", double(perSeedTable.saturationFraction(bestIdx)), ...
    "deltaActionL2", double(perSeedTable.deltaActionL2(bestIdx)), ...
    "finalStatus", string(perSeedTable.finalStatus(bestIdx)));

referenceTable = struct2table(vertcat(rows{:}));
end

function rows = appendReferenceIfAvailable(rows, label, kind, resolver, options, resultsRoot, benchmark)
try
    checkpointPath = string(resolver());
catch
    return;
end
if strlength(checkpointPath) == 0 || ~isfile(checkpointPath)
    return;
end

referenceRoot = fullfile(resultsRoot, "reference_tests", char(label));
ensureDirectoryExists(referenceRoot);
runCheckpointTest(checkpointPath, options.finalTestEpisodes, false, struct( ...
    "resultsRoot", referenceRoot));
runDir = findNewestSubdir(referenceRoot);
analysis = analyzeExperimentRun(string(runDir));
decision = classifyBenchmarkAcceptance(analysis.episodeSummary, benchmark);

rows{end+1, 1} = struct( ...
    "candidateLabel", string(label), ...
    "candidateKind", string(kind), ...
    "trackingMSE", double(analysis.episodeSummary.trackingMseMean), ...
    "trackingMAE", double(analysis.episodeSummary.trackingMaeMean), ...
    "actionL2", double(analysis.episodeSummary.actionL2Mean), ...
    "saturationFraction", double(analysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2", double(analysis.episodeSummary.deltaActionL2Mean), ...
    "finalStatus", string(decision.status));
end

function createComparisonFigure(referenceTable, figurePath)
metrics = { ...
    "trackingMSE", "trackingMSE"; ...
    "trackingMAE", "trackingMAE"; ...
    "actionL2", "actionL2"; ...
    "saturationFraction", "saturationFraction"; ...
    "deltaActionL2", "deltaActionL2"};
labels = string(referenceTable.candidateLabel);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 900]);
tiledlayout(f, 2, 3, "TileSpacing", "compact", "Padding", "compact");
for i = 1:size(metrics, 1)
    nexttile;
    values = double(referenceTable.(metrics{i, 1}));
    bar(categorical(labels), values, 0.62, ...
        "FaceColor", [0.12 0.47 0.71], "FaceAlpha", 0.85);
    grid on
    ylabel(metrics{i, 2});
    title(metrics{i, 2});
end
nexttile;
axis off
text(0, 0.7, "Final test comparison", "FontWeight", "bold", "FontSize", 12);
text(0, 0.5, "Lower is better for all metrics.", "FontSize", 10);
text(0, 0.35, "Agent7250 remains the official benchmark.", "FontSize", 10);

ensureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function summary = summarizeCampaign(perSeedTable, benchmark)
summary = struct();
summary.numSeeds = height(perSeedTable);
summary.trackingMSEMean = mean(double(perSeedTable.trackingMSE), "omitnan");
summary.trackingMSEStd = std(double(perSeedTable.trackingMSE), 0, "omitnan");
summary.trackingMAEMean = mean(double(perSeedTable.trackingMAE), "omitnan");
summary.trackingMAEStd = std(double(perSeedTable.trackingMAE), 0, "omitnan");
summary.actionL2Mean = mean(double(perSeedTable.actionL2), "omitnan");
summary.actionL2Std = std(double(perSeedTable.actionL2), 0, "omitnan");
summary.saturationFractionMean = mean(double(perSeedTable.saturationFraction), "omitnan");
summary.saturationFractionStd = std(double(perSeedTable.saturationFraction), 0, "omitnan");
summary.deltaActionL2Mean = mean(double(perSeedTable.deltaActionL2), "omitnan");
summary.deltaActionL2Std = std(double(perSeedTable.deltaActionL2), 0, "omitnan");
summary.conditionACount = sum(string(perSeedTable.finalStatus) == "ConditionA");
summary.conditionBCount = sum(string(perSeedTable.finalStatus) == "ConditionB");
summary.rejectedCount = sum(string(perSeedTable.finalStatus) == "Rejected");
summary.bestSeedIndex = findBestSeedIndex(perSeedTable);
summary.bestSeed = double(perSeedTable.seed(summary.bestSeedIndex));
summary.bestSeedCheckpointPath = string(perSeedTable.selectedCheckpointPath(summary.bestSeedIndex));
summary.bestSeedEpisode = double(perSeedTable.selectedCheckpointEpisode(summary.bestSeedIndex));
summary.aggregateDecision = classifyBenchmarkAcceptance(struct( ...
    "trackingMseMean", summary.trackingMSEMean, ...
    "saturationFractionMean", summary.saturationFractionMean, ...
    "actionL2Mean", summary.actionL2Mean, ...
    "deltaActionL2Mean", summary.deltaActionL2Mean), benchmark);
end

function idx = findBestSeedIndex(perSeedTable)
statusRank = arrayfun(@mapStatusToRank, string(perSeedTable.finalStatus));
metricMatrix = [ ...
    -statusRank(:), ...
    double(perSeedTable.trackingMSE(:)), ...
    double(perSeedTable.saturationFraction(:)), ...
    double(perSeedTable.actionL2(:)), ...
    double(perSeedTable.deltaActionL2(:))];
[~, order] = sortrows(metricMatrix);
idx = order(1);
end

function textValue = buildSummaryText(results)
summary = results.aggregateSummary;
lines = strings(0, 1);
lines(end+1) = "Residual Lift seeded documented retrain";
lines(end+1) = "=======================================";
lines(end+1) = "";
lines(end+1) = sprintf("Results root: %s", string(results.resultsRoot));
lines(end+1) = sprintf("Base label: %s", string(results.options.baseLabel));
lines(end+1) = sprintf("Base checkpoint: %s", string(results.options.baseCheckpointPath));
lines(end+1) = sprintf("Residual scale alpha_res = %.3f", double(results.options.residualScale));
lines(end+1) = sprintf("Seeds: %s", mat2str(results.options.seeds));
lines(end+1) = sprintf("Training episodes per seed: %d", round(results.options.trainingEpisodes));
lines(end+1) = sprintf("Checkpoint save every: %d", round(results.options.trainingSaveEvery));
lines(end+1) = sprintf("Audit: %d fast / %d full / topK=%d", ...
    round(results.options.auditFastSimulations), ...
    round(results.options.auditFullSimulations), ...
    round(results.options.auditTopK));
lines(end+1) = sprintf("Final test episodes per selected checkpoint: %d", ...
    round(results.options.finalTestEpisodes));
lines(end+1) = "Scope: software/simulation only; prerecorded dataset, simulated motors, no hardware ports.";
lines(end+1) = "";
lines(end+1) = sprintf("ConditionA count: %d", summary.conditionACount);
lines(end+1) = sprintf("ConditionB count: %d", summary.conditionBCount);
lines(end+1) = sprintf("Rejected count: %d", summary.rejectedCount);
lines(end+1) = sprintf("Aggregate status: %s", string(summary.aggregateDecision.status));
lines(end+1) = sprintf("Best seed: %d at episode %d", summary.bestSeed, summary.bestSeedEpisode);
lines(end+1) = "";
lines(end+1) = sprintf("trackingMSE mean +- std = %.6f +- %.6f", ...
    summary.trackingMSEMean, summary.trackingMSEStd);
lines(end+1) = sprintf("trackingMAE mean +- std = %.6f +- %.6f", ...
    summary.trackingMAEMean, summary.trackingMAEStd);
lines(end+1) = sprintf("actionL2 mean +- std = %.6f +- %.6f", ...
    summary.actionL2Mean, summary.actionL2Std);
lines(end+1) = sprintf("saturationFraction mean +- std = %.6f +- %.6f", ...
    summary.saturationFractionMean, summary.saturationFractionStd);
lines(end+1) = sprintf("deltaActionL2 mean +- std = %.6f +- %.6f", ...
    summary.deltaActionL2Mean, summary.deltaActionL2Std);
lines(end+1) = "";
lines(end+1) = "Per-seed selected checkpoints:";
for i = 1:height(results.perSeedTable)
    row = results.perSeedTable(i, :);
    lines(end+1) = sprintf( ...
        "seed %d | episode %d | status %s | trackingMSE %.6f | actionL2 %.6f | visual %s | checkpoint %s | reason %s", ...
        row.seed, row.selectedCheckpointEpisode, string(row.finalStatus), ...
        row.trackingMSE, row.actionL2, string(row.visualTestFigurePath), ...
        string(row.selectedCheckpointPath), string(row.selectionReason)); %#ok<AGROW>
end
textValue = strjoin(lines, newline);
end

function markdownText = buildFigureIndexMarkdown(results)
lines = strings(0, 1);
lines(end+1) = "# Residual retrain figures";
lines(end+1) = "";
lines(end+1) = sprintf("- Results root: `%s`", string(results.resultsRoot));
lines(end+1) = "- Scope: software/simulation only; no hardware ports are touched.";
lines(end+1) = "";
lines(end+1) = "## Campaign figures";
lines(end+1) = "";
lines(end+1) = "| Figure | Path |";
lines(end+1) = "| --- | --- |";
lines(end+1) = sprintf("| Training overview | `%s` |", string(results.figurePaths.trainingOverview));
lines(end+1) = sprintf("| Reference comparison | `%s` |", string(results.figurePaths.comparison));
lines(end+1) = "";
lines(end+1) = "## Per-seed figures";
lines(end+1) = "";
lines(end+1) = "| Seed | Training | Selected checkpoint visual test |";
lines(end+1) = "| --- | --- | --- |";
for i = 1:height(results.perSeedTable)
    lines(end+1) = sprintf("| %d | `%s` | `%s` |", ...
        results.perSeedTable.seed(i), ...
        string(results.perSeedTable.trainingFigurePath(i)), ...
        string(results.perSeedTable.visualTestFigurePath(i)));
end
markdownText = strjoin(lines, newline);
end

function summary = getTrainingSummaryOrEmpty(trainingAnalysis)
summary = struct();
if isstruct(trainingAnalysis) && isfield(trainingAnalysis, "trainingSummary")
    summary = trainingAnalysis.trainingSummary;
end
end

function value = getStructField(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function createEmptyFigure(figurePath, message)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1000 500]);
axis off
text(0.5, 0.5, string(message), "HorizontalAlignment", "center", ...
    "Units", "normalized", "FontSize", 12);
ensureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function ensureParentDirectoryExists(filePath)
[parentDir, ~, ~] = fileparts(char(string(filePath)));
if strlength(string(parentDir)) > 0
    ensureDirectoryExists(parentDir);
end
end

function newestDir = findNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No subdirectories found in %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
newestDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function resultsRoot = resolveResultsRoot(requestedRoot, workspaceRoot)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    baseRoot = char(requestedRoot);
else
    baseRoot = fullfile(workspaceRoot, "Agentes", ...
        "residual_lift_seeded_retrain_documented", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
resultsRoot = makeUniqueDirectoryPath(baseRoot);
end

function uniquePath = makeUniqueDirectoryPath(basePath)
basePath = char(string(basePath));
if ~exist(basePath, "dir")
    uniquePath = basePath;
    return;
end

for i = 1:999
    candidatePath = sprintf("%s_%02d", basePath, i);
    if ~exist(candidatePath, "dir")
        uniquePath = candidatePath;
        return;
    end
end
error("Could not create a unique results directory for %s", basePath);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end
