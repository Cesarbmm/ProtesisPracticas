function reason = classifyIntentZeroReferenceReason( ...
        referenceVelocity, desiredVelocity, decoderDetails, ...
        referenceDiagnostics, zeroTolerance)
%classifyIntentZeroReferenceReason labels the causal source of v_ref=0.

arguments
    referenceVelocity (1, 4) double
    desiredVelocity (1, 4) double
    decoderDetails (1, 1) struct
    referenceDiagnostics (1, 1) struct
    zeroTolerance (1, 1) double {mustBeNonnegative} = 1e-12
end

requiredDecoder = ["gateActive", "isRest", "lowActivityCountdown"];
requiredReference = ["positionLimited", "brakingLimited", ...
    "accelerationLimited"];
if any(~isfinite([referenceVelocity, desiredVelocity])) || ...
        ~all(isfield(decoderDetails, cellstr(requiredDecoder))) || ...
        ~all(isfield(referenceDiagnostics, cellstr(requiredReference)))
    error("classifyIntentZeroReferenceReason:InvalidContract", ...
        "Decoder or reference diagnostics are incomplete.");
end
gateActive = logicalScalar(decoderDetails.gateActive, "gateActive");
isRest = logicalScalar(decoderDetails.isRest, "isRest");
countdown = logicalScalar( ...
    decoderDetails.lowActivityCountdown, "lowActivityCountdown");
positionLimited = logicalFour( ...
    referenceDiagnostics.positionLimited, "positionLimited");
brakingLimited = logicalFour( ...
    referenceDiagnostics.brakingLimited, "brakingLimited");
accelerationLimited = logicalFour( ...
    referenceDiagnostics.accelerationLimited, "accelerationLimited");

if max(abs(referenceVelocity)) > zeroTolerance
    reason = "movingReference";
elseif isRest
    reason = "decoderRest";
elseif gateActive && countdown
    reason = "activeCountdownZero";
elseif gateActive && max(abs(desiredVelocity)) <= zeroTolerance
    reason = "activeSynergyZero";
elseif any(positionLimited)
    reason = "mechanicalPositionLimitZero";
elseif any(brakingLimited | accelerationLimited)
    reason = "mechanicalRateLimitZero";
else
    reason = "unresolvedActiveZero";
end
end

function value = logicalScalar(value, name)
if ~islogical(value) || ~isscalar(value)
    error("classifyIntentZeroReferenceReason:InvalidContract", ...
        "%s must be a scalar logical.", name);
end
end

function value = logicalFour(value, name)
if ~islogical(value) || numel(value) ~= 4
    error("classifyIntentZeroReferenceReason:InvalidContract", ...
        "%s must contain four logical motor flags.", name);
end
value = reshape(value, 1, 4);
end
