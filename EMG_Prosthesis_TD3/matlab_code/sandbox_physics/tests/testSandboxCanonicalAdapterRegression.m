function tests = testSandboxCanonicalAdapterRegression
% Gate G1/G3 del sandbox: el adaptador de planta no cambia la fisica canonica.
% No entrena, no toca src/@Env, no lee guante y no modifica pattern_curve.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
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
testCase.TestData.fixturePath = fullfile(here, "fixtures", "canonical_step_reference.csv");
testCase.TestData.levels = [64 96 128 160 192 224 255];
testCase.TestData.encoderLimits = [26500 11500 8500 9000];
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

function testAdapterReproducesHistoricSimulatorExactly(testCase)
% El adaptador debe ser una envoltura, no una reimplementacion.
plant = CanonicalPlantAdapter();
positions = [0 0 0 0; 5000 2000 3000 2500; 17000 6500 7500 6200; -400 -200 -300 -250];
commands = [255 255 255 255; -255 -255 -255 -255; 64 -96 128 -160; 0 224 0 -224];
for p = 1:size(positions, 1)
    for c = 1:size(commands, 1)
        expected = SimController.prosthesis_simulator(positions(p, :), ...
            commands(c, :), 0.2, 0.14, plantSource = "patternCurveCanonical");
        plant.reset(positions(p, :));
        actual = plant.step(commands(c, :));
        verifyEqual(testCase, actual, expected(end, :), ...
            "El adaptador se aparto del simulador historico.");
    end
end
end

function testMultiStepMatchesSequentialSimulatorCalls(testCase)
plant = CanonicalPlantAdapter();
q = [0 0 0 0];
plant.reset(q);
commands = [128 128 128 128; 255 -64 96 255; -192 255 -255 64; 0 0 255 -128];
for k = 1:size(commands, 1)
    trajectory = SimController.prosthesis_simulator(q, commands(k, :), 0.2, 0.14, ...
        plantSource = "patternCurveCanonical");
    q = trajectory(end, :);
    verifyEqual(testCase, plant.step(commands(k, :)), q, ...
        "La composicion de pasos del adaptador no coincide con el simulador.");
end
end

function testCrossLanguageFixtureAgrees(testCase)
% Contraste cruzado: la fixture la genero una revision independiente en
% Python leyendo pattern_curve.mat. La fuente de verdad sigue siendo MATLAB;
% esta prueba solo detecta que ambas lecturas de la curva coinciden.
T = readtable(testCase.TestData.fixturePath);
worst = 0;
for r = 1:height(T)
    motor = T.motor(r);
    q0 = zeros(1, 4);
    pwm = zeros(1, 4);
    q0(motor) = T.q0_encoder(r);
    pwm(motor) = T.pwm(r);
    trajectory = SimController.prosthesis_simulator(q0, pwm, 0.2, 0.14, ...
        plantSource = "patternCurveCanonical");
    worst = max(worst, abs(trajectory(end, motor) - T.q1_encoder(r)));
end
verifyLessThan(testCase, worst, 1e-6, ...
    sprintf("Discrepancia MATLAB/Python en la planta canonica: %g", worst));
end

function testSubstepSamplingKeepsHistoricEndpoint(testCase)
% Los sub-pasos del visor deben ser el MISMO recorrido, no otra fisica.
plant = CanonicalPlantAdapter();
positions = [0 0 0 0; 3000 1500 2500 2000; 17100 6600 7600 6250];
for p = 1:size(positions, 1)
    for level = [64 128 255]
        for direction = [1 -1]
            pwm = direction * level * ones(1, 4);
            plant.reset(positions(p, :));
            [coarse, diagnostics] = plant.step(pwm, 0.2, substepSamplingPeriod = 0.02);
            fine = diagnostics.substepTrajectory;
            verifyEqual(testCase, size(fine, 1), 10, ...
                "Se esperaban 10 sub-muestras en 0.2 s a 0.02 s.");
            verifyEqual(testCase, fine(end, :), coarse, ...
                "El sub-muestreo cambio el punto final del paso historico.");
        end
    end
end
end

function testHoldOutsideCurveIsPreserved(testCase)
% Fix HOLD de la ETAPA E0: fuera del recorrido, mantener posicion.
plant = CanonicalPlantAdapter();
beyondClosing = testCase.TestData.encoderLimits;   % mas alla del final de curva
plant.reset(beyondClosing);
after = plant.step(255 * ones(1, 4));
verifyEqual(testCase, after, beyondClosing, ...
    "Fuera del recorrido y en la direccion pedida, la planta debe mantener q.");
end

function testFixedPeriodContractIsExplicit(testCase)
plant = CanonicalPlantAdapter();
plant.reset(zeros(1, 4));
verifyError(testCase, @() plant.step(255 * ones(1, 4), 0.1), "Sandbox:FixedPeriod");
end

function testPwmRangeRejected(testCase)
plant = CanonicalPlantAdapter();
verifyError(testCase, @() plant.step([256 0 0 0]), "Sandbox:PwmRange");
end

function testPlantSourceContractEnforced(testCase)
legacyOverride = testCase.TestData.override;
legacyOverride.simPlantSource = "legacyAuto";
setConfigurablesOverride(legacyOverride);
verifyError(testCase, @() CanonicalPlantAdapter(), "Sandbox:PlantSource");
setConfigurablesOverride(testCase.TestData.override);
end

function testAdapterDoesNotChangeFrozenConfiguration(testCase)
before = configurables();
plant = CanonicalPlantAdapter();
plant.reset(zeros(1, 4));
plant.step(255 * ones(1, 4));
after = configurables();
verifyEqual(testCase, after.period, before.period);
verifyEqual(testCase, after.actionCommandLevels, before.actionCommandLevels);
verifyEqual(testCase, after.speeds, before.speeds);
verifyEqual(testCase, string(after.simPlantSource), "patternCurveCanonical");
verifyEqual(testCase, before.period, 0.2, "El periodo historico no debe cambiar.");
end

function testReachableRangeMatchesFrozenAuditValues(testCase)
% Valores congelados en la auditoria S0. Si cambian, cambio pattern_curve.mat
% y hay que rehacer la auditoria, no ajustar este test.
range = sandboxPlantReachableRange();
expectedMin = [-788.7, -437.3, -681.3, -562.2];
expectedMax = [17246.5, 6665.7, 7672.2, 6280.8];
verifyEqual(testCase, range(1, :), expectedMin, AbsTol = 0.05);
verifyEqual(testCase, range(2, :), expectedMax, AbsTol = 0.05);
fraction = 100 * range(2, :) ./ testCase.TestData.encoderLimits;
verifyLessThan(testCase, fraction, 100, ...
    "La planta canonica no alcanza los limites de encoder del firmware.");
end
