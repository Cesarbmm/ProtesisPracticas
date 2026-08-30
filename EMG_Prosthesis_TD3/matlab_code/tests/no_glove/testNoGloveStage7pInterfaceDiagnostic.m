function tests = testNoGloveStage7pInterfaceDiagnostic
%testNoGloveStage7pInterfaceDiagnostic deterministic ETAPA 7P tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
testCase.TestData.actuator = actuatorContract();
end

function teardown(~)
clearConfigurablesOverride();
end

function testCanonicalSweepHasSignedZeroTo64Jump(testCase)
corpus = syntheticCorpus("quantizer");
result = analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator);
testCase.verifyTrue(result.canonicalDiscontinuityPassed);
testCase.verifyTrue(result.nearCounterfactualPassed);
testCase.verifyEqual(result.futureAblationSelection, ...
    "quantizerPriority");
sweep = result.canonicalSweep;
below = sweep.offsetLabel == "minusEpsilon";
at = sweep.offsetLabel == "threshold";
testCase.verifyEqual(abs(sweep.pwm(below)), zeros(sum(below), 1));
testCase.verifyEqual(abs(sweep.pwm(at)), 64.*ones(sum(at), 1));
testCase.verifyEqual(abs(sweep.effectiveAction(at)), ...
    repmat(64/255, sum(at), 1), "AbsTol", 1e-12);
end

function testNearThresholdCounterfactualPreservesOnlyInterface(testCase)
corpus = syntheticCorpus("quantizer");
result = analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator);
rows = result.componentTable(result.componentTable.nearThreshold, :);
testCase.verifyGreaterThan(height(rows), 0);
testCase.verifyTrue(all(rows.zeroTo64 | rows.sixtyFourToZero));
testCase.verifyEqual(abs(rows.deltaPwm), ...
    repmat(64, height(rows), 1));
testCase.verifyEqual(abs(rows.deltaEffective), ...
    repmat(64/255, height(rows), 1), "AbsTol", 1e-12);
testCase.verifyLessThanOrEqual(abs(rows.deltaRaw), ...
    repmat(0.010001, height(rows), 1));
testCase.verifyEqual(rows.qBefore, ...
    result.componentTable.qBefore(result.componentTable.nearThreshold));
end

function testSelectionFallsThroughToGatePriority(testCase)
corpus = syntheticCorpus("gate");
result = analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator);
testCase.verifyFalse(result.nearCounterfactualPassed);
testCase.verifyLessThan(result.nearThresholdFraction, 0.01);
testCase.verifyGreaterThanOrEqual( ...
    result.gateInactiveReferenceFraction, 0.10);
testCase.verifyGreaterThanOrEqual( ...
    result.gateInactiveReferenceNonzeroPwmFraction, 0.10);
testCase.verifyEqual(result.futureAblationSelection, "gatePriority");
end

function testSelectionCanRejectBothHypotheses(testCase)
corpus = syntheticCorpus("none");
result = analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator);
testCase.verifyEqual(result.futureAblationSelection, ...
    "noAblationSupported");
end

function testSafetyAttributionRemainsDescriptive(testCase)
corpus = syntheticCorpus("quantizer");
result = analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator);
rows = result.componentTable(result.componentTable.safetyIntervened, :);
testCase.verifyTrue(any(rows.safetyAttribution == "outwardBoundary"));
testCase.verifyTrue(any(rows.safetyAttribution == "boundaryOther"));
testCase.verifyTrue(any(rows.safetyAttribution == "interior"));
testCase.verifyFalse(result.safetyChanged);
testCase.verifyFalse(result.quantizationChanged);
testCase.verifyFalse(result.gateChanged);
end

function testLoaderReplaysCausalAlignmentAndQuantization(testCase)
root = string(tempname);
acceptance = fullfile(root, "acceptance");
steadyRest = fullfile(root, "steady_rest");
mkdir(acceptance);
mkdir(steadyRest);
cleanup = onCleanup(@() removeTempDir(root));
writeSyntheticEpisode(acceptance, 1, testCase.TestData.actuator);
writeSyntheticEpisode(steadyRest, 1, testCase.TestData.actuator);
sources = struct("acceptance", acceptance, "steadyRest", steadyRest);
corpus = loadNoGloveStage7pInterfaceCorpus( ...
    sources, testCase.TestData.actuator);
testCase.verifyEqual(corpus.windowCount, 6);
testCase.verifyEqual(height(corpus.inventory), 2);
testCase.verifyEqual(corpus.metadata.gateContext(1), "initialRest");
testCase.verifyEqual(corpus.metadata.gateContext(2), "declaredRest");
testCase.verifyEqual(max(corpus.alignmentAudit.pwmMismatchCount), 0);
testCase.verifyEqual(max( ...
    corpus.alignmentAudit.nextStateMaximumError), 0, "AbsTol", 0);
testCase.verifyFalse(corpus.trainingLogsUsed);
testCase.verifyFalse(corpus.futureLeakageUsed);
end

function testInvalidInputsFailClosed(testCase)
corpus = syntheticCorpus("quantizer");
invalid = corpus;
invalid.rawAction(1, 1) = NaN;
testCase.verifyError(@() analyzeNoGloveStage7pInterface( ...
    invalid, testCase.TestData.actuator), ...
    "analyzeNoGloveStage7pInterface:InvalidArrays");
testCase.verifyError(@() analyzeNoGloveStage7pInterface( ...
    corpus, testCase.TestData.actuator, ...
    "thresholdNeighborhood", 0.06), ...
    "analyzeNoGloveStage7pInterface:InvalidNeighborhood");
