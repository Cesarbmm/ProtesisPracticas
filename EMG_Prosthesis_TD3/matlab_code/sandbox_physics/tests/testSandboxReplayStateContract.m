function tests = testSandboxReplayStateContract
% Gate G0/G1 del sandbox: contrato de unidades, aislamiento y prohibiciones.
% Ningun test entrena, abre sujetos sellados ni escribe fuera de sandbox_physics.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
testCase.TestData.matlabRoot = matlabRoot;
testCase.TestData.sandboxRoot = sandboxRoot;
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

function testClosingStartsAtHomePosition(testCase)
[q0, provenance] = sandboxInitialPosition(1);
verifyEqual(testCase, q0, zeros(1, 4));
verifyEqual(testCase, provenance.episodeType, "Closing");
verifyFalse(testCase, provenance.gloveUsed);
end

function testOpeningStartsAtTheFrozenPartiallyClosedPose(testCase)
% Valor congelado: un unico periodo de 0.2 s a PWM 255 desde cero, porque
% Timing.toc(10000) avanza el contador en 1 y SimController avanza por
% contador. Coincide con state_41..44 de e2a_results/execution_traces.csv.
expectedEncoder = [11176.666666666666, 6665.166666666667, ...
    7509.666666666667, 6280.833333333333];
expectedNormalized = [0.4217610062893081, 0.5795797101449276, ...
    0.8834901960784314, 0.6978703703703704];
[q0, provenance] = sandboxInitialPosition(2);
verifyEqual(testCase, q0, expectedEncoder, AbsTol = 1e-9);
verifyEqual(testCase, provenance.q0Normalized, expectedNormalized, AbsTol = 1e-12);
verifyEqual(testCase, provenance.episodeType, "Opening");
verifyLessThan(testCase, max(provenance.q0Normalized), 1, ...
    "La mano de partida en apertura esta parcialmente cerrada, no cerrada del todo.");
end

function testInitialPositionNeverBuildsAGlove(testCase)
profile clear;
profile on;
cleanup = onCleanup(@() profile("off"));
sandboxInitialPosition(2);
profile off;
info = profile("info");
executed = string({info.FunctionTable.FunctionName});
forbidden = contains(executed, "RecordedGlove") | contains(executed, "FakeGlove") | ...
    startsWith(executed, "Glove.") | startsWith(executed, "Glove>") | ...
    contains(executed, "getDataset");
verifyFalse(testCase, any(forbidden), ...
    "La posicion inicial no puede construir ni leer un guante.");
clear cleanup;
end

function testSealedSubjectsRejectedBeforeAnyIO(testCase)
calls = 0;
for subject = ["MATEO", "SANDRA"]
    verifyError(testCase, @() loadE2ADevelopmentEpisode(subject, 1, 1, ...
        variableLoader = @spy), "ProtesisPracticas:E2ADevelopmentOnly");
end
verifyEqual(testCase, calls, 0, "Un sujeto sellado llego al loader.");
    function loaded = spy(varargin) %#ok<INUSD>
        calls = calls + 1;
        loaded = struct();
        error("SandboxTest:UnexpectedIO", "El sujeto sellado llego al loader.");
    end
end

function testRuntimeStillForbidsTraining(testCase)
% El sandbox hereda el guard de E2A; que exista una fase nueva no lo relaja.
emg = reshape(sin((1:800) / 13), 100, 8);
runtime = GloveFreePolicyRuntime(emg, zeros(1, 4), purpose = "causalEvaluation");
verifyError(testCase, @() train(runtime), "E2A:TrainingForbidden");
verifyError(testCase, @() GloveFreePolicyRuntime(emg, zeros(1, 4), purpose = "training"), ...
    "E2A:TrainingForbidden");
end

