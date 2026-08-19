function results = run_motor2_encoder2flex_limit_sweep_diagnostic(options)
%run_motor2_encoder2flex_limit_sweep_diagnostic sweeps motor-2 limits.
%
% This workflow is simulation-only and performs no training. It runs the
% before/after conversion diagnostic across candidate motor-2 gap/break
% offsets and selects the most conservative accepted candidate.

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

rows = cell(numel(options.gapOffsets) * numel(options.breakOffsets), 1);
candidateResults = cell(size(rows));
rowIdx = 0;

for gapIdx = 1:numel(options.gapOffsets)
    for breakIdx = 1:numel(options.breakOffsets)
        rowIdx = rowIdx + 1;
        gapOffset = options.gapOffsets(gapIdx);
        breakOffset = options.breakOffsets(breakIdx);
        candidateLabel = localCandidateLabel(gapOffset, breakOffset);
        candidateRoot = fullfile(options.resultsRoot, "candidates", ...
            candidateLabel);
        candidateOptions = struct( ...
            "encoder2FlexVariant", ["baseline", "motor2Calibrated"], ...
            "initialMode", options.initialMode, ...
            "levels", options.levels, ...
            "duration", options.duration, ...
            "samplingPeriod", options.samplingPeriod, ...
            "normalizedFlatThreshold", options.normalizedFlatThreshold, ...
            "motor2Encoder2FlexGapOffset", gapOffset, ...
            "motor2Encoder2FlexBreakOffset", breakOffset, ...
            "motor2Encoder2FlexMinEffectiveEncoder", ...
                options.motor2Encoder2FlexMinEffectiveEncoder, ...
            "resultsRoot", string(candidateRoot));
        candidateResult = run_motor2_conversion_fix_diagnostic( ...
            candidateOptions);
        candidateResults{rowIdx} = candidateResult;
        rows{rowIdx} = localSummarizeCandidate( ...
            candidateLabel, gapOffset, breakOffset, candidateResult, ...
            options.lowActionLevel);
    end
end

sweepTable = struct2table(vertcat(rows{:}));
[selectedRow, selectionReason] = localSelectCandidate(sweepTable);
sweepTable.selectedCandidate = string(sweepTable.candidateLabel) == ...
    string(selectedRow.candidateLabel);

summaryCsvPath = fullfile(options.summaryRoot, ...
    "motor2_encoder2flex_limit_sweep.csv");
summaryTxtPath = fullfile(options.summaryRoot, ...
    "motor2_encoder2flex_limit_sweep.txt");
matPath = fullfile(options.summaryRoot, ...
    "motor2_encoder2flex_limit_sweep_results.mat");
scoreFigurePath = fullfile(options.figuresRoot, ...
    "motor2_encoder2flex_limit_sweep_score.png");
candidateFigurePath = fullfile(options.figuresRoot, ...
    "motor2_encoder2flex_selected_candidate.png");
regressionFigurePath = fullfile(options.figuresRoot, ...
    "motor2_encoder2flex_sweep_regression.png");

writetable(sweepTable, summaryCsvPath);
localWriteTextFile(summaryTxtPath, localBuildSummaryText( ...
    options, sweepTable, selectedRow, selectionReason));
localCreateScoreFigure(sweepTable, scoreFigurePath);
localCreateSelectedCandidateFigure(sweepTable, selectedRow, ...
    candidateFigurePath);
localCreateRegressionFigure(sweepTable, regressionFigurePath);

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.options = options;
results.sweepTable = sweepTable;
results.selectedCandidate = selectedRow;
results.selectionReason = selectionReason;
results.candidateResults = candidateResults;
results.summaryCsvPath = string(summaryCsvPath);
results.summaryTxtPath = string(summaryTxtPath);
results.matPath = string(matPath);
results.figurePaths = struct( ...
    "score", string(scoreFigurePath), ...
    "selectedCandidate", string(candidateFigurePath), ...
    "regression", string(regressionFigurePath));

