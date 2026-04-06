function results = runResidualStopbandCampaignCore(mode, options)
%runResidualStopbandCampaignCore executes stop-band discovery/confirmation campaigns.

arguments
    mode (1, 1) string {mustBeMember(mode, ["discovery", "confirmation"])}
    options = struct()
end

options = normalizeCampaignOptions(mode, options);

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
projectRoot = fileparts(matlabRoot);

cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

benchmark = getAgent7250Benchmark();
referenceCheckpoints = resolveReferenceCheckpoints();

if ~exist(options.resultsRoot, "dir")
    mkdir(options.resultsRoot);
end

[docsRoot, summaryFiguresDir] = resolveArtifactDirs(projectRoot, options);

seedRows = cell(numel(options.seeds), 1);
seedResults = cell(numel(options.seeds), 1);

for i = 1:numel(options.seeds)
    seedValue = double(options.seeds(i));
    [seedRows{i}, seedResults{i}] = runSeedCampaign( ...
        mode, seedValue, options, benchmark, summaryFiguresDir);
end

perSeedTable = struct2table(vertcat(seedRows{:}));
summary = summarizeResidualStopbandCampaign(perSeedTable, benchmark, struct( ...
    "roundToEpisode", options.roundToEpisode, ...
    "fallbackEpisode", options.stopBandFallbackEpisode, ...
    "clampRange", options.stopBandClampRange, ...
    "mode", mode));

referenceTable = evaluateReferenceCandidates( ...
    mode, options, benchmark, referenceCheckpoints, perSeedTable, summary);

trainingFigurePath = fullfile(summaryFiguresDir, char(options.trainingFigureName));
winnerFigurePath = fullfile(summaryFiguresDir, char(options.winnerFigureName));
comparisonFigurePath = fullfile(summaryFiguresDir, char(options.comparisonFigureName));

createCampaignTrainingFigure(perSeedTable, trainingFigurePath, mode);
createWinnerEpisodeFigure(perSeedTable, summary, winnerFigurePath, mode);
createReferenceComparisonFigure(referenceTable, comparisonFigurePath, mode);

results = struct();
results.mode = mode;
results.resultsRoot = string(options.resultsRoot);
results.docsRoot = string(docsRoot);
results.benchmark = benchmark;
results.referenceCheckpoints = referenceCheckpoints;
results.options = options;
results.perSeedTable = perSeedTable;
results.summary = summary;
results.referenceTable = referenceTable;
results.seedResults = seedResults;
results.figurePaths = struct( ...
    "training", string(trainingFigurePath), ...
    "winnerEpisodes", string(winnerFigurePath), ...
    "comparison", string(comparisonFigurePath));

summaryBaseName = "residual_lift_stopband_" + mode + "_summary";
writetable(perSeedTable, fullfile(options.resultsRoot, summaryBaseName + ".csv"));
writetable(referenceTable, fullfile(options.resultsRoot, "reference_comparison.csv"));
writeTextFile(fullfile(options.resultsRoot, summaryBaseName + ".txt"), ...
    buildCampaignSummaryText(results));

save(fullfile(options.resultsRoot, "residual_lift_stopband_" + mode + "_results.mat"), ...
    "results", "perSeedTable", "summary", "referenceTable", "options");

if logical(options.generateReport)
    reportPaths = generateCampaignReport(results, options, docsRoot);
    results.reportPaths = reportPaths;
    save(fullfile(options.resultsRoot, "residual_lift_stopband_" + mode + "_results.mat"), ...
        "results", "perSeedTable", "summary", "referenceTable", "options");
end
end

function options = normalizeCampaignOptions(mode, options)
commonDefaults = struct( ...
    "baseCheckpointPath", getAgent7250CheckpointPath(), ...
    "baseLabel", "Agent7250", ...
    "residualScale", 0.20, ...
    "residualHiddenUnits", 32, ...
    "explorationStd", 0.02, ...
    "explorationStdMin", 0.002, ...
    "explorationStdDecayRate", 1e-4, ...
    "resetExperienceBufferBeforeTraining", false, ...
    "trainingPlots", "none", ...
    "flagSaveTraining", true, ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 5, ...
    "comparisonSimulations", 50, ...
    "comparisonPlotEpisodes", false, ...
    "roundToEpisode", 250, ...
    "stopBandFallbackEpisode", 2000, ...
    "stopBandClampRange", [1750 3000], ...
    "docsRoot", "", ...
    "generateReport", true, ...
    "compileReport", true, ...
    "dateTag", string(datetime("today", "Format", "yyyyMMdd")), ...
    "resultsRoot", "");

if mode == "discovery"
    modeDefaults = struct( ...
        "seeds", [11 22 33 44 55], ...
        "trainingEpisodes", 10000, ...
        "trainingSaveEvery", 250, ...
        "episodeSaveFreq", 250, ...
        "stopBandEpisode", NaN, ...
        "stopBandWindow", []);
else
    modeDefaults = struct( ...
        "seeds", [66 77 88 99 111], ...
        "trainingEpisodes", NaN, ...
        "trainingSaveEvery", 100, ...
        "episodeSaveFreq", 100, ...
        "stopBandEpisode", NaN, ...
        "stopBandWindow", [], ...
        "discoveryResultsPath", "");
