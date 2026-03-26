function diagnostics = computeEpisodeActionDiagnostics( ...
    actionLog, actionSatLog, actionPwmLog, targetLog, predLog, ...
    activationThreshold, actionLevels, includeDetailed, includePerMotor, ...
    actionWarpLog, actionWarpLevels, actionWarpDeadzone)
%computeEpisodeActionDiagnostics summarizes action aggressiveness per episode.

arguments
    actionLog
    actionSatLog
    actionPwmLog
    targetLog = []
    predLog = []
    activationThreshold (1, 1) double = 0.05
    actionLevels = [0 64 96 128 160 192 224 255]
    includeDetailed (1, 1) logical = false
    includePerMotor (1, 1) logical = true
    actionWarpLog = []
    actionWarpLevels = []
    actionWarpDeadzone (1, 1) double = 0.05
end

actionRaw = ensureMatrix(actionLog);
actionEffective = ensureMatrix(actionSatLog);
actionPwm = ensureMatrix(actionPwmLog);
if nargin >= 10 && ~isempty(actionWarpLog)
    actionWarped = ensureMatrix(actionWarpLog);
else
    actionWarped = actionRaw;
end

numMotors = max([size(actionRaw, 2), size(actionWarped, 2), size(actionEffective, 2), 4]);
actionRaw = ensureWidth(actionRaw, numMotors);
actionWarped = ensureWidth(actionWarped, numMotors);
actionEffective = ensureWidth(actionEffective, numMotors);
actionPwm = ensureWidth(actionPwm, numMotors);

targetMatrix = convertCellLogToMatrix(targetLog, numMotors);
predMatrix = convertCellLogToMatrix(predLog, numMotors);

validMotorMask = ~isnan(actionEffective) & ~isnan(actionRaw);
if ~any(validMotorMask, "all")
    diagnostics = buildEmptyDiagnostics(numMotors, includeDetailed);
    return;
end

maxPwm = max(abs(double(actionLevels(:))));
if maxPwm == 0
    pwmLevelsSigned = 0;
    effectiveLevels = 0;
