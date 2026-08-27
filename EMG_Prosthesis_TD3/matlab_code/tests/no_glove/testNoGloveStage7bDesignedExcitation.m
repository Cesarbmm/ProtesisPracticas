function tests = testNoGloveStage7bDesignedExcitation
%testNoGloveStage7bDesignedExcitation deterministic ETAPA 7B tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testPath = string(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(fileparts(testPath)));
addpath(genpath(fullfile(matlabRoot, "src")));
config = buildNoGloveStage2OfflineConfig(11);
dataset = buildSyntheticEmgIntentDataset(config);
calibration = calibrateEmgIntent( ...
    dataset.restCapture, dataset.instructionTrials, ...
    config.calibrationOptions);
expected = buildExpectedContext(dataset, config, calibration);
corpus = buildNoGloveStage7bTemporalCorpus(calibration, expected);
testCase.TestData.calibration = calibration;
testCase.TestData.expected = expected;
testCase.TestData.corpus = corpus;
end

function testTemporalCorpusIsDeterministicAndComplete(testCase)
repeat = buildNoGloveStage7bTemporalCorpus( ...
    testCase.TestData.calibration, testCase.TestData.expected);
corpus = testCase.TestData.corpus;

testCase.verifySize(corpus.emgs, [8 2]);
testCase.verifyEqual(corpus.expectedSimulationCount, 16);
testCase.verifyEqual(height(corpus.protocolTable), 16);
testCase.verifyEqual(height(corpus.validationTable), 16);
testCase.verifyTrue(all(corpus.validationTable.isValid));
testCase.verifyEqual(corpus.emgs, repeat.emgs);
testCase.verifyEqual(corpus.calibrationContentSha256, ...
    testCase.TestData.calibration.contentSha256);
testCase.verifyFalse(corpus.agent7250Used);
testCase.verifyFalse(corpus.hardwareUsed);
end

function testProfilesHavePreRegisteredTemporalPhases(testCase)
corpus = testCase.TestData.corpus;
phaseCounts = groupsummary(corpus.windowProtocol, "phase");
expectedCounts = table( ...
    ["final_hold"; "plateau"; "pre_rest"; "ramp_down"; "ramp_up"], ...
    [20; 12; 8; 6; 6], ...
    'VariableNames', ["phase", "GroupCount"]);
phaseCounts = sortrows(phaseCounts(:, ["phase", "GroupCount"]), "phase");
testCase.verifyEqual(phaseCounts, expectedCounts);
testCase.verifyTrue(all(corpus.validationTable.initialRestValid));
testCase.verifyTrue(all(corpus.validationTable.finalHoldValid));
testCase.verifyTrue(all(corpus.validationTable.intentSignValid));
testCase.verifyTrue(all(corpus.validationTable.axisDominanceValid));
testCase.verifyGreaterThanOrEqual( ...
    min(corpus.validationTable.axisDominanceRatio), 1.25);
end

function testKnownInteriorDelayPassesDesignedGate(testCase)
[values, pairing, protocol] = makeMatchedFixture(2);
analysis = analyzeNoGloveStage7bDesignedResponse( ...
    values, pairing, protocol, "designed_temporal", ...
    "targetMotors", [2 3], "maxLagSteps", 5);

agentRows = analysis.designedGateTable( ...
    analysis.designedGateTable.commandSource == "Agent200", :);
testCase.verifyTrue(all(agentRows.causalCompensationCandidate));
testCase.verifyEqual(agentRows.maximumPreReferenceCommandFraction, ...
    zeros(height(agentRows), 1));
testCase.verifyEqual(agentRows.medianSelectedLagSteps, ...
    2*ones(height(agentRows), 1));
testCase.verifyTrue(analysis.causalCompensationGatePassed);
testCase.verifyEqual(analysis.primaryDecision.classification, ...
    "designedCausalCandidate");
testCase.verifyFalse(analysis.compensationInterventionExecuted);
testCase.verifyFalse(analysis.filteredReferenceInterventionExecuted);
testCase.verifyFalse(analysis.dtwCalculated);
testCase.verifyFalse(analysis.runTraining);
testCase.verifyFalse(analysis.agent7250Loaded);
testCase.verifyFalse(analysis.hardwareUsed);
end

function testPreReferenceCommandRejectsTemporalCandidate(testCase)
[values, pairing, protocol] = makeMatchedFixture(2);
preReference = values.commandSource == "Agent200" & values.step < 11;
values.appliedPwm(preReference) = 32;
values.effectiveAction(preReference) = 32/255;
analysis = analyzeNoGloveStage7bDesignedResponse( ...
    values, pairing, protocol, "designed_temporal", ...
    "targetMotors", [2 3], "maxLagSteps", 5);

agentRows = analysis.designedGateTable( ...
    analysis.designedGateTable.commandSource == "Agent200", :);
testCase.verifyTrue(all(agentRows.lagGatePassed));
testCase.verifyFalse(any(agentRows.eventGatePassed));
testCase.verifyFalse(any(agentRows.causalCompensationCandidate));
testCase.verifyGreaterThan( ...
    min(agentRows.maximumPreReferenceCommandFraction), 0);
testCase.verifyFalse(analysis.causalCompensationGatePassed);
end

function testBoundaryDelayDoesNotAuthorizeCompensation(testCase)
[values, pairing, protocol] = makeMatchedFixture(5);
analysis = analyzeNoGloveStage7bDesignedResponse( ...
    values, pairing, protocol, "designed_temporal", ...
    "targetMotors", [2 3], "maxLagSteps", 5);

agentRows = analysis.designedGateTable( ...
    analysis.designedGateTable.commandSource == "Agent200", :);
