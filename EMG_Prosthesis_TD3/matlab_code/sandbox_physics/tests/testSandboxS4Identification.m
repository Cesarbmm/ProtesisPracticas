function tests = testSandboxS4Identification
% Gate S4 del sandbox: contrato del modelo reducido, unidades, limites,
% direccion, convergencia numerica y aislamiento del split.
% No entrena, no toca src/@Env, no lee el dataset de sujetos y no modifica
% pattern_curve.mat.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
testCase.TestData.matlabRoot = matlabRoot;
testCase.TestData.oldPath = path;
testCase.TestData.oldDir = cd(matlabRoot);
addpath(genpath(matlabRoot));
testCase.TestData.hadOverride = isappdata(0, "configurables_override");
if testCase.TestData.hadOverride
    testCase.TestData.previousOverride = getappdata(0, "configurables_override");
end
testCase.TestData.override = struct("run_training", false, ...
    "flagSaveTraining", false, "plotEpisodeOnTest", false, "verbose", false, ...
    "usePrerecorded", true, "simMotors", true, "observationVariant", "markov52", ...
    "simPlantSource", "patternCurveCanonical", ...
    "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(testCase.TestData.override);
testCase.TestData.conditions = s4Conditions();
testCase.TestData.range = sandboxPlantReachableRange();
end

function teardownOnce(testCase)
if testCase.TestData.hadOverride
    setConfigurablesOverride(testCase.TestData.previousOverride);
else
    clearConfigurablesOverride();
end
cd(testCase.TestData.oldDir);
path(testCase.TestData.oldPath);
end

function setup(testCase)
setConfigurablesOverride(testCase.TestData.override);
end

% =======================================================================
function testDatasetContract(testCase)
[dataset, split, floorTable] = buildS4IdentificationDataset();
verifyEqual(testCase, height(floorTable), 56, ...
    "Se esperaban 7 PWM x 2 direcciones x 4 motores.");
verifyEqual(testCase, height(dataset), 160848);
verifyTrue(testCase, all(isfinite(dataset.q_encoder)), "El dataset contiene no finitos.");
verifyEqual(testCase, sort(unique(dataset.pwm))', [64 96 128 160 192 224 255], ...
    "Los niveles PWM deben ser los canonicos, sin inventar ninguno.");
verifyEqual(testCase, sort(unique(dataset.motor))', 1:4);
verifyEqual(testCase, height(split), 268);
end

function testSplitIsDisjointNonEmptyAndFrozen(testCase)
[~, split] = buildS4IdentificationDataset();
groups = findgroups(split.motor, split.direction, split.pwm);
for g = unique(groups)'
    rows = split(groups == g, :);
    fitReps = rows.repetition(rows.role == "FIT");
    valReps = rows.repetition(rows.role == "VALIDATION");
    verifyNotEmpty(testCase, fitReps);
    verifyNotEmpty(testCase, valReps);
    verifyEmpty(testCase, intersect(fitReps, valReps), ...
        "FIT y VALIDATION deben ser disjuntos por repeticion.");
    verifyTrue(testCase, all(mod(fitReps, 2) == 1) && all(mod(valReps, 2) == 0), ...
        "El split congelado es impares = FIT, pares = VALIDATION.");
end
end

function testFitIgnoresValidationRepetitions(testCase)
% Prueba fuerte de aislamiento: se corrompen las repeticiones VALIDATION en
% memoria y los parametros ajustados no pueden cambiar.
subset = testCase.TestData.conditions(1:4);
clean = fitReducedOrderPlant(subset, tauMode = "zero");
corrupted = subset;
for i = 1:numel(corrupted)
    corrupted(i).val = corrupted(i).val * 3 + 1234;
end
polluted = fitReducedOrderPlant(corrupted, tauMode = "zero");
verifyEqual(testCase, polluted.v_inf_counts_per_s, clean.v_inf_counts_per_s, ...
    "El ajuste uso repeticiones VALIDATION.");
end

function testResponseIsInEncoderCounts(testCase)
% v_inf esta en cuentas/s: en 1 s sin saturar debe recorrer exactamente v_inf.
wide = [-1e12, 1e12];
q = reducedOrderPlantResponse(1000, 5000, 0, [0; 1], wide);
verifyEqual(testCase, q(1), 1000, AbsTol = 1e-12);
verifyEqual(testCase, q(2), 6000, AbsTol = 1e-9);
end

function testModelAIsModelBWithTauZero(testCase)
% Los modelos son anidados: B con tau -> 0 converge a A.
wide = [-1e12, 1e12];
t = (0:0.01:0.2)';
a = reducedOrderPlantResponse(0, 40000, 0, t, wide);
b = reducedOrderPlantResponse(0, 40000, 1e-11, t, wide);
verifyEqual(testCase, b, a, 'AbsTol', 1e-4);
end

function testZeroInputStability(testCase)
for tau = [0, 0.001, 0.02, 0.5]
    [q, v] = reducedOrderPlantResponse(4321, 0, tau, (0:0.05:2)', [-1000, 20000]);
    verifyEqual(testCase, q, repmat(4321, size(q)), ...
        "Sin comando la posicion no puede moverse.", ...
        'AbsTol', 1e-12);
    verifyEqual(testCase, v, zeros(size(v)), 'AbsTol', 1e-12);
end
end

function testEmpiricalLimitsAreNeverExceeded(testCase)
range = testCase.TestData.range;
t = (0:0.01:3)';
for m = 1:4
    limits = range(:, m)';
    for vInf = [1e6, -1e6]
        q = reducedOrderPlantResponse(mean(limits), vInf, 0.01, t, limits);
        verifyGreaterThanOrEqual(testCase, q, limits(1) - 1e-9);
        verifyLessThanOrEqual(testCase, q, limits(2) + 1e-9);
    end
end
end

function testMovementDirectionMatchesCommand(testCase)
range = testCase.TestData.range;
t = (0:0.005:1)';
for m = 1:4
    limits = range(:, m)';
    up = reducedOrderPlantResponse(limits(1) + 10, 20000, 0.01, t, limits);
    down = reducedOrderPlantResponse(limits(2) - 10, -20000, 0.01, t, limits);
    verifyGreaterThanOrEqual(testCase, diff(up), -1e-9, "Comando positivo debe cerrar.");
    verifyLessThanOrEqual(testCase, diff(down), 1e-9, "Comando negativo debe abrir.");
end
end

function testNumericalConvergenceAndAnalyticAgreement(testCase)
wide = [-1e12, 1e12];
worstDt = 0; worstAnalytic = 0;
for vInf = [5000, 60000, -60000]
    for tau = [0.001, 0.005, 0.020, 0.100]
        analytic = reducedOrderPlantResponse(0, vInf, tau, 0.2, wide);
        values = arrayfun(@(dt) reducedOrderPlantResponse(0, vInf, tau, 0.2, wide, ...
            method = "rk4", dt = dt), [0.002, 0.001, 0.0005]);
        worstAnalytic = max(worstAnalytic, max(abs(values - analytic)));
        worstDt = max(worstDt, abs(values(2) - values(3)));
    end
end
verifyLessThanOrEqual(testCase, worstDt, 0.5, ...
    "dt = 1 ms y dt = 0.5 ms deben converger dentro de 0.5 cuentas.");
verifyLessThanOrEqual(testCase, worstAnalytic, 0.5, ...
    "RK4 debe coincidir con la solucion analitica del modelo lineal.");
end

function testIntegrationIsDeterministic(testCase)
wide = [-1e12, 1e12];
t = (0:0.002:0.2)';
first = reducedOrderPlantResponse(0, 43210, 0.008, t, wide, method = "rk4", dt = 0.001);
other = reducedOrderPlantResponse(500, -1000, 0.05, t, wide); %#ok<NASGU>
second = reducedOrderPlantResponse(0, 43210, 0.008, t, wide, method = "rk4", dt = 0.001);
verifyTrue(testCase, isequal(first, second), ...
    "La integracion debe ser identica bit a bit entre llamadas.");
end

function testNoNanOrInfOverTheParameterGrid(testCase)
range = testCase.TestData.range;
t = (0:0.02:2)';
for m = 1:4
    limits = range(:, m)';
    for vInf = [-80000, -1000, 0, 1000, 80000]
        for tau = [0, 1e-4, 0.01, 0.5]
            [q, v] = reducedOrderPlantResponse(0, vInf, tau, t, limits);
            verifyTrue(testCase, all(isfinite(q)) && all(isfinite(v)), ...
                sprintf("No finito en motor %d, v_inf %g, tau %g.", m, vInf, tau));
        end
    end
end
end

function testMarkov52StaysAt52WithReducedModelPositions(testCase)
% La salida del modelo reducido esta en cuentas de encoder, asi que pasa por la
% normalizacion existente sin cambiar la dimension del estado.
parameters = configurables();
range = testCase.TestData.range;
q = zeros(1, 4);
for m = 1:4
    q(m) = reducedOrderPlantResponse(0, 40000, 0.005, 0.2, range(:, m)');
end
normalized = parameters.encoder2state_scale(q');
verifyEqual(testCase, size(normalized), [4 1]);
verifyTrue(testCase, all(isfinite(normalized)));
verifyLessThanOrEqual(testCase, abs(normalized), 1);

emg = reshape(sin((1:800) / 13), 100, 8);
runtime = GloveFreePolicyRuntime(emg, q, purpose = "causalEvaluation");
verifyEqual(testCase, size(runtime.state), [52 1], ...
    "markov52 debe seguir teniendo 52 componentes.");
verifyEqual(testCase, parameters.stateLength, 52);
end

function testCanonicalAdapterContractUnchanged(testCase)
% S4 no puede relajar el contrato de la planta canonica.
plant = CanonicalPlantAdapter();
plant.reset(zeros(1, 4));
verifyError(testCase, @() plant.step([256 0 0 0]), "Sandbox:PwmRange");
verifyError(testCase, @() plant.step(255 * ones(1, 4), 0.1), "Sandbox:FixedPeriod");
q = plant.step(255 * ones(1, 4));
verifyEqual(testCase, size(q), [1 4]);
verifyTrue(testCase, all(isfinite(q)));
end

function testPatternCurveIsNotModified(testCase)
info = dir(fullfile(testCase.TestData.matlabRoot, "src", "@SimController", "pattern_curve.mat"));
verifyEqual(testCase, info.bytes, 365132, ...
    "pattern_curve.mat cambio de tamano: S4 no debe tocarlo.");
end
