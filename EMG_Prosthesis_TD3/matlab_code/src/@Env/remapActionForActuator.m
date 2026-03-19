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

levels = sort(unique(abs(double(this.actionCommandLevels(:)'))));
nonZeroLevels = levels(levels > 0);

effectiveAction = zeros(size(action));
appliedPwm = zeros(size(action));

for i = 1:numel(action)
    actionValue = action(i);
    magnitude = abs(actionValue);

    if magnitude < this.actionCommandActivationThreshold
        continue
    end

    targetPwm = magnitude * maxPwm;
    [~, idx] = min(abs(nonZeroLevels - targetPwm));
    pwmMagnitude = nonZeroLevels(idx);

    appliedPwm(i) = sign(actionValue) * pwmMagnitude;
    effectiveAction(i) = appliedPwm(i) / maxPwm;
end
end
