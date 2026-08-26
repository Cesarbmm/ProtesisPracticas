function [limitedEncoder, info] = limitSimulationPosition( ...
        encoder, safetyConfig)
%limitSimulationPosition applies configured per-motor simulation bounds.
%
% This adapter is intentionally outside prosthesis_simulator.m. With the
% feature disabled it is an exact identity; with it enabled, only finite
% simulated encoder samples are clipped at the controller boundary.

arguments
    encoder (:, 4) double
    safetyConfig (1, 1) struct
end

required = ["enabled", "mode", "positionMin", "positionMax", ...
    "encoderScale"];
if ~all(isfield(safetyConfig, cellstr(required)))
    error("limitSimulationPosition:InvalidConfiguration", ...
        "The simulation position-safety configuration is incomplete.");
end

enabled = safetyConfig.enabled;
mode = string(safetyConfig.mode);
qMin = double(safetyConfig.positionMin(:)');
qMax = double(safetyConfig.positionMax(:)');
encoderScale = double(safetyConfig.encoderScale(:)');
valid = islogical(enabled) && isscalar(enabled) && ...
    isscalar(mode) && mode == "clipTrajectoryOutput" && ...
    numel(qMin) == 4 && numel(qMax) == 4 && ...
    numel(encoderScale) == 4 && ...
    all(isfinite([qMin, qMax, encoderScale])) && ...
    all(qMax > qMin) && all(encoderScale > 0);
if ~valid
    error("limitSimulationPosition:InvalidConfiguration", ...
        "Position safety must define finite ordered bounds and positive scales.");
end

limitedEncoder = encoder;
interventionMask = false(size(encoder));
if enabled && ~isempty(encoder)
    rawMin = qMin .* encoderScale;
    rawMax = qMax .* encoderScale;
    finiteMask = isfinite(encoder);
    rawMinMatrix = repmat(rawMin, size(encoder, 1), 1);
    rawMaxMatrix = repmat(rawMax, size(encoder, 1), 1);
    interventionMask = finiteMask & ...
        (encoder < rawMin | encoder > rawMax);
    limitedEncoder(finiteMask) = min(max(encoder(finiteMask), ...
        rawMinMatrix(finiteMask)), rawMaxMatrix(finiteMask));
end

info = struct( ...
    "enabled", enabled, ...
    "mode", mode, ...
    "interventionMask", interventionMask, ...
    "interventionCountByMotor", sum(interventionMask, 1), ...
    "interventionCount", sum(interventionMask, "all"));
end
