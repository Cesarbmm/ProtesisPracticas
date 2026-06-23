function [diagnostic, metricsByMotor] = analyzeMotor2Diagnostic(testRunDir, figurePath, options)
%analyzeMotor2Diagnostic computes per-motor tracking and action diagnostics.

arguments
    testRunDir (1, 1) string
    figurePath (1, 1) string = ""
    options = struct()
end

if ~isfolder(testRunDir)
    error("Test run directory not found: %s", testRunDir);
end
if ~isstruct(options)
    error("options must be a struct.");
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));

episodeFiles = dir(fullfile(testRunDir, "episode*.mat"));
if isempty(episodeFiles)
    error("No episode*.mat files found in %s", testRunDir);
end
[episodeFiles, episodeNumbers] = localSortEpisodeFiles(episodeFiles);

numEpisodes = numel(episodeFiles);
numMotors = 4;
trackingMSE = nan(numEpisodes, numMotors);
trackingMAE = nan(numEpisodes, numMotors);
actionL2 = nan(numEpisodes, numMotors);
deltaActionL2 = nan(numEpisodes, numMotors);
saturationFraction = nan(numEpisodes, numMotors);
actionRange = nan(numEpisodes, numMotors);
responseRange = nan(numEpisodes, numMotors);
targetRange = nan(numEpisodes, numMotors);
correlationValue = nan(numEpisodes, numMotors);

for episodeIdx = 1:numEpisodes
    episodeFile = fullfile(episodeFiles(episodeIdx).folder, episodeFiles(episodeIdx).name);
    data = localLoadEpisodeData(episodeFile);
    [target, response, ~, actionSteps] = localExtractAlignedSignals(data);

    for motorIdx = 1:numMotors
        targetMotor = target(:, motorIdx);
        responseMotor = response(:, motorIdx);
        actionMotor = actionSteps(:, motorIdx);
        errorMotor = responseMotor - targetMotor;

        trackingMSE(episodeIdx, motorIdx) = mean(errorMotor.^2, "omitnan");
        trackingMAE(episodeIdx, motorIdx) = mean(abs(errorMotor), "omitnan");
        actionL2(episodeIdx, motorIdx) = sqrt(mean(actionMotor.^2, "omitnan"));
        if size(actionSteps, 1) >= 2
            deltaActionL2(episodeIdx, motorIdx) = ...
                sqrt(mean(diff(actionMotor).^2, "omitnan"));
        else
            deltaActionL2(episodeIdx, motorIdx) = 0;
        end
        saturationFraction(episodeIdx, motorIdx) = ...
            mean(abs(actionMotor) >= 0.95, "omitnan");
        actionRange(episodeIdx, motorIdx) = localRange(actionMotor);
        responseRange(episodeIdx, motorIdx) = localRange(responseMotor);
        targetRange(episodeIdx, motorIdx) = localRange(targetMotor);
        correlationValue(episodeIdx, motorIdx) = ...
            localCorrelation(targetMotor, responseMotor);

    end
end

metricMeans = struct();
metricMeans.trackingMSE = mean(trackingMSE, 1, "omitnan");
metricMeans.trackingMAE = mean(trackingMAE, 1, "omitnan");
metricMeans.actionL2 = mean(actionL2, 1, "omitnan");
metricMeans.deltaActionL2 = mean(deltaActionL2, 1, "omitnan");
metricMeans.saturationFraction = mean(saturationFraction, 1, "omitnan");
metricMeans.actionRange = mean(actionRange, 1, "omitnan");
metricMeans.responseRange = mean(responseRange, 1, "omitnan");
metricMeans.targetRange = mean(targetRange, 1, "omitnan");
metricMeans.correlation = mean(correlationValue, 1, "omitnan");
metricMeans.flatResponse = false(1, numMotors);
metricMeans.actionNoMotion = false(1, numMotors);
metricMeans.highActionFlatResponse = false(1, numMotors);
for motorIdx = 1:numMotors
    metricMeans.flatResponse(motorIdx) = ...
        localMotorFlatResponse(metricMeans, motorIdx);
    metricMeans.actionNoMotion(motorIdx) = ...
        localMotorActionNoMotion(metricMeans, motorIdx);
    metricMeans.highActionFlatResponse(motorIdx) = ...
        localMotorHighActionFlatResponse(metricMeans, motorIdx, options);
end

