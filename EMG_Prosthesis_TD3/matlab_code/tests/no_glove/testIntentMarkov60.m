function tests = testIntentMarkov60
%testIntentMarkov60 deterministic ETAPA 3 state/alignment tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
[config, dataset, calibration, expected] = buildFixture(11);
testCase.TestData.matlabRoot = matlabRoot;
testCase.TestData.config = config;
testCase.TestData.dataset = dataset;
testCase.TestData.calibration = calibration;
testCase.TestData.expected = expected;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testObservationLayoutIndices(testCase)
legacy = buildObservationLayout("legacy44", 40, 3, 4);
testCase.verifyEqual(legacy.totalLength, 44);
testCase.verifyEqual(legacy.emg, 1:40);
testCase.verifyEqual(legacy.encoder, 41:44);
testCase.verifyEmpty(legacy.deltaEncoder);

markov = buildObservationLayout("markov52", 40, 3, 4);
testCase.verifyEqual(markov.totalLength, 52);
testCase.verifyEqual(markov.deltaEncoder, 45:48);
testCase.verifyEqual(markov.previousEffectiveAction, 49:52);

stacked = buildObservationLayout("stackedEmg132", 40, 3, 4);
testCase.verifyEqual(stacked.totalLength, 132);
testCase.verifyEqual(stacked.emg, 1:120);
testCase.verifyEqual(stacked.encoder, 121:124);
testCase.verifyEqual(stacked.deltaEncoder, 125:128);
testCase.verifyEqual(stacked.previousEffectiveAction, 129:132);

intent = buildObservationLayout("intentMarkov60", 40, 3, 4);
testCase.verifyEqual(intent.totalLength, 60);
testCase.verifyEqual(intent.emg, 1:40);
testCase.verifyEqual(intent.encoder, 41:44);
testCase.verifyEqual(intent.deltaEncoder, 45:48);
testCase.verifyEqual(intent.previousEffectiveAction, 49:52);
testCase.verifyEqual(intent.referencePosition, 53:56);
testCase.verifyEqual(intent.referenceVelocity, 57:60);
testCase.verifyError(@() buildObservationLayout("unknown", 40, 3, 4), ...
    "buildObservationLayout:UnsupportedVariant");
end

function testHistoricalObservationDimensions(testCase)
emgSet = makeEpisodeSet(testCase.TestData.dataset.evaluationRawEmg);
variants = ["legacy44", "markov52", "stackedEmg132"];
expectedLengths = [44, 52, 132];
for variantIdx = 1:numel(variants)
    profile = buildNoGloveStage1Override(11);
    profile.observationVariant = variants(variantIdx);
    setConfigurablesOverride(profile);
    env = Env("", true, emgSet, {});
    observation = reset(env);
    testCase.verifyEqual(numel(observation), expectedLengths(variantIdx));
    testCase.verifyTrue(all(isfinite(observation)));
    testCase.verifyEqual(env.observationVariant, variants(variantIdx));
end
end

function testIntentConfigurationFailsClosed(testCase)
profile = buildNoGloveStage1Override(11);
profile.observationVariant = "intentMarkov60";
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:IntentStateRequiresDecoder");

profile.intentDecoderEnabled = true;
profile.intentCalibration = testCase.TestData.calibration;
profile.intentExpectedContext = testCase.TestData.expected;
profile.referenceSource = "glove";
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:IntentStateRequiresEmgIntent");

profile.referenceSource = "emgIntent";
profile.stateLength = 59;
setConfigurablesOverride(profile);
testCase.verifyError(@() configurables(), ...
    "configurables:StateLengthMismatch");

profile = buildNoGloveStage3Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile.period = profile.period / 2;
setConfigurablesOverride(profile);
emgSet = makeEpisodeSet(testCase.TestData.dataset.evaluationRawEmg);
testCase.verifyError(@() Env("", true, emgSet, {}), ...
    "Env:IntentPeriodMismatch");
end