end

options = fillMissingFields(options, commonDefaults);
options = fillMissingFields(options, modeDefaults);

options.baseCheckpointPath = string(options.baseCheckpointPath);
options.baseLabel = string(options.baseLabel);
options.trainingPlots = string(options.trainingPlots);
options.docsRoot = string(options.docsRoot);
options.dateTag = string(options.dateTag);
options.seeds = double(options.seeds(:))';
options.auditFastSimulations = max(2, double(options.auditFastSimulations));
options.auditFullSimulations = max(2, double(options.auditFullSimulations));
options.comparisonSimulations = max(2, double(options.comparisonSimulations));

if mode == "confirmation"
    [stopBandEpisode, stopBandWindow, discoveryResultsPath] = resolveConfirmationStopBand(options);
    options.stopBandEpisode = double(stopBandEpisode);
    options.stopBandWindow = double(stopBandWindow);
    options.discoveryResultsPath = string(discoveryResultsPath);
    if ~isfinite(double(options.trainingEpisodes))
        options.trainingEpisodes = double(options.stopBandEpisode) + 500;
    end
else
    options.stopBandEpisode = double(options.stopBandEpisode);
    options.stopBandWindow = double(options.stopBandWindow);
end

if strlength(options.resultsRoot) == 0
    options.resultsRoot = resolveDefaultResultsRoot(mode);
end
options.resultsRoot = char(options.resultsRoot);

options.trainingFigureName = "residual_stopband_" + mode + "_training_overview_" + options.dateTag + ".png";
options.winnerFigureName = "residual_stopband_" + mode + "_winner_episodes_" + options.dateTag + ".png";
options.comparisonFigureName = "residual_stopband_" + mode + "_comparison_" + options.dateTag + ".png";
if mode == "discovery"
    options.reportBaseName = "reporte_descubrimiento_stopband_residual_" + options.dateTag;
else
    options.reportBaseName = "reporte_confirmacion_stopband_residual_" + options.dateTag;
end
end

function [seedRow, seedResult] = runSeedCampaign(mode, seedValue, options, benchmark, summaryFiguresDir)
seedLabel = sprintf("seed_%03d", round(seedValue));
seedRoot = fullfile(options.resultsRoot, seedLabel);
if ~exist(seedRoot, "dir")
    mkdir(seedRoot);
end
seedFigureDir = fullfile(seedRoot, "figures");
if ~exist(seedFigureDir, "dir")
    mkdir(seedFigureDir);
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
    "auditSamplingPolicy", struct("mode", "all"), ...
    "alwaysRunVisualTest", false, ...
    "resultsRoot", string(seedRoot));

pilotResults = run_residual_lift_pilot(pilotOptions);

trainingFigurePath = fullfile(seedFigureDir, "training_progress.png");
trainingAnalysis = analyzeExperimentRun(string(pilotResults.trainingRunDir), string(trainingFigurePath));
auditFigurePath = fullfile(seedFigureDir, "checkpoint_evolution.png");
createSeedAuditFigure(pilotResults.auditResults.phaseATable, benchmark, auditFigurePath);

    [selectedAuditRow, selectionMeta] = selectAuditRow(mode, pilotResults.auditResults.phaseBTable, options);
    visualTestRoot = fullfile(seedRoot, "selected_checkpoint_test");
    runCheckpointTest(string(selectedAuditRow.checkpointPath), ...
        options.comparisonSimulations, logical(options.comparisonPlotEpisodes), struct( ...
        "resultsRoot", visualTestRoot));
    visualTestRunDir = findNewestSubdir(visualTestRoot);
    visualAnalysis = analyzeExperimentRun(string(visualTestRunDir));
    visualDecision = classifyBenchmarkAcceptance(visualAnalysis.episodeSummary, benchmark);

    seedRow = struct( ...
        "seed", double(seedValue), ...
        "seedLabel", string(seedLabel), ...
        "trainingRunDir", string(pilotResults.trainingRunDir), ...
        "trainingFigurePath", string(trainingFigurePath), ...
        "auditFigurePath", string(auditFigurePath), ...
        "phaseBTopCheckpointPath", string(pilotResults.bestAuditRow.checkpointPath), ...
        "phaseBTopCheckpointEpisode", double(pilotResults.bestAuditRow.checkpointEpisode), ...
        "selectedCheckpointPath", string(selectedAuditRow.checkpointPath), ...
        "selectedCheckpointEpisode", double(selectedAuditRow.checkpointEpisode), ...
        "selectedWasPhaseBTop", string(selectedAuditRow.checkpointPath) == string(pilotResults.bestAuditRow.checkpointPath), ...
        "selectionReason", string(selectionMeta.reason), ...
        "selectedInStopBandWindow", logical(selectionMeta.selectedInStopBandWindow), ...
        "windowReferenceEpisode", double(selectionMeta.windowReferenceEpisode), ...
        "windowReferencePath", string(selectionMeta.windowReferencePath), ...
        "visualTestRunDir", string(visualTestRunDir), ...
        "finalStatus", string(visualDecision.status), ...
        "finalTrackingMse", double(visualAnalysis.episodeSummary.trackingMseMean), ...
        "finalTrackingMae", double(visualAnalysis.episodeSummary.trackingMaeMean), ...
        "finalActionL2", double(visualAnalysis.episodeSummary.actionL2Mean), ...
        "finalSaturationFraction", double(visualAnalysis.episodeSummary.saturationFractionMean), ...
        "finalDeltaActionL2", double(visualAnalysis.episodeSummary.deltaActionL2Mean), ...
        "auditTrackingMse", double(selectedAuditRow.trackingMseMean), ...
        "auditTrackingMae", double(selectedAuditRow.trackingMaeMean), ...
        "auditActionL2", double(selectedAuditRow.actionL2Mean), ...
        "auditSaturationFraction", double(selectedAuditRow.saturationFractionMean), ...
        "auditDeltaActionL2", double(selectedAuditRow.deltaActionL2Mean), ...
        "auditStatus", string(selectedAuditRow.benchmarkStatus), ...
        "meetsConditionA", logical(visualDecision.meetsConditionA), ...
        "meetsConditionB", logical(visualDecision.meetsConditionB), ...
        "trainingAverageRewardFinal", double(trainingAnalysis.trainingSummary.averageRewardFinal), ...
        "bestAverageReward", double(trainingAnalysis.trainingSummary.bestAverageReward), ...
        "bestAverageRewardEpisode", double(trainingAnalysis.trainingSummary.bestAverageRewardEpisode), ...
        "totalAgentStepsFinal", double(trainingAnalysis.trainingSummary.totalAgentStepsFinal));

    seedResult = struct( ...
        "pilotResults", pilotResults, ...
        "trainingAnalysis", trainingAnalysis, ...
        "selectedAuditRow", selectedAuditRow, ...
        "selectionMeta", selectionMeta, ...
        "visualAnalysis", visualAnalysis, ...
        "visualDecision", visualDecision, ...
        "summaryFiguresDir", string(summaryFiguresDir));
