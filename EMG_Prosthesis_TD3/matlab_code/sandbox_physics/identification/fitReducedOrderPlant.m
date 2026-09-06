function [parameters, tauByMotor, diagnostics] = fitReducedOrderPlant(conditions, options)
%fitReducedOrderPlant ajusta los modelos reducidos A y B SOLO con FIT.
%
%   Modelo A: tauMode = "zero"     -> tau = 0, se ajusta v_inf por condicion.
%   Modelo B: tauMode = "perMotor" -> tau por motor + v_inf por condicion.
%
%   Optimizacion DETERMINISTA y sin componente estocastica, por tanto sin
%   semilla: rejilla acotada + refinamiento con fminbnd (MATLAB base).
%   Ninguna repeticion VALIDATION entra aqui. Comprobado con assert.
%
%   Bounds del preregistro:
%       |v_inf| <= vInfBoundFactor * carrera / duracion   (por defecto 3)
%       tau     en [1e-4, 1] s
%   Se registra si un bound queda activo: un parametro en el bound NO es un
%   optimo libre y hay que reportarlo como tal.

arguments
    conditions (1, :) struct
    options.tauMode (1, 1) string {mustBeMember(options.tauMode, ["zero", "perMotor"])} = "zero"
    options.vInfBoundFactor (1, 1) double {mustBePositive} = 3
    options.tauBounds (1, 2) double = [1e-4, 1]
    options.gridPoints (1, 1) double {mustBeInteger, mustBePositive} = 241
end

motors = unique([conditions.motor]);
tauByMotor = zeros(1, 4);
tauProfile = struct("motor", {}, "tau", {}, "cost", {});

if options.tauMode == "perMotor"
    for m = motors
        grid = [options.tauBounds(1), logspace(log10(0.005), log10(options.tauBounds(2)), 24)];
        cost = arrayfun(@(t) localMotorCost(conditions, m, t, options), grid);
        [bestCost, k] = min(cost);
        lo = grid(max(1, k - 1));
        hi = grid(min(numel(grid), k + 1));
        [tauRefined, refinedCost] = fminbnd(@(t) localMotorCost(conditions, m, t, options), ...
            lo, hi, optimset("TolX", 1e-6));
        if refinedCost <= bestCost
            tauByMotor(m) = tauRefined;
        else
            tauByMotor(m) = grid(k);
        end
        tauProfile(end + 1) = struct("motor", m, "tau", grid, "cost", cost); %#ok<AGROW>
    end
end

rows = cell(numel(conditions), 1);
for i = 1:numel(conditions)
    c = conditions(i);
    tau = tauByMotor(c.motor);
    [vInf, sse, atBound, bounds] = localFitVinf(c, tau, options);
    rows{i} = table(c.motor, string(c.direction), c.pwm, vInf, tau * 1000, sse, ...
        numel(c.fit), atBound, bounds(1), bounds(2), ...
        VariableNames = ["motor", "direction", "pwm", "v_inf_counts_per_s", "tau_ms", ...
        "fit_sse", "n_fit_samples", "at_bound", "bound_low", "bound_high"]);
end
parameters = vertcat(rows{:});

diagnostics = struct( ...
    "tauMode", options.tauMode, ...
    "tauByMotor_ms", tauByMotor * 1000, ...
    "vInfBoundFactor", options.vInfBoundFactor, ...
    "tauBounds", options.tauBounds, ...
    "boundsActive", sum(parameters.at_bound), ...
    "totalFitSse", sum(parameters.fit_sse), ...
    "tauProfile", tauProfile, ...
    "optimizer", "rejilla acotada + fminbnd, determinista, sin semilla");
end

% =======================================================================
function total = localMotorCost(conditions, motor, tau, options)
total = 0;
for i = 1:numel(conditions)
    if conditions(i).motor ~= motor
        continue
    end
    [~, sse] = localFitVinf(conditions(i), tau, options);
    total = total + sse;
end
end

% =======================================================================
function [vInf, sse, atBound, bounds] = localFitVinf(c, tau, options)
span = c.stroke / max(c.t(end), eps);
magnitude = options.vInfBoundFactor * span;
if c.direction == "closing"
    bounds = [0, magnitude];
else
    bounds = [-magnitude, 0];
end

grid = linspace(bounds(1), bounds(2), options.gridPoints);
cost = localCostVector(c, tau, grid);
[bestCost, k] = min(cost);
lo = grid(max(1, k - 1));
hi = grid(min(numel(grid), k + 1));
[vRefined, refinedCost] = fminbnd(@(v) localCostVector(c, tau, v), lo, hi, ...
    optimset("TolX", 1e-6));
if refinedCost <= bestCost
    vInf = vRefined;
    sse = refinedCost;
else
    vInf = grid(k);
    sse = bestCost;
end
atBound = abs(vInf - bounds(1)) < 1e-6 || abs(vInf - bounds(2)) < 1e-6;
end

% =======================================================================
function cost = localCostVector(c, tau, vCandidates)
%localCostVector coste para un vector de candidatos v_inf, vectorizado.
if tau <= 0
    g = c.t;
else
    g = c.t - tau * (1 - exp(-c.t / tau));
end
vCandidates = vCandidates(:)';
cost = zeros(1, numel(vCandidates));
for j = 1:size(c.fit, 2)
    y = c.fit(:, j);
    q = y(1) + g * vCandidates;
    q = min(max(q, c.limits(1)), c.limits(2));
    cost = cost + sum((q - y) .^ 2, 1);
end
end
