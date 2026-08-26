function [effectiveAction, appliedPwm] = quantizeBaselineAction( ...
        rawAction, maxPwm, activationThreshold, commandLevels)
%quantizeBaselineAction pure implementation of the baseline PWM interface.

arguments
    rawAction {mustBeNumeric, mustBeReal}
    maxPwm (1, 1) double {mustBePositive}
    activationThreshold (1, 1) double {mustBeNonnegative}
    commandLevels {mustBeNumeric, mustBeReal}
end

if numel(rawAction) ~= 4 || any(~isfinite(rawAction), "all")
    error("quantizeBaselineAction:InvalidAction", ...
        "rawAction must be a finite real numeric four-vector.");
end
if ~isfinite(maxPwm) || fix(maxPwm) ~= maxPwm
    error("quantizeBaselineAction:InvalidMaxPwm", ...
        "maxPwm must be a finite positive integer.");
end
if ~isfinite(activationThreshold) || activationThreshold > 1
    error("quantizeBaselineAction:InvalidActivationThreshold", ...
        "activationThreshold must lie within [0,1].");
end
levels = sort(unique(abs(double(commandLevels(:)'))));
if isempty(levels) || any(~isfinite(levels)) || ...
        any(levels < 0) || any(levels > maxPwm) || ...
        any(fix(levels) ~= levels)
    error("quantizeBaselineAction:InvalidLevels", ...
        "commandLevels must be finite integer PWM magnitudes within maxPwm.");
end
nonZeroLevels = levels(levels > 0);
if isempty(nonZeroLevels)
    error("quantizeBaselineAction:NoActiveLevel", ...
        "At least one positive command level is required.");
end

rawAction = max(-1, min(1, double(rawAction(:))));
effectiveAction = zeros(4, 1);
appliedPwm = zeros(4, 1);
for motorIdx = 1:4
    value = rawAction(motorIdx);
    if abs(value) < activationThreshold
        continue;
    end
    targetPwm = abs(value) * maxPwm;
    [~, levelIdx] = min(abs(nonZeroLevels - targetPwm));
    appliedPwm(motorIdx) = sign(value) * nonZeroLevels(levelIdx);
    effectiveAction(motorIdx) = appliedPwm(motorIdx) / maxPwm;
end
end