end

function [selectedAuditRow, selectionMeta] = selectAuditRow(mode, phaseBTable, options)
phaseBRows = table2struct(phaseBTable);
topRow = phaseBRows(1);

selectionMeta = struct( ...
    "reason", "", ...
    "selectedInStopBandWindow", false, ...
    "windowReferenceEpisode", NaN, ...
    "windowReferencePath", "");

if mode == "discovery"
    selectedAuditRow = topRow;
    selectionMeta.reason = "phaseB_top1";
    return;
end

windowValue = double(options.stopBandWindow);
episodes = double([phaseBRows.checkpointEpisode]);
statuses = string({phaseBRows.benchmarkStatus});
inWindowMask = episodes >= windowValue(1) & episodes <= windowValue(2);
acceptedMask = statuses == "ConditionA" | statuses == "ConditionB";

acceptedWindowIdx = find(inWindowMask & acceptedMask);
if ~isempty(acceptedWindowIdx)
    [~, order] = sort(episodes(acceptedWindowIdx), "ascend");
    winnerIdx = acceptedWindowIdx(order(1));
    selectedAuditRow = phaseBRows(winnerIdx);
    selectionMeta.reason = "earliest_accepted_checkpoint_inside_stopband_window";
    selectionMeta.selectedInStopBandWindow = true;
    selectionMeta.windowReferenceEpisode = double(selectedAuditRow.checkpointEpisode);
    selectionMeta.windowReferencePath = string(selectedAuditRow.checkpointPath);
    return;
end

windowIdx = find(inWindowMask);
if isempty(windowIdx)
    selectedAuditRow = topRow;
    selectionMeta.reason = "no_phaseB_checkpoint_inside_stopband_window";
    return;
end

windowReferenceRow = phaseBRows(windowIdx(1));
selectionMeta.windowReferenceEpisode = double(windowReferenceRow.checkpointEpisode);
selectionMeta.windowReferencePath = string(windowReferenceRow.checkpointPath);

topInsideWindow = episodes(1) >= windowValue(1) && episodes(1) <= windowValue(2);
if topInsideWindow
    selectedAuditRow = topRow;
    selectionMeta.reason = "phaseB_top1_inside_stopband_window";
    selectionMeta.selectedInStopBandWindow = true;
    return;
end

improvesTracking = double(topRow.trackingMseMean) < double(windowReferenceRow.trackingMseMean);
notWorseEffort = double(topRow.actionL2Mean) <= double(windowReferenceRow.actionL2Mean);
notWorseSaturation = double(topRow.saturationFractionMean) <= double(windowReferenceRow.saturationFractionMean);

if improvesTracking && notWorseEffort && notWorseSaturation
    selectedAuditRow = topRow;
    selectionMeta.reason = "outside_window_promoted_by_tracking_without_effort_or_saturation_regression";
    selectionMeta.selectedInStopBandWindow = false;
