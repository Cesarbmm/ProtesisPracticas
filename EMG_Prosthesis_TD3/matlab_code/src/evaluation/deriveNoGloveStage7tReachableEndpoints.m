function endpoints = deriveNoGloveStage7tReachableEndpoints( ...
        firstStepQ, qMin, tolerance)
%deriveNoGloveStage7tReachableEndpoints derives the simulator's true
%zero-velocity firstStep equilibria from the frozen corpus itself.
%
% ETAPA 7T originally assumed every firstStep episode reaches the idealized
% calibrated bound (q=positionMin for a relaxed start, q=positionMax for an
% Opening-type start driven by Env.reset's closeHand + long toc sequence).
% That assumption is false for the Opening-type cohort: prosthesis_simulator
% replays an empirically fitted per-motor trajectory (fit_C2.mat /
% pattern_curve.mat) whose sample index is clamped to the recorded curve
% length (see prosthesis_simulator.m, predict_1dim, the "idx = max(1,
% min(idx, ws_len))" clamp). Beyond that clamp, continued full-speed PWM
% cannot move the simulated position further, so the curve's last sample is
% a genuine, reproducible zero-velocity equilibrium of THIS simulator - it is
% just not equal to the idealized positionMax=1.
%
% This function never re-runs the simulator (ETAPA 7T stays fully offline).
% It only reads the already-frozen firstStep positions and certifies, from
% the frozen data alone, that every non-lower-endpoint row agrees with every
% other one on the same equilibrium value per motor. That agreement (not an
% assumption about the idealized bound) is what licenses treating the value
% as "the reachable upper endpoint" for ETAPA 7T's invariant.

arguments
    firstStepQ (:, 4) double
    qMin (1, 4) double
    tolerance (1, 1) double {mustBePositive}
end

if isempty(firstStepQ)
    error("deriveNoGloveStage7tReachableEndpoints:EmptyInput", ...
        "At least one firstStep row is required.");
end
if any(~isfinite(firstStepQ), "all") || any(~isfinite(qMin))
    error("deriveNoGloveStage7tReachableEndpoints:NonfiniteInput", ...
        "Position values must be finite.");
end

lowerMask = all(abs(firstStepQ - qMin) <= tolerance, 2);
upperRows = firstStepQ(~lowerMask, :);

if isempty(upperRows)
    qUpper = nan(1, 4);
    maxDeviation = 0;
    consistent = true;
else
    qUpper = mean(upperRows, 1);
    maxDeviation = max(abs(upperRows - qUpper), [], "all");
    consistent = maxDeviation <= tolerance;
end

endpoints = struct( ...
    "schemaVersion", 1, ...
    "qLower", qMin, ...
    "qUpper", qUpper, ...
    "lowerRowCount", sum(lowerMask), ...
    "upperRowCount", sum(~lowerMask), ...
    "maxUpperDeviation", maxDeviation, ...
    "upperEquilibriumConsistent", consistent, ...
    "tolerance", tolerance, ...
    "source", "derivedFromFrozenFirstStepCorpus");
end
