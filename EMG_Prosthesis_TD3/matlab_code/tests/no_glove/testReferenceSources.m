function tests = testReferenceSources
%testReferenceSources deterministic ETAPA 1 tests (simulation only).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
testCase.TestData.matlabRoot = matlabRoot;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testDefaultAndInvalidReferenceSource(testCase)
clearConfigurablesOverride();
testCase.verifyEqual(configurables("referenceSource"), "glove");

setConfigurablesOverride(struct("referenceSource", "invalid"));
testCase.verifyError(@() configurables(), ...
    "configurables:InvalidReferenceSource");
end

function testEmgOnlyDatasetDoesNotRequireGloves(testCase)
tempDir = string(tempname);
mkdir(tempDir);
cleanup = onCleanup(@() removeTempDir(tempDir));

emgs = buildSyntheticEmgSet();
metadata = struct("user", "synthetic", "session", "stage1");
save(fullfile(tempDir, "emg_only.mat"), "emgs", "metadata");

[loadedEmg, loadedGlove, loadedMetadata] = getDataset( ...
    "emg_only", tempDir, "emgIntent");
testCase.verifyEqual(loadedEmg, emgs);
testCase.verifyEmpty(loadedGlove);
testCase.verifyEqual(loadedMetadata.emg_only, metadata);
testCase.verifyError(@() getDataset("emg_only", tempDir, "glove"), ...
    "getDataset:MissingGloves");
end

function testRewardInfoContract(testCase)
context = struct( ...
    "effectiveAction", [1, 0, -0.5, 0.25], ...
    "previousEffectiveAction", [0, 0, -0.25, 0.25], ...
    "trackingError", [0.1, -0.2, 0.3, -0.4], ...
    "referenceSource", "emgIntent");
inputInfo = struct("trackingMse", 123, "extraDiagnostic", 7);

rewardInfo = normalizeRewardInfo(inputInfo, context);
expectedFields = { ...
    'trackingMse', 'trackingMae', 'actionL2', 'progressTerm', ...
    'smoothnessPenalty', 'deltaActionL2', 'saturationFraction', ...
    'saturationPenalty', 'referenceSource', 'schemaVersion'};
testCase.verifyTrue(all(isfield(rewardInfo, expectedFields)));
testCase.verifyEqual(rewardInfo.trackingMse, 123);
testCase.verifyEqual(rewardInfo.trackingMae, 0.25, "AbsTol", 1e-12);
testCase.verifyEqual(rewardInfo.actionL2, mean(context.effectiveAction.^2), ...
    "AbsTol", 1e-12);
testCase.verifyEqual(rewardInfo.extraDiagnostic, 7);
testCase.verifyEqual(rewardInfo.referenceSource, "emgIntent");
testCase.verifyEqual(rewardInfo.schemaVersion, 1);

invalidContext = context;
invalidContext.trackingError(1) = NaN;
testCase.verifyError(@() normalizeRewardInfo(struct(), invalidContext), ...
    "normalizeRewardInfo:InvalidContextVector");

invalidInfo = struct("referenceSource", ["glove", "emgIntent"]);
testCase.verifyError(@() normalizeRewardInfo(invalidInfo, context), ...
    "normalizeRewardInfo:InvalidReferenceSource");

