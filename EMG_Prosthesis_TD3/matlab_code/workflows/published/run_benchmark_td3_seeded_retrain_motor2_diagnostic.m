function results = run_benchmark_td3_seeded_retrain_motor2_diagnostic(options)
%run_benchmark_td3_seeded_retrain_motor2_diagnostic trains TD3 base by seed.
%
% This is the active software/simulation workflow for the benchmark phase.
% It does not use hardware and does not change COM ports.

arguments
    options = struct()
end

options = localNormalizeOptions(options);

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);

cd(matlabRoot);
addpath(genpath(matlabRoot));
clearConfigurablesOverride();

resultsRoot = localResolveResultsRoot(options.resultsRoot, workspaceRoot);
summaryRoot = fullfile(resultsRoot, "summary");
figuresRoot = fullfile(resultsRoot, "figures");
ensureDirectoryExists(resultsRoot);
ensureDirectoryExists(summaryRoot);
ensureDirectoryExists(figuresRoot);

gpuInfo = configureGpuForTraining(options.useGpu);
benchmark = getAgent7250Benchmark();

sanityResults = struct();
if options.runMotor2SanityCheck
    sanityResults = run_motor2_simulation_sanity_check(struct( ...
        "resultsRoot", fullfile(resultsRoot, "motor2_sanity_check")));
end

seedRows = cell(numel(options.seeds), 1);
seedResults = cell(numel(options.seeds), 1);
for i = 1:numel(options.seeds)
    seedValue = double(options.seeds(i));
    [seedRows{i}, seedResults{i}] = localRunSeedBenchmark( ...
        seedValue, options, resultsRoot, figuresRoot, benchmark);
end
if isappdata(0, "last_training_gpu_info")
    gpuInfo = getappdata(0, "last_training_gpu_info");
end

perSeedTable = struct2table(vertcat(seedRows{:}));
aggregateSummary = localSummarizeCampaign(perSeedTable, benchmark);
referenceTable = localBuildFinalComparisonTable( ...
    perSeedTable, aggregateSummary, options, resultsRoot, benchmark);

trainingOverviewPath = fullfile(figuresRoot, "benchmark_training_overview.png");
selectedCheckpointsFigurePath = fullfile(figuresRoot, "benchmark_selected_checkpoints.png");
motor2SummaryFigurePath = fullfile(figuresRoot, "motor2_diagnostic_summary.png");
comparisonFigurePath = fullfile(figuresRoot, "benchmark_final_comparison.png");

localCreateTrainingOverviewFigure(perSeedTable, trainingOverviewPath);
localCreateSelectedCheckpointsFigure(perSeedTable, selectedCheckpointsFigurePath);
localCreateMotor2SummaryFigure(perSeedTable, motor2SummaryFigurePath);
localCreateFinalComparisonFigure(referenceTable, comparisonFigurePath);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.options = options;
results.gpuInfo = gpuInfo;
results.benchmark = benchmark;
results.perSeedTable = perSeedTable;
results.aggregateSummary = aggregateSummary;
results.referenceTable = referenceTable;
results.seedResults = seedResults;
results.sanityResults = sanityResults;
results.figurePaths = struct( ...
    "trainingOverview", string(trainingOverviewPath), ...
    "selectedCheckpoints", string(selectedCheckpointsFigurePath), ...
    "motor2Summary", string(motor2SummaryFigurePath), ...
    "finalComparison", string(comparisonFigurePath));

writetable(perSeedTable, fullfile(summaryRoot, "benchmark_seeded_summary.csv"));
writetable(referenceTable, fullfile(summaryRoot, "benchmark_seeded_final_comparison.csv"));
localWriteTextFile(fullfile(summaryRoot, "benchmark_seeded_summary.txt"), ...
    localBuildSummaryText(results));
localWriteTextFile(fullfile(summaryRoot, "benchmark_seeded_figures.md"), ...
    localBuildFigureIndexMarkdown(results));
results.figureIndexPath = string(fullfile(summaryRoot, "benchmark_seeded_figures.md"));

save(fullfile(summaryRoot, "benchmark_seeded_results.mat"), ...
    "results", "perSeedTable", "aggregateSummary", "referenceTable", ...
    "options", "seedResults", "gpuInfo", "sanityResults");

clearConfigurablesOverride();
end

