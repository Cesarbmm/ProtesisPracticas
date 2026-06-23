function results = run_all_motor_visual_comparison_from_run(options)
%run_all_motor_visual_comparison_from_run rebuilds labeled visual reviews.
%
% It reads an existing ablation run and regenerates per-seed figures from
% episode*.mat files, with explicit metadata in file names and titles.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

options = localNormalizeOptions(options, workspaceRoot);
ensureDirectoryExists(options.outputFolder);
ensureDirectoryExists(options.docsOutputFolder);

configLabels = localNormalizeConfigLabels(options.configsToCompare);
rows = cell(numel(configLabels) * numel(options.seeds), 1);
rowIdx = 0;
comparisonFigures = strings(0, 1);

for configIdx = 1:numel(configLabels)
    configLabel = configLabels(configIdx);
    summaryPath = fullfile(options.runRoot, configLabel, "summary", ...
        "benchmark_seeded_summary.csv");
    if ~isfile(summaryPath)
        error("Config summary not found: %s", summaryPath);
    end
    seedTable = readtable(summaryPath, "TextType", "string");
    seedTable = seedTable(ismember(double(seedTable.seed), options.seeds), :);

    for seedIdx = 1:height(seedTable)
        seedValue = double(seedTable.seed(seedIdx));
        testRunDir = string(seedTable.finalTestRunDir(seedIdx));
        episodeFile = localSelectEpisodeFile(testRunDir, options.episodeToPlot);
        [target, response, actionAligned, episodeNumber] = ...
            localLoadEpisodeSignals(episodeFile);

        metadata = localBuildMetadata(seedTable(seedIdx, :), configLabel, ...
            options.runRoot, episodeNumber);
        safeMeta = localSafeName(sprintf("seed_%03d_episode_%03d_%s_%s_%s_ckpt_%04d", ...
            seedValue, episodeNumber, metadata.actionInterfaceVariant, ...
            metadata.encoder2FlexVariant, metadata.selectionMode, ...
            round(metadata.checkpointEpisode)));

        visualPath = fullfile(options.outputFolder, ...
            safeMeta + "_visual_test_all_motors.png");
        diagnosticPath = fullfile(options.outputFolder, ...
            safeMeta + "_motor_diagnostic_all_motors.png");
        actionPath = fullfile(options.outputFolder, ...
            safeMeta + "_action_vs_response_by_motor.png");

        localCreateVisualFigure(visualPath, target, response, metadata);
        localCreateDiagnosticFigure(diagnosticPath, target, response, ...
            actionAligned, metadata);
        localCreateActionFigure(actionPath, target, response, actionAligned, metadata);

        copyfile(visualPath, fullfile(options.docsOutputFolder, ...
            string(getFileName(visualPath))));
        copyfile(diagnosticPath, fullfile(options.docsOutputFolder, ...
            string(getFileName(diagnosticPath))));
        copyfile(actionPath, fullfile(options.docsOutputFolder, ...
            string(getFileName(actionPath))));

        rowIdx = rowIdx + 1;
        rows{rowIdx, 1} = struct( ...
            "seed", seedValue, ...
            "configLabel", configLabel, ...
            "episodeNumber", episodeNumber, ...
            "checkpointEpisode", metadata.checkpointEpisode, ...
            "finalTestRunDir", testRunDir, ...
            "visualFigurePath", string(visualPath), ...
            "diagnosticFigurePath", string(diagnosticPath), ...
            "actionFigurePath", string(actionPath));
    end
end

for seedValue = options.seeds
    comparisonPath = localCreateComparisonForSeed(options.runRoot, configLabels, ...
        seedValue, options.episodeToPlot, options.outputFolder);
    if strlength(comparisonPath) > 0
        comparisonFigures(end+1, 1) = comparisonPath; %#ok<AGROW>
        copyfile(comparisonPath, fullfile(options.docsOutputFolder, ...
            string(getFileName(comparisonPath))));
    end
end

rows = rows(~cellfun(@isempty, rows));
summaryTable = struct2table(vertcat(rows{:}));
summaryPath = fullfile(options.outputFolder, "all_motor_visual_review_summary.csv");
matPath = fullfile(options.outputFolder, "all_motor_visual_review_results.mat");
writetable(summaryTable, summaryPath);

results = struct();
results.runRoot = string(options.runRoot);
results.outputFolder = string(options.outputFolder);
results.docsOutputFolder = string(options.docsOutputFolder);
results.configLabels = configLabels;
results.seeds = options.seeds;
results.summaryTable = summaryTable;
results.comparisonFigures = comparisonFigures;
results.paths = struct("summaryCsv", string(summaryPath), "mat", string(matPath));
save(matPath, "results", "summaryTable", "options", "comparisonFigures");
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "runRoot", fullfile(workspaceRoot, "Agentes", ...
        "motor2_conversion_fix_ablation", "26-06-18_09-04-57"), ...
    "configsToCompare", ["baseline_quantized_conversion_baseline", ...
        "baseline_quantized_conversion_motor2_calibrated"], ...
    "seeds", [11 22 55], ...
    "episodeToPlot", NaN, ...
    "outputFolder", "", ...
    "docsOutputFolder", "");
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
options.runRoot = localResolvePath(string(options.runRoot), workspaceRoot);
options.configsToCompare = string(options.configsToCompare);
options.seeds = double(options.seeds(:))';
options.episodeToPlot = double(options.episodeToPlot);
if strlength(string(options.outputFolder)) == 0
    options.outputFolder = fullfile(options.runRoot, "figures", ...
        "all_motor_visual_review");
