function tests = testNoGloveStage7iHoldSupport
%testNoGloveStage7iHoldSupport deterministic offline ETAPA 7I tests.
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

function testFeasibleOfflineDomain(testCase)
windows = syntheticCorpus("feasible");
analysis = analyzeNoGloveStage7iHoldSupport(windows);
testCase.verifyEqual(analysis.classification, ...
    "offlineHoldSupportDomainExists");
candidate = analysis.supportDecision( ...
    analysis.supportDecision.variant == "candidate", :);
testCase.verifyTrue(candidate.feasibleThresholdExists);
testCase.verifyLessThanOrEqual( ...
    candidate.farCorrectionExposureAtRestThreshold, 0.05);
testCase.verifyFalse(analysis.rootCauseIdentified);
testCase.verifyFalse(analysis.behavioralInterventionExecuted);
testCase.verifyFalse(analysis.simulatorInvoked);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testRestAndCorrectionAreNotSeparable(testCase)
windows = syntheticCorpus("nonseparable");
analysis = analyzeNoGloveStage7iHoldSupport(windows);
testCase.verifyEqual(analysis.classification, ...
    "holdSupportNotSeparableFromFarCorrection");
candidate = analysis.supportDecision( ...
    analysis.supportDecision.variant == "candidate", :);
testCase.verifyTrue(candidate.restOnlyThresholdExists);
testCase.verifyFalse(candidate.feasibleThresholdExists);
testCase.verifyGreaterThan( ...
    candidate.farCorrectionExposureAtRestThreshold, 0.05);
end

function testTimelineUsesPrecedingCommandAtFirstExit(testCase)
windows = syntheticCorpus("timeline");
analysis = analyzeNoGloveStage7iHoldSupport(windows);
row = analysis.episodeTimeline( ...
    analysis.episodeTimeline.variant == "candidate", :);
testCase.verifyTrue(row.initialEligible);
testCase.verifyFalse(row.initialMismatch);
testCase.verifyTrue(row.exitedEligibleRegion);
testCase.verifyEqual(row.firstExitStep, 3);
testCase.verifyEqual(row.reentryCount, 1);
testCase.verifyEqual(row.longestEligibleRun, 2);
testCase.verifyEqual(row.eligibleFraction, 3/5, "AbsTol", 1e-15);
testCase.verifyEqual(row.precedingMeanAbsPwm, 5);
testCase.verifyEqual(row.precedingMaxAbsPwm, 8);
testCase.verifyEqual(row.precedingActionL2, 0.25);
testCase.verifyEqual(row.precedingSafetyComponentCount, 1);
testCase.verifyTrue(row.precedingAnySafety);
end

function testSoftGateUsesFixedPreregisteredTau(testCase)
analysis = analyzeNoGloveStage7iHoldSupport( ...
    syntheticCorpus("feasible"));
testCase.verifyEqual(unique(analysis.softGateSummary.tau)', ...
    [1e-4, 5e-4, 1e-3, 2.5e-3], "AbsTol", 0);
candidate = analysis.softGateSummary( ...
    analysis.softGateSummary.variant == "candidate" & ...
    analysis.softGateSummary.tau == 1e-4, :);
rest = [0; 2e-5; 4e-5; 6e-5; 8e-5];
testCase.verifyEqual(candidate.meanRestWeight, ...
    mean(exp(-rest./1e-4)), "AbsTol", 1e-15);
end

function testInvalidCorpusFailsClosed(testCase)
windows = syntheticCorpus("feasible");
windows.eligible(1) = ~windows.eligible(1);
testCase.verifyError(@() analyzeNoGloveStage7iHoldSupport(windows), ...
    "analyzeNoGloveStage7iHoldSupport:InvalidCorpus");
end

function testFrozenEpisodeLoaderReplaysDiagnostics(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTempDir(root));
directories = createEpisodeFixture(root, 0.20);
settings = struct("holdActionWeight", 0.20, ...
    "velocityTolerance", 1e-12, ...
    "positionMseTolerance", 1e-4);
[windows, episodes] = loadNoGloveStage7iHoldSupportCorpus( ...
    "candidate", directories, settings);
testCase.verifyEqual(height(windows), 9);
testCase.verifyEqual(height(episodes), 3);
testCase.verifyEqual(max(episodes.maximumDiagnosticReplayError), 0);
testCase.verifyEqual(sort(unique(windows.source))', ...
    ["acceptance", "steadyRest", "training"]);

path = fullfile(directories.training, "episode00001.mat");
data = load(path);
data.rewardInfoLog{1}.holdActive = 0;
save(path, "-struct", "data");
testCase.verifyError(@() loadNoGloveStage7iHoldSupportCorpus( ...
    "candidate", directories, settings), ...
    "loadNoGloveStage7iHoldSupportCorpus:ReplayMismatch");
end