else
    selectedAuditRow = windowReferenceRow;
    selectionMeta.reason = "fallback_to_best_phaseB_checkpoint_inside_stopband_window";
    selectionMeta.selectedInStopBandWindow = true;
end
end

function referenceTable = evaluateReferenceCandidates(mode, options, benchmark, referenceCheckpoints, perSeedTable, summary)
referenceRows = cell(5, 1);

referenceRows{1} = struct( ...
    "candidateLabel", "Agent7250", ...
    "candidateKind", "benchmark", ...
    "trackingMseMean", double(benchmark.trackingMse), ...
    "trackingMaeMean", double(benchmark.trackingMae), ...
    "actionL2Mean", double(benchmark.actionL2), ...
    "saturationFractionMean", double(benchmark.saturationFraction), ...
    "deltaActionL2Mean", double(benchmark.deltaActionL2), ...
    "benchmarkStatus", "Reference");

referenceRows{2} = runReferenceCandidate("Seed22", "reproducible_seed", referenceCheckpoints.seed22, options);
referenceRows{3} = runReferenceCandidate("Agent1850", "single_run", referenceCheckpoints.agent1850, options);

bestSeedIdx = findBestCampaignSeed(perSeedTable);
referenceRows{4} = struct( ...
    "candidateLabel", "CampaignMean", ...
    "candidateKind", mode + "_mean", ...
    "trackingMseMean", double(summary.trackingMseMean), ...
    "trackingMaeMean", double(summary.trackingMaeMean), ...
    "actionL2Mean", double(summary.actionL2Mean), ...
    "saturationFractionMean", double(summary.saturationFractionMean), ...
    "deltaActionL2Mean", double(summary.deltaActionL2Mean), ...
    "benchmarkStatus", string(summary.aggregateBenchmarkDecision.status));

referenceRows{5} = struct( ...
    "candidateLabel", "BestCampaignSeed", ...
    "candidateKind", mode + "_best_seed", ...
    "trackingMseMean", double(perSeedTable.finalTrackingMse(bestSeedIdx)), ...
    "trackingMaeMean", double(perSeedTable.finalTrackingMae(bestSeedIdx)), ...
    "actionL2Mean", double(perSeedTable.finalActionL2(bestSeedIdx)), ...
    "saturationFractionMean", double(perSeedTable.finalSaturationFraction(bestSeedIdx)), ...
    "deltaActionL2Mean", double(perSeedTable.finalDeltaActionL2(bestSeedIdx)), ...
    "benchmarkStatus", string(perSeedTable.finalStatus(bestSeedIdx)));

referenceTable = struct2table(vertcat(referenceRows{:}));
end

function row = runReferenceCandidate(label, kind, checkpointPath, options)
resultsRoot = fullfile(options.resultsRoot, "reference_tests", char(label));
if ~exist(resultsRoot, "dir")
    mkdir(resultsRoot);
end

runCheckpointTest(string(checkpointPath), options.comparisonSimulations, false, struct( ...
    "resultsRoot", resultsRoot));
runDir = findNewestSubdir(resultsRoot);
analysis = analyzeExperimentRun(string(runDir));
benchmarkDecision = classifyBenchmarkAcceptance(analysis.episodeSummary);

