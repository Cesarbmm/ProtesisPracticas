function results = run_compare_against_canonical_benchmark_all_motor(options)
%run_compare_against_canonical_benchmark_all_motor compares all motors.
%
% The workflow is simulation-only. It compares Agent7250 against selected
% checkpoints from an existing conversion-fix ablation run using per-motor
% diagnostics and visual tests.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

options = localNormalizeOptions(options, workspaceRoot);
ensureDirectoryExists(options.resultsRoot);
ensureDirectoryExists(options.summaryRoot);
ensureDirectoryExists(options.figuresRoot);

rows = {};
rowIdx = 0;
agent7250Root = fullfile(options.resultsRoot, "reference_tests", "Agent7250");
ensureDirectoryExists(agent7250Root);
runCheckpointTest(getAgent7250CheckpointPath(), options.finalTestEpisodes, ...
    options.plotEpisodeOnTest, struct("resultsRoot", string(agent7250Root)));
agent7250RunDir = localFindNewestSubdir(agent7250Root);
rowIdx = rowIdx + 1;
rows{rowIdx, 1} = localBuildComparisonRow("Agent7250", ...
    "official_benchmark", getAgent7250CheckpointPath(), 7250, ...
    agent7250RunDir);

configLabels = localNormalizeConfigLabels(options.configsToCompare);
for configIdx = 1:numel(configLabels)
    configLabel = configLabels(configIdx);
    summaryPath = fullfile(options.runRoot, configLabel, "summary", ...
        "benchmark_seeded_summary.csv");
    if ~isfile(summaryPath)
        warning("Config summary not found: %s", summaryPath);
        continue;
    end
    seedTable = readtable(summaryPath, "TextType", "string");
    seedTable = seedTable(ismember(double(seedTable.seed), options.seeds), :);
    for seedIdx = 1:height(seedTable)
        if options.rerunCurrentCheckpoints
            rerunRoot = fullfile(options.resultsRoot, "current_tests", ...
                configLabel, seedTable.seedLabel(seedIdx));
            ensureDirectoryExists(rerunRoot);
            runCheckpointTest(seedTable.selectedCheckpointPath(seedIdx), ...
                options.finalTestEpisodes, options.plotEpisodeOnTest, ...
                struct("resultsRoot", string(rerunRoot)));
            runDir = localFindNewestSubdir(rerunRoot);
        else
            runDir = string(seedTable.finalTestRunDir(seedIdx));
        end
        label = sprintf("%s_seed_%03d", configLabel, double(seedTable.seed(seedIdx)));
        rowIdx = rowIdx + 1;
        rows{rowIdx, 1} = localBuildComparisonRow(label, configLabel, ...
            seedTable.selectedCheckpointPath(seedIdx), ...
            double(seedTable.selectedCheckpointEpisode(seedIdx)), runDir);
    end
end

comparisonTable = struct2table(vertcat(rows{:}));
summaryPath = fullfile(options.summaryRoot, ...
    "canonical_benchmark_all_motor_comparison.csv");
matPath = fullfile(options.summaryRoot, ...
    "canonical_benchmark_all_motor_comparison_results.mat");
figurePath = fullfile(options.figuresRoot, "canonical_vs_current_all_motor.png");
visualPath = fullfile(options.figuresRoot, ...
    "canonical_vs_current_visual_seed_or_episode.png");

writetable(comparisonTable, summaryPath);
localCreateComparisonFigure(comparisonTable, figurePath);
localCreateCanonicalVisualFigure(comparisonTable, visualPath);

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.options = options;
results.comparisonTable = comparisonTable;
results.paths = struct( ...
    "comparisonCsv", string(summaryPath), ...
    "comparisonFigure", string(figurePath), ...
    "visualFigure", string(visualPath), ...
    "mat", string(matPath));
