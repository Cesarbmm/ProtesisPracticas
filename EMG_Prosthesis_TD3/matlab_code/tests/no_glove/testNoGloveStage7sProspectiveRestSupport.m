function tests = testNoGloveStage7sProspectiveRestSupport
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(tempname);
mkdir(root);
testCase.TestData.root = root;
testCase.TestData.cleanup = onCleanup(@() removeRoot(root));
base = buildNoGloveStage6SyntheticCorpus(11);
profile = struct( ...
    "referenceSource", "emgIntent", ...
    "observationVariant", "intentMarkov60", ...
    "intentCalibration", base.calibration, ...
    "intentExpectedContext", base.expectedContext);
testCase.TestData.base = base;
testCase.TestData.profile = profile;
end

function testSyntheticCaptureContractIsCausalAndDeterministic(testCase)
scale = ones(1, 40);
first = buildNoGloveStage7sRestSupportCorpus( ...
    testCase.TestData.profile, scale, ...
    "episodeCount", 14, "windowCount", 5);
second = buildNoGloveStage7sRestSupportCorpus( ...
    testCase.TestData.profile, scale, ...
    "episodeCount", 14, "windowCount", 5);
testCase.verifyEqual(numel(first.emgs), 14);
testCase.verifyEqual(height(first.designTable), 70);
testCase.verifyEqual(first.emgs, second.emgs);
testCase.verifyEqual(first.designTable, second.designTable);
testCase.verifyTrue(all(struct2array(first.checks)));
testCase.verifyEqual(first.designTable.aggregateActivity, ...
    0.13*ones(70, 1), "AbsTol", 1e-10);
testCase.verifyFalse(any(first.designTable.gateActive));
testCase.verifyFalse(any(first.designTable.lowActivityCountdown));
testCase.verifyGreaterThanOrEqual( ...
    first.minimumCrossDominantEmgRms, 0.50);
testCase.verifyTrue(all(cellfun(@(value) ...
    all(value(:, 8) == 0), first.emgs), "all"));
end

function testInvalidSyntheticContractsFailClosed(testCase)
testCase.verifyError(@() buildNoGloveStage7sRestSupportCorpus( ...
    testCase.TestData.profile, ones(1, 40), ...
    "episodeCount", 13, "windowCount", 5), ...
    "buildNoGloveStage7sRestSupportCorpus:OddEpisodeCount");
testCase.verifyError(@() buildNoGloveStage7sRestSupportCorpus( ...
    testCase.TestData.profile, ones(1, 39), ...
    "episodeCount", 14, "windowCount", 5), ...
    "buildNoGloveStage7sRestSupportCorpus:InvalidScale");
testCase.verifyError(@() buildNoGloveStage7sRestSupportCorpus( ...
    testCase.TestData.profile, ones(1, 40), ...
    "episodeCount", 14, "windowCount", 5, ...
    "targetActivity", 0.15), ...
    "buildNoGloveStage7sRestSupportCorpus:ProtocolChanged");
end

function testStage7rPairingAcceptsOnlyCompleteFrozenScales(testCase)
corpus = pairingFixture();
emgScale = 2*ones(1, 40);
contextScale = 3*ones(1, 20);
pairs = buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", 80, ...
    "emgScaleOverride", emgScale, ...
    "contextScaleOverride", contextScale);
testCase.verifyEqual(pairs.emgScale, emgScale);
testCase.verifyEqual(pairs.contextScale, contextScale);
testCase.verifyEqual(pairs.scaleSource, "frozenOverride");
testCase.verifyError(@() buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", 80, ...
    "emgScaleOverride", emgScale), ...
    "buildNoGloveStage7rRealPairs:IncompleteScaleOverride");
testCase.verifyError(@() buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", 80, ...
    "emgScaleOverride", [emgScale(1:end-1), 0], ...
    "contextScaleOverride", contextScale), ...
    "buildNoGloveStage7rRealPairs:InvalidScaleOverride");
end

function testGlobalFoldCoverageIsFivePerRepresentedSource(testCase)
corpus = twoSourcePairingFixture();
pairs = buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", 160, ...
    "emgScaleOverride", ones(1, 40), ...
    "contextScaleOverride", ones(1, 20), ...
    "minimumPairCount", 1, "minimumUniqueEpisodes", 1, ...
    "maximumDonorReuseFraction", 1);
