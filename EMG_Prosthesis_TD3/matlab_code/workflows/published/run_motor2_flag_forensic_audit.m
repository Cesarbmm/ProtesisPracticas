function results = run_motor2_flag_forensic_audit(options)
%run_motor2_flag_forensic_audit audits why M2 flags remain on frozen Agent7250.
%
% This workflow does not train. It evaluates Agent7250 frozen under four
% simulation-only configurations and computes motor-2 flags per episode.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
projectRoot = char(paths.projectRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));
clearConfigurablesOverride();

options = localNormalizeOptions(options, workspaceRoot, projectRoot);
ensureDirectoryExists(options.resultsRoot);
ensureDirectoryExists(options.summaryRoot);
ensureDirectoryExists(options.figuresRoot);
ensureDirectoryExists(options.docsFigureRoot);

checkpointPath = string(getAgent7250CheckpointPath());
episodeRows = cell(numel(options.configs), 1);
configResults = cell(numel(options.configs), 1);
integrityRows = cell(numel(options.configs), 1);
for configIdx = 1:numel(options.configs)
    [episodeRows{configIdx}, configResults{configIdx}, integrityRows{configIdx}] = ...
        localEvaluateConfig(options.configs(configIdx), checkpointPath, options);
end

episodeTable = vertcat(episodeRows{:});
episodeTable = localAddPossibleFalsePositive(episodeTable, options);
episodeTable = localCreateFlagFigures(episodeTable, configResults, options);
integrityTable = struct2table(vertcat(integrityRows{:}));
summaryTable = localBuildSummaryTable(episodeTable, integrityTable);
thresholdTable = localBuildThresholdSensitivity(episodeTable, options);

byEpisodeCsvPath = fullfile(options.summaryRoot, ...
    "motor2_flag_forensic_by_episode.csv");
summaryCsvPath = fullfile(options.summaryRoot, ...
    "motor2_flag_forensic_summary.csv");
thresholdCsvPath = fullfile(options.summaryRoot, ...
    "motor2_flag_threshold_sensitivity.csv");
summaryTxtPath = fullfile(options.summaryRoot, ...
    "motor2_flag_forensic_summary.txt");
matPath = fullfile(options.summaryRoot, ...
    "motor2_flag_forensic_results.mat");

writetable(episodeTable, byEpisodeCsvPath);
writetable(summaryTable, summaryCsvPath);
writetable(thresholdTable, thresholdCsvPath);
localWriteTextFile(summaryTxtPath, localBuildSummaryText(options, summaryTable));

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.docsFigureRoot = string(options.docsFigureRoot);
results.checkpointPath = checkpointPath;
results.options = options;
results.episodeTable = episodeTable;
results.summaryTable = summaryTable;
results.thresholdTable = thresholdTable;
results.configResults = configResults;
results.paths = struct( ...
    "byEpisodeCsv", string(byEpisodeCsvPath), ...
    "summaryCsv", string(summaryCsvPath), ...
    "thresholdSensitivityCsv", string(thresholdCsvPath), ...
    "summaryTxt", string(summaryTxtPath), ...
    "mat", string(matPath));

save(matPath, "results", "episodeTable", "summaryTable", ...
    "thresholdTable", "configResults", "options");
clearConfigurablesOverride();
end

function options = localNormalizeOptions(options, workspaceRoot, projectRoot)
defaults = struct( ...
    "gapOffset", -256, ...
    "finalTestEpisodes", 50, ...
    "plotEpisodeOnTest", true, ...
    "useGpu", true, ...
    "randomSeed", 7250, ...
    "motor2OnlyCorrectionGain", 0.50, ...
    "motor2OnlyCorrectionMaxDelta", 0.20, ...
    "motor2OnlyCorrectionMinBoost", 0.08, ...
    "motor2OnlyCorrectionMinError", 0.08, ...
    "motor2OnlyCorrectionFlatUpper", 0.18, ...
    "falsePositiveTargetRangeThreshold", 0.12, ...
    "falsePositiveResponseRatio", 0.70, ...
    "falsePositiveMseTolerance", 0.05, ...
    "reuseExistingRuns", false, ...
    "resultsRoot", "", ...
    "docsFigureRoot", "");
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.gapOffset = double(options.gapOffset);
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.plotEpisodeOnTest = logical(options.plotEpisodeOnTest);
options.useGpu = logical(options.useGpu);
options.randomSeed = double(options.randomSeed);
options.motor2OnlyCorrectionGain = double(options.motor2OnlyCorrectionGain);
options.motor2OnlyCorrectionMaxDelta = double(options.motor2OnlyCorrectionMaxDelta);
options.motor2OnlyCorrectionMinBoost = double(options.motor2OnlyCorrectionMinBoost);
options.motor2OnlyCorrectionMinError = double(options.motor2OnlyCorrectionMinError);
options.motor2OnlyCorrectionFlatUpper = double(options.motor2OnlyCorrectionFlatUpper);
options.falsePositiveTargetRangeThreshold = ...
    double(options.falsePositiveTargetRangeThreshold);
options.falsePositiveResponseRatio = double(options.falsePositiveResponseRatio);
options.falsePositiveMseTolerance = double(options.falsePositiveMseTolerance);
options.reuseExistingRuns = logical(options.reuseExistingRuns);

if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = char(string(options.resultsRoot));
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "motor2_flag_forensic_audit", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
if strlength(string(options.docsFigureRoot)) > 0
    options.docsFigureRoot = char(string(options.docsFigureRoot));