[reward, rewardVector] = normalizeRewardOutputs(-1, (1:4)', 4);
testCase.verifyEqual(reward, -1);
testCase.verifyEqual(rewardVector, 1:4);
testCase.verifyError(@() normalizeRewardOutputs(NaN, zeros(1, 4), 4), ...
    "normalizeRewardOutputs:InvalidReward");
testCase.verifyError(@() normalizeRewardOutputs(-1, [0, Inf, 0, 0], 4), ...
    "normalizeRewardOutputs:InvalidRewardVector");
testCase.verifyError(@() normalizeRewardOutputs(-1, [0, 0, 0], 4), ...
    "normalizeRewardOutputs:InvalidRewardVector");
testCase.verifyError(@() normalizeRewardOutputs(-1, [0, 0, 0, 1i], 4), ...
    "normalizeRewardOutputs:InvalidRewardVector");
end

function testStage1RejectsLiveMyoAndPhysicalMotors(testCase)
profile = buildNoGloveStage1Override(11);
setConfigurablesOverride(profile);
testCase.verifyError(@() Env("", false), ...
    "Env:EmgIntentRequiresPrerecorded");

profile.simMotors = false;
setConfigurablesOverride(profile);
emgSet = buildSyntheticEmgSet();
testCase.verifyError(@() Env("", true, emgSet, {}), ...
    "Env:EmgIntentRequiresSimulation");
end

function testSimulationOptionsOverrideIsHonored(testCase)
profile = buildNoGloveStage1Override(11);
profile.simOpts = rlSimulationOptions( ...
    "MaxSteps", 7, ...
    "NumSimulations", 2, ...
    "StopOnError", "on", ...
    "UseParallel", false);
setConfigurablesOverride(profile);
configs = configurables();
testCase.verifyEqual(configs.simOpts.MaxSteps, 7);
testCase.verifyEqual(configs.simOpts.NumSimulations, 2);
end

function testGloveAndEmgIntentEpisodesInSameSession(testCase)
rng(11, "twister");
emgSet = buildSyntheticEmgSet();
gloveSet = buildSyntheticGloveSet();
tempDir = string(tempname);
mkdir(tempDir);
cleanup = onCleanup(@() removeTempDir(tempDir));

gloveProfile = buildNoGloveStage1Override(11);
gloveProfile.referenceSource = "glove";
% Deliberately load a different glove reward first. emgIntent must still
% resolve its own per-instance callback after the override changes.
gloveProfile.rewardType = "trackingMseActionReward";
setConfigurablesOverride(gloveProfile);
gloveEnv = Env(tempDir, true, emgSet, gloveSet);
testCase.verifyEqual(gloveEnv.referenceSource, "glove");
testCase.verifyTrue(gloveEnv.simMotors);
testCase.verifyTrue(isa(gloveEnv.prosthesis, "SimController"));
testCase.verifyTrue(isa(gloveEnv.glove, "RecordedGlove"));
[gloveSteps, gloveRewards, gloveObservation] = runZeroActionEpisode(gloveEnv);
testCase.verifyGreaterThan(gloveSteps, 0);
testCase.verifyTrue(all(isfinite(gloveRewards)));
testCase.verifyTrue(all(isfinite(gloveObservation), "all"));
testCase.verifyEqual(gloveEnv.referenceHistoryCount, gloveSteps);
testCase.verifyFalse(isempty(gloveEnv.flexConvertedLog{1}));
testCase.verifyEqual(size(gloveEnv.flexConvertedLog{1}, 1), 2);
testCase.verifyEqual(gloveEnv.referenceHistory(1, :), ...
    gloveEnv.flexConvertedLog{1}(end, :), "AbsTol", 1e-12);
testCase.verifyTrue(all(cellfun(@(x) ...
    isstruct(x) && x.referenceSource == "glove" && x.schemaVersion == 1, ...
    gloveEnv.rewardInfoLog(1:gloveSteps))));

intentProfile = buildNoGloveStage1Override(11);
setConfigurablesOverride(intentProfile);
intentEnv = Env(tempDir, true, emgSet, {});
testCase.verifyEqual(intentEnv.referenceSource, "emgIntent");
testCase.verifyTrue(intentEnv.simMotors);
testCase.verifyTrue(isa(intentEnv.prosthesis, "SimController"));
testCase.verifyTrue(isa(intentEnv.myo, "RecordedMyo"));
testCase.verifyEmpty(intentEnv.gloveSet);

initialObservation = reset(intentEnv);
initialTarget = intentEnv.intentTarget;
testCase.verifyTrue(all(isfinite(initialObservation), "all"));
testCase.verifyEqual(intentEnv.intentVelocity, zeros(4, 1));
testCase.verifyEqual(intentEnv.referenceTarget, initialTarget, "AbsTol", 1e-12);
[intentSteps, intentRewards, finalObservation] = ...
    continueZeroActionEpisode(intentEnv);

testCase.verifyGreaterThan(intentSteps, 0);
testCase.verifyTrue(intentEnv.isDone);
testCase.verifyTrue(intentEnv.myo.exhausted);
testCase.verifyTrue(all(isfinite(intentRewards)));
testCase.verifyTrue(all(isfinite(finalObservation), "all"));
testCase.verifyEqual(intentEnv.referenceHistoryCount, intentSteps);
expectedHistory = repmat(initialTarget(:)', intentSteps, 1);
testCase.verifyEqual(intentEnv.referenceHistory(1:intentSteps, :), ...
    expectedHistory, "AbsTol", 1e-12);
testCase.verifyEqual(intentEnv.intentVelocity, zeros(4, 1));
testCase.verifyEqual(intentEnv.actionPwmLog(1:intentSteps, :), ...
    zeros(intentSteps, 4));
testCase.verifyTrue(all(cellfun(@isempty, ...
    intentEnv.flexConvertedLog(1:intentSteps))));
testCase.verifyTrue(all(cellfun(@(x) ...
    isstruct(x) && x.referenceSource == "emgIntent" && x.schemaVersion == 1, ...
    intentEnv.rewardInfoLog(1:intentSteps))));

intentEnv.saveEpisode();
episodePath = fullfile(tempDir, "episode00001.mat");
testCase.verifyTrue(isfile(episodePath));
saved = load(episodePath, ...
    "referenceSource", "referenceHistory", "referenceHistoryCount", ...
    "trackingPredictionHistory", "intentTarget", "intentVelocity", ...
    "rewardInfoLog", "rewardInfoSchemaVersion", "flexConvertedLog");
testCase.verifyEqual(saved.referenceSource, "emgIntent");
testCase.verifyEqual(saved.referenceHistoryCount, intentSteps);
testCase.verifyEqual(saved.referenceHistory, expectedHistory, "AbsTol", 1e-12);
testCase.verifyEqual(saved.rewardInfoSchemaVersion, 1);
testCase.verifyTrue(all(cellfun(@isempty, saved.flexConvertedLog)));

summary = summarizeEpisodeDirectory(tempDir);
testCase.verifyEqual(summary.numEpisodes, 1);
testCase.verifyEqual(summary.referenceSource, "emgIntent");

mixedEpisode = load(episodePath);
mixedEpisode.referenceSource = "glove";
for i = 1:numel(mixedEpisode.rewardInfoLog)
    if ~isempty(mixedEpisode.rewardInfoLog{i})
        mixedEpisode.rewardInfoLog{i}.referenceSource = "glove";
    end
end
save(fullfile(tempDir, "episode00002.mat"), "-struct", "mixedEpisode");
testCase.verifyError(@() summarizeEpisodeDirectory(tempDir), ...
    "summarizeEpisodeDirectory:MixedReferenceSources");

malformedDir = fullfile(tempDir, "malformed");
mkdir(malformedDir);
malformedEpisode = load(episodePath);
malformedEpisode = rmfield(malformedEpisode, "referenceHistory");
save(fullfile(malformedDir, "episode00001.mat"), ...
    "-struct", "malformedEpisode");
testCase.verifyError(@() summarizeEpisodeDirectory(malformedDir), ...
    "summarizeEpisodeDirectory:IncompleteEmgIntentSchema");
end

function [steps, rewards, observation] = runZeroActionEpisode(env)
reset(env);
[steps, rewards, observation] = continueZeroActionEpisode(env);
end

function [steps, rewards, observation] = continueZeroActionEpisode(env)
steps = 0;
rewards = nan(50, 1);
observation = env.State;
isDone = false;
while ~isDone && steps < 50
    steps = steps + 1;
    [observation, rewards(steps), isDone] = step(env, zeros(4, 1));
end
rewards = rewards(1:steps);
if ~isDone
    error("testReferenceSources:EpisodeDidNotFinish", ...
        "Synthetic episode did not finish within 50 steps.");
end
end

function emgSet = buildSyntheticEmgSet()
t = (0:239)';
channels = 0:7;
closing = 40 * sin(0.07 * t + 0.31 * channels) + ...
    8 * cos(0.013 * t .* (channels + 1));
opening = 35 * cos(0.05 * t + 0.23 * channels) - ...
    6 * sin(0.017 * t .* (channels + 1));
emgSet = {closing, opening};
end

function gloveSet = buildSyntheticGloveSet()
template = struct( ...
    "thumb", 1000, ...
    "indexUp", 500, ...
    "indexDown", 450, ...
    "middleUp", 480, ...
    "middleDown", 430, ...
    "ringUp", 400, ...
    "ringDown", 350, ...
    "pinkyUp", 420, ...
    "pinkyDown", 370, ...
    "switchIndexMiddle", 0, ...
    "dipSwitch", 0, ...
    "yaw", 0, ...
    "pitch", 0, ...
    "roll", 0);
closing = repmat(template, 30, 1);
opening = repmat(template, 30, 1);
for i = 1:30
    closing(i).thumb = template.thumb + i;
    opening(i).thumb = template.thumb + 30 - i;
end
gloveSet = {closing, opening};
end

function removeTempDir(tempDir)
if isfolder(tempDir)
    rmdir(tempDir, "s");
end
end
