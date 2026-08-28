function tests = testNoGloveStage7eCheckpointEvolution
%testNoGloveStage7eCheckpointEvolution deterministic ETAPA 7E tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
[training, actuator, weights] = makeFixture();
testCase.TestData.training = training;
testCase.TestData.actuator = actuator;
testCase.TestData.weights = weights;
end

function testPresentFromEarlyCheckpoint(testCase)
checkpoints = makeCheckpoints([0.40 0.38 0.36 0.35]);
analysis = runAnalysis(testCase, checkpoints);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "presentFromEarlyCheckpoint");
testCase.verifyEqual(analysis.sourceDecision.firstActiveCheckpoint, ...
    "Agent50");
testCase.verifyFalse(analysis.sourceDecision.materialAttenuation);
testCase.verifyEqual(analysis.rewardAudit.maximumAuditError, 0, ...
    "AbsTol", 1e-15);
testCase.verifyFalse(analysis.rootCauseIdentified);
testCase.verifyFalse(analysis.checkpointSelectedAsWinner);
testCase.verifyFalse(analysis.explorationEffectIsolated);
testCase.verifyFalse(analysis.counterfactualRewardCalculated);
testCase.verifyFalse(analysis.runTraining);
testCase.verifyFalse(analysis.envCreated);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.rewardFunctionInvoked);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testEmergesDuringTraining(testCase)
checkpoints = makeCheckpoints([0 0.20 0.30 0.40]);
analysis = runAnalysis(testCase, checkpoints);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "emergesDuringTraining");
testCase.verifyEqual(analysis.sourceDecision.firstActiveCheckpoint, ...
    "Agent100");
testCase.verifyFalse(analysis.sourceDecision.earlyCheckpointActive);
testCase.verifyTrue(analysis.sourceDecision.laterCheckpointActive);
end

function testAttenuatesButPersists(testCase)
checkpoints = makeCheckpoints([0.80 0.60 0.40 0.20]);
analysis = runAnalysis(testCase, checkpoints);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "attenuatesButPersists");
testCase.verifyTrue(analysis.sourceDecision.materialAttenuation);
testCase.verifyGreaterThanOrEqual( ...
    analysis.sourceDecision.relativeMeanAbsPwmReduction, 0.25);
end

function testCheckpointEvolutionUnresolved(testCase)
checkpoints = makeCheckpoints([0 0 0 0]);
analysis = runAnalysis(testCase, checkpoints);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "checkpointEvolutionUnresolved");
testCase.verifyEqual(analysis.sourceDecision.firstActiveCheckpoint, "none");
end

function testHistoricalActionsStaySeparate(testCase)
checkpoints = makeCheckpoints([0.40 0.38 0.36 0.35]);
analysis = runAnalysis(testCase, checkpoints);
testCase.verifyEqual(height(analysis.historicalSummary), 5);
testCase.verifyEqual(height(analysis.blockEndReplayComparison), 20);
testCase.verifyEqual(analysis.historicalActionContract, ...
    "changingTrainingPolicyPlusExplorationNotDeterministicCheckpoint");
testCase.verifyFalse( ...
    analysis.historicalActionInterpretedAsDeterministicActor);
end

function testRewardMismatchFailsClosed(testCase)
training = testCase.TestData.training;
training.recordedReward(1) = training.recordedReward(1)+0.01;
checkpoints = makeCheckpoints([0.40 0.38 0.36 0.35]);
testCase.verifyError(@() analyzeNoGloveStage7eCheckpointEvolution( ...
    training, checkpoints, testCase.TestData.actuator, ...
    testCase.TestData.weights), ...
    "analyzeNoGloveStage7eCheckpointEvolution:RewardMismatch");
end

function testNonholdStateFailsClosed(testCase)
training = testCase.TestData.training;
training.state(1, 57) = 0.01;
checkpoints = makeCheckpoints([0.40 0.38 0.36 0.35]);
testCase.verifyError(@() analyzeNoGloveStage7eCheckpointEvolution( ...
    training, checkpoints, testCase.TestData.actuator, ...
    testCase.TestData.weights), ...
    "analyzeNoGloveStage7eCheckpointEvolution:NonholdState");
end