else
    options.docsFigureRoot = fullfile(projectRoot, "docs", ...
        "benchmark_motor2_diagnostic", "figures", ...
        "frozen_agent7250_final", "motor2_flag_forensic");
end

options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
options.configs = localBuildConfigs(options);
options.baseThresholds = localCurrentThresholds();
options.thresholdScenarios = localThresholdScenarios();
end

function configs = localBuildConfigs(options)
gapLabel = localOffsetLabel(options.gapOffset);
configs = [ ...
    struct( ...
        "label", "agent7250_baseline_conversion", ...
        "encoder2FlexVariant", "baseline", ...
        "gapOffset", NaN, ...
        "actionPostprocessVariant", "none"), ...
    struct( ...
        "label", "agent7250_motor2Calibrated_gap_" + gapLabel, ...
        "encoder2FlexVariant", "motor2Calibrated", ...
        "gapOffset", options.gapOffset, ...
        "actionPostprocessVariant", "none"), ...
    struct( ...
        "label", "agent7250_motor2OnlyHeuristic_baseline_conversion", ...
        "encoder2FlexVariant", "baseline", ...
        "gapOffset", NaN, ...
        "actionPostprocessVariant", "motor2OnlyHeuristicCorrection"), ...
    struct( ...
        "label", "agent7250_motor2OnlyHeuristic_motor2Calibrated_gap_" + gapLabel, ...
        "encoder2FlexVariant", "motor2Calibrated", ...
        "gapOffset", options.gapOffset, ...
        "actionPostprocessVariant", "motor2OnlyHeuristicCorrection")];
end

function thresholds = localCurrentThresholds()
thresholds = struct( ...
    "label", "current", ...
    "minTargetRange", 0.10, ...
    "responseRangeFloor", 0.03, ...
    "responseRangeRatio", 0.35, ...
    "flatOtherTargetRatio", 0.50, ...
    "actionNoMotionActionMin", 0.10, ...
    "actionNoMotionOtherActionRatio", 0.75, ...
    "highActionFlatActionL2Threshold", 0.70, ...
    "highActionFlatSaturationThreshold", 0.25);
end

function scenarios = localThresholdScenarios()
scenarios = [
    localScenario("current", 0.10, 0.03, 0.35, 0.50, 0.10, 0.75, 0.70, 0.25)
    localScenario("relaxed_low_target", 0.15, 0.03, 0.30, 0.60, 0.20, 0.90, 0.80, 0.35)
    localScenario("relaxed_response", 0.10, 0.02, 0.25, 0.50, 0.15, 0.85, 0.80, 0.35)
    localScenario("strict_target", 0.05, 0.03, 0.35, 0.40, 0.10, 0.75, 0.70, 0.25)
    localScenario("strict_response", 0.05, 0.05, 0.50, 0.40, 0.08, 0.60, 0.60, 0.15)
    ];
end

function scenario = localScenario(label, minTargetRange, responseRangeFloor, ...
        responseRangeRatio, flatOtherTargetRatio, actionNoMotionActionMin, ...
        actionNoMotionOtherActionRatio, highActionThreshold, saturationThreshold)
scenario = struct( ...
    "label", label, ...
    "minTargetRange", minTargetRange, ...
    "responseRangeFloor", responseRangeFloor, ...
    "responseRangeRatio", responseRangeRatio, ...
    "flatOtherTargetRatio", flatOtherTargetRatio, ...
    "actionNoMotionActionMin", actionNoMotionActionMin, ...
    "actionNoMotionOtherActionRatio", actionNoMotionOtherActionRatio, ...
    "highActionFlatActionL2Threshold", highActionThreshold, ...
    "highActionFlatSaturationThreshold", saturationThreshold);
end

function [episodeTable, configResult, integrityRow] = localEvaluateConfig( ...
        cfg, checkpointPath, options)
configRoot = fullfile(options.resultsRoot, char(cfg.label));
ensureDirectoryExists(configRoot);

overridePatch = struct( ...
    "run_training", false, ...
    "newTraining", false, ...
    "initialAgentSource", "Agent7250", ...
    "isAgentFrozen", true, ...
    "isTrainingFromScratch", false, ...
    "isWarmStartFromAgent7250", false, ...
    "trainableActorParameters", 0, ...
    "trainableCriticParameters", 0, ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "actionPostprocessVariant", string(cfg.actionPostprocessVariant), ...
    "motor2OnlyCorrectionGain", options.motor2OnlyCorrectionGain, ...
    "motor2OnlyCorrectionMaxDelta", options.motor2OnlyCorrectionMaxDelta, ...
    "motor2OnlyCorrectionMinBoost", options.motor2OnlyCorrectionMinBoost, ...
    "motor2OnlyCorrectionMinError", options.motor2OnlyCorrectionMinError, ...
    "motor2OnlyCorrectionFlatUpper", options.motor2OnlyCorrectionFlatUpper, ...
    "quantizeCommandsForSimulation", true, ...
    "encoder2FlexVariant", string(cfg.encoder2FlexVariant), ...
    "motor2Encoder2FlexGapOffset", double(cfg.gapOffset), ...
    "usePrerecorded", true, ...
    "simMotors", true, ...
    "connect_glove", false, ...
    "randomSeed", options.randomSeed, ...
    "useGpu", options.useGpu, ...
    "enableDetailedActionDiagnostics", true, ...
    "savePerMotorMetrics", true);
