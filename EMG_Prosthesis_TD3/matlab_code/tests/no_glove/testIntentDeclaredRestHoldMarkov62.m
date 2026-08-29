function tests = testIntentDeclaredRestHoldMarkov62
%testIntentDeclaredRestHoldMarkov62 deterministic ETAPA 7M tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
[dataset, calibration, expected] = buildFixture(11);
testCase.TestData.dataset = dataset;
testCase.TestData.calibration = calibration;
testCase.TestData.expected = expected;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testLayoutIndicesAndHistoricalDimensions(testCase)
expected = ["legacy44", 44; "markov52", 52; ...
    "intentMarkov60", 60; "intentDeclaredRestHoldMarkov62", 62; ...
    "stackedEmg132", 132];
for idx = 1:size(expected, 1)
    layout = buildObservationLayout(expected(idx, 1), 40, 3, 4);
    testCase.verifyEqual(layout.totalLength, double(expected(idx, 2)));
end
layout60 = buildObservationLayout("intentMarkov60", 40, 3, 4);
layout62 = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
testCase.verifyEqual(layout62.emg, layout60.emg);
testCase.verifyEqual(layout62.encoder, layout60.encoder);
testCase.verifyEqual(layout62.deltaEncoder, layout60.deltaEncoder);
testCase.verifyEqual(layout62.previousEffectiveAction, ...
    layout60.previousEffectiveAction);
testCase.verifyEqual(layout62.referencePosition, ...
    layout60.referencePosition);
testCase.verifyEqual(layout62.referenceVelocity, ...
    layout60.referenceVelocity);
testCase.verifyEqual(layout62.declaredRest, 61);
testCase.verifyEqual(layout62.holdLatch, 62);
end

function testSemanticLatchRecurrenceAndCountdownDivergence(testCase)
q = [0.2, 0.3, 0.4, 0.5];
[latch, details] = updateIntentDeclaredRestHoldState( ...
    false, true, q, q, 1e-4);
testCase.verifyTrue(latch);
testCase.verifyTrue(details.nearTarget);

[latch, details] = updateIntentDeclaredRestHoldState( ...
    true, true, q, q+0.02, 1e-4);
testCase.verifyTrue(latch);
testCase.verifyFalse(details.nearTarget);

% activeCountdownZero is non-rest. A purely geometric rule would activate
% because q==q_ref, whereas the semantic contract must release immediately.
[latch, details] = updateIntentDeclaredRestHoldState( ...
    true, false, q, q, 1e-4);
testCase.verifyFalse(latch);
testCase.verifyTrue(details.nearTarget);
testCase.verifyFalse(details.declaredRest);

[latch, ~] = updateIntentDeclaredRestHoldState( ...
    false, true, q, q+0.02, 1e-4);
testCase.verifyFalse(latch);
testCase.verifyError(@() updateIntentDeclaredRestHoldState( ...
    false, true, q(1:3), q, 1e-4), ...
    "updateIntentDeclaredRestHoldState:InvalidPosition");
end

