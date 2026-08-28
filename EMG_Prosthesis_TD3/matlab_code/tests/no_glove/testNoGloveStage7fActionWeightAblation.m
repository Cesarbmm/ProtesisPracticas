function tests = testNoGloveStage7fActionWeightAblation
%testNoGloveStage7fActionWeightAblation deterministic ETAPA 7F tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
testCase.TestData.tempDir = string(tempname);
mkdir(testCase.TestData.tempDir);
end

function teardownOnce(testCase)
clearConfigurablesOverride();
if isfolder(testCase.TestData.tempDir) && ...
        startsWith(testCase.TestData.tempDir, string(tempdir))
    rmdir(testCase.TestData.tempDir, "s");
end
end

function testSupportedAblation(testCase)
[control, candidate] = makeVariants();
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyTrue(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, ...
    "actionRegularizationSupported");
testCase.verifyEqual(analysis.comparison.actionL2Reduction, 0.125, ...
    "AbsTol", 1e-12);
testCase.verifyFalse(analysis.rootCauseIdentified);
testCase.verifyFalse(analysis.pilotAuthorized);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testTrackingRegressionClassification(testCase)
[control, candidate] = makeVariants();
candidate.acceptance.trackingMse = 0.106;
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyFalse(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, "trackingRegression");
end

function testNoMaterialEffortReductionClassification(testCase)
[control, candidate] = makeVariants();
candidate.acceptance.actionL2 = 0.37;
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyFalse(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, ...
    "noMaterialEffortReduction");
end

function testRestGateFailureClassification(testCase)
[control, candidate] = makeVariants();
candidate.rest.windowAnyCommandFraction = 1;
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyFalse(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, ...
    "effortReducedButRestGateFailed");
end

function testFunctionalFailureClassification(testCase)
[control, candidate] = makeVariants();
candidate.acceptance.motor2FunctionalFlagCount = 1;
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyFalse(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, "functionalGateFailed");
end

function testDynamicRegularityFailureClassification(testCase)
[control, candidate] = makeVariants();
candidate.acceptance.positionSafetyInterventionCount = 21;
analysis = analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate);
testCase.verifyFalse(analysis.gatePassed);
testCase.verifyEqual(analysis.classification, ...
    "dynamicRegularityGateFailed");
end

function testVariantContractFailsClosed(testCase)
[control, candidate] = makeVariants();
candidate.actionWeight = 0.04;
testCase.verifyError(@() analyzeNoGloveStage7fActionWeightAblation( ...
    control, candidate), ...
    "analyzeNoGloveStage7fActionWeightAblation:InvalidVariant");
end

function testIncompleteResumeFailsClosed(testCase)
testFile = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testFile)));
addpath(fullfile(matlabRoot, "workflows", "published"));
testCase.verifyError(@() ...
    run_no_glove_stage7f_action_weight_ablation(struct( ...
    "completedControlRunRoot", testCase.TestData.tempDir)), ...
    "run_no_glove_stage7f_action_weight_ablation:IncompleteResume");
end

function testRewardProfilesDifferOnlyByActionWeight(testCase)
corpus = buildNoGloveStage6SyntheticCorpus(11);
datasetPath = fullfile(testCase.TestData.tempDir, "training.mat");
emgs = corpus.trainingEmgs;
metadata = corpus.trainingMetadata;
save(datasetPath, "emgs", "metadata");
control = buildNoGloveStage6Override(corpus.calibration, ...
    corpus.expectedContext, 11, 200, 50, datasetPath, ...
    testCase.TestData.tempDir);
candidate = control;
candidate.intentRewardActionWeight = 0.05;
controlWithoutWeight = rmfield(control, "intentRewardActionWeight");
candidateWithoutWeight = rmfield(candidate, "intentRewardActionWeight");
testCase.verifyEqual(controlWithoutWeight, candidateWithoutWeight);
testCase.verifyEqual(control.intentRewardActionWeight, 0.01);
testCase.verifyEqual(candidate.intentRewardActionWeight, 0.05);
testCase.verifyTrue(control.simulationPositionSafety.enabled == false);
end

function testRestCommandSummary(testCase)
episodeDir = fullfile(testCase.TestData.tempDir, "rest_summary");
mkdir(episodeDir);
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
stateLog = zeros(3, layout.totalLength);
stateLog(:, layout.referencePosition) = repmat([0.1 0.2 0.3 0.4], 3, 1);
actionPwmLog = [0 64 0 0; 0 0 0 0; -64 0 0 0];
actionSatLog = actionPwmLog/255;
save(fullfile(episodeDir, "episode00001.mat"), ...
    "stateLog", "actionPwmLog", "actionSatLog");
summary = summarizeNoGloveStage7fRestCommands(episodeDir);
testCase.verifyEqual(summary.episodeCount, 1);
testCase.verifyEqual(summary.windowCount, 3);
testCase.verifyEqual(summary.commandActiveFraction, 2/12, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(summary.windowAnyCommandFraction, 2/3, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(summary.meanAbsPwm, 128/12, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(summary.saturationFraction, 0);
end

function [control, candidate] = makeVariants()
control = makeVariant("control", 0.01);
candidate = makeVariant("candidate", 0.05);
candidate.acceptance.trackingMse = 0.105;
candidate.acceptance.trackingMae = 0.21;
candidate.acceptance.actionL2 = 0.35;
candidate.acceptance.deltaActionL2 = 0.19;
candidate.acceptance.saturationFraction = 0.09;
candidate.rest.commandActiveFraction = 0.002;
candidate.rest.windowAnyCommandFraction = 0.005;
candidate.rest.meanAbsPwm = 20;
candidate.rest.saturationFraction = 0;
candidate.rest.commandActiveFractionByMotor = 0.002*ones(1, 4);
candidate.rest.meanAbsPwmByMotor = 20*ones(1, 4);
candidate.rest.saturationFractionByMotor = zeros(1, 4);
candidate.decodedRestFalseActivationFraction = 0;
candidate.training.positionSafetyInterventionCount = 90;
candidate.acceptance.positionSafetyInterventionCount = 19;
end

function value = makeVariant(label, weight)
training = struct("allFinite", true, ...
    "positionViolationEpisodeCount", 0, ...
    "positionSafetyInterventionCount", 100);
acceptance = struct("allFinite", true, ...
    "positionViolationEpisodeCount", 0, ...
    "positionSafetyInterventionCount", 20, ...
    "trackingMse", 0.1, "trackingMae", 0.2, ...
    "actionL2", 0.4, "deltaActionL2", 0.2, ...
    "saturationFraction", 0.1, ...
    "motor2FunctionalFlagCount", 0, ...
    "otherMotorFunctionalFlagCount", 0);
rest = struct("allFinite", true, ...
    "positionViolationEpisodeCount", 0, ...
    "positionSafetyInterventionCount", 0, ...
    "commandActiveFraction", 1, ...
    "windowAnyCommandFraction", 1, "meanAbsPwm", 100, ...
    "saturationFraction", 0.1, ...
    "commandActiveFractionByMotor", ones(1, 4), ...
    "meanAbsPwmByMotor", 100*ones(1, 4), ...
    "saturationFractionByMotor", 0.1*ones(1, 4));
value = struct("label", label, "actionWeight", weight, ...
    "training", training, "acceptance", acceptance, "rest", rest, ...
    "decodedRestFalseActivationFraction", 0, ...
    "checkpointSha256", upper(repmat('a', 1, 64)));
end
