function report = validateIntentCalibration(calibration, expected)
%validateIntentCalibration checks schema, bounds and session compatibility.
%
% Malformed inputs are reported without repairing, reordering or silently
% accepting an incompatible same-user/different-session capture.

arguments
    calibration
    expected struct = struct()
end

issues = strings(0, 1);
if ~isstruct(calibration) || ~isscalar(calibration)
    report = makeReport(false, "Calibration must be a scalar struct.", 0, 0);
    return;
end
if ~isstruct(expected) || ~isscalar(expected)
    report = makeReport(false, ...
        "Expected compatibility data must be a scalar struct.", 0, 0);
    return;
end
allowedExpectedFields = [ ...
    "userId", "sessionId", "channelOrder", "sampleRateHz", ...
    "windowLengthSamples", "hopLengthSamples", "dataProvenance", ...
    "motorOrder", "units", "synergyMatrixVersion", ...
    "instructionProtocolVersion", "sourceDomain", ...
    "calibrationContentSha256"];
unknownExpectedFields = setdiff(string(fieldnames(expected)), ...
    allowedExpectedFields);
if ~isempty(unknownExpectedFields)
    issues(end + 1) = "Unknown expected-context fields: " + ...
        strjoin(unknownExpectedFields, ", ");
end

requiredTopLevel = { ...
    'schemaVersion', 'userId', 'sessionId', 'calibratedAt', ...
    'sourceCapturedAt', 'dataProvenance', ...
    'channelOrder', 'channelCount', 'sampleRateHz', ...
    'windowLengthSamples', 'hopLengthSamples', ...
    'baselineMedian', 'signalLevel', 'restEnvelopeMad', ...
    'requiredSignalRange', 'signalPercentile', 'epsilon', ...
    'minCalibrationRange', 'flatChannelMadMultiplier', ...
    'activeChannelMask', 'flatChannelMask', 'activityAggregation', ...
    'minimumWindows', 'restWindowCount', 'instructionProtocol', ...
    'trainingWindowCount', ...
    'decoder', 'synergy', 'motorOrder', 'limits', 'restGate', ...
    'units', 'sourceDomain', 'wmoosStandardizationUsed'};
requiredTopLevel{end + 1} = 'contentSha256';
missingFields = requiredTopLevel(~isfield(calibration, requiredTopLevel));
if ~isempty(missingFields)
    issues(end + 1) = "Missing fields: " + ...
        strjoin(string(missingFields), ", ");
    report = makeReport(false, issues, 0, 0);
    return;
end

if ~isFiniteScalar(calibration.schemaVersion) || ...
        calibration.schemaVersion ~= 1
    issues(end + 1) = "schemaVersion must equal 1.";
end

[validUser, userId] = nonemptyScalarString(calibration.userId);
[validSession, sessionId] = nonemptyScalarString(calibration.sessionId);
[validDate, ~] = nonemptyScalarString(calibration.calibratedAt);
[validCaptureDate, ~] = nonemptyScalarString(calibration.sourceCapturedAt);
[validProvenance, dataProvenance] = ...
    nonemptyScalarString(calibration.dataProvenance);
if ~validUser
    issues(end + 1) = "userId must be a nonempty scalar string.";
end
if ~validSession
    issues(end + 1) = "sessionId must be a nonempty scalar string.";
end
if ~validDate
    issues(end + 1) = "calibratedAt must be recorded.";
end
if ~validCaptureDate
    issues(end + 1) = "sourceCapturedAt must be recorded.";
end
if ~validProvenance
    issues(end + 1) = "dataProvenance must be a nonempty scalar string.";
end

channelCount = calibration.channelCount;
validChannelCount = isPositiveInteger(channelCount);
if validChannelCount
    channelCount = double(channelCount);
else
    issues(end + 1) = "channelCount must be a positive integer.";
    channelCount = 0;
end
[validChannelOrder, channelOrder] = uniqueStringRow( ...
    calibration.channelOrder, channelCount);
if ~validChannelOrder
    issues(end + 1) = ...
        "channelOrder must contain exactly channelCount unique nonempty labels.";
