function results = run_agent7250_frozen_conversion_evaluation(options)
%run_agent7250_frozen_conversion_evaluation tests conversion variants.
%
% This workflow does not train. It loads the canonical Agent7250 checkpoint,
% keeps the policy frozen, and evaluates encoder2Flex variants in simulation.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));
clearConfigurablesOverride();

options = localNormalizeOptions(options, workspaceRoot);
ensureDirectoryExists(options.resultsRoot);
ensureDirectoryExists(options.summaryRoot);
ensureDirectoryExists(options.figuresRoot);
ensureDirectoryExists(options.visualRoot);

checkpointPath = string(getAgent7250CheckpointPath());
rows = cell(numel(options.configs), 1);
configResults = cell(numel(options.configs), 1);
for configIdx = 1:numel(options.configs)
    [rows{configIdx}, configResults{configIdx}] = localEvaluateConfig( ...
        options.configs(configIdx), checkpointPath, options);
end

summaryTable = struct2table(vertcat(rows{:}));
summaryTable = localAddAggregateColumns(summaryTable);
[summaryTable.acceptedFrozenConversion, ...
    summaryTable.selectionReason, ...
    summaryTable.motor2Accepted, ...
    summaryTable.allMotorAccepted, ...
    summaryTable.nonMotorRegression] = localEvaluateFrozenAcceptance(summaryTable);

summaryCsvPath = fullfile(options.summaryRoot, ...
    "agent7250_frozen_conversion_summary.csv");
summaryTxtPath = fullfile(options.summaryRoot, ...
    "agent7250_frozen_conversion_summary.txt");
matPath = fullfile(options.summaryRoot, ...
    "agent7250_frozen_conversion_results.mat");
allMotorFigurePath = fullfile(options.figuresRoot, ...
    "agent7250_frozen_all_motor_comparison.png");
motor2FigurePath = fullfile(options.figuresRoot, ...
    "agent7250_frozen_motor2_detail.png");
motor4FigurePath = fullfile(options.figuresRoot, ...
    "agent7250_frozen_motor4_detail.png");

writetable(summaryTable, summaryCsvPath);
localWriteTextFile(summaryTxtPath, localBuildSummaryText(options, summaryTable));
localCreateAllMotorFigure(summaryTable, allMotorFigurePath);
localCreateMotorDetailFigure(summaryTable, 2, motor2FigurePath);
localCreateMotorDetailFigure(summaryTable, 4, motor4FigurePath);

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.visualRoot = string(options.visualRoot);
results.options = options;
results.checkpointPath = checkpointPath;
results.summaryTable = summaryTable;
results.configResults = configResults;
results.paths = struct( ...
    "summaryCsv", string(summaryCsvPath), ...
    "summaryTxt", string(summaryTxtPath), ...
    "mat", string(matPath), ...
    "allMotorFigure", string(allMotorFigurePath), ...
    "motor2Figure", string(motor2FigurePath), ...
    "motor4Figure", string(motor4FigurePath));