if isnan(cfg.gapOffset)
    overridePatch = rmfield(overridePatch, "motor2Encoder2FlexGapOffset");
end

if options.reuseExistingRuns
    testRunDir = localFindNewestSubdir(configRoot);
else
    runCheckpointTest(checkpointPath, options.finalTestEpisodes, ...
        options.plotEpisodeOnTest, struct( ...
        "resultsRoot", string(configRoot), ...
        "overridePatch", overridePatch));
    testRunDir = localFindNewestSubdir(configRoot);
end

[episodeTable, allMotorMetrics] = localBuildEpisodeTable( ...
    testRunDir, cfg, checkpointPath, options);
integrity = localComputeActionIntegrity(testRunDir);
if integrity.maxNonMotor2ActionDelta > 0
    error("Motor2-only audit detected non-M2 action delta: %.17g", ...
        integrity.maxNonMotor2ActionDelta);
end
episodeTable.maxNonMotor2ActionDelta = repmat( ...
    integrity.maxNonMotor2ActionDelta, height(episodeTable), 1);
episodeTable.meanAbsMotor2ActionDelta = repmat( ...
    integrity.meanAbsMotor2ActionDelta, height(episodeTable), 1);
episodeTable.maxAbsMotor2ActionDelta = repmat( ...
    integrity.maxAbsMotor2ActionDelta, height(episodeTable), 1);

integrityRow = struct( ...
    "configLabel", string(cfg.label), ...
    "maxNonMotor2ActionDelta", integrity.maxNonMotor2ActionDelta, ...
    "meanAbsMotor2ActionDelta", integrity.meanAbsMotor2ActionDelta, ...
    "maxAbsMotor2ActionDelta", integrity.maxAbsMotor2ActionDelta);
configResult = struct( ...
    "config", cfg, ...
    "checkpointPath", string(checkpointPath), ...
    "testRunDir", string(testRunDir), ...
    "allMotorMetrics", {allMotorMetrics}, ...
    "integrity", integrity);
end

function [episodeTable, allMotorMetrics] = localBuildEpisodeTable( ...
        testRunDir, cfg, checkpointPath, options)
episodeFiles = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(episodeFiles)
    error("No episode*.mat files found in %s", testRunDir);
end
[episodeFiles, episodeNumbers] = localSortEpisodeFiles(episodeFiles);

rows = cell(numel(episodeFiles), 1);
allMotorMetrics = cell(numel(episodeFiles), 1);
for episodeIdx = 1:numel(episodeFiles)
    episodeFile = fullfile(episodeFiles(episodeIdx).folder, episodeFiles(episodeIdx).name);
    data = localLoadEpisodeData(episodeFile);
    [target, response, actionSteps] = localExtractAlignedSignals(data);
    metrics = localComputeMetricsByMotor(target, response, actionSteps);
    flags = localComputeFlags(metrics, options.baseThresholds);
    allMotorMetrics{episodeIdx} = struct( ...
        "episode", episodeNumbers(episodeIdx), ...
        "metrics", metrics, ...
        "flags", flags);

    motorIdx = 2;
    flagReason = localBuildFlagReason(flags, motorIdx);
    row = struct( ...
        "configLabel", string(cfg.label), ...
        "episode", episodeNumbers(episodeIdx), ...
        "checkpointPath", string(checkpointPath), ...
        "checkpoint", "Agent7250", ...
        "frozen", true, ...
        "actionInterfaceVariant", "baselineQuantized", ...
        "encoder2FlexVariant", string(cfg.encoder2FlexVariant), ...
        "actionPostprocessVariant", string(cfg.actionPostprocessVariant), ...
        "gapOffset", double(cfg.gapOffset), ...
        "testRunDir", string(testRunDir), ...
        "trackingMSE_motor2", metrics.trackingMSE(motorIdx), ...
        "trackingMAE_motor2", metrics.trackingMAE(motorIdx), ...
        "responseRange_motor2", metrics.responseRange(motorIdx), ...
        "targetRange_motor2", metrics.targetRange(motorIdx), ...
        "actionRange_motor2", metrics.actionRange(motorIdx), ...
        "actionL2_motor2", metrics.actionL2(motorIdx), ...
        "saturationFraction_motor2", metrics.saturationFraction(motorIdx), ...
        "flat_response_motor2", flags.flatResponse(motorIdx), ...
        "action_no_motion_motor2", flags.actionNoMotion(motorIdx), ...
        "high_action_flat_response_motor2", flags.highActionFlatResponse(motorIdx), ...
        "totalFlags_motor2", double(flags.flatResponse(motorIdx)) + ...
            double(flags.actionNoMotion(motorIdx)) + ...
            double(flags.highActionFlatResponse(motorIdx)), ...
        "meanAbsAction_motor2", metrics.meanAbsAction(motorIdx), ...
        "maxAbsAction_motor2", metrics.maxAbsAction(motorIdx), ...
        "meanResponse_motor2", metrics.meanResponse(motorIdx), ...
        "minResponse_motor2", metrics.minResponse(motorIdx), ...
        "maxResponse_motor2", metrics.maxResponse(motorIdx), ...
        "initialResponse_motor2", metrics.initialResponse(motorIdx), ...
        "finalResponse_motor2", metrics.finalResponse(motorIdx), ...
        "initialTarget_motor2", metrics.initialTarget(motorIdx), ...
        "finalTarget_motor2", metrics.finalTarget(motorIdx), ...
        "otherTargetRangeMean_motor2", mean(metrics.targetRange([1 3 4]), "omitnan"), ...
        "otherActionL2Mean_motor2", mean(metrics.actionL2([1 3 4]), "omitnan"), ...
        "totalFlags_motor1", localTotalFlags(flags, 1), ...
        "totalFlags_motor3", localTotalFlags(flags, 3), ...
        "totalFlags_motor4", localTotalFlags(flags, 4), ...
        "possibleFalsePositive", false, ...
        "flagReasonText", flagReason, ...
        "forensicFigurePath", "");
    rows{episodeIdx} = row;
