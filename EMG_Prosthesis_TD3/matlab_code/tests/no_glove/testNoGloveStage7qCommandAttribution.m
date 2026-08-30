function tests = testNoGloveStage7qCommandAttribution
%testNoGloveStage7qCommandAttribution deterministic ETAPA 7Q tests.
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

function teardown(~)
clearConfigurablesOverride();
end

function testFullStateGradientMatchesFiniteDifference(testCase)
rng(731, "twister");
layers = [ ...
    featureInputLayer(60, "Normalization", "none", "Name", "state")
    fullyConnectedLayer(4, "Name", "action")];
model = dlnetwork(layerGraph(layers));
states = 0.1.*randn(7, 60);
analytic = evaluateFrozenActorStateGradients(model, states, ...
    "batchSize", 3);
step = 1e-3;
sampleIndices = [1, 17, 41, 49, 53, 60];
for inputIdx = sampleIndices
    plus = states;
    minus = states;
    plus(:, inputIdx) = plus(:, inputIdx)+step;
    minus(:, inputIdx) = minus(:, inputIdx)-step;
    finite = (evaluateFrozenActorModelStates(model, plus) - ...
        evaluateFrozenActorModelStates(model, minus))./(2*step);
    actual = analytic(:, :, inputIdx);
    testCase.verifyLessThan(max(abs(actual(:)-finite(:))), 2e-4);
end
testCase.verifyError(@() evaluateFrozenActorStateGradients( ...
    model, states(:, 1:59)), ...
    "evaluateFrozenActorStateGradients:InvalidStates");
end

function testBlockContractAndPrimaryCohortAreExact(testCase)
[corpus, evaluations, own] = attributionFixture("distributed");
expected = sum(corpus.zeroControlDemand, "all");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", expected);
testCase.verifyEqual(result.blockContract.block, ...
    ["emgFeatures"; "q"; "deltaQ"; ...
    "previousEffectiveAction"; "qRef"; "vRef"]);
testCase.verifyEqual(result.blockContract.firstIndex, ...
    [1; 41; 45; 49; 53; 57]);
testCase.verifyEqual(result.blockContract.lastIndex, ...
    [40; 44; 48; 52; 56; 60]);
testCase.verifyEqual(height(result.primaryComponents), expected);
testCase.verifyFalse(result.stateCounterfactualUsed);
testCase.verifyFalse(result.futureLeakageUsed);
end

function testUniquePreviousActionRequiresAllThreeEvidenceLayers(testCase)
[corpus, evaluations, own] = attributionFixture("previousAction");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"));
testCase.verifyEqual(result.scientificResult, ...
    "uniqueUpstreamBlock:previousEffectiveAction");
row = result.blockDecisionAudit( ...
    result.blockDecisionAudit.block == "previousEffectiveAction", :);
testCase.verifyGreaterThanOrEqual(row.strongGradientMotorCount, 3);
testCase.verifyGreaterThanOrEqual(row.strongAssociationMotorCount, 3);
testCase.verifyGreaterThanOrEqual(row.strongTemporalMotorCount, 3);
testCase.verifyTrue(row.uniqueBlockEligible);
end

function testDistributedEvidenceDoesNotSelectBlock(testCase)
[corpus, evaluations, own] = attributionFixture("distributed");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"));
testCase.verifyEqual(result.scientificResult, ...
    "distributedOrUnresolved");
testCase.verifyFalse(any(result.blockDecisionAudit.uniqueBlockEligible));
end

function testLateTrainingGateUsesSharedRealStates(testCase)
[corpus, evaluations, own] = attributionFixture("late");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"));
testCase.verifyEqual(result.scientificResult, "lateTrainingEmergence");
testCase.verifyTrue(result.decisionAudit.lateTrainingGatePassed);
rows = result.sharedCheckpointSummary( ...
    result.sharedCheckpointSummary.cohort == "primaryZeroDemand" & ...
    result.sharedCheckpointSummary.motor == 0, :);
testCase.verifyEqual(unique(rows.replayMode), "sharedAgent200States");
end

function testGroupedAssociationKeepsEpisodeFoldsNonempty(testCase)
[corpus, evaluations, own] = attributionFixture("previousAction");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"));
rows = result.associationSummary( ...
    result.associationSummary.checkpointEpisode == 200, :);
testCase.verifyEqual(unique(rows.foldCount), 5);
testCase.verifyGreaterThan(min(rows.minimumTestRows), 0);
selected = rows(rows.block == "previousEffectiveAction", :);
testCase.verifyGreaterThan(min(selected.crossValidatedR2), 0.9);
end

function testTransitionsUseOnlyConsecutiveRealRows(testCase)
[corpus, evaluations, own] = attributionFixture("previousAction");
result = analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"));
rows = result.temporalSummary( ...
    result.temporalSummary.checkpointEpisode == 200 & ...
    result.temporalSummary.block == "previousEffectiveAction", :);
