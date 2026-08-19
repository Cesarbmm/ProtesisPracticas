function results = run_motor_reference_permutation_batch(testRunDirs, options)
%run_motor_reference_permutation_batch aggregates permutation checks.
%
% The helper does not change motor/reference mappings. It flags a suspicion
% only when a non-diagonal response wins by tracking MSE in most runs.

if nargin < 1 || isempty(testRunDirs)
    error("testRunDirs must contain one or more final test directories.");
end
if nargin < 2 || isempty(options)
    options = struct();
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

testRunDirs = string(testRunDirs);
testRunDirs = testRunDirs(:);

resultsRoot = fullfile(workspaceRoot, "Agentes", ...
    "motor_reference_permutation_batch", ...
    string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
if isfield(options, "resultsRoot") && strlength(string(options.resultsRoot)) > 0
    resultsRoot = char(string(options.resultsRoot));
end
summaryRoot = fullfile(resultsRoot, "summary");
figuresRoot = fullfile(resultsRoot, "figures");
ensureDirectoryExists(resultsRoot);
ensureDirectoryExists(summaryRoot);
ensureDirectoryExists(figuresRoot);

numRuns = numel(testRunDirs);
runResults = cell(numRuns, 1);
allRows = cell(numRuns, 1);
correlationStack = nan(4, 4, numRuns);
trackingMseStack = nan(4, 4, numRuns);
responseRangeStack = nan(4, 4, numRuns);

for runIdx = 1:numRuns
    runRoot = fullfile(resultsRoot, sprintf("run_%03d", runIdx));
    runResults{runIdx} = checkMotorReferencePermutation( ...
        testRunDirs(runIdx), struct("resultsRoot", string(runRoot)));
    tableRows = runResults{runIdx}.permutationTable;
    tableRows.runIndex = repmat(runIdx, height(tableRows), 1);
    tableRows.testRunDir = repmat(testRunDirs(runIdx), height(tableRows), 1);
    allRows{runIdx} = tableRows;
    correlationStack(:, :, runIdx) = runResults{runIdx}.correlationMatrix;
    trackingMseStack(:, :, runIdx) = runResults{runIdx}.trackingMseMatrix;
    responseRangeStack(:, :, runIdx) = runResults{runIdx}.responseRangeMatrix;
end

permutationTable = vertcat(allRows{:});
summaryTable = localBuildBatchSummary(permutationTable, numRuns);
meanCorrelation = mean(correlationStack, 3, "omitnan");
meanTrackingMse = mean(trackingMseStack, 3, "omitnan");
meanResponseRange = mean(responseRangeStack, 3, "omitnan");

summaryCsvPath = fullfile(summaryRoot, "permutation_batch_summary.csv");
matPath = fullfile(summaryRoot, "permutation_batch_results.mat");
heatmapPath = fullfile(figuresRoot, "permutation_batch_heatmap_mean.png");
writetable(summaryTable, summaryCsvPath);
writetable(permutationTable, fullfile(summaryRoot, "permutation_batch_all_rows.csv"));
localCreateMeanHeatmap(heatmapPath, meanCorrelation, meanTrackingMse, meanResponseRange);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.testRunDirs = testRunDirs;
results.runResults = runResults;
results.permutationTable = permutationTable;
results.summaryTable = summaryTable;
results.meanCorrelation = meanCorrelation;
results.meanTrackingMse = meanTrackingMse;
results.meanResponseRange = meanResponseRange;
results.summaryCsvPath = string(summaryCsvPath);
results.heatmapPath = string(heatmapPath);
results.mappingSuspicion = any(summaryTable.suspectedNonDiagonal);

save(matPath, "results", "summaryTable", "permutationTable", ...
    "meanCorrelation", "meanTrackingMse", "meanResponseRange");
end

function summaryTable = localBuildBatchSummary(permutationTable, numRuns)
rows = {};
rowIdx = 0;
for referenceMotor = 1:4
    winners = nan(numRuns, 1);
    for runIdx = 1:numRuns
        idx = permutationTable.referenceMotor == referenceMotor & ...
            permutationTable.runIndex == runIdx;
        subset = permutationTable(idx, :);
        if isempty(subset)
            continue;
        end
        [~, bestIdx] = min(subset.trackingMSE);
        winners(runIdx) = subset.responseMotor(bestIdx);
    end

    for responseMotor = 1:4
        winCount = sum(winners == responseMotor);
        rowIdx = rowIdx + 1;
        rows{rowIdx, 1} = struct( ...
            "referenceMotor", referenceMotor, ...
            "responseMotor", responseMotor, ...
            "winCount", winCount, ...
            "numRuns", numRuns, ...
            "winFraction", winCount / numRuns, ...
            "isDiagonal", responseMotor == referenceMotor, ...
            "suspectedNonDiagonal", ...
                responseMotor ~= referenceMotor && winCount > numRuns / 2);
    end
end
summaryTable = struct2table(vertcat(rows{:}));
end

function localCreateMeanHeatmap(figurePath, meanCorrelation, ...
        meanTrackingMse, meanResponseRange)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1450 820]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");
localHeatmap(nexttile, meanCorrelation, "Mean correlation");
localHeatmap(nexttile, meanTrackingMse, "Mean tracking MSE");
localHeatmap(nexttile, meanResponseRange, "Mean response range");
sgtitle(f, "Motor reference permutation batch");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localHeatmap(ax, matrixValues, plotTitle)
imagesc(ax, matrixValues);
colorbar(ax);
grid(ax, "on");
title(ax, plotTitle);
xlabel(ax, "Response motor");
ylabel(ax, "Reference motor");
set(ax, "XTick", 1:4, "XTickLabel", ["M1", "M2", "M3", "M4"]);
set(ax, "YTick", 1:4, "YTickLabel", ["M1", "M2", "M3", "M4"]);
end
