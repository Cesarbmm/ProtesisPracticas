function tests = testE3AXInfrastructure
% Infraestructura E3AX: fixtures sinteticos y lectura del smoke ya terminado.
% Ningun setup, fixture o comprobacion de artefactos entrena ni carga datasets.
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
oldPath = path;
t.addTeardown(@() path(oldPath));
addpath(root);
addpath(genpath(fullfile(root, "src")));
addpath(fullfile(root, "config"));
addpath(genpath(fullfile(root, "lib")));
addpath(fullfile(root, "analysis", "paired_reference"));
addpath(fullfile(root, "analysis", "paired_reference", "e3ax"));
t.TestData.matlabRoot = root;
end

function setup(t)
folder = t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
t.TestData.out = string(folder.Folder);
keys = ["configurables_override", "configurables_override_key"];
saved = struct();
for key = keys
    saved.(key) = struct("present", isappdata(0, key), "value", []);
    if saved.(key).present, saved.(key).value = getappdata(0, key); end
end
oldRng = rng;
t.addTeardown(@() rng(oldRng));
t.addTeardown(@() restoreOverrides(saved));
clearConfigurablesOverride();
end

function testLongConfigurationIsFrozen(t)
cfg = e3axConfig("long");
verifyEqual(t, cfg.maxEpisodes, 20000);
verifyEqual(t, cfg.checkpoints, [250 500 1000 2000 5000 10000 15000 20000]);
verifyEqual(t, cfg.evaluationFrequency, 250);
verifyEqual(t, cfg.seed, 20260908);
verifyEqual(t, cfg.maxSteps, 50);
verifyEqual(t, cfg.plots, "training-progress");
verifyEqual(t, cfg.root, t.TestData.matlabRoot);
verifyTrue(t, endsWith(replace(cfg.outputParent, "\", "/"), "results/e3ax_long"));
verifyFalse(t, isfolder(fullfile(t.TestData.out, "results")));
end

function testSmokeBudgetDoesNotAlterLongConfiguration(t)
before = e3axConfig("long");
smoke = e3axConfig("smoke");
after = e3axConfig("long");
verifyEqual(t, smoke.maxEpisodes, 5);
verifyEqual(t, smoke.checkpoints, [2 5]);
verifyEqual(t, smoke.evaluationFrequency, 1);
verifyEqual(t, smoke.seed, before.seed);
verifyEqual(t, smoke.trainSubjects, before.trainSubjects);
verifyEqual(t, smoke.validationSubjects, before.validationSubjects);
verifyEqual(t, before, after);
verifyTrue(t, endsWith(replace(smoke.outputParent, "\", "/"), "results/e3ax_smoke"));
end

function testSplitAndScientificAuthorizationAreExplicit(t)
cfg = e3axConfig;
verifyEqual(t, cfg.trainSubjects, ...
    ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA"]);
verifyEqual(t, cfg.validationSubjects, ["JOE", "JONATHAN", "KHAROL"]);
verifyEmpty(t, intersect(cfg.trainSubjects, cfg.validationSubjects));
allSubjects = [cfg.trainSubjects cfg.validationSubjects];
verifyEqual(t, allSubjects, sort(allSubjects));
verifyEqual(t, numel(unique(allSubjects)), 10);
verifyFalse(t, any(ismember(allSubjects, ["MATEO", "SANDRA"])));
verifyEqual(t, cfg.referenceTransform, "ORIGINAL");
verifyFalse(t, cfg.referenceContractValidated);
verifyTrue(t, cfg.exploratoryTrainingAuthorized);
verifyFalse(t, cfg.hardwareAuthorized);
verifyFalse(t, cfg.fullTrainingResumeAvailable);
end

function testOverridePreservesPlantRewardActionsAndMarkov52(t)
cfg = e3axConfig("smoke");
o = e3axOverride(cfg);
verifyEqual(t, string(o.dataset), cfg.trainSubjects);
verifyEqual(t, o.observationVariant, "markov52");
verifyEqual(t, o.simPlantSource, "patternCurveCanonical");
verifyEqual(t, o.period, .2);
verifyEqual(t, o.actionInterfaceVariant, "baselineQuantized");
verifyEqual(t, o.actionCommandLevels, [0 64 96 128 160 192 224 255]);
verifyEqual(t, o.actionCommandActivationThreshold, .05);
verifyEqual(t, o.speeds, 255 * ones(1, 4));
verifyFalse(t, o.unifyActions);
verifyTrue(t, o.quantizeCommandsForSimulation);
verifyEqual(t, string(o.rewardType), "trackingMseActionRateReward");
verifyEqual(t, o.rewardActionWeight, .01);
verifyEqual(t, o.rewardDeltaActionWeight, .05);
verifyFalse(t, o.td3.useRecurrent);
verifyFalse(t, o.td3Residual.enabled);
verifyTrue(t, o.newTraining && o.usePrerecorded && o.simMotors);
verifyFalse(t, o.connect_glove || o.flagSaveTraining || o.plotEpisodeOnTest);
verifyFalse(t, isappdata(0, "configurables_override"), ...
    "Construir el override no debe instalarlo ni iniciar un entrenamiento.");
end

function testLogEpisodeAcceptsHistoricalStatisticsVector(t)
session = newSession(t);
info = statisticsFixture([1; 3]);
answer = session.logEpisode(info);
verifyFalse(t, answer, "El callback propio no solicita otro guardado automatico.");
verifyEqual(t, session.lastLogged, 3);
T = readtable(fullfile(session.out, "training_incremental.csv"));
verifyEqual(t, height(T), 1);
for field = string(T.Properties.VariableNames)
    verifyEqual(t, T.(field), info.(field)(end), AbsTol=1e-12);
end
verifyEmpty(t, dir(fullfile(session.out, "checkpoints", "TrainingEpisode*.mat")));
end

function testLogEpisodeAppendsOnceAndIgnoresOldNotifications(t)
session = newSession(t);
session.logEpisode(statisticsFixture(1));
session.logEpisode(statisticsFixture([1; 3]));
file = fullfile(session.out, "training_incremental.csv");
before = readBytes(file);
session.logEpisode(statisticsFixture([1; 3]));
session.logEpisode(statisticsFixture([1; 2]));
verifyEqual(t, readBytes(file), before);
T = readtable(file);
verifyEqual(t, T.EpisodeIndex, [1; 3]);
verifyEqual(t, session.lastLogged, 3);
verifyEqual(t, count(string(fileread(file)), "EpisodeIndex"), 1);
end

function testLogEpisodeCheckpointPreservesCompleteHistoricalStruct(t)
session = newSession(t);
info = statisticsFixture([1; 2]);
info.sentinel = struct("source", "fixture", "unlistedValue", [17 23]);
session.logEpisode(info);
file = fullfile(session.out, "checkpoints", "TrainingEpisode000002.mat");
assertTrue(t, isfile(file));
saved = load(file, "trainingStatsAtCheckpoint", "rngState");
verifyEqual(t, saved.trainingStatsAtCheckpoint, info);
verifyTrue(t, all(isfield(saved.rngState, ["Type", "Seed", "State"])));
verifyEqual(t, saved.trainingStatsAtCheckpoint.EpisodeIndex, [1; 2]);
end

function testTrainingStatisticsCheckpointCannotBeOverwritten(t)
session = newSession(t);
file = fullfile(session.out, "checkpoints", "TrainingEpisode000002.mat");
sentinel = uint8([2 3 5 7 11]); %#ok<NASGU>
save(file, "sentinel");
before = readBytes(file);
verifyError(t, @() session.logEpisode(statisticsFixture([1; 2])), "MATLAB:assertion:failed");
verifyEqual(t, readBytes(file), before);
end

function testRecordEvaluationAcceptsItsFirstStruct(t)
session = newSession(t);
verifyEmpty(t, session.records);
result = evaluationFixture("checkpoint_A.mat", -.25, .12);
session.recordEvaluation(result, 2);
verifyEqual(t, numel(session.records), 1);
verifyEqual(t, session.records.episode, 2);
verifyEqual(t, rmfield(session.records, "episode"), result);
T = readtable(fullfile(session.out, "checkpoint_validation.csv"), TextType="string");
verifyEqual(t, height(T), 1);
verifyEqual(t, T.episode, 2);
verifyEqual(t, T.checkpoint, result.checkpoint);
verifyTrue(t, logical(T.actorUnchanged));
end

function testRecordEvaluationKeepsFirstWhenAppendingSecond(t)
session = newSession(t);
first = evaluationFixture("checkpoint_A.mat", -.25, .12);
second = evaluationFixture("checkpoint_B.mat", -.13, .08);
session.recordEvaluation(first, 2);
session.recordEvaluation(second, 5);
verifyEqual(t, numel(session.records), 2);
verifyEqual(t, rmfield(session.records(1), "episode"), first);
verifyEqual(t, rmfield(session.records(2), "episode"), second);
T = readtable(fullfile(session.out, "checkpoint_validation.csv"), TextType="string");
verifyEqual(t, T.episode, [2; 5]);
verifyEqual(t, T.reward, [first.reward; second.reward]);
verifyEqual(t, T.checkpoint, [first.checkpoint; second.checkpoint]);
end

function testNonMilestoneEvaluationDoesNotAccessAgentOrEnvironment(t)
session = newSession(t);
[statistic, scores, evaluationData] = session.evaluate([], [], struct("EpisodeIndex", 3));
verifyEmpty(t, statistic);
verifyEmpty(t, scores);
verifyEmpty(t, evaluationData);
verifyEmpty(t, session.records);
verifyFalse(t, isfolder(fullfile(session.out, "evaluation")));
verifyFalse(t, isfile(fullfile(session.out, "EVALUATION_ERROR.json")));
verifyEmpty(t, dir(fullfile(session.out, "checkpoints", "*.mat")));
end

function testAgentCheckpointIsReloadableWithoutClaimingExactResume(t)
session = newSession(t);
[agent, env] = checkpointFixtures(t);
beforeRng = rng;
file = session.saveCheckpoint(agent, env, 2);
assertTrue(t, isfile(file));
verifyFalse(t, isfile(file + ".writing.mat"));
saved = load(file);
verifyEqual(t, getLearnableParameters(getActor(saved.saved_agent)), getLearnableParameters(getActor(agent)));
verifyEqual(t, getLearnableParameters(saved.saved_actor), getLearnableParameters(getActor(agent)));
verifyEqual(t, saved.cfg, session.cfg);
verifyEqual(t, saved.rngState, beforeRng);
verifyEqual(t, saved.envSchedule.episodeCounter, env.episodeCounter);
verifyEqual(t, saved.envSchedule.repetitionId, env.repetitionId);
verifyEqual(t, saved.envSchedule.episodes_shuffled, env.episodes_shuffled);
verifyEqual(t, saved.envSchedule.q, env.motorData(end, :));
verifyEqual(t, saved.checkpointInfo.episode, 2);
verifyTrue(t, saved.checkpointInfo.agentCheckpointAvailable);
verifyFalse(t, saved.checkpointInfo.fullTrainingResumeAvailable);
verifyEqual(t, saved.checkpointInfo.infoToSave, agent.AgentOptions.InfoToSave);
sidecar = jsondecode(fileread(file + ".json"));
verifyTrue(t, sidecar.agentCheckpointAvailable);
verifyFalse(t, sidecar.fullTrainingResumeAvailable);
verifyEqual(t, sidecar.episode, 2);
end

function testExistingAgentCheckpointRejectsBeforeAccessingAgent(t)
session = newSession(t);
file = fullfile(session.out, "checkpoints", "AgentEpisode000002.mat");
sentinel = "checkpoint previo inmutable"; %#ok<NASGU>
save(file, "sentinel");
before = readBytes(file);
verifyError(t, @() session.saveCheckpoint([], [], 2), "E3AX:CheckpointExists");
verifyEqual(t, readBytes(file), before);
verifyFalse(t, isfile(file + ".writing.mat"));
verifyFalse(t, isfile(file + ".json"));
end

function testHeadlessGuardStopsBeforeAnyTrainingSideEffect(t)
source = string(fileread(fullfile(t.TestData.matlabRoot, "runE3AXLongTraining.m")));
guard = strfind(source, "assert(usejava('desktop') && usejava('awt')");
assertEqual(t, numel(guard), 1, "El guard debe existir antes de considerar invocar el runner.");
for operation = ["cd(root)", "mkdir(out)", "e3axLoadData(cfg,out)", "train(agent,env,opts"]
    position = strfind(source, operation);
    assertNotEmpty(t, position);
    verifyLessThan(t, guard, position(1));
end
if ~(usejava('desktop') && usejava('awt'))
    % Esta rama se ejecuta solo si la condicion auditada garantiza el rechazo.
    % En MATLAB Desktop jamas se llama al runner desde este test.
    oldDir = pwd;
    oldRng = rng;
    oldPath = path;
    verifyError(t, @() runE3AXLongTraining(mode="smoke"), "E3AX:DesktopRequired");
    verifyEqual(t, pwd, oldDir);
    verifyEqual(t, rng, oldRng);
    verifyEqual(t, path, oldPath);
end
end

function testCompletedSmokeDemonstratesLearningAndExplicitLimitations(t)
out = smokeRoot(t);
S = readJSON(fullfile(out, "summary.json"));
verifyEqual(t, string(S.mode), "smoke");
verifyEqual(t, S.requestedEpisodes, 5);
verifyEqual(t, S.completedEpisodes, 5);
verifyTrue(t, S.desktop && S.trainingStatsSaved);
verifyEqual(t, string(S.plots), "training-progress");
verifyTrue(t, S.learning.actorChanged && all(S.learning.criticsChanged));
verifyTrue(t, S.agentCheckpointAvailable);
verifyFalse(t, S.fullTrainingResumeAvailable || S.referenceContractValidated || S.hardwareAuthorized);
verifyTrue(t, S.exploratoryTrainingAuthorized && S.MATEO_SANDRA_SEALED);
verifyFalse(t, S.PUSH);
verifyTrue(t, isfile(fullfile(out, "COMPLETED.txt")));
verifyFalse(t, isfile(fullfile(out, "FAILED.txt")));
end

function testSmokeCheckpointsAndTrainingExportsAreComplete(t)
out = smokeRoot(t);
for episode = [2 5]
    file = fullfile(out, "checkpoints", compose("AgentEpisode%06d.mat", episode));
    assertTrue(t, isfile(file));
    variables = string(who("-file", file));
    verifyTrue(t, all(ismember(["saved_agent", "saved_actor", "cfg", "rngState", "envSchedule", "checkpointInfo"], variables)));
    saved = load(file, "checkpointInfo");
    verifyEqual(t, saved.checkpointInfo.episode, episode);
    verifyTrue(t, saved.checkpointInfo.agentCheckpointAvailable);
    verifyFalse(t, saved.checkpointInfo.fullTrainingResumeAvailable);
    for field = ["ExperienceBuffer", "Optimizer", "PolicyState", "Target"]
        verifyTrue(t, logical(saved.checkpointInfo.infoToSave.(field)));
    end
    verifyFalse(t, isfile(file + ".writing.mat"));
    snapshot = load(fullfile(out, "checkpoints", compose("TrainingEpisode%06d.mat", episode)), ...
        "trainingStatsAtCheckpoint");
    verifyEqual(t, snapshot.trainingStatsAtCheckpoint.EpisodeIndex(end), episode);
end
T = readtable(fullfile(out, "training_incremental.csv"));
verifyEqual(t, T.EpisodeIndex, (1:5)');
statsCSV = readtable(fullfile(out, "trainingStats.csv"));
verifyEqual(t, statsCSV.EpisodeIndex, T.EpisodeIndex);
saved = load(fullfile(out, "trainingStats.mat"), "trainingStats");
verifyEqual(t, saved.trainingStats.EpisodeIndex(:), T.EpisodeIndex);
verifyEqual(t, saved.trainingStats.EpisodeReward(:), T.EpisodeReward, AbsTol=1e-12);
for extension = ["fig", "png", "pdf", "svg"]
    assertNonemptyFile(t, fullfile(out, "training_progress." + extension));
end
end

function testSmokeValidationSelectionUsesOnlyFrozenSubjectsAndScores(t)
out = smokeRoot(t);
cfg = e3axConfig("smoke");
selection = readtable(fullfile(out, "evaluation_selection.csv"), TextType="string");
verifyEqual(t, height(selection), 4);
verifyEqual(t, sort(selection.subject(selection.split == "TRAIN")), repmat(cfg.trainSubjects(1), 2, 1));
verifyEqual(t, sort(selection.subject(selection.split == "VALIDATION")), repmat(cfg.validationSubjects(1), 2, 1));
for split = ["TRAIN", "VALIDATION"]
    verifyEqual(t, sort(selection.side(selection.split == split)), [1; 2]);
end
R = readtable(fullfile(out, "checkpoint_validation.csv"), TextType="string", Delimiter=",", VariableNamingRule="preserve");
verifyEqual(t, R.episode, [2; 5]);
verifyTrue(t, all(logical(R.actorUnchanged)));
verifyEqual(t, R.episodes, [2; 2]);
verifyTrue(t, all(R.runtimeTermination == "EMG_ONLY"));
ranked = sortrows(R, ["reward", "mse", "episode"], ["descend", "ascend", "ascend"]);
F = readJSON(fullfile(out, "evaluation", "final_summary.json"));
verifyEqual(t, F.bestEpisode, ranked.episode(1));
verifyEqual(t, string(F.bestCheckpoint), ranked.checkpoint(1));
verifyEqual(t, F.lastEpisode, 5);
verifyTrue(t, F.completedRequestedEpisodes);
end

function testSmokeSixPoliciesAndEveryEpisodeFigure(t)
out = smokeRoot(t);
expected = ["ZERO", "Agent7250", "P2", "Oracle_H5", "BEST_TD3", "LAST_TD3"];
for split = ["ALL", "TRAIN", "VALIDATION"]
    folder = fullfile(out, "evaluation", "comparison", split);
    M = readtable(fullfile(folder, "metrics.csv"), TextType="string");
    verifyEqual(t, sort(M.controller), sort(expected(:)));
    verifyEqual(t, height(M), 6);
    verifyTrue(t, all(ismember(["trackingMSE", "rewardMean", "actionL2", ...
        "deltaActionL2", "saturationFraction", "persistentTwoCycle", "m3Reversals"], ...
        string(M.Properties.VariableNames))));
    for extension = ["fig", "png", "pdf", "svg"]
        assertNonemptyFile(t, fullfile(folder, "policy_comparison." + extension));
    end
end
selection = readtable(fullfile(out, "evaluation_selection.csv"), TextType="string");
directions = ["closing", "opening"];
for checkpoint = ["best_checkpoint", "last_checkpoint"]
    folder = fullfile(out, "evaluation", checkpoint);
    result = readJSON(fullfile(folder, "summary.json"));
    verifyEqual(t, result.episodes, 4);
    verifyTrue(t, result.actorUnchanged);
    verifyEqual(t, string(result.runtimeTermination), "EMG_ONLY");
    for row = 1:height(selection)
        stem = selection.subject(row) + compose("_row%04d_", selection.row(row)) + directions(selection.side(row));
        for extension = ["fig", "png"]
            assertNonemptyFile(t, fullfile(folder, "figures", selection.split(row), stem + "." + extension));
        end
    end
end
end

function session = newSession(t)
mkdir(fullfile(t.TestData.out, "checkpoints"));
session = E3AXSession(e3axConfig("smoke"), t.TestData.out, struct());
end

function info = statisticsFixture(episodes)
episodes = episodes(:);
info = struct("EpisodeIndex", episodes, "EpisodeReward", -.1 * episodes, ...
    "AverageReward", -.2 * episodes, "EpisodeSteps", 20 + episodes, ...
    "AverageSteps", 20 + episodes / 2, "EpisodeQ0", -.3 * episodes, ...
    "TotalAgentSteps", 25 * episodes);
end

function result = evaluationFixture(checkpoint, reward, mse)
result = struct("checkpoint", checkpoint, "label", "TD3_fixture", ...
    "reward", reward, "mse", mse, "episodes", 2, "output", "fixture_output", ...
    "actorUnchanged", true, "runtimeTermination", "EMG_ONLY", "commonHorizonTeacherMetrics", true);
end

function [agent, env] = checkpointFixtures(t)
source = load(fullfile(smokeRoot(t), "checkpoints", "AgentEpisode000002.mat"), "saved_agent");
agent = source.saved_agent;
env = struct("episodeCounter", 2, "repetitionId", 17, "episodes_shuffled", [3 1 2], ...
    "episodeType", "TRAIN", "motorData", [0 0 0 0; 100 200 300 400]);
end

function out = smokeRoot(t)
pointer = fullfile(t.TestData.matlabRoot, "analysis", "paired_reference", ...
    "e3ax_preparation", "smoke_path.txt");
assertTrue(t, isfile(pointer), "Falta smoke_path.txt del smoke5 exitoso; los tests no entrenan para generarlo.");
out = erase(strtrim(string(fileread(pointer))), char(65279));
assertTrue(t, isscalar(out) && strlength(out) > 0 && isfolder(out));
normalized = replace(lower(out), "\", "/");
assertTrue(t, contains(normalized, "/results/e3ax_smoke/"));
assertFalse(t, contains(normalized, "e3ax_long"));
end

function data = readJSON(file)
data = jsondecode(fileread(file));
end

function assertNonemptyFile(t, file)
assertTrue(t, isfile(file), "Falta artefacto: " + file);
item = dir(file);
verifyGreaterThan(t, item.bytes, 0);
end

function bytes = readBytes(file)
fid = fopen(file, "rb");
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, "*uint8");
end

function restoreOverrides(saved)
clearConfigurablesOverride();
for key = string(fieldnames(saved))'
    if saved.(key).present, setappdata(0, key, saved.(key).value); end
end
clear configurables
end