end
episodeTable = struct2table(vertcat(rows{:}));
end

function total = localTotalFlags(flags, motorIdx)
total = double(flags.flatResponse(motorIdx)) + ...
    double(flags.actionNoMotion(motorIdx)) + ...
    double(flags.highActionFlatResponse(motorIdx));
end

function metrics = localComputeMetricsByMotor(target, response, actionSteps)
numMotors = 4;
metrics = struct();
names = ["trackingMSE", "trackingMAE", "actionL2", "deltaActionL2", ...
    "saturationFraction", "actionRange", "responseRange", "targetRange", ...
    "meanAbsAction", "maxAbsAction", "meanResponse", "minResponse", ...
    "maxResponse", "initialResponse", "finalResponse", "initialTarget", ...
    "finalTarget"];
for name = names
    metrics.(name) = nan(1, numMotors);
end

for motorIdx = 1:numMotors
    targetMotor = target(:, motorIdx);
    responseMotor = response(:, motorIdx);
    actionMotor = actionSteps(:, motorIdx);
    errorMotor = responseMotor - targetMotor;
    metrics.trackingMSE(motorIdx) = mean(errorMotor.^2, "omitnan");
    metrics.trackingMAE(motorIdx) = mean(abs(errorMotor), "omitnan");
    metrics.actionL2(motorIdx) = sqrt(mean(actionMotor.^2, "omitnan"));
    if size(actionSteps, 1) >= 2
        metrics.deltaActionL2(motorIdx) = ...
            sqrt(mean(diff(actionMotor).^2, "omitnan"));
    else
        metrics.deltaActionL2(motorIdx) = 0;
    end
    metrics.saturationFraction(motorIdx) = ...
        mean(abs(actionMotor) >= 0.95, "omitnan");
    metrics.actionRange(motorIdx) = localRange(actionMotor);
    metrics.responseRange(motorIdx) = localRange(responseMotor);
    metrics.targetRange(motorIdx) = localRange(targetMotor);
    metrics.meanAbsAction(motorIdx) = mean(abs(actionMotor), "omitnan");
    metrics.maxAbsAction(motorIdx) = max(abs(actionMotor), [], "omitnan");
    metrics.meanResponse(motorIdx) = mean(responseMotor, "omitnan");
    metrics.minResponse(motorIdx) = min(responseMotor, [], "omitnan");
    metrics.maxResponse(motorIdx) = max(responseMotor, [], "omitnan");
    metrics.initialResponse(motorIdx) = localFirstFinite(responseMotor);
    metrics.finalResponse(motorIdx) = localLastFinite(responseMotor);
    metrics.initialTarget(motorIdx) = localFirstFinite(targetMotor);
    metrics.finalTarget(motorIdx) = localLastFinite(targetMotor);
end
end

function flags = localComputeFlags(metrics, thresholds)
numMotors = numel(metrics.targetRange);
flags = struct( ...
    "flatResponse", false(1, numMotors), ...
    "actionNoMotion", false(1, numMotors), ...
    "highActionFlatResponse", false(1, numMotors));
for motorIdx = 1:numMotors
    otherIdx = setdiff(1:numMotors, motorIdx);
    targetRange = metrics.targetRange(motorIdx);
    responseRange = metrics.responseRange(motorIdx);
    actionValue = metrics.actionL2(motorIdx);
    saturationValue = metrics.saturationFraction(motorIdx);
    flatThreshold = max(thresholds.responseRangeFloor, ...
        thresholds.responseRangeRatio * targetRange);
    targetMovesFlat = localFinite(targetRange) && targetRange >= ...
        max(thresholds.minTargetRange, ...
        thresholds.flatOtherTargetRatio * mean(metrics.targetRange(otherIdx), "omitnan"));
    flatResponse = localFinite(responseRange) && targetMovesFlat && ...
        responseRange <= flatThreshold;
    actionLargeEnough = localFinite(actionValue) && actionValue >= ...
        max(thresholds.actionNoMotionActionMin, ...
        thresholds.actionNoMotionOtherActionRatio * ...
        mean(metrics.actionL2(otherIdx), "omitnan"));
    actionNoMotion = actionLargeEnough && localFinite(responseRange) && ...
        localFinite(targetRange) && responseRange <= flatThreshold;
    highAction = (localFinite(actionValue) && actionValue >= ...
        thresholds.highActionFlatActionL2Threshold) || ...
        (localFinite(saturationValue) && saturationValue >= ...
        thresholds.highActionFlatSaturationThreshold);
    highActionFlat = highAction && localFinite(responseRange) && ...
        localFinite(targetRange) && targetRange >= thresholds.minTargetRange && ...
        responseRange <= flatThreshold;

    flags.flatResponse(motorIdx) = flatResponse;
    flags.actionNoMotion(motorIdx) = actionNoMotion;
    flags.highActionFlatResponse(motorIdx) = highActionFlat;