row = pairs.supportSummary( ...
    pairs.supportSummary.source == "ALL" & ...
    pairs.supportSummary.motor == 1 & ...
    pairs.supportSummary.pairMode == "crossEpisode", :);
testCase.verifyEqual(row.representedSourceCount, 2);
testCase.verifyEqual(row.observedFoldCount, 10);
testCase.verifyEqual(row.expectedSourceFoldCount, 10);
testCase.verifyTrue(row.foldCoveragePassed);
testCase.verifyTrue(row.supportPassed);
end

function testSupportGatePassesOnlyCompleteProspectiveEvidence(testCase)
support = passingSupport();
acquisition = passingAcquisition();
gate = classifyNoGloveStage7sSupportGate(acquisition, support);
testCase.verifyTrue(gate.passed);
testCase.verifyEqual(gate.scientificResult, ...
    "prospectiveSupportPassed");
testCase.verifyTrue(gate.modelsAuthorized);

support.supportPassed(support.source == "steadyRest" & ...
    support.pairMode == "crossEpisode" & support.motor <= 2) = false;
failed = classifyNoGloveStage7sSupportGate(acquisition, support);
testCase.verifyFalse(failed.passed);
testCase.verifyEqual(failed.scientificResult, ...
    "prospectiveSupportFailed");
testCase.verifyFalse(failed.modelsAuthorized);
end

function testSupportGateRejectsSemanticOrOperationalLeakage(testCase)
support = passingSupport();
fields = ["declaredRestActivityExact", "acceptanceInvariant", ...
    "frozenScalesUsed", "completeObservedStates"];
for field = fields
    acquisition = passingAcquisition();
    acquisition.(field) = false;
    gate = classifyNoGloveStage7sSupportGate(acquisition, support);
    testCase.verifyFalse(gate.passed, field);
end
acquisition = passingAcquisition();
acquisition.hybridStateUsed = true;
testCase.verifyFalse(classifyNoGloveStage7sSupportGate( ...
    acquisition, support).passed);
acquisition = passingAcquisition();
acquisition.stateCounterfactualUsed = true;
testCase.verifyFalse(classifyNoGloveStage7sSupportGate( ...
    acquisition, support).passed);
end

function testEvaluationProfileForbidsTrainingAndHardware(testCase)
base = testCase.TestData.base;
datasetPath = fullfile(testCase.TestData.root, "stage7s_fixture.mat");
emgs = {zeros(80, 8), zeros(80, 8)};
metadata = struct();
save(datasetPath, "emgs", "metadata");
checkpointPath = fullfile(testCase.TestData.root, "Agent200.mat");
placeholder = 1;
save(checkpointPath, "placeholder");
profile = buildNoGloveStage6Override(base.calibration, ...
    base.expectedContext, 7701, 200, 50, datasetPath, ...
    testCase.TestData.root, "intentMarkov60");
profile.run_training = false;
profile.newTraining = false;
profile.agentFile = checkpointPath;
profile.randomSeed = 7701;
profile.simulationPositionSafety = ...
    buildNoGloveSimulationPositionSafety(base.calibration, true);
profile.intentRewardPositionWeight = 1.00;
profile.intentRewardVelocityWeight = 0.00;
profile.intentRewardActionWeight = 0.05;
profile.intentRewardDeltaActionWeight = 0.05;
profile.intentRewardSaturationWeight = 0.02;
profile.intentRewardSoftActionLimit = 0.90;
profile.simOpts = rlSimulationOptions("MaxSteps", 20, ...
    "NumSimulations", 80, "StopOnError", "on", ...
    "UseParallel", false);
audit = validateNoGloveStage7sEvaluationProfile( ...
    profile, checkpointPath, datasetPath);
testCase.verifyTrue(all(struct2array(audit)));

profile.run_training = true;
testCase.verifyError(@() validateNoGloveStage7sEvaluationProfile( ...
    profile, checkpointPath, datasetPath), ...
    "validateNoGloveStage7sEvaluationProfile:UnsafeProfile");
end

