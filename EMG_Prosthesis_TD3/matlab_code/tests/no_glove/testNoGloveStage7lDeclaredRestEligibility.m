function tests = testNoGloveStage7lDeclaredRestEligibility
%testNoGloveStage7lDeclaredRestEligibility deterministic ETAPA 7L tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
end

function testSupportedSemanticContract(testCase)
[decisions, windows, episodeCount] = buildFixture("supported");
analysis = analyzeNoGloveStage7lDeclaredRestEligibility( ...
    decisions, windows, "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows));
testCase.verifyTrue(analysis.contractSupported);
testCase.verifyEqual(analysis.classification, ...
    "offlineDeclaredRestEligibilitySupported");
testCase.verifyEqual(sum(analysis.windowAudit.nonRestLeakage), 0);
testCase.verifyEqual( ...
    sum(analysis.windowAudit.prematureFarStartedLatch), 0);
testCase.verifyGreaterThan( ...
    sum(analysis.windowAudit.recoveredByMemory), 0);
testCase.verifyEqual(analysis.prefixMismatchCount, 0);
end

function testReleaseAtActiveCountdownZero(testCase)
[decisions, windows, episodeCount] = buildFixture("supported");
analysis = analyzeNoGloveStage7lDeclaredRestEligibility( ...
    decisions, windows, "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows));
rows = analysis.windowAudit.source == "acceptance" & ...
    analysis.windowAudit.provenance == "activeCountdownZero";
testCase.verifyTrue(all(analysis.windowAudit.stopped(rows)));
testCase.verifyFalse(any(analysis.windowAudit.declaredRest(rows)));
testCase.verifyFalse(any(analysis.windowAudit.latchActive(rows)));
testCase.verifyTrue(all(analysis.windowAudit.latchRelease(rows)));
end

function testFarStartedWaitsForNearTarget(testCase)
[decisions, windows, episodeCount] = buildFixture("supported");
analysis = analyzeNoGloveStage7lDeclaredRestEligibility( ...
    decisions, windows, "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows));
rows = analysis.windowAudit.source == "training" & ...
    analysis.windowAudit.segmentFarStarted;
values = analysis.windowAudit(rows, :);
testCase.verifyFalse(any(values.latchActive( ...
    values.beforeFarConvergence)));
testCase.verifyTrue(any(values.latchEntry & values.nearTarget));
testCase.verifyTrue(any(values.recoveredByMemory));
end

function testCoverageFailureClassification(testCase)
[decisions, windows, episodeCount] = buildFixture("coverageFailure");
analysis = analyzeNoGloveStage7lDeclaredRestEligibility( ...
    decisions, windows, "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows));
testCase.verifyFalse(analysis.contractSupported);
testCase.verifyEqual(analysis.classification, ...
    "declaredRestCoverageInsufficient");
end

function testNoMemorySupportClassification(testCase)
[decisions, windows, episodeCount] = buildFixture("noMemorySupport");
analysis = analyzeNoGloveStage7lDeclaredRestEligibility( ...
    decisions, windows, "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows));
testCase.verifyFalse(analysis.contractSupported);
testCase.verifyEqual(analysis.classification, ...
    "declaredRestLatchAddsNoSupport");
end

function testRejectsKeyMismatchAndDuplicate(testCase)
[decisions, windows, episodeCount] = buildFixture("supported");
changed = windows;
changed.windowIndex(end) = changed.windowIndex(end)+1000;
testCase.verifyError(@() ...
    analyzeNoGloveStage7lDeclaredRestEligibility(decisions, changed, ...
    "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(changed)), ...
    "analyzeNoGloveStage7lDeclaredRestEligibility:KeyMismatch");
duplicated = decisions;
duplicated(end, :) = duplicated(end-1, :);
testCase.verifyError(@() ...
    analyzeNoGloveStage7lDeclaredRestEligibility(duplicated, windows, ...
    "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows)), ...
    "analyzeNoGloveStage7lDeclaredRestEligibility:DuplicateKey");
end

function testRejectsNoncontiguousSteps(testCase)
[decisions, windows, episodeCount] = buildFixture("supported");
row = decisions.variant == "candidate" & ...
    decisions.source == "training" & decisions.step == 5;
decisions.step(row) = 6;
windows.step(row) = 6;
testCase.verifyError(@() ...
    analyzeNoGloveStage7lDeclaredRestEligibility(decisions, windows, ...
    "expectedEpisodeCount", episodeCount, ...
    "expectedWindowCount", height(windows)), ...
    "analyzeNoGloveStage7lDeclaredRestEligibility:StepOrder");
end

function testLauncherOptionsFailClosed(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7l_declared_rest_eligibility_audit( ...
    struct("unknown", 1)), ...
    "run_no_glove_stage7l_declared_rest_eligibility_audit:UnknownOption");
testCase.verifyError(@() ...
    run_no_glove_stage7l_declared_rest_eligibility_audit(struct( ...
    "stage7kRunRoot", fullfile(tempdir, "missing-stage7k"))), ...
    "run_no_glove_stage7l_declared_rest_eligibility_audit:MissingStage7k");
end

function [decisions, windows, episodeCount] = buildFixture(mode)
variants = ["control", "candidate"];
sources = ["training", "acceptance", "steadyRest"];
partCount = numel(variants)*numel(sources);
decisionParts = cell(partCount, 1);
windowParts = cell(partCount, 1);
windowOffset = 0;
episode = 0;
partIdx = 0;
for variant = variants
    for source = sources
        partIdx = partIdx+1;
        episode = episode+1;
        [provenance, mse, stopped, segmentId, farStarted] = ...
            sourceFixture(source, mode);
        count = numel(mse);
        step = (1:count)';
        windowIndex = windowOffset+step;
        windowOffset = windowOffset+count;
        oldLatch = false(count, 1);
        decisionParts{partIdx} = table( ...
            repmat(variant, count, 1), repmat(source, count, 1), ...
            repmat(episode, count, 1), ones(count, 1), step, ...
            windowIndex, stopped, provenance, oldLatch, segmentId, ...
            farStarted, 'VariableNames', ["variant", "source", ...
            "episode", "repetitionId", "step", "windowIndex", ...
            "stopped", "provenance", "latchActive", ...
            "stoppedSegmentId", "segmentFarStarted"]);
        windowParts{partIdx} = table( ...
            repmat(variant, count, 1), repmat(source, count, 1), ...
            repmat(episode, count, 1), ones(count, 1), step, ...
            windowIndex, mse, stopped, 'VariableNames', ...
            ["variant", "source", "episode", "repetitionId", ...
            "step", "windowIndex", "holdPositionMse", "stopped"]);
    end
end
decisions = vertcat(decisionParts{:});
windows = vertcat(windowParts{:});
episodeCount = episode;
end

function [provenance, mse, stopped, segmentId, farStarted] = ...
        sourceFixture(source, mode)
switch source
    case "training"
        provenance = ["movingReference"; "activeCountdownZero"; ...
            "decoderRest"; "decoderRest"; "decoderRest"];
        mse = [3e-3; 3e-3; 3e-3; 1e-5; 3e-3];
        stopped = [false; true; true; true; true];
        segmentId = [0; 1; 1; 1; 1];
        farStarted = [false; true; true; true; true];
    case "acceptance"
        provenance = ["episodeInitialization"; "decoderRest"; ...
            "activeCountdownZero"; "decoderRest"; "decoderRest"];
        mse = [1e-5; 3e-3; 3e-3; 1e-5; 3e-3];
        stopped = true(5, 1);
        segmentId = ones(5, 1);
        farStarted = false(5, 1);
    otherwise
        provenance = ["episodeInitialization"; repmat("decoderRest", 4, 1)];
        mse = [1e-5; 3e-3; 3e-3; 1e-5; 3e-3];
        stopped = true(5, 1);
        segmentId = ones(5, 1);
        farStarted = false(5, 1);
end
if mode == "coverageFailure" && source == "steadyRest"
    mse(:) = 3e-3;
elseif mode == "noMemorySupport"
    mse(:) = 1e-5;
end
end