end

if ~isPositiveScalar(calibration.sampleRateHz)
    issues(end + 1) = "sampleRateHz must be a positive finite scalar.";
end
if ~isPositiveInteger(calibration.windowLengthSamples) || ...
        ~isPositiveInteger(calibration.hopLengthSamples)
    issues(end + 1) = ...
        "windowLengthSamples and hopLengthSamples must be positive integers.";
end

baseline = calibration.baselineMedian;
signalLevel = calibration.signalLevel;
restMad = calibration.restEnvelopeMad;
requiredRange = calibration.requiredSignalRange;
activeMask = calibration.activeChannelMask;
flatMask = calibration.flatChannelMask;
validEnvelopeVectors = channelCount > 0 && ...
    isFiniteRow(baseline, channelCount) && ...
    isFiniteRow(signalLevel, channelCount) && ...
    isFiniteRow(restMad, channelCount) && all(restMad >= 0) && ...
    isPositiveRow(requiredRange, channelCount) && ...
    islogical(activeMask) && isrow(activeMask) && ...
    numel(activeMask) == channelCount && ...
    islogical(flatMask) && isrow(flatMask) && ...
    numel(flatMask) == channelCount;
if ~validEnvelopeVectors
    issues(end + 1) = ...
        "Envelope calibration vectors have invalid size, type or values.";
    activeChannelCount = 0;
else
    activeChannelCount = sum(activeMask);
    signalRange = double(signalLevel) - double(baseline);
    if ~isequal(flatMask, ~activeMask)
        issues(end + 1) = "flatChannelMask must complement activeChannelMask.";
    end
    if any(signalRange(activeMask) < requiredRange(activeMask)) || ...
            any(signalRange(activeMask) <= 0)
        issues(end + 1) = ...
            "Active channels do not meet their robust calibration range.";
    end
    if any(~activeMask) && ...
            any(signalRange(~activeMask) >= requiredRange(~activeMask))
        issues(end + 1) = ...
            "Inactive-channel mask is inconsistent with the calibration range.";
    end
    if activeChannelCount < 2
        issues(end + 1) = ...
            "At least two informative channels are required for r=2.";
    end
end
if ~isPositiveScalar(calibration.epsilon)
    issues(end + 1) = "epsilon must be a positive finite scalar.";
end
if ~isPositiveScalar(calibration.minCalibrationRange)
    issues(end + 1) = "minCalibrationRange must be a positive finite scalar.";
end
if ~isFiniteScalar(calibration.signalPercentile) || ...
        calibration.signalPercentile <= 50 || calibration.signalPercentile > 100
    issues(end + 1) = "signalPercentile must lie in (50,100].";
end
if ~isPositiveScalar(calibration.flatChannelMadMultiplier)
    issues(end + 1) = ...
        "flatChannelMadMultiplier must be a positive finite scalar.";
end
[validAggregation, activityAggregation] = ...
    nonemptyScalarString(calibration.activityAggregation);
if ~validAggregation || activityAggregation ~= "meanActiveChannels"
    issues(end + 1) = "Unsupported activityAggregation.";
end

minimumWindows = calibration.minimumWindows;
validMinimumWindows = isstruct(minimumWindows) && isscalar(minimumWindows) && ...
    all(isfield(minimumWindows, {'rest', 'perInstruction'})) && ...
    isPositiveInteger(minimumWindows.rest) && ...
    isPositiveInteger(minimumWindows.perInstruction);
if validMinimumWindows
    minimumRestWindows = minimumWindows.rest;
    minimumInstructionWindows = minimumWindows.perInstruction;
else
    minimumRestWindows = Inf;
    minimumInstructionWindows = Inf;
end
if ~validMinimumWindows || ~isPositiveInteger(calibration.restWindowCount) || ...
        ~isPositiveInteger(calibration.trainingWindowCount)
    issues(end + 1) = "Calibration window-count schema is invalid.";
elseif calibration.restWindowCount < minimumRestWindows
    issues(end + 1) = "Rest calibration has too few complete windows.";
