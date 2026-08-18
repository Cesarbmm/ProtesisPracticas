function tests = testEmgIntentOffline
%testEmgIntentOffline deterministic ETAPA 2 tests (offline, no RL/hardware).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));

config = buildNoGloveStage2OfflineConfig(11);
dataset = buildSyntheticEmgIntentDataset(config);
calibration = calibrateEmgIntent(dataset.restCapture, ...
    dataset.instructionTrials, config.calibrationOptions);
expectedContext = makeExpectedContext(config, dataset, calibration);
testCase.TestData.config = config;
testCase.TestData.dataset = dataset;
testCase.TestData.calibration = calibration;
testCase.TestData.expectedContext = expectedContext;
end

function teardown(~)
clearConfigurablesOverride();
close all force;
end

function testEnvelopeFormulaWindowingAndInvalidInput(testCase)
raw = [1, -2; -3, 4; 5, -6; -7, 8; 100, 100];
[envelope, ranges] = computeEmgEnvelope(raw, 2, 2);
testCase.verifyEqual(envelope, [2, 3; 6, 7], "AbsTol", 0);
testCase.verifyEqual(ranges, [1, 2; 3, 4]);

[overlapEnvelope, overlapRanges] = computeEmgEnvelope(raw(1:4, :), 2, 1);
testCase.verifyEqual(overlapEnvelope, [2, 3; 4, 5; 6, 7], ...
    "AbsTol", 0);
testCase.verifyEqual(overlapRanges, [1, 2; 2, 3; 3, 4]);
testCase.verifyError(@() computeEmgEnvelope([], 2), ...
    "computeEmgEnvelope:InvalidEmg");
testCase.verifyError(@() computeEmgEnvelope([1, NaN], 1), ...
    "computeEmgEnvelope:NonfiniteEmg");
testCase.verifyError(@() computeEmgEnvelope([1, 2], 2), ...
    "computeEmgEnvelope:InsufficientSamples");
testCase.verifyError(@() computeEmgEnvelope([1, 1i], 1), ...
    "computeEmgEnvelope:NonfiniteEmg");
end

function testCalibrationSchemaFlatChannelAndDeterminism(testCase)
config = testCase.TestData.config;
dataset = testCase.TestData.dataset;
calibration = testCase.TestData.calibration;
expected = struct( ...
    "channelOrder", dataset.channelOrder, ...
    "userId", config.calibrationOptions.userId, ...
    "sessionId", config.calibrationOptions.sessionId, ...
    "sampleRateHz", dataset.sampleRateHz, ...
    "windowLengthSamples", dataset.windowLengthSamples, ...
    "hopLengthSamples", dataset.hopLengthSamples);
validation = validateIntentCalibration(calibration, expected);
testCase.verifyTrue(validation.isValid, strjoin(validation.issues, "; "));
testCase.verifyEqual(validation.activeChannelCount, 7);
testCase.verifyFalse(calibration.activeChannelMask(dataset.flatChannelIndex));
testCase.verifyEqual( ...
    calibration.decoder.W(:, dataset.flatChannelIndex), zeros(2, 1));
testCase.verifyEqual(size(calibration.decoder.W), [2, 8]);
testCase.verifyEqual(size(calibration.synergy.matrix), [4, 2]);
testCase.verifyEqual(rank(calibration.synergy.matrix), 2);
testCase.verifyEqual(calibration.motorOrder, ...
    string(definitions("fingers")));
testCase.verifyEqual(calibration.dataProvenance, "synthetic");
testCase.verifyEqual(calibration.sourceDomain, "rawEmgSameSession");
testCase.verifyFalse(calibration.wmoosStandardizationUsed);
testCase.verifyEqual(strlength(calibration.contentSha256), 64);

repeatCalibration = calibrateEmgIntent(dataset.restCapture, ...
    dataset.instructionTrials, config.calibrationOptions);
testCase.verifyEqual(repeatCalibration.contentSha256, ...
    calibration.contentSha256);
testCase.verifyEqual(repeatCalibration.decoder.W, ...
    calibration.decoder.W, "AbsTol", 0);
testCase.verifyEqual(repeatCalibration.decoder.bias, ...
    calibration.decoder.bias, "AbsTol", 0);
testCase.verifyEqual(computeIntentCalibrationChecksum(calibration), ...
    computeIntentCalibrationChecksum(orderfields(calibration)));

