function results = compareAllMotorRegression(beforeTable, afterTable, options)
%compareAllMotorRegression compares baseline vs experimental conversion.
%
% The helper is table-based so it can be reused by diagnostics and short
% ablations without touching Env state.

arguments
    beforeTable table
    afterTable table
    options struct = struct()
end

rangeThreshold = localGetOption(options, "rangeThreshold", 1e-4);
regressionTolerance = localGetOption(options, "regressionTolerance", 0.10);
motors = 1:4;
rows = cell(numel(motors), 1);

for i = 1:numel(motors)
    motorIdx = motors(i);
    beforeRows = beforeTable(beforeTable.motor == motorIdx, :);
    afterRows = afterTable(afterTable.motor == motorIdx, :);
    matched = localMatchRows(beforeRows, afterRows);

    beforeRange = matched.normalizedFlexRangeBefore;
    afterRange = matched.normalizedFlexRangeAfter;
    meanBefore = mean(beforeRange, "omitnan");
    meanAfter = mean(afterRange, "omitnan");
    if meanBefore <= eps
        percentChange = NaN;
    else
        percentChange = 100 * (meanAfter - meanBefore) / meanBefore;
    end

    deadzonePositiveBefore = localDeadzoneThreshold( ...
        matched.rawAction, matched.normalizedFlexRangeBefore, ...
        rangeThreshold, "positive");
    deadzonePositiveAfter = localDeadzoneThreshold( ...
        matched.rawAction, matched.normalizedFlexRangeAfter, ...
        rangeThreshold, "positive");
    deadzoneNegativeBefore = localDeadzoneThreshold( ...
        matched.rawAction, matched.normalizedFlexRangeBefore, ...
        rangeThreshold, "negative");
    deadzoneNegativeAfter = localDeadzoneThreshold( ...
        matched.rawAction, matched.normalizedFlexRangeAfter, ...
        rangeThreshold, "negative");

    signMismatch = localSignMismatch( ...
        matched.finalFlexDeltaBefore, matched.finalFlexDeltaAfter, ...
        matched.normalizedFlexRangeBefore, matched.normalizedFlexRangeAfter, ...
        rangeThreshold);
    maxAbsoluteDeviation = max(abs(afterRange - beforeRange), [], "omitnan");

    rows{i} = struct( ...
        "motor", motorIdx, ...
        "normalizedFlexRangeBefore", meanBefore, ...
        "normalizedFlexRangeAfter", meanAfter, ...
        "percentChange", percentChange, ...
        "signConsistencyBefore", true, ...
        "signConsistencyAfter", ~signMismatch, ...
        "deadzonePositiveBefore", deadzonePositiveBefore, ...
        "deadzonePositiveAfter", deadzonePositiveAfter, ...
        "deadzoneNegativeBefore", deadzoneNegativeBefore, ...
        "deadzoneNegativeAfter", deadzoneNegativeAfter, ...
        "maxAbsoluteDeviation", maxAbsoluteDeviation, ...
        "signMismatch", signMismatch);
end

perMotorTable = struct2table(vertcat(rows{:}));
motor2Row = perMotorTable(perMotorTable.motor == 2, :);
motor2ImprovementScore = localMotor2ImprovementScore(motor2Row);

motor1Regression = localMotorRegression(perMotorTable, 1, regressionTolerance);
motor3Regression = localMotorRegression(perMotorTable, 3, regressionTolerance);
motor4Regression = localMotorRegression(perMotorTable, 4, regressionTolerance);
motor2Improved = motor2Row.normalizedFlexRangeAfter > ...
    motor2Row.normalizedFlexRangeBefore && ...
    localDeadzoneNotWorse(motor2Row.deadzonePositiveBefore, ...
        motor2Row.deadzonePositiveAfter);
signErrorDetected = any(perMotorTable.signMismatch);
calibrationAccepted = motor2Improved && ~motor1Regression && ...
    ~motor3Regression && ~motor4Regression && ~signErrorDetected;

summary = struct( ...
    "motor1_regression", motor1Regression, ...
    "motor3_regression", motor3Regression, ...
    "motor4_regression", motor4Regression, ...
    "motor2_improved", motor2Improved, ...
    "sign_error_detected", signErrorDetected, ...
    "calibration_accepted", calibrationAccepted, ...
    "motor2ImprovementScore", motor2ImprovementScore);

