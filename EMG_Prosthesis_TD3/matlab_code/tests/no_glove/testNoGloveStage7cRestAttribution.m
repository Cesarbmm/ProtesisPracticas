function tests = testNoGloveStage7cRestAttribution
%testNoGloveStage7cRestAttribution deterministic ETAPA 7C tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
[episodes, protocol, matchedP, controller, actuator] = makeFixture();
testCase.TestData.episodes = episodes;
testCase.TestData.protocol = protocol;
testCase.TestData.matchedP = matchedP;
testCase.TestData.controller = controller;
testCase.TestData.actuator = actuator;
end

function testReplayAnchorsAndControls(testCase)
analysis = analyzeFixture(testCase);
testCase.verifyEqual(analysis.replayMaximumAbsoluteError, 0);
testCase.verifyEqual(analysis.sourceDecision.restCommandActiveFraction, 1);
testCase.verifyEqual(analysis.sourceDecision.initialCommandActiveFraction, 1);
testCase.verifyEqual(analysis.sourceDecision.homeAnchorEpisodeCount, 2);
testCase.verifyTrue( ...
    analysis.sourceDecision.commandAtObservedEmgOnlyStateConfirmed);
testCase.verifyFalse(analysis.sourceDecision.rootCauseIdentified);
testCase.verifyFalse(analysis.behavioralInterventionExecuted);
testCase.verifyFalse(analysis.runTraining);
testCase.verifyFalse(analysis.agent7250Loaded);
testCase.verifyFalse(analysis.envCreated);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.hardwareUsed);

aggregate = analysis.controlSummary(analysis.controlSummary.motor == 0, :);
actor = aggregate(aggregate.commandSource == "Agent200Observed", :);
zero = aggregate(aggregate.commandSource == "zeroAction", :);
matched = aggregate( ...
    aggregate.commandSource == "conventionalPMatchedTrajectory", :);
testCase.verifyEqual(actor.commandActiveFraction, 1);
testCase.verifyEqual(zero.commandActiveFraction, 0);
testCase.verifyEqual(matched.commandActiveFraction, 0);
end

function testLocalSensitivityAndInvariantReferenceBlocks(testCase)
analysis = analyzeFixture(testCase);
emg = analysis.blockDecision( ...
    analysis.blockDecision.block == "emgFeatures", :);
encoder = analysis.blockDecision( ...
    analysis.blockDecision.block == "encoder", :);
previous = analysis.blockDecision( ...
    analysis.blockDecision.block == "previousEffectiveAction", :);
qReference = analysis.blockDecision( ...
    analysis.blockDecision.block == "referencePosition", :);
vReference = analysis.blockDecision( ...
    analysis.blockDecision.block == "referenceVelocity", :);
testCase.verifyEqual(emg.classification, "localSensitivityObserved");
testCase.verifyEqual(encoder.classification, "localSensitivityObserved");
testCase.verifyEqual(previous.classification, "localSensitivityObserved");
testCase.verifyEqual(qReference.classification, ...
    "invariantDuringPreRest");
testCase.verifyEqual(vReference.classification, ...
    "invariantDuringPreRest");
testCase.verifyEqual(analysis.sourceDecision.classification, ...
    "restEmgPathSensitivityObservedBiasUnresolved");
end

function testDonorsStayWithinEpisodeAndObservedFeatureBounds(testCase)
analysis = analyzeFixture(testCase);
identified = analysis.interventionTable( ...
    analysis.interventionTable.identifiable, :);
testCase.verifyNotEmpty(identified);
testCase.verifyEqual(identified.donorEpisode, identified.episode);
testCase.verifyNotEqual(identified.donorStep, identified.recipientStep);
testCase.verifyTrue(all(identified.hybridWithinObservedFeatureBounds));
testCase.verifyTrue(all(identified.locallyMatched));
testCase.verifyEqual(analysis.blockSwapContract, ...
    "sameEpisodeNearestComplementObservedBlock");
end