row = struct( ...
    "candidateLabel", string(label), ...
    "candidateKind", string(kind), ...
    "trackingMseMean", double(analysis.episodeSummary.trackingMseMean), ...
    "trackingMaeMean", double(analysis.episodeSummary.trackingMaeMean), ...
    "actionL2Mean", double(analysis.episodeSummary.actionL2Mean), ...
    "saturationFractionMean", double(analysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2Mean", double(analysis.episodeSummary.deltaActionL2Mean), ...
    "benchmarkStatus", string(benchmarkDecision.status));
end

function idx = findBestCampaignSeed(perSeedTable)
statusRank = arrayfun(@mapStatusToRank, string(perSeedTable.finalStatus));
metricMatrix = [ ...
    -statusRank(:), ...
    double(perSeedTable.finalTrackingMse(:)), ...
    double(perSeedTable.finalSaturationFraction(:)), ...
    double(perSeedTable.finalDeltaActionL2(:)), ...
    double(perSeedTable.finalActionL2(:))];
[~, order] = sortrows(metricMatrix);
idx = order(1);
end

function [docsRoot, summaryFiguresDir] = resolveArtifactDirs(projectRoot, options)
if strlength(options.docsRoot) > 0
    docsRoot = char(options.docsRoot);
else
    docsRoot = fullfile(projectRoot, "docs", "td3_training_report");
end
if logical(options.generateReport)
    summaryFiguresDir = fullfile(docsRoot, "figures");
else
    summaryFiguresDir = fullfile(options.resultsRoot, "figures");
end
if ~exist(docsRoot, "dir")
    mkdir(docsRoot);
end
if ~exist(summaryFiguresDir, "dir")
    mkdir(summaryFiguresDir);
end
end

function rootDir = resolveDefaultResultsRoot(mode)
srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
rootDir = fullfile( ...
    repoRoot, "Agentes", "residual_lift_stopband_" + mode, ...
    string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end

function refs = resolveReferenceCheckpoints()
refs = struct( ...
    "seed22", string(getResidualSeed22CheckpointPath()), ...
    "agent1850", string(getResidualFinalCheckpointPath()));
end

function [stopBandEpisode, stopBandWindow, discoveryResultsPath] = resolveConfirmationStopBand(options)
stopBandEpisode = double(options.stopBandEpisode);
stopBandWindow = double(options.stopBandWindow);
discoveryResultsPath = string(options.discoveryResultsPath);

if isfinite(stopBandEpisode)
    if isempty(stopBandWindow)
        stopBandWindow = [stopBandEpisode - 250, stopBandEpisode + 250];
    end
    return;
end

if strlength(discoveryResultsPath) == 0
    discoveryResultsPath = inferLatestDiscoveryResultsPath();
end

if strlength(discoveryResultsPath) == 0 || ~isfile(discoveryResultsPath)
    error("Could not resolve a discovery results file to infer stop-band confirmation defaults.");
end

data = load(discoveryResultsPath, "results");
if ~isfield(data, "results") || ~isfield(data.results, "summary")
    error("Discovery results file does not contain a usable summary: %s", discoveryResultsPath);
end

stopBandEpisode = double(data.results.summary.stopBandEpisode);
stopBandWindow = double(data.results.summary.stopBandWindow);
end

function discoveryResultsPath = inferLatestDiscoveryResultsPath()
srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
rootDir = fullfile(repoRoot, "Agentes", "residual_lift_stopband_discovery");

discoveryResultsPath = "";
if ~isfolder(rootDir)
    return;
end

matFiles = dir(fullfile(rootDir, "*", "residual_lift_stopband_discovery_results.mat"));
if isempty(matFiles)
    return;
end

[~, idx] = max([matFiles.datenum]);
discoveryResultsPath = string(fullfile(matFiles(idx).folder, matFiles(idx).name));
end

function createSeedAuditFigure(phaseATable, benchmark, figurePath)
episodes = double(phaseATable.checkpointEpisode);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plotMetricTrace(episodes, double(phaseATable.trackingMseMean), benchmark.trackingMse, "trackingMSE");
nexttile;
plotMetricTrace(episodes, double(phaseATable.actionL2Mean), benchmark.actionL2, "actionL2");
nexttile;
plotMetricTrace(episodes, double(phaseATable.saturationFractionMean), benchmark.saturationFraction, "saturationFraction");
nexttile;
plotMetricTrace(episodes, double(phaseATable.deltaActionL2Mean), benchmark.deltaActionL2, "deltaActionL2");

exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function plotMetricTrace(episodes, metricValues, benchmarkValue, titleText)
plot(episodes, metricValues, "-o", "Color", [0.00 0.45 0.74], "LineWidth", 1.6, "MarkerSize", 4);
hold on
yline(benchmarkValue, "--", "Color", [0.85 0.33 0.10], "LineWidth", 1.5);
hold off
grid on
xlabel("Checkpoint episode")
ylabel(titleText)
title(titleText)
legend({"campaign", "Agent7250"}, "Location", "best", "Box", "off");
end

function createCampaignTrainingFigure(perSeedTable, figurePath, mode)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
t = tiledlayout(f, 2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile(t);
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
    plot(double(data.trainingInfo.EpisodeIndex(:)), double(data.trainingInfo.AverageReward(:)), ...
        "LineWidth", 1.4, "DisplayName", sprintf("seed %d", perSeedTable.seed(i)));
end
hold off
grid on
xlabel("Episode")
ylabel("AverageReward")
title("AverageReward trajectory by seed")
legend("Location", "bestoutside")

nexttile(t);
bar(categorical(string(perSeedTable.seed)), double(perSeedTable.bestAverageRewardEpisode), ...
    "FaceColor", [0.12 0.47 0.71], "FaceAlpha", 0.85);
grid on
xlabel("Seed")
ylabel("Best AverageReward episode")
title("Episode of best AverageReward by seed")

title(t, sprintf("Residual stop-band %s: training overview", mode), "FontWeight", "bold");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function createWinnerEpisodeFigure(perSeedTable, summary, figurePath, mode)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 760]);
t = tiledlayout(f, 1, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile(t);
hold on
windowValue = double(summary.stopBandWindow);
patch([windowValue(1) windowValue(2) windowValue(2) windowValue(1)], ...
    [0.5 0.5 height(perSeedTable)+0.5 height(perSeedTable)+0.5], ...
    [0.90 0.95 1.00], "EdgeColor", "none", "FaceAlpha", 0.45);
for i = 1:height(perSeedTable)
    statusValue = string(perSeedTable.finalStatus(i));
    switch statusValue
        case "ConditionA"
            markerColor = [0.13 0.55 0.13];
        case "ConditionB"
            markerColor = [0.93 0.69 0.13];
        case "Rejected"
            markerColor = [0.80 0.10 0.10];
        otherwise
            markerColor = [0.40 0.40 0.40];
    end
    scatter(double(perSeedTable.selectedCheckpointEpisode(i)), i, 72, "filled", ...
        "MarkerFaceColor", markerColor);
end
xline(summary.stopBandEpisode, "--", "Color", [0.00 0.45 0.74], "LineWidth", 1.6);
hold off
yticks(1:height(perSeedTable));
yticklabels("seed " + string(perSeedTable.seed));
xlabel("Selected checkpoint episode")
ylabel("Seed")
title("Selected final checkpoint by seed")
grid on

nexttile(t);
statusCounts = [summary.conditionACount, summary.conditionBCount, summary.rejectedCount];
bar(categorical(["ConditionA", "ConditionB", "Rejected"]), statusCounts, 0.6, ...
    "FaceColor", [0.20 0.55 0.80], "FaceAlpha", 0.85);
grid on
ylabel("Count")
title("Final status distribution")

title(t, sprintf("Residual stop-band %s: episode winners and acceptance", mode), ...
    "FontWeight", "bold");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function createReferenceComparisonFigure(referenceTable, figurePath, mode)
labels = string(referenceTable.candidateLabel);
metrics = { ...
    "trackingMseMean", "trackingMSE"; ...
    "actionL2Mean", "actionL2"; ...
    "saturationFractionMean", "saturationFraction"; ...
    "deltaActionL2Mean", "deltaActionL2"};

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

for i = 1:size(metrics, 1)
    nexttile;
    values = double(referenceTable.(metrics{i, 1}));
    b = bar(categorical(labels), values, 0.6, "FaceColor", [0.12 0.47 0.71]);
    b.FaceAlpha = 0.85;
    ylabel(metrics{i, 2});
    title(metrics{i, 2});
    grid on
end

sgtitle(sprintf("Residual stop-band %s: comparison against active references", mode), ...
    "FontWeight", "bold");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function summaryText = buildCampaignSummaryText(results)
summary = results.summary;
lines = strings(0, 1);
lines(end+1) = "Residual stop-band campaign";
lines(end+1) = "==========================";
lines(end+1) = "";
lines(end+1) = sprintf("Mode: %s", results.mode);
lines(end+1) = sprintf("Results root: %s", results.resultsRoot);
lines(end+1) = sprintf("Base label: %s", results.options.baseLabel);
lines(end+1) = sprintf("Base checkpoint: %s", results.options.baseCheckpointPath);
lines(end+1) = sprintf("Seeds: %s", mat2str(results.options.seeds));
lines(end+1) = sprintf("Training episodes per seed: %d", results.options.trainingEpisodes);
lines(end+1) = sprintf("Save every: %d | episode save freq: %d", ...
    results.options.trainingSaveEvery, results.options.episodeSaveFreq);
lines(end+1) = "";
lines(end+1) = sprintf("Accepted seeds: %d/%d", summary.acceptedCount, summary.numSeeds);
lines(end+1) = sprintf("ConditionA count: %d", summary.conditionACount);
lines(end+1) = sprintf("ConditionB count: %d", summary.conditionBCount);
lines(end+1) = sprintf("Rejected count: %d", summary.rejectedCount);
lines(end+1) = sprintf("Derived stop-band episode: %d", summary.stopBandEpisode);
lines(end+1) = sprintf("Derived stop-band window: [%d, %d]", ...
    summary.stopBandWindow(1), summary.stopBandWindow(2));
lines(end+1) = sprintf("Stop-band rule: %s", string(summary.stopBandDecision.rule));
lines(end+1) = "";
lines(end+1) = sprintf("trackingMSE mean +- std = %.6f +- %.6f", ...
    summary.trackingMseMean, summary.trackingMseStd);
lines(end+1) = sprintf("trackingMAE mean +- std = %.6f +- %.6f", ...
    summary.trackingMaeMean, summary.trackingMaeStd);
lines(end+1) = sprintf("actionL2 mean +- std = %.6f +- %.6f", ...
    summary.actionL2Mean, summary.actionL2Std);
lines(end+1) = sprintf("saturationFraction mean +- std = %.6f +- %.6f", ...
    summary.saturationFractionMean, summary.saturationFractionStd);
lines(end+1) = sprintf("deltaActionL2 mean +- std = %.6f +- %.6f", ...
    summary.deltaActionL2Mean, summary.deltaActionL2Std);
lines(end+1) = sprintf("Aggregate benchmark status: %s", ...
    string(summary.aggregateBenchmarkDecision.status));
lines(end+1) = sprintf("Promotion supported: %d", summary.promotionSupported);
lines(end+1) = "";
lines(end+1) = sprintf("Conclusion: %s", string(summary.conclusion));
summaryText = strjoin(lines, newline);
end

function reportPaths = generateCampaignReport(results, options, docsRoot)
reportBaseName = char(options.reportBaseName);
reportTexPath = fullfile(docsRoot, [reportBaseName '.tex']);
reportPdfPath = fullfile(docsRoot, [reportBaseName '.pdf']);

texContent = buildCampaignReportTex(results, options);
writeTextFile(reportTexPath, texContent);

compiled = false;
if logical(options.compileReport)
    compiled = tryCompileLatexReport(docsRoot, reportTexPath);
end

reportPaths = struct( ...
    "tex", string(reportTexPath), ...
    "pdf", string(reportPdfPath), ...
    "compiled", logical(compiled));
end

function texContent = buildCampaignReportTex(results, ~)
summary = results.summary;
referenceTable = results.referenceTable;
perSeedTable = results.perSeedTable;

titleText = "Discovery";
purposeText = "descubrir en que banda de episodios aparece el mejor compromiso residual antes de la deriva";
if results.mode == "confirmation"
    titleText = "Confirmacion";
    purposeText = "confirmar si la banda propuesta por discovery se sostiene con seeds nuevas y permite promover una linea residual estable";
end

lines = strings(0, 1);
lines(end+1) = "\documentclass[11pt,a4paper]{article}";
lines(end+1) = "";
lines(end+1) = "\usepackage[utf8]{inputenc}";
lines(end+1) = "\usepackage[T1]{fontenc}";
lines(end+1) = "\usepackage[spanish,es-nodecimaldot]{babel}";
lines(end+1) = "\usepackage{amsmath}";
lines(end+1) = "\usepackage{booktabs}";
lines(end+1) = "\usepackage{tabularx}";
lines(end+1) = "\usepackage{array}";
lines(end+1) = "\usepackage{graphicx}";
lines(end+1) = "\usepackage{geometry}";
lines(end+1) = "\usepackage{xcolor}";
lines(end+1) = "\usepackage{float}";
lines(end+1) = "\usepackage{hyperref}";
lines(end+1) = "\geometry{margin=2.2cm}";
lines(end+1) = "\hypersetup{colorlinks=true, linkcolor=blue!50!black, urlcolor=blue!50!black}";
lines(end+1) = "\newcolumntype{Y}{>{\raggedright\arraybackslash}X}";
lines(end+1) = "";
lines(end+1) = "\title{Reporte de " + titleText + " de la stop-band residual\\\large Proyecto TD3 para protesis mioelectrica}";
lines(end+1) = "\author{C\'esar Zapata\\Research Laboratory in Artificial Intelligence and Computer Vision ``Alan Turing''}";
lines(end+1) = "\date{" + string(datetime("today", "Format", "dd-MM-yyyy")) + "}";
lines(end+1) = "\begin{document}";
lines(end+1) = "\maketitle";
lines(end+1) = "";
lines(end+1) = "\section*{Proposito}";
lines(end+1) = "Esta fase se diseno para " + purposeText + ". El benchmark oficial se mantiene fijo en \texttt{Agent7250}, mientras que \texttt{seed 22} y \texttt{Agent1850} siguen siendo las referencias residuales activas durante toda la campana.";
lines(end+1) = "";
lines(end+1) = "\section*{Configuracion}";
lines(end+1) = "\begin{table}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Configuracion principal de la campana}";
lines(end+1) = "\begin{tabularx}{\linewidth}{lY}";
lines(end+1) = "\toprule";
lines(end+1) = "Elemento & Valor \\";
lines(end+1) = "\midrule";
lines(end+1) = "Base congelada & \texttt{" + texEscape(char(results.options.baseLabel)) + "} \\";
lines(end+1) = "Checkpoint base & \texttt{" + texEscape(char(results.options.baseCheckpointPath)) + "} \\";
lines(end+1) = "Seeds & \texttt{" + texEscape(mat2str(results.options.seeds)) + "} \\";
lines(end+1) = "Episodios por seed & " + sprintf("%d", results.options.trainingEpisodes) + " \\";
lines(end+1) = "Guardado de checkpoints & cada " + sprintf("%d", results.options.trainingSaveEvery) + " episodios \\";
lines(end+1) = "Auditoria & " + sprintf("%d rapido / %d completo / topK=%d", results.options.auditFastSimulations, results.options.auditFullSimulations, results.options.auditTopK) + " \\";
lines(end+1) = "Stop-band derivada & " + sprintf("%d con ventana [%d, %d]", summary.stopBandEpisode, summary.stopBandWindow(1), summary.stopBandWindow(2)) + " \\";
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabularx}";
lines(end+1) = "\end{table}";
lines(end+1) = "";
lines(end+1) = "\section*{Evolucion por seed}";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(results.options.trainingFigureName)) + "}";
lines(end+1) = "\caption{Resumen de entrenamiento por seed para la campana de " + lower(titleText) + ".}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "\section*{Episodios ganadores y stop-band}";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(results.options.winnerFigureName)) + "}";
lines(end+1) = "\caption{Episodios seleccionados por seed y distribucion final de estados.}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "La regla de derivacion produjo una propuesta de stop-band en el episodio " + sprintf("%d", summary.stopBandEpisode) + ", con ventana [" + sprintf("%d", summary.stopBandWindow(1)) + ", " + sprintf("%d", summary.stopBandWindow(2)) + "]. La regla aplicada fue \texttt{" + texEscape(string(summary.stopBandDecision.rule)) + "} y el numero total de seeds aceptadas fue " + sprintf("%d de %d", summary.acceptedCount, summary.numSeeds) + ".";
lines(end+1) = "";
lines(end+1) = "\begin{table}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Resumen por seed}";
lines(end+1) = "\scriptsize";
lines(end+1) = "\begin{tabularx}{\linewidth}{>{\raggedright\arraybackslash}p{1.2cm} c c c c c >{\raggedright\arraybackslash}p{1.7cm}}";
lines(end+1) = "\toprule";
lines(end+1) = "Seed & Episodio & trackingMSE & actionL2 & saturation & deltaActionL2 & Estado \\";
lines(end+1) = "\midrule";
for i = 1:height(perSeedTable)
    lines(end+1) = sprintf("%d & %d & %.6f & %.6f & %.6f & %.6f & %s \\\\", ...
        perSeedTable.seed(i), perSeedTable.selectedCheckpointEpisode(i), ...
        perSeedTable.finalTrackingMse(i), perSeedTable.finalActionL2(i), ...
        perSeedTable.finalSaturationFraction(i), perSeedTable.finalDeltaActionL2(i), ...
        texEscape(string(perSeedTable.finalStatus(i))));
