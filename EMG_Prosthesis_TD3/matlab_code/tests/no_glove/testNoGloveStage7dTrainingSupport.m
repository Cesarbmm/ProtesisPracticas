function tests = testNoGloveStage7dTrainingSupport
%testNoGloveStage7dTrainingSupport deterministic ETAPA 7D tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
[query, training, actuator, biasAudit] = makeFixture();
testCase.TestData.query = query;
testCase.TestData.training = training;
testCase.TestData.actuator = actuator;
testCase.TestData.biasAudit = biasAudit;
end

function testTrainingRestCommandsClassification(testCase)
query = testCase.TestData.query;
query.rawAction = commandActor(query.state);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @commandActor, @commandActor, @zeroActor, ...
    testCase.TestData.biasAudit, testCase.TestData.actuator);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "trainingRestAlsoCommands");
testCase.verifyTrue(analysis.sourceDecision.trainingRestAlsoCommands);
testCase.verifyEqual(analysis.replayMaximumAbsoluteError, 0);
testCase.verifyEqual(analysis.trainingEpisodeCount, 4);
testCase.verifyEqual(analysis.trainingEligibleStateCount, 24);
testCase.verifyFalse(analysis.rootCauseIdentified);
testCase.verifyFalse(analysis.hybridStateCreated);
testCase.verifyFalse(analysis.runTraining);
testCase.verifyFalse(analysis.envCreated);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.rewardInvoked);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testOutOfTrainingSupportClassification(testCase)
query = testCase.TestData.query;
query.state(:, 1) = query.state(:, 1)+100;
query.rawAction = zeroActor(query.state);
quietBias = testCase.TestData.biasAudit;
quietBias.zeroInputOriginalAction = zeros(1, 4);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @zeroActor, @zeroActor, @zeroActor, ...
    quietBias, testCase.TestData.actuator);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "restStateOutOfTrainingSupport");
testCase.verifyTrue(analysis.sourceDecision.restStateOutOfTrainingSupport);
testCase.verifyLessThan(analysis.sourceDecision.emgSupportFraction, 0.75);
end

function testActorBiasContributionClassification(testCase)
training = testCase.TestData.training;
% Keep every recorded training state on or below the sharp response edge.
training.state(:, 1) = min(training.state(:, 1), 0.30);
query = testCase.TestData.query;
query.state(:, 1) = 0.35;
query.rawAction = edgeActor(query.state);
biasAudit = testCase.TestData.biasAudit;
biasAudit.zeroInputOriginalAction = 0.2*ones(1, 4);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, training, @edgeActor, @edgeActor, @zeroActor, biasAudit, ...
    testCase.TestData.actuator, minimumSupportFraction=0.25);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "actorBiasContribution");
testCase.verifyTrue(analysis.sourceDecision.actorBiasContribution);
testCase.verifyFalse(analysis.sourceDecision.trainingRestAlsoCommands);
end

function testCauseStillUnresolvedClassification(testCase)
query = testCase.TestData.query;
query.rawAction = zeroActor(query.state);
biasAudit = testCase.TestData.biasAudit;
biasAudit.zeroInputOriginalAction = zeros(1, 4);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @zeroActor, @zeroActor, @zeroActor, ...
    biasAudit, testCase.TestData.actuator);
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "causeStillUnresolved");
end

function testInvariantReferenceVelocityExcluded(testCase)
query = testCase.TestData.query;
query.rawAction = commandActor(query.state);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @commandActor, @commandActor, @zeroActor, ...
    testCase.TestData.biasAudit, testCase.TestData.actuator);
vref = analysis.blockSupport( ...
    analysis.blockSupport.block == "referenceVelocity", :);
testCase.verifyEqual(vref.variableDimensionCount, 0);
testCase.verifyEqual(vref.classification, "invariantNoDistance");
testCase.verifyTrue(all(analysis.featureScaleTable.scaleSource(57:60) == ...
    "invariantExcluded"));
end

function testNearestStatesAreRecordedRows(testCase)
query = testCase.TestData.query;
query.rawAction = commandActor(query.state);
analysis = analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @commandActor, @commandActor, @zeroActor, ...
    testCase.TestData.biasAudit, testCase.TestData.actuator);