function testPartialVariationCannotClaimLocalSensitivity(testCase)
episodes = testCase.TestData.episodes;
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
for episodeIdx = 3:4
    qReference = episodes(episodeIdx).stateLog(1, ...
        layout.referencePosition);
    episodes(episodeIdx).stateLog(:, layout.encoder) = ...
        repmat(qReference, size(episodes(episodeIdx).stateLog, 1), 1);
    episodes(episodeIdx).stateLog(:, layout.deltaEncoder) = 0;
    episodes(episodeIdx) = rebuildActions( ...
        episodes(episodeIdx), testCase.TestData.actuator, layout);
end
analysis = runAnalysis(episodes, testCase);
encoder = analysis.blockDecision( ...
    analysis.blockDecision.block == "encoder", :);
testCase.verifyEqual(encoder.classification, "identifiabilityLimited");
testCase.verifyEqual(encoder.locallySensitiveMotorCount, 0);
testCase.verifyGreaterThan( ...
    encoder.insufficientIdentifiabilityMotorCount, 0);
end

function testActorReplayMismatchFailsClosed(testCase)
episodes = testCase.TestData.episodes;
episodes(1).rawAction(8, 1) = episodes(1).rawAction(8, 1) + 0.01;
testCase.verifyError(@() runAnalysis(episodes, testCase), ...
    "analyzeNoGloveStage7cRestCommands:ReplayMismatch");
end

function testNonrestReferenceFailsClosed(testCase)
episodes = testCase.TestData.episodes;
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
episodes(1).stateLog(3, layout.referenceVelocity(1)) = 0.01;
testCase.verifyError(@() runAnalysis(episodes, testCase), ...
    "analyzeNoGloveStage7cRestCommands:NonrestReference");
end

function testTemporalMisalignmentFailsClosed(testCase)
episodes = testCase.TestData.episodes;
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
episodes(1).stateLog(4, layout.previousEffectiveAction(1)) = 0;
testCase.verifyError(@() runAnalysis(episodes, testCase), ...
    "analyzeNoGloveStage7cRestCommands:TemporalMismatch");
end

function testMatchedControlCoverageFailsClosed(testCase)
matchedP = testCase.TestData.matchedP(1:end-1, :);
testCase.verifyError(@() analyzeNoGloveStage7cRestCommands( ...
    testCase.TestData.episodes, testCase.TestData.protocol, matchedP, ...
    @fixtureActor, testCase.TestData.controller, ...
    testCase.TestData.actuator), ...
    "analyzeNoGloveStage7cRestCommands:MatchedControlCoverage");
end

function analysis = analyzeFixture(testCase)
analysis = runAnalysis(testCase.TestData.episodes, testCase);
end

function analysis = runAnalysis(episodes, testCase)
analysis = analyzeNoGloveStage7cRestCommands( ...
    episodes, testCase.TestData.protocol, testCase.TestData.matchedP, ...
    @fixtureActor, testCase.TestData.controller, ...
    testCase.TestData.actuator);
end

function [episodes, protocol, matchedP, controller, actuator] = makeFixture()
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
episodeCount = 4;
stepCount = 8;
template = struct("episode", 0, "repetitionId", 0, "side", 0, ...
    "profileId", "", "stateLog", [], "rawAction", [], ...
    "effectiveAction", [], "appliedPwm", [], ...
    "referenceHistory", [], "positionSafetyInterventionLog", [], ...
    "referenceSource", "emgIntent", ...
    "observationVariant", "intentMarkov60", "stateLength", 60);
episodes = repmat(template, episodeCount, 1);
protocolRows = repmat(struct("profileId", "", "repetitionId", 0, ...
    "side", 0, "synergyAxis", "", "directionName", "", ...
    "preRestWindows", stepCount), episodeCount, 1);
actuator = struct("maxPwm", 255, "activationThreshold", 0.05, ...
    "commandLevels", [0 64 96 128 160 192 224 255]);
controller = struct("schemaVersion", 1, "type", "P", ...
    "kp", 1.5*ones(4, 1), "kd", zeros(4, 1), ...
    "maxAction", (64/255)*ones(4, 1), ...
    "positionTolerance", 0.01*ones(4, 1), ...
    "velocityTolerance", 0.03*ones(4, 1));