save(matPath, "results", "sweepTable", "selectedRow", ...
    "selectionReason", "candidateResults", "options");
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "gapOffsets", [0 -32 -64 -96 -128 -192 -256], ...
    "breakOffsets", 0, ...
    "initialMode", "all", ...
    "levels", [-1.00 -0.75 -0.50 -0.25 0 0.25 0.50 0.75 1.00], ...
    "duration", 2.0, ...
    "samplingPeriod", 0.14, ...
    "lowActionLevel", 0.25, ...
    "normalizedFlatThreshold", 1e-4, ...
    "motor2Encoder2FlexMinEffectiveEncoder", 0, ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.gapOffsets = double(options.gapOffsets(:))';
options.breakOffsets = double(options.breakOffsets(:))';
options.initialMode = lower(string(options.initialMode));
options.levels = double(options.levels(:))';
options.duration = double(options.duration);
options.samplingPeriod = double(options.samplingPeriod);
options.lowActionLevel = double(options.lowActionLevel);
options.normalizedFlatThreshold = double(options.normalizedFlatThreshold);
options.motor2Encoder2FlexMinEffectiveEncoder = ...
    double(options.motor2Encoder2FlexMinEffectiveEncoder);

if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = char(string(options.resultsRoot));
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "motor2_encoder2flex_limit_sweep", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
end

function row = localSummarizeCandidate(candidateLabel, gapOffset, ...
        breakOffset, candidateResult, lowActionLevel)
regression = candidateResult.regression;
perMotor = regression.perMotorTable;
summary = regression.summary;
motor2 = perMotor(perMotor.motor == 2, :);

tableValue = candidateResult.beforeAfterTable;
baseLow = localFindMotor2Row(tableValue, "baseline", "home", lowActionLevel);
calLow = localFindMotor2Row(tableValue, "motor2Calibrated", "home", lowActionLevel);
baseHigh = localFindMotor2Row(tableValue, "baseline", "home", 1.00);
calHigh = localFindMotor2Row(tableValue, "motor2Calibrated", "home", 1.00);

motor2BaseRows = tableValue(tableValue.encoder2FlexVariant == "baseline" & ...
    tableValue.motor == 2, :);
motor2CalRows = tableValue(tableValue.encoder2FlexVariant == ...
    "motor2Calibrated" & tableValue.motor == 2, :);

row = struct( ...
    "candidateLabel", string(candidateLabel), ...
    "gapOffset", gapOffset, ...
    "breakOffset", breakOffset, ...
    "baselineGapIdx", 3650, ...
    "calibratedGapIdx", 3650 + gapOffset, ...
    "baselineBreakLimitIdx", 11500, ...
    "calibratedBreakLimitIdx", 11500 + breakOffset, ...
    "motor2RangeBefore", motor2.normalizedFlexRangeBefore, ...
    "motor2RangeAfter", motor2.normalizedFlexRangeAfter, ...
    "motor2PercentChange", motor2.percentChange, ...
    "motor2MaxAbsoluteDeviation", motor2.maxAbsoluteDeviation, ...
    "motor2LowActionRangeBefore", baseLow.normalizedFlexRange, ...
    "motor2LowActionRangeAfter", calLow.normalizedFlexRange, ...
    "motor2LowActionFlexRawBefore", baseLow.encoder2FlexRange, ...
    "motor2LowActionFlexRawAfter", calLow.encoder2FlexRange, ...
    "motor2HighActionRangeBefore", baseHigh.normalizedFlexRange, ...
    "motor2HighActionRangeAfter", calHigh.normalizedFlexRange, ...
    "motor2FlatRowsBefore", sum(motor2BaseRows.flattenStage ~= "responsive"), ...
    "motor2FlatRowsAfter", sum(motor2CalRows.flattenStage ~= "responsive"), ...
    "motor1_regression", summary.motor1_regression, ...
    "motor3_regression", summary.motor3_regression, ...
    "motor4_regression", summary.motor4_regression, ...
    "motor2_improved", summary.motor2_improved, ...
    "sign_error_detected", summary.sign_error_detected, ...
    "calibration_accepted", summary.calibration_accepted, ...
    "candidateScore", localCandidateScore(summary, motor2, baseLow, calLow));
