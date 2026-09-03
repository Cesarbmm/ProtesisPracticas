function tests = testNoGloveStage7uExplorationDecayRate
%testNoGloveStage7uExplorationDecayRate deterministic tests for the
%ETAPA 7U exploration-decay-rate audit fix.
tests = functiontests(localfunctions);
end

function setupOnce(~)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
end

function testMatchesHistoricalRateAtReferenceHorizon(testCase)
% At the exact ETAPA 6 horizon (200 episodes), the scaled rate must
% reproduce the historical 1e-4 rate exactly (same total steps).
rate = computeNoGloveStage7uExplorationDecayRate(200);
testCase.verifyEqual(rate, 1e-4, "RelTol", 1e-10);
end

function testTenThousandEpisodesGivesMuchSmallerRate(testCase)
% Root cause of the 2026-09-03_00-49-48-172 campaign's actor saturation:
% reusing 1e-4 unchanged over 10000 episodes reaches the exploration
% floor almost immediately. The scaled rate must be far smaller, and the
% resulting end-of-training multiplier must match Agent200's own
% (~0.295), not collapse near-instantly.
rate = computeNoGloveStage7uExplorationDecayRate(10000);
testCase.verifyLessThan(rate, 1e-4 / 40);
totalSteps = 10000 * 61;
endMultiplier = exp(-rate * totalSteps);
referenceMultiplier = exp(-1e-4 * 200 * 61);
testCase.verifyEqual(endMultiplier, referenceMultiplier, "RelTol", 1e-9);
end

function testMonotonicDecreaseWithHorizon(testCase)
rShort = computeNoGloveStage7uExplorationDecayRate(500);
rLong = computeNoGloveStage7uExplorationDecayRate(10000);
testCase.verifyGreaterThan(rShort, rLong);
end

function testCustomReferenceIsHonored(testCase)
rate = computeNoGloveStage7uExplorationDecayRate(200, ...
    "referenceEpisodes", 200, "referenceDecayRate", 1e-4);
testCase.verifyEqual(rate, 1e-4, "RelTol", 1e-10);
end