end
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabularx}";
lines(end+1) = "\end{table}";
lines(end+1) = "";
lines(end+1) = "\section*{Comparacion contra referencias activas}";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(results.options.comparisonFigureName)) + "}";
lines(end+1) = "\caption{Comparacion entre la campana, \texttt{Agent7250}, \texttt{seed 22} y \texttt{Agent1850}.}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "\begin{table}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Comparacion de candidatos y resumen agregado}";
lines(end+1) = "\scriptsize";
lines(end+1) = "\begin{tabularx}{\linewidth}{>{\raggedright\arraybackslash}p{1.8cm} c c c c c >{\raggedright\arraybackslash}p{1.6cm}}";
lines(end+1) = "\toprule";
lines(end+1) = "Candidato & trackingMSE & trackingMAE & actionL2 & saturation & deltaActionL2 & Estado \\";
lines(end+1) = "\midrule";
for i = 1:height(referenceTable)
    lines(end+1) = sprintf("%s & %.6f & %.6f & %.6f & %.6f & %.6f & %s \\\\", ...
        texEscape(string(referenceTable.candidateLabel(i))), ...
        referenceTable.trackingMseMean(i), referenceTable.trackingMaeMean(i), ...
        referenceTable.actionL2Mean(i), referenceTable.saturationFractionMean(i), ...
        referenceTable.deltaActionL2Mean(i), texEscape(string(referenceTable.benchmarkStatus(i))));
