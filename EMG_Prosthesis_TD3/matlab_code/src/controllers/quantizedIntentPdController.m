function [rawAction, effectiveAction, appliedPwm, info] = ...
    quantizedIntentPdController(qRef, q, vRef, v, controller, actuator)
%quantizedIntentPdController conventional P/PD baseline for q_ref tracking.
%
% The controller contains no EMG, reward, agent or hardware access. A P
% baseline is selected by setting kd=0; nonzero kd enables the same explicit
% velocity-error form without changing the quantization contract.

qRef = validateFourVector(qRef, "qRef");
q = validateFourVector(q, "q");
vRef = validateFourVector(vRef, "vRef");
v = validateFourVector(v, "v");
controller = validateController(controller);
actuator = validateActuator(actuator);

positionError = qRef - q;
velocityError = vRef - v;
rawAction = controller.kp .* positionError + ...
    controller.kd .* velocityError;
holdMask = abs(positionError) <= controller.positionTolerance & ...
    abs(velocityError) <= controller.velocityTolerance;
rawAction(holdMask) = 0;
rawAction = max(-controller.maxAction, ...
    min(controller.maxAction, rawAction));

[effectiveAction, appliedPwm] = quantizeBaselineAction( ...
    rawAction, actuator.maxPwm, actuator.activationThreshold, ...
    actuator.commandLevels);
info = struct( ...
    "positionError", positionError, ...
    "velocityError", velocityError, ...
    "holdMask", holdMask, ...
    "controllerType", string(controller.type));
end

function value = validateFourVector(value, fieldName)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 4 || ...
        any(~isfinite(value), "all")
    error("quantizedIntentPdController:InvalidVector", ...
        "%s must be a finite real numeric four-vector.", fieldName);
end
value = double(value(:));
end

function controller = validateController(controller)
required = { ...
    'type', 'kp', 'kd', 'maxAction', ...
    'positionTolerance', 'velocityTolerance'};
if ~isstruct(controller) || ~isscalar(controller) || ...
        ~all(isfield(controller, required))
    error("quantizedIntentPdController:InvalidController", ...
        "controller is missing required fields.");
end
controller.type = string(controller.type);
if ~isscalar(controller.type) || ...
        ~any(controller.type == ["P", "PD"])
    error("quantizedIntentPdController:InvalidController", ...
        "controller.type must be P or PD.");
end
controller.kp = expandNonnegativeFourVector(controller.kp, "kp");
controller.kd = expandNonnegativeFourVector(controller.kd, "kd");
controller.maxAction = expandBoundedFourVector( ...
    controller.maxAction, "maxAction", 0, 1, false);
controller.positionTolerance = expandBoundedFourVector( ...
    controller.positionTolerance, "positionTolerance", 0, Inf, true);
controller.velocityTolerance = expandBoundedFourVector( ...
    controller.velocityTolerance, "velocityTolerance", 0, Inf, true);
if controller.type == "P" && any(controller.kd ~= 0)
    error("quantizedIntentPdController:InvalidController", ...
        "A P controller requires kd=0.");
end
end

function actuator = validateActuator(actuator)
required = {'maxPwm', 'activationThreshold', 'commandLevels'};
if ~isstruct(actuator) || ~isscalar(actuator) || ...
        ~all(isfield(actuator, required))
    error("quantizedIntentPdController:InvalidActuator", ...
        "actuator is missing required fields.");
end
end

function value = expandNonnegativeFourVector(value, fieldName)
value = expandBoundedFourVector(value, fieldName, 0, Inf, true);
end

function value = expandBoundedFourVector( ...
        value, fieldName, lowerBound, upperBound, allowZero)
if ~isnumeric(value) || ~isreal(value) || ...
        ~(isscalar(value) || numel(value) == 4) || ...
        any(~isfinite(value), "all")
    error("quantizedIntentPdController:InvalidController", ...
        "controller.%s must be a finite scalar or four-vector.", fieldName);
end
value = double(value(:));
if isscalar(value)
    value = repmat(value, 4, 1);
end
if any(value < lowerBound) || any(value > upperBound) || ...
        (~allowZero && any(value == 0))
    error("quantizedIntentPdController:InvalidController", ...
        "controller.%s lies outside its valid range.", fieldName);
end
end