else
    nonZeroLevels = unique(abs(double(actionLevels(:)')));
    nonZeroLevels = sort(nonZeroLevels(nonZeroLevels > 0));
    pwmLevelsSigned = [-fliplr(nonZeroLevels), 0, nonZeroLevels];
    effectiveLevels = pwmLevelsSigned / maxPwm;
end

warpLevelsSigned = buildSignedLevels(actionWarpLevels);
if isempty(warpLevelsSigned)
    warpLevelsSigned = effectiveLevels;
end
nonZeroWarpLevels = sort(unique(abs(warpLevelsSigned(:)')));
nonZeroWarpLevels = nonZeroWarpLevels(nonZeroWarpLevels > 0);
if isempty(nonZeroWarpLevels)
    firstWarpLevel = NaN;
else
    firstWarpLevel = nonZeroWarpLevels(1);
end

rawEffectiveError = abs(actionRaw - actionEffective);
rawWarpError = abs(actionRaw - actionWarped);
thresholdNullMask = abs(actionRaw) > 0 & ...
    abs(actionRaw) < activationThreshold & ...
    actionEffective == 0;
rawDeadzoneToFirstLevelMask = abs(actionRaw) >= actionWarpDeadzone & ...
    abs(actionRaw) < firstWarpLevel;
saturationMask = abs(actionEffective) >= 0.95;

signFlipCountByMotor = nan(1, numMotors);
signFlipFractionByMotor = nan(1, numMotors);
saturationRunMeanByMotor = nan(1, numMotors);
saturationRunMaxByMotor = nan(1, numMotors);
deltaActionL2ByMotor = nan(1, numMotors);
trackingMseByMotor = nan(1, numMotors);
trackingMaeByMotor = nan(1, numMotors);

for motorIdx = 1:numMotors
    validIdx = validMotorMask(:, motorIdx);
    motorEffective = actionEffective(validIdx, motorIdx);
    motorSaturation = saturationMask(validIdx, motorIdx);

    nonZeroIdx = abs(motorEffective) > 0;
    if sum(nonZeroIdx) >= 2
        motorNonZero = motorEffective(nonZeroIdx);
        signFlipCountByMotor(motorIdx) = sum( ...
            sign(motorNonZero(2:end)) ~= sign(motorNonZero(1:end-1)));
        signFlipFractionByMotor(motorIdx) = ...
            signFlipCountByMotor(motorIdx) / (numel(motorNonZero) - 1);
    elseif any(nonZeroIdx)
        signFlipCountByMotor(motorIdx) = 0;
        signFlipFractionByMotor(motorIdx) = 0;
    end

    runLengths = extractRunLengths(motorSaturation);
    if isempty(runLengths)
        saturationRunMeanByMotor(motorIdx) = 0;
        saturationRunMaxByMotor(motorIdx) = 0;
    else
        saturationRunMeanByMotor(motorIdx) = mean(runLengths, "omitnan");
        saturationRunMaxByMotor(motorIdx) = max(runLengths);
    end

    if numel(motorEffective) >= 2
        motorDelta = diff(motorEffective, 1, 1);
        deltaActionL2ByMotor(motorIdx) = mean(motorDelta.^2, "omitnan");
    else
        deltaActionL2ByMotor(motorIdx) = 0;
    end
end

if ~isempty(targetMatrix) && ~isempty(predMatrix) && isequal(size(targetMatrix), size(predMatrix))
    errorMatrix = predMatrix - targetMatrix;
    trackingMseByMotor = mean(errorMatrix.^2, 1, "omitnan");
    trackingMaeByMotor = mean(abs(errorMatrix), 1, "omitnan");
end

pwmLevelCounts = countLevelHits(actionPwm, pwmLevelsSigned);
pwmLevelCountsByMotor = countLevelHitsByMotor(actionPwm, pwmLevelsSigned);
effectiveActionLevelCounts = countLevelHits(actionEffective, effectiveLevels);
effectiveActionLevelCountsByMotor = countLevelHitsByMotor(actionEffective, effectiveLevels);
warpedActionLevelCounts = countLevelHits(actionWarped, warpLevelsSigned);
warpedActionLevelCountsByMotor = countLevelHitsByMotor(actionWarped, warpLevelsSigned);

diagnostics = struct( ...
    "numSteps", size(actionEffective, 1), ...
    "thresholdNullFraction", mean(thresholdNullMask(validMotorMask), "omitnan"), ...
    "thresholdNullFractionByMotor", mean(thresholdNullMask, 1, "omitnan"), ...
    "meanRawEffectiveActionError", mean(rawEffectiveError(validMotorMask), "omitnan"), ...
    "meanRawEffectiveActionErrorByMotor", mean(rawEffectiveError, 1, "omitnan"), ...
    "rawToWarpedActionErrorMean", mean(rawWarpError(validMotorMask), "omitnan"), ...
    "rawToWarpedActionErrorMeanByMotor", mean(rawWarpError, 1, "omitnan"), ...
    "rawDeadzoneToFirstLevelFraction", mean(rawDeadzoneToFirstLevelMask(validMotorMask), "omitnan"), ...
    "rawDeadzoneToFirstLevelFractionByMotor", mean(rawDeadzoneToFirstLevelMask, 1, "omitnan"), ...
    "meanAbsActionByMotor", mean(abs(actionEffective), 1, "omitnan"), ...
    "saturationFractionByMotor", mean(saturationMask, 1, "omitnan"), ...
    "deltaActionL2ByMotor", deltaActionL2ByMotor, ...
    "trackingMseByMotor", trackingMseByMotor, ...
    "trackingMaeByMotor", trackingMaeByMotor, ...
    "signFlipCountByMotor", signFlipCountByMotor, ...
    "signFlipFractionByMotor", signFlipFractionByMotor, ...
    "saturationRunMeanByMotor", saturationRunMeanByMotor, ...
    "saturationRunMaxByMotor", saturationRunMaxByMotor, ...
    "signFlipFractionMean", mean(signFlipFractionByMotor, "omitnan"), ...
    "saturationRunMean", mean(saturationRunMeanByMotor, "omitnan"), ...
    "saturationRunMax", max(saturationRunMaxByMotor, [], "omitnan"), ...
    "pwmLevels", pwmLevelsSigned, ...
    "pwmLevelCounts", pwmLevelCounts, ...
    "pwmLevelFractions", normalizeLevelCounts(pwmLevelCounts), ...
    "pwmLevelCountsByMotor", pwmLevelCountsByMotor, ...
    "pwmLevelFractionsByMotor", normalizeLevelCountsByMotor(pwmLevelCountsByMotor), ...
    "warpedActionLevels", warpLevelsSigned, ...
    "warpedActionLevelCounts", warpedActionLevelCounts, ...
    "warpedActionLevelFractions", normalizeLevelCounts(warpedActionLevelCounts), ...
    "warpedActionLevelCountsByMotor", warpedActionLevelCountsByMotor, ...
    "warpedActionLevelFractionsByMotor", normalizeLevelCountsByMotor(warpedActionLevelCountsByMotor), ...
    "effectiveActionLevels", effectiveLevels, ...
    "effectiveActionLevelCounts", effectiveActionLevelCounts, ...
    "effectiveActionLevelFractions", normalizeLevelCounts(effectiveActionLevelCounts), ...
    "effectiveActionLevelCountsByMotor", effectiveActionLevelCountsByMotor, ...
    "effectiveActionLevelFractionsByMotor", normalizeLevelCountsByMotor(effectiveActionLevelCountsByMotor), ...
    "saturationMask", []);

if ~includePerMotor
    diagnostics.thresholdNullFractionByMotor = [];
    diagnostics.meanRawEffectiveActionErrorByMotor = [];
    diagnostics.rawToWarpedActionErrorMeanByMotor = [];
    diagnostics.rawDeadzoneToFirstLevelFractionByMotor = [];
    diagnostics.meanAbsActionByMotor = [];
    diagnostics.saturationFractionByMotor = [];
    diagnostics.deltaActionL2ByMotor = [];
    diagnostics.trackingMseByMotor = [];
    diagnostics.trackingMaeByMotor = [];
    diagnostics.signFlipCountByMotor = [];
    diagnostics.signFlipFractionByMotor = [];
    diagnostics.saturationRunMeanByMotor = [];
    diagnostics.saturationRunMaxByMotor = [];
    diagnostics.pwmLevelCountsByMotor = [];
    diagnostics.pwmLevelFractionsByMotor = [];
    diagnostics.warpedActionLevelCountsByMotor = [];
    diagnostics.warpedActionLevelFractionsByMotor = [];
    diagnostics.effectiveActionLevelCountsByMotor = [];
    diagnostics.effectiveActionLevelFractionsByMotor = [];
end

if includeDetailed
    diagnostics.saturationMask = saturationMask;
end
end

function matrix = ensureMatrix(value)
if isempty(value)
    matrix = zeros(0, 4);
    return;
end

if iscell(value)
    matrix = convertCellLogToMatrix(value, []);
else
    matrix = double(value);
end
end

function matrix = ensureWidth(matrix, width)
if isempty(matrix)
    matrix = nan(0, width);
    return;
end

matrix = double(matrix);
currentWidth = size(matrix, 2);
if currentWidth == width
    return;
elseif currentWidth < width
    matrix(:, currentWidth + 1:width) = nan;
else
    matrix = matrix(:, 1:width);
end
end

function matrix = convertCellLogToMatrix(cellLog, numMotors)
if isempty(cellLog)
    if isempty(numMotors)
        matrix = zeros(0, 0);
    else
        matrix = nan(0, numMotors);
    end
    return;
end

if ~iscell(cellLog)
    matrix = double(cellLog);
    return;
end

firstNonEmpty = find(~cellfun(@isempty, cellLog), 1, "first");
if isempty(firstNonEmpty)
    if isempty(numMotors)
        numMotors = 4;
    end
    matrix = nan(numel(cellLog), numMotors);
    return;
end

sample = double(cellLog{firstNonEmpty});
if isempty(numMotors)
    numMotors = size(sample, 2);
end

matrix = nan(numel(cellLog), numMotors);
for i = 1:numel(cellLog)
    if isempty(cellLog{i})
        continue;
    end
    current = double(cellLog{i});
    matrix(i, :) = current(end, :);
end
end

function signedLevels = buildSignedLevels(levels)
levels = unique(sort(abs(double(levels(:)'))));
levels = levels(levels > 0);
if isempty(levels)
    signedLevels = [];
else
    signedLevels = [-fliplr(levels), 0, levels];
end
end

function runLengths = extractRunLengths(mask)
mask = logical(mask(:));
if isempty(mask)
    runLengths = [];
    return;
end

d = diff([false; mask; false]);
starts = find(d == 1);
stops = find(d == -1) - 1;
runLengths = stops - starts + 1;
end

function counts = countLevelHits(values, levels)
flatValues = values(~isnan(values));
counts = zeros(1, numel(levels));
for i = 1:numel(levels)
    counts(i) = sum(abs(flatValues - levels(i)) < 1e-9);
end
end

function countsByMotor = countLevelHitsByMotor(values, levels)
numMotors = size(values, 2);
countsByMotor = zeros(numMotors, numel(levels));
for motorIdx = 1:numMotors
    motorValues = values(:, motorIdx);
    validValues = motorValues(~isnan(motorValues));
    for levelIdx = 1:numel(levels)
        countsByMotor(motorIdx, levelIdx) = ...
            sum(abs(validValues - levels(levelIdx)) < 1e-9);
    end
end
end

function fractions = normalizeLevelCounts(counts)
fractions = counts ./ max(1, sum(counts));
end

function fractionsByMotor = normalizeLevelCountsByMotor(countsByMotor)
fractionsByMotor = nan(size(countsByMotor));
for motorIdx = 1:size(countsByMotor, 1)
    fractionsByMotor(motorIdx, :) = countsByMotor(motorIdx, :) ./ ...
        max(1, sum(countsByMotor(motorIdx, :)));
end
end

function diagnostics = buildEmptyDiagnostics(numMotors, includeDetailed)
diagnostics = struct( ...
    "numSteps", 0, ...
    "thresholdNullFraction", NaN, ...
    "thresholdNullFractionByMotor", nan(1, numMotors), ...
    "meanRawEffectiveActionError", NaN, ...
    "meanRawEffectiveActionErrorByMotor", nan(1, numMotors), ...
    "rawToWarpedActionErrorMean", NaN, ...
    "rawToWarpedActionErrorMeanByMotor", nan(1, numMotors), ...
    "rawDeadzoneToFirstLevelFraction", NaN, ...
    "rawDeadzoneToFirstLevelFractionByMotor", nan(1, numMotors), ...
    "meanAbsActionByMotor", nan(1, numMotors), ...
    "saturationFractionByMotor", nan(1, numMotors), ...
    "deltaActionL2ByMotor", nan(1, numMotors), ...
    "trackingMseByMotor", nan(1, numMotors), ...
    "trackingMaeByMotor", nan(1, numMotors), ...
    "signFlipCountByMotor", nan(1, numMotors), ...
    "signFlipFractionByMotor", nan(1, numMotors), ...
    "saturationRunMeanByMotor", nan(1, numMotors), ...
    "saturationRunMaxByMotor", nan(1, numMotors), ...
    "signFlipFractionMean", NaN, ...
    "saturationRunMean", NaN, ...
    "saturationRunMax", NaN, ...
    "pwmLevels", [], ...
    "pwmLevelCounts", [], ...
    "pwmLevelFractions", [], ...
    "pwmLevelCountsByMotor", [], ...
    "pwmLevelFractionsByMotor", [], ...
    "warpedActionLevels", [], ...
    "warpedActionLevelCounts", [], ...
    "warpedActionLevelFractions", [], ...
    "warpedActionLevelCountsByMotor", [], ...
    "warpedActionLevelFractionsByMotor", [], ...
    "effectiveActionLevels", [], ...
    "effectiveActionLevelCounts", [], ...
    "effectiveActionLevelFractions", [], ...
    "effectiveActionLevelCountsByMotor", [], ...
    "effectiveActionLevelFractionsByMotor", [], ...
    "saturationMask", []);

if ~includeDetailed
    diagnostics.saturationMask = [];
end
end