function testLauncherOptionsFailClosed(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7i_hold_support_audit(struct("unknown", 1)), ...
    "run_no_glove_stage7i_hold_support_audit:UnknownOption");
testCase.verifyError(@() ...
    run_no_glove_stage7i_hold_support_audit(struct( ...
        "stage7hRunRoot", fullfile(tempdir, "missing-stage7h"))), ...
    "run_no_glove_stage7i_hold_support_audit:MissingStage7h");
end

function windows = syntheticCorpus(mode)
variants = ["control", "candidate"];
parts = cell(0, 1);
cursor = 0;
for variant = variants
    far = [0.003; 0.004; 0.005; 0.006];
    parts{end+1, 1} = makeRows(variant, "training", ...
        far(1:2), cursor, false); %#ok<AGROW>
    cursor = cursor+2;
    parts{end+1, 1} = makeRows(variant, "acceptance", ...
        far(3:4), cursor, false); %#ok<AGROW>
    cursor = cursor+2;
    switch mode
        case "feasible"
            rest = [0; 2e-5; 4e-5; 6e-5; 8e-5];
        case "nonseparable"
            rest = [0.003; 0.004; 0.005; 0.006; 0.007];
        case "timeline"
            rest = [0; 5e-5; 2e-4; 2e-4; 0];
        otherwise
            error("testNoGloveStage7iHoldSupport:Mode", ...
                "Unknown synthetic mode.");
    end
    rows = makeRows(variant, "steadyRest", rest, cursor, true);
    if mode == "timeline" && variant == "candidate"
        rows.pwm(2, :) = [2, 4, 6, 8];
        rows.effectiveAction(2, :) = 0.5.*ones(1, 4);
        rows.safetyIntervention(2, 3) = 1;
    end
    parts{end+1, 1} = rows; %#ok<AGROW>
    cursor = cursor+numel(rest);
end
windows = vertcat(parts{:});
end

function rows = makeRows(variant, source, mse, cursor, isRest)
count = numel(mse);
q = zeros(count, 4);
q(:, 1) = 2.*sqrt(mse);
zeros4 = zeros(count, 4);
stopped = true(count, 1);
eligible = mse <= 1e-4;
rows = table(repmat(variant, count, 1), ...
    repmat(source, count, 1), ones(count, 1), ones(count, 1), ...
    (1:count)', cursor+(1:count)', q, zeros4, zeros4, ...
    zeros4, zeros4, zeros4, zeros4, mse, zeros(count, 1), ...
    stopped, eligible, zeros(count, 1), zeros(count, 1), ...
    'VariableNames', ["variant", "source", "episode", ...
    "repetitionId", "step", "windowIndex", "qDecision", ...
    "qReference", "vReference", "rawAction", ...
    "effectiveAction", "pwm", "safetyIntervention", ...
    "holdPositionMse", "holdVelocityMaxAbs", "stopped", ...
    "eligible", "holdActionL2", "holdActionPenalty"]);
if ~isRest
    rows.eligible(:) = false;
end
end

function directories = createEpisodeFixture(root, holdWeight)
sources = ["training", "acceptance", "steadyRest"];
directories = struct();
for source = sources
    directory = fullfile(root, source);
    mkdir(directory);
    directories.(source) = directory;
    writeEpisode(fullfile(directory, "episode00001.mat"), holdWeight);
end
end

function writeEpisode(path, holdWeight)
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
stateLog = zeros(3, 60);
stateLog(:, layout.encoder) = [zeros(1, 4); ...
    0.02.*ones(1, 4); 0.005.*ones(1, 4)];
stateLog(:, layout.referencePosition) = zeros(3, 4);
stateLog(:, layout.referenceVelocity) = zeros(3, 4);
actionLog = [0.5.*ones(1, 4); zeros(2, 4)];
actionSatLog = actionLog;
actionPwmLog = [128.*ones(1, 4); zeros(2, 4)];
positionSafetyInterventionLog = zeros(3, 4);
mse = mean(stateLog(:, layout.encoder).^2, 2);
active = mse <= 1e-4;
rewardInfoLog = cell(3, 1);
for idx = 1:3
    actionL2 = active(idx)*mean(actionSatLog(idx, :).^2);
    rewardInfoLog{idx} = struct("holdActive", double(active(idx)), ...
        "holdPositionMse", mse(idx), ...
        "holdVelocityMaxAbs", 0, "holdActionL2", actionL2, ...
        "holdActionPenalty", holdWeight*actionL2);
end
referenceSource = "emgIntent";
observationVariant = "intentMarkov60";
stateLength = 60;
repetitionId = 1;
save(path, "stateLog", "actionLog", "actionSatLog", ...
    "actionPwmLog", "positionSafetyInterventionLog", ...
    "rewardInfoLog", "referenceSource", "observationVariant", ...
    "stateLength", "repetitionId");
end

function removeTempDir(path)
if isfolder(path) && startsWith(path, string(tempdir))
    rmdir(path, "s");
end
end
