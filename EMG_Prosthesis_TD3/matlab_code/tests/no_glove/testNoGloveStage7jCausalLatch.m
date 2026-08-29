function tests = testNoGloveStage7jCausalLatch
%testNoGloveStage7jCausalLatch deterministic offline ETAPA 7J tests.
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

function testSupportedLatchRecoversRestWithoutFarExposure(testCase)
analysis = analyzeNoGloveStage7jCausalLatch( ...
    syntheticCorpus("supported"));
testCase.verifyEqual(analysis.classification, ...
    "offlineLatchedHoldContractSupported");
testCase.verifyTrue(analysis.contractSupported);
candidate = analysis.variantSummary( ...
    analysis.variantSummary.variant == "candidate", :);
testCase.verifyEqual(candidate.latchedRestCoverage, 1);
testCase.verifyEqual(candidate.latchedFarCorrectionExposure, 0);
testCase.verifyGreaterThan(candidate.recoveredWindowCount, 0);
testCase.verifyTrue(candidate.explicitMemoryRequired);
testCase.verifyTrue(analysis.explicitMemoryRequired);
testCase.verifyFalse(analysis.observationVariantImplemented);
testCase.verifyFalse(analysis.behavioralInterventionExecuted);
end

function testCoverageFailureClassification(testCase)
analysis = analyzeNoGloveStage7jCausalLatch( ...
    syntheticCorpus("coverageFailure"));
testCase.verifyEqual(analysis.classification, ...
    "latchedHoldCoverageInsufficient");
testCase.verifyFalse(analysis.contractSupported);
end

function testFarExposureFailureClassification(testCase)
analysis = analyzeNoGloveStage7jCausalLatch( ...
    syntheticCorpus("farExposure"));
testCase.verifyEqual(analysis.classification, ...
    "latchedHoldNotSeparableFromFarCorrection");
candidate = analysis.variantSummary( ...
    analysis.variantSummary.variant == "candidate", :);
testCase.verifyGreaterThan( ...
    candidate.latchedFarCorrectionExposure, 0.05);
testCase.verifyEqual(candidate.prematureLatchWindowCount, 0);
end

function testEntryPersistenceAndMovingRelease(testCase)
analysis = analyzeNoGloveStage7jCausalLatch( ...
    syntheticCorpus("supported"));
rows = analysis.windowAudit( ...
    analysis.windowAudit.variant == "candidate" & ...
    analysis.windowAudit.source == "acceptance", :);
testCase.verifyEqual(rows.latchActive', ...
    logical([1, 1, 0, 0]));
testCase.verifyEqual(rows.latchEntry', ...
    logical([1, 0, 0, 0]));
testCase.verifyEqual(rows.latchRelease', ...
    logical([0, 0, 1, 0]));
testCase.verifyEqual(rows.recoveredByMemory', ...
    logical([0, 1, 0, 0]));
testCase.verifyEqual(rows.stoppedSegmentId', [1, 1, 0, 2]);
testCase.verifyTrue(rows.segmentFarStarted(4));
testCase.verifyFalse(rows.latchActive(4));
end

function testFarStartedSegmentCannotLatchBeforeConvergence(testCase)
windows = syntheticCorpus("supported");
rows = windows.variant == "candidate" & ...
    windows.source == "training";
windows.holdPositionMse(rows) = [0.01; 1e-5; 0.02];
windows.eligible(rows) = [false; true; false];
analysis = analyzeNoGloveStage7jCausalLatch(windows);
values = analysis.windowAudit(rows, :);
testCase.verifyEqual(values.latchActive', logical([0, 1, 1]));
testCase.verifyEqual(values.beforeFarConvergence', ...
    logical([1, 0, 0]));
testCase.verifyFalse(any(values.prematureLatch));
segment = analysis.segmentAudit( ...
    analysis.segmentAudit.variant == "candidate" & ...
    analysis.segmentAudit.source == "training", :);
testCase.verifyTrue(segment.farStarted);
testCase.verifyTrue(segment.converged);
testCase.verifyEqual(segment.firstConvergenceStep, 2);
end

function testPrefixReplayHasNoFutureLeakage(testCase)
analysis = analyzeNoGloveStage7jCausalLatch( ...
    syntheticCorpus("supported"));
testCase.verifyEqual(analysis.prefixCheckCount, 6);
testCase.verifyEqual(analysis.prefixMismatchCount, 0);
testCase.verifyFalse(any(analysis.windowAudit.prefixMismatch));
testCase.verifyTrue(analysis.checks.prefixCausal);
end

function testInvalidInstantReplayFailsClosed(testCase)
windows = syntheticCorpus("supported");
windows.eligible(1) = ~windows.eligible(1);
testCase.verifyError(@() analyzeNoGloveStage7jCausalLatch(windows), ...
    "analyzeNoGloveStage7jCausalLatch:InvalidCorpus");
end

function testLauncherOptionsFailClosed(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7j_causal_hold_latch_audit( ...
        struct("unknown", 1)), ...
    "run_no_glove_stage7j_causal_hold_latch_audit:UnknownOption");
testCase.verifyError(@() ...
    run_no_glove_stage7j_causal_hold_latch_audit(struct( ...
        "stage7iRunRoot", fullfile(tempdir, "missing-stage7i"))), ...
    "run_no_glove_stage7j_causal_hold_latch_audit:MissingStage7i");
end

function windows = syntheticCorpus(mode)
variants = ["control", "candidate"];
parts = cell(0, 1);
cursor = 0;
for variant = variants
    switch mode
        case "farExposure"
            trainingMse = [0; 0.01; 0.02];
        otherwise
            trainingMse = [0.01; 0.02; 0.03];
    end
    rows = makeRows(variant, "training", trainingMse, ...
        zeros(size(trainingMse)), cursor);
    parts{end+1, 1} = rows; %#ok<AGROW>
    cursor = cursor+height(rows);

    acceptanceMse = [0; 0.001; 0.001; 0.02];
    acceptanceVelocity = [0; 0; 1; 0];
    rows = makeRows(variant, "acceptance", acceptanceMse, ...
        acceptanceVelocity, cursor);
    parts{end+1, 1} = rows; %#ok<AGROW>
    cursor = cursor+height(rows);

    if mode == "coverageFailure"
        restMse = 0.01.*ones(5, 1);
    else
        restMse = [0; 0.01; 0.02; 0.03; 0.04];
    end
    rows = makeRows(variant, "steadyRest", restMse, ...
        zeros(size(restMse)), cursor);
    parts{end+1, 1} = rows; %#ok<AGROW>
    cursor = cursor+height(rows);
end
windows = vertcat(parts{:});
end

function rows = makeRows(variant, source, mse, velocity, cursor)
count = numel(mse);
effectiveAction = repmat([0.5, 0, 0, 0], count, 1);
pwm = repmat([128, 0, 0, 0], count, 1);
safety = zeros(count, 4);
stopped = abs(velocity) <= 1e-12;
eligible = stopped & mse <= 1e-4;
rows = table(repmat(variant, count, 1), ...
    repmat(source, count, 1), ones(count, 1), ones(count, 1), ...
    (1:count)', cursor+(1:count)', effectiveAction, pwm, safety, ...
    mse, abs(velocity), stopped, eligible, ...
    'VariableNames', ["variant", "source", "episode", ...
    "repetitionId", "step", "windowIndex", "effectiveAction", ...
    "pwm", "safetyIntervention", "holdPositionMse", ...
    "holdVelocityMaxAbs", "stopped", "eligible"]);
end
