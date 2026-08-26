function tests = testNoGloveStage7TemporalMetrics
% Deterministic tests for ETAPA 7 offline temporal metrics.
tests = functiontests(localfunctions);
end

function testKnownOneStepResponseLagIsRecovered(testCase)
values = buildKnownLagFixture();
analysis = analyzeNoGloveStage7TemporalMetrics( ...
    values, "acceptance", "maxDiscreteLagSteps", 3, ...
    "dtwMaxLagSteps", 1, "minimumRegimeSamples", 5);

agent = analysis.discreteLagSummary( ...
    analysis.discreteLagSummary.commandSource == "Agent200", :);
baseline = analysis.discreteLagSummary( ...
    analysis.discreteLagSummary.commandSource == "conventionalP", :);
testCase.verifyEqual(agent.bestMseLagSteps, 1);
testCase.verifyEqual(agent.bestMseLagSec, 0.2, "AbsTol", 1e-12);
testCase.verifyEqual(agent.bestLagMse, 0, "AbsTol", 1e-15);
testCase.verifyGreaterThan(agent.bestLagImprovementFraction, 0.99);
testCase.verifyEqual(baseline.bestMseLagSteps, 0);
testCase.verifyEqual(baseline.zeroLagMse, 0, "AbsTol", 0);
end

function testSharedDtwPathIsSquaredRestrictedAndNormalized(testCase)
analysis = analyzeNoGloveStage7TemporalMetrics( ...
    buildKnownLagFixture(), "acceptance", ...
    "maxDiscreteLagSteps", 3, "dtwMaxLagSteps", 1, ...
    "minimumRegimeSamples", 5);
agentEpisodes = analysis.episodeDtwTable( ...
    analysis.episodeDtwTable.commandSource == "Agent200", :);
testCase.verifyLessThanOrEqual(max(agentEpisodes.maxAbsLagSteps), 1);
testCase.verifyLessThanOrEqual( ...
    max(agentEpisodes.distanceConsistencyAbs), 1e-12);
testCase.verifyEqual(agentEpisodes.dtwMse, ...
    agentEpisodes.dtwRawSquaredDistance ./ ...
    agentEpisodes.dtwComponentPathCount, "AbsTol", 1e-15);
testCase.verifyGreaterThanOrEqual( ...
    agentEpisodes.normalizedLagPenalty, 0);
testCase.verifyLessThanOrEqual( ...
    agentEpisodes.normalizedLagPenalty, 1);
testCase.verifyTrue(analysis.endpointErrorRetained);
testCase.verifyEqual(analysis.dtwPathContract, ...
    "one shared four-motor path per episode");
end

function testRegimeMetricsAndEvidenceAreReported(testCase)
analysis = analyzeNoGloveStage7TemporalMetrics( ...
    buildKnownLagFixture(), "acceptance", ...
    "maxDiscreteLagSteps", 3, "dtwMaxLagSteps", 1, ...
    "minimumRegimeSamples", 5);
testCase.verifyEqual(unique(analysis.regimeLagSummary.regime), ...
    ["closing"; "hold"; "opening"]);
testCase.verifyEqual(height(analysis.regimeLagSummary), 24);
testCase.verifyEqual(height(analysis.evidenceDecision), 2);
testCase.verifyFalse(analysis.agentLoaded);
testCase.verifyFalse(analysis.reinforcementLearningInvoked);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.rewardInvoked);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testNoncontiguousEpisodeFailsClosed(testCase)
values = buildKnownLagFixture();
values(values.commandSource == "Agent200" & values.step == 10, :) = [];
testCase.verifyError(@() analyzeNoGloveStage7TemporalMetrics( ...
    values, "acceptance"), ...
    "analyzeNoGloveStage7TemporalMetrics:NoncontiguousSteps");
end

function testNonfiniteAndInvalidLagBoundsFailClosed(testCase)
values = buildKnownLagFixture();
values.qAfter(1) = NaN;
testCase.verifyError(@() analyzeNoGloveStage7TemporalMetrics( ...
    values, "acceptance"), ...
    "analyzeNoGloveStage7TemporalMetrics:NonfiniteData");
values = buildKnownLagFixture();
testCase.verifyError(@() analyzeNoGloveStage7TemporalMetrics( ...
    values, "acceptance", "maxDiscreteLagSteps", 1, ...
    "dtwMaxLagSteps", 2), ...
    "analyzeNoGloveStage7TemporalMetrics:InvalidLagBounds");
end

function values = buildKnownLagFixture()
stepCount = 30;
time = 0:(stepCount-1);
qReference = zeros(4, stepCount);
for motorIdx = 1:4
    qReference(motorIdx, :) = 0.5 + 0.2 * sin( ...
        2*pi*time/(8+motorIdx) + 0.3*motorIdx);
end
referenceVelocity = [zeros(4, 1), diff(qReference, 1, 2)/0.2];
lagged = [qReference(:, 1), qReference(:, 1:end-1)];

sources = ["Agent200", "conventionalP"];
rows = cell(numel(sources), 1);
for sourceIdx = 1:numel(sources)
    if sources(sourceIdx) == "Agent200"
        response = lagged;
    else
        response = qReference;
    end
    [step, motor] = ndgrid((1:stepCount)', 1:4);
    count = stepCount * 4;
    responseByStep = response';
    referenceByStep = qReference';
    velocityByStep = referenceVelocity';
    rows{sourceIdx} = table( ...
        repmat("acceptance", count, 1), ...
        repmat(sources(sourceIdx), count, 1), ...
        ones(count, 1), step(:), motor(:), responseByStep(:), ...
        referenceByStep(:), velocityByStep(:), ...
        'VariableNames', ["split", "commandSource", "episode", ...
        "step", "motor", "qAfter", "qReference", ...
        "referenceVelocity"]);
end
values = vertcat(rows{:});
end
