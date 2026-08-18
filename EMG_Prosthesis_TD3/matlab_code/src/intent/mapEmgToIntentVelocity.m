function [intentVelocity, intent, gateState, details] = ...
        mapEmgToIntentVelocity(rawEmg, calibration, expected, gateState)
%mapEmgToIntentVelocity decodes causal raw-EMG windows into r=2 intent.
%
% rawEmg is samples-by-channels raw EMG. The physical mean-absolute
% envelope and same-session normalization are computed here, before and
% independently from any WMoos feature standardization.
% expected is mandatory and pins session, channels, timing, units, motor
% order, mapping versions and calibration checksum. gateState is explicit
% and optional so batch and streaming execution are equivalent.

arguments
    rawEmg {mustBeNumeric}
    calibration
    expected struct = struct()
    gateState struct = struct()
end

requiredExpectedFields = { ...
    'userId', 'sessionId', 'channelOrder', 'sampleRateHz', ...
    'windowLengthSamples', 'hopLengthSamples', 'dataProvenance', ...
    'motorOrder', 'units', 'synergyMatrixVersion', ...
    'instructionProtocolVersion', 'sourceDomain', ...
    'calibrationContentSha256'};
if ~isscalar(expected) || ...
        ~all(isfield(expected, requiredExpectedFields))
    error("mapEmgToIntentVelocity:IncompleteExpectedContext", ...
        "A complete runtime session/mechanics compatibility context is required.");
end
validation = validateIntentCalibration(calibration, expected);
if ~validation.isValid
    error("mapEmgToIntentVelocity:InvalidCalibration", ...
        "Calibration is invalid or incompatible: %s", ...
        strjoin(validation.issues, "; "));
end
if ~isstruct(gateState) || ~isscalar(gateState)
    error("mapEmgToIntentVelocity:InvalidGateState", ...
        "gateState must be a scalar struct.");
end

channelCount = calibration.channelCount;
if isempty(rawEmg) || ~ismatrix(rawEmg) || ...
        size(rawEmg, 2) ~= channelCount
    error("mapEmgToIntentVelocity:InvalidRawEmg", ...
        "rawEmg must be a nonempty samples-by-%d raw-EMG matrix.", ...
        channelCount);
end
if ~isreal(rawEmg) || any(~isfinite(rawEmg), "all")
    error("mapEmgToIntentVelocity:NonfiniteRawEmg", ...
        "rawEmg must contain finite real samples.");
end

gateState = normalizeGateState(gateState);
if gateState.onCount >= calibration.restGate.nOn || ...
        gateState.offCount >= calibration.restGate.nOff || ...
        (gateState.isActive && gateState.onCount ~= 0) || ...
        (~gateState.isActive && gateState.offCount ~= 0)
    error("mapEmgToIntentVelocity:InvalidGateState", ...
        "Gate counters are not canonical for the calibrated hysteresis.");
end
[envelope, sampleRanges] = computeEmgEnvelope(rawEmg, ...
    calibration.windowLengthSamples, calibration.hopLengthSamples);
activation = normalizeEnvelope(envelope, calibration);
activeChannels = calibration.activeChannelMask;
activity = mean(activation(:, activeChannels), 2);

decodedIntent = tanh(activation * calibration.decoder.W' + ...
    calibration.decoder.bias');
intent = zeros(size(decodedIntent));
intentVelocity = zeros(size(decodedIntent, 1), 4);
gateActive = false(size(decodedIntent, 1), 1);
lowActivityCountdown = false(size(decodedIntent, 1), 1);
onCount = zeros(size(decodedIntent, 1), 1);
offCount = zeros(size(decodedIntent, 1), 1);

for windowIdx = 1:size(decodedIntent, 1)
    currentActivity = activity(windowIdx);
    if gateState.isActive
        gateState.onCount = 0;
        if currentActivity <= calibration.restGate.thetaOff
            gateState.offCount = gateState.offCount + 1;
            lowActivityCountdown(windowIdx) = true;
            if gateState.offCount >= calibration.restGate.nOff
                gateState.isActive = false;
                gateState.offCount = 0;
            end
        else
            gateState.offCount = 0;
        end
    else
        gateState.offCount = 0;
        if currentActivity >= calibration.restGate.thetaOn
            gateState.onCount = gateState.onCount + 1;
            if gateState.onCount >= calibration.restGate.nOn
                gateState.isActive = true;
                gateState.onCount = 0;
            end
        else
            gateState.onCount = 0;
        end
    end

    gateActive(windowIdx) = gateState.isActive;
    onCount(windowIdx) = gateState.onCount;
    offCount(windowIdx) = gateState.offCount;

    % Low-activity countdown commands zero before the gate closes. With the
    % validated nOff/acceleration relation this permits a bounded stop, then
    % exact positional hold once rest is declared.
    if gateState.isActive && ~lowActivityCountdown(windowIdx)
        intent(windowIdx, :) = decodedIntent(windowIdx, :);
        synergyCommand = intent(windowIdx, :) * ...
            calibration.synergy.matrix';
        synergyCommand = max(-1, min(1, synergyCommand));
        intentVelocity(windowIdx, :) = ...
            calibration.limits.velocityMax .* synergyCommand;
    end
end

details = struct( ...
    "envelope", envelope, ...
    "sampleRanges", sampleRanges, ...
    "discardedSampleCount", size(rawEmg, 1) - sampleRanges(end, 2), ...
    "normalizedActivation", activation, ...
    "activity", activity, ...
    "decodedIntent", decodedIntent, ...
    "gateActive", gateActive, ...
    "isRest", ~gateActive, ...
    "lowActivityCountdown", lowActivityCountdown, ...
    "onCount", onCount, ...
    "offCount", offCount, ...
    "sourceDomain", "rawEmgMeanAbsolute", ...
    "wmoosStandardizationUsed", false);
end

function gateState = normalizeGateState(gateState)
defaults = struct("isActive", false, "onCount", 0, "offCount", 0);
fieldNames = fieldnames(defaults);
unknownFields = setdiff(string(fieldnames(gateState)), string(fieldNames));
if ~isempty(unknownFields)
    error("mapEmgToIntentVelocity:InvalidGateState", ...
        "Unknown gateState field(s): %s", strjoin(unknownFields, ", "));
end
for fieldIdx = 1:numel(fieldNames)
    fieldName = fieldNames{fieldIdx};
    if ~isfield(gateState, fieldName)
        gateState.(fieldName) = defaults.(fieldName);
    end
end
if ~islogical(gateState.isActive) || ~isscalar(gateState.isActive) || ...
        ~isCount(gateState.onCount) || ~isCount(gateState.offCount)
    error("mapEmgToIntentVelocity:InvalidGateState", ...
        "Gate state requires scalar logical isActive and nonnegative integer counters.");
end
gateState.onCount = double(gateState.onCount);
gateState.offCount = double(gateState.offCount);
end

function activation = normalizeEnvelope(envelope, calibration)
activation = (double(envelope) - double(calibration.baselineMedian)) ./ ...
    (double(calibration.signalLevel) - ...
    double(calibration.baselineMedian) + calibration.epsilon);
activation = max(0, min(1, activation));
activation(:, ~calibration.activeChannelMask) = 0;
end

function tf = isCount(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
    isfinite(value) && value >= 0 && fix(value) == value;
end