end

protocol = calibration.instructionProtocol;
protocolValid = false;
protocolCount = 0;
protocolVersion = "";
validProtocolVersion = false;
if ~isstruct(protocol) || ~isscalar(protocol) || ...
        ~all(isfield(protocol, ...
        {'version', 'labels', 'directions', 'capturedAt', 'windowCounts'}))
    issues(end + 1) = "instructionProtocol schema is incomplete.";
else
    [validProtocolVersion, protocolVersion] = ...
        nonemptyScalarString(protocol.version);
    try
        protocolLabels = string(protocol.labels(:));
        protocolDates = string(protocol.capturedAt(:));
    catch
        protocolLabels = strings(0, 1);
        protocolDates = strings(0, 1);
    end
    protocolCount = numel(protocolLabels);
    allowedDirections = [1, 0; -1, 0; 0, 1; 0, -1];
    validDirections = isFiniteNumeric(protocol.directions) && ...
        isequal(size(protocol.directions), [protocolCount, 2]) && ...
        all(ismember(protocol.directions, allowedDirections, "rows"));
    validLabels = protocolCount >= 4 && ...
        numel(unique(protocolLabels)) == protocolCount && ...
        ~any(ismissing(protocolLabels)) && all(strlength(protocolLabels) > 0);
    validDates = numel(protocolDates) == protocolCount && ...
        ~any(ismissing(protocolDates)) && all(strlength(protocolDates) > 0);
    validCounts = isnumeric(protocol.windowCounts) && ...
        isreal(protocol.windowCounts) && iscolumn(protocol.windowCounts) && ...
        numel(protocol.windowCounts) == protocolCount && ...
        all(isfinite(protocol.windowCounts)) && ...
        all(protocol.windowCounts >= minimumInstructionWindows) && ...
        all(fix(protocol.windowCounts) == protocol.windowCounts);
    validCoverage = validDirections && rank(protocol.directions) == 2 && ...
        all(min(protocol.directions, [], 1) < 0) && ...
        all(max(protocol.directions, [], 1) > 0);
    protocolValid = validProtocolVersion && validLabels && validDates && ...
        validCounts && validCoverage;
    if ~protocolValid
        issues(end + 1) = ...
            "instructionProtocol must provide unique categorical +/- r=2 trials.";
    elseif calibration.trainingWindowCount ~= ...
            calibration.restWindowCount + sum(protocol.windowCounts)
        issues(end + 1) = ...
            "trainingWindowCount is inconsistent with protocol window counts.";
        protocolValid = false;
    end
end

decoder = calibration.decoder;
if ~isstruct(decoder) || ~isscalar(decoder) || ...
        ~all(isfield(decoder, ...
        {'rank', 'activationDesignRank', 'weightRank', 'W', 'bias', ...
        'ridgeLambda', 'fitLimit', 'trainingRmse', 'maxTrainingRmse', ...
        'classLabels', 'classRmse'}))
    issues(end + 1) = "decoder schema is incomplete.";
elseif channelCount == 0 || ~isFiniteScalar(decoder.rank) || ...
        decoder.rank ~= 2 || ...
        ~isFiniteScalar(decoder.activationDesignRank) || ...
        decoder.activationDesignRank < 2 || ...
        ~isFiniteScalar(decoder.weightRank) || decoder.weightRank ~= 2 || ...
        ~isequal(size(decoder.W), [2, channelCount]) || ...
        ~isFiniteNumeric(decoder.W) || ...
        ~isequal(size(decoder.bias), [2, 1]) || ...
        ~isFiniteNumeric(decoder.bias) || ...
        ~isPositiveScalar(decoder.ridgeLambda) || ...
        ~isFiniteScalar(decoder.fitLimit) || decoder.fitLimit <= 0 || ...
        decoder.fitLimit >= 1 || ...
        ~isFiniteScalar(decoder.trainingRmse) || decoder.trainingRmse < 0 || ...
        ~isPositiveScalar(decoder.maxTrainingRmse) || ...
        decoder.maxTrainingRmse > 1 || ...
        decoder.trainingRmse > decoder.maxTrainingRmse || ...
        (validEnvelopeVectors && ...
        rank(double(decoder.W(:, activeMask))) ~= 2)
    issues(end + 1) = "decoder parameters are invalid for r=2.";