function options = localNormalizeOptions(options)
defaults = struct( ...
    "seeds", [11 22 33 44 55], ...
    "trainingEpisodes", 12000, ...
    "trainingSaveEvery", 100, ...
    "episodeSaveFreq", 100, ...
    "trainingPlots", "none", ...
    "flagSaveTraining", true, ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 5, ...
    "auditSamplingPolicy", struct("mode", "all"), ...
    "selectionMode", "global", ...
    "rewardType", "trackingMseActionRateReward", ...
    "rewardMotorWeights", [1 2 1 1], ...
    "rewardActionMotorWeights", [1 1 1 1], ...
    "rewardDeltaActionMotorWeights", [1 1 1 1], ...
    "quantizeCommandsForSimulation", true, ...
    "actionCommandLevels", [0 64 96 128 160 192 224 255], ...
    "configLabel", "", ...
    "finalTestEpisodes", 50, ...
    "plotEpisodeOnTest", true, ...
    "useGpu", true, ...
    "generateReport", true, ...
    "compileReport", false, ...
    "runMotor2SanityCheck", true, ...
    "evaluateReferenceCheckpoints", true, ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.seeds = double(options.seeds(:))';
options.trainingEpisodes = double(options.trainingEpisodes);
options.trainingSaveEvery = double(options.trainingSaveEvery);
options.episodeSaveFreq = double(options.episodeSaveFreq);
options.auditFastSimulations = max(1, double(options.auditFastSimulations));
options.auditFullSimulations = max(1, double(options.auditFullSimulations));
options.auditTopK = max(1, double(options.auditTopK));
options.selectionMode = lower(string(options.selectionMode));
options.rewardType = string(options.rewardType);
options.rewardMotorWeights = double(options.rewardMotorWeights(:))';
options.rewardActionMotorWeights = double(options.rewardActionMotorWeights(:))';
options.rewardDeltaActionMotorWeights = double(options.rewardDeltaActionMotorWeights(:))';
options.quantizeCommandsForSimulation = logical(options.quantizeCommandsForSimulation);
options.actionCommandLevels = double(options.actionCommandLevels(:))';
options.configLabel = string(options.configLabel);
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.trainingPlots = string(options.trainingPlots);
options.plotEpisodeOnTest = logical(options.plotEpisodeOnTest);
options.useGpu = logical(options.useGpu);
options.generateReport = logical(options.generateReport);
options.compileReport = logical(options.compileReport);
options.runMotor2SanityCheck = logical(options.runMotor2SanityCheck);
options.evaluateReferenceCheckpoints = logical(options.evaluateReferenceCheckpoints);
options.resultsRoot = string(options.resultsRoot);

if isempty(options.seeds)
    error("options.seeds must contain at least one seed.");
end
if ~isstruct(options.auditSamplingPolicy)
    error("options.auditSamplingPolicy must be a struct.");
end
if ~ismember(options.selectionMode, ["global", "motor2_aware"])
    error("Unsupported selectionMode '%s'.", options.selectionMode);
end
end

function [seedRow, seedResult] = localRunSeedBenchmark(seedValue, options, resultsRoot, figuresRoot, benchmark)
seedLabel = sprintf("seed_%03d", round(seedValue));
seedRoot = fullfile(resultsRoot, seedLabel);
trainingParent = fullfile(seedRoot, "training");
auditRoot = fullfile(seedRoot, "checkpoint_audit");
finalTestRoot = fullfile(seedRoot, sprintf("final_test_%d", round(options.finalTestEpisodes)));
ensureDirectoryExists(seedRoot);
ensureDirectoryExists(trainingParent);
ensureDirectoryExists(auditRoot);
ensureDirectoryExists(finalTestRoot);

clearConfigurablesOverride();
baseConfigs = configurables();
td3Config = baseConfigs.td3;
td3Config.useRecurrent = false;

patch = struct( ...
    "agent_id", "td3", ...
    "run_training", true, ...
    "newTraining", true, ...
    "rewardType", options.rewardType, ...
    "rewardMotorWeights", options.rewardMotorWeights, ...
    "rewardActionMotorWeights", options.rewardActionMotorWeights, ...
    "rewardDeltaActionMotorWeights", options.rewardDeltaActionMotorWeights, ...
    "observationVariant", "markov52", ...
    "usePrerecorded", true, ...
    "simMotors", true, ...
    "connect_glove", false, ...
    "unifyActions", false, ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "quantizeCommandsForSimulation", options.quantizeCommandsForSimulation, ...
    "actionCommandLevels", options.actionCommandLevels, ...
    "trainingMaxEpisodes", options.trainingEpisodes, ...
    "trainingSaveAgentEvery", options.trainingSaveEvery, ...
    "episode_save_freq", options.episodeSaveFreq, ...
    "trainingPlots", options.trainingPlots, ...
    "flagSaveTraining", options.flagSaveTraining, ...
    "randomSeed", seedValue, ...
    "td3", td3Config, ...
    "td3Residual", struct("enabled", false), ...
    "useGpu", options.useGpu, ...
    "enableDetailedActionDiagnostics", true, ...
    "savePerMotorMetrics", true, ...
    "agents_directory", @(agent_id, variant) fullfile( ...
        trainingParent, string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss"))));
override = buildMarkov52BaselineOverride(baseConfigs, patch);

try
    setConfigurablesOverride(override);
    clear configurables
    clear Env
    trainInterface("td3", "", "");
catch ME
    clearConfigurablesOverride();
    rethrow(ME);
end
clearConfigurablesOverride();

trainingRunDir = localFindNewestSubdir(trainingParent);
trainingFigurePath = fullfile(figuresRoot, string(seedLabel) + "_training_progress.png");
localCreateTrainingProgressFigureFromRun( ...
    string(trainingRunDir), string(trainingFigurePath), "Benchmark TD3 training progress");
trainingAnalysis = analyzeExperimentRun(string(trainingRunDir));

auditResults = runCheckpointAudit( ...
    options.auditFastSimulations, ...
    options.auditFullSimulations, ...
    options.auditTopK, ...
    struct( ...
        "experimentDir", string(trainingRunDir), ...
        "samplingPolicy", options.auditSamplingPolicy, ...
        "resultsRoot", string(auditRoot), ...
        "verbose", false));

[selectedAuditRow, selectionMeta] = localSelectBenchmarkCheckpoint( ...
    auditResults.phaseBTable, options, auditRoot);

visualCopyStartedAt = datenum(datetime("now"));
runCheckpointTest( ...
    string(selectedAuditRow.checkpointPath), ...
    options.finalTestEpisodes, ...
    options.plotEpisodeOnTest, ...
    struct("resultsRoot", string(finalTestRoot)));
finalTestRunDir = localFindNewestSubdir(finalTestRoot);
finalAnalysis = analyzeExperimentRun(string(finalTestRunDir));
finalDecision = classifyBenchmarkAcceptance(finalAnalysis.episodeSummary, benchmark);

visualTestFigurePath = fullfile(figuresRoot, sprintf( ...
    "%s_selected_checkpoint_episode_%d_visual_test.png", ...
    seedLabel, round(options.finalTestEpisodes)));
visualTestFigurePath = localCopyOrCreateVisualTestFigure( ...
    string(finalTestRunDir), string(visualTestFigurePath), ...
    round(options.finalTestEpisodes), visualCopyStartedAt);

motorDiagnosticFigurePath = fullfile(figuresRoot, string(seedLabel) + "_motor_diagnostic.png");
[motorDiagnostic, motorTable] = analyzeMotor2Diagnostic( ...
    string(finalTestRunDir), string(motorDiagnosticFigurePath));
writetable(motorTable, fullfile(seedRoot, "motor_diagnostic.csv"));

seedRow = struct( ...
    "seed", double(seedValue), ...
    "seedLabel", string(seedLabel), ...
    "configLabel", string(options.configLabel), ...
    "rewardType", string(options.rewardType), ...
    "selectionMode", string(options.selectionMode), ...
    "trainingRunDir", string(trainingRunDir), ...
    "selectedCheckpointPath", string(selectedAuditRow.checkpointPath), ...
    "selectedCheckpointEpisode", double(selectedAuditRow.checkpointEpisode), ...
    "finalTestRunDir", string(finalTestRunDir), ...
    "trainingFigurePath", string(trainingFigurePath), ...
    "visualTestFigurePath", string(visualTestFigurePath), ...
    "motorDiagnosticFigurePath", string(motorDiagnosticFigurePath), ...
    "trackingMSE", double(finalAnalysis.episodeSummary.trackingMseMean), ...
    "trackingMAE", double(finalAnalysis.episodeSummary.trackingMaeMean), ...
    "actionL2", double(finalAnalysis.episodeSummary.actionL2Mean), ...
    "saturationFraction", double(finalAnalysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2", double(finalAnalysis.episodeSummary.deltaActionL2Mean), ...
    "finalStatus", string(finalDecision.status), ...
    "selectionReason", string(selectionMeta.reason), ...
    "auditStatus", string(selectedAuditRow.benchmarkStatus), ...
    "auditTrackingMSE", double(selectedAuditRow.trackingMseMean), ...
    "auditTrackingMAE", double(selectedAuditRow.trackingMaeMean), ...
    "auditActionL2", double(selectedAuditRow.actionL2Mean), ...
    "auditSaturationFraction", double(selectedAuditRow.saturationFractionMean), ...
    "auditDeltaActionL2", double(selectedAuditRow.deltaActionL2Mean), ...
    "trainingAverageRewardFinal", localGetTrainingSummaryValue(trainingAnalysis, "averageRewardFinal"), ...
    "trainingBestAverageReward", localGetTrainingSummaryValue(trainingAnalysis, "bestAverageReward"), ...
    "trainingBestAverageRewardEpisode", localGetTrainingSummaryValue(trainingAnalysis, "bestAverageRewardEpisode"), ...
    "motor2_flat_response", logical(motorDiagnostic.motor2_flat_response), ...
    "motor2_action_no_motion", logical(motorDiagnostic.motor2_action_no_motion), ...
    "motor2_tracking_outlier", logical(motorDiagnostic.motor2_tracking_outlier), ...
    "motor2Interpretation", string(motorDiagnostic.motor2Interpretation));

for motorIdx = 1:4
    seedRow.(sprintf("trackingMSE_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("trackingMSE_motor%d", motorIdx)));
    seedRow.(sprintf("trackingMAE_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("trackingMAE_motor%d", motorIdx)));
    seedRow.(sprintf("actionL2_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("actionL2_motor%d", motorIdx)));
    seedRow.(sprintf("deltaActionL2_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("deltaActionL2_motor%d", motorIdx)));
    seedRow.(sprintf("saturationFraction_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("saturationFraction_motor%d", motorIdx)));
    seedRow.(sprintf("responseRange_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("responseRange_motor%d", motorIdx)));
    seedRow.(sprintf("targetRange_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("targetRange_motor%d", motorIdx)));
    seedRow.(sprintf("correlation_motor%d", motorIdx)) = ...
        double(motorDiagnostic.(sprintf("correlation_motor%d", motorIdx)));
end

seedResult = struct( ...
    "trainingRunDir", string(trainingRunDir), ...
    "trainingAnalysis", trainingAnalysis, ...
    "auditResults", auditResults, ...
    "selectedAuditRow", selectedAuditRow, ...
    "selectionMeta", selectionMeta, ...
    "finalTestRunDir", string(finalTestRunDir), ...
    "finalAnalysis", finalAnalysis, ...
    "finalDecision", finalDecision, ...
    "motorDiagnostic", motorDiagnostic, ...
    "motorTable", motorTable, ...
    "trainingFigurePath", string(trainingFigurePath), ...
    "visualTestFigurePath", string(visualTestFigurePath), ...
    "motorDiagnosticFigurePath", string(motorDiagnosticFigurePath));

save(fullfile(seedRoot, "seed_result.mat"), "seedResult");
end

function [selectedRow, meta] = localSelectBenchmarkCheckpoint(phaseBTable, options, auditRoot)
rows = table2struct(phaseBTable);
selectionMode = "global";
if nargin >= 2 && isfield(options, "selectionMode")
    selectionMode = lower(string(options.selectionMode));
end

if selectionMode == "motor2_aware"
    [rankedRows, motor2AuditTable] = localRankMotor2AwareRows(rows, auditRoot);
    selectedRow = rankedRows(1);
    meta = struct( ...
        "reason", "motor2_aware_phaseB_selection", ...
        "motor2AuditTable", motor2AuditTable);
else
    rankedRows = localRankBenchmarkRows(rows);
    selectedRow = rankedRows(1);
    meta = struct( ...
        "reason", "best_phaseB_checkpoint_by_status_tracking_effort_and_saturation", ...
        "motor2AuditTable", table());
end
end

function rankedRows = localRankBenchmarkRows(rows)
statusRank = arrayfun(@localMapStatusToRank, string({rows.benchmarkStatus}));
metricMatrix = [ ...
    -statusRank(:), ...
    double([rows.trackingMseMean])', ...
    double([rows.trackingMaeMean])', ...
    double([rows.saturationFractionMean])', ...
    double([rows.actionL2Mean])', ...
    double([rows.deltaActionL2Mean])'];
[~, order] = sortrows(metricMatrix);
rankedRows = rows(order);
end

function [rankedRows, motor2AuditTable] = localRankMotor2AwareRows(rows, auditRoot)
phaseBRoot = fullfile(auditRoot, "phaseB_full");
augmentedRows = rows;
motorRows = cell(numel(rows), 1);

for i = 1:numel(rows)
    runDir = localFindAuditRunDirForCheckpoint(phaseBRoot, string(rows(i).checkpointPath));
    motor2 = localEmptyMotor2Audit(string(rows(i).checkpointPath), runDir);
    if strlength(runDir) > 0 && isfolder(runDir)
        try
            diagnostic = analyzeMotor2Diagnostic(string(runDir), "");
            motor2.trackingMSE_motor2 = diagnostic.trackingMSE_motor2;
            motor2.responseRange_motor2 = diagnostic.responseRange_motor2;
            motor2.targetRange_motor2 = diagnostic.targetRange_motor2;
            motor2.actionL2_motor2 = diagnostic.actionL2_motor2;
            motor2.saturationFraction_motor2 = diagnostic.saturationFraction_motor2;
            motor2.motor2_flat_response = diagnostic.motor2_flat_response;
            motor2.motor2_action_no_motion = diagnostic.motor2_action_no_motion;
        catch ME
            motor2.diagnosticError = string(ME.message);
        end
    end

    augmentedRows(i).trackingMSE_motor2 = motor2.trackingMSE_motor2;
    augmentedRows(i).responseRange_motor2 = motor2.responseRange_motor2;
    augmentedRows(i).targetRange_motor2 = motor2.targetRange_motor2;
    augmentedRows(i).actionL2_motor2 = motor2.actionL2_motor2;
    augmentedRows(i).saturationFraction_motor2 = motor2.saturationFraction_motor2;
    augmentedRows(i).motor2_flat_response = motor2.motor2_flat_response;
    augmentedRows(i).motor2_action_no_motion = motor2.motor2_action_no_motion;
    motorRows{i} = motor2;
end

motor2AuditTable = struct2table(vertcat(motorRows{:}));
candidateRows = augmentedRows;
noFlag = ~logical([candidateRows.motor2_flat_response]) & ...
    ~logical([candidateRows.motor2_action_no_motion]);
if any(noFlag)
    candidateRows = candidateRows(noFlag);
end

metricMatrix = [ ...
    localRowMetric(candidateRows, "trackingMSE_motor2")', ...
    double([candidateRows.trackingMseMean])', ...
    double([candidateRows.saturationFractionMean])', ...
    double([candidateRows.actionL2Mean])', ...
    double([candidateRows.deltaActionL2Mean])'];
[~, order] = sortrows(metricMatrix);
rankedRows = candidateRows(order);
end

function values = localRowMetric(rows, fieldName)
values = nan(1, numel(rows));
for i = 1:numel(rows)
    if isfield(rows(i), fieldName)
        values(i) = double(rows(i).(fieldName));
    end
end
end

function runDir = localFindAuditRunDirForCheckpoint(phaseBRoot, checkpointPath)
runDir = "";
if ~isfolder(phaseBRoot)
    return;
end
dirInfo = dir(phaseBRoot);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
for i = 1:numel(dirInfo)
    auditPath = fullfile(dirInfo(i).folder, dirInfo(i).name, "audit_run.mat");
    if ~isfile(auditPath)
        continue;
    end
    try
        data = load(auditPath, "checkpointPath");
        if isfield(data, "checkpointPath") && string(data.checkpointPath) == checkpointPath
            runDir = string(fullfile(dirInfo(i).folder, dirInfo(i).name));
            return;
        end
    catch
    end
end
end

function row = localEmptyMotor2Audit(checkpointPath, runDir)
row = struct( ...
    "checkpointPath", string(checkpointPath), ...
    "auditRunDir", string(runDir), ...
    "trackingMSE_motor2", NaN, ...
    "responseRange_motor2", NaN, ...
    "targetRange_motor2", NaN, ...
    "actionL2_motor2", NaN, ...
    "saturationFraction_motor2", NaN, ...
    "motor2_flat_response", false, ...
    "motor2_action_no_motion", false, ...
    "diagnosticError", "");
end

function rank = localMapStatusToRank(status)
switch string(status)
    case "ConditionA"
        rank = 2;
    case "ConditionB"
        rank = 1;
    otherwise
        rank = 0;
end
end

function value = localGetTrainingSummaryValue(trainingAnalysis, fieldName)
value = NaN;
if isstruct(trainingAnalysis) && isfield(trainingAnalysis, "trainingSummary") && ...
        isfield(trainingAnalysis.trainingSummary, fieldName)
    value = double(trainingAnalysis.trainingSummary.(fieldName));
end
end

function localCreateTrainingProgressFigureFromRun(runDir, figurePath, plotTitle)
trainingInfoPath = fullfile(runDir, "training_info.mat");
if ~isfile(trainingInfoPath)
    localCreateEmptyFigure(figurePath, "training_info.mat not found");
    return;
end

data = load(trainingInfoPath, "trainingInfo");
if ~isfield(data, "trainingInfo")
    localCreateEmptyFigure(figurePath, "trainingInfo not found");
    return;
end

trainingInfo = data.trainingInfo;
episodeIndex = localGetTrainingInfoVector(trainingInfo, "EpisodeIndex");
series = { ...
    "EpisodeReward", [0.45 0.80 1.00], 0.8; ...
    "AverageReward", [0.00 0.45 0.74], 2.0; ...
    "EpisodeQ0", [0.93 0.69 0.13], 0.9};

if isempty(episodeIndex)
    maxLength = 0;
    for i = 1:size(series, 1)
        maxLength = max(maxLength, numel(localGetTrainingInfoVector(trainingInfo, series{i, 1})));
    end
    episodeIndex = (1:maxLength)';
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
hold on
legendLabels = strings(0, 1);
for i = 1:size(series, 1)
    values = localGetTrainingInfoVector(trainingInfo, series{i, 1});
    if isempty(values)
        continue;
    end
    n = min(numel(episodeIndex), numel(values));
    plot(episodeIndex(1:n), values(1:n), ...
        "Color", series{i, 2}, "LineWidth", series{i, 3});
    legendLabels(end+1, 1) = series{i, 1}; %#ok<AGROW>
end
hold off
grid on
xlabel("Episode")
ylabel("Reward")
title(plotTitle)
if ~isempty(legendLabels)
    legend(cellstr(legendLabels), "Location", "best", "Box", "off");
else
    text(0.5, 0.5, "No plottable training fields found", ...
        "HorizontalAlignment", "center", "Units", "normalized");
end

localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function values = localGetTrainingInfoVector(trainingInfo, fieldName)
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

function visualPath = localCopyOrCreateVisualTestFigure(runDir, targetPath, targetEpisode, startDatenum)
sourcePath = localFindVisualEpisodeImage(runDir, targetEpisode, startDatenum);
if strlength(sourcePath) > 0 && isfile(sourcePath)
    localEnsureParentDirectoryExists(targetPath);
    copyfile(char(sourcePath), char(targetPath));
    visualPath = string(targetPath);
    return;
end

visualPath = localCreateRepresentativeEpisodeFigure(runDir, targetPath, targetEpisode);
end

function sourcePath = localFindVisualEpisodeImage(runDir, targetEpisode, startDatenum)
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

function figurePath = localCreateRepresentativeEpisodeFigure(runDir, targetPath, targetEpisode)
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

actionAligned = [];
if ~isempty(actions)
    actionAligned = localAlignRows(actions, nGlove);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
motorNames = ["Motor 1", "Motor 2", "Motor 3", "Motor 4"];

for i = 1:4
    nexttile;
    plot(prosthesisInterp(:, i), "-", "LineWidth", 2.0, "Color", [0.00 0.45 0.74]);
    hold on
    plot(glovePosition(:, i), "--", "LineWidth", 2.0, "Color", [0.85 0.33 0.10]);
    if ~isempty(actionAligned)
        scatter(1:nGlove, prosthesisInterp(:, i), 18, actionAligned(:, i), "filled");
        colormap(gca, parula);
    end
    hold off
    grid on
    title(string(motorNames(i)))
    xlabel("Sample")
    ylabel("Normalized position")
    if i == 1
        legend(["Simulated", "Glove ref", "Action"], "Location", "best");
    end
end

localEnsureParentDirectoryExists(targetPath);
exportgraphics(f, targetPath, "Resolution", 220);
close(f);
figurePath = string(targetPath);
end

function aligned = localAlignRows(value, targetRows)
value = double(value);
if isempty(value)
    aligned = nan(targetRows, 4);
elseif size(value, 1) == targetRows
    aligned = value;
elseif size(value, 1) == 1
    aligned = repmat(value, targetRows, 1);
else
    xSource = linspace(1, targetRows, size(value, 1));
    aligned = interp1(xSource, value, 1:targetRows, "linear", "extrap");
end
if size(aligned, 2) < 4
    aligned(:, end+1:4) = NaN;
end
aligned = aligned(:, 1:4);
end

function localCreateTrainingOverviewFigure(perSeedTable, figurePath)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
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
    episodeIndex = localGetTrainingInfoVector(data.trainingInfo, "EpisodeIndex");
    averageReward = localGetTrainingInfoVector(data.trainingInfo, "AverageReward");
    if isempty(averageReward)
        averageReward = localGetTrainingInfoVector(data.trainingInfo, "EpisodeReward");
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
title("Benchmark TD3 training overview")
legend("Location", "bestoutside", "Box", "off");

localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateSelectedCheckpointsFigure(perSeedTable, figurePath)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1200 650]);
bar(categorical(string(perSeedTable.seed)), double(perSeedTable.selectedCheckpointEpisode), ...
    "FaceColor", [0.12 0.47 0.71], "FaceAlpha", 0.85);
grid on
xlabel("Seed")
ylabel("Selected checkpoint episode")
title("Selected checkpoint by seed")
localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateMotor2SummaryFigure(perSeedTable, figurePath)
metrics = ["trackingMSE", "responseRange", "actionL2", "saturationFraction"];
titles = ["Tracking MSE", "Response range", "Action L2", "Saturation fraction"];
colors = repmat([0.12 0.47 0.71], 4, 1);
colors(2, :) = [0.75 0.12 0.12];

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
for metricIdx = 1:numel(metrics)
    values = nan(1, 4);
    for motorIdx = 1:4
        fieldName = sprintf("%s_motor%d", metrics(metricIdx), motorIdx);
        values(motorIdx) = mean(double(perSeedTable.(fieldName)), "omitnan");
    end
    ax = nexttile;
    b = bar(ax, values, "FaceColor", "flat");
    b.CData = colors;
    grid(ax, "on");
    title(ax, titles(metricIdx));
    xlabel(ax, "Motor")
    ylabel(ax, titles(metricIdx))
    set(ax, "XTick", 1:4, "XTickLabel", ["M1", "M2", "M3", "M4"]);
end
sgtitle(f, "Motor 2 diagnostic summary across seeds");
localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function referenceTable = localBuildFinalComparisonTable(perSeedTable, aggregateSummary, options, resultsRoot, benchmark)
rows = {};

if logical(options.evaluateReferenceCheckpoints)
    rows = localAppendReferenceIfAvailable(rows, "Agent7250", "official_benchmark", ...
        @getAgent7250CheckpointPath, options, resultsRoot, benchmark, true);
else
    rows{end+1, 1} = localBuildHistoricalBenchmarkRow(benchmark);
end

rows = localAppendReferenceIfAvailable(rows, "Agent1850", "residual_historical_single_run", ...
    @getResidualFinalCheckpointPath, options, resultsRoot, benchmark, false);

meanRow = localBuildCampaignMeanRow(perSeedTable, aggregateSummary, benchmark);
bestRow = localBuildBestCampaignSeedRow(perSeedTable);
rows{end+1, 1} = meanRow;
rows{end+1, 1} = bestRow;

referenceTable = struct2table(vertcat(rows{:}));
end

function rows = localAppendReferenceIfAvailable(rows, label, kind, resolver, options, resultsRoot, benchmark, fallbackToBenchmark)
try
    checkpointPath = string(resolver());
catch
    if fallbackToBenchmark
        rows{end+1, 1} = localBuildHistoricalBenchmarkRow(benchmark);
    end
    return;
end

if strlength(checkpointPath) == 0 || ~isfile(checkpointPath)
    if fallbackToBenchmark
        rows{end+1, 1} = localBuildHistoricalBenchmarkRow(benchmark);
    end
    return;
end

try
    referenceRoot = fullfile(resultsRoot, "reference_tests", char(label));
    ensureDirectoryExists(referenceRoot);
    runCheckpointTest(checkpointPath, options.finalTestEpisodes, false, struct( ...
        "resultsRoot", string(referenceRoot)));
    runDir = localFindNewestSubdir(referenceRoot);
    analysis = analyzeExperimentRun(string(runDir));
    [motorDiagnostic, ~] = analyzeMotor2Diagnostic(string(runDir), "");
    decision = classifyBenchmarkAcceptance(analysis.episodeSummary, benchmark);
    rows{end+1, 1} = localBuildComparisonRow( ...
        string(label), string(kind), analysis.episodeSummary, decision.status, motorDiagnostic);
catch ME
    warning("Reference evaluation failed for %s: %s", string(label), string(ME.message));
    if fallbackToBenchmark
        rows{end+1, 1} = localBuildHistoricalBenchmarkRow(benchmark);
    end
end
end

function row = localBuildHistoricalBenchmarkRow(benchmark)
row = struct( ...
    "candidateLabel", "Agent7250", ...
    "candidateKind", "official_benchmark_historical", ...
    "trackingMSE", double(benchmark.trackingMse), ...
    "trackingMAE", double(benchmark.trackingMae), ...
    "actionL2", double(benchmark.actionL2), ...
    "saturationFraction", double(benchmark.saturationFraction), ...
    "deltaActionL2", double(benchmark.deltaActionL2), ...
    "trackingMSE_motor2", NaN, ...
    "responseRange_motor2", NaN, ...
    "finalStatus", "Reference");
end

function row = localBuildComparisonRow(label, kind, summary, status, motorDiagnostic)
row = struct( ...
    "candidateLabel", string(label), ...
    "candidateKind", string(kind), ...
    "trackingMSE", double(summary.trackingMseMean), ...
    "trackingMAE", double(summary.trackingMaeMean), ...
    "actionL2", double(summary.actionL2Mean), ...
    "saturationFraction", double(summary.saturationFractionMean), ...
    "deltaActionL2", double(summary.deltaActionL2Mean), ...
    "trackingMSE_motor2", double(motorDiagnostic.trackingMSE_motor2), ...
    "responseRange_motor2", double(motorDiagnostic.responseRange_motor2), ...
    "finalStatus", string(status));
end

function row = localBuildCampaignMeanRow(perSeedTable, aggregateSummary, benchmark)
metrics = struct( ...
    "trackingMseMean", aggregateSummary.trackingMSEMean, ...
    "saturationFractionMean", aggregateSummary.saturationFractionMean, ...
    "actionL2Mean", aggregateSummary.actionL2Mean, ...
    "deltaActionL2Mean", aggregateSummary.deltaActionL2Mean);
decision = classifyBenchmarkAcceptance(metrics, benchmark);
row = struct( ...
    "candidateLabel", "CampaignMean", ...
    "candidateKind", "new_campaign_mean", ...
    "trackingMSE", double(aggregateSummary.trackingMSEMean), ...
    "trackingMAE", double(aggregateSummary.trackingMAEMean), ...
    "actionL2", double(aggregateSummary.actionL2Mean), ...
    "saturationFraction", double(aggregateSummary.saturationFractionMean), ...
    "deltaActionL2", double(aggregateSummary.deltaActionL2Mean), ...
    "trackingMSE_motor2", mean(double(perSeedTable.trackingMSE_motor2), "omitnan"), ...
    "responseRange_motor2", mean(double(perSeedTable.responseRange_motor2), "omitnan"), ...
    "finalStatus", string(decision.status));
end

function row = localBuildBestCampaignSeedRow(perSeedTable)
bestIdx = localFindBestSeedIndex(perSeedTable);
row = struct( ...
    "candidateLabel", sprintf("BestSeed%d", perSeedTable.seed(bestIdx)), ...
    "candidateKind", "new_campaign_best_seed", ...
    "trackingMSE", double(perSeedTable.trackingMSE(bestIdx)), ...
    "trackingMAE", double(perSeedTable.trackingMAE(bestIdx)), ...
    "actionL2", double(perSeedTable.actionL2(bestIdx)), ...
    "saturationFraction", double(perSeedTable.saturationFraction(bestIdx)), ...
    "deltaActionL2", double(perSeedTable.deltaActionL2(bestIdx)), ...
    "trackingMSE_motor2", double(perSeedTable.trackingMSE_motor2(bestIdx)), ...
    "responseRange_motor2", double(perSeedTable.responseRange_motor2(bestIdx)), ...
    "finalStatus", string(perSeedTable.finalStatus(bestIdx)));
end

function localCreateFinalComparisonFigure(referenceTable, figurePath)
metrics = ["trackingMSE", "trackingMAE", "actionL2", "saturationFraction", ...
    "deltaActionL2", "trackingMSE_motor2", "responseRange_motor2"];
labels = string(referenceTable.candidateLabel);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 1000]);
tiledlayout(f, 3, 3, "TileSpacing", "compact", "Padding", "compact");
for i = 1:numel(metrics)
    ax = nexttile;
    values = double(referenceTable.(metrics(i)));
    bar(ax, categorical(labels), values, 0.62, ...
        "FaceColor", [0.12 0.47 0.71], "FaceAlpha", 0.85);
    grid(ax, "on");
    ylabel(ax, metrics(i), "Interpreter", "none");
    title(ax, metrics(i), "Interpreter", "none");
end
nexttile;
axis off
text(0, 0.72, "Benchmark TD3 comparison", "FontWeight", "bold", "FontSize", 12);
text(0, 0.52, "Lower is better for error and effort metrics.", "FontSize", 10);
text(0, 0.36, "Agent1850 is residual history only, not active line.", "FontSize", 10);

localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function summary = localSummarizeCampaign(perSeedTable, benchmark)
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
summary.trackingMSEMotor2Mean = mean(double(perSeedTable.trackingMSE_motor2), "omitnan");
summary.responseRangeMotor2Mean = mean(double(perSeedTable.responseRange_motor2), "omitnan");
summary.motor2FlatResponseCount = sum(logical(perSeedTable.motor2_flat_response));
summary.motor2ActionNoMotionCount = sum(logical(perSeedTable.motor2_action_no_motion));
summary.motor2TrackingOutlierCount = sum(logical(perSeedTable.motor2_tracking_outlier));
summary.conditionACount = sum(string(perSeedTable.finalStatus) == "ConditionA");
summary.conditionBCount = sum(string(perSeedTable.finalStatus) == "ConditionB");
summary.rejectedCount = sum(string(perSeedTable.finalStatus) == "Rejected");
summary.bestSeedIndex = localFindBestSeedIndex(perSeedTable);
summary.bestSeed = double(perSeedTable.seed(summary.bestSeedIndex));
summary.bestSeedCheckpointPath = string(perSeedTable.selectedCheckpointPath(summary.bestSeedIndex));
summary.bestSeedEpisode = double(perSeedTable.selectedCheckpointEpisode(summary.bestSeedIndex));
summary.aggregateDecision = classifyBenchmarkAcceptance(struct( ...
    "trackingMseMean", summary.trackingMSEMean, ...
    "saturationFractionMean", summary.saturationFractionMean, ...
    "actionL2Mean", summary.actionL2Mean, ...
    "deltaActionL2Mean", summary.deltaActionL2Mean), benchmark);
summary.motor2PreliminaryConclusion = localBuildMotor2PreliminaryConclusion(summary);
end

function idx = localFindBestSeedIndex(perSeedTable)
statusRank = arrayfun(@localMapStatusToRank, string(perSeedTable.finalStatus));
metricMatrix = [ ...
    -statusRank(:), ...
    double(perSeedTable.trackingMSE(:)), ...
    double(perSeedTable.trackingMAE(:)), ...
    double(perSeedTable.saturationFraction(:)), ...
    double(perSeedTable.actionL2(:)), ...
    double(perSeedTable.deltaActionL2(:))];
[~, order] = sortrows(metricMatrix);
idx = order(1);
end

function conclusion = localBuildMotor2PreliminaryConclusion(summary)
if summary.motor2ActionNoMotionCount > 0
    conclusion = "Motor 2 may receive action without proportional simulated motion; prioritize simulator/mapping checks.";
elseif summary.motor2FlatResponseCount > 0
    conclusion = "Motor 2 response may be flat while target varies; inspect response scaling and mapping.";
elseif summary.motor2TrackingOutlierCount > 0
    conclusion = "Motor 2 is a tracking outlier; compare training behavior with simulator sanity check.";
else
    conclusion = "No strong motor 2 failure flag was triggered; real conclusion requires the full 50-episode campaign.";
end
end

function textValue = localBuildSummaryText(results)
summary = results.aggregateSummary;
gpuInfo = results.gpuInfo;
lines = strings(0, 1);
lines(end+1) = "Benchmark TD3 seeded retrain + motor 2 diagnostic";
lines(end+1) = "===================================================";
lines(end+1) = "";
lines(end+1) = sprintf("Results root: %s", string(results.resultsRoot));
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
lines(end+1) = sprintf("GPU requested: %d", gpuInfo.useGpuRequested);
lines(end+1) = sprintf("GPU available: %d", gpuInfo.gpuAvailable);
lines(end+1) = sprintf("GPU name: %s", string(gpuInfo.gpuName));
if isfield(gpuInfo, "gpuComputeCapability")
    lines(end+1) = sprintf("GPU compute capability: %s", string(gpuInfo.gpuComputeCapability));
end
if isfield(gpuInfo, "forwardCompatibilityEnabled")
    lines(end+1) = sprintf("GPU forward compatibility enabled: %d", gpuInfo.forwardCompatibilityEnabled);
end
lines(end+1) = sprintf("GPU enabled: %d", gpuInfo.gpuEnabled);
if strlength(string(gpuInfo.gpuFallbackReason)) > 0
    lines(end+1) = sprintf("GPU fallback reason: %s", string(gpuInfo.gpuFallbackReason));
end
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
lines(end+1) = sprintf("Motor 2 trackingMSE mean: %.6f", summary.trackingMSEMotor2Mean);
lines(end+1) = sprintf("Motor 2 responseRange mean: %.6f", summary.responseRangeMotor2Mean);
lines(end+1) = sprintf("Motor 2 flat response flags: %d", summary.motor2FlatResponseCount);
lines(end+1) = sprintf("Motor 2 action-no-motion flags: %d", summary.motor2ActionNoMotionCount);
lines(end+1) = sprintf("Motor 2 tracking outlier flags: %d", summary.motor2TrackingOutlierCount);
lines(end+1) = sprintf("Preliminary conclusion: %s", string(summary.motor2PreliminaryConclusion));
lines(end+1) = "";
if isfield(results.sanityResults, "csvPath")
    lines(end+1) = sprintf("Motor 2 sanity CSV: %s", string(results.sanityResults.csvPath));
    lines(end+1) = sprintf("Motor 2 sanity PNG: %s", string(results.sanityResults.figurePath));
    lines(end+1) = "";
end
lines(end+1) = "Per-seed selected checkpoints:";
for i = 1:height(results.perSeedTable)
    row = results.perSeedTable(i, :);
    lines(end+1) = sprintf( ...
        "seed %d | episode %d | status %s | trackingMSE %.6f | motor2MSE %.6f | visual %s | checkpoint %s | reason %s", ...
        row.seed, row.selectedCheckpointEpisode, string(row.finalStatus), ...
        row.trackingMSE, row.trackingMSE_motor2, string(row.visualTestFigurePath), ...
        string(row.selectedCheckpointPath), string(row.selectionReason)); %#ok<AGROW>
end
textValue = strjoin(lines, newline);
end

function markdownText = localBuildFigureIndexMarkdown(results)
lines = strings(0, 1);
lines(end+1) = "# Benchmark TD3 seeded figures";
lines(end+1) = "";
lines(end+1) = sprintf("- Results root: `%s`", string(results.resultsRoot));
lines(end+1) = "- Scope: software/simulation only; no hardware ports are touched.";
lines(end+1) = "";
lines(end+1) = "## Campaign figures";
lines(end+1) = "";
lines(end+1) = "| Figure | Path |";
lines(end+1) = "| --- | --- |";
lines(end+1) = sprintf("| Training overview | `%s` |", string(results.figurePaths.trainingOverview));
lines(end+1) = sprintf("| Selected checkpoints | `%s` |", string(results.figurePaths.selectedCheckpoints));
lines(end+1) = sprintf("| Motor 2 summary | `%s` |", string(results.figurePaths.motor2Summary));
lines(end+1) = sprintf("| Final comparison | `%s` |", string(results.figurePaths.finalComparison));
if isfield(results.sanityResults, "figurePath")
    lines(end+1) = sprintf("| Motor 2 sanity check | `%s` |", string(results.sanityResults.figurePath));
end
lines(end+1) = "";
lines(end+1) = "## Per-seed figures";
lines(end+1) = "";
lines(end+1) = "| Seed | Training | Selected checkpoint visual test | Motor diagnostic |";
lines(end+1) = "| --- | --- | --- | --- |";
for i = 1:height(results.perSeedTable)
    lines(end+1) = sprintf("| %d | `%s` | `%s` | `%s` |", ...
        results.perSeedTable.seed(i), ...
        string(results.perSeedTable.trainingFigurePath(i)), ...
        string(results.perSeedTable.visualTestFigurePath(i)), ...
        string(results.perSeedTable.motorDiagnosticFigurePath(i)));
end
markdownText = strjoin(lines, newline);
end

function localCreateEmptyFigure(figurePath, message)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1000 500]);
axis off
text(0.5, 0.5, string(message), "HorizontalAlignment", "center", ...
    "Units", "normalized", "FontSize", 12);
localEnsureParentDirectoryExists(figurePath);
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localEnsureParentDirectoryExists(filePath)
[parentDir, ~, ~] = fileparts(char(string(filePath)));
if strlength(string(parentDir)) > 0
    ensureDirectoryExists(parentDir);
end
end

function newestDir = localFindNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No subdirectories found in %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
newestDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function resultsRoot = localResolveResultsRoot(requestedRoot, workspaceRoot)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    baseRoot = char(requestedRoot);
else
    baseRoot = fullfile(workspaceRoot, "Agentes", ...
        "benchmark_td3_seeded_retrain_motor2_diagnostic", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
resultsRoot = localMakeUniqueDirectoryPath(baseRoot);
end

function uniquePath = localMakeUniqueDirectoryPath(basePath)
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

function localWriteTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textValue);
end
