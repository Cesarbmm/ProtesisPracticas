function tests = testNoGloveStage6Training
%testNoGloveStage6Training deterministic ETAPA 6 protocol tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
clearConfigurablesOverride();
testCase.TestData.corpus = buildNoGloveStage6SyntheticCorpus(11);
testCase.TestData.tempDir = string(tempname);
mkdir(testCase.TestData.tempDir);
emgs = testCase.TestData.corpus.trainingEmgs;
metadata = testCase.TestData.corpus.trainingMetadata;
testCase.TestData.datasetPath = fullfile( ...
    testCase.TestData.tempDir, "stage6_training_emg_only.mat");
save(testCase.TestData.datasetPath, "emgs", "metadata");
end

function teardownOnce(testCase)
clearConfigurablesOverride();
tempDir = testCase.TestData.tempDir;
if isfolder(tempDir) && startsWith(tempDir, string(tempdir))
    rmdir(tempDir, "s");
end
end

function setup(~)
clearConfigurablesOverride();
end

function teardown(~)
clearConfigurablesOverride();
end

function testSyntheticCorpusUsesOneDeclaredSession(testCase)
corpus = testCase.TestData.corpus;
testCase.verifyEqual(size(corpus.trainingEmgs), [6, 2]);
testCase.verifyEqual(size(corpus.evaluationEmgs), [6, 2]);
testCase.verifyEqual(size(corpus.restEmgs), [3, 2]);
testCase.verifyEqual(corpus.dataProvenance, "synthetic");
testCase.verifyEqual(corpus.trainingMetadata.sessionId, ...
    corpus.calibration.sessionId);
testCase.verifyEqual(corpus.evaluationMetadata.sessionId, ...
    corpus.calibration.sessionId);
testCase.verifyEqual(corpus.restMetadata.sessionId, ...
    corpus.calibration.sessionId);
testCase.verifyEqual(corpus.restFalseActivationFraction, 0);
testCase.verifyGreaterThan(corpus.restWindowCount, 0);
testCase.verifyFalse(corpus.agent7250Used);
testCase.verifyFalse(corpus.hardwareUsed);
end

function testTrainingProfileIsFreshFeedforwardIntent60(testCase)
corpus = testCase.TestData.corpus;
profile = buildNoGloveStage6Override( ...
    corpus.calibration, corpus.expectedContext, 11, 200, 50, ...
    testCase.TestData.datasetPath, testCase.TestData.tempDir);
setConfigurablesOverride(profile);
configs = configurables();
observationInfo = Env.defineObservationInfo();

testCase.verifyTrue(configs.run_training);
testCase.verifyTrue(configs.newTraining);
testCase.verifyEqual(string(configs.agentFile), "");
testCase.verifyEqual(string(configs.agent_id), ...
    "td3_no_glove_intent");
testCase.verifyEqual(configs.referenceSource, "emgIntent");
testCase.verifyEqual(configs.observationVariant, "intentMarkov60");
testCase.verifyEqual(configs.stateLength, 60);
testCase.verifyEqual(observationInfo.Dimension, [60, 1]);
testCase.verifyEqual(configs.rewardType, ...
    "trackingIntentActionRateReward");
testCase.verifyEqual(configs.actionInterfaceVariant, ...
    "baselineQuantized");
testCase.verifyFalse(configs.td3.useRecurrent);
testCase.verifyTrue(configs.td3.resetExperienceBufferBeforeTraining);
testCase.verifyFalse(configs.td3Residual.enabled);
testCase.verifyEqual(string(configs.td3Residual.baseCheckpointPath), "");
testCase.verifyTrue(configs.simMotors);
testCase.verifyFalse(configs.connect_glove);
end

function testFreshAgentFactoryBuildsSixtyInputTd3(testCase)
corpus = testCase.TestData.corpus;
profile = buildNoGloveStage6Override( ...
    corpus.calibration, corpus.expectedContext, 11, 200, 50, ...
    testCase.TestData.datasetPath, testCase.TestData.tempDir);
setConfigurablesOverride(profile);
observationInfo = Env.defineObservationInfo();
actionInfo = Env.defineActionInfo();
agent = agentNoGloveIntentTd3(observationInfo, actionInfo);

testCase.verifyClass(agent, "rl.agent.rlTD3Agent");
testCase.verifyEqual(observationInfo.Dimension, [60, 1]);
testCase.verifyEqual(actionInfo.Dimension, [4, 1]);
end

function testFactoryRejectsCheckpointResume(testCase)
corpus = testCase.TestData.corpus;
profile = buildNoGloveStage6Override( ...
    corpus.calibration, corpus.expectedContext, 11, 200, 50, ...
    testCase.TestData.datasetPath, testCase.TestData.tempDir);
profile.newTraining = false;
profile.agentFile = "forbidden_checkpoint.mat";
setConfigurablesOverride(profile);
observationInfo = Env.defineObservationInfo();
actionInfo = Env.defineActionInfo();
testCase.verifyError(@() agentNoGloveIntentTd3( ...
    observationInfo, actionInfo), ...
    "agentNoGloveIntentTd3:HistoricalCheckpointForbidden");
end

function testGatePassAndMotor2FailureAreExplicit(testCase)
acceptance = nominalAnalysis();
rest = nominalAnalysis();
rest.saturationFraction = 0;
gate = classifyNoGloveStage6Gate(acceptance, rest, 0);
testCase.verifyTrue(gate.passed);
testCase.verifyEqual(gate.thresholds.saturationFractionMax, 0.196043);
testCase.verifyEqual(gate.thresholds.deltaActionL2Max, 0.257108);

acceptance.motor2FunctionalFlagCount = 1;
gate = classifyNoGloveStage6Gate(acceptance, rest, 0);
testCase.verifyFalse(gate.passed);
testCase.verifyFalse(gate.checks.motor2);
end

function testPilotRefusesFailedSmokeManifest(testCase)
testFile = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testFile)));
addpath(fullfile(matlabRoot, "workflows", "published"));
manifestPath = fullfile(testCase.TestData.tempDir, ...
    "failed_smoke_manifest.json");
fid = fopen(manifestPath, "w");
testCase.assertGreaterThanOrEqual(fid, 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", jsonencode(struct( ...
    "phase", "smoke", "phaseGatePassed", false)));
clear cleanup

testCase.verifyError(@() run_no_glove_stage6_pilot(struct( ...
    "smokeManifestPath", manifestPath)), ...
    "run_no_glove_stage6_training:PriorGateFailed");
end

function analysis = nominalAnalysis()
analysis = struct( ...
    "allFinite", true, ...
    "positionViolationEpisodeCount", 0, ...
    "saturationFraction", 0, ...
    "deltaActionL2", 0, ...
    "motor2FunctionalFlagCount", 0, ...
    "otherMotorFunctionalFlagCount", 0);
end
