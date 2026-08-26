function tests = testConventionalPlantDiagnostic
%testConventionalPlantDiagnostic deterministic ETAPA 5 simulation tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
originalDir = pwd;
cd(matlabRoot);
cleanup = onCleanup(@() cd(originalDir));
[dataset, calibration, expected] = buildFixture(11);
profile = buildNoGloveStage5Override(calibration, expected, 11);
setConfigurablesOverride(profile);
configs = configurables();
results = evaluateNoGloveStage5Plant(configs);
testCase.TestData.matlabRoot = matlabRoot;
testCase.TestData.dataset = dataset;
testCase.TestData.calibration = calibration;
testCase.TestData.expected = expected;
testCase.TestData.profile = profile;
testCase.TestData.configs = configs;
testCase.TestData.results = results;
clear cleanup;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testBaselineQuantizerContract(testCase)
configs = testCase.TestData.configs;
maxPwm = max(abs(configs.speeds));
[effective, pwm] = quantizeBaselineAction( ...
    [0; 0.049; 0.25; 1], maxPwm, ...
    configs.actionCommandActivationThreshold, ...
    configs.actionCommandLevels);
testCase.verifyEqual(pwm, [0; 0; 64; 255]);
testCase.verifyEqual(effective, pwm ./ maxPwm, "AbsTol", 1e-15);

[effective, pwm] = quantizeBaselineAction( ...
    [-0.5; 0.5; -2; 2], maxPwm, ...
    configs.actionCommandActivationThreshold, ...
    configs.actionCommandLevels);
testCase.verifyEqual(pwm, [-128; 128; -255; 255]);
testCase.verifyEqual(effective, pwm ./ maxPwm, "AbsTol", 1e-15);
testCase.verifyError(@() quantizeBaselineAction( ...
    [0; 0; NaN; 0], maxPwm, 0.05, [0, 64]), ...
    "quantizeBaselineAction:InvalidAction");
end

function testConventionalControllerExactCases(testCase)
configs = testCase.TestData.configs;
actuator = struct( ...
    "maxPwm", max(abs(configs.speeds)), ...
    "activationThreshold", configs.actionCommandActivationThreshold, ...
    "commandLevels", configs.actionCommandLevels);
controller = configs.conventionalController;
[raw, effective, pwm, info] = quantizedIntentPdController( ...
    zeros(4, 1), zeros(4, 1), zeros(4, 1), zeros(4, 1), ...
    controller, actuator);
testCase.verifyEqual(raw, zeros(4, 1));
testCase.verifyEqual(effective, zeros(4, 1));
testCase.verifyEqual(pwm, zeros(4, 1));
testCase.verifyTrue(all(info.holdMask));

qRef = [0.2; -0.2; 0.005; 0];
[raw, effective, pwm] = quantizedIntentPdController( ...
    qRef, zeros(4, 1), zeros(4, 1), zeros(4, 1), ...
    controller, actuator);
cap = 64 / 255;
testCase.verifyEqual(raw, [cap; -cap; 0; 0], "AbsTol", 1e-15);
testCase.verifyEqual(effective, [cap; -cap; 0; 0], "AbsTol", 1e-15);
testCase.verifyEqual(pwm, [64; -64; 0; 0]);

invalid = controller;
invalid.kd = ones(4, 1);
testCase.verifyError(@() quantizedIntentPdController( ...
    zeros(4, 1), zeros(4, 1), zeros(4, 1), zeros(4, 1), ...
    invalid, actuator), ...
    "quantizedIntentPdController:InvalidController");
end

function testStage5ProfilePreservesExperimentInvariants(testCase)
stage4 = buildNoGloveStage4Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
stage5 = testCase.TestData.profile;
invariants = [ ...
    "referenceSource", "observationVariant", "rewardType", ...
    "actionInterfaceVariant", "quantizeCommandsForSimulation", ...
    "simMotors", "connect_glove", "run_training", ...
    "newTraining", "usePrerecorded"];
for idx = 1:numel(invariants)
    fieldName = invariants(idx);
    testCase.verifyEqual(stage5.(fieldName), stage4.(fieldName));
end
testCase.verifyEqual(stage5.conventionalController.type, "P");
testCase.verifyEqual(stage5.conventionalController.kd, zeros(4, 1));
testCase.verifyEqual(stage5.conventionalController.maxAction, ...
    (64 / 255) * ones(4, 1), "AbsTol", 1e-15);
testCase.verifyEqual(stage5.plantDiagnostic.initialModes, ...
    ["home", "intermediate"]);
end

