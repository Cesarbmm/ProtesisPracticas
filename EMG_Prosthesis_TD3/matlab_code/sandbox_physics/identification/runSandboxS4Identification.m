function summary = runSandboxS4Identification(options)
%runSandboxS4Identification FASE S4: identificacion de planta dinamica reducida.
%
%   Ejecuta, en el orden que fija PREREGISTRO_S4_DYNAMIC_IDENTIFICATION.md:
%     1. dataset + split congelado + repeatability floor (solo FIT)
%     2. ajuste del Modelo A (tau = 0) sobre repeticiones FIT
%     3. ajuste del Modelo B (tau por motor) sobre repeticiones FIT
%     4. validacion held-out de ambos sobre repeticiones VALIDATION
%     5. test de convergencia numerica (C5)
%     6. gate C1-C5 y veredicto S4
%
%   No entrena RL, no toca src/@Env, no modifica pattern_curve.mat, no lee el
%   dataset de sujetos y no crea DynamicPlantAdapter salvo que el gate lo
%   autorice — y esa creacion es un paso posterior y manual, no automatico.
%
%   Uso:  summary = runSandboxS4Identification();

arguments
    options.outputDir (1, 1) string = ""
end

here = string(fileparts(mfilename("fullpath")));
sandboxRoot = fileparts(here);
if options.outputDir == ""
    options.outputDir = fullfile(sandboxRoot, "results", "s4_identification");
end
if ~isfolder(options.outputDir)
    mkdir(options.outputDir);
end

fprintf("S4 · 1/6 dataset, split congelado y repeatability floor\n");
[dataset, split, floorTable] = buildS4IdentificationDataset(outputDir = here);
writetable(split, fullfile(options.outputDir, "s4_repetition_split.csv"));
writetable(floorTable, fullfile(options.outputDir, "s4_condition_floor.csv"));
save(fullfile(options.outputDir, "s4_identification_dataset.mat"), "dataset", "-v7.3");

conditions = s4Conditions();
assert(numel(conditions) == 56, "Sandbox:S4Conditions", "Se esperaban 56 condiciones.");

fprintf("S4 · 2/6 ajuste Modelo A (tau = 0) sobre FIT\n");
[parametersA, tauA, diagnosticsA] = fitReducedOrderPlant(conditions, tauMode = "zero");

fprintf("S4 · 3/6 ajuste Modelo B (tau por motor) sobre FIT\n");
[parametersB, tauB, diagnosticsB] = fitReducedOrderPlant(conditions, tauMode = "perMotor");
fprintf("        tau identificado [ms]: %s\n", mat2str(round(tauB * 1000, 3)));

fprintf("S4 · 4/6 validacion held-out\n");
resultsA = validateReducedOrderPlant(conditions, parametersA, tauA);
resultsB = validateReducedOrderPlant(conditions, parametersB, tauB);

key = ["motor", "direction", "pwm"];
metrics = ["RMSE", "NRMSE", "MAE", "endpoint_error", "direction_violations", ...
    "limit_violations", "v_inf_counts_per_s", "tau_ms"];
leftTable = resultsA(:, [key, metrics]);
leftTable.Properties.VariableNames = [key, metrics + "_A"];
rightTable = resultsB(:, [key, metrics]);
rightTable.Properties.VariableNames = [key, metrics + "_B"];
merged = innerjoin(leftTable, rightTable, Keys = key);
merged = innerjoin(merged, ...
    floorTable(:, [key, "floor_heldout_rmse", "floor_heldout_nrmse", "floor_nrmse", "stroke"]), ...
    Keys = key);
assert(height(merged) == numel(conditions), "Sandbox:S4Join", ...
    "El cruce de resultados perdio condiciones.");
merged.relative_improvement = (merged.NRMSE_A - merged.NRMSE_B) ./ merged.NRMSE_A;
merged.absolute_improvement = merged.RMSE_A - merged.RMSE_B;

fprintf("S4 · 5/6 convergencia numerica\n");
convergence = localConvergence(conditions, parametersB, tauB);

fprintf("S4 · 6/6 gate\n");
c1 = median(merged.relative_improvement);
c2 = nnz(merged.NRMSE_B <= merged.NRMSE_A + 1e-12);
c3 = nnz(merged.absolute_improvement > merged.floor_heldout_rmse);
c4Direction = sum(resultsB.direction_violations);
c4Limit = sum(resultsB.limit_violations);

gate = struct( ...
    "C1_median_relative_improvement", c1, "C1_threshold", 0.20, "C1_pass", c1 >= 0.20, ...
    "C2_conditions_B_not_worse", c2, "C2_threshold", 42, "C2_pass", c2 >= 42, ...
    "C3_improvement_above_floor", c3, "C3_threshold", 28, "C3_pass", c3 >= 28, ...
    "C4_direction_violations", c4Direction, "C4_limit_violations", c4Limit, ...
    "C4_pass", c4Direction == 0 && c4Limit == 0, ...
    "C5_max_dt_difference", convergence.maxDtDifference, ...
    "C5_max_analytic_difference", convergence.maxAnalyticDifference, ...
    "C5_threshold", 0.5, "C5_pass", convergence.maxDtDifference <= 0.5 && ...
    convergence.maxAnalyticDifference <= 0.5);