else
    if validEnvelopeVectors && any(decoder.W(:, ~activeMask) ~= 0, "all")
        issues(end + 1) = ...
            "Decoder weights for flat channels must be exactly zero.";
    end
    try
        decoderClassLabels = string(decoder.classLabels(:));
    catch
        decoderClassLabels = strings(0, 1);
    end
    validClassMetrics = protocolValid && ...
        isequal(decoderClassLabels, ["rest"; string(protocol.labels(:))]) && ...
        isFiniteNumeric(decoder.classRmse) && iscolumn(decoder.classRmse) && ...
        numel(decoder.classRmse) == protocolCount + 1 && ...
        all(decoder.classRmse >= 0) && ...
        all(decoder.classRmse <= decoder.maxTrainingRmse);
    if ~validClassMetrics
        issues(end + 1) = "Decoder per-class quality metrics are invalid.";
    end
end

synergy = calibration.synergy;
synergyVersion = "";
validSynergyVersion = false;
if ~isstruct(synergy) || ~isscalar(synergy) || ...
        ~all(isfield(synergy, {'matrix', 'version'}))
    issues(end + 1) = "synergy schema is incomplete.";
else
    [validSynergyVersion, synergyVersion] = ...
        nonemptyScalarString(synergy.version);
    if ~isequal(size(synergy.matrix), [4, 2]) || ...
            ~isFiniteNumeric(synergy.matrix) || ...
            any(abs(synergy.matrix) > 1, "all") || ...
            rank(double(synergy.matrix)) < 2 || ~validSynergyVersion
        issues(end + 1) = ...
            "synergy matrix must be finite, rank-2, versioned, " + ...
            "4-by-2 and within [-1,1].";
    end
end

[validMotorOrder, motorOrder] = uniqueStringRow(calibration.motorOrder, 4);
if ~validMotorOrder
    issues(end + 1) = "motorOrder must contain four unique nonempty labels.";
end

limits = calibration.limits;
validLimits = false;
if ~isstruct(limits) || ~isscalar(limits) || ...
        ~all(isfield(limits, { ...
        'velocityMax', 'positionMin', 'positionMax', ...
        'accelerationMax', 'deltaT'}))
    issues(end + 1) = "limits schema is incomplete.";
else
    validLimits = isPositiveRow(limits.velocityMax, 4) && ...
        isFiniteRow(limits.positionMin, 4) && ...
        isFiniteRow(limits.positionMax, 4) && ...
        isPositiveRow(limits.accelerationMax, 4) && ...
        isPositiveScalar(limits.deltaT) && ...
        all(limits.positionMax > limits.positionMin);
    if ~validLimits
        issues(end + 1) = ...
            "Position, velocity, acceleration or time limits are invalid.";
    elseif isPositiveScalar(calibration.sampleRateHz) && ...
            isPositiveInteger(calibration.hopLengthSamples)
        expectedDeltaT = calibration.hopLengthSamples / ...
            calibration.sampleRateHz;
        if abs(limits.deltaT - expectedDeltaT) > ...
                64 * eps(max(1, max(abs([limits.deltaT, expectedDeltaT]))))
            issues(end + 1) = ...
                "deltaT must equal hopLengthSamples/sampleRateHz.";
        end
    end
end

gate = calibration.restGate;
if ~isstruct(gate) || ~isscalar(gate) || ...
        ~all(isfield(gate, {'thetaOn', 'thetaOff', 'nOn', 'nOff'}))
    issues(end + 1) = "restGate schema is incomplete.";