end
end

function episodeTable = localAddPossibleFalsePositive(episodeTable, options)
episodeTable.possibleFalsePositive(:) = false;
baseline = episodeTable(episodeTable.configLabel == ...
    "agent7250_baseline_conversion", :);
for i = 1:height(episodeTable)
    if episodeTable.totalFlags_motor2(i) == 0
        continue;
    end
    baselineIdx = find(baseline.episode == episodeTable.episode(i), 1);
    if isempty(baselineIdx)
        baselineMse = episodeTable.trackingMSE_motor2(i);
    else
        baselineMse = baseline.trackingMSE_motor2(baselineIdx);
    end
    lowTarget = episodeTable.targetRange_motor2(i) <= ...
        options.falsePositiveTargetRangeThreshold;
    responseNotMuchLower = episodeTable.responseRange_motor2(i) >= ...
        options.falsePositiveResponseRatio * episodeTable.targetRange_motor2(i);
    mseSimilar = episodeTable.trackingMSE_motor2(i) <= ...
        (1 + options.falsePositiveMseTolerance) * baselineMse;
    episodeTable.possibleFalsePositive(i) = lowTarget && ...
        responseNotMuchLower && mseSimilar;
end
for i = 1:height(episodeTable)
    reason = localBuildFlagReasonFromTable(episodeTable(i, :));
    episodeTable.flagReasonText(i) = reason;
end
end

function reason = localBuildFlagReason(flags, motorIdx)
parts = strings(0, 1);
if flags.flatResponse(motorIdx)
    parts(end+1) = "flat_response";
end
if flags.actionNoMotion(motorIdx)
    parts(end+1) = "action_no_motion";
end
if flags.highActionFlatResponse(motorIdx)
    parts(end+1) = "high_action_flat_response";
end
if isempty(parts)
    reason = "none";
else
    reason = strjoin(parts, ";");
end
end

function reason = localBuildFlagReasonFromTable(row)
parts = strings(0, 1);
if row.flat_response_motor2
    parts(end+1) = "flat_response";
end
if row.action_no_motion_motor2
    parts(end+1) = "action_no_motion";
end
if row.high_action_flat_response_motor2
    parts(end+1) = "high_action_flat_response";
end
if row.possibleFalsePositive
    parts(end+1) = "possible_false_positive";
end
if isempty(parts)
    reason = "none";
else
    reason = strjoin(parts, ";");
end
end

function episodeTable = localCreateFlagFigures(episodeTable, configResults, options)
for i = 1:height(episodeTable)
    if episodeTable.totalFlags_motor2(i) == 0
        continue;
    end
    cfgIdx = localFindConfigResult(configResults, episodeTable.configLabel(i));
    if cfgIdx == 0
        continue;
    end
    testRunDir = configResults{cfgIdx}.testRunDir;
    episodeFile = fullfile(testRunDir, sprintf("episode%d.mat", episodeTable.episode(i)));
    if ~isfile(episodeFile)
        episodeFile = localFindEpisodeFile(testRunDir, episodeTable.episode(i));
    end
    fileName = sprintf("%s_episode_%03d_flags_%s.png", ...
        localSafeFileName(episodeTable.configLabel(i)), ...
        episodeTable.episode(i), ...
        localSafeFileName(episodeTable.flagReasonText(i)));
    targetPath = fullfile(options.docsFigureRoot, fileName);
    localCreateForensicFigure(episodeFile, episodeTable(i, :), targetPath);
    episodeTable.forensicFigurePath(i) = string(targetPath);
end
end

function localCreateForensicFigure(episodeFile, row, figurePath)
localEnsureParent(figurePath);
data = localLoadEpisodeData(episodeFile);
[target, response, actionSteps] = localExtractAlignedSignals(data);
x = 1:size(target, 1);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 1000]);
tiledlayout(f, 3, 4, "TileSpacing", "compact", "Padding", "compact");
motorNames = ["M1", "M2", "M3", "M4"];
for motorIdx = 1:4
    ax = nexttile(motorIdx);
    plot(ax, x, target(:, motorIdx), "Color", [0.00 0.45 0.74], "LineWidth", 1.3);
    hold(ax, "on");
    plot(ax, x, response(:, motorIdx), "Color", [0.85 0.33 0.10], "LineWidth", 1.2);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " ref/response");
    if motorIdx == 1
        legend(ax, ["Glove", "Sim"], "Location", "best");
    end
    localHighlightM2(ax, motorIdx);

    ax = nexttile(4 + motorIdx);
    plot(ax, x, response(:, motorIdx) - target(:, motorIdx), ...
        "Color", [0.49 0.18 0.56], "LineWidth", 1.1);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " error");
    localHighlightM2(ax, motorIdx);

    ax = nexttile(8 + motorIdx);
    plot(ax, x, actionSteps(:, motorIdx), "Color", [0.47 0.67 0.19], "LineWidth", 1.1);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " action");
    ylim(ax, [-1.05 1.05]);
    localHighlightM2(ax, motorIdx);
end
titleText = sprintf([ ...
    '%s | episode=%d | checkpoint=Agent7250 | frozen=true\n', ...
    'encoder2FlexVariant=%s | actionPostprocessVariant=%s | gapOffset=%s | flags=%s'], ...
    char(row.configLabel), row.episode, char(row.encoder2FlexVariant), ...
    char(row.actionPostprocessVariant), char(localGapText(row.gapOffset)), ...
    char(row.flagReasonText));