end

function row = localFindMotor2Row(tableValue, variantName, initialMode, actionLevel)
idx = tableValue.encoder2FlexVariant == variantName & ...
    tableValue.motor == 2 & ...
    string(tableValue.initialMode) == string(initialMode) & ...
    abs(tableValue.rawAction - actionLevel) < 1e-12;
if any(idx)
    row = tableValue(find(idx, 1), :);
else
    row = tableValue(1, :);
    row.normalizedFlexRange = NaN;
    row.encoder2FlexRange = NaN;
end
end

function score = localCandidateScore(summary, motor2, baseLow, calLow)
score = 0;
if summary.calibration_accepted
    score = score + 10;
end
if calLow.normalizedFlexRange > baseLow.normalizedFlexRange
    score = score + 5;
end
score = score + double(motor2.normalizedFlexRangeAfter - ...
    motor2.normalizedFlexRangeBefore);
score = score - 0.25 * double(motor2.maxAbsoluteDeviation);
if summary.sign_error_detected
    score = score - 20;
end
end

function [selectedRow, reason] = localSelectCandidate(sweepTable)
candidateRows = sweepTable(logical(sweepTable.calibration_accepted) & ...
    sweepTable.motor2LowActionRangeAfter > ...
        sweepTable.motor2LowActionRangeBefore & ...
    ~logical(sweepTable.sign_error_detected), :);
if isempty(candidateRows)
    [~, idx] = max(sweepTable.candidateScore);
    selectedRow = sweepTable(idx, :);
    reason = "best_score_no_candidate_met_all_acceptance_rules";
    return;
end

rankMatrix = [ ...
    abs(candidateRows.gapOffset), ...
    abs(candidateRows.breakOffset), ...
    -candidateRows.motor2LowActionRangeAfter, ...
    -candidateRows.motor2RangeAfter];
[~, order] = sortrows(rankMatrix);
selectedRow = candidateRows(order(1), :);
reason = "most_conservative_accepted_low_action_recovery";
end

function label = localCandidateLabel(gapOffset, breakOffset)
label = sprintf("gap_%+04d_break_%+04d", round(gapOffset), ...
    round(breakOffset));
label = strrep(label, "+", "p");
label = strrep(label, "-", "m");
end

function localCreateScoreFigure(sweepTable, figurePath)
localEnsureFigureDir(figurePath);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 850]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");

scatter(nexttile, sweepTable.gapOffset, sweepTable.motor2LowActionRangeAfter, ...
    75, double(sweepTable.calibration_accepted), "filled");
grid on;
title("Motor 2 low-action recovery");
xlabel("gap offset");
ylabel("home action 0.25 normalized range");

scatter(nexttile, sweepTable.gapOffset, sweepTable.motor2RangeAfter, ...
    75, sweepTable.motor2MaxAbsoluteDeviation, "filled");
colorbar;
grid on;
title("Motor 2 mean range vs deviation");
xlabel("gap offset");
ylabel("mean normalized range");

bar(nexttile, categorical(string(sweepTable.candidateLabel)), ...
    sweepTable.candidateScore);
title("Candidate score");
grid on;
xtickangle(45);

sgtitle(f, "Motor 2 encoder2Flex limit sweep");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateSelectedCandidateFigure(sweepTable, selectedRow, figurePath)
localEnsureFigureDir(figurePath);
baseline = sweepTable(sweepTable.gapOffset == 0 & sweepTable.breakOffset == 0, :);
if isempty(baseline)
    baseline = sweepTable(1, :);
end