for episode = 1:episodeCount
    repetitionId = ceil(episode/2);
    side = 1+mod(episode-1, 2);
    home = 0;
    directionName = "positive";
    if side == 2
        home = 0.5;
        directionName = "negative";
    end
    profileId = sprintf("fixture_%s_r%02d", ...
        directionName, repetitionId);
    state = zeros(stepCount, layout.totalLength);
    raw = zeros(stepCount, 4);
    effective = zeros(stepCount, 4);
    pwm = zeros(stepCount, 4);
    for step = 1:stepCount
        state(step, layout.emg) = -ones(1, 40);
        state(step, layout.emg(1)) = -0.15 + 0.025*(step-1);
        q = home*ones(1, 4);
        q(3) = q(3) + 0.01*(step-1);
        state(step, layout.encoder) = q;
        state(step, layout.referencePosition) = home*ones(1, 4);
        if step > 1
            state(step, layout.deltaEncoder) = ...
                state(step, layout.encoder)-state(step-1, layout.encoder);
            state(step, layout.previousEffectiveAction) = ...
                effective(step-1, :);
        end
        raw(step, :) = fixtureActor(state(step, :));
        [effectiveRow, pwmRow] = quantizeBaselineAction( ...
            raw(step, :), actuator.maxPwm, actuator.activationThreshold, ...
            actuator.commandLevels);
        effective(step, :) = effectiveRow';
        pwm(step, :) = pwmRow';
    end
    episodes(episode) = struct("episode", episode, ...
        "repetitionId", repetitionId, "side", side, ...
        "profileId", string(profileId), "stateLog", state, ...
        "rawAction", raw, "effectiveAction", effective, ...
        "appliedPwm", pwm, ...
        "referenceHistory", state(:, layout.referencePosition), ...
        "positionSafetyInterventionLog", zeros(stepCount, 4), ...
        "referenceSource", "emgIntent", ...
        "observationVariant", "intentMarkov60", "stateLength", 60);
    synergy = "primary";
    if repetitionId == 2
        synergy = "thumb";
    end
    protocolRows(episode) = struct("profileId", string(profileId), ...
        "repetitionId", repetitionId, "side", side, ...
        "synergyAxis", synergy, "directionName", directionName, ...
        "preRestWindows", stepCount);
end
protocol = struct2table(protocolRows);

[step, motor] = ndgrid((1:stepCount)', 1:4);
matchedCells = cell(episodeCount, 1);
for episode = 1:episodeCount
    matchedCells{episode} = table( ...
        repmat("conventionalP", stepCount*4, 1), ...
        repmat(episode, stepCount*4, 1), step(:), motor(:), ...
        zeros(stepCount*4, 1), zeros(stepCount*4, 1), ...
        zeros(stepCount*4, 1), false(stepCount*4, 1), ...
        'VariableNames', ["commandSource", "episode", "step", ...
        "motor", "rawAction", "effectiveAction", "appliedPwm", ...
        "positionViolation"]);
end
matchedP = vertcat(matchedCells{:});
end

function action = fixtureActor(states)
states = double(states);
wasVector = isvector(states);
if wasVector
    states = reshape(states, 1, []);
end
action = zeros(size(states, 1), 4);
action(:, 1) = 0.70 + 3.0*states(:, 1);
action(:, 2) = 0.20 + 1.5*states(:, 49);
action(:, 3) = 0.20 + 5.0*(states(:, 43)-states(:, 55));
action(:, 4) = 0.30;
action = max(-1, min(1, action));
if wasVector
    action = action(1, :);
end
end

function episode = rebuildActions(episode, actuator, layout)
stepCount = size(episode.stateLog, 1);
raw = zeros(stepCount, 4);
effective = zeros(stepCount, 4);
pwm = zeros(stepCount, 4);
episode.stateLog(1, layout.previousEffectiveAction) = 0;
for step = 1:stepCount
    if step > 1
        episode.stateLog(step, layout.previousEffectiveAction) = ...
            effective(step-1, :);
    end
    raw(step, :) = fixtureActor(episode.stateLog(step, :));
    [effectiveRow, pwmRow] = quantizeBaselineAction( ...
        raw(step, :), actuator.maxPwm, actuator.activationThreshold, ...
        actuator.commandLevels);
    effective(step, :) = effectiveRow';
    pwm(step, :) = pwmRow';
end
episode.rawAction = raw;
episode.effectiveAction = effective;
episode.appliedPwm = pwm;
end