if gate.C1_pass && gate.C2_pass && gate.C3_pass && gate.C4_pass && gate.C5_pass
    verdict = "PASS";
elseif ~(gate.C1_pass && gate.C2_pass && gate.C3_pass)
    verdict = "DYNAMIC_MEMORY_NOT_JUSTIFIED";
else
    verdict = "FAIL_NUMERICAL_OR_PHYSICAL";
end

writetable(parametersA, fullfile(options.outputDir, "s4_parameters_modelA.csv"));
writetable(parametersB, fullfile(options.outputDir, "s4_parameters_modelB.csv"));
writetable(resultsA, fullfile(options.outputDir, "s4_validation_modelA.csv"));
writetable(resultsB, fullfile(options.outputDir, "s4_validation_modelB.csv"));
writetable(merged, fullfile(options.outputDir, "s4_validation_merged.csv"));

summary = struct( ...
    "stage", "S4_DYNAMIC_IDENTIFICATION", ...
    "conditions", numel(conditions), ...
    "fit_repetitions", nnz(split.role == "FIT"), ...
    "validation_repetitions", nnz(split.role == "VALIDATION"), ...
    "floor_median_nrmse", median(floorTable.floor_nrmse), ...
    "floor_heldout_median_nrmse", median(floorTable.floor_heldout_nrmse), ...
    "MODEL_A", "dq/dt = v_inf(motor,direccion,PWM)", ...
    "MODEL_A_VALIDATION_NRMSE_median", median(resultsA.NRMSE), ...
    "MODEL_B", "dq/dt = v ; dv/dt = (v_inf - v)/tau(motor)", ...
    "IDENTIFIED_TAU_ms", tauB * 1000, ...
    "MODEL_B_VALIDATION_NRMSE_median", median(resultsB.NRMSE), ...
    "MODEL_B_IMPROVEMENT_VS_A_median", c1, ...
    "INTEGRATION_DT", convergence.dtSeconds, ...
    "INTEGRATION_CONVERGENCE_ERROR", convergence.maxDtDifference, ...
    "DIRECTION_VIOLATIONS", c4Direction, ...
    "EMPIRICAL_LIMIT_VIOLATIONS", c4Limit, ...
    "boundsActiveA", diagnosticsA.boundsActive, ...
    "boundsActiveB", diagnosticsB.boundsActive, ...
    "gate", gate, ...
    "S4_RESULT", verdict, ...
    "DYNAMIC_PLANT_ADAPTER_CREATED", "NO", ...
    "MATEO_SANDRA_USED", false, ...
    "RL_EXECUTED", false, ...
    "SIMSCAPE_USED", false, ...
    "PUSH", "NO");

fid = fopen(fullfile(options.outputDir, "s4_summary.json"), "w", "n", "UTF-8");
assert(fid >= 0, "Sandbox:S4Write", "No se pudo escribir s4_summary.json");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s\n", jsonencode(summary, PrettyPrint = true));

fprintf("\nS4_RESULT = %s\n", verdict);
fprintf("  C1 mejora relativa mediana %.5f (>= 0.20): %d\n", c1, gate.C1_pass);
fprintf("  C2 B no peor en %d/56 (>= 42): %d\n", c2, gate.C2_pass);
fprintf("  C3 mejora sobre el suelo en %d/56 (>= 28): %d\n", c3, gate.C3_pass);
fprintf("  C4 violaciones direccion %d, limite %d (== 0): %d\n", c4Direction, c4Limit, gate.C4_pass);
fprintf("  C5 convergencia %.3e cuentas (<= 0.5): %d\n", convergence.maxDtDifference, gate.C5_pass);
end

% =======================================================================
function convergence = localConvergence(conditions, parameters, tauByMotor)
%localConvergence C5: RK4 con dt = 2, 1 y 0.5 ms contra la solucion analitica.
% Se prueba tambien un tau de estres de 20 ms para no medir solo el caso facil.
dtList = [0.002, 0.001, 0.0005];
maxDtDifference = 0;
maxAnalyticDifference = 0;
t = 0.2;   % un paso de control completo
for i = 1:numel(conditions)
    c = conditions(i);
    row = parameters(parameters.motor == c.motor & parameters.direction == c.direction & ...
        parameters.pwm == c.pwm, :);
    for tau = [tauByMotor(c.motor), 0.020]
        wide = [-1e12, 1e12];   % sin saturar: se mide el integrador, no el clamp
        analytic = reducedOrderPlantResponse(0, row.v_inf_counts_per_s, tau, t, wide);
        values = zeros(size(dtList));
        for k = 1:numel(dtList)
            values(k) = reducedOrderPlantResponse(0, row.v_inf_counts_per_s, tau, t, wide, ...
                method = "rk4", dt = dtList(k));
        end
        maxAnalyticDifference = max(maxAnalyticDifference, max(abs(values - analytic)));
        maxDtDifference = max(maxDtDifference, abs(values(2) - values(3)));
    end
end
convergence = struct("dtSeconds", dtList, "maxDtDifference", maxDtDifference, ...
    "maxAnalyticDifference", maxAnalyticDifference, ...
    "note", "modelo lineal por paso: se usa la solucion analitica; RK4 es contraste");
end