labels = categorical(["baseline", "selected"]);
values = [ ...
    baseline.motor2RangeAfter, selectedRow.motor2RangeAfter; ...
    baseline.motor2LowActionRangeAfter, selectedRow.motor2LowActionRangeAfter; ...
    baseline.motor2MaxAbsoluteDeviation, selectedRow.motor2MaxAbsoluteDeviation];

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 800]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");
metricNames = ["Mean range", "Low-action range", "Max abs deviation"];
for i = 1:numel(metricNames)
    bar(nexttile, labels, values(i, :));
    title(metricNames(i));
    grid on;
end
sgtitle(f, "Selected encoder2Flex candidate: " + ...
    string(selectedRow.candidateLabel));
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateRegressionFigure(sweepTable, figurePath)
localEnsureFigureDir(figurePath);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 800]);
labels = categorical(string(sweepTable.candidateLabel));
tiledlayout(f, 1, 2, "TileSpacing", "compact", "Padding", "compact");
bar(nexttile, labels, [sweepTable.motor1_regression, ...
    sweepTable.motor3_regression, sweepTable.motor4_regression, ...
    sweepTable.sign_error_detected]);
title("Regression/sign flags");
legend(["M1", "M3", "M4", "sign"], "Location", "best");
grid on;
xtickangle(45);

bar(nexttile, labels, [sweepTable.motor2FlatRowsBefore, ...
    sweepTable.motor2FlatRowsAfter]);
title("Motor 2 non-responsive rows");
legend(["before", "after"], "Location", "best");
grid on;
xtickangle(45);
sgtitle(f, "Limit sweep regression overview");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function text = localBuildSummaryText(options, sweepTable, selectedRow, reason)
lines = strings(height(sweepTable) + 16, 1);
lineIdx = 0;
lineIdx = lineIdx + 1;
lines(lineIdx) = "Motor 2 encoder2Flex limit sweep";
lineIdx = lineIdx + 1;
lines(lineIdx) = "Results root: " + string(options.resultsRoot);
lineIdx = lineIdx + 1;
lines(lineIdx) = "Gap offsets: " + mat2str(options.gapOffsets);
lineIdx = lineIdx + 1;
lines(lineIdx) = "Break offsets: " + mat2str(options.breakOffsets);
lineIdx = lineIdx + 1;
lines(lineIdx) = "Selected: " + string(selectedRow.candidateLabel);
lineIdx = lineIdx + 1;
lines(lineIdx) = "Selection reason: " + reason;
lineIdx = lineIdx + 1;
lines(lineIdx) = sprintf( ...
    "Selected gap.idx=%g, breakLimit.idx=%g", ...
    selectedRow.calibratedGapIdx, selectedRow.calibratedBreakLimitIdx);
lineIdx = lineIdx + 1;
lines(lineIdx) = sprintf( ...
    "Selected motor2 mean range %.6f -> %.6f", ...
    selectedRow.motor2RangeBefore, selectedRow.motor2RangeAfter);
lineIdx = lineIdx + 1;
lines(lineIdx) = sprintf( ...
    "Selected motor2 low-action range %.6f -> %.6f", ...
    selectedRow.motor2LowActionRangeBefore, ...
    selectedRow.motor2LowActionRangeAfter);
lineIdx = lineIdx + 1;
lines(lineIdx) = "";

for i = 1:height(sweepTable)
    lineIdx = lineIdx + 1;
    lines(lineIdx) = sprintf( ...
        "%s: gap=%g, break=%g, low=%.6f, range=%.6f, accepted=%d, score=%.3f", ...
        string(sweepTable.candidateLabel(i)), ...
        sweepTable.gapOffset(i), sweepTable.breakOffset(i), ...
        sweepTable.motor2LowActionRangeAfter(i), ...
        sweepTable.motor2RangeAfter(i), ...
        sweepTable.calibration_accepted(i), sweepTable.candidateScore(i));
end

lines = lines(1:lineIdx);
text = strjoin(lines, newline);
end

function localEnsureFigureDir(figurePath)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
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
