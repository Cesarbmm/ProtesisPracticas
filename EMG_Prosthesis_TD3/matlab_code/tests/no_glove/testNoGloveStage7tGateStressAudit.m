function tests = testNoGloveStage7tGateStressAudit
%testNoGloveStage7tGateStressAudit deterministic ETAPA 7T tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
end

function testBroadClassificationRequiresChannelsMotorsAndSafety(testCase)
values = classifierFixture("broad");
decision = classifyNoGloveStage7tConsequence(values);
testCase.verifyEqual(decision.classification, ...
    "broadSyntheticGateStressConsequence");
testCase.verifyEqual(decision.recommendation, ...
    "preregisterSingleFactorGateAggregationAblation");
testCase.verifyEqual(decision.passedChannelCount, 7);
testCase.verifyEqual(decision.passedMotorCount, 4);
testCase.verifyGreaterThan(decision.firstStepSafetyInterventionCount, 0);
end

function testSpecificClassificationIsNotBroad(testCase)
decision = classifyNoGloveStage7tConsequence( ...
    classifierFixture("specific"));
testCase.verifyEqual(decision.classification, ...
    "channelSpecificSyntheticGateStressConsequence");
testCase.verifyEqual(decision.passedChannelCount, 1);
testCase.verifyEqual(decision.passedMotorCount, 1);
end

function testLimitedClassificationHasNoNonzeroPwm(testCase)
decision = classifyNoGloveStage7tConsequence( ...
    classifierFixture("limited"));
testCase.verifyEqual(decision.classification, ...
    "limitedSyntheticGateStressConsequence");
testCase.verifyEqual(decision.recommendation, ...
    "closeSyntheticPathAndRequireShadowMode");
end

function testBroadPwmWithoutSafetyDoesNotPassBroadRule(testCase)
values = classifierFixture("broad");
values.safetyIntervention(:) = 0;
decision = classifyNoGloveStage7tConsequence(values);
testCase.verifyNotEqual(decision.classification, ...
    "broadSyntheticGateStressConsequence");
end

function testClassifierFailsClosedOnIncompleteChannels(testCase)
values = classifierFixture("broad");
values(values.dominantChannel == 7, :) = [];
testCase.verifyError(@() classifyNoGloveStage7tConsequence(values), ...
    "classifyNoGloveStage7tConsequence:IncompleteFirstStep");
values = classifierFixture("broad");
values.pwm(1) = NaN;
testCase.verifyError(@() classifyNoGloveStage7tConsequence(values), ...
    "classifyNoGloveStage7tConsequence:InvalidTable");
end

function testContextAuditRestoresQAndPreviousActionSeparately(testCase)
[corpus, pairs] = contextFixture();
audit = auditNoGloveStage7tContextDivergence(corpus, pairs);
testCase.verifyEqual(audit.queryCount, 16);
testCase.verifyEqual(audit.firstStepQueryCount, 8);
testCase.verifyEqual(audit.postFirstQueryCount, 8);
testCase.verifyEqual(audit.fullMatchCount, 0);
firstQ = audit.blockTable.phase == "firstStep" & ...
    audit.blockTable.block == "q";
postPrevious = audit.blockTable.phase == "postFirst" & ...
    audit.blockTable.block == "previousEffectiveAction";
testCase.verifyTrue(all(audit.blockTable.restoredWithoutBlock(firstQ)));
testCase.verifyTrue(all( ...
    audit.blockTable.restoredWithoutBlock(postPrevious)));
testCase.verifyFalse(any(audit.blockTable.restoredWithoutBlock( ...
    audit.blockTable.phase == "firstStep" & ...
    audit.blockTable.block ~= "q")));
end

function testContextAuditUsesOnlyCrossEpisodeSameFoldAndContext(testCase)
[corpus, pairs] = contextFixture();
audit = auditNoGloveStage7tContextDivergence(corpus, pairs);
query = audit.queryTable;
testCase.verifyNotEqual(query.episode, query.selectedDonorEpisode);
testCase.verifyGreaterThanOrEqual(query.selectedEmgRms, 0.50);
testCase.verifyEqual(query.gateContext(query.phase == "firstStep"), ...
    repmat("initialRest", 8, 1));
testCase.verifyEqual(query.gateContext(query.phase == "postFirst"), ...
    repmat("declaredRest", 8, 1));
end

function testContextAuditDoesNotMutateStatesOrEvaluateActor(testCase)
[corpus, pairs] = contextFixture();
before = corpus.states;
audit = auditNoGloveStage7tContextDivergence(corpus, pairs);
testCase.verifyEqual(corpus.states, before);
testCase.verifyFalse(audit.stateCounterfactualUsed);
testCase.verifyFalse(audit.actorEvaluated);
testCase.verifyTrue(audit.distanceBlockOmissionOnly);
end