testCase.verifyTrue(all(analysis.jointNearest.trainingRow >= 1));
testCase.verifyTrue(all(analysis.jointNearest.trainingRow <= ...
    size(testCase.TestData.training.state, 1)));
testCase.verifyEqual(height(analysis.nearestActionTable), ...
    4*size(query.state, 1));
testCase.verifyFalse(analysis.zeroInputProbe.interpretedAsPhysicalEmgAmplitude);
testCase.verifyTrue(analysis.zeroInputProbe.declaredOodProbe);
end

function testReplayMismatchFailsClosed(testCase)
query = testCase.TestData.query;
query.rawAction = commandActor(query.state);
query.rawAction(1, 1) = query.rawAction(1, 1)+0.01;
testCase.verifyError(@() analyzeNoGloveStage7dTrainingSupport( ...
    query, testCase.TestData.training, @commandActor, @commandActor, @zeroActor, ...
    testCase.TestData.biasAudit, testCase.TestData.actuator), ...
    "analyzeNoGloveStage7dTrainingSupport:ReplayMismatch");
end

function testNonholdTrainingStateFailsClosed(testCase)
query = testCase.TestData.query;
query.rawAction = commandActor(query.state);
training = testCase.TestData.training;
training.state(1, 57) = 0.01;
testCase.verifyError(@() analyzeNoGloveStage7dTrainingSupport( ...
    query, training, @commandActor, @commandActor, @zeroActor, ...
    testCase.TestData.biasAudit, testCase.TestData.actuator), ...
    "analyzeNoGloveStage7dTrainingSupport:NonholdTrainingState");
end

function [query, training, actuator, biasAudit] = makeFixture()
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
episodeCount = 4;
rowsPerEpisode = 6;
state = zeros(episodeCount*rowsPerEpisode, layout.totalLength);
episode = zeros(size(state, 1), 1);
step = zeros(size(state, 1), 1);
phase = strings(size(state, 1), 1);
cursor = 0;
for episodeId = 1:episodeCount
    for localStep = 1:rowsPerEpisode
        cursor = cursor+1;
        episode(cursor) = episodeId;
        step(cursor) = localStep+1;
        phase(cursor) = "preActivationHold";
        if localStep > rowsPerEpisode/2
            phase(cursor) = "postActivationHold";
        end
        state(cursor, layout.emg) = ...
            0.05*episodeId+0.01*localStep+(0:39)*1e-3;
        state(cursor, layout.encoder) = ...
            0.02*episodeId+0.001*localStep+(0:3)*1e-3;
        state(cursor, layout.deltaEncoder) = ...
            1e-3*localStep*(1:4);
        state(cursor, layout.previousEffectiveAction) = ...
            0.01*episodeId*(1:4);
        state(cursor, layout.referencePosition) = ...
            0.1*episodeId*ones(1, 4);
    end
end
training = struct("state", state, "episode", episode, "step", step, ...
    "previousReferencePosition", state(:, layout.referencePosition), ...
    "phase", phase);
queryRows = [1, 8, 15, 22];
query = struct("state", state(queryRows, :), ...
    "rawAction", zeros(numel(queryRows), 4), ...
    "episode", (1:numel(queryRows))', "step", ones(numel(queryRows), 1));
actuator = struct("maxPwm", 255, "activationThreshold", 0.05, ...
    "commandLevels", [0 64 96 128 160 192 224 255]);
biasAudit = struct( ...
    "parameterTable", table(["fc1"; "fc2"; "action"], ...
        [64; 64; 4], [0.1; 0.2; 0.3], ...
        'VariableNames', ["layer", "parameterCount", "l2Norm"]), ...
    "zeroInputOriginalAction", 0.2*ones(1, 4), ...
    "zeroInputBiaslessAction", zeros(1, 4));
end

function action = commandActor(state)
action = 0.2*ones(size(state, 1), 4);
end

function action = zeroActor(state)
action = zeros(size(state, 1), 4);
end

function action = edgeActor(state)
value = max(0, 10*(state(:, 1)-0.30));
action = repmat(value, 1, 4);
end