end
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabularx}";
lines(end+1) = "\end{table}";
lines(end+1) = "";
lines(end+1) = "\section*{Veredicto}";
lines(end+1) = "La media agregada de la campana fue: \texttt{trackingMSE = " + sprintf("%.6f", summary.trackingMseMean) + " +- " + sprintf("%.6f", summary.trackingMseStd) + "}, \texttt{actionL2 = " + sprintf("%.6f", summary.actionL2Mean) + " +- " + sprintf("%.6f", summary.actionL2Std) + "} y \texttt{saturationFraction = " + sprintf("%.6f", summary.saturationFractionMean) + " +- " + sprintf("%.6f", summary.saturationFractionStd) + "}.";
lines(end+1) = "";
lines(end+1) = "El estado agregado frente al benchmark fue \texttt{" + texEscape(string(summary.aggregateBenchmarkDecision.status)) + "} y la decision global de la fase queda fijada asi: " + string(summary.conclusion);
lines(end+1) = "";
lines(end+1) = "\section*{Punto actual del proyecto}";
if summary.promotionSupported
    lines(end+1) = "La campana confirma una banda residual suficientemente estable para seguir como linea activa. Aun asi, \texttt{Agent7250} se mantiene como benchmark oficial, mientras que la nueva stop-band pasa a ser la referencia operativa principal de la exploracion residual.";
