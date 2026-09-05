function summary = runPairedReferenceE0P(options)
%runPairedReferenceE0P mide la planta canonica sin EMG ni controladores.
% Desde matlab_code, con src, config y analysis/paired_reference en el path:
%   summary = runPairedReferenceE0P();
%   summary = runPairedReferenceE0P(outputDir="ruta/de/resultados");
%
% El diagnostico principal usa 21 posiciones por motor entre el minimo y
% maximo globales de sus limites, en unidades reales de encoder. Un segundo
% barrido usa los limites de cada combinacion, como el workflow original E0.
% Las fracciones de carrera son desplazamientos / carrera global del motor;
% NO son fracciones de tiempo de la curva. Los CSV largos incluyen q inicial.
% Ejecuta al final los tests de planta y guarda su resultado y el gate E0P.
% No regenera ni modifica el oraculo proporcionado, ni los datos de planta.

arguments
    options.outputDir (1, 1) string = ""
end

analysisDir = string(fileparts(mfilename("fullpath")));
matlabDir = fileparts(fileparts(analysisDir));
simDir = string(fullfile(matlabDir, "src", "@SimController"));
if options.outputDir == ""
    options.outputDir = string(fullfile(analysisDir, "e0p_results"));
end
if ~isfolder(options.outputDir)
    mkdir(options.outputDir);
end

settings = struct("source", "patternCurveCanonical", ...
    "curvePath", string(fullfile(simDir, "pattern_curve.mat")), ...
    "limitsPath", string(fullfile(simDir, "plant_limits_canonical.csv")), ...
    "oraclePath", string(fullfile(analysisDir, "plant_e0_regression_cases.csv")), ...
    "fitC2Path", string(fullfile(simDir, "fit_C2.mat")), ...
    "samplingPeriod", 0.14, "operationalPeriod", 0.2, ...
    "stressDuration", 3.0, "absoluteTolerance", 1e-9, "nInitial", 21);

manifest = pairedReferencePlantManifest(plantSource=settings.source, ...
    canonicalCurvePath=settings.curvePath, canonicalLimitsPath=settings.limitsPath, ...
    fitC2Path=settings.fitC2Path, ...
    outputPath=fullfile(options.outputDir, "plant_manifest.json"));
assert(manifest.simPlantSource == settings.source, "Fuente de manifiesto inconsistente.");
limits = readtable(settings.limitsPath, TextType="string");
curves = load(settings.curvePath, "avgs").avgs;

[globalCases, globalLong, globalDiagnostics] = sweep(limits, curves, settings, "globalPerMotor");
[combinationCases, combinationLong, combinationDiagnostics] = ...
    sweep(limits, curves, settings, "perCombination");
[regression, regressionLong] = checkRegression(settings);

writetable(globalDiagnostics, fullfile(options.outputDir, "pwm_destination_diagnostics.csv"));
writetable(combinationDiagnostics, fullfile(options.outputDir, ...
    "pwm_destination_diagnostics_combination_limits.csv"));
writeSweep(globalCases, globalLong, options.outputDir, "");
writeSweep(combinationCases, combinationLong, options.outputDir, "_combination_limits");
writetable(regression, fullfile(options.outputDir, "e0_regression_results.csv"));
writetable(regressionLong, fullfile(options.outputDir, "e0_regression_trajectories.csv"));

summary = struct();
summary.simPlantSource = settings.source;
summary.patternCurveSHA256 = manifest.patternCurveSHA256;
summary.absoluteTolerance = settings.absoluteTolerance;
summary.endpointGrouping = "sorted groups of diameter <= absoluteTolerance; no relative tolerance";
summary.samplingPeriod = settings.samplingPeriod;
summary.operationalPeriod = settings.operationalPeriod;
summary.stressDuration = settings.stressDuration;
summary.mainGrid = "globalPerMotor: 21 points over min(min_lim)..max(max_lim) for each motor";
summary.comparisonGrid = "perCombination: 21 points over each motor/PWM/direction limits";
summary.strokeFractionDefinition = "abs(q_final-q_initial)/(global_motor_max-global_motor_min)";
summary.monotonicityDefinition = "case fails if any commanded-sign * diff([q_initial; trajectory]) < -1e-9";
summary.fitC2Present = manifest.fitC2Present;
summary.curveFittingToolboxPresent = manifest.curveFittingToolboxPresent;
summary.globalPerMotor = summarizeSweep(globalCases, globalDiagnostics);
summary.perCombination = summarizeSweep(combinationCases, combinationDiagnostics);
summary.E0_REGRESSION_CASES = height(regression);
summary.E0_REGRESSION_MAX_ERROR = max(regression.max_abs_error);
summary.E0_REGRESSION_NPOINT_MISMATCHES = nnz(~regression.n_points_match);
summary.E0_REGRESSION_PASS = all(regression.regression_pass);
summary.OPERATIONAL_MONOTONICITY_FAILURES = summary.globalPerMotor.operationalMonotonicityFailures;
% El campo historico corresponde a la rejilla E0 por combinacion.
summary.M3_LONG_HORIZON_FAILURES = summary.perCombination.motor3ClosingStressFailures;
summary.MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION = ...
    "diagnostic only; artificial 3.0 s horizon, excluded from operational gate";
