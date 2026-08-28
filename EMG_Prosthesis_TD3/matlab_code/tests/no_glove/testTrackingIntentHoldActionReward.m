function tests = testTrackingIntentHoldActionReward
%testTrackingIntentHoldActionReward deterministic ETAPA 7H reward tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
testCase.TestData.corpus = buildNoGloveStage6SyntheticCorpus(11);
testCase.TestData.tempDir = string(tempname);
mkdir(testCase.TestData.tempDir);
emgs = testCase.TestData.corpus.trainingEmgs;
metadata = testCase.TestData.corpus.trainingMetadata;
testCase.TestData.datasetPath = fullfile( ...
    testCase.TestData.tempDir, "training.mat");
save(testCase.TestData.datasetPath, "emgs", "metadata");
end

function teardownOnce(testCase)
clearConfigurablesOverride();
if isfolder(testCase.TestData.tempDir) && ...
        startsWith(testCase.TestData.tempDir, string(tempdir))
    rmdir(testCase.TestData.tempDir, "s");
end
end

function setup(~)
clearConfigurablesOverride();
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testZeroWeightIsExactlyBaseReward(testCase)
profile = holdProfile(testCase, 0);
setConfigurablesOverride(profile);
context = makeContext();
context.trackingPrediction = [0.1, -0.2, 0.3, -0.4];
context.trackingVelocityPrediction = [0.2, 0, -0.1, 0];
context.previousEffectiveAction = [0.1, 0, 0, -0.2];
action = [0.4, -0.3, 0.2, -0.1];

[baseReward, baseVector, baseInfo] = ...
    trackingIntentActionRateReward([], action, context);
[holdReward, holdVector, holdInfo] = ...
    trackingIntentHoldActionReward([], action, context);

testCase.verifyEqual(holdReward, baseReward, "AbsTol", 0);
testCase.verifyEqual(holdVector, baseVector, "AbsTol", 0);
baseFields = string(fieldnames(baseInfo));
for idx = 1:numel(baseFields)
    field = baseFields(idx);
    testCase.verifyEqual(holdInfo.(field), baseInfo.(field));
end
testCase.verifyEqual(holdInfo.holdActive, 1);
testCase.verifyEqual(holdInfo.holdActionPenalty, 0);
end

function testAtTargetHoldAddsExactPenalty(testCase)
profile = holdProfile(testCase, 0.20);
setConfigurablesOverride(profile);
context = makeContext();
action = [1, -0.5, 0.25, 0];

[baseReward, baseVector] = ...
    trackingIntentActionRateReward([], action, context);
[reward, rewardVector, info] = ...
    trackingIntentHoldActionReward([], action, context);
expectedPenalty = 0.20.*action.^2;

testCase.verifyEqual(rewardVector, baseVector-expectedPenalty, ...
    "AbsTol", 1e-15);
testCase.verifyEqual(reward, baseReward-mean(expectedPenalty), ...
    "AbsTol", 1e-15);
testCase.verifyEqual(info.holdActive, 1);
testCase.verifyEqual(info.holdPositionMse, 0);
testCase.verifyEqual(info.holdVelocityMaxAbs, 0);
testCase.verifyEqual(info.holdActionL2, mean(action.^2), ...
    "AbsTol", 1e-15);
testCase.verifyEqual(info.holdActionPenalty, ...
    0.20*mean(action.^2), "AbsTol", 1e-15);
end

function testMovementDisablesHoldTerm(testCase)
setConfigurablesOverride(holdProfile(testCase, 0.20));
context = makeContext();
context.trackingVelocityTarget(3) = 2e-12;
action = [0.8, -0.6, 0.4, -0.2];
[baseReward, baseVector] = ...
    trackingIntentActionRateReward([], action, context);
[reward, rewardVector, info] = ...
    trackingIntentHoldActionReward([], action, context);

testCase.verifyEqual(reward, baseReward, "AbsTol", 0);
testCase.verifyEqual(rewardVector, baseVector, "AbsTol", 0);
testCase.verifyEqual(info.holdActive, 0);
testCase.verifyEqual(info.holdActionPenalty, 0);
end

function testDecisionStateControlsIndicatorWithoutFutureLeak(testCase)
setConfigurablesOverride(holdProfile(testCase, 0.20));
action = 0.5.*ones(1, 4);

