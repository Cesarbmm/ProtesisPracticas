function tests = testNoGloveStage7gActionMargins
%testNoGloveStage7gActionMargins deterministic ETAPA 7G tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
testCase.TestData.actuator = struct("maxPwm", 255, ...
    "activationThreshold", 0.05, ...
    "commandLevels", [0 64 96 128 160 192 224 255]);
testCase.TestData.tempDir = string(tempname);
mkdir(testCase.TestData.tempDir);
end

function teardownOnce(testCase)
if isfolder(testCase.TestData.tempDir) && ...
        startsWith(testCase.TestData.tempDir, string(tempdir))
    rmdir(testCase.TestData.tempDir, "s");
end
end

function testSeparableThresholdExists(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.10, ...
    0.80*ones(1, 4), false);
analysis = analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator);
testCase.verifyEqual(analysis.classification, ...
    "offlineThresholdSeparationExists");
candidate = analysis.thresholdDecision( ...
    analysis.thresholdDecision.variant == "candidate", :);
testCase.verifyTrue(candidate.feasibleThresholdExists);
testCase.verifyGreaterThan(candidate.minimumFeasibleThreshold, 0.10);
testCase.verifyEqual(candidate.movementCommandLossAtRestThreshold, 0);
testCase.verifyFalse(analysis.thresholdAppliedToEnvironment);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.runTraining);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testNonseparableThresholdClassification(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.80, ...
    0.70*ones(1, 4), false);
analysis = analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator);
testCase.verifyEqual(analysis.classification, ...
    "restMovementNotSeparableBySingleThreshold");
candidate = analysis.thresholdDecision( ...
    analysis.thresholdDecision.variant == "candidate", :);
testCase.verifyFalse(candidate.feasibleThresholdExists);
testCase.verifyTrue(candidate.restOnlyThresholdExists);
testCase.verifyEqual(candidate.movementCommandLossAtRestThreshold, 1);
end

function testMotor2ConstraintIsIndependent(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.60, ...
    [0.90 0.55 0.90 0.90], true);
analysis = analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator);
candidate = analysis.thresholdDecision( ...
    analysis.thresholdDecision.variant == "candidate", :);
testCase.verifyFalse(candidate.feasibleThresholdExists);
testCase.verifyLessThanOrEqual( ...
    candidate.movementCommandLossAtRestThreshold, 0.05);
testCase.verifyEqual(candidate.motor2CommandLossAtRestThreshold, 1);
end

function testCurrentThresholdUsesGreaterThanOrEqual(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.05, ...
    0.80*ones(1, 4), false);
analysis = analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator);
candidate = analysis.thresholdDecision( ...
    analysis.thresholdDecision.variant == "candidate", :);
testCase.verifyEqual(candidate.currentRestWindowActiveFraction, 1);
testCase.verifyTrue(analysis.quantizationAudit.exactlyReproduced);
end

function testQuantizationMismatchFailsClosed(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.10, ...
    0.80*ones(1, 4), false);
components.pwm(1) = components.pwm(1)+1;
testCase.verifyError(@() analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator), ...
    "analyzeNoGloveStage7gActionMargins:QuantizationMismatch");
end

function testMissingVariantFailsClosed(testCase)
components = makeCorpus(testCase.TestData.actuator, 0.10, ...
    0.80*ones(1, 4), false);
components = components(components.variant == "candidate", :);
testCase.verifyError(@() analyzeNoGloveStage7gActionMargins( ...
    components, testCase.TestData.actuator), ...
    "analyzeNoGloveStage7gActionMargins:InvalidCorpus");
end

function testLoaderBuildsCausalPhases(testCase)
acceptance = fullfile(testCase.TestData.tempDir, "acceptance");
rest = fullfile(testCase.TestData.tempDir, "rest");
mkdir(acceptance);
mkdir(rest);
writeEpisode(fullfile(acceptance, "episode00001.mat"), ...
    [0; 0.1; 0; 0], testCase.TestData.actuator);
writeEpisode(fullfile(rest, "episode00001.mat"), ...
    [0; 0], testCase.TestData.actuator);