save(matPath, "results", "comparisonTable", "options");
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "runRoot", fullfile(workspaceRoot, "Agentes", ...
        "motor2_conversion_fix_ablation", "26-06-18_09-04-57"), ...
    "configsToCompare", [ ...
        "baseline_quantized_conversion_baseline", ...
        "baseline_quantized_conversion_motor2_calibrated", ...
        "motor_calibrated_quantized_conversion_baseline", ...
        "motor_calibrated_quantized_conversion_motor2_calibrated"], ...
    "seeds", [11 22 55], ...
    "finalTestEpisodes", 20, ...
    "plotEpisodeOnTest", true, ...
    "rerunCurrentCheckpoints", false, ...
    "resultsRoot", "");
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
options.runRoot = localResolvePath(string(options.runRoot), workspaceRoot);
options.configsToCompare = string(options.configsToCompare);
options.seeds = double(options.seeds(:))';
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.plotEpisodeOnTest = logical(options.plotEpisodeOnTest);
options.rerunCurrentCheckpoints = logical(options.rerunCurrentCheckpoints);
if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = localResolvePath(string(options.resultsRoot), workspaceRoot);
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "canonical_benchmark_all_motor_comparison", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
end

function pathValue = localResolvePath(pathValue, workspaceRoot)
pathValue = string(pathValue);
if isfolder(pathValue) || startsWith(pathValue, workspaceRoot) || ...
        contains(pathValue, ":\")
    pathValue = char(pathValue);
else
    pathValue = fullfile(workspaceRoot, char(pathValue));
end
end

function labels = localNormalizeConfigLabels(labels)
labels = string(labels);
for i = 1:numel(labels)
    switch labels(i)
        case "baseline_baseline"
            labels(i) = "baseline_quantized_conversion_baseline";
        case "baseline_motor2Calibrated"
            labels(i) = "baseline_quantized_conversion_motor2_calibrated";
    end
end
end

function row = localBuildComparisonRow(label, kind, checkpointPath, ...
        checkpointEpisode, testRunDir)
analysis = analyzeExperimentRun(string(testRunDir));
[diagnostic, ~] = analyzeMotor2Diagnostic(string(testRunDir), "");
row = struct( ...
    "candidateLabel", string(label), ...
    "candidateKind", string(kind), ...
    "checkpointPath", string(checkpointPath), ...
    "checkpointEpisode", double(checkpointEpisode), ...
    "testRunDir", string(testRunDir), ...
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
end

function localCreateComparisonFigure(comparisonTable, figurePath)
localEnsureParent(figurePath);
labels = categorical(string(comparisonTable.candidateLabel));
labels = reordercats(labels, string(comparisonTable.candidateLabel));
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 950]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
bar(nexttile, labels, comparisonTable.trackingMSE);
title("Global tracking MSE");
grid on;
motor2Mse = [comparisonTable.trackingMSE_motor1, comparisonTable.trackingMSE_motor2, ...
    comparisonTable.trackingMSE_motor3, comparisonTable.trackingMSE_motor4];
bar(nexttile, labels, motor2Mse);
title("Tracking MSE by motor");
legend(["M1", "M2", "M3", "M4"], "Location", "best");
grid on;
ranges = [comparisonTable.responseRange_motor1, comparisonTable.responseRange_motor2, ...
    comparisonTable.responseRange_motor3, comparisonTable.responseRange_motor4];
bar(nexttile, labels, ranges);
title("Response range by motor");
legend(["M1", "M2", "M3", "M4"], "Location", "best");
grid on;
flags = [comparisonTable.flat_response_motor1 + comparisonTable.action_no_motion_motor1 + comparisonTable.high_action_flat_response_motor1, ...
    comparisonTable.flat_response_motor2 + comparisonTable.action_no_motion_motor2 + comparisonTable.high_action_flat_response_motor2, ...
    comparisonTable.flat_response_motor3 + comparisonTable.action_no_motion_motor3 + comparisonTable.high_action_flat_response_motor3, ...
    comparisonTable.flat_response_motor4 + comparisonTable.action_no_motion_motor4 + comparisonTable.high_action_flat_response_motor4];
bar(nexttile, labels, flags);
title("All-motor flags");
legend(["M1", "M2", "M3", "M4"], "Location", "best");
grid on;
sgtitle(f, "Canonical benchmark vs current all-motor diagnostics");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateCanonicalVisualFigure(comparisonTable, figurePath)
localEnsureParent(figurePath);
if height(comparisonTable) < 2
    return;
end
rows = comparisonTable([1 2], :);
payload = cell(2, 1);
for i = 1:2
    episodeFile = localSelectLastEpisode(rows.testRunDir(i));
    payload{i} = localLoadEpisodeSignals(episodeFile);
end
x = 1:size(payload{1}.target, 1);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 1000]);
tiledlayout(f, 4, 2, "TileSpacing", "compact", "Padding", "compact");
for motorIdx = 1:4
    for colIdx = 1:2
        ax = nexttile;
        plot(ax, x, payload{colIdx}.target(:, motorIdx), "LineWidth", 1.1);
        hold(ax, "on");
        plot(ax, x, payload{colIdx}.response(:, motorIdx), "LineWidth", 1.1);
        yyaxis(ax, "right");
        plot(ax, x, payload{colIdx}.action(:, motorIdx), ":", "LineWidth", 0.9);
        ylim(ax, [-1.05 1.05]);
        yyaxis(ax, "left");
        grid(ax, "on");
        title(ax, sprintf("M%d - %s", motorIdx, rows.candidateLabel(colIdx)), ...
            "Interpreter", "none");
    end