decisionNear = makeContext();
decisionNear.trackingPrediction = ones(1, 4);
[~, ~, nearInfo] = trackingIntentHoldActionReward( ...
    [], action, decisionNear);
testCase.verifyEqual(nearInfo.holdActive, 1);

decisionFar = makeContext();
decisionFar.decisionPositionPrediction = 0.02.*ones(1, 4);
decisionFar.trackingPrediction = zeros(1, 4);
[baseReward, baseVector] = ...
    trackingIntentActionRateReward([], action, decisionFar);
[reward, rewardVector, farInfo] = ...
    trackingIntentHoldActionReward([], action, decisionFar);
testCase.verifyEqual(farInfo.holdPositionMse, 4e-4, "AbsTol", 1e-16);
testCase.verifyEqual(farInfo.holdActive, 0);
testCase.verifyEqual(reward, baseReward, "AbsTol", 0);
testCase.verifyEqual(rewardVector, baseVector, "AbsTol", 0);
end

function testEveryMotorReceivesOnlyItsPenalty(testCase)
setConfigurablesOverride(holdProfile(testCase, 0.20));
for motor = 1:4
    context = makeContext();
    action = zeros(1, 4);
    action(motor) = 0.5;
    [baseReward, baseVector] = ...
        trackingIntentActionRateReward([], action, context);
    [reward, rewardVector] = ...
        trackingIntentHoldActionReward([], action, context);
    expected = zeros(1, 4);
    expected(motor) = 0.20*0.5^2;
    testCase.verifyEqual(rewardVector, baseVector-expected, ...
        "AbsTol", 1e-15);
    testCase.verifyEqual(reward, baseReward-mean(expected), ...
        "AbsTol", 1e-15);
end
end

function testSelectorAndInvalidInputsFailClosed(testCase)
setConfigurablesOverride(holdProfile(testCase, 0.20));
context = makeContext();
action = [0.4, 0.3, 0.2, 0.1];
[directReward, directVector, directInfo] = ...
    trackingIntentHoldActionReward([], action, context);
[selectedReward, selectedVector, selectedInfo] = ...
    rewardFunctionSelector([], "trackingIntentHoldActionReward", ...
        action, context);
testCase.verifyEqual(selectedReward, directReward);
testCase.verifyEqual(selectedVector, directVector);
testCase.verifyEqual(selectedInfo, directInfo);

incomplete = rmfield(context, "decisionPositionPrediction");
testCase.verifyError(@() trackingIntentHoldActionReward( ...
    [], action, incomplete), ...
    "trackingIntentHoldActionReward:InvalidContext");
invalid = context;
invalid.decisionPositionPrediction(2) = NaN;
testCase.verifyError(@() trackingIntentHoldActionReward( ...
    [], action, invalid), ...
    "trackingIntentHoldActionReward:InvalidVector");
invalid = context;
invalid.referenceSource = "glove";
testCase.verifyError(@() trackingIntentHoldActionReward( ...
    [], action, invalid), ...
    "trackingIntentHoldActionReward:InvalidReferenceSource");
end

function testConfigurationValidation(testCase)
profile = holdProfile(testCase, 0.20);
setConfigurablesOverride(profile);
configs = configurables();
testCase.verifyEqual(configs.rewardType, ...
    "trackingIntentHoldActionReward");
testCase.verifyEqual(configs.intentHoldActionWeight, 0.20);
testCase.verifyEqual(configs.intentHoldVelocityTolerance, 1e-12);
testCase.verifyEqual(configs.intentHoldPositionMseTolerance, 1e-4);

profile.intentHoldActionWeight = -1;
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:InvalidIntentRewardWeight");
profile = holdProfile(testCase, 0.20);
profile.intentHoldPositionMseTolerance = -1;
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:InvalidIntentHoldTolerance");
profile = holdProfile(testCase, 0.20);
profile.observationVariant = "markov52";
profile.stateLength = 52;
profile.intentDecoderEnabled = false;
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:IntentRewardRequiresIntentState");
end

