function tests = testNoGloveStage7oBitCounterfactual
%testNoGloveStage7oBitCounterfactual deterministic ETAPA 7O tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
testCase.TestData.matlabRoot = matlabRoot;
end

function teardown(~)
clearConfigurablesOverride();
end

function testContextsAreExclusiveAndCausallyOrdered(testCase)
layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
states = zeros(8, layout.totalLength);
states(:, layout.declaredRest) = [1; 1; 1; 1; 1; 0; 0; 0];
states(:, layout.holdLatch) = [1; 0; 0; 1; 1; 0; 0; 0];
states([2, 5], layout.referencePosition) = 0.1;
states(6, layout.referenceVelocity(1)) = 0.2;
steps = (1:8)';
countdown = logical([0; 0; 0; 0; 0; 0; 1; 0]);
gateActive = false(8, 1);

actual = classifyNoGloveStage7oContexts( ...
    states, steps, countdown, gateActive);
expected = ["initialRest"; "declaredRestFar"; ...
    "nearBeforeLatch"; "latchActive"; "driftAfterLatch"; ...
    "intentionalMovement"; "lowActivityCountdown"; ...
    "uncategorized"];
testCase.verifyEqual(actual, expected);
end

function testCounterfactualPrefixIsImmutable(testCase)
rng(71, "twister");
prefix = randn(5, 60);
states = [prefix, double(rand(5, 2) > 0.5)];
states00 = states;
states10 = states;
states11 = states;
states01 = states;
states00(:, 61:62) = repmat([0, 0], 5, 1);
states10(:, 61:62) = repmat([1, 0], 5, 1);
states11(:, 61:62) = repmat([1, 1], 5, 1);
states01(:, 61:62) = repmat([0, 1], 5, 1);
testCase.verifyEqual(states00(:, 1:60), prefix);
testCase.verifyEqual(states10(:, 1:60), prefix);
testCase.verifyEqual(states11(:, 1:60), prefix);
testCase.verifyEqual(states01(:, 1:60), prefix);
testCase.verifyEqual(unique(states00(:, 61:62), "rows"), [0, 0]);
testCase.verifyEqual(unique(states10(:, 61:62), "rows"), [1, 0]);
testCase.verifyEqual(unique(states11(:, 61:62), "rows"), [1, 1]);
testCase.verifyEqual(unique(states01(:, 61:62), "rows"), [0, 1]);
end

function testActorBitGradientMatchesFiniteDifference(testCase)
rng(72, "twister");
layers = [ ...
    featureInputLayer(62, "Normalization", "none", "Name", "state")
    fullyConnectedLayer(4, "Name", "action")];
model = dlnetwork(layerGraph(layers));
states = 0.1.*randn(6, 62);
analytic = evaluateFrozenActorBitGradients(model, states, [61, 62]);
step = 1e-3;
finite = nan(size(analytic));
for bitIdx = 1:2
    plus = states;
    minus = states;
    plus(:, 60+bitIdx) = plus(:, 60+bitIdx)+step;
    minus(:, 60+bitIdx) = minus(:, 60+bitIdx)-step;
    finite(:, :, bitIdx) = ( ...
        evaluateFrozenActorModel62(model, plus) - ...
        evaluateFrozenActorModel62(model, minus))./(2*step);
end
testCase.verifyLessThan(max(abs(analytic-finite), [], "all"), 1e-4);
testCase.verifyError(@() evaluateFrozenActorBitGradients( ...
    model, states(:, 1:61), [61, 62]), ...
    "evaluateFrozenActorBitGradients:InvalidInput");
end

function testAllFiveClassificationOutcomes(testCase)
labels = ["bitsIgnored", "bitsRawOnly", "bitsBeneficial", ...
    "bitsAdversarial", "bitsContextDependent"];
for label = labels
    [effects, gradients] = classificationFixture(label);
    result = analyzeNoGloveStage7oBitEffects(effects, gradients);
    testCase.verifyEqual(result.classification, label);
    testCase.verifyFalse(result.oodIncludedInClassification);
    testCase.verifyEqual(string( ...
        result.classificationAudit.Properties.VariableNames), ...
        ["rawSensitive", "pwmSensitive", "macroNetBenefit", ...
        "positiveCellCount", "negativeCellCount", ...
        "dominanceMargin", "classification", "recommendation"]);
end
end

function testOodCombinationCannotChangePrimaryClassification(testCase)
[effects, gradients] = classificationFixture("bitsBeneficial");
before = analyzeNoGloveStage7oBitEffects(effects, gradients);
ood = effects(1, :);
ood.contrast = "oodInvalid01";
ood.causalValid = false;
ood.classificationEligible = false;
ood.deltaAbsPwm = 255;
ood.beneficialPwm = false;
ood.adversePwm = true;
ood.pwmChanged = true;
after = analyzeNoGloveStage7oBitEffects([effects; ood], gradients);
testCase.verifyEqual(before.classification, "bitsBeneficial");
testCase.verifyEqual(after.classification, before.classification);
end