sgtitle(f, titleText, "Interpreter", "none");
exportgraphics(f, figurePath, "Resolution", 180);
close(f);
end

function localHighlightM2(ax, motorIdx)
if motorIdx ~= 2
    return;
end
ax.LineWidth = 1.5;
ax.XColor = [0.70 0.10 0.10];
ax.YColor = [0.70 0.10 0.10];
end

function idx = localFindConfigResult(configResults, configLabel)
idx = 0;
for i = 1:numel(configResults)
    if configResults{i}.config.label == string(configLabel)
        idx = i;
        return;
    end
end
end

function episodeFile = localFindEpisodeFile(testRunDir, episodeNumber)
files = dir(fullfile(testRunDir, "episode*.mat"));
for i = 1:numel(files)
    token = regexp(files(i).name, "episode(\d+)", "tokens", "once");
    if ~isempty(token) && str2double(token{1}) == episodeNumber
        episodeFile = fullfile(files(i).folder, files(i).name);
        return;
    end
end
error("Episode %d not found in %s", episodeNumber, testRunDir);
end

function summaryTable = localBuildSummaryTable(episodeTable, integrityTable)
configLabels = unique(episodeTable.configLabel, "stable");
rows = cell(numel(configLabels), 1);
for i = 1:numel(configLabels)
    label = configLabels(i);
    cfgRows = episodeTable(episodeTable.configLabel == label, :);
    flagged = cfgRows.totalFlags_motor2 > 0;
    integrity = integrityTable(integrityTable.configLabel == label, :);
    row = struct( ...
        "configLabel", label, ...
        "totalM2Flags", sum(cfgRows.totalFlags_motor2), ...
        "episodesWithFlags", sum(flagged), ...
        "flaggedEpisodeList", localEpisodeList(cfgRows.episode(flagged)), ...
        "flatResponseCount", sum(double(cfgRows.flat_response_motor2)), ...
        "actionNoMotionCount", sum(double(cfgRows.action_no_motion_motor2)), ...
        "highActionFlatResponseCount", sum(double(cfgRows.high_action_flat_response_motor2)), ...
        "possibleFalsePositiveCount", sum(double(cfgRows.possibleFalsePositive)), ...
        "meanMSE_M2_flagged", localMean(cfgRows.trackingMSE_motor2(flagged)), ...
        "meanMSE_M2_unflagged", localMean(cfgRows.trackingMSE_motor2(~flagged)), ...
        "meanTargetRange_M2_flagged", localMean(cfgRows.targetRange_motor2(flagged)), ...
        "meanResponseRange_M2_flagged", localMean(cfgRows.responseRange_motor2(flagged)), ...
        "meanActionRange_M2_flagged", localMean(cfgRows.actionRange_motor2(flagged)), ...
        "totalFlags_motor1", sum(cfgRows.totalFlags_motor1), ...
        "totalFlags_motor3", sum(cfgRows.totalFlags_motor3), ...
        "totalFlags_motor4", sum(cfgRows.totalFlags_motor4), ...
        "maxNonMotor2ActionDelta", integrity.maxNonMotor2ActionDelta, ...
        "meanAbsMotor2ActionDelta", integrity.meanAbsMotor2ActionDelta, ...
        "maxAbsMotor2ActionDelta", integrity.maxAbsMotor2ActionDelta, ...
        "nonMotorFlagsIncreased", false, ...
        "acceptedForensic", false, ...
        "decision", "");
    rows{i} = row;
end
summaryTable = struct2table(vertcat(rows{:}));
baseline = summaryTable(summaryTable.configLabel == ...
    "agent7250_baseline_conversion", :);
for i = 1:height(summaryTable)
    if ~isempty(baseline)
        summaryTable.nonMotorFlagsIncreased(i) = ...
            summaryTable.totalFlags_motor1(i) > baseline.totalFlags_motor1 || ...
            summaryTable.totalFlags_motor3(i) > baseline.totalFlags_motor3 || ...
            summaryTable.totalFlags_motor4(i) > baseline.totalFlags_motor4;
    end
    if summaryTable.totalM2Flags(i) == 0 && ...
            ~summaryTable.nonMotorFlagsIncreased(i) && ...
            summaryTable.maxNonMotor2ActionDelta(i) == 0
        summaryTable.acceptedForensic(i) = true;
        summaryTable.decision(i) = "accepted";
    elseif summaryTable.episodesWithFlags(i) > 0 && ...
            summaryTable.possibleFalsePositiveCount(i) == summaryTable.episodesWithFlags(i)
        summaryTable.decision(i) = "inconclusive_possible_false_positive";
    else
        summaryTable.decision(i) = "rejected_m2_flags_remain";
    end
end
end