function testConfigurationFailsClosed(testCase)
profile = buildNoGloveStage7mOverride(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
setConfigurablesOverride(profile);
configs = configurables();
testCase.verifyEqual(configs.observationVariant, ...
    "intentDeclaredRestHoldMarkov62");
testCase.verifyEqual(configs.stateLength, 62);
testCase.verifyTrue(configs.simMotors);
testCase.verifyFalse(configs.run_training);

invalid = profile;
invalid.referenceSource = "glove";
setConfigurablesOverride(invalid);
testCase.verifyError(@() configurables(), ...
    "configurables:IntentStateRequiresEmgIntent");

invalid = profile;
invalid.intentDecoderEnabled = false;
setConfigurablesOverride(invalid);
testCase.verifyError(@() configurables(), ...
    "configurables:IntentStateRequiresDecoder");

invalid = profile;
invalid.stateLength = 61;
setConfigurablesOverride(invalid);
testCase.verifyError(@() configurables(), ...
    "configurables:StateLengthMismatch");

invalid = profile;
invalid.intentDeclaredRestHoldPositionMseTolerance = -1;
setConfigurablesOverride(invalid);
testCase.verifyError(@() configurables(), ...
    "configurables:InvalidIntentDeclaredRestHoldTolerance");
end

function testResetAndTransitionAlignment(testCase)
[env, cleanup] = makeStage7mEnv(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
initial = reset(env);
testCase.verifySize(initial, [62, 1]);
testCase.verifyEqual(initial(layout.referencePosition), ...
    initial(layout.encoder), "AbsTol", 1e-12);
testCase.verifyEqual(initial(layout.declaredRest), 1);
testCase.verifyEqual(initial(layout.holdLatch), 1);
testCase.verifyEqual(env.intentHoldPositionMse, 0, "AbsTol", 1e-12);

[next, reward] = step(env, [0.4; -0.4; 0.2; -0.2]);
testCase.verifyTrue(isfinite(reward));
testCase.verifyEqual(env.stateLog(1, :)', initial, "AbsTol", 1e-12);
provenance = env.intentProvenanceLog{1};
testCase.verifyEqual(provenance.schemaVersion, 2);
testCase.verifyEqual(provenance.declaredRestHoldContractVersion, 1);
testCase.verifyEqual(double(provenance.declaredRestBefore), ...
    initial(layout.declaredRest));
testCase.verifyEqual(double(provenance.holdLatchBefore), ...
    initial(layout.holdLatch));
testCase.verifyEqual(double(provenance.declaredRestAfter), ...
    next(layout.declaredRest));
testCase.verifyEqual(double(provenance.holdLatchAfter), ...
    next(layout.holdLatch));
expectedMse = mean((next(layout.encoder)- ...
    next(layout.referencePosition)).^2);
testCase.verifyEqual(provenance.holdPositionMseAfter, ...
    expectedMse, "AbsTol", 1e-12);
testCase.verifyEqual(env.intentHoldPositionMse, ...
    expectedMse, "AbsTol", 1e-12);
end

function testIntent60PrefixAndBehaviorRemainIdentical(testCase)
raw = testCase.TestData.dataset.evaluationRawEmg;
profile60 = buildNoGloveStage4Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile60.maxNumberStepsInEpisodes = 20;
profile62 = buildNoGloveStage7mOverride(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile62.maxNumberStepsInEpisodes = 20;
actions = deterministicActions(12);
trace60 = runTrace(profile60, raw, actions);
trace62 = runTrace(profile62, raw, actions);

testCase.verifyEqual(trace62.observations(:, 1:60), ...
    trace60.observations, "AbsTol", 1e-12);
testCase.verifyEqual(trace62.rewards, trace60.rewards, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(trace62.rawAction, trace60.rawAction, ...
    "AbsTol", 1e-12);
testCase.verifyEqual(trace62.effectiveAction, ...
    trace60.effectiveAction, "AbsTol", 1e-12);
testCase.verifyEqual(trace62.pwm, trace60.pwm, "AbsTol", 1e-12);
testCase.verifyEqual(trace62.referenceHistory, ...
    trace60.referenceHistory, "AbsTol", 1e-12);
testCase.verifyEqual(trace62.safety, trace60.safety);
testCase.verifyTrue(all(trace60.provenanceSchemaVersion == 1));
testCase.verifyTrue(all(trace62.provenanceSchemaVersion == 2));
testCase.verifyFalse(isfield(trace60.firstProvenance, ...
    "declaredRestAfter"));
testCase.verifyTrue(isfield(trace62.firstProvenance, ...
    "declaredRestAfter"));
end

function testRuntimeBitsMatchIndependentReplay(testCase)
[env, cleanup] = makeStage7mEnv(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
observations = nan(13, 62);
observations(1, :) = reset(env)';
for idx = 1:12
    observations(idx+1, :) = step(env, zeros(4, 1))';
end

expectedLatch = true;
testCase.verifyEqual(observations(1, layout.declaredRest), 1);
testCase.verifyEqual(observations(1, layout.holdLatch), 1);
for idx = 1:12
    provenance = env.intentProvenanceLog{idx};
    expectedRest = logical(provenance.isRest);
    mse = mean((observations(idx+1, layout.encoder)- ...
        observations(idx+1, layout.referencePosition)).^2);
    near = mse <= env.intentDeclaredRestHoldPositionMseTolerance;
    if ~expectedRest
        expectedLatch = false;
    elseif near
        expectedLatch = true;
    end
    testCase.verifyEqual(observations(idx+1, layout.declaredRest), ...
        double(expectedRest));
    testCase.verifyEqual(observations(idx+1, layout.holdLatch), ...
        double(expectedLatch));
end
end

function testFutureEmgCannotChangeCurrentRewardOrBits(testCase)
dataset = testCase.TestData.dataset;
windowLength = dataset.windowLengthSamples;
restPrefix = dataset.restCapture.rawEmg(1:5*windowLength, :);
labels = string({dataset.instructionTrials.label});
closeRaw = dataset.instructionTrials(labels == "close_maximum").rawEmg;
openRaw = dataset.instructionTrials(labels == "open_maximum").rawEmg;
streamClose = [restPrefix; closeRaw];
streamOpen = [restPrefix; openRaw];
profile = buildNoGloveStage7mOverride(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile.maxNumberStepsInEpisodes = 20;
setConfigurablesOverride(profile);
rootClose = string(tempname);
rootOpen = string(tempname);
mkdir(rootClose);
mkdir(rootOpen);
cleanup = onCleanup(@() removeTwoDirs(rootClose, rootOpen));
envClose = Env(rootClose, true, makeEpisodeSet(streamClose), {});
envOpen = Env(rootOpen, true, makeEpisodeSet(streamOpen), {});
obsClose = reset(envClose);
obsOpen = reset(envOpen);
testCase.verifyEqual(obsClose, obsOpen, "AbsTol", 1e-12);
layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);

for idx = 1:4
    [obsClose, rewardClose] = step(envClose, zeros(4, 1));
    [obsOpen, rewardOpen] = step(envOpen, zeros(4, 1));
    testCase.verifyEqual(obsClose, obsOpen, "AbsTol", 1e-12);
    testCase.verifyEqual(rewardClose, rewardOpen, "AbsTol", 1e-12);
end
[~, rewardClose] = step(envClose, zeros(4, 1));
[~, rewardOpen] = step(envOpen, zeros(4, 1));
testCase.verifyEqual(rewardClose, rewardOpen, "AbsTol", 1e-12);
testCase.verifyEqual(envClose.stateLog(5, ...
    [layout.declaredRest, layout.holdLatch]), ...
    envOpen.stateLog(5, [layout.declaredRest, layout.holdLatch]));
end

function testResetClearsAndReinitializesMemory(testCase)
[env, cleanup] = makeStage7mEnv(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
reset(env);
step(env, zeros(4, 1));
secondInitial = reset(env);
testCase.verifyEqual(secondInitial(layout.declaredRest), 1);
testCase.verifyEqual(secondInitial(layout.holdLatch), 1);
testCase.verifyEqual(env.intentHoldPositionMse, 0, "AbsTol", 1e-12);
testCase.verifyTrue(all(cellfun(@isempty, env.intentProvenanceLog)));
end

function testSavedMetadataIncludesExplicitContract(testCase)
[env, cleanup, root] = makeStage7mEnv(testCase, ...
    testCase.TestData.dataset.evaluationRawEmg); %#ok<ASGLU>
reset(env);
step(env, zeros(4, 1));
env.saveEpisode();
saved = load(fullfile(root, "episode00001.mat"), ...
    "observationVariant", "stateLength", "intentDeclaredRest", ...
    "intentHoldLatch", "intentHoldPositionMse", ...
    "intentDeclaredRestHoldPositionMseTolerance", ...
    "intentProvenanceLog");
testCase.verifyEqual(saved.observationVariant, ...
    "intentDeclaredRestHoldMarkov62");
testCase.verifyEqual(saved.stateLength, 62);
testCase.verifyEqual(saved.intentDeclaredRest, env.intentDeclaredRest);
testCase.verifyEqual(saved.intentHoldLatch, env.intentHoldLatch);
testCase.verifyEqual(saved.intentHoldPositionMse, ...
    env.intentHoldPositionMse, "AbsTol", 1e-12);
testCase.verifyEqual(saved.intentDeclaredRestHoldPositionMseTolerance, ...
    1e-4, "AbsTol", 1e-12);
testCase.verifyEqual(saved.intentProvenanceLog{1}.schemaVersion, 2);
end

function testLauncherOptionsFailClosed(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7m_observable_hold_state(struct("unknown", 1)), ...
    "run_no_glove_stage7m_observable_hold_state:UnknownOption");
testCase.verifyError(@() ...
    run_no_glove_stage7m_observable_hold_state(struct( ...
    "stage7lRunRoot", fullfile(tempdir, "missing-stage7l"))), ...
    "run_no_glove_stage7m_observable_hold_state:MissingStage7l");
end

function trace = runTrace(profile, raw, actions)
setConfigurablesOverride(profile);
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTempDir(root));
env = Env(root, true, makeEpisodeSet(raw), {});
stateLength = configurables("stateLength");
count = size(actions, 1);
trace.observations = nan(count+1, stateLength);
trace.rewards = nan(count, 1);
trace.observations(1, :) = reset(env)';
for idx = 1:count
    [observation, trace.rewards(idx)] = step(env, actions(idx, :)');
    trace.observations(idx+1, :) = observation';
end
trace.rawAction = env.actionLog(1:count, :);
trace.effectiveAction = env.actionSatLog(1:count, :);
trace.pwm = env.actionPwmLog(1:count, :);
trace.referenceHistory = env.referenceHistory(1:count, :);
trace.safety = env.positionSafetyInterventionLog(1:count, :);
trace.provenanceSchemaVersion = cellfun( ...
    @(value) value.schemaVersion, env.intentProvenanceLog(1:count));
trace.firstProvenance = env.intentProvenanceLog{1};
end

function actions = deterministicActions(count)
pattern = [0.4, -0.4, 0.2, -0.2; ...
    0, 0, 0, 0; -0.2, 0.2, -0.4, 0.4; ...
    0.1, 0.1, -0.1, -0.1];
actions = repmat(pattern, ceil(count/size(pattern, 1)), 1);
actions = actions(1:count, :);
end

function [env, cleanup, root] = makeStage7mEnv(testCase, raw)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTempDir(root));
profile = buildNoGloveStage7mOverride(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
setConfigurablesOverride(profile);
env = Env(root, true, makeEpisodeSet(raw), {});
end

function emgSet = makeEpisodeSet(raw)
emgSet = {raw, raw};
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
    "units", struct("rawEmg", dataset.restCapture.rawEmgUnits, ...
        "envelope", options.envelopeUnits, ...
        "position", options.positionUnits, ...
        "velocity", options.velocityUnits, ...
        "acceleration", options.accelerationUnits), ...
    "synergyMatrixVersion", options.synergyMatrixVersion, ...
    "instructionProtocolVersion", options.instructionProtocolVersion, ...
    "sourceDomain", "rawEmgSameSession", ...
    "calibrationContentSha256", calibration.contentSha256);
end

function removeTwoDirs(first, second)
removeTempDir(first);
removeTempDir(second);
end

function removeTempDir(root)
if isfolder(root) && startsWith(root, string(tempdir))
    rmdir(root, "s");
end
end
