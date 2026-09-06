function results = validateReducedOrderPlant(conditions, parameters, tauByMotor)
%validateReducedOrderPlant evalua un modelo reducido en repeticiones HELD-OUT.
%
%   Solo se usan repeticiones VALIDATION. La condicion inicial de cada
%   prediccion es la primera muestra de la propia repeticion held-out: el modelo
%   recibe la misma informacion que tendria en el sandbox, ni mas ni menos.
%
%   Metricas del preregistro: RMSE, NRMSE (normalizado por la carrera empirica),
%   MAE, error de posicion final, violaciones de direccion y violaciones del
%   limite empirico. Se anade la dispersion entre repeticiones VALIDATION como
%   referencia, no como criterio.

arguments
    conditions (1, :) struct
    parameters table
    tauByMotor (1, 4) double
end

rows = cell(numel(conditions), 1);
for i = 1:numel(conditions)
    c = conditions(i);
    row = parameters(parameters.motor == c.motor & parameters.direction == c.direction & ...
        parameters.pwm == c.pwm, :);
    assert(height(row) == 1, "Sandbox:S4MissingParameter", ...
        "Falta v_inf para motor %d, %s, PWM %d.", c.motor, c.direction, c.pwm);
    vInf = row.v_inf_counts_per_s;
    tau = tauByMotor(c.motor);

    squaredError = 0; absoluteError = 0; samples = 0;
    endpointError = zeros(1, size(c.val, 2));
    directionViolations = 0; limitViolations = 0;
    expectedSign = 1;
    if c.direction == "opening"
        expectedSign = -1;
    end

    for j = 1:size(c.val, 2)
        y = c.val(:, j);
        yHat = reducedOrderPlantResponse(y(1), vInf, tau, c.t, c.limits);
        squaredError = squaredError + sum((yHat - y) .^ 2);
        absoluteError = absoluteError + sum(abs(yHat - y));
        samples = samples + numel(y);
        endpointError(j) = abs(yHat(end) - y(end));
        step = diff(yHat);
        directionViolations = directionViolations + nnz(step * expectedSign < -1e-9);
        limitViolations = limitViolations + nnz(yHat < c.limits(1) - 1e-9 | yHat > c.limits(2) + 1e-9);
    end

    rmse = sqrt(squaredError / samples);
    valSd = nan;
    if size(c.val, 2) > 1
        valSd = sqrt(mean(var(c.val, 0, 2)));
    end

    rows{i} = table(c.motor, string(c.direction), c.pwm, size(c.val, 2), c.stroke, ...
        vInf, tau * 1000, rmse, rmse / c.stroke, absoluteError / samples, ...
        mean(endpointError), directionViolations, limitViolations, valSd, ...
        VariableNames = ["motor", "direction", "pwm", "n_val", "stroke", ...
        "v_inf_counts_per_s", "tau_ms", "RMSE", "NRMSE", "MAE", ...
        "endpoint_error", "direction_violations", "limit_violations", "val_rep_sd"]);
end
results = vertcat(rows{:});
end