function testClassifierRejectsMissingRowsAndFields(testCase)
support = passingSupport();
acquisition = rmfield(passingAcquisition(), "allFinite");
testCase.verifyError(@() classifyNoGloveStage7sSupportGate( ...
    acquisition, support), ...
    "classifyNoGloveStage7sSupportGate:InvalidAcquisition");
testCase.verifyError(@() classifyNoGloveStage7sSupportGate( ...
    passingAcquisition(), support(1:end-1, :)), ...
    "classifyNoGloveStage7sSupportGate:MissingSupportRows");
end

function testLauncherFailsBeforeCreatingOutputWithMissingParent(testCase)
output = fullfile(testCase.TestData.root, "forbidden_output");
options = struct( ...
    "resultsRoot", output, ...
    "stage7rRunRoot", fullfile(testCase.TestData.root, "missing7r"), ...
    "stage7qRunRoot", fullfile(testCase.TestData.root, "missing7q"), ...
    "stage7pRunRoot", fullfile(testCase.TestData.root, "missing7p"), ...
    "stage7nRunRoot", fullfile(testCase.TestData.root, "missing7n"));
testCase.verifyError(@() ...
    run_no_glove_stage7s_prospective_rest_support(options), ...
    "loadNoGloveStage7sEvidence:MissingStage7r");
testCase.verifyFalse(isfolder(output));
end

function corpus = pairingFixture()
rng(71, "twister");
count = 20;
states = randn(count, 60);
zeroControlDemand = true(count, 4);
windowIndex = (1:count)';
rowId = "row"+string(windowIndex);
source = repmat("acceptance", count, 1);
episode = repelem((1:5)', 4);
step = repmat((1:4)', 5, 1);
gateContext = repmat("initialRest", count, 1);
metadata = table(windowIndex, rowId, source, episode, step, gateContext);
corpus = struct("states", states, ...
    "zeroControlDemand", zeroControlDemand, "metadata", metadata);
end

function corpus = twoSourcePairingFixture()
sourceNames = ["acceptance", "steadyRest"];
count = 40;
states = zeros(count, 60);
zeroControlDemand = true(count, 4);
windowIndex = (1:count)';
rowId = strings(count, 1);
source = strings(count, 1);
episode = zeros(count, 1);
step = zeros(count, 1);
gateContext = repmat("initialRest", count, 1);
cursor = 0;
for sourceIdx = 1:2
    for episodeIdx = 1:10
        for stepIdx = 1:2
            cursor = cursor+1;
            source(cursor) = sourceNames(sourceIdx);
            episode(cursor) = episodeIdx;
            step(cursor) = stepIdx;
            rowId(cursor) = source(cursor)+":"+episodeIdx+":"+stepIdx;
            signValue = 2*mod(episodeIdx, 2)-1;
            if stepIdx == 2
                signValue = -signValue;
            end
            states(cursor, 1:40) = 2*signValue;
        end
    end
end
metadata = table(windowIndex, rowId, source, episode, step, gateContext);
corpus = struct("states", states, ...
    "zeroControlDemand", zeroControlDemand, "metadata", metadata);
end

function support = passingSupport()
motor = [(1:4)'; (1:4)'; (1:4)'];
pairMode = [repmat("crossEpisode", 8, 1); ...
    repmat("withinEpisode", 4, 1)];
source = [repmat("steadyRest", 4, 1); repmat("ALL", 8, 1)];
supportPassed = true(12, 1);
support = table(motor, pairMode, source, supportPassed);
end

function value = passingAcquisition()
value = struct( ...
    "episodeCount", 80, "stateCount", 1600, ...
    "allFinite", true, "state60", true, ...
    "positionLimitsRespected", true, ...
    "gateActiveCount", 0, "countdownCount", 0, ...
    "nonzeroReferenceVelocityCount", 0, ...
    "referenceHoldMaximumError", 0, ...
    "declaredRestActivityExact", true, ...
    "alignmentPassed", true, "acceptanceInvariant", true, ...
    "frozenScalesUsed", true, "completeObservedStates", true, ...
    "hybridStateUsed", false, "stateCounterfactualUsed", false, ...
    "futureLeakageUsed", false, "hardwareUsed", false, ...
    "trainingUsed", false);
end

function removeRoot(root)
if isfolder(root)
    rmdir(root, "s");
end
end