tempFile = string(tempname) + ".mat";
cleanup = onCleanup(@() deleteIfPresent(tempFile));
save(tempFile, "repeatCalibration");
loaded = load(tempFile, "repeatCalibration");
testCase.verifyTrue(validateIntentCalibration( ...
    loaded.repeatCalibration, testCase.TestData.expectedContext).isValid);
end

function testCalibrationRejectsIncompleteOrFlatProtocols(testCase)
config = testCase.TestData.config;
dataset = testCase.TestData.dataset;

missingNegativeSecondAxis = dataset.instructionTrials(1:6);
testCase.verifyError(@() calibrateEmgIntent(dataset.restCapture, ...
    missingNegativeSecondAxis, config.calibrationOptions), ...
    "calibrateEmgIntent:InsufficientIntentDirections");

flatRest = dataset.restCapture;
flatRest.rawEmg(:) = 0;
flatTrials = dataset.instructionTrials;
for trialIdx = 1:numel(flatTrials)
    flatTrials(trialIdx).rawEmg(:) = 0;
end
testCase.verifyError(@() calibrateEmgIntent( ...
    flatRest, flatTrials, config.calibrationOptions), ...
    "calibrateEmgIntent:InsufficientActiveChannels");

invalidOptions = config.calibrationOptions;
invalidOptions.synergyMatrix(:, 2) = ...
    invalidOptions.synergyMatrix(:, 1);
testCase.verifyError(@() calibrateEmgIntent(dataset.restCapture, ...
    dataset.instructionTrials, invalidOptions), ...
    "calibrateEmgIntent:InvalidSynergyMatrix");

nonseparableTrials = dataset.instructionTrials;
sharedRaw = nonseparableTrials(1).rawEmg;
for trialIdx = 1:numel(nonseparableTrials)
    nonseparableTrials(trialIdx).rawEmg = sharedRaw;
end
testCase.verifyError(@() calibrateEmgIntent(dataset.restCapture, ...
    nonseparableTrials, config.calibrationOptions), ...
    "calibrateEmgIntent:UnidentifiableDecoder");

diagonalTrial = dataset.instructionTrials;
diagonalTrial(1).intentDirection = [0.5, 0.5];
testCase.verifyError(@() calibrateEmgIntent(dataset.restCapture, ...
    diagonalTrial, config.calibrationOptions), ...
    "calibrateEmgIntent:InvalidIntentDirection");

shortRest = dataset.restCapture;
shortRest.rawEmg = shortRest.rawEmg( ...
    1:config.calibrationOptions.windowLengthSamples, :);
testCase.verifyError(@() calibrateEmgIntent(shortRest, ...
    dataset.instructionTrials, config.calibrationOptions), ...
    "calibrateEmgIntent:InsufficientRestWindows");

incompatibleRest = dataset.restCapture;
incompatibleRest.channelOrder([1, 2]) = ...
    incompatibleRest.channelOrder([2, 1]);
testCase.verifyError(@() calibrateEmgIntent(incompatibleRest, ...
    dataset.instructionTrials, config.calibrationOptions), ...
    "calibrateEmgIntent:IncompatibleCapture");
end

function testCompatibilityAndMalformedCalibrationAreRejected(testCase)
dataset = testCase.TestData.dataset;
calibration = testCase.TestData.calibration;
expectedContext = testCase.TestData.expectedContext;

swappedOrder = dataset.channelOrder;
swappedOrder([1, 2]) = swappedOrder([2, 1]);
incompatible = validateIntentCalibration(calibration, ...
    struct("channelOrder", swappedOrder));
testCase.verifyFalse(incompatible.isValid);
swappedContext = expectedContext;
swappedContext.channelOrder = swappedOrder;
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, swappedContext), ...
    "mapEmgToIntentVelocity:InvalidCalibration");

wrongSession = validateIntentCalibration(calibration, ...
    struct("sessionId", "another-session"));
testCase.verifyFalse(wrongSession.isValid);
wrongUser = validateIntentCalibration(calibration, ...
    struct("userId", "another-user"));
testCase.verifyFalse(wrongUser.isValid);
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration), ...
    "mapEmgToIntentVelocity:IncompleteExpectedContext");
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    zeros(40, 1), calibration, expectedContext), ...
    "mapEmgToIntentVelocity:InvalidRawEmg");

wrongUnits = expectedContext;
wrongUnits.units.rawEmg = "volts";
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, wrongUnits), ...
    "mapEmgToIntentVelocity:InvalidCalibration");
wrongMotors = expectedContext;
wrongMotors.motorOrder([1, 2]) = wrongMotors.motorOrder([2, 1]);
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, wrongMotors), ...
    "mapEmgToIntentVelocity:InvalidCalibration");