function thresholdTable = localBuildThresholdSensitivity(episodeTable, options)
configLabels = unique(episodeTable.configLabel, "stable");
rows = cell(numel(options.thresholdScenarios) * numel(configLabels), 1);
rowIdx = 0;
for scenarioIdx = 1:numel(options.thresholdScenarios)
    thresholds = options.thresholdScenarios(scenarioIdx);
    for configIdx = 1:numel(configLabels)
        cfgRows = episodeTable(episodeTable.configLabel == configLabels(configIdx), :);
        flat = false(height(cfgRows), 1);
        actionNoMotion = false(height(cfgRows), 1);
        highActionFlat = false(height(cfgRows), 1);
        for i = 1:height(cfgRows)
            flatThreshold = max(thresholds.responseRangeFloor, ...
                thresholds.responseRangeRatio * cfgRows.targetRange_motor2(i));
            targetMovesFlat = cfgRows.targetRange_motor2(i) >= ...
                max(thresholds.minTargetRange, ...
                thresholds.flatOtherTargetRatio * cfgRows.otherTargetRangeMean_motor2(i));
            flat(i) = targetMovesFlat && cfgRows.responseRange_motor2(i) <= flatThreshold;
            actionLargeEnough = cfgRows.actionL2_motor2(i) >= ...
                max(thresholds.actionNoMotionActionMin, ...
                thresholds.actionNoMotionOtherActionRatio * ...
                cfgRows.otherActionL2Mean_motor2(i));
            actionNoMotion(i) = actionLargeEnough && ...
                cfgRows.responseRange_motor2(i) <= flatThreshold;
            highAction = cfgRows.actionL2_motor2(i) >= ...
                thresholds.highActionFlatActionL2Threshold || ...
                cfgRows.saturationFraction_motor2(i) >= ...
                thresholds.highActionFlatSaturationThreshold;
            highActionFlat(i) = highAction && ...
                cfgRows.targetRange_motor2(i) >= thresholds.minTargetRange && ...
                cfgRows.responseRange_motor2(i) <= flatThreshold;
        end
        totalFlags = double(flat) + double(actionNoMotion) + double(highActionFlat);
        rowIdx = rowIdx + 1;
        rows{rowIdx, 1} = struct( ...
            "thresholdLabel", string(thresholds.label), ...
            "configLabel", configLabels(configIdx), ...
            "minTargetRange", thresholds.minTargetRange, ...
            "responseRangeFloor", thresholds.responseRangeFloor, ...
            "responseRangeRatio", thresholds.responseRangeRatio, ...
            "actionNoMotionActionMin", thresholds.actionNoMotionActionMin, ...
            "actionNoMotionOtherActionRatio", thresholds.actionNoMotionOtherActionRatio, ...
            "highActionFlatActionL2Threshold", thresholds.highActionFlatActionL2Threshold, ...
            "highActionFlatSaturationThreshold", thresholds.highActionFlatSaturationThreshold, ...
            "flatResponseCount", sum(double(flat)), ...
            "actionNoMotionCount", sum(double(actionNoMotion)), ...
            "highActionFlatResponseCount", sum(double(highActionFlat)), ...
            "totalFlags", sum(totalFlags), ...
            "episodesWithAnyFlag", sum(totalFlags > 0), ...
            "flaggedEpisodeList", localEpisodeList(cfgRows.episode(totalFlags > 0)));
    end
end
thresholdTable = struct2table(vertcat(rows{:}));
end

function textValue = localBuildSummaryText(options, summaryTable)
lines = strings(0, 1);
lines(end+1) = "Motor 2 flag forensic audit";
lines(end+1) = "============================";
lines(end+1) = "";
lines(end+1) = "Training mode: Frozen Agent7250 evaluation";
lines(end+1) = "Training from scratch: false";
lines(end+1) = "Reward/defaults unchanged.";
lines(end+1) = sprintf("Final test episodes: %d", options.finalTestEpisodes);
lines(end+1) = sprintf("Gap offset: %.0f", options.gapOffset);
lines(end+1) = "";
for i = 1:height(summaryTable)
    lines(end+1) = sprintf( ...
        "%s | totalM2Flags=%d | episodesWithFlags=%d | falsePositiveCandidates=%d | M1/M3/M4 flags=%d/%d/%d | nonM2Delta=%.3g | meanAbsM2Delta=%.6f | decision=%s | flaggedEpisodes=%s", ...
        string(summaryTable.configLabel(i)), ...
        summaryTable.totalM2Flags(i), ...
        summaryTable.episodesWithFlags(i), ...
        summaryTable.possibleFalsePositiveCount(i), ...
        summaryTable.totalFlags_motor1(i), ...
        summaryTable.totalFlags_motor3(i), ...
        summaryTable.totalFlags_motor4(i), ...
        summaryTable.maxNonMotor2ActionDelta(i), ...
        summaryTable.meanAbsMotor2ActionDelta(i), ...
        string(summaryTable.decision(i)), ...
        string(summaryTable.flaggedEpisodeList(i))); %#ok<AGROW>
end
textValue = strjoin(lines, newline);
end

function [episodeFiles, episodeNumbers] = localSortEpisodeFiles(episodeFiles)
episodeNumbers = nan(numel(episodeFiles), 1);
for i = 1:numel(episodeFiles)
    token = regexp(episodeFiles(i).name, "episode(\d+)", "tokens", "once");
    if ~isempty(token)
        episodeNumbers(i) = str2double(token{1});
    end
end
if all(isnan(episodeNumbers))
    [~, idx] = sort({episodeFiles.name});
else
    [~, idx] = sort(episodeNumbers, "ascend", "MissingPlacement", "last");
end
episodeFiles = episodeFiles(idx);
episodeNumbers = episodeNumbers(idx);
end

function data = localLoadEpisodeData(episodeFile)
availableVars = string(who("-file", episodeFile));
requestedVars = [ ...
    "flexConvertedLog", "encoderAdjustedLog", ...
    "effectiveActionLog", "actionSatLog", "actionLog", "rawActionLog", ...
    "actionWarpLog"];