save(matPath, "results", "summaryTable", "configResults", "options");
clearConfigurablesOverride();
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "gapOffsets", [0 -64 -128 -256], ...
    "finalTestEpisodes", 20, ...
    "plotEpisodeOnTest", true, ...
    "useGpu", true, ...
    "randomSeed", 7250, ...
    "resultsRoot", "");
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
options.gapOffsets = unique(double(options.gapOffsets(:))', "stable");
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.plotEpisodeOnTest = logical(options.plotEpisodeOnTest);
options.useGpu = logical(options.useGpu);
options.randomSeed = double(options.randomSeed);
if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = char(string(options.resultsRoot));
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "agent7250_frozen_conversion_evaluation", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
options.visualRoot = fullfile(options.figuresRoot, ...
    "agent7250_frozen_visual_tests");
options.configs = localBuildConfigs(options.gapOffsets);
end

function configs = localBuildConfigs(gapOffsets)
template = struct( ...
    "label", "agent7250_baseline_conversion", ...
    "encoder2FlexVariant", "baseline", ...
    "gapOffset", NaN);
configs = repmat(template, 1, numel(gapOffsets) + 1);
for i = 1:numel(gapOffsets)
    offset = gapOffsets(i);
    label = "agent7250_motor2Calibrated_gap_" + localOffsetLabel(offset);
    configs(i + 1) = struct( ...
        "label", label, ...
        "encoder2FlexVariant", "motor2Calibrated", ...
        "gapOffset", offset);
end
end

function [row, configResult] = localEvaluateConfig(cfg, checkpointPath, options)
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

runCheckpointTest(checkpointPath, options.finalTestEpisodes, ...
    options.plotEpisodeOnTest, struct( ...
    "resultsRoot", string(configRoot), ...
    "overridePatch", overridePatch));
testRunDir = localFindNewestSubdir(configRoot);
analysis = analyzeExperimentRun(string(testRunDir));
diagnosticFigurePath = fullfile(options.figuresRoot, ...
    string(cfg.label) + "_motor_diagnostic.png");
[diagnostic, metricsByMotor] = analyzeMotor2Diagnostic( ...
    string(testRunDir), string(diagnosticFigurePath));
visualFigurePath = localCopyVisualTestFigure( ...
    testRunDir, cfg, options.finalTestEpisodes, options.visualRoot);

row = struct( ...
    "configLabel", string(cfg.label), ...
    "initialAgentSource", "Agent7250", ...
    "isAgentFrozen", true, ...
    "isTrainingFromScratch", false, ...
    "isWarmStartFromAgent7250", false, ...
    "trainableActorParameters", 0, ...
    "trainableCriticParameters", 0, ...
    "checkpointPath", string(checkpointPath), ...
    "checkpointEpisode", 7250, ...
    "testRunDir", string(testRunDir), ...
    "visualFigurePath", string(visualFigurePath), ...
    "motorDiagnosticFigurePath", string(diagnosticFigurePath), ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "encoder2FlexVariant", string(cfg.encoder2FlexVariant), ...
    "motor2Encoder2FlexGapOffset", double(cfg.gapOffset), ...
    "finalTestEpisodes", options.finalTestEpisodes, ...
    "trackingMSE", double(analysis.episodeSummary.trackingMseMean), ...
    "trackingMAE", double(analysis.episodeSummary.trackingMaeMean), ...
    "actionL2", double(analysis.episodeSummary.actionL2Mean), ...
    "saturationFraction", double(analysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2", double(analysis.episodeSummary.deltaActionL2Mean));

for motorIdx = 1:4
    fields = ["trackingMSE", "trackingMAE", "responseRange", ...
        "targetRange", "actionL2", "actionRange", "saturationFraction", ...
        "deltaActionL2", "flat_response", "action_no_motion", ...
        "high_action_flat_response"];
    for fieldIdx = 1:numel(fields)
        sourceName = sprintf("%s_motor%d", fields(fieldIdx), motorIdx);
        row.(sourceName) = diagnostic.(sourceName);
    end
end

configResult = struct( ...
    "config", cfg, ...
    "testRunDir", string(testRunDir), ...
    "analysis", analysis, ...
    "diagnostic", diagnostic, ...
    "metricsByMotor", metricsByMotor, ...
    "visualFigurePath", string(visualFigurePath), ...
    "diagnosticFigurePath", string(diagnosticFigurePath));
end

function summaryTable = localAddAggregateColumns(summaryTable)
for motorIdx = 1:4
    summaryTable.(sprintf("totalFlags_motor%d", motorIdx)) = ...
        double(summaryTable.(sprintf("flat_response_motor%d", motorIdx))) + ...
        double(summaryTable.(sprintf("action_no_motion_motor%d", motorIdx))) + ...
        double(summaryTable.(sprintf("high_action_flat_response_motor%d", motorIdx)));
end
end

function [accepted, reason, motor2Accepted, allMotorAccepted, ...
        nonMotorRegression] = localEvaluateFrozenAcceptance(summaryTable)
accepted = false(height(summaryTable), 1);
reason = strings(height(summaryTable), 1);
motor2Accepted = false(height(summaryTable), 1);
allMotorAccepted = false(height(summaryTable), 1);
nonMotorRegression = false(height(summaryTable), 1);
baseline = summaryTable(summaryTable.configLabel == ...
    "agent7250_baseline_conversion", :);
if isempty(baseline)
    reason(:) = "missing_baseline_reference";
    return;
end

for i = 1:height(summaryTable)
    if summaryTable.configLabel(i) == "agent7250_baseline_conversion"
        reason(i) = "baseline_reference";
        motor2Accepted(i) = true;
        allMotorAccepted(i) = true;
        continue;
    end
    m2MseImproved = summaryTable.trackingMSE_motor2(i) < ...
        baseline.trackingMSE_motor2;
    m2RangeOk = summaryTable.responseRange_motor2(i) >= ...
        baseline.responseRange_motor2;
    m2FlagsOk = summaryTable.totalFlags_motor2(i) <= ...
        baseline.totalFlags_motor2 && summaryTable.totalFlags_motor2(i) == 0;
    m2NoHighFlatRegression = summaryTable.high_action_flat_response_motor2(i) <= ...
        baseline.high_action_flat_response_motor2;
    motor2Accepted(i) = m2MseImproved && m2RangeOk && ...
        m2FlagsOk && m2NoHighFlatRegression;

    nonTargetOk = true;
    for motorIdx = [1 3 4]
        mseField = sprintf("trackingMSE_motor%d", motorIdx);
        rangeField = sprintf("responseRange_motor%d", motorIdx);
        totalFlagsField = sprintf("totalFlags_motor%d", motorIdx);
        highFlatField = sprintf("high_action_flat_response_motor%d", motorIdx);
        thisMotorOk = ...
            summaryTable.(mseField)(i) <= 1.05 * baseline.(mseField) && ...
            summaryTable.(rangeField)(i) >= 0.95 * baseline.(rangeField) && ...
            summaryTable.(totalFlagsField)(i) <= baseline.(totalFlagsField) && ...
            summaryTable.(highFlatField)(i) <= baseline.(highFlatField);
        nonTargetOk = nonTargetOk && thisMotorOk;
    end
    nonMotorRegression(i) = ~nonTargetOk;
    highFlatOk = true;
    for motorIdx = 1:4
        fieldName = sprintf("high_action_flat_response_motor%d", motorIdx);
        highFlatOk = highFlatOk && summaryTable.(fieldName)(i) <= ...
            baseline.(fieldName);
    end
    globalOk = summaryTable.trackingMSE(i) <= baseline.trackingMSE;
    allMotorAccepted(i) = nonTargetOk && highFlatOk && globalOk;
    if m2MseImproved && m2RangeOk && summaryTable.totalFlags_motor2(i) > 0
        reason(i) = "m2_metrics_improved_but_flags_remain";
    elseif ~motor2Accepted(i)
        reason(i) = "motor2_acceptance_failed";
    elseif nonMotorRegression(i)
        reason(i) = "non_motor_regression_detected";
    elseif ~highFlatOk
        reason(i) = "high_action_flat_regression_detected";
    elseif ~globalOk
        reason(i) = "global_tracking_regression_detected";
    else
        reason(i) = "accepted";
    end
    accepted(i) = reason(i) == "accepted";
end
end

function localCreateAllMotorFigure(summaryTable, figurePath)
localEnsureParent(figurePath);
labels = categorical(string(summaryTable.configLabel));
labels = reordercats(labels, string(summaryTable.configLabel));
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 950]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
localGroupedBar(nexttile, labels, summaryTable, "trackingMSE", ...
    "Tracking MSE by motor");
localGroupedBar(nexttile, labels, summaryTable, "responseRange", ...
    "Response range by motor");
localGroupedBar(nexttile, labels, summaryTable, "saturationFraction", ...
    "Saturation fraction by motor");
flags = [ ...
    summaryTable.flat_response_motor1 + summaryTable.action_no_motion_motor1 + summaryTable.high_action_flat_response_motor1, ...
    summaryTable.flat_response_motor2 + summaryTable.action_no_motion_motor2 + summaryTable.high_action_flat_response_motor2, ...
    summaryTable.flat_response_motor3 + summaryTable.action_no_motion_motor3 + summaryTable.high_action_flat_response_motor3, ...
    summaryTable.flat_response_motor4 + summaryTable.action_no_motion_motor4 + summaryTable.high_action_flat_response_motor4];
bar(nexttile, labels, flags);
title("All-motor flags");
legend(["M1", "M2", "M3", "M4"], "Location", "best");
grid on;
sgtitle(f, "Frozen Agent7250 conversion evaluation");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateMotorDetailFigure(summaryTable, motorIdx, figurePath)
localEnsureParent(figurePath);
labels = categorical(string(summaryTable.configLabel));
labels = reordercats(labels, string(summaryTable.configLabel));
metrics = [ ...
    summaryTable.(sprintf("trackingMSE_motor%d", motorIdx)), ...
    summaryTable.(sprintf("responseRange_motor%d", motorIdx)), ...
    summaryTable.(sprintf("saturationFraction_motor%d", motorIdx)), ...
    double(summaryTable.(sprintf("flat_response_motor%d", motorIdx))) + ...
    double(summaryTable.(sprintf("action_no_motion_motor%d", motorIdx))) + ...
    double(summaryTable.(sprintf("high_action_flat_response_motor%d", motorIdx)))];
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
bar(labels, metrics);
legend(["trackingMSE", "responseRange", "saturation", "flags"], ...
    "Location", "best");
title(sprintf("Frozen Agent7250 motor %d detail", motorIdx));
grid on;
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localGroupedBar(ax, labels, tableValue, metricPrefix, plotTitle)
values = nan(height(tableValue), 4);
for motorIdx = 1:4
    values(:, motorIdx) = tableValue.(sprintf("%s_motor%d", ...
        metricPrefix, motorIdx));
end
bar(ax, labels, values);
title(ax, plotTitle);
legend(ax, ["M1", "M2", "M3", "M4"], "Location", "best");
grid(ax, "on");
end

function textValue = localBuildSummaryText(options, summaryTable)
lines = strings(0, 1);
lines(end+1) = "Frozen Agent7250 conversion evaluation";
lines(end+1) = "=======================================";
lines(end+1) = "";
lines(end+1) = "Training mode: Frozen Agent7250 evaluation";
lines(end+1) = "Initial agent source: Agent7250";
lines(end+1) = "Training from scratch: false";
lines(end+1) = "Warm-start from Agent7250: false";
lines(end+1) = "Agent frozen: true";
lines(end+1) = "Trainable actor parameters: 0";
lines(end+1) = "Trainable critic parameters: 0";
lines(end+1) = sprintf("Final test episodes: %d", options.finalTestEpisodes);
lines(end+1) = sprintf("Gap offsets: %s", mat2str(options.gapOffsets));
lines(end+1) = "";
for i = 1:height(summaryTable)
    lines(end+1) = sprintf( ...
        "%s | MSE=%.6f | M2 MSE=%.6f | M2 range=%.6f | M2 flags=%d | M4 MSE=%.6f | M4 range=%.6f | M4 flags=%d | accepted=%d | reason=%s", ...
        string(summaryTable.configLabel(i)), ...
        summaryTable.trackingMSE(i), ...
        summaryTable.trackingMSE_motor2(i), ...
        summaryTable.responseRange_motor2(i), ...
        summaryTable.totalFlags_motor2(i), ...
        summaryTable.trackingMSE_motor4(i), ...
        summaryTable.responseRange_motor4(i), ...
        summaryTable.totalFlags_motor4(i), ...
        summaryTable.acceptedFrozenConversion(i), ...
        string(summaryTable.selectionReason(i))); %#ok<AGROW>
end
textValue = strjoin(lines, newline);
end

function visualPath = localCopyVisualTestFigure(testRunDir, cfg, finalEpisode, visualRoot)
ensureDirectoryExists(visualRoot);
sourcePath = fullfile(testRunDir, "visual_episodes", ...
    sprintf("episode_%d.png", finalEpisode));
if ~isfile(sourcePath)
    files = dir(fullfile(testRunDir, "visual_episodes", "episode_*.png"));
    if isempty(files)
        visualPath = "";
        return;
    end
    [~, idx] = max([files.datenum]);
    sourcePath = fullfile(files(idx).folder, files(idx).name);
end
targetName = string(cfg.label) + "_episode_" + string(finalEpisode) + ...
    "_Agent7250_frozen_visual_test.png";
visualPath = fullfile(visualRoot, targetName);
metadataTitle = sprintf([ ...
    '%s | checkpoint=Agent7250 | frozen=true | episode=%d\n', ...
    'actionInterfaceVariant=baselineQuantized | actionPostprocessVariant=none | encoder2FlexVariant=%s | gapOffset=%s'], ...
    char(string(cfg.label)), finalEpisode, char(string(cfg.encoder2FlexVariant)), ...
    char(localGapText(cfg.gapOffset)));
localRenderVisualWithMetadata(sourcePath, visualPath, metadataTitle);
end

function localRenderVisualWithMetadata(sourcePath, targetPath, metadataTitle)
img = imread(sourcePath);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 900]);
ax = axes(f);
image(ax, img);
axis(ax, "image");
axis(ax, "off");
title(ax, metadataTitle, "Interpreter", "none", "FontSize", 10);
exportgraphics(f, targetPath, "Resolution", 180);
close(f);
end

function textValue = localGapText(gapOffset)
if isnan(gapOffset)
    textValue = "NaN";
else
    textValue = string(gapOffset);
end
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

function label = localOffsetLabel(offset)
if offset < 0
    label = "neg" + sprintf("%03d", abs(round(offset)));
else
    label = "pos" + sprintf("%03d", round(offset));
end
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