summary.oracleStressCases = nnz(regression.duration == settings.stressDuration);
summary.oracleMotor3ClosingStressFailures = nnz(regression.duration == settings.stressDuration & ...
    regression.motor == 3 & regression.pwm > 0 & ~regression.monotonic);
summary.oracleOtherStressFailures = nnz(regression.duration == settings.stressDuration & ...
    ~(regression.motor == 3 & regression.pwm > 0) & ~regression.monotonic);
summary.E2_AUTHORIZED = false;
summary.RL_AUTHORIZED = false;
summary.outputDir = options.outputDir;
testDir = fullfile(matlabDir, "tests", "paired_reference");
testResults = runtests([fullfile(testDir, "testPairedReferencePlantCanonicalSource.m"), ...
    fullfile(testDir, "testPairedReferencePlantHoldOutsideCurve.m"), ...
    fullfile(testDir, "testPairedReferenceStage0PlantSanity.m")]);
testTable = table(testResults);
writetable(testTable(:, ["Name", "Passed", "Failed", "Incomplete", "Duration"]), ...
    fullfile(options.outputDir, "test_results.csv"));
summary.TESTS = numel(testResults);
summary.TESTS_PASS = all([testResults.Passed]);
summary.OUT_OF_DOMAIN_HOLD_PASS = summary.globalPerMotor.outOfDomainHoldFailures == 0 && ...
    summary.perCombination.outOfDomainHoldFailures == 0;
summary.E0P_RESULT = "FAIL";
if summary.TESTS_PASS && summary.E0_REGRESSION_PASS && summary.OUT_OF_DOMAIN_HOLD_PASS && ...
        summary.OPERATIONAL_MONOTONICITY_FAILURES == 0 && ...
        summary.perCombination.operationalMonotonicityFailures == 0
    summary.E0P_RESULT = "PASS";
end
writeJson(fullfile(options.outputDir, "e0p_summary.json"), summary);
disp(summary);
assert(summary.E0P_RESULT == "PASS", "E0P_RESULT = FAIL; revisar artefactos y test_results.csv.");
end

function [cases, longTable, diagnostics] = sweep(limits, curves, settings, gridName)
levels = [64 96 128 160 192 224 255];
durations = [settings.operationalPeriod settings.stressDuration];
nGroups = 4 * 2 * numel(levels);
nCases = nGroups * settings.nInitial * numel(durations);
caseRows = cell(nCases, 1);
trajectoryRows = cell(nCases, 1);
diagnosticRows = cell(nGroups, 1);
motorMin = zeros(1, 4); motorMax = motorMin;
for motor = 1:4
    selected = limits.motor == motor;
    motorMin(motor) = min(limits.min_lim(selected));
    motorMax(motor) = max(limits.max_lim(selected));