varsToLoad = intersect(requestedVars, availableVars, "stable");
data = load(episodeFile, varsToLoad{:});
end

function [target, response, actionSteps] = localExtractAlignedSignals(data)
if ~isfield(data, "flexConvertedLog") || ~isfield(data, "encoderAdjustedLog")
    error("Episode file does not contain flexConvertedLog and encoderAdjustedLog.");
end
target = localCellOrMatrixToRows(data.flexConvertedLog);
responseRaw = localCellOrMatrixToRows(data.encoderAdjustedLog);
target = localEnsureFourColumns(target);
responseRaw = localEnsureFourColumns(responseRaw);
response = localAlignRows(responseRaw, size(target, 1));
if isfield(data, "effectiveActionLog")
    actionSteps = double(data.effectiveActionLog);
elseif isfield(data, "actionSatLog")
    actionSteps = double(data.actionSatLog);
elseif isfield(data, "actionLog")
    actionSteps = double(data.actionLog);
elseif isfield(data, "rawActionLog")
    actionSteps = double(data.rawActionLog);
else
    actionSteps = nan(size(target, 1), 4);
end
actionSteps = localEnsureFourColumns(actionSteps);
actionSteps = localAlignRows(actionSteps, size(target, 1));
end

function rows = localCellOrMatrixToRows(value)
if iscell(value)
    rows = [];
    for i = 1:numel(value)
        if ~isempty(value{i})
            rows = [rows; double(value{i})]; %#ok<AGROW>
        end
    end
else
    rows = double(value);
end
end

function value = localEnsureFourColumns(value)
if isempty(value)
    value = nan(1, 4);
end
if size(value, 2) < 4 && size(value, 1) == 4
    value = value.';
end
if size(value, 2) < 4
    value(:, end+1:4) = NaN;
end
if size(value, 2) > 4
    value = value(:, 1:4);
end
end

function aligned = localAlignRows(value, targetRows)
if targetRows <= 0
    aligned = value;
    return;
end
if isempty(value)
    aligned = nan(targetRows, 4);
    return;
end
if size(value, 1) == targetRows
    aligned = value;
    return;
end
if size(value, 1) == 1
    aligned = repmat(value, targetRows, 1);
    return;
end
xSource = linspace(1, targetRows, size(value, 1));
xTarget = 1:targetRows;
aligned = interp1(xSource, value, xTarget, "linear", "extrap");
end

function value = localRange(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x) - min(x);
end
end

function value = localFirstFinite(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = x(1);
end
end

function value = localLastFinite(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = x(end);
end
end

function tf = localFinite(value)
tf = isfinite(value) && ~isnan(value);
end

function integrity = localComputeActionIntegrity(testRunDir)
files = dir(fullfile(testRunDir, "episode*.mat"));
maxNonMotor2Delta = 0;
maxMotor2Delta = 0;
motor2DeltaValues = [];
for fileIdx = 1:numel(files)
    data = load(fullfile(files(fileIdx).folder, files(fileIdx).name), ...
        "actionLog", "actionWarpLog");
    if ~isfield(data, "actionLog") || ~isfield(data, "actionWarpLog") || ...
            isempty(data.actionLog) || isempty(data.actionWarpLog)
        continue;
    end
    delta = double(data.actionWarpLog) - double(data.actionLog);
    nonMotor2 = delta(:, [1 3 4]);
    maxNonMotor2Delta = max(maxNonMotor2Delta, ...
        max(abs(nonMotor2(:)), [], "omitnan"));
    motor2DeltaValues = [motor2DeltaValues; abs(delta(:, 2))]; %#ok<AGROW>
    maxMotor2Delta = max(maxMotor2Delta, ...
        max(abs(delta(:, 2)), [], "omitnan"));
end
if isempty(motor2DeltaValues)
    meanAbsMotor2ActionDelta = 0;
else
    meanAbsMotor2ActionDelta = mean(motor2DeltaValues, "omitnan");
end
integrity = struct( ...
    "maxNonMotor2ActionDelta", maxNonMotor2Delta, ...
    "meanAbsMotor2ActionDelta", meanAbsMotor2ActionDelta, ...
    "maxAbsMotor2ActionDelta", maxMotor2Delta);
end

function runDir = localFindNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No run directory found under %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
runDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function textValue = localEpisodeList(episodes)
if isempty(episodes)
    textValue = "";
else
    textValue = strjoin(string(episodes(:).'), ";");
end
end

function value = localMean(x)
if isempty(x)
    value = NaN;
else
    value = mean(x, "omitnan");
end
end

function label = localOffsetLabel(offset)
if offset < 0
    label = "neg" + sprintf("%03d", abs(round(offset)));
else
    label = "pos" + sprintf("%03d", round(offset));
end
end

function textValue = localGapText(gapOffset)
if isnan(gapOffset)
    textValue = "NaN";
else
    textValue = string(gapOffset);
end
end

function fileName = localSafeFileName(value)
fileName = regexprep(char(string(value)), "[^A-Za-z0-9_-]+", "_");
fileName = regexprep(fileName, "_+", "_");
fileName = regexprep(fileName, "^_|_$", "");
end

function localEnsureParent(filePath)
[parent, ~, ~] = fileparts(filePath);
if strlength(string(parent)) > 0 && ~exist(parent, "dir")
    mkdir(parent);
end
end

function localWriteTextFile(filePath, text)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not write %s", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", text);
end