end
sgtitle(f, "Agent7250 vs first current checkpoint visual comparison", ...
    "Interpreter", "none");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
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

function episodeFile = localSelectLastEpisode(testRunDir)
files = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(files)
    error("No episode files found in %s", testRunDir);
end
numbers = nan(numel(files), 1);
for i = 1:numel(files)
    token = regexp(files(i).name, "episode(\d+)", "tokens", "once");
    if ~isempty(token)
        numbers(i) = str2double(token{1});
    end
end
[~, idx] = max(numbers);
if isnan(numbers(idx))
    [~, idx] = max([files.datenum]);
end
episodeFile = fullfile(files(idx).folder, files(idx).name);
end

function payload = localLoadEpisodeSignals(episodeFile)
data = load(episodeFile, "flexConvertedLog", "encoderAdjustedLog", ...
    "effectiveActionLog", "actionSatLog", "actionLog", "rawActionLog");
target = localEnsureFourColumns(localCellOrMatrixToRows(data.flexConvertedLog));
response = localAlignRows(localEnsureFourColumns( ...
    localCellOrMatrixToRows(data.encoderAdjustedLog)), size(target, 1));
if isfield(data, "effectiveActionLog")
    actions = data.effectiveActionLog;
elseif isfield(data, "actionSatLog")
    actions = data.actionSatLog;
elseif isfield(data, "actionLog")
    actions = data.actionLog;
elseif isfield(data, "rawActionLog")
    actions = data.rawActionLog;
else
    actions = nan(size(target, 1), 4);
end
payload = struct( ...
    "target", target, ...
    "response", response, ...
    "action", localAlignRows(localEnsureFourColumns(double(actions)), ...
    size(target, 1)));
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
if size(value, 1) == targetRows
    aligned = value;
elseif size(value, 1) == 1
    aligned = repmat(value, targetRows, 1);
else
    aligned = interp1(linspace(1, targetRows, size(value, 1)), ...
        value, 1:targetRows, "linear", "extrap");
end
end

function localEnsureParent(filePath)
[parent, ~, ~] = fileparts(filePath);
if strlength(string(parent)) > 0 && ~exist(parent, "dir")
    mkdir(parent);
end
end