end
mid = (motorMin + motorMax) / 2;
caseIndex = 0; groupIndex = 0;
for motor = 1:4
    stroke = motorMax(motor) - motorMin(motor);
    assert(stroke > 0, "Carrera global de motor no positiva.");
    for directionSign = [1 -1]
        if directionSign > 0
            direction = "closing";
        else
            direction = "opening";
        end
        for level = levels
            storedLevel = level;
            if level == 255, storedLevel = 256; end
            row = limits(limits.motor == motor & limits.direction == direction & ...
                limits.speed_value == storedLevel, :);
            assert(height(row) == 1, "Falta una combinacion unica de limites.");
            if gridName == "globalPerMotor"
                positions = linspace(motorMin(motor), motorMax(motor), settings.nInitial);
            else
                positions = linspace(row.min_lim, row.max_lim, settings.nInitial);
            end
            curve = curves.(row.speed_field).(direction).(sprintf("m_%d", motor)).avg;
            operationalFinal = zeros(settings.nInitial, 1);
            for duration = durations
                for positionIndex = 1:settings.nInitial
                    initial = mid;
                    initial(motor) = positions(positionIndex);
                    pwm = directionSign * level;
                    series = simulate(initial, motor, pwm, duration, settings);
                    directedSteps = directionSign * diff([initial(motor); series]);
                    monotonic = all(directedSteps >= -settings.absoluteTolerance);
                    clamped = min(row.max_lim, max(row.min_lim, initial(motor)));
                    if directionSign > 0
                        foundStart = any(curve >= clamped);
                    else
                        foundStart = any(curve <= clamped);
                    end
                    held = all(abs(series - initial(motor)) <= settings.absoluteTolerance);
                    caseIndex = caseIndex + 1;
                    caseRows{caseIndex} = struct("case_id", caseIndex, "grid", gridName, ...
                        "motor", motor, "direction", direction, "pwm", pwm, ...
                        "initial_index", positionIndex, "q_initial", initial(motor), ...
                        "duration", duration, "n_points", numel(series), "first", series(1), ...
                        "q_final", series(end), "trajectory_sum", sum(series), ...
                        "displacement", series(end) - initial(motor), ...
                        "abs_stroke_fraction", abs(series(end) - initial(motor)) / stroke, ...
                        "monotonic", monotonic, "n_reverse_steps", ...
                        nnz(directedSteps < -settings.absoluteTolerance), ...
                        "minimum_directed_step", min(directedSteps), ...
                        "out_of_curve_domain", ~foundStart, "held_initial", held);
                    trajectoryRows{caseIndex} = trajectoryTable(caseIndex, gridName, motor, pwm, ...
                        initial(motor), duration, series);
                    if duration == settings.operationalPeriod
                        operationalFinal(positionIndex) = series(end);
                    end
                end
            end
            displacement = operationalFinal - positions(:);
            fractions = abs(displacement) / stroke;
            [nUnique, modalCount] = countDestinations(operationalFinal, settings.absoluteTolerance);
            groupIndex = groupIndex + 1;
            diagnosticRows{groupIndex} = struct("grid", gridName, "motor", motor, ...
                "direction", direction, "pwm", directionSign * level, "pwm_magnitude", level, ...
                "duration", settings.operationalPeriod, "n_initial", settings.nInitial, ...
                "n_unique_endpoints", nUnique, "mean_displacement", mean(displacement), ...
                "min_displacement", min(displacement), "max_displacement", max(displacement), ...
                "mean_abs_stroke_fraction", mean(fractions), ...
                "min_abs_stroke_fraction", min(fractions), "max_abs_stroke_fraction", max(fractions), ...
                "modal_endpoint_percent", 100 * modalCount / settings.nInitial, ...
                "q_final_min", min(operationalFinal), "q_final_max", max(operationalFinal), ...
                "motor_global_min", motorMin(motor), "motor_global_max", motorMax(motor), ...
                "motor_stroke", stroke, "grid_initial_min", positions(1), ...
                "grid_initial_max", positions(end));
        end
    end
end
cases = struct2table(vertcat(caseRows{:}));
longTable = vertcat(trajectoryRows{:});
diagnostics = struct2table(vertcat(diagnosticRows{:}));
assert(height(cases) == 2352 && height(diagnostics) == 56, "Barrido incompleto.");
end

function series = simulate(initial, motor, pwm, duration, settings)
speeds = zeros(1, 4);
speeds(motor) = pwm;
trajectory = SimController.prosthesis_simulator(initial, speeds, duration, ...
    settings.samplingPeriod, plantSource=settings.source, ...
    canonicalCurvePath=settings.curvePath, canonicalLimitsPath=settings.limitsPath, ...
    fitC2Path=settings.fitC2Path);
assert(~isempty(trajectory) && all(isfinite(trajectory), "all"), "Trayectoria invalida.");
series = trajectory(:, motor);
end

function result = trajectoryTable(caseId, gridName, motor, pwm, initial, duration, series)
n = numel(series);
result = table(repmat(caseId, n+1, 1), repmat(gridName, n+1, 1), ...
    repmat(motor, n+1, 1), repmat(pwm, n+1, 1), repmat(initial, n+1, 1), ...
    repmat(duration, n+1, 1), (0:n)', (0:n)' * duration/n, [initial; series], ...
    VariableNames=["case_id", "grid", "motor", "pwm", "q_initial", ...
    "duration", "sample_index", "time_s", "position"]);
end

function [nUnique, modalCount] = countDestinations(values, tolerance)
% Cada grupo tiene diametro <= tolerancia: se compara con su minimo, no con
% el vecino anterior (evita encadenar puntos separados mas de la tolerancia).
values = sort(values);
nUnique = 1; counts = zeros(numel(values), 1); counts(1) = 1;
groupStart = values(1);
for i = 2:numel(values)
    if values(i) - groupStart > tolerance
        nUnique = nUnique + 1;
        groupStart = values(i);
    end
    counts(nUnique) = counts(nUnique) + 1;
end
modalCount = max(counts);
end

function [regression, longTable] = checkRegression(settings)
regression = readtable(settings.oraclePath);
assert(height(regression) == 784, "El oraculo debe contener 784 casos.");
assert(nnz(regression.duration == 0.2) == 392 && nnz(regression.duration == 3.0) == 392, ...
    "Distribucion de duraciones del oraculo incorrecta.");