function testStateContractIsMarkov52(testCase)
emg = reshape(sin((1:800) / 13), 100, 8);
runtime = GloveFreePolicyRuntime(emg, zeros(1, 4), purpose = "causalEvaluation");
verifyEqual(testCase, size(runtime.state), [52 1]);
parameters = configurables();
verifyEqual(testCase, parameters.stateLength, 52);
verifyEqual(testCase, string(parameters.observationVariant), "markov52");
verifyEqual(testCase, parameters.period, 0.2);
verifyEqual(testCase, parameters.actionCommandLevels, [0 64 96 128 160 192 224 255]);
verifyEqual(testCase, parameters.speeds, 255 * ones(1, 4));
end

function testEncoderNormalizationDividesByTheFirmwareLimits(testCase)
% Unidades: el estado normaliza con los limites del firmware, no con el
% recorrido de la planta. Mezclarlos es lo que el plan prohibe.
parameters = configurables();
q = [26500 11500 8500 9000];
verifyEqual(testCase, parameters.encoder2state_scale(q')', ones(1, 4), AbsTol = 1e-12);
verifyEqual(testCase, testCase.TestData.encoderLimits, q);
end

function testViewerDoesNotAlterTheReplayTrace(testCase)
% Dibujar no puede cambiar la trayectoria: se compara un rollout de planta
% con y sin visor intercalado, paso a paso.
commands = [128 -64 96 -160; 255 255 255 255; -224 192 -128 64; 0 255 -255 0];
plain = CanonicalPlantAdapter();
plain.reset(zeros(1, 4));
withViewer = CanonicalPlantAdapter();
withViewer.reset(zeros(1, 4));
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
for k = 1:size(commands, 1)
    expected = plain.step(commands(k, :));
    actual = withViewer.step(commands(k, :));
    viewer.update(actual);
    verifyEqual(testCase, actual, expected, ...
        "El visor altero la evolucion de la planta.");
end
end

function testHistoricFilesAreNotModifiedByTheSandbox(testCase)
% Aislamiento verificado sobre el disco, no sobre intenciones: se toman
% tamano y fecha de los archivos historicos criticos antes y despues de
% ejercitar el sandbox, y deben coincidir.
protectedFiles = [ ...
    fullfile("src", "@Env", "step.m"), ...
    fullfile("src", "@Env", "reset.m"), ...
    fullfile("src", "@Env", "calculateState.m"), ...
    fullfile("src", "@Env", "remapActionForActuator.m"), ...
    fullfile("src", "@Env", "checkEndEpisode.m"), ...
    fullfile("src", "@SimController", "SimController.m"), ...
    fullfile("src", "@SimController", "prosthesis_simulator.m"), ...
    fullfile("src", "@SimController", "pattern_curve.mat"), ...
    fullfile("src", "@SimController", "plant_limits_canonical.csv"), ...
    fullfile("src", "reward_functions", "trackingMseActionRateReward.m"), ...
    fullfile("src", "runtime", "GloveFreePolicyRuntime.m"), ...
    fullfile("config", "configurables.m"), ...
    fullfile("config", "definitions.m")];

before = fileStamps(testCase.TestData.matlabRoot, protectedFiles);

sandboxInitialPosition(1);
sandboxInitialPosition(2);
plant = CanonicalPlantAdapter();
plant.reset(zeros(1, 4));
plant.step(255 * ones(1, 4), 0.2, substepSamplingPeriod = 0.02);
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
viewer.update(plant.q);
sandboxPlantReachableRange();

after = fileStamps(testCase.TestData.matlabRoot, protectedFiles);
verifyEqual(testCase, after, before, ...
    "El sandbox modifico un archivo de la ruta historica.");
end

function stamps = fileStamps(root, relativePaths)
stamps = table(strings(numel(relativePaths), 1), zeros(numel(relativePaths), 1), ...
    zeros(numel(relativePaths), 1), VariableNames = ["file", "bytes", "datenum"]);
for k = 1:numel(relativePaths)
    info = dir(fullfile(root, relativePaths(k)));
    stamps.file(k) = relativePaths(k);
    if isempty(info)
        stamps.bytes(k) = -1;
        stamps.datenum(k) = -1;
    else
        stamps.bytes(k) = info(1).bytes;
        stamps.datenum(k) = info(1).datenum;
    end
end
end
