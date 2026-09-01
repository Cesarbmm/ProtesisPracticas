function tests = testNoGloveStage7rRealStateEmgAttribution
%testNoGloveStage7rRealStateEmgAttribution deterministic ETAPA 7R tests.
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

function testPublishedWmoosOrderIsExact(testCase)
rng(741, "twister");
emg = randn(32, 8);
actual = getWmoosFeatures(emg);
x = emg';
expected = [WMoos_F1(x); WMoos_F2(x); WMoos_F4(x); ...
    WMoos_F5(x); WMoos_F13(emg)'];
contract = getNoGloveWmoosFeatureContract();
testCase.verifyEqual(actual, expected, "AbsTol", 1e-12);
testCase.verifyEqual(contract.families.firstIndex, [1; 9; 17; 25; 33]);
testCase.verifyEqual(contract.families.lastIndex, [8; 16; 24; 32; 40]);
testCase.verifyEqual(contract.channels.energyIndex, (25:32)');
testCase.verifyFalse(contract.interpretedAsPhysicalAmplitude);
end

function testMatchingUsesOnlyCompleteObservedRows(testCase)
corpus = syntheticCorpus();
pairs = buildFixturePairs(corpus);
tableValue = pairs.table;
testCase.verifyGreaterThan(height(tableValue), 0);
testCase.verifyFalse(pairs.stateCounterfactualUsed);
testCase.verifyFalse(pairs.hybridStateUsed);
testCase.verifyEqual(pairs.statesEvaluated, corpus.states);
testCase.verifyLessThanOrEqual(max(tableValue.contextMaximum), 0.25);
testCase.verifyGreaterThanOrEqual(min(tableValue.emgRms), 0.10);
testCase.verifyNotEqual(tableValue.queryRow, tableValue.donorRow);
end

function testWithinAndCrossEpisodeContractsAreExclusive(testCase)
pairs = buildFixturePairs(syntheticCorpus());
within = pairs.table(pairs.table.pairMode == "withinEpisode", :);
cross = pairs.table(pairs.table.pairMode == "crossEpisode", :);
testCase.verifyEqual(within.queryEpisode, within.donorEpisode);
testCase.verifyNotEqual(within.queryStep, within.donorStep);
testCase.verifyNotEqual(cross.queryEpisode, cross.donorEpisode);
testCase.verifyEqual(cross.fold, ...
    pairs.metadata.fold(cross.donorRow));
testCase.verifyEqual(cross.source, pairs.metadata.source(cross.donorRow));
testCase.verifyEqual(cross.gateContext, ...
    pairs.metadata.gateContext(cross.donorRow));
end

function testEpisodeFoldsAndPermutationCannotLeak(testCase)
pairs = buildFixturePairs(syntheticCorpus());
metadata = pairs.metadata;
keys = metadata.source+":"+compose("%05d", metadata.episode);
for key = unique(keys)'
    testCase.verifyEqual(numel(unique(metadata.fold(keys == key))), 1);
end
tableValue = pairs.table;
permuted = tableValue(tableValue.permutedPairRow, :);
testCase.verifyEqual(tableValue.motor, permuted.motor);
testCase.verifyEqual(tableValue.pairMode, permuted.pairMode);
testCase.verifyEqual(tableValue.source, permuted.source);
testCase.verifyEqual(tableValue.fold, permuted.fold);
end

function testSupportGridDoesNotChangePrimaryPairs(testCase)
pairs = buildFixturePairs(syntheticCorpus());
primary = pairs.gridSummary( ...
    pairs.gridSummary.contextMaximumThreshold == 0.25 & ...
    pairs.gridSummary.minimumEmgDistance == 0.10, :);
summary = pairs.supportSummary(pairs.supportSummary.source == "ALL", :);
testCase.verifyEqual(primary.pairCount, summary.pairCount);
testCase.verifyEqual(unique(pairs.gridSummary.contextMaximumThreshold), ...
    [0.15; 0.25; 0.5]);
end

function testIncrementalModelsUsePairedRealActions(testCase)
corpus = syntheticCorpus();
pairs = buildFixturePairs(corpus);
evaluations = syntheticEvaluations(corpus.states);
result = analyzeNoGloveStage7rEmgAttribution(pairs, evaluations);
testCase.verifyEqual(height(result.pairActionTable), ...
    4*height(pairs.table));
testCase.verifyTrue(all(isfinite( ...
    result.familyModelSummary.incrementalR2)));
rows = result.familyModelSummary( ...
    result.familyModelSummary.checkpointEpisode == 200 & ...
    result.familyModelSummary.family == "standardDeviation" & ...
    result.familyModelSummary.source == "ALL", :);
testCase.verifyGreaterThan(max(rows.incrementalR2), 0);
testCase.verifyFalse(result.stateCounterfactualUsed);
testCase.verifyFalse(result.hybridStateUsed);
end

function testAllFiveScientificClassifications(testCase)
labels = ["insufficientMatchedSupport", ...
    "singleFamilySupported:familyA", ...
    "multiFamilyEmgAssociation", ...
    "distributedEmgAssociation", ...
    "emgNotIdentifiedUnderMatching"];
for label = labels
    [support, models] = classificationFixture(label);
    decision = classifyNoGloveStage7rEvidence(support, models);
    testCase.verifyEqual(decision.scientificResult, label);
end
end

function testInvalidInputsFailClosed(testCase)
corpus = syntheticCorpus();
testCase.verifyError(@() buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", 1), ...
    "buildNoGloveStage7rRealPairs:PrimaryCount");
pairs = buildFixturePairs(corpus);
evaluations = syntheticEvaluations(corpus.states);
evaluations(1).raw(1, 1) = NaN;
testCase.verifyError(@() analyzeNoGloveStage7rEmgAttribution( ...
    pairs, evaluations), ...
    "analyzeNoGloveStage7rEmgAttribution:InvalidActions");
end

function testLauncherFailsClosedBeforeEvidenceLoad(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7r_real_state_emg_attribution(struct( ...
    "unexpected", true)), ...
    "run_no_glove_stage7r_real_state_emg_attribution:UnknownOption");
missing = fullfile(tempdir, "missing-stage7r-parent");
testCase.verifyError(@() ...
    run_no_glove_stage7r_real_state_emg_attribution(struct( ...
    "stage7qRunRoot", missing)), ...
    "loadNoGloveStage7rEvidence:MissingParent");
end

function corpus = syntheticCorpus()
rng(742, "twister");
episodeCount = 25;
stepsPerEpisode = 4;
count = episodeCount*stepsPerEpisode;
states = zeros(count, 60);
states(:, 1:40) = randn(count, 40);
source = repmat("acceptance", count, 1);
episode = repelem((1:episodeCount)', stepsPerEpisode);
step = repmat((1:stepsPerEpisode)', episodeCount, 1);
gateContext = repmat("declaredRest", count, 1);
metadata = table((1:count)', "fixture:"+compose("%04d", (1:count)'), ...
    source, episode, step, gateContext, ...
    'VariableNames', ["windowIndex", "rowId", "source", ...
    "episode", "step", "gateContext"]);
corpus = struct("states", states, ...
    "zeroControlDemand", true(count, 4), "metadata", metadata);
end

function pairs = buildFixturePairs(corpus)
pairs = buildNoGloveStage7rRealPairs(corpus, ...
    "expectedPrimaryComponentCount", ...
        sum(corpus.zeroControlDemand, "all"), ...
    "minimumEmgDistance", 0.10, ...
    "emgGrid", [0.05, 0.10, 0.20], ...
    "minimumPairCount", 10, "minimumUniqueEpisodes", 5, ...
    "maximumDonorReuseFraction", 1);
end

function evaluations = syntheticEvaluations(states)
episodes = [50, 100, 150, 200];
evaluations = repmat(struct("episode", 0, "raw", [], ...
    "effective", [], "pwm", []), 4, 1);
for idx = 1:4
    raw = 0.2.*tanh(states(:, 1:4)+0.5.*states(:, 5:8));
    evaluations(idx) = struct("episode", episodes(idx), ...
        "raw", raw, "effective", raw, ...
        "pwm", round(255.*raw));
end
end

function [support, models] = classificationFixture(label)
motor = repelem((1:4)', 2);
pairMode = repmat(["withinEpisode"; "crossEpisode"], 4, 1);
source = repmat("ALL", 8, 1);
supportPassed = true(8, 1);
if label == "insufficientMatchedSupport"
    supportPassed(motor >= 3 & pairMode == "crossEpisode") = false;
end
support = table(motor, pairMode, source, supportPassed);

episodes = [50, 100, 150, 200];
sources = ["ALL", "acceptance", "steadyRest"];
families = ["allEmg", "familyA", "familyB"];
rows = cell(numel(episodes)*4*2*numel(sources)*numel(families), 1);
cursor = 0;
for episode = episodes
    for motorIdx = 1:4
        for mode = ["withinEpisode", "crossEpisode"]
            for sourceValue = sources
                for family = families
                    cursor = cursor+1;
                    rows{cursor} = table(episode, motorIdx, mode, ...
                        sourceValue, family, 0, 0, 0, ...
                        'VariableNames', ["checkpointEpisode", "motor", ...
                        "pairMode", "source", "family", ...
                        "incrementalR2", "signAccuracyGain", ...
                        "permutationMargin"]);
                end
            end
        end
    end
end
models = vertcat(rows{:});
if label == "singleFamilySupported:familyA"
    models = makeCandidatePass(models, "familyA");
elseif label == "multiFamilyEmgAssociation"
    models = makeCandidatePass(models, "familyA");
    models = makeCandidatePass(models, "familyB");
elseif label == "distributedEmgAssociation"
    models = makeCandidatePass(models, "allEmg");
end
end

function models = makeCandidatePass(models, family)
candidate = models.family == family;
crossAll = candidate & models.source == "ALL" & ...
    models.pairMode == "crossEpisode";
models.incrementalR2(crossAll) = 0.20;
agent200All = candidate & models.checkpointEpisode == 200 & ...
    models.source == "ALL";
models.incrementalR2(agent200All) = 0.20;
models.signAccuracyGain(agent200All) = 0.10;
models.permutationMargin(agent200All) = 0.10;
sourceRows = candidate & models.checkpointEpisode == 200 & ...
    models.source ~= "ALL" & models.pairMode == "crossEpisode";
models.incrementalR2(sourceRows) = 0.05;
end