else
    options.outputFolder = localResolvePath(string(options.outputFolder), workspaceRoot);
end
if strlength(string(options.docsOutputFolder)) == 0
    options.docsOutputFolder = fullfile(workspaceRoot, "EMG_Prosthesis_TD3", ...
        "docs", "benchmark_motor2_diagnostic", "figures", ...
        "all_motor_review");
else
    options.docsOutputFolder = localResolvePath(string(options.docsOutputFolder), ...
        workspaceRoot);
end
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

function episodeFile = localSelectEpisodeFile(testRunDir, episodeToPlot)
files = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(files)
    error("No episode*.mat files found in %s", testRunDir);
end
numbers = nan(numel(files), 1);
for i = 1:numel(files)
    token = regexp(files(i).name, "episode(\d+)", "tokens", "once");
    if ~isempty(token)
        numbers(i) = str2double(token{1});
    end
end
if isfinite(episodeToPlot)
    [~, idx] = min(abs(numbers - episodeToPlot));
else
    [~, idx] = max(numbers);
    if isnan(numbers(idx))
        [~, idx] = max([files.datenum]);
    end
end
episodeFile = fullfile(files(idx).folder, files(idx).name);
end

function [target, response, actionAligned, episodeNumber] = ...
        localLoadEpisodeSignals(episodeFile)
data = load(episodeFile, "flexConvertedLog", "encoderAdjustedLog", ...
    "effectiveActionLog", "actionSatLog", "actionLog", "rawActionLog");
target = localEnsureFourColumns(localCellOrMatrixToRows(data.flexConvertedLog));
responseRaw = localEnsureFourColumns(localCellOrMatrixToRows(data.encoderAdjustedLog));
response = localAlignRows(responseRaw, size(target, 1));
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
actionAligned = localAlignRows(localEnsureFourColumns(double(actions)), ...
    size(target, 1));
token = regexp(string(episodeFile), "episode(\d+)", "tokens", "once");
if isempty(token)
    episodeNumber = NaN;
else
    episodeNumber = str2double(token{1});
end
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

function metadata = localBuildMetadata(seedRow, configLabel, runRoot, episodeNumber)
metadata = struct( ...
    "seed", double(seedRow.seed(1)), ...
    "episodeNumber", double(episodeNumber), ...
    "configLabel", string(configLabel), ...
    "actionInterfaceVariant", string(seedRow.actionInterfaceVariant(1)), ...
    "encoder2FlexVariant", string(seedRow.encoder2FlexVariant(1)), ...
    "selectionMode", string(seedRow.selectionMode(1)), ...
    "checkpointEpisode", double(seedRow.selectedCheckpointEpisode(1)), ...
    "runRoot", string(runRoot));
end

function localCreateVisualFigure(figurePath, target, response, metadata)
localEnsureParent(figurePath);
x = 1:size(target, 1);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1350 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
for motorIdx = 1:4
    ax = nexttile;
    plot(ax, x, target(:, motorIdx), "LineWidth", 1.3);
    hold(ax, "on");
    plot(ax, x, response(:, motorIdx), "LineWidth", 1.2);
    grid(ax, "on");
    title(ax, sprintf("M%d reference vs response", motorIdx));
    if motorIdx == 1
        legend(ax, ["Glove ref", "Simulated"], "Location", "best");
    end
end
sgtitle(f, localMetadataTitle(metadata, "Visual test all motors"), ...
    "Interpreter", "none");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateDiagnosticFigure(figurePath, target, response, actionAligned, metadata)
localEnsureParent(figurePath);
x = 1:size(target, 1);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 950]);
tiledlayout(f, 3, 4, "TileSpacing", "compact", "Padding", "compact");
for motorIdx = 1:4
    ax = nexttile(motorIdx);
    plot(ax, x, target(:, motorIdx), "LineWidth", 1.2);
    hold(ax, "on");
    plot(ax, x, response(:, motorIdx), "LineWidth", 1.2);
    title(ax, sprintf("M%d ref/response", motorIdx));
    grid(ax, "on");
    if motorIdx == 1
        legend(ax, ["Glove ref", "Simulated"], "Location", "best");
    end
    ax = nexttile(4 + motorIdx);
    plot(ax, x, response(:, motorIdx) - target(:, motorIdx), ...
        "LineWidth", 1.1);
    title(ax, sprintf("M%d error", motorIdx));
    grid(ax, "on");
    ax = nexttile(8 + motorIdx);
    plot(ax, x, actionAligned(:, motorIdx), "LineWidth", 1.1);
    ylim(ax, [-1.05 1.05]);
    title(ax, sprintf("M%d action", motorIdx));
    grid(ax, "on");