function testCheckpointOrderFailsClosed(testCase)
checkpoints = makeCheckpoints([0.40 0.38 0.36 0.35]);
checkpoints(2).episode = 99;
testCase.verifyError(@() runAnalysis(testCase, checkpoints), ...
    "analyzeNoGloveStage7eCheckpointEvolution:CheckpointOrder");
end

function analysis = runAnalysis(testCase, checkpoints)
analysis = analyzeNoGloveStage7eCheckpointEvolution( ...
    testCase.TestData.training, checkpoints, ...
    testCase.TestData.actuator, testCase.TestData.weights);
end

function [training, actuator, weights] = makeFixture()
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
episode = [1; 25; 51; 75; 101; 125; 151; 175];
stateCount = numel(episode);
state = zeros(stateCount, layout.totalLength);
for row = 1:stateCount
    state(row, layout.emg) = 0.01*row+(0:39)*1e-3;
    state(row, layout.encoder) = 0.02*row+(0:3)*1e-3;
    state(row, layout.deltaEncoder) = 1e-3*(1:4);
    state(row, layout.previousEffectiveAction) = 0.1*(1:4);
    state(row, layout.referencePosition) = 0.05*row*ones(1, 4);
end
historicalRaw = 0.3*ones(stateCount, 4);
actuator = struct("maxPwm", 255, "activationThreshold", 0.05, ...
    "commandLevels", [0 64 96 128 160 192 224 255]);
[historicalEffective, historicalPwm] = quantizeFixture( ...
    historicalRaw, actuator);
weights = struct("position", 1, "velocity", 0, "action", 0.01, ...
    "deltaAction", 0.05, "saturation", 0.02, ...
    "softActionLimit", 0.9);

trackingMse = 0.2+0.001*(1:stateCount)';
trackingMae = sqrt(trackingMse);
velocityMse = 0.1*ones(stateCount, 1);
actionL2 = mean(historicalEffective.^2, 2);
deltaActionL2 = 0.02*ones(stateCount, 1);
smoothnessPenalty = weights.deltaAction*deltaActionL2;
saturationFraction = zeros(stateCount, 1);
softSaturationPenalty = zeros(stateCount, 1);
saturationPenalty = weights.saturation*softSaturationPenalty;
referenceSource = repmat("emgIntent", stateCount, 1);
rewardInfo = table(trackingMse, trackingMae, velocityMse, actionL2, ...
    smoothnessPenalty, deltaActionL2, saturationFraction, ...
    softSaturationPenalty, saturationPenalty, referenceSource);
totalCost = weights.position*trackingMse + ...
    weights.velocity*velocityMse + weights.action*actionL2 + ...
    weights.deltaAction*deltaActionL2 + ...
    weights.saturation*softSaturationPenalty;
recordedReward = -totalCost;
recordedRewardVector = repmat(recordedReward, 1, 4);
training = struct("state", state, "episode", episode, ...
    "step", 2*ones(stateCount, 1), ...
    "previousReferencePosition", state(:, layout.referencePosition), ...
    "historicalRawAction", historicalRaw, ...
    "historicalEffectiveAction", historicalEffective, ...
    "historicalPwm", historicalPwm, ...
    "recordedReward", recordedReward, ...
    "recordedRewardVector", recordedRewardVector, ...
    "rewardInfo", rewardInfo);
end

function checkpoints = makeCheckpoints(values)
episodes = [50 100 150 200];
labels = ["Agent50" "Agent100" "Agent150" "Agent200"];
checkpoints = repmat(struct("label", "", "episode", 0, ...
    "evaluator", []), 1, 4);
for checkpointIdx = 1:4
    value = values(checkpointIdx);
    checkpoints(checkpointIdx) = struct( ...
        "label", labels(checkpointIdx), ...
        "episode", episodes(checkpointIdx), ...
        "evaluator", @(state) constantActor(state, value));
end
end

function action = constantActor(state, value)
action = value*ones(size(state, 1), 4);
end

function [effective, pwm] = quantizeFixture(raw, actuator)
effective = zeros(size(raw));
pwm = zeros(size(raw));
for row = 1:size(raw, 1)
    [effectiveRow, pwmRow] = quantizeBaselineAction( ...
        raw(row, :), actuator.maxPwm, actuator.activationThreshold, ...
        actuator.commandLevels);
    effective(row, :) = effectiveRow;
    pwm(row, :) = pwmRow;
end
end