[components, audit] = loadNoGloveStage7gActionCorpus( ...
    "control", acceptance, rest);
testCase.verifyEqual(height(audit), 2);
acceptanceRows = components.source == "acceptance" & ...
    components.motor == 1;
testCase.verifyEqual(components.phase(acceptanceRows), ...
    ["preActivation"; "movement"; ...
    "postActivationHold"; "postActivationHold"]);
testCase.verifyTrue(all(components.phase( ...
    components.source == "steadyRest") == "steadyRest"));
end

function testLauncherRejectsUnknownOption(testCase)
testFile = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testFile)));
addpath(fullfile(matlabRoot, "workflows", "published"));
testCase.verifyError(@() ...
    run_no_glove_stage7g_action_margin_analysis(struct("forbidden", 1)), ...
    "run_no_glove_stage7g_action_margin_analysis:UnknownOption");
end

function components = makeCorpus(actuator, restMagnitude, ...
        movementMagnitude, sparseMotor2)
parts = cell(0, 1);
window = 0;
for variant = ["control", "candidate"]
    for idx = 1:10
        window = window+1;
        parts{end+1, 1} = makeWindow(variant, "steadyRest", idx, ...
            window, repmat(restMagnitude, 1, 4), ...
            repmat("steadyRest", 1, 4), zeros(1, 4), actuator); %#ok<AGROW>
    end
    window = window+1;
    parts{end+1, 1} = makeWindow(variant, "acceptance", 1, ...
        window, 0.20*ones(1, 4), repmat("preActivation", 1, 4), ...
        zeros(1, 4), actuator); %#ok<AGROW>
    for idx = 1:10
        window = window+1;
        phase = repmat("movement", 1, 4);
        velocity = 0.1*ones(1, 4);
        if sparseMotor2 && idx > 1
            phase(2) = "inactiveOther";
            velocity(2) = 0;
        end
        parts{end+1, 1} = makeWindow(variant, "acceptance", 1, ...
            window, movementMagnitude, phase, velocity, actuator); %#ok<AGROW>
    end
    window = window+1;
    parts{end+1, 1} = makeWindow(variant, "acceptance", 1, ...
        window, 0.20*ones(1, 4), ...
        repmat("postActivationHold", 1, 4), zeros(1, 4), actuator); %#ok<AGROW>
end
components = vertcat(parts{:});
end

function value = makeWindow(variant, source, episode, window, raw, ...
        phase, velocity, actuator)
[effective, pwm] = quantizeBaselineAction(raw, actuator.maxPwm, ...
    actuator.activationThreshold, actuator.commandLevels);
value = table(repmat(variant, 4, 1), repmat(source, 4, 1), ...
    repmat(episode, 4, 1), repmat(window, 4, 1), (1:4)', ...
    repmat(window, 4, 1), phase(:), raw(:), effective(:), pwm(:), ...
    velocity(:), 'VariableNames', ["variant", "source", "episode", ...
    "step", "motor", "windowIndex", "phase", "rawAction", ...
    "effectiveAction", "pwm", "referenceVelocity"]);
end

function writeEpisode(path, velocityProfile, actuator)
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
stepCount = numel(velocityProfile);
stateLog = zeros(stepCount, layout.totalLength);
stateLog(:, layout.referencePosition) = ...
    repmat([0.1 0.2 0.3 0.4], stepCount, 1);
stateLog(:, layout.referenceVelocity) = ...
    repmat(velocityProfile, 1, 4);
actionLog = 0.2*ones(stepCount, 4);
actionSatLog = zeros(stepCount, 4);
actionPwmLog = zeros(stepCount, 4);
for idx = 1:stepCount
    [effective, pwm] = quantizeBaselineAction(actionLog(idx, :), ...
        actuator.maxPwm, actuator.activationThreshold, ...
        actuator.commandLevels);
    actionSatLog(idx, :) = effective;
    actionPwmLog(idx, :) = pwm;
end
referenceSource = "emgIntent";
observationVariant = "intentMarkov60";
stateLength = 60;
save(path, "stateLog", "actionLog", "actionSatLog", "actionPwmLog", ...
    "referenceSource", "observationVariant", "stateLength");
end