function testIntentResetAndStepOrdering(testCase)
[env, cleanup] = makeStage3Env(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
initialObservation = reset(env);

testCase.verifySize(initialObservation, [60, 1]);
testCase.verifyEqual(initialObservation(layout.referencePosition), ...
    initialObservation(layout.encoder), "AbsTol", 1e-12);
testCase.verifyEqual(initialObservation(layout.deltaEncoder), zeros(4, 1));
testCase.verifyEqual(initialObservation(layout.previousEffectiveAction), ...
    zeros(4, 1));
testCase.verifyEqual(initialObservation(layout.referenceVelocity), ...
    zeros(4, 1));
testCase.verifyEqual(env.intentGateState, struct( ...
    "isActive", false, "onCount", 0, "offCount", 0));

stateBeforeAction = initialObservation;
action = [0.4; -0.4; 0.2; -0.2];
[nextObservation, reward] = step(env, action);
effectiveAction = env.actionSatLog(1, :)';

testCase.verifyEqual(env.stateLog(1, :)', stateBeforeAction, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(env.referenceHistory(1, :)', ...
    stateBeforeAction(layout.referencePosition), "AbsTol", 1e-12);
testCase.verifyEqual(nextObservation(layout.previousEffectiveAction), ...
    effectiveAction, "AbsTol", 1e-12);
testCase.verifyEqual(nextObservation(layout.referencePosition), ...
    env.intentTarget, "AbsTol", 1e-12);
testCase.verifyEqual(nextObservation(layout.referenceVelocity), ...
    env.intentVelocity, "AbsTol", 1e-12);
provenance = env.intentProvenanceLog{1};
testCase.verifyTrue(isstruct(provenance) && isscalar(provenance));
testCase.verifyEqual(provenance.schemaVersion, 1);
testCase.verifyEqual(provenance.transitionStep, 1);
testCase.verifyEqual(provenance.referencePositionBefore, ...
    stateBeforeAction(layout.referencePosition)', "AbsTol", 1e-12);
testCase.verifyEqual(provenance.referencePositionAfter, ...
    nextObservation(layout.referencePosition)', "AbsTol", 1e-12);
testCase.verifyEqual(provenance.referenceVelocityAfter, ...
    nextObservation(layout.referenceVelocity)', "AbsTol", 1e-12);
testCase.verifyEqual(provenance.zeroReferenceReason, ...
    classifyIntentZeroReferenceReason( ...
        provenance.referenceVelocityAfter, provenance.desiredVelocity, ...
        provenance, provenance, 1e-12));
expectedDelta = max(-1, min(1, ...
    nextObservation(layout.encoder) - stateBeforeAction(layout.encoder)));
testCase.verifyEqual(nextObservation(layout.deltaEncoder), ...
    expectedDelta, "AbsTol", 1e-12);

trackingError = env.trackingPredictionHistory(1, :) - ...
    env.referenceHistory(1, :);
configs = configurables();
expectedReward = -mean(trackingError.^2 + ...
    configs.rewardActionWeight * effectiveAction'.^2 + ...
    configs.rewardDeltaActionWeight * effectiveAction'.^2);
testCase.verifyEqual(reward, expectedReward, "AbsTol", 1e-12);
end

function testFullEpisodeReferenceInvariants(testCase)
[env, cleanup] = makeStage3Env(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
observation = reset(env);
calibration = testCase.TestData.calibration;
previousVelocity = observation(layout.referenceVelocity)';
stepCount = 0;
isDone = false;
while ~isDone && stepCount < 80
    stepCount = stepCount + 1;
    stateBeforeAction = observation;
    [observation, reward, isDone] = step(env, zeros(4, 1));
    qRef = observation(layout.referencePosition)';
    vRef = observation(layout.referenceVelocity)';
    previousQRef = stateBeforeAction(layout.referencePosition)';

    testCase.verifyTrue(isfinite(reward));
    testCase.verifyEqual(env.referenceHistory(stepCount, :), ...
        previousQRef, "AbsTol", 1e-12);
    testCase.verifyEqual(qRef - previousQRef, ...
        calibration.limits.deltaT .* vRef, "AbsTol", 1e-12);
    testCase.verifyLessThanOrEqual(abs(vRef), ...
        calibration.limits.velocityMax + 1e-12);
    testCase.verifyLessThanOrEqual(abs(vRef - previousVelocity), ...
        calibration.limits.accelerationMax .* ...
        calibration.limits.deltaT + 1e-12);
    testCase.verifyGreaterThanOrEqual(qRef, ...
        calibration.limits.positionMin - 1e-12);
    testCase.verifyLessThanOrEqual(qRef, ...
        calibration.limits.positionMax + 1e-12);
    previousVelocity = vRef;
end
testCase.verifyTrue(isDone);
testCase.verifyGreaterThan(stepCount, 0);
testCase.verifyEqual(env.referenceHistoryCount, stepCount);
testCase.verifyGreaterThan(max(abs(diff([ ...
    env.referenceHistory(1, :); ...
    observation(layout.referencePosition)'], 1, 1)), [], "all"), 0);
end

function testIntentEpisodeSaveMetadata(testCase)
[env, cleanup, tempDir] = makeStage3Env(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
stateBeforeAction = reset(env);
step(env, zeros(4, 1));
env.saveEpisode();
episodePath = fullfile(tempDir, "episode00001.mat");
testCase.verifyTrue(isfile(episodePath));
saved = load(episodePath, "stateLog", "referenceHistory", ...
    "observationVariant", "stateLength", ...
    "intentCalibrationContentSha256", "intentGateState", ...
    "intentProvenanceLog");
testCase.verifyEqual(saved.observationVariant, "intentMarkov60");
testCase.verifyEqual(saved.stateLength, 60);
testCase.verifyEqual(saved.intentCalibrationContentSha256, ...
    testCase.TestData.calibration.contentSha256);
testCase.verifyEqual(saved.stateLog(1, layout.referencePosition), ...
    saved.referenceHistory(1, :), "AbsTol", 1e-12);
testCase.verifyEqual(saved.stateLog(1, :)', stateBeforeAction, ...
    "AbsTol", 1e-12);
testCase.verifyTrue(isstruct(saved.intentGateState));
testCase.verifyEqual(numel(saved.intentProvenanceLog), 1);
testCase.verifyEqual(saved.intentProvenanceLog{1}.transitionStep, 1);
testCase.verifyEqual(saved.intentProvenanceLog{1}.schemaVersion, 1);
end

function testFutureEmgCannotChangeCurrentReward(testCase)
dataset = testCase.TestData.dataset;
windowLength = dataset.windowLengthSamples;
restPrefix = dataset.restCapture.rawEmg(1:5 * windowLength, :);
labels = string({dataset.instructionTrials.label});
closeRaw = dataset.instructionTrials(labels == "close_maximum").rawEmg;
openRaw = dataset.instructionTrials(labels == "open_maximum").rawEmg;
streamClose = [restPrefix; closeRaw];
streamOpen = [restPrefix; openRaw];

profile = buildNoGloveStage3Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile.maxNumberStepsInEpisodes = 20;
setConfigurablesOverride(profile);
envClose = Env("", true, makeEpisodeSet(streamClose), {});
envOpen = Env("", true, makeEpisodeSet(streamOpen), {});
obsClose = reset(envClose);
obsOpen = reset(envOpen);
testCase.verifyEqual(obsClose, obsOpen, "AbsTol", 1e-12);
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);

for stepIdx = 1:4
    [obsClose, rewardClose] = step(envClose, zeros(4, 1));
    [obsOpen, rewardOpen] = step(envOpen, zeros(4, 1));
    testCase.verifyEqual(obsClose, obsOpen, "AbsTol", 1e-12);
    testCase.verifyEqual(rewardClose, rewardOpen, "AbsTol", 1e-12);
end

% Step 5 reads the first differing future window. Its reward must still use
% the identical reference that was visible before the action.
[obsClose, rewardClose] = step(envClose, zeros(4, 1));
[obsOpen, rewardOpen] = step(envOpen, zeros(4, 1));
testCase.verifyEqual(rewardClose, rewardOpen, "AbsTol", 1e-12);
testCase.verifyEqual(envClose.referenceHistory(5, :), ...
    envOpen.referenceHistory(5, :), "AbsTol", 1e-12);
testCase.verifyNotEqual(obsClose(layout.emg), obsOpen(layout.emg));
testCase.verifyEqual(obsClose(layout.referencePosition), ...
    obsOpen(layout.referencePosition), "AbsTol", 1e-12);

% The second differing window activates the calibrated nOn=2 gate. The
% reward remains tied to the old common state, while the returned q_ref is
% allowed to diverge for the next action.
[obsClose, rewardClose] = step(envClose, zeros(4, 1));
[obsOpen, rewardOpen] = step(envOpen, zeros(4, 1));
testCase.verifyEqual(rewardClose, rewardOpen, "AbsTol", 1e-12);
testCase.verifyNotEqual(obsClose(layout.referencePosition), ...
    obsOpen(layout.referencePosition));
end

function [env, cleanup, tempDir] = makeStage3Env(testCase, rawEmg)
tempDir = string(tempname);
mkdir(tempDir);
cleanup = onCleanup(@() removeTempDir(tempDir));
profile = buildNoGloveStage3Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
setConfigurablesOverride(profile);
env = Env(tempDir, true, makeEpisodeSet(rawEmg), {});
end

function emgSet = makeEpisodeSet(rawEmg)
emgSet = {rawEmg, rawEmg};
end

function [config, dataset, calibration, expected] = buildFixture(seed)
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

function removeTempDir(tempDir)
if isfolder(tempDir)
    rmdir(tempDir, "s");
end
end