function testOpenLoopPlantCoverageAndConversion(testCase)
results = testCase.TestData.results;
trials = results.openLoopTrials;
testCase.verifyEqual(height(trials), 112);
testCase.verifyEqual(height(results.plantByCondition), 16);
testCase.verifyEqual(height(results.plantByMotor), 4);
testCase.verifyEqual(unique(trials.initialMode), ...
    ["home"; "intermediate"]);
testCase.verifyEqual(unique(trials.motor), (1:4)');
testCase.verifyEqual(unique(trials.direction), [-1; 1]);
testCase.verifyEqual(unique(trials.requestedPwmMagnitude), ...
    [64; 96; 128; 160; 192; 224; 255]);
testCase.verifyTrue(all(isfinite(trials.finalEncoderDelta)));
testCase.verifyTrue(all(isfinite(trials.maxNormalizedSpeedPerSec)));
testCase.verifyLessThanOrEqual(max( ...
    trials.encoder2FlexImplementationMaxAbs), 1e-12);
testCase.verifyLessThanOrEqual(max( ...
    trials.crossMotorMaxNormalizedDelta), 1e-12);
testCase.verifyTrue(any(~trials.directionConsistent));
testCase.verifyTrue(any(trials.positionViolationFraction > 0));
testCase.verifyEqual(numel(results.openLoopTraces), height(trials));
end

function testClosedLoopStepRampCoverageAndBaseline(testCase)
results = testCase.TestData.results;
scenarios = results.baselineScenarios;
testCase.verifyEqual(height(scenarios), 32);
testCase.verifyEqual(height(results.baselineByMotor), 4);
testCase.verifyEqual(unique(scenarios.initialMode), ...
    ["home"; "intermediate"]);
testCase.verifyEqual(unique(scenarios.profile), ["ramp"; "step"]);
testCase.verifyEqual(unique(scenarios.motor), (1:4)');
testCase.verifyEqual(unique(scenarios.direction), [-1; 1]);
testCase.verifyEqual(sum(scenarios.isDegenerateAtPositionLimit), 8);
testCase.verifyTrue(all(isfinite(scenarios.trackingMse)));
testCase.verifyTrue(all(isfinite(scenarios.trackingMae)));
testCase.verifyEqual(scenarios.saturationFraction, zeros(32, 1));
testCase.verifyLessThanOrEqual(max( ...
    scenarios.crossMotorMaxNormalizedDelta), 1e-12);
testCase.verifyLessThanOrEqual(max( ...
    scenarios.encoder2FlexImplementationMaxAbs), 1e-12);
testCase.verifyEqual(numel(results.baselineTraces), height(scenarios));
testCase.verifyFalse(results.hardwareUsed);
testCase.verifyTrue(results.simulatorUsed);
testCase.verifyFalse(results.reinforcementLearningUsed);

for traceIdx = 1:numel(results.baselineTraces)
    trace = results.baselineTraces{traceIdx};
    testCase.verifyLessThanOrEqual(max(abs(trace.appliedPwm), [], "all"), 64);
    testCase.verifyTrue(all(isfinite(trace.normalizedEncoder), "all"));
    testCase.verifyTrue(all(isfinite(trace.qReference), "all"));
    testCase.verifyTrue(all(isfinite(trace.effectiveAction), "all"));
end
end

function [dataset, calibration, expected] = buildFixture(seed)
config = buildNoGloveStage2OfflineConfig(seed);
dataset = buildSyntheticEmgIntentDataset(config);
calibration = calibrateEmgIntent(dataset.restCapture, ...
    dataset.instructionTrials, config.calibrationOptions);
options = config.calibrationOptions;
expected = struct( ...
    "userId", dataset.restCapture.userId, ...
    "sessionId", dataset.restCapture.sessionId, ...
    "channelOrder", dataset.restCapture.channelOrder, ...
    "sampleRateHz", dataset.restCapture.sampleRateHz, ...
    "windowLengthSamples", dataset.windowLengthSamples, ...
    "hopLengthSamples", dataset.hopLengthSamples, ...
    "dataProvenance", dataset.restCapture.dataProvenance, ...
    "motorOrder", options.motorOrder, ...
    "units", struct( ...
        "rawEmg", dataset.restCapture.rawEmgUnits, ...
        "envelope", options.envelopeUnits, ...
        "position", options.positionUnits, ...
        "velocity", options.velocityUnits, ...
        "acceleration", options.accelerationUnits), ...
    "synergyMatrixVersion", options.synergyMatrixVersion, ...
    "instructionProtocolVersion", options.instructionProtocolVersion, ...
    "sourceDomain", "rawEmgSameSession", ...
    "calibrationContentSha256", calibration.contentSha256);
end
