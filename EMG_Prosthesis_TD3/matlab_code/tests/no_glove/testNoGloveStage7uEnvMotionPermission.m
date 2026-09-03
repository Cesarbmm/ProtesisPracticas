function tests = testNoGloveStage7uEnvMotionPermission
%testNoGloveStage7uEnvMotionPermission deterministic Env-level regression
%tests for the ETAPA 7U opt-in motionPermission gate.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
config = buildNoGloveStage2OfflineConfig(11);
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
% 21 windows: rest_initial(6) + transient_noise(1, rejected by nOn=2) +
% rest_after_noise(4) + close_moderate(5) + close_maximum(5). Window 1 is
% consumed by reset(); windows 2:21 drive steps 1:20. Gate must start
% inactive (rest scenarios) and become active before window 21
% (close_maximum), without hardcoding the exact activation step.
rawEmg = dataset.evaluationRawEmg(1:21*dataset.windowLengthSamples, :);
testCase.TestData.calibration = calibration;
testCase.TestData.expected = expected;
testCase.TestData.rawEmg = rawEmg;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testDisabledByDefaultLeavesActionsUnchanged(testCase)
[env, cleanup] = makeEnv(testCase, false); %#ok<ASGLU>
reset(env);
action = [0.4; -0.4; 0.4; -0.4];
for stepIdx = 1:19
    step(env, action);
end
testCase.verifyTrue(all(env.motionPermissionLog(1:19)));
testCase.verifyEqual(env.actionWarpLog(1:19, :), env.actionLog(1:19, :));
end

function testEnabledZeroesRequestWhenGateInactive(testCase)
[env, cleanup] = makeEnv(testCase, true); %#ok<ASGLU>
reset(env);
action = [0.6; -0.6; 0.6; -0.6];
for stepIdx = 1:19
    step(env, action);
end
inactive = ~env.motionPermissionLog(1:19);
testCase.verifyTrue(any(inactive), ...
    "Fixture must contain at least one gate-inactive step.");
testCase.verifyEqual(env.actionWarpLog(inactive, :), ...
    zeros(sum(inactive), 4));
testCase.verifyEqual(env.actionSatLog(inactive, :), ...
    zeros(sum(inactive), 4));
testCase.verifyEqual(env.actionPwmLog(inactive, :), ...
    zeros(sum(inactive), 4));
% u_actor_raw is never touched by the gate.
testCase.verifyEqual(env.actionLog(1:19, :), repmat(action', 19, 1));
end

function testEnabledLeavesRequestUnchangedWhenGateActive(testCase)
[env, cleanup] = makeEnv(testCase, true); %#ok<ASGLU>
reset(env);
action = [0.6; -0.6; 0.6; -0.6];
for stepIdx = 1:19
    step(env, action);
end
active = logical(env.motionPermissionLog(1:19));
testCase.verifyTrue(any(active), ...
    "Fixture must contain at least one gate-active step.");
testCase.verifyEqual(env.actionWarpLog(active, :), ...
    env.actionLog(active, :));
end

function testRewardUsesGatedActionNotRawAction(testCase)
% ETAPA 7U training-pipeline audit: trackingIntentActionRateReward.m must
% score the EXECUTED (gated) action, never u_actor_raw - otherwise the
% actor would be penalized/rewarded for magnitudes that never actually
% reached the plant. This is what makes reward causally coherent with what
% the RL toolbox's MATLABSimulator.m records as exp.Reward for the SAME
% experience whose exp.Action is u_actor_raw (verified by inspection of
% rl/+rl/+env/+internal/MATLABSimulator.m: exp.Action is captured from the
% policy's output BEFORE step() runs, so it is never affected by this
% internal gate - only reward/next-observation reflect the gated outcome).
[env, cleanup] = makeEnv(testCase, true); %#ok<ASGLU>
reset(env);
action = [0.9; -0.9; 0.9; -0.9]; % large raw request, well above threshold
for stepIdx = 1:19
    step(env, action);
end
inactive = ~env.motionPermissionLog(1:19);
testCase.verifyTrue(any(inactive), ...
    "Fixture must contain at least one gate-inactive step.");
rewardInfo = env.rewardInfoLog(1:19);
actionL2 = cellfun(@(s) s.actionL2, rewardInfo(inactive));
testCase.verifyEqual(actionL2, zeros(size(actionL2)), ...
    "actionL2 in the reward must be computed on the gated (zero) " + ...
    "action, not on u_actor_raw, whenever permission is inactive.");
end

function testMotionPermissionRequiresIntentState(testCase)
% Base default referenceSource is "glove" (configurables.m); confirm the
% gate cannot be enabled outside the emgIntent line.
setConfigurablesOverride(struct("motionPermissionEnabled", true));
testCase.verifyError(@() configurables(), ...
    "configurables:MotionPermissionRequiresIntentState");
end

function [env, cleanup] = makeEnv(testCase, motionPermissionEnabled)
tempDir = string(tempname);
mkdir(tempDir);
cleanup = onCleanup(@() removeTempDir(tempDir));
profile = buildNoGloveStage3Override(testCase.TestData.calibration, ...
    testCase.TestData.expected, 11);
profile.motionPermissionEnabled = motionPermissionEnabled;
setConfigurablesOverride(profile);
rawEmg = testCase.TestData.rawEmg;
env = Env(tempDir, true, {rawEmg, rawEmg}, {});
end

function removeTempDir(tempDir)
if isfolder(tempDir)
    rmdir(tempDir, "s");
end
end