actual = zeros(height(regression), 4);
monotonic = false(height(regression), 1);
trajectoryRows = cell(height(regression), 1);
for i = 1:height(regression)
    initial = zeros(1, 4);
    initial(regression.motor(i)) = regression.pos(i);
    series = simulate(initial, regression.motor(i), regression.pwm(i), regression.duration(i), settings);
    actual(i, :) = [numel(series), series(1), series(end), sum(series)];
    monotonic(i) = all(sign(regression.pwm(i)) * diff([regression.pos(i); series]) >= ...
        -settings.absoluteTolerance);
    trajectoryRows{i} = trajectoryTable(i, "oracle", regression.motor(i), regression.pwm(i), ...
        regression.pos(i), regression.duration(i), series);
end
regression.actual_n_points = actual(:, 1);
regression.actual_first = actual(:, 2);
regression.actual_last = actual(:, 3);
regression.actual_sum = actual(:, 4);
regression.n_points_match = actual(:, 1) == regression.n_points;
regression.first_abs_error = abs(actual(:, 2) - regression.first);
regression.last_abs_error = abs(actual(:, 3) - regression.last);
regression.sum_abs_error = abs(actual(:, 4) - regression.sum);
regression.max_abs_error = max([regression.first_abs_error, regression.last_abs_error, ...
    regression.sum_abs_error], [], 2);
regression.regression_pass = regression.n_points_match & ...
    regression.max_abs_error < settings.absoluteTolerance;
regression.monotonic = monotonic;
longTable = vertcat(trajectoryRows{:});
end

function writeSweep(cases, longTable, outputDir, suffix)
operational = cases.duration == 0.2;
stress = cases.duration == 3.0;
writetable(cases(operational, :), fullfile(outputDir, "operational_cases" + suffix + ".csv"));
writetable(cases(stress, :), fullfile(outputDir, "stress_cases" + suffix + ".csv"));
writetable(longTable(longTable.duration == 0.2, :), ...
    fullfile(outputDir, "operational_trajectories" + suffix + ".csv"));
writetable(longTable(longTable.duration == 3.0, :), ...
    fullfile(outputDir, "stress_trajectories" + suffix + ".csv"));
end

function result = summarizeSweep(cases, diagnostics)
operational = cases.duration == 0.2;
stress = cases.duration == 3.0;
m3Closing = cases.motor == 3 & cases.pwm > 0;
outside = cases.out_of_curve_domain;
result = struct("operationalCases", nnz(operational), "stressCases", nnz(stress), ...
    "operationalMonotonicityFailures", nnz(operational & ~cases.monotonic), ...
    "stressMonotonicityFailures", nnz(stress & ~cases.monotonic), ...
    "motor3ClosingStressFailures", nnz(stress & m3Closing & ~cases.monotonic), ...
    "otherStressFailures", nnz(stress & ~m3Closing & ~cases.monotonic), ...
    "outOfDomainCases", nnz(outside), "outOfDomainHoldFailures", nnz(outside & ~cases.held_initial));
result.PWM64 = summarizeDestinations(diagnostics(diagnostics.pwm_magnitude == 64, :));
result.PWM96 = summarizeDestinations(diagnostics(diagnostics.pwm_magnitude == 96, :));
high = diagnostics(diagnostics.pwm_magnitude >= 128, :);
result.PWM_HIGH = summarizeDestinations(high);
result.PWM_HIGH.exactlyTwoEndpointGroups = table2struct(high(high.n_unique_endpoints == 2, ...
    ["motor", "direction", "pwm_magnitude", "n_unique_endpoints", "modal_endpoint_percent"]));
end

function result = summarizeDestinations(rows)
result = struct("groups", height(rows), "minimumEndpoints", min(rows.n_unique_endpoints), ...
    "medianEndpoints", median(rows.n_unique_endpoints), "maximumEndpoints", max(rows.n_unique_endpoints), ...
    "groupsWithExactlyTwoEndpoints", nnz(rows.n_unique_endpoints == 2), ...
    "minimumModalEndpointPercent", min(rows.modal_endpoint_percent), ...
    "maximumModalEndpointPercent", max(rows.modal_endpoint_percent), ...
    "minimumGroupMeanAbsStrokeFraction", min(rows.mean_abs_stroke_fraction), ...
    "maximumGroupMeanAbsStrokeFraction", max(rows.mean_abs_stroke_fraction));
end

function writeJson(path, value)
fid = fopen(path, "w", "n", "UTF-8");
assert(fid >= 0, "No se puede abrir el JSON de resultados.");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s\n", jsonencode(value, PrettyPrint=true));
end
