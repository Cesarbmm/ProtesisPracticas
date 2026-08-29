function [nextLatch, details] = updateIntentDeclaredRestHoldState( ...
        previousLatch, declaredRest, encoderPosition, referencePosition, ...
        positionMseTolerance)
%updateIntentDeclaredRestHoldState advances the causal semantic hold bit.

arguments
    previousLatch (1, 1) logical
    declaredRest (1, 1) logical
    encoderPosition {mustBeNumeric, mustBeReal}
    referencePosition {mustBeNumeric, mustBeReal}
    positionMseTolerance (1, 1) double ...
        {mustBeNonnegative, mustBeFinite}
end

encoderPosition = double(encoderPosition(:)');
referencePosition = double(referencePosition(:)');
if numel(encoderPosition) ~= 4 || numel(referencePosition) ~= 4 || ...
        any(~isfinite(encoderPosition)) || ...
        any(~isfinite(referencePosition))
    error("updateIntentDeclaredRestHoldState:InvalidPosition", ...
        "Encoder and reference positions must be finite four-vectors.");
end

positionMse = mean((encoderPosition-referencePosition).^2);
nearTarget = positionMse <= positionMseTolerance;
if ~declaredRest
    nextLatch = false;
elseif nearTarget
    nextLatch = true;
else
    nextLatch = previousLatch;
end
details = struct("positionMse", positionMse, ...
    "nearTarget", logical(nearTarget), ...
    "declaredRest", declaredRest, ...
    "previousLatch", previousLatch, "nextLatch", nextLatch, ...
    "positionMseTolerance", positionMseTolerance);
end