typoContext = expectedContext;
typoContext.sessionID = typoContext.sessionId;
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, typoContext), ...
    "mapEmgToIntentVelocity:InvalidCalibration");

badThresholds = calibration;
badThresholds.restGate.thetaOff = badThresholds.restGate.thetaOn;
testCase.verifyFalse(validateIntentCalibration(badThresholds).isValid);
badPosition = calibration;
badPosition.limits.positionMax(1) = badPosition.limits.positionMin(1);
testCase.verifyFalse(validateIntentCalibration(badPosition).isValid);
badTiming = calibration;
badTiming.limits.deltaT = calibration.limits.deltaT / 2;
testCase.verifyFalse(validateIntentCalibration(badTiming).isValid);
badFinite = calibration;
badFinite.decoder.W(1) = NaN;
testCase.verifyFalse(validateIntentCalibration(badFinite).isValid);
badChecksum = calibration;
badChecksum.decoder.W(1) = badChecksum.decoder.W(1) + 1e-6;
checksumReport = validateIntentCalibration(badChecksum);
testCase.verifyFalse(checksumReport.isValid);
testCase.verifyTrue(any(contains(checksumReport.issues, "checksum")));

badRank = calibration;
badRank.decoder.W(2, :) = badRank.decoder.W(1, :);
badRank.decoder.weightRank = 1;
badRank.contentSha256 = computeIntentCalibrationChecksum(badRank);
testCase.verifyFalse(validateIntentCalibration(badRank).isValid);

relabeledUnits = calibration;
relabeledUnits.units.rawEmg = "volts";
relabeledUnits.contentSha256 = ...
    computeIntentCalibrationChecksum(relabeledUnits);
unitPinnedContext = expectedContext;
unitPinnedContext.calibrationContentSha256 = ...
    relabeledUnits.contentSha256;
testCase.verifyFalse(validateIntentCalibration( ...
    relabeledUnits, unitPinnedContext).isValid);
end

function testRestModerateMaximumNoiseFlatAndSignedIntent(testCase)
dataset = testCase.TestData.dataset;
calibration = testCase.TestData.calibration;
expectedContext = testCase.TestData.expectedContext;
[velocity, intent, ~, details] = mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, expectedContext);

testCase.verifyTrue(all(isfinite(details.envelope), "all"));
testCase.verifyGreaterThanOrEqual(min(details.normalizedActivation, [], "all"), 0);
testCase.verifyLessThanOrEqual(max(details.normalizedActivation, [], "all"), 1);
testCase.verifyEqual(max(details.normalizedActivation, [], "all"), 1, ...
    "AbsTol", 1e-12);
testCase.verifyGreaterThanOrEqual(min(intent, [], "all"), -1);
testCase.verifyLessThanOrEqual(max(intent, [], "all"), 1);
testCase.verifyLessThanOrEqual(max(abs(velocity), [], 1), ...
    calibration.limits.velocityMax + 1e-12);
testCase.verifyEqual(details.normalizedActivation(:, ...
    dataset.flatChannelIndex), zeros(size(intent, 1), 1));

noise = dataset.evaluationWindowScenario == "transient_noise";
testCase.verifyFalse(any(details.gateActive(noise)));
testCase.verifyEqual(velocity(noise, :), zeros(sum(noise), 4), "AbsTol", 0);
intendedRest = dataset.evaluationIntendedRest;
testCase.verifyEqual(intent(intendedRest, :), ...
    zeros(sum(intendedRest), 2), "AbsTol", 0);
testCase.verifyEqual(velocity(intendedRest, :), ...
    zeros(sum(intendedRest), 4), "AbsTol", 0);

closeModerate = dataset.evaluationWindowScenario == "close_moderate" & ...
    details.gateActive;
closeMaximum = dataset.evaluationWindowScenario == "close_maximum" & ...
    details.gateActive;
openMaximum = dataset.evaluationWindowScenario == "open_maximum" & ...
    details.gateActive;
opposeMaximum = dataset.evaluationWindowScenario == ...
    "thumb_oppose_maximum" & details.gateActive;
releaseMaximum = dataset.evaluationWindowScenario == ...
    "thumb_release_maximum" & details.gateActive;
testCase.verifyGreaterThan(mean(intent(closeModerate, 1)), 0);
testCase.verifyGreaterThan(mean(intent(closeMaximum, 1)), ...
    mean(intent(closeModerate, 1)));