end
sgtitle(f, localMetadataTitle(metadata, "Motor diagnostic all motors"), ...
    "Interpreter", "none");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateActionFigure(figurePath, target, response, actionAligned, metadata)
localEnsureParent(figurePath);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 850]);
tiledlayout(f, 2, 4, "TileSpacing", "compact", "Padding", "compact");
for motorIdx = 1:4
    ax = nexttile(motorIdx);
    plot(ax, actionAligned(:, motorIdx), response(:, motorIdx), ".", ...
        "MarkerSize", 8);
    grid(ax, "on");
    xlabel(ax, "Action");
    ylabel(ax, "Response");
    title(ax, sprintf("M%d action-response", motorIdx));
    ax = nexttile(4 + motorIdx);
    plot(ax, actionAligned(:, motorIdx), response(:, motorIdx) - ...
        target(:, motorIdx), ".", "MarkerSize", 8);
    grid(ax, "on");
    xlabel(ax, "Action");
    ylabel(ax, "Error");
    title(ax, sprintf("M%d action-error", motorIdx));
end
sgtitle(f, localMetadataTitle(metadata, "Action vs response by motor"), ...
    "Interpreter", "none");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function comparisonPath = localCreateComparisonForSeed(runRoot, configLabels, ...
        seedValue, episodeToPlot, outputFolder)
if numel(configLabels) < 2
    comparisonPath = "";
    return;
end
payload = cell(2, 1);
metadata = cell(2, 1);
for i = 1:2
    summaryPath = fullfile(runRoot, configLabels(i), "summary", ...
        "benchmark_seeded_summary.csv");
    seedTable = readtable(summaryPath, "TextType", "string");
    row = seedTable(double(seedTable.seed) == seedValue, :);
    if isempty(row)
        comparisonPath = "";
        return;
    end
    episodeFile = localSelectEpisodeFile(row.finalTestRunDir(1), episodeToPlot);
    [target, response, actionAligned, episodeNumber] = ...
        localLoadEpisodeSignals(episodeFile);
    payload{i} = struct("target", target, "response", response, ...
        "action", actionAligned);
    metadata{i} = localBuildMetadata(row, configLabels(i), runRoot, episodeNumber);
end

comparisonPath = fullfile(outputFolder, sprintf( ...
    "seed_%03d_baseline_vs_motor2Calibrated_all_motor_comparison.png", ...
    seedValue));
localEnsureParent(comparisonPath);
x = 1:size(payload{1}.target, 1);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1600 1000]);
tiledlayout(f, 4, 2, "TileSpacing", "compact", "Padding", "compact");
for motorIdx = 1:4
    for cfgIdx = 1:2
        ax = nexttile;
        plot(ax, x, payload{cfgIdx}.target(:, motorIdx), "LineWidth", 1.1);
        hold(ax, "on");
        plot(ax, x, payload{cfgIdx}.response(:, motorIdx), "LineWidth", 1.1);
        yyaxis(ax, "right");
        plot(ax, x, payload{cfgIdx}.action(:, motorIdx), ":", "LineWidth", 0.9);
        ylim(ax, [-1.05 1.05]);
        yyaxis(ax, "left");
        grid(ax, "on");
        title(ax, sprintf("M%d - %s", motorIdx, metadata{cfgIdx}.configLabel), ...
            "Interpreter", "none");
        if motorIdx == 1 && cfgIdx == 1
            legend(ax, ["Glove ref", "Simulated", "Action"], "Location", "best");
        end
    end
end
sgtitle(f, sprintf( ...
    "Seed %03d comparison | %s | %s", seedValue, ...
    localMetadataTitle(metadata{1}, ""), localMetadataTitle(metadata{2}, "")), ...
    "Interpreter", "none");
exportgraphics(f, comparisonPath, "Resolution", 220);
close(f);
end

function titleText = localMetadataTitle(metadata, prefix)
titleText = sprintf( ...
    "%s | seed %03d | episode %d | action=%s | conversion=%s | selection=%s | checkpoint=%d | run=%s", ...
    prefix, metadata.seed, metadata.episodeNumber, ...
    metadata.actionInterfaceVariant, metadata.encoder2FlexVariant, ...
    metadata.selectionMode, round(metadata.checkpointEpisode), metadata.runRoot);
end

function safeName = localSafeName(value)
safeName = regexprep(string(value), "[^A-Za-z0-9_\\-]+", "_");
safeName = regexprep(safeName, "_+", "_");
end

function name = getFileName(filePath)
[~, base, ext] = fileparts(filePath);
name = string(base) + string(ext);
end

function localEnsureParent(filePath)
[parent, ~, ~] = fileparts(filePath);
if strlength(string(parent)) > 0 && ~exist(parent, "dir")
    mkdir(parent);
end
end