function testLauncherFailsClosedBeforeAnyExecution(testCase)
testCase.verifyError(@() ...
    run_no_glove_stage7o_bit_counterfactual_audit( ...
    struct("unexpected", true)), ...
    "run_no_glove_stage7o_bit_counterfactual_audit:UnknownOption");
testCase.verifyError(@() ...
    run_no_glove_stage7o_bit_counterfactual_audit(struct( ...
    "stage7nRunRoot", fullfile(tempdir, "missing-stage7n"))), ...
    "run_no_glove_stage7o_bit_counterfactual_audit:MissingStage7n");
end

function [effects, gradients] = classificationFixture(label)
context = ["initialRest"; "latchActive"; ...
    "declaredRestFar"; "driftAfterLatch"];
contrast = ["restEffect"; "restEffect"; ...
    "latchEffect"; "latchEffect"];
count = numel(context);
checkpointEpisode = repmat(200, count, 1);
primary = true(count, 1);
motor = ones(count, 1);
causalValid = true(count, 1);
classificationEligible = true(count, 1);
deltaRaw = zeros(count, 1);
deltaAbsRaw = zeros(count, 1);
deltaAbsPwm = zeros(count, 1);
rawChanged = false(count, 1);
rawMagnitudeReduced = false(count, 1);
rawMagnitudeIncreased = false(count, 1);
pwmChanged = false(count, 1);
quantizationLevelChanged = false(count, 1);
zeroTo64 = false(count, 1);
sixtyFourToZero = false(count, 1);
saturationEntry = false(count, 1);
saturationExit = false(count, 1);
beneficialPwm = false(count, 1);
adversePwm = false(count, 1);
gradientValue = zeros(count, 1);

switch label
    case "bitsIgnored"
        % All finite differences and gradients remain zero.
    case "bitsRawOnly"
        deltaRaw(:) = 0.01;
        deltaAbsRaw(:) = 0.01;
        rawChanged(:) = true;
        rawMagnitudeIncreased(:) = true;
        gradientValue(:) = 0.01;
    case "bitsBeneficial"
        [deltaRaw, deltaAbsRaw, deltaAbsPwm, rawChanged, ...
            rawMagnitudeReduced, pwmChanged, ...
            quantizationLevelChanged, beneficialPwm, gradientValue] = ...
            pwmFixture(count, -1);
    case "bitsAdversarial"
        [deltaRaw, deltaAbsRaw, deltaAbsPwm, rawChanged, ...
            rawMagnitudeIncreased, pwmChanged, ...
            quantizationLevelChanged, adversePwm, gradientValue] = ...
            pwmFixture(count, 1);
    case "bitsContextDependent"
        deltaRaw(:) = 0.1;
        deltaAbsRaw = [-0.1; 0.1; -0.1; 0.1];
        deltaAbsPwm = [-64; 64; -64; 64];
        rawChanged(:) = true;
        rawMagnitudeReduced = deltaAbsRaw < 0;
        rawMagnitudeIncreased = deltaAbsRaw > 0;
        pwmChanged(:) = true;
        quantizationLevelChanged(:) = true;
        beneficialPwm = deltaAbsPwm < 0;
        adversePwm = deltaAbsPwm > 0;
        gradientValue(:) = 0.1;
    otherwise
        error("testNoGloveStage7oBitCounterfactual:UnknownFixture", ...
            "Unknown classification fixture %s.", label);
end

effects = table(checkpointEpisode, primary, context, motor, contrast, ...
    causalValid, classificationEligible, deltaRaw, deltaAbsRaw, ...
    deltaAbsPwm, rawChanged, rawMagnitudeReduced, ...
    rawMagnitudeIncreased, pwmChanged, quantizationLevelChanged, ...
    zeroTo64, sixtyFourToZero, saturationEntry, saturationExit, ...
    beneficialPwm, adversePwm);
bit = repmat("declaredRest", count, 1);
gradient = gradientValue;
gradients = table(checkpointEpisode, context, motor, bit, gradient);
end

function [deltaRaw, deltaAbsRaw, deltaAbsPwm, rawChanged, ...
        rawMagnitudeFlag, pwmChanged, levelChanged, pwmFlag, gradient] = ...
        pwmFixture(count, direction)
deltaRaw = repmat(0.1*direction, count, 1);
deltaAbsRaw = repmat(0.1*direction, count, 1);
deltaAbsPwm = repmat(64*direction, count, 1);
rawChanged = true(count, 1);
rawMagnitudeFlag = true(count, 1);
pwmChanged = true(count, 1);
levelChanged = true(count, 1);
pwmFlag = true(count, 1);
gradient = repmat(0.1*direction, count, 1);
end