else
    validGate = isFiniteScalar(gate.thetaOn) && ...
        isFiniteScalar(gate.thetaOff) && gate.thetaOff >= 0 && ...
        gate.thetaOn <= 1 && gate.thetaOff < gate.thetaOn && ...
        isPositiveInteger(gate.nOn) && isPositiveInteger(gate.nOff);
    if ~validGate
        issues(end + 1) = ...
            "restGate must satisfy 0 <= thetaOff < thetaOn <= 1.";
    elseif validLimits && any((gate.nOff - 1) .* limits.accelerationMax .* ...
            limits.deltaT < limits.velocityMax - 128 * eps)
        issues(end + 1) = ...
            "(nOff-1)*accelerationMax*deltaT must permit a bounded stop " + ...
            "before exact rest hold.";
    end
end

units = calibration.units;
validUnits = false;
if ~isstruct(units) || ~isscalar(units) || ...
        ~all(isfield(units, ...
        {'rawEmg', 'envelope', 'position', 'velocity', 'acceleration'}))
    issues(end + 1) = "units schema is incomplete.";
else
    unitFields = fieldnames(units);
    validUnits = true;
    for fieldIdx = 1:numel(unitFields)
        [validUnit, ~] = nonemptyScalarString(units.(unitFields{fieldIdx}));
        if ~validUnit
            validUnits = false;
            break;
        end
    end
    if ~validUnits
        issues(end + 1) = ...
            "Every units field must be a nonempty scalar string.";
    end
end

[validSource, sourceDomain] = nonemptyScalarString(calibration.sourceDomain);
if ~validSource || sourceDomain ~= "rawEmgSameSession"
    issues(end + 1) = "sourceDomain must be rawEmgSameSession.";
end
if ~islogical(calibration.wmoosStandardizationUsed) || ...
        ~isscalar(calibration.wmoosStandardizationUsed) || ...
        calibration.wmoosStandardizationUsed
    issues(end + 1) = ...
        "Envelope calibration must not use WMoos-standardized features.";
end

[validChecksum, checksum] = nonemptyScalarString(calibration.contentSha256);
if ~validChecksum || strlength(checksum) ~= 64 || ...
        isempty(regexp(char(checksum), '^[0-9a-f]{64}$', 'once'))
    issues(end + 1) = "contentSha256 must be a lowercase SHA-256 value.";
elseif isempty(issues)
    try
        expectedChecksum = computeIntentCalibrationChecksum(calibration);
        if checksum ~= expectedChecksum
            issues(end + 1) = ...
                "Calibration checksum does not match the calibration payload.";
        end
    catch
        issues(end + 1) = "Calibration payload checksum could not be verified.";
    end
end

if isfield(expected, "channelOrder") && ~isempty(expected.channelOrder)
    [validExpectedOrder, expectedOrder] = uniqueStringRow( ...
        expected.channelOrder, channelCount);
    if ~validExpectedOrder || ~validChannelOrder || ...
            ~isequal(channelOrder, expectedOrder)
        issues(end + 1) = ...
            "Channel order is incompatible with this calibration.";
    end
end
if isfield(expected, "motorOrder") && ~isempty(expected.motorOrder)
    [validExpectedMotorOrder, expectedMotorOrder] = uniqueStringRow( ...
        expected.motorOrder, 4);
    if ~validExpectedMotorOrder || ~validMotorOrder || ...
            ~isequal(motorOrder, expectedMotorOrder)
        issues(end + 1) = ...
            "Motor order is incompatible with this calibration.";
    end
end
if isfield(expected, "units") && ~isempty(expected.units)
    if ~validUnits || ~unitsEqual(units, expected.units)
        issues(end + 1) = "Units are incompatible with this calibration.";
    end
end
issues = appendExpectedStringIssue(issues, expected, "userId", ...
    userId, validUser, "User is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, "sessionId", ...
    sessionId, validSession, "Session is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, "dataProvenance", ...
    dataProvenance, validProvenance, ...
    "Data provenance is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, "synergyMatrixVersion", ...
    synergyVersion, validSynergyVersion, ...
    "Synergy matrix version is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, ...
    "instructionProtocolVersion", protocolVersion, validProtocolVersion, ...
    "Instruction protocol version is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, "sourceDomain", ...
    sourceDomain, validSource, ...
    "Source domain is incompatible with this calibration.");