testCase.verifyLessThan(mean(intent(openMaximum, 1)), 0);
testCase.verifyGreaterThan(mean(intent(opposeMaximum, 2)), 0);
testCase.verifyLessThan(mean(intent(releaseMaximum, 2)), 0);
end

function testHysteresisThresholdsAreInclusiveAndConsecutive(testCase)
calibration = testCase.TestData.calibration;
expectedContext = testCase.TestData.expectedContext;
activeLevels = [ ...
    calibration.restGate.thetaOn - 0.01; ...
    calibration.restGate.thetaOn; ...
    calibration.restGate.thetaOn; ...
    mean([calibration.restGate.thetaOn, calibration.restGate.thetaOff]); ...
    calibration.restGate.thetaOff; ...
    calibration.restGate.thetaOff; ...
    calibration.restGate.thetaOff];
raw = rawFromUniformActivation(activeLevels, calibration);
[~, intent, gateState, details] = mapEmgToIntentVelocity( ...
    raw, calibration, expectedContext);
testCase.verifyEqual(details.gateActive, ...
    logical([0; 0; 1; 1; 1; 1; 0]));
testCase.verifyEqual(details.lowActivityCountdown, ...
    logical([0; 0; 0; 0; 1; 1; 1]));
testCase.verifyEqual(intent(5:7, :), zeros(3, 2), "AbsTol", 0);
testCase.verifyFalse(gateState.isActive);
testCase.verifyEqual(gateState.onCount, 0);
testCase.verifyEqual(gateState.offCount, 0);
invalidGate = struct("isActive", false, ...
    "onCount", calibration.restGate.nOn, "offCount", 0);
testCase.verifyError(@() mapEmgToIntentVelocity( ...
    raw, calibration, expectedContext, invalidGate), ...
    "mapEmgToIntentVelocity:InvalidGateState");
end

function testReferenceResetRestBoundsAccelerationAndReversal(testCase)
dataset = testCase.TestData.dataset;
calibration = testCase.TestData.calibration;
expectedContext = testCase.TestData.expectedContext;
[desiredVelocity, ~, ~, details] = mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, expectedContext);
restMask = ~details.gateActive;
[qRef, vRef, finalState] = updateIntentReference( ...
    dataset.initialEncoder, desiredVelocity, calibration, restMask);

testCase.verifyGreaterThanOrEqual(min(qRef, [], 1), ...
    calibration.limits.positionMin - 1e-12);
testCase.verifyLessThanOrEqual(max(qRef, [], 1), ...
    calibration.limits.positionMax + 1e-12);
testCase.verifyLessThanOrEqual(max(abs(vRef), [], 1), ...
    calibration.limits.velocityMax + 1e-12);
deltaVelocity = diff([zeros(1, 4); vRef], 1, 1);
testCase.verifyLessThanOrEqual(max(abs(deltaVelocity), [], 1), ...
    calibration.limits.accelerationMax .* ...
    calibration.limits.deltaT + 1e-12);