motor = (1:numMotors)';
trackingMSEColumn = metricMeans.trackingMSE(:);
trackingMAEColumn = metricMeans.trackingMAE(:);
actionL2Column = metricMeans.actionL2(:);
deltaActionL2Column = metricMeans.deltaActionL2(:);
saturationFractionColumn = metricMeans.saturationFraction(:);
actionRangeColumn = metricMeans.actionRange(:);
responseRangeColumn = metricMeans.responseRange(:);
targetRangeColumn = metricMeans.targetRange(:);
correlationColumn = metricMeans.correlation(:);
flatResponseColumn = metricMeans.flatResponse(:);
actionNoMotionColumn = metricMeans.actionNoMotion(:);
highActionFlatResponseColumn = metricMeans.highActionFlatResponse(:);
metricsByMotor = table( ...
    motor, trackingMSEColumn, trackingMAEColumn, actionL2Column, ...
    deltaActionL2Column, saturationFractionColumn, actionRangeColumn, ...
    responseRangeColumn, ...
    targetRangeColumn, correlationColumn, flatResponseColumn, ...
    actionNoMotionColumn, highActionFlatResponseColumn, ...
    'VariableNames', {'motor', 'trackingMSE', 'trackingMAE', 'actionL2', ...
    'deltaActionL2', 'saturationFraction', 'actionRange', 'responseRange', ...
    'targetRange', 'correlation', 'flatResponse', 'actionNoMotion', ...
    'highActionFlatResponse'});

diagnostic = struct();
diagnostic.testRunDir = string(testRunDir);
diagnostic.numEpisodes = numEpisodes;
diagnostic.episodeNumbers = episodeNumbers(:);
diagnostic.metricsByMotor = metricsByMotor;
diagnostic.figurePath = string(figurePath);

for motorIdx = 1:numMotors
    diagnostic.(sprintf("trackingMSE_motor%d", motorIdx)) = metricMeans.trackingMSE(motorIdx);
    diagnostic.(sprintf("trackingMAE_motor%d", motorIdx)) = metricMeans.trackingMAE(motorIdx);
    diagnostic.(sprintf("actionL2_motor%d", motorIdx)) = metricMeans.actionL2(motorIdx);
    diagnostic.(sprintf("deltaActionL2_motor%d", motorIdx)) = metricMeans.deltaActionL2(motorIdx);
    diagnostic.(sprintf("saturationFraction_motor%d", motorIdx)) = metricMeans.saturationFraction(motorIdx);
    diagnostic.(sprintf("actionRange_motor%d", motorIdx)) = metricMeans.actionRange(motorIdx);
    diagnostic.(sprintf("responseRange_motor%d", motorIdx)) = metricMeans.responseRange(motorIdx);
    diagnostic.(sprintf("targetRange_motor%d", motorIdx)) = metricMeans.targetRange(motorIdx);
    diagnostic.(sprintf("correlation_motor%d", motorIdx)) = metricMeans.correlation(motorIdx);
    diagnostic.(sprintf("flat_response_motor%d", motorIdx)) = ...
        metricMeans.flatResponse(motorIdx);
    diagnostic.(sprintf("action_no_motion_motor%d", motorIdx)) = ...
        metricMeans.actionNoMotion(motorIdx);
    diagnostic.(sprintf("high_action_flat_response_motor%d", motorIdx)) = ...
        metricMeans.highActionFlatResponse(motorIdx);
end

diagnostic.motor2_flat_response = metricMeans.flatResponse(2);
diagnostic.motor2_action_no_motion = metricMeans.actionNoMotion(2);
diagnostic.motor2_high_action_flat_response = metricMeans.highActionFlatResponse(2);
diagnostic.motor2_tracking_outlier = localMotor2TrackingOutlier(metricMeans);
diagnostic.motor2Interpretation = localBuildInterpretation(diagnostic);

if strlength(figurePath) > 0
    localCreateDiagnosticFigure(episodeFiles(end), episodeNumbers(end), figurePath);
end
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
    "effectiveActionLog", "actionSatLog", "actionLog", "rawActionLog"];
varsToLoad = intersect(requestedVars, availableVars, "stable");
data = load(episodeFile, varsToLoad{:});
end

function [target, response, actionAligned, actionSteps] = localExtractAlignedSignals(data)
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
actionAligned = localAlignRows(actionSteps, size(target, 1));
actionSteps = actionAligned;
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

function tf = localMotorFlatResponse(metricMeans, motorIdx)
targetRange = metricMeans.targetRange(motorIdx);
responseRange = metricMeans.responseRange(motorIdx);
otherIdx = setdiff(1:numel(metricMeans.targetRange), motorIdx);
otherTargetRange = metricMeans.targetRange(otherIdx);
tf = localFinite(targetRange) && localFinite(responseRange) && ...
    targetRange >= max(0.10, 0.50 * mean(otherTargetRange, "omitnan")) && ...
    responseRange <= max(0.03, 0.35 * targetRange);
end

function tf = localMotorActionNoMotion(metricMeans, motorIdx)
actionValue = metricMeans.actionL2(motorIdx);
responseRange = metricMeans.responseRange(motorIdx);
targetRange = metricMeans.targetRange(motorIdx);
otherIdx = setdiff(1:numel(metricMeans.actionL2), motorIdx);
otherAction = metricMeans.actionL2(otherIdx);
tf = localFinite(actionValue) && localFinite(responseRange) && ...
    localFinite(targetRange) && ...
    actionValue >= max(0.10, 0.75 * mean(otherAction, "omitnan")) && ...
    responseRange <= max(0.03, 0.35 * targetRange);
end