issues = appendExpectedStringIssue(issues, expected, ...
    "calibrationContentSha256", checksum, validChecksum, ...
    "Calibration checksum is incompatible with the expected context.");
issues = appendExpectedScalarIssue(issues, expected, "sampleRateHz", ...
    calibration.sampleRateHz, ...
    "Sample rate is incompatible with this calibration.");
issues = appendExpectedScalarIssue(issues, expected, ...
    "windowLengthSamples", calibration.windowLengthSamples, ...
    "Window length is incompatible with this calibration.");
issues = appendExpectedScalarIssue(issues, expected, ...
    "hopLengthSamples", calibration.hopLengthSamples, ...
    "Hop length is incompatible with this calibration.");

report = makeReport(isempty(issues), issues, channelCount, activeChannelCount);
end

function issues = appendExpectedStringIssue( ...
        issues, expected, fieldName, actual, validActual, message)
if ~isfield(expected, fieldName) || isempty(expected.(fieldName))
    return;
end
[validExpected, expectedValue] = nonemptyScalarString(expected.(fieldName));
if ~validExpected || ~validActual || actual ~= expectedValue
    issues(end + 1) = message;
end
end

function issues = appendExpectedScalarIssue( ...
        issues, expected, fieldName, actual, message)
if ~isfield(expected, fieldName) || isempty(expected.(fieldName))
    return;
end
if ~isFiniteScalar(expected.(fieldName)) || ...
        ~isFiniteScalar(actual) || actual ~= expected.(fieldName)
    issues(end + 1) = message;
end
end

function tf = unitsEqual(actual, expected)
requiredFields = {'rawEmg', 'envelope', 'position', 'velocity', 'acceleration'};
if ~isstruct(expected) || ~isscalar(expected) || ...
        ~all(isfield(expected, requiredFields)) || ...
        numel(fieldnames(expected)) ~= numel(requiredFields)
    tf = false;
    return;
end
tf = true;
for fieldIdx = 1:numel(requiredFields)
    fieldName = requiredFields{fieldIdx};
    [validActual, actualValue] = nonemptyScalarString(actual.(fieldName));
    [validExpected, expectedValue] = nonemptyScalarString(expected.(fieldName));
    if ~validActual || ~validExpected || actualValue ~= expectedValue
        tf = false;
        return;
    end
end
end

function report = makeReport(isValid, issues, channelCount, activeChannelCount)
report = struct( ...
    "isValid", logical(isValid), ...
    "issues", string(issues(:)), ...
    "channelCount", double(channelCount), ...
    "activeChannelCount", double(activeChannelCount));
end

function [tf, value] = nonemptyScalarString(value)
try
    value = string(value);
    tf = isscalar(value) && ~ismissing(value) && strlength(value) > 0;
catch
    value = "";
    tf = false;
end
end

function [tf, value] = uniqueStringRow(value, expectedLength)
try
    value = string(value(:)');
    tf = isPositiveInteger(expectedLength) && ...
        numel(value) == expectedLength && ~any(ismissing(value)) && ...
        all(strlength(value) > 0) && ...
        numel(unique(value)) == expectedLength;
catch
    value = strings(1, 0);
    tf = false;
end
end

function tf = isFiniteNumeric(value)
tf = isnumeric(value) && isreal(value) && all(isfinite(value), "all");
end

function tf = isFiniteScalar(value)
tf = isFiniteNumeric(value) && isscalar(value);
end

function tf = isPositiveScalar(value)
tf = isFiniteScalar(value) && value > 0;
end

function tf = isPositiveInteger(value)
tf = isPositiveScalar(value) && fix(value) == value;
end

function tf = isFiniteRow(value, expectedLength)
tf = isFiniteNumeric(value) && isrow(value) && ...
    numel(value) == expectedLength;
end

function tf = isPositiveRow(value, expectedLength)
tf = isFiniteRow(value, expectedLength) && all(value > 0);
end