summaryTable = struct2table(summary);
results = struct();
results.perMotorTable = perMotorTable;
results.summaryTable = summaryTable;
results.summary = summary;
results.accepted = calibrationAccepted;
end

function value = localGetOption(options, fieldName, defaultValue)
if isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function matched = localMatchRows(beforeRows, afterRows)
actionBefore = localActionColumn(beforeRows);
actionAfter = localActionColumn(afterRows);
modeBefore = localModeColumn(beforeRows);
modeAfter = localModeColumn(afterRows);

rows = cell(height(beforeRows), 1);
rowIdx = 0;
for i = 1:height(beforeRows)
    hit = find(modeAfter == modeBefore(i) & abs(actionAfter - actionBefore(i)) < 1e-12, 1);
    if isempty(hit)
        continue;
    end
    rowIdx = rowIdx + 1;
    rows{rowIdx} = struct( ...
        "initialMode", modeBefore(i), ...
        "rawAction", actionBefore(i), ...
        "normalizedFlexRangeBefore", beforeRows.normalizedFlexRange(i), ...
        "normalizedFlexRangeAfter", afterRows.normalizedFlexRange(hit), ...
        "finalFlexDeltaBefore", beforeRows.finalFlexDelta(i), ...
        "finalFlexDeltaAfter", afterRows.finalFlexDelta(hit));
end

if rowIdx == 0
    matched = table();
else
    matched = struct2table(vertcat(rows{1:rowIdx}));
end
end

function values = localActionColumn(tableValue)
if ismember("rawAction", string(tableValue.Properties.VariableNames))
    values = double(tableValue.rawAction);
elseif ismember("level", string(tableValue.Properties.VariableNames))
    values = double(tableValue.level);
else
    error("Input table must contain rawAction or level.");
end
end

function values = localModeColumn(tableValue)
if ismember("initialMode", string(tableValue.Properties.VariableNames))
    values = string(tableValue.initialMode);
else
    values = repmat("default", height(tableValue), 1);
end
end

function threshold = localDeadzoneThreshold(actions, ranges, rangeThreshold, side)
if side == "positive"
    idx = actions > 0 & ranges > rangeThreshold;
elseif side == "negative"
    idx = actions < 0 & ranges > rangeThreshold;
else
    error("Unsupported side '%s'.", side);
end

if any(idx)
    threshold = min(abs(actions(idx)));
else
    threshold = Inf;
end
end

function mismatch = localSignMismatch(deltaBefore, deltaAfter, rangeBefore, ...
        rangeAfter, rangeThreshold)
active = rangeBefore > rangeThreshold & rangeAfter > rangeThreshold;
if ~any(active)
    mismatch = false;
    return;
end
beforeSign = sign(deltaBefore(active));
afterSign = sign(deltaAfter(active));
nonZero = beforeSign ~= 0 & afterSign ~= 0;
mismatch = any(beforeSign(nonZero) ~= afterSign(nonZero));
end

function value = localMotorRegression(perMotorTable, motorIdx, tolerance)
row = perMotorTable(perMotorTable.motor == motorIdx, :);
if isempty(row)
    value = true;
    return;
end
rangeRegression = row.normalizedFlexRangeAfter < ...
    (1 - tolerance) * row.normalizedFlexRangeBefore;
value = rangeRegression || ~row.signConsistencyAfter;
end

function ok = localDeadzoneNotWorse(beforeValue, afterValue)
if isinf(beforeValue)
    ok = true;
else
    ok = afterValue <= beforeValue;
end
end

function score = localMotor2ImprovementScore(row)
rangeGain = row.normalizedFlexRangeAfter - row.normalizedFlexRangeBefore;
positiveDeadzoneGain = localFiniteDeadzoneGain( ...
    row.deadzonePositiveBefore, row.deadzonePositiveAfter);
negativeDeadzoneGain = localFiniteDeadzoneGain( ...
    row.deadzoneNegativeBefore, row.deadzoneNegativeAfter);
score = rangeGain + 0.5 * positiveDeadzoneGain + ...
    0.25 * negativeDeadzoneGain;
end

function gain = localFiniteDeadzoneGain(beforeValue, afterValue)
if isinf(beforeValue) && isinf(afterValue)
    gain = 0;
elseif isinf(beforeValue)
    gain = 1;
elseif isinf(afterValue)
    gain = -1;
else
    gain = beforeValue - afterValue;
end
end