function tf = localMotorHighActionFlatResponse(metricMeans, motorIdx, options)
actionValue = metricMeans.actionL2(motorIdx);
saturationValue = metricMeans.saturationFraction(motorIdx);
responseRange = metricMeans.responseRange(motorIdx);
targetRange = metricMeans.targetRange(motorIdx);
actionThreshold = localGetOption(options, "highActionFlatActionL2Threshold", 0.70);
saturationThreshold = localGetOption(options, ...
    "highActionFlatSaturationThreshold", 0.25);
targetThreshold = localGetOption(options, "highActionFlatTargetRangeThreshold", 0.10);
responseRatio = localGetOption(options, "highActionFlatResponseRatio", 0.35);
responseFloor = localGetOption(options, "highActionFlatResponseFloor", 0.03);

highAction = (localFinite(actionValue) && actionValue >= actionThreshold) || ...
    (localFinite(saturationValue) && saturationValue >= saturationThreshold);
flatResponse = localFinite(responseRange) && localFinite(targetRange) && ...
    responseRange <= max(responseFloor, responseRatio * targetRange);
targetMoves = localFinite(targetRange) && targetRange >= targetThreshold;
tf = highAction && flatResponse && targetMoves;
end

function tf = localMotor2TrackingOutlier(metricMeans)
mse2 = metricMeans.trackingMSE(2);
otherMse = metricMeans.trackingMSE([1 3 4]);
otherMean = mean(otherMse, "omitnan");
otherStd = std(otherMse, 0, "omitnan");
tf = localFinite(mse2) && localFinite(otherMean) && ...
    mse2 > max(otherMean + 2 * otherStd, 1.5 * otherMean);
end

function tf = localFinite(value)
tf = isfinite(value) && ~isnan(value);
end

function interpretation = localBuildInterpretation(diagnostic)
messages = strings(0, 1);
if diagnostic.motor2_action_no_motion
    messages(end+1, 1) = "Motor 2 receives action but has low response range; check simulator mapping or motor scale.";
end
if isfield(diagnostic, "motor2_high_action_flat_response") && ...
        diagnostic.motor2_high_action_flat_response
    messages(end+1, 1) = "Motor 2 receives high action or saturation while response remains flat.";
end
if diagnostic.motor2_flat_response
    messages(end+1, 1) = "Motor 2 target varies while response is flat; check simulator response and encoder/flex scaling.";
end
if diagnostic.motor2_tracking_outlier
    messages(end+1, 1) = "Motor 2 tracking error is an outlier versus the other motors.";
end
if isempty(messages)
    messages = "No strong motor 2 failure flag was triggered by these thresholds.";
end
interpretation = strjoin(messages, " ");
end

function value = localGetOption(options, fieldName, defaultValue)
if isstruct(options) && isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = double(options.(fieldName));
else
    value = defaultValue;
end
end

function localCreateDiagnosticFigure(episodeFile, episodeNumber, figurePath)
data = localLoadEpisodeData(fullfile(episodeFile.folder, episodeFile.name));
[target, response, actionAligned] = localExtractAlignedSignals(data);
x = 1:size(target, 1);

[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off");
set(f, "Units", "normalized", "OuterPosition", [0 0 1 1]);
tiledlayout(f, 3, 4, "TileSpacing", "compact", "Padding", "compact");

motorNames = ["Motor 1", "Motor 2", "Motor 3", "Motor 4"];
for motorIdx = 1:4
    ax = nexttile(motorIdx);
    plot(ax, x, target(:, motorIdx), "Color", [0.00 0.45 0.74], "LineWidth", 1.5);
    hold(ax, "on");
    plot(ax, x, response(:, motorIdx), "Color", [0.85 0.33 0.10], "LineWidth", 1.2);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " reference vs response");
    if motorIdx == 1
        ylabel(ax, "Position");
        legend(ax, ["Glove ref", "Simulated"], "Location", "best");
    end
    localHighlightMotor2(ax, motorIdx);

    ax = nexttile(4 + motorIdx);
    plot(ax, x, response(:, motorIdx) - target(:, motorIdx), ...
        "Color", [0.49 0.18 0.56], "LineWidth", 1.1);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " error");
    if motorIdx == 1
        ylabel(ax, "Error");
    end
    localHighlightMotor2(ax, motorIdx);

    ax = nexttile(8 + motorIdx);
    plot(ax, x, actionAligned(:, motorIdx), "Color", [0.47 0.67 0.19], "LineWidth", 1.1);
    grid(ax, "on");
    title(ax, motorNames(motorIdx) + " effective action");
    xlabel(ax, "Sample");
    if motorIdx == 1
        ylabel(ax, "Action");
    end
    ylim(ax, [-1.05 1.05]);
    localHighlightMotor2(ax, motorIdx);
end

sgtitle(f, sprintf("Motor diagnostic, episode %d", episodeNumber));
saveas(f, figurePath);
close(f);
end

function localHighlightMotor2(ax, motorIdx)
if motorIdx ~= 2
    return;
end
ax.LineWidth = 1.5;
ax.XColor = [0.70 0.10 0.10];
ax.YColor = [0.70 0.10 0.10];
end
