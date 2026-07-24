function [effectiveAction, appliedPwm] = remapActionForActuator(this, action)
%remapActionForActuator maps continuous policy output to the effective
%actuator command used by the simulator.

action = max(-1, min(1, double(action(:))));
maxPwm = max(abs(this.speeds));

if ~this.simMotors || ~this.quantizeCommandsForSimulation
    appliedPwm = round(action * maxPwm);
    effectiveAction = appliedPwm / maxPwm;
    return
end

effectiveAction = zeros(size(action));
appliedPwm = zeros(size(action));
actionInterfaceVariant = string(this.actionInterfaceVariant);

for i = 1:numel(action)
    actionValue = action(i);
    magnitude = abs(actionValue);

    if magnitude < this.actionCommandActivationThreshold
        continue
    end

    if actionInterfaceVariant == "motorCalibratedQuantized"
        levels = localGetMotorLevels( ...
            this.actionCommandLevelsByMotor, this.actionCommandLevels, i);
    else
        levels = sort(unique(abs(double(this.actionCommandLevels(:)'))));
    end
    nonZeroLevels = levels(levels > 0);
    if isempty(nonZeroLevels)
        continue
    end

    targetPwm = magnitude * maxPwm;
    [~, idx] = min(abs(nonZeroLevels - targetPwm));
    pwmMagnitude = nonZeroLevels(idx);

    appliedPwm(i) = sign(actionValue) * pwmMagnitude;
    effectiveAction(i) = appliedPwm(i) / maxPwm;
end
end

function levels = localGetMotorLevels(levelsByMotor, fallbackLevels, motorIdx)
levels = fallbackLevels;
if isstruct(levelsByMotor)
    fieldName = sprintf("m%d", motorIdx);
    if isfield(levelsByMotor, fieldName)
        levels = levelsByMotor.(fieldName);
    end
elseif iscell(levelsByMotor) && numel(levelsByMotor) >= motorIdx
    levels = levelsByMotor{motorIdx};
end
levels = sort(unique(abs(double(levels(:)'))));
end