else
    lines(end+1) = "La campana no desplaza el punto actual del proyecto. Se mantiene \texttt{Agent7250} como benchmark oficial, \texttt{seed 22} como referencia residual reproducible y \texttt{Agent1850} como mejor residual single-run historico.";
end
lines(end+1) = "";
lines(end+1) = "\end{document}";

texContent = strjoin(lines, newline);
end

function ok = tryCompileLatexReport(docsRoot, reportTexPath)
[~, reportName, reportExt] = fileparts(reportTexPath);
reportFile = [reportName reportExt];
command = sprintf('pdflatex -interaction=nonstopmode -halt-on-error %s', reportFile);

currentDir = pwd;
cleanup = onCleanup(@() cd(currentDir)); %#ok<NASGU>
cd(docsRoot);
status1 = system(command);
status2 = system(command);
ok = status1 == 0 && status2 == 0;
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

function out = fillMissingFields(in, defaults)
out = in;
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(out, fields{i}) || isempty(out.(fields{i}))
        out.(fields{i}) = defaults.(fields{i});
    end
end
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

function escaped = texEscape(value)
escaped = string(value);
escaped = replace(escaped, "\", "\textbackslash{}");
escaped = replace(escaped, "_", "\_");
escaped = replace(escaped, "%", "\%");
escaped = replace(escaped, "&", "\&");
escaped = replace(escaped, "#", "\#");
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end