testCase.verifyFalse(any(agentRows.causalCompensationCandidate));
testCase.verifyEqual(agentRows.classification, ...
    repmat("unresolvedAtPreRegisteredBound", height(agentRows), 1));
testCase.verifyFalse(analysis.causalCompensationGatePassed);
end

function testPairingAndPositionViolationsAreRejected(testCase)
[values, pairing, protocol] = makeMatchedFixture(2);
badPairing = pairing;
badPairing.referenceMaxAbs(1) = 1e-3;
testCase.verifyError(@() analyzeNoGloveStage7bDesignedResponse( ...
    values, badPairing, protocol, "designed_temporal"), ...
    "analyzeNoGloveStage7bDesignedResponse:PairingOrSafetyFailure");

badValues = values;
badValues.positionViolation(1) = true;
testCase.verifyError(@() analyzeNoGloveStage7bDesignedResponse( ...
    badValues, pairing, protocol, "designed_temporal"), ...
    "analyzeNoGloveStage7bDesignedResponse:PairingOrSafetyFailure");
end

function expected = buildExpectedContext(dataset, config, calibration)
options = config.calibrationOptions;
units = struct("rawEmg", dataset.restCapture.rawEmgUnits, ...
    "envelope", options.envelopeUnits, ...
    "position", options.positionUnits, ...
    "velocity", options.velocityUnits, ...
    "acceleration", options.accelerationUnits);
expected = struct( ...
    "userId", dataset.restCapture.userId, ...
    "sessionId", dataset.restCapture.sessionId, ...
    "channelOrder", dataset.restCapture.channelOrder, ...
    "sampleRateHz", dataset.restCapture.sampleRateHz, ...
    "windowLengthSamples", dataset.windowLengthSamples, ...
    "hopLengthSamples", dataset.hopLengthSamples, ...
    "dataProvenance", dataset.restCapture.dataProvenance, ...
    "motorOrder", options.motorOrder, "units", units, ...
    "synergyMatrixVersion", options.synergyMatrixVersion, ...
    "instructionProtocolVersion", options.instructionProtocolVersion, ...
    "sourceDomain", "rawEmgSameSession", ...
    "calibrationContentSha256", calibration.contentSha256);
end

function [values, pairing, protocol] = makeMatchedFixture(agentDelay)
periodSec = 0.2;
stepCount = 60;
repetitionCount = 4;
sources = ["Agent200", "conventionalP"];
componentCells = cell(numel(sources)*repetitionCount*2*2, 1);
protocolRows = repmat(struct("profileId", "", "repetitionId", 0, ...
    "side", 0, "synergyAxis", "primary", "directionName", "", ...
    "expectedIntentSign", 0), repetitionCount*2, 1);
pairRows = repmat(struct("episode", 0, "repetitionId", 0, ...
    "referenceMaxAbs", 0, "referenceVelocityMaxAbs", 0, ...
    "initialPositionMaxAbs", 0, ...
    "sourceTemporalAlignmentMaxAbs", 0), repetitionCount*2, 1);
cellIdx = 0;
episode = 0;
for repetition = 1:repetitionCount
    for side = 1:2
        episode = episode + 1;
        direction = 1;
        directionName = "positive";
        initial = 0.2;
        if side == 2
            direction = -1;
            directionName = "negative";
            initial = 0.8;
        end
        referenceVelocity = zeros(stepCount, 1);
        referenceVelocity(11:30) = direction*0.02;
        reference = initial + periodSec*cumsum(referenceVelocity);
        protocolRows(episode).profileId = sprintf("primary_%s_r%02d", ...
            directionName, repetition);
        protocolRows(episode).repetitionId = repetition;
        protocolRows(episode).side = side;
        protocolRows(episode).directionName = directionName;
        protocolRows(episode).expectedIntentSign = direction;
        pairRows(episode).episode = episode;
        pairRows(episode).repetitionId = repetition;
        for sourceIdx = 1:numel(sources)
            delay = 1;
            if sources(sourceIdx) == "Agent200"
                delay = agentDelay;
            end
            sourceIndices = max(1, (1:stepCount)'-delay);
            qAfterBase = reference(sourceIndices);
            for motor = [2 3]
                qAfter = qAfterBase;
                qBefore = [initial; qAfter(1:end-1)];
                deltaQ = qAfter-qBefore;
                velocity = deltaQ/periodSec;
                active = referenceVelocity ~= 0;
                appliedPwm = zeros(stepCount, 1);
                appliedPwm(active) = direction*32;
                effectiveAction = appliedPwm/255;
                cellIdx = cellIdx + 1;
                componentCells{cellIdx} = table( ...
                    repmat("designed_temporal", stepCount, 1), ...
                    repmat(sources(sourceIdx), stepCount, 1), ...
                    repmat(episode, stepCount, 1), ...
                    repmat(repetition, stepCount, 1), ...
                    (1:stepCount)', repmat(motor, stepCount, 1), ...
                    qBefore, qAfter, reference, referenceVelocity, ...
                    deltaQ, velocity, appliedPwm, effectiveAction, ...
                    false(stepCount, 1), zeros(stepCount, 1), ...
                    false(stepCount, 1), ...
                    'VariableNames', ["split", "commandSource", ...
                    "episode", "repetitionId", "step", "motor", ...
                    "qBefore", "qAfter", "qReference", ...
                    "referenceVelocity", "deltaQ", "velocity", ...
                    "appliedPwm", "effectiveAction", "saturated", ...
                    "safetyInterventionCount", "positionViolation"]);
            end
        end
    end
end
values = vertcat(componentCells{1:cellIdx});
pairing = struct2table(pairRows);
protocol = struct2table(protocolRows);
end
