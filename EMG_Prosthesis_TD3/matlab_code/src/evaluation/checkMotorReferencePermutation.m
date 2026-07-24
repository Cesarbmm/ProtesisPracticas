function results = checkMotorReferencePermutation(testRunDir, options)
%checkMotorReferencePermutation compares every glove reference to every response.

arguments
    testRunDir (1, 1) string
    options = struct()
end

if ~isfolder(testRunDir)
    error("Test run directory not found: %s", testRunDir);
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));

resultsRoot = fullfile(testRunDir, "motor_reference_permutation");
if isfield(options, "resultsRoot") && strlength(string(options.resultsRoot)) > 0
    resultsRoot = char(string(options.resultsRoot));
end
ensureDirectoryExists(resultsRoot);

episodeFiles = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(episodeFiles)
    error("No episode*.mat files found in %s", testRunDir);
end

targetAll = [];
responseAll = [];
for episodeIdx = 1:numel(episodeFiles)
    episodeFile = fullfile(episodeFiles(episodeIdx).folder, episodeFiles(episodeIdx).name);
    data = load(episodeFile, "flexConvertedLog", "encoderAdjustedLog");
    if ~isfield(data, "flexConvertedLog") || ~isfield(data, "encoderAdjustedLog")
        continue;
    end
    target = localCellOrMatrixToRows(data.flexConvertedLog);
    responseRaw = localCellOrMatrixToRows(data.encoderAdjustedLog);
    target = localEnsureFourColumns(target);
    response = localAlignRows(localEnsureFourColumns(responseRaw), size(target, 1));
    targetAll = [targetAll; target]; %#ok<AGROW>
    responseAll = [responseAll; response]; %#ok<AGROW>
end

if isempty(targetAll) || isempty(responseAll)
    error("No valid target/response samples were found in %s", testRunDir);
end

numMotors = 4;
correlationMatrix = nan(numMotors, numMotors);
trackingMseMatrix = nan(numMotors, numMotors);
responseRangeMatrix = nan(numMotors, numMotors);
targetRangeMatrix = nan(numMotors, numMotors);
rows = cell(numMotors * numMotors, 1);
rowIdx = 0;

for refMotor = 1:numMotors
    ref = targetAll(:, refMotor);
    for responseMotor = 1:numMotors
        response = responseAll(:, responseMotor);
        correlationValue = localCorrelation(ref, response);
        trackingMse = mean((response - ref).^2, "omitnan");
        responseRange = localRange(response);
        targetRange = localRange(ref);

        correlationMatrix(refMotor, responseMotor) = correlationValue;
        trackingMseMatrix(refMotor, responseMotor) = trackingMse;
        responseRangeMatrix(refMotor, responseMotor) = responseRange;
        targetRangeMatrix(refMotor, responseMotor) = targetRange;

        rowIdx = rowIdx + 1;
        rows{rowIdx} = struct( ...
            "referenceMotor", refMotor, ...
            "responseMotor", responseMotor, ...
            "correlation", correlationValue, ...
            "trackingMSE", trackingMse, ...
            "responseRange", responseRange, ...
            "targetRange", targetRange);
    end
end

permutationTable = struct2table(vertcat(rows{:}));
csvPath = fullfile(resultsRoot, "motor_reference_permutation_matrix.csv");
figurePath = fullfile(resultsRoot, "motor_reference_permutation_matrix.png");
writetable(permutationTable, csvPath);
localCreatePermutationFigure(figurePath, correlationMatrix, trackingMseMatrix, responseRangeMatrix);

results = struct();
results.testRunDir = string(testRunDir);
results.resultsRoot = string(resultsRoot);
results.csvPath = string(csvPath);
results.figurePath = string(figurePath);
results.permutationTable = permutationTable;
results.correlationMatrix = correlationMatrix;
results.trackingMseMatrix = trackingMseMatrix;
results.responseRangeMatrix = responseRangeMatrix;
results.targetRangeMatrix = targetRangeMatrix;

save(fullfile(resultsRoot, "motor_reference_permutation_results.mat"), "results");
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

function value = localRange(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x) - min(x);
end
end

function value = localCorrelation(x, y)
mask = isfinite(x) & isfinite(y);
x = x(mask);
y = y(mask);
if numel(x) < 2 || std(x) == 0 || std(y) == 0
    value = NaN;
    return;
end
c = corrcoef(x, y);
value = c(1, 2);
end

function localCreatePermutationFigure(figurePath, correlationMatrix, trackingMseMatrix, responseRangeMatrix)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1450 820]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");
localHeatmap(nexttile, correlationMatrix, "Correlation");
localHeatmap(nexttile, trackingMseMatrix, "Tracking MSE");
localHeatmap(nexttile, responseRangeMatrix, "Response range");
sgtitle(f, "Motor reference permutation check");
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