for stepIdx = find(restMask(:)')
    if stepIdx == 1
        previousPosition = dataset.initialEncoder;
    else
        previousPosition = qRef(stepIdx - 1, :);
    end
    testCase.verifyEqual(qRef(stepIdx, :), previousPosition, "AbsTol", 0);
    testCase.verifyEqual(vRef(stepIdx, :), zeros(1, 4), "AbsTol", 0);
end
testCase.verifyEqual(finalState.position, qRef(end, :), "AbsTol", 0);
testCase.verifyEqual(finalState.velocity, vRef(end, :), "AbsTol", 0);

splitIdx = 20;
[qFirst, vFirst, blockState] = updateIntentReference( ...
    dataset.initialEncoder, desiredVelocity(1:splitIdx, :), calibration, ...
    restMask(1:splitIdx));
[qSecond, vSecond] = updateIntentReference( ...
    blockState.position, desiredVelocity((splitIdx + 1):end, :), ...
    calibration, restMask((splitIdx + 1):end), blockState.velocity);
testCase.verifyEqual([qFirst; qSecond], qRef, "AbsTol", 0);
testCase.verifyEqual([vFirst; vSecond], vRef, "AbsTol", 0);

longCommand = [10 * ones(120, 4); -10 * ones(160, 4)];
[boundedQ, boundedV] = updateIntentReference( ...
    dataset.initialEncoder, longCommand, calibration, ...
    false(size(longCommand, 1), 1));
testCase.verifyGreaterThanOrEqual(min(boundedQ, [], 1), ...
    calibration.limits.positionMin - 1e-12);
testCase.verifyLessThanOrEqual(max(boundedQ, [], 1), ...
    calibration.limits.positionMax + 1e-12);
boundedDeltaV = diff([zeros(1, 4); boundedV], 1, 1);
testCase.verifyLessThanOrEqual(max(abs(boundedDeltaV), [], 1), ...
    calibration.limits.accelerationMax .* ...
    calibration.limits.deltaT + 1e-12);
longSplit = 213;
[boundedQ1, boundedV1, boundedState] = updateIntentReference( ...
    dataset.initialEncoder, longCommand(1:longSplit, :), calibration, ...
    false(longSplit, 1));
[boundedQ2, boundedV2] = updateIntentReference( ...
    boundedState.position, longCommand((longSplit + 1):end, :), ...
    calibration, false(size(longCommand, 1) - longSplit, 1), ...
    boundedState.velocity);
testCase.verifyEqual([boundedQ1; boundedQ2], boundedQ, "AbsTol", 0);
testCase.verifyEqual([boundedV1; boundedV2], boundedV, "AbsTol", 0);

testCase.verifyError(@() updateIntentReference( ...
    dataset.initialEncoder, zeros(1, 4), calibration, true, ...
    0.1 * ones(1, 4)), ...
    "updateIntentReference:InfeasibleRestTransition");
end

function testFutureWindowsCannotAffectPastOutputs(testCase)
dataset = testCase.TestData.dataset;
calibration = testCase.TestData.calibration;
expectedContext = testCase.TestData.expectedContext;
windowLength = calibration.windowLengthSamples;
prefixWindows = 20;
changedRaw = dataset.evaluationRawEmg;
futureRows = prefixWindows * windowLength + 1:size(changedRaw, 1);
changedRaw(futureRows, 1:7) = 50 * changedRaw(futureRows, 1:7) + 3;

[velocityA, intentA, ~, detailsA] = mapEmgToIntentVelocity( ...
    dataset.evaluationRawEmg, calibration, expectedContext);
[velocityB, intentB, ~, detailsB] = mapEmgToIntentVelocity( ...
    changedRaw, calibration, expectedContext);
prefix = 1:prefixWindows;
testCase.verifyEqual(velocityA(prefix, :), velocityB(prefix, :), ...
    "AbsTol", 0);
testCase.verifyEqual(intentA(prefix, :), intentB(prefix, :), ...
    "AbsTol", 0);
testCase.verifyEqual(detailsA.normalizedActivation(prefix, :), ...
    detailsB.normalizedActivation(prefix, :), "AbsTol", 0);
testCase.verifyEqual(detailsA.gateActive(prefix), ...
    detailsB.gateActive(prefix));

windowLength = calibration.windowLengthSamples;
streamVelocity = zeros(size(velocityA));
streamIntent = zeros(size(intentA));
gateState = struct();
for windowIdx = 1:size(velocityA, 1)
    rows = (windowIdx - 1) * windowLength + (1:windowLength);
    [streamVelocity(windowIdx, :), streamIntent(windowIdx, :), gateState] = ...
        mapEmgToIntentVelocity(dataset.evaluationRawEmg(rows, :), ...
        calibration, expectedContext, gateState);
end
testCase.verifyEqual(streamVelocity, velocityA, "AbsTol", 0);
testCase.verifyEqual(streamIntent, intentA, "AbsTol", 0);
end

function raw = rawFromUniformActivation(levels, calibration)
windowLength = calibration.windowLengthSamples;
channelCount = calibration.channelCount;
raw = zeros(numel(levels) * windowLength, channelCount);
for levelIdx = 1:numel(levels)
    envelope = calibration.baselineMedian + levels(levelIdx) .* ...
        (calibration.signalLevel - calibration.baselineMedian + ...
        calibration.epsilon);
    envelope(~calibration.activeChannelMask) = 0;
    rows = (levelIdx - 1) * windowLength + (1:windowLength);
    raw(rows, :) = repmat(envelope, windowLength, 1);
end
end

function expected = makeExpectedContext(config, dataset, calibration)
options = config.calibrationOptions;
expectedUnits = struct( ...
    "rawEmg", dataset.restCapture.rawEmgUnits, ...
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
    "motorOrder", options.motorOrder, ...
    "units", expectedUnits, ...
    "synergyMatrixVersion", ...
        options.synergyMatrixVersion, ...
    "instructionProtocolVersion", ...
        options.instructionProtocolVersion, ...
    "sourceDomain", "rawEmgSameSession", ...
    "calibrationContentSha256", calibration.contentSha256);
end

function deleteIfPresent(filePath)
if isfile(filePath)
    delete(filePath);
end
end
