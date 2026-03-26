function warpedAction = warpActionToAlignedContinuousMagnitude(action, deadzone, outputLevels)
%warpActionToAlignedContinuousMagnitude aligns continuous magnitudes to actuator bins.

arguments
    action
    deadzone (1, 1) double {mustBeNonnegative, mustBeLessThan(deadzone, 1)} = 0.05
    outputLevels (1, :) double = [64 96 128 160 192 224 255] / 255
end

action = double(action(:));
outputLevels = unique(sort(abs(double(outputLevels(:)'))));
outputLevels = outputLevels(outputLevels > 0);
if isempty(outputLevels)
    warpedAction = zeros(size(action));
    return;
end

magnitude = min(abs(action), 1);
warpedMagnitude = zeros(size(magnitude));
activeMask = magnitude >= deadzone;
if any(activeMask)
    anchorsIn = linspace(0, 1, numel(outputLevels));
    scaledMagnitude = (magnitude(activeMask) - deadzone) / max(1 - deadzone, eps);
    scaledMagnitude = min(max(scaledMagnitude, 0), 1);
    warpedMagnitude(activeMask) = interp1( ...
        anchorsIn, outputLevels, scaledMagnitude, "linear");
end

warpedAction = sign(action) .* warpedMagnitude;
end
