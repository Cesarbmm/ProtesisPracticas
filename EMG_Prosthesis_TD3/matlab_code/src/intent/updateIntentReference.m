function [referenceHistory, velocityHistory, referenceState, diagnostics] = ...
        updateIntentReference(initialEncoder, desiredVelocity, ...
        calibration, restMask, initialVelocity)
%updateIntentReference integrates a mechanically bounded intent reference.
%
% Rows of desiredVelocity are causal four-motor commands. The initial
% reference is exactly the supplied encoder position. In declared rest the
% reference holds bit-for-bit and velocity is zero; an infeasible abrupt
% rest request is rejected instead of silently violating acceleration.

arguments
    initialEncoder {mustBeNumeric}
    desiredVelocity {mustBeNumeric}
    calibration
    restMask = []
    initialVelocity {mustBeNumeric} = zeros(1, 4)
end

validation = validateIntentCalibration(calibration);
if ~validation.isValid
    error("updateIntentReference:InvalidCalibration", ...
        "Calibration is invalid: %s", strjoin(validation.issues, "; "));
end

initialEncoder = normalizeFourVector(initialEncoder, ...
    "initialEncoder", "updateIntentReference:InvalidInitialEncoder");
initialVelocity = normalizeFourVector(initialVelocity, ...
    "initialVelocity", "updateIntentReference:InvalidInitialVelocity");
if isempty(desiredVelocity) || ~ismatrix(desiredVelocity) || ...
        size(desiredVelocity, 2) ~= 4 || ~isreal(desiredVelocity) || ...
        any(~isfinite(desiredVelocity), "all")
    error("updateIntentReference:InvalidVelocity", ...
        "desiredVelocity must be a nonempty finite real T-by-4 matrix.");
end
desiredVelocity = double(desiredVelocity);
stepCount = size(desiredVelocity, 1);

if isempty(restMask)
    restMask = false(stepCount, 1);
end
if ~islogical(restMask) || ~isvector(restMask) || ...
        numel(restMask) ~= stepCount
    error("updateIntentReference:InvalidRestMask", ...
        "restMask must be a logical vector with one value per step.");
end
restMask = restMask(:);

limits = calibration.limits;
qMin = double(limits.positionMin);
qMax = double(limits.positionMax);
vMax = double(limits.velocityMax);
aMax = double(limits.accelerationMax);
deltaT = double(limits.deltaT);
if any(initialEncoder < qMin) || any(initialEncoder > qMax)
    error("updateIntentReference:InitialEncoderOutOfRange", ...
        "initialEncoder must already lie within the calibrated position limits.");
end
velocityTolerance = 128 * eps(max(1, max(vMax)));
if any(abs(initialVelocity) > vMax + velocityTolerance)
    error("updateIntentReference:InitialVelocityOutOfRange", ...
        "initialVelocity exceeds the calibrated velocity limits.");
end

referenceHistory = zeros(stepCount, 4);
velocityHistory = zeros(stepCount, 4);
brakingLimited = false(stepCount, 4);
positionLimited = false(stepCount, 4);
accelerationLimited = false(stepCount, 4);
qCurrent = initialEncoder;
vCurrent = initialVelocity;

for stepIdx = 1:stepCount
    if restMask(stepIdx)
        if any(abs(vCurrent) > 64 * eps(max(1, max(abs(vCurrent)))))
            error("updateIntentReference:InfeasibleRestTransition", ...
                "Rest hold was requested before velocity reached zero. " + ...
                "Use the hysteresis low-activity countdown to decelerate first.");
        end
        vNext = zeros(1, 4);
        qNext = qCurrent;
    else
        requested = max(-vMax, min(vMax, desiredVelocity(stepIdx, :)));
        accelerationStep = aMax * deltaT;
        distancePositive = max(0, qMax - qCurrent);
        distanceNegative = max(0, qCurrent - qMin);
        brakingCapPositive = max(0, -accelerationStep + sqrt( ...
            accelerationStep .^ 2 + 2 .* aMax .* distancePositive));
        brakingCapNegative = max(0, -accelerationStep + sqrt( ...
            accelerationStep .^ 2 + 2 .* aMax .* distanceNegative));
        oneStepPositive = distancePositive / deltaT;
        oneStepNegative = distanceNegative / deltaT;

        lowerBound = max(max(-vMax, vCurrent - accelerationStep), ...
            max(-brakingCapNegative, -oneStepNegative));
        upperBound = min(min(vMax, vCurrent + accelerationStep), ...
            min(brakingCapPositive, oneStepPositive));
        if any(lowerBound > upperBound + 128 * eps)
            error("updateIntentReference:InfeasibleBounds", ...
                "No velocity satisfies the current position and acceleration limits.");
        end
        vNext = max(lowerBound, min(upperBound, requested));
        qNext = qCurrent + deltaT .* vNext;
        qNext = max(qMin, min(qMax, qNext));
        % Log the velocity that actually generated the bounded reference.
        vNext = (qNext - qCurrent) ./ deltaT;

        tolerance = 64 * eps(max(1, max(abs(requested))));
        accelerationLimited(stepIdx, :) = ...
            abs(vNext - requested) > tolerance;
        brakingLimited(stepIdx, :) = ...
            (requested > upperBound + tolerance & ...
            abs(upperBound - brakingCapPositive) <= tolerance) | ...
            (requested < lowerBound - tolerance & ...
            abs(lowerBound + brakingCapNegative) <= tolerance);
        positionLimited(stepIdx, :) = ...
            qNext <= qMin + 64 * eps | qNext >= qMax - 64 * eps;
    end

    referenceHistory(stepIdx, :) = qNext;
    velocityHistory(stepIdx, :) = vNext;
    qCurrent = qNext;
    vCurrent = vNext;
end

referenceState = struct("position", qCurrent, "velocity", vCurrent);
diagnostics = struct( ...
    "initialPosition", initialEncoder, ...
    "initialVelocity", initialVelocity, ...
    "restMask", restMask, ...
    "brakingLimited", brakingLimited, ...
    "positionLimited", positionLimited, ...
    "accelerationLimited", accelerationLimited, ...
    "deltaT", deltaT);
end

function value = normalizeFourVector(value, fieldName, errorId)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 4 || ...
        any(~isfinite(value), "all")
    error(errorId, "%s must be a finite real four-vector.", fieldName);
end
value = double(value(:)');
end