testCase.verifyEqual(unique(rows.transitionCount), 48);
testCase.verifyGreaterThan(min(rows.absoluteContributionFraction), 0.99);
testCase.verifyLessThan(max(rows.meanLinearApproximationError), 1e-10);
end

function testInvalidPrimaryCountFailsClosed(testCase)
[corpus, evaluations, own] = attributionFixture("distributed");
testCase.verifyError(@() analyzeNoGloveStage7qAttribution( ...
    corpus, evaluations, own, "expectedPrimaryComponentCount", 1), ...
    "analyzeNoGloveStage7qAttribution:PrimaryCount");
invalid = evaluations;
invalid(1).gradients(1, 1, 1) = NaN;
testCase.verifyError(@() analyzeNoGloveStage7qAttribution( ...
    corpus, invalid, own, "expectedPrimaryComponentCount", ...
    sum(corpus.zeroControlDemand, "all")), ...
    "analyzeNoGloveStage7qAttribution:InvalidEvaluation");
end

function testLauncherFailsClosedBeforeEvidenceLoad(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7q_command_attribution(struct( ...
    "unexpected", true)), ...
    "run_no_glove_stage7q_command_attribution:UnknownOption");
missing = fullfile(tempdir, "missing-stage7q-parent");
testCase.verifyError(@() ...
    run_no_glove_stage7q_command_attribution(struct( ...
    "stage7pRunRoot", missing, "stage7nRunRoot", missing)), ...
    "loadNoGloveStage7qCheckpointSet:MissingParent");
end

function [corpus, evaluations, own] = attributionFixture(mode)
rng(732, "twister");
episodeCount = 12;
stepsPerEpisode = 5;
count = episodeCount*stepsPerEpisode;
states = 0.2.*randn(count, 60);
states(:, 49:52) = 0.18.*randn(count, 4);
source = repmat("acceptance", count, 1);
episode = repelem((1:episodeCount)', stepsPerEpisode);
step = repmat((1:stepsPerEpisode)', episodeCount, 1);
gateContext = repmat("declaredRest", count, 1);
metadata = table((1:count)', "fixture:"+compose("%04d", (1:count)'), ...
    source, episode, step, gateContext, ...
    'VariableNames', ["windowIndex", "rowId", "source", ...
    "episode", "step", "gateContext"]);
q = zeros(count, 4);
qRef = q;
vRef = zeros(count, 4);
zeroDemand = true(count, 4);
safety = zeros(count, 4);
episodes = [50, 100, 150, 200];
evaluations = repmat(struct("episode", 0, "raw", [], ...
    "effective", [], "pwm", [], "gradients", []), 4, 1);
for idx = 1:4
    switch mode
        case "previousAction"
            raw = 0.5.*states(:, 49:52);
            gradients = zeros(count, 4, 60);
            for motor = 1:4
                gradients(:, motor, 48+motor) = 0.5;
            end
        case "late"
            raw = repmat(0.2.*ones(1, 4), count, 1);
            gradients = 0.01.*ones(count, 4, 60);
            if episodes(idx) == 200
                raw = -0.6.*ones(count, 4);
            end
        otherwise
            raw = 0.1.*tanh(states(:, 1:4)+states(:, 41:44));
            gradients = 0.01.*ones(count, 4, 60);
    end
    [effective, pwm] = quantizeRowsFixture(raw);
    evaluations(idx) = struct("episode", episodes(idx), ...
        "raw", raw, "effective", effective, "pwm", pwm, ...
        "gradients", gradients);
end
corpus = struct("states", states, ...
    "rawAction", evaluations(4).raw, ...
    "effectiveAction", evaluations(4).effective, ...
    "pwm", evaluations(4).pwm, "qBefore", q, ...
    "qReference", qRef, "vReference", vRef, ...
    "zeroControlDemand", zeroDemand, ...
    "safetyIntervention", safety, "metadata", metadata);
own = repmat(struct("episode", 0, "corpus", corpus), 4, 1);
for idx = 1:4
    own(idx).episode = episodes(idx);
    own(idx).corpus.rawAction = evaluations(idx).raw;
    own(idx).corpus.effectiveAction = evaluations(idx).effective;
    own(idx).corpus.pwm = evaluations(idx).pwm;
end
end

function [effective, pwm] = quantizeRowsFixture(raw)
actuator = struct("maxPwm", 255, "activationThreshold", 0.05, ...
    "commandLevels", [0, 64, 96, 128, 160, 192, 224, 255]);
effective = zeros(size(raw));
pwm = zeros(size(raw));
for row = 1:size(raw, 1)
    [effectiveValue, pwmValue] = quantizeBaselineAction(raw(row, :), ...
        actuator.maxPwm, actuator.activationThreshold, ...
        actuator.commandLevels);
    effective(row, :) = double(effectiveValue(:))';
    pwm(row, :) = double(pwmValue(:))';
end
end