function testCompleteEpisodePersistsCausalDiagnostics(testCase)
episodeDir = fullfile(testCase.TestData.tempDir, "hold_episode");
mkdir(episodeDir);
profile = holdProfile(testCase, 0.20);
profile.maxNumberStepsInEpisodes = 12;
profile.flagSaveTraining = true;
profile.episode_save_freq = 1;
setConfigurablesOverride(profile);
samplesPerStep = round(profile.period* ...
    testCase.TestData.corpus.expectedContext.sampleRateHz);
rawEmg = testCase.TestData.corpus.trainingEmgs{1, 1};
rawEmg = rawEmg(1:(profile.maxNumberStepsInEpisodes+1)* ...
    samplesPerStep, :);
env = Env(episodeDir, true, {rawEmg, rawEmg}, {});
reset(env);
pattern = [0.4, 0, 0, 0; 0, 0, 0, 0; -0.4, 0.2, 0, 0];
isDone = false;
stepCount = 0;
while ~isDone
    stepCount = stepCount+1;
    action = pattern(mod(stepCount-1, size(pattern, 1))+1, :)';
    [~, ~, isDone] = step(env, action);
end
testCase.verifyEqual(stepCount, 12);
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
for idx = 1:stepCount
    state = env.stateLog(idx, :);
    expectedPositionMse = mean((state(layout.encoder)- ...
        state(layout.referencePosition)).^2);
    expectedVelocity = max(abs(state(layout.referenceVelocity)));
    expectedActive = expectedVelocity <= 1e-12 && ...
        expectedPositionMse <= 1e-4;
    info = env.rewardInfoLog{idx};
    testCase.verifyEqual(info.holdPositionMse, ...
        expectedPositionMse, "AbsTol", 1e-12);
    testCase.verifyEqual(info.holdVelocityMaxAbs, ...
        expectedVelocity, "AbsTol", 1e-12);
    testCase.verifyEqual(info.holdActive, double(expectedActive));
    testCase.verifyEqual(info.holdActionL2, ...
        double(expectedActive)*mean(env.actionSatLog(idx, :).^2), ...
        "AbsTol", 1e-12);
    reconstructed = -( ...
        profile.intentRewardPositionWeight*info.trackingMse + ...
        profile.intentRewardVelocityWeight*info.velocityMse + ...
        profile.intentRewardActionWeight*info.actionL2 + ...
        profile.intentRewardDeltaActionWeight*info.deltaActionL2 + ...
        profile.intentRewardSaturationWeight* ...
            info.softSaturationPenalty + info.holdActionPenalty);
    testCase.verifyEqual(env.rewardLog(idx), reconstructed, ...
        "AbsTol", 1e-12);
end
env.saveEpisode();
episodePath = fullfile(episodeDir, ...
    sprintf("episode%05d.mat", env.episodeCounter));
saved = load(episodePath, ...
    "rewardInfoLog");
testCase.verifyEqual(numel(saved.rewardInfoLog), stepCount);
holdFields = ["holdActive", "holdPositionMse", ...
    "holdVelocityMaxAbs", "holdActionL2", "holdActionPenalty"];
for idx = 1:stepCount
    testCase.verifyTrue(all(isfield(saved.rewardInfoLog{idx}, ...
        cellstr(holdFields))), sprintf("saved step %d", idx));
end
end

function profile = holdProfile(testCase, weight)
corpus = testCase.TestData.corpus;
profile = buildNoGloveStage6Override(corpus.calibration, ...
    corpus.expectedContext, 11, 200, 50, ...
    testCase.TestData.datasetPath, testCase.TestData.tempDir);
profile.rewardType = "trackingIntentHoldActionReward";
profile.intentRewardActionWeight = 0.05;
profile.intentHoldActionWeight = weight;
profile.intentHoldVelocityTolerance = 1e-12;
profile.intentHoldPositionMseTolerance = 1e-4;
end

function context = makeContext()
context = struct( ...
    "trackingTarget", zeros(1, 4), ...
    "trackingPrediction", zeros(1, 4), ...
    "trackingVelocityTarget", zeros(1, 4), ...
    "trackingVelocityPrediction", zeros(1, 4), ...
    "decisionPositionPrediction", zeros(1, 4), ...
    "previousEffectiveAction", zeros(1, 4), ...
    "referenceSource", "emgIntent");
end