function testLauncherRejectsUnknownOptionsBeforeOutput(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7t_gate_stress_consequence_audit( ...
    struct("unexpected", true)), ...
    "run_no_glove_stage7t_gate_stress_consequence_audit:UnknownOption");
end

function testReachableEndpointCertifiesConsistentUpperEquilibrium(testCase)
% Amendment 2 regression: Opening-type firstStep rows do NOT land at the
% idealized positionMax=1 (Env.reset/prosthesis_simulator plateau below it).
% A consistent, reproducible non-unit value must still be certified as the
% reachable upper endpoint, not rejected as "interior".
qMin = zeros(1, 4);
upperEquilibrium = [0.4218, 0.5796, 0.8835, 0.6979];
firstStepQ = [ ...
    qMin; qMin; qMin; ...
    upperEquilibrium; upperEquilibrium; upperEquilibrium];
endpoints = deriveNoGloveStage7tReachableEndpoints(firstStepQ, qMin, 1e-4);
testCase.verifyTrue(endpoints.upperEquilibriumConsistent);
testCase.verifyEqual(endpoints.qUpper, upperEquilibrium, "AbsTol", 1e-12);
testCase.verifyEqual(endpoints.lowerRowCount, 3);
testCase.verifyEqual(endpoints.upperRowCount, 3);
testCase.verifyLessThanOrEqual(endpoints.maxUpperDeviation, 1e-4);
end

function testReachableEndpointFailsClosedOnInconsistentUpperRows(testCase)
% If Opening-type episodes do NOT actually agree with each other, there is
% no genuine simulator equilibrium to certify: consistency must be false so
% the caller fails closed (auditInvalid) instead of silently averaging over
% a real anomaly.
qMin = zeros(1, 4);
firstStepQ = [ ...
    qMin; ...
    0.50, 0.50, 0.50, 0.50; ...
    0.90, 0.50, 0.50, 0.50]; % motor 1 disagrees far beyond tolerance
endpoints = deriveNoGloveStage7tReachableEndpoints(firstStepQ, qMin, 1e-4);
testCase.verifyFalse(endpoints.upperEquilibriumConsistent);
end

function testReachableEndpointRejectsIdealizedUnitAssumption(testCase)
% This is the direct regression test for the bug that made ETAPA 7T
% auditInvalid: classifying against a hardcoded positionMax=1 would flag a
% genuine, reproducible 0.88-normalized equilibrium as "not at an endpoint".
% The derived-endpoint contract must not do that.
qMin = zeros(1, 4);
plateau = [0.4218, 0.5796, 0.8835, 0.6979];
firstStepQ = repmat(plateau, 4, 1);
endpoints = deriveNoGloveStage7tReachableEndpoints(firstStepQ, qMin, 1e-4);
testCase.verifyTrue(endpoints.upperEquilibriumConsistent);
testCase.verifyTrue(all(abs(endpoints.qUpper - 1) > 0.10), ...
    "The certified endpoint must be the empirical plateau, not 1.0.");
end


function values = classifierFixture(mode)
dominantChannel = repelem((1:7)', 4);
motor = repmat((1:4)', 7, 1);
phase = repmat("firstStep", 28, 1);
pwm = zeros(28, 1);
safetyIntervention = zeros(28, 1);
switch mode
    case "broad"
        pwm(:) = 64;
        safetyIntervention(1) = 1;
    case "specific"
        pwm(dominantChannel == 1 | motor == 1) = 64;
        safetyIntervention(1) = 1;
    case "limited"
        % Frozen zeros intentionally remain zeros.
    otherwise
        error("Unknown fixture mode.");
end
values = table(phase, dominantChannel, motor, pwm, ...
    safetyIntervention);
end

function [corpus, pairSet] = contextFixture()
states = zeros(4, 60);
states(2, 1:40) = 1;
states(3, 1:40) = 2;
states(4, 1:40) = 3;
states(2, 41:44) = 0.5;
states(4, 49:52) = 0.6;
source = repmat("steadyRest", 4, 1);
episode = (1:4)';
step = [1; 1; 2; 2];
gateContext = ["initialRest"; "initialRest"; ...
    "declaredRest"; "declaredRest"];
fold = ones(4, 1);
metadata = table(source, episode, step, gateContext, fold);
zeroControlDemand = true(4, 4);
corpus = struct("states", states, ...
    "zeroControlDemand", zeroControlDemand, "metadata", metadata);
pairSet = struct("metadata", metadata, ...
    "primaryMask", true(4, 4), ...
    "emgScale", ones(1, 40), ...
    "contextScale", ones(1, 20), ...
    "statesEvaluated", states);
end
