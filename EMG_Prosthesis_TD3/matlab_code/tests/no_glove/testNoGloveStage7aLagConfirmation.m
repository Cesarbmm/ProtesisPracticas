function tests = testNoGloveStage7aLagConfirmation
%testNoGloveStage7aLagConfirmation deterministic ETAPA 7A tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
testCase.TestData.matlabRoot = matlabRoot;
end

function testKnownPositiveDelayIsConfirmedHeldOut(testCase)
values = makeSyntheticTable(2*ones(1, 6));
analysis = analyzeNoGloveStage7aLagConfirmation(values, "acceptance", ...
    "targetMotors", 2, "maxLagSteps", 5);

testCase.verifyEqual(analysis.foldEvaluationTable.selectedLagSteps, ...
    2*ones(height(analysis.foldEvaluationTable), 1));
testCase.verifyTrue(all(analysis.confirmationSummary.fixedLagConfirmed));
testCase.verifyTrue(all( ...
    analysis.confirmationSummary.causalCompensationCandidate));
testCase.verifyTrue(analysis.causalCompensationGatePassed);
testCase.verifyEqual(analysis.primaryDecision.classification, ...
    "targetedCausalCandidate");
testCase.verifyTrue(analysis.commonInteriorSupport);
testCase.verifyTrue(analysis.fullEndpointErrorRetained);
testCase.verifyFalse(analysis.compensationInterventionExecuted);
testCase.verifyFalse(analysis.filteredReferenceInterventionExecuted);
testCase.verifyFalse(analysis.dtwCalculated);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testHeldOutRepetitionCannotChangeItsSelectedLag(testCase)
baseline = makeSyntheticTable(2*ones(1, 6));
changedDelays = 2*ones(1, 6);
changedDelays(6) = -4;
changed = makeSyntheticTable(changedDelays);
baselineAnalysis = analyzeNoGloveStage7aLagConfirmation( ...
    baseline, "acceptance", "targetMotors", 2, "maxLagSteps", 5);
changedAnalysis = analyzeNoGloveStage7aLagConfirmation( ...
    changed, "acceptance", "targetMotors", 2, "maxLagSteps", 5);

baselineFold = baselineAnalysis.foldEvaluationTable( ...
    baselineAnalysis.foldEvaluationTable.heldOutRepetition == 6, :);
changedFold = changedAnalysis.foldEvaluationTable( ...
    changedAnalysis.foldEvaluationTable.heldOutRepetition == 6, :);
testCase.verifyEqual(changedFold.selectedLagSteps, ...
    baselineFold.selectedLagSteps);
testCase.verifyNotEqual(changedFold.evaluationSelectedLagMse, ...
    baselineFold.evaluationSelectedLagMse);
end

function testInconsistentLagSignsFailConfirmation(testCase)
values = makeSyntheticTable([2 -2 2 -2 2 -2]);
analysis = analyzeNoGloveStage7aLagConfirmation(values, "acceptance", ...
    "targetMotors", 2, "maxLagSteps", 5);

testCase.verifyFalse(any(analysis.confirmationSummary.fixedLagConfirmed));
testCase.verifyFalse(any( ...
    analysis.confirmationSummary.causalCompensationCandidate));
testCase.verifyFalse(analysis.causalCompensationGatePassed);
testCase.verifyLessThanOrEqual( ...
    max(analysis.confirmationSummary.dominantSignFraction), 0.5);
end

function testBoundarySelectionIsNotCalledConfirmed(testCase)
values = makeSyntheticTable(5*ones(1, 6));
analysis = analyzeNoGloveStage7aLagConfirmation(values, "acceptance", ...
    "targetMotors", 2, "maxLagSteps", 5);

testCase.verifyEqual( ...
    analysis.confirmationSummary.boundarySelectionFraction, ...
    ones(height(analysis.confirmationSummary), 1));
testCase.verifyEqual(analysis.confirmationSummary.classification, ...
    repmat("boundaryUnresolved", ...
    height(analysis.confirmationSummary), 1));
testCase.verifyFalse(analysis.causalCompensationGatePassed);
end

function testEveryLagUsesIdenticalCommonSupport(testCase)
values = makeSyntheticTable(2*ones(1, 6));
analysis = analyzeNoGloveStage7aLagConfirmation(values, "acceptance", ...
    "targetMotors", 2, "maxLagSteps", 5);
keys = unique(analysis.calibrationLagTable(:, ...
    ["regime", "heldOutRepetition"]), "rows");
for keyIdx = 1:height(keys)
    selected = analysis.calibrationLagTable( ...
        analysis.calibrationLagTable.regime == keys.regime(keyIdx) & ...
        analysis.calibrationLagTable.heldOutRepetition == ...
        keys.heldOutRepetition(keyIdx), :);
    testCase.verifyEqual(numel(unique(selected.sampleCount)), 1);
    testCase.verifyEqual(numel(unique(selected.zeroLagMse)), 1);
end
end

function testInvalidDataAreRejected(testCase)
values = makeSyntheticTable(2*ones(1, 6));
noncontiguous = values(~(values.episode == 1 & values.step == 10), :);
testCase.verifyError(@() analyzeNoGloveStage7aLagConfirmation( ...
    noncontiguous, "acceptance", "targetMotors", 2), ...
    "analyzeNoGloveStage7aLagConfirmation:NoncontiguousSteps");

nonfinite = values;
nonfinite.qAfter(1) = NaN;
testCase.verifyError(@() analyzeNoGloveStage7aLagConfirmation( ...
    nonfinite, "acceptance", "targetMotors", 2), ...
    "analyzeNoGloveStage7aLagConfirmation:NonfiniteData");
end

function values = makeSyntheticTable(delays)
stepCount = 60;
periodSec = 0.2;
values = table();
for repetition = 1:numel(delays)
    velocity = zeros(stepCount, 1);
    velocity(8:25) = 0.02;
    velocity(36:53) = -0.02;
    reference = 0.25 + periodSec*cumsum(velocity);
    delay = delays(repetition);
    sourceIndices = min(stepCount, max(1, (1:stepCount)'-delay));
    response = reference(sourceIndices);
    episodeValues = table( ...
        repmat("acceptance", stepCount, 1), ...
        repmat("Agent200", stepCount, 1), ...
        repmat(repetition, stepCount, 1), ...
        repmat(repetition, stepCount, 1), ...
        (1:stepCount)', repmat(2, stepCount, 1), response, ...
        reference, velocity, ...
        'VariableNames', ["split", "commandSource", "episode", ...
        "repetitionId", "step", "motor", "qAfter", ...
        "qReference", "referenceVelocity"]);
    values = [values; episodeValues]; %#ok<AGROW>
end
end