end

function testLauncherFailsClosedBeforeLoadingEvidence(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7p_interface_diagnostic( ...
    struct("unexpected", true)), ...
    "run_no_glove_stage7p_interface_diagnostic:UnknownOption");
missing = fullfile(tempdir, "missing-stage7p-parent");
testCase.verifyError(@() ...
    run_no_glove_stage7p_interface_diagnostic(struct( ...
    "stage7oRunRoot", missing, "stage7nRunRoot", missing)), ...
    "run_no_glove_stage7p_interface_diagnostic:MissingParent");
end

function corpus = syntheticCorpus(mode)
actuator = actuatorContract();
count = 4;
switch mode
    case "quantizer"
        raw = [ ...
            -0.050, 0.049, 0.055, -0.041; ...
             0.045, 0.051, -0.059, 0.20; ...
             0.049, -0.050, 0.04, -0.06; ...
             0.20, -0.20, 0.40, -0.40];
        contexts = ["gateActive"; "gateActive"; ...
            "declaredRest"; "initialRest"];
    case "gate"
        raw = repmat([0.20, -0.20, 0.40, -0.40], count, 1);
        contexts = repmat("gateActive", count, 1);
    otherwise
        raw = repmat([0.20, -0.20, 0.40, -0.40], count, 1);
        contexts = repmat("declaredRest", count, 1);
end
[effective, pwm] = quantizeFixtureRows(raw, actuator);
qBefore = 0.5.*ones(count, 4);
qBefore(1, 1:2) = 0;
qAfter = qBefore;
qReference = qBefore;
vReference = zeros(count, 4);
if mode == "quantizer"
    vReference(1, 1:2) = [0.01, -0.01];
end
referenceActive = abs(vReference) >= 0.005;
zeroControlDemand = ~referenceActive & abs(qReference-qBefore) <= 1e-4;
safety = zeros(count, 4);
safety(1, 1:3) = 1;
gateActive = contexts == "gateActive";
activeMotorCount = sum(referenceActive, 2);
partial = gateActive & activeMotorCount > 0 & activeMotorCount < 4;
metadata = table((1:count)', "row"+string((1:count)'), ...
    repmat("fixture", count, 1), ones(count, 1), (1:count)', ...
    contexts, gateActive, activeMotorCount, partial, ...
    'VariableNames', ["windowIndex", "rowId", "source", ...
    "episode", "step", "gateContext", "gateActive", ...
    "activeMotorCount", "partialMotorReference"]);
corpus = struct("rawAction", raw, "effectiveAction", effective, ...
    "pwm", pwm, "qBefore", qBefore, "qAfter", qAfter, ...
    "qReference", qReference, "vReference", vReference, ...
    "referenceActive", referenceActive, ...
    "zeroControlDemand", zeroControlDemand, ...
    "safetyIntervention", safety, "metadata", metadata);
end

function writeSyntheticEpisode(directory, episode, actuator)
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
count = 3;
stateLog = zeros(count, layout.totalLength);
q = [zeros(1, 4); 0.1.*ones(1, 4); 0.2.*ones(1, 4)];
stateLog(:, layout.encoder) = q;
stateLog(:, layout.referencePosition) = q;
actionLog = [zeros(1, 4); 0.05.*ones(1, 4); -0.05.*ones(1, 4)];
[actionSatLog, actionPwmLog] = quantizeFixtureRows(actionLog, actuator);
trackingPredictionHistory = [q(2:3, :); 0.3.*ones(1, 4)];
referenceHistory = q;
positionSafetyInterventionLog = zeros(count, 4);
intentProvenanceLog = cell(count, 1);
for idx = 1:count
    nextIdx = min(idx+1, count);
    intentProvenanceLog{idx} = struct( ...
        "schemaVersion", 1, "transitionStep", idx, ...
        "activity", 0, "gateActive", false, "isRest", true, ...
        "lowActivityCountdown", false, ...
        "referencePositionAfter", q(nextIdx, :), ...
        "referenceVelocityAfter", zeros(1, 4), ...
        "zeroReferenceReason", "decoderRest");
end
referenceSource = "emgIntent";
observationVariant = "intentMarkov60";
stateLength = 60;
simulationPositionSafety = struct("enabled", true);
path = fullfile(directory, sprintf("episode%05d.mat", episode));
save(path, "stateLog", "actionLog", "actionSatLog", ...
    "actionPwmLog", "trackingPredictionHistory", ...
    "referenceHistory", "positionSafetyInterventionLog", ...
    "intentProvenanceLog", "referenceSource", ...
    "observationVariant", "stateLength", ...
    "simulationPositionSafety");
end

function [effective, pwm] = quantizeFixtureRows(raw, actuator)
effective = zeros(size(raw));
pwm = zeros(size(raw));
for idx = 1:size(raw, 1)
    [e, p] = quantizeBaselineAction(raw(idx, :), ...
        actuator.maxPwm, actuator.activationThreshold, ...
        actuator.commandLevels);
    effective(idx, :) = double(e(:))';
    pwm(idx, :) = double(p(:))';
end
end

function actuator = actuatorContract()
actuator = struct("maxPwm", 255, "activationThreshold", 0.05, ...
    "commandLevels", [0, 64, 96, 128, 160, 192, 224, 255]);
end

function removeTempDir(root)
if isfolder(root) && startsWith(root, string(tempdir))
    rmdir(root, "s");
end
end
