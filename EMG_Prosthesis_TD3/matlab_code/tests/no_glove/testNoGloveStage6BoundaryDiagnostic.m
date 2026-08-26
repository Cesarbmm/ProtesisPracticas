function tests = testNoGloveStage6BoundaryDiagnostic
%testNoGloveStage6BoundaryDiagnostic deterministic ETAPA 6B tests.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "workflows", "published")));
testCase.TestData.tempDir = string(tempname);
mkdir(testCase.TestData.tempDir);
end

function teardownOnce(testCase)
clearConfigurablesOverride();
if isfolder(testCase.TestData.tempDir) && ...
        startsWith(testCase.TestData.tempDir, string(tempdir))
    rmdir(testCase.TestData.tempDir, "s");
end
end

function setup(~)
clearConfigurablesOverride();
end

function teardown(~)
clearConfigurablesOverride();
end

function testCausalAlignmentAndMutuallyExclusiveAttribution(testCase)
episodeDir = makeEpisodeDirectory(testCase, "nominal", "none");
analysis = analyzeNoGloveStage6BoundaryDiagnostics( ...
    episodeDir, "acceptance");
motor1 = analysis.motorSummary(analysis.motorSummary.motor == 1, :);
motor2 = analysis.motorSummary(analysis.motorSummary.motor == 2, :);

testCase.verifyEqual(analysis.nextStateAlignmentMaxAbs, 0);
testCase.verifyEqual(analysis.referenceAlignmentMaxAbs, 0);
testCase.verifyEqual(motor1.activeReferenceSteps, 4);
testCase.verifyEqual(motor1.noMotionActiveSteps, 3);
testCase.verifyEqual(motor1.noMotionBoundaryOrSafetySteps, 1);
testCase.verifyEqual(motor1.noMotionInteriorZeroPwmSteps, 1);
testCase.verifyEqual(motor1.noMotionInteriorNonzeroPwmSteps, 1);
testCase.verifyEqual(motor1.wrongMotionActiveSteps, 1);
testCase.verifyEqual(motor1.responseOpposesCommandSteps, 1);
testCase.verifyEqual(motor1.outwardReferenceAtLimitSteps, 1);
testCase.verifyEqual(motor1.outwardCommandAtBoundarySteps, 1);
testCase.verifyEqual(motor2.wrongCommandDirectionActiveSteps, 1);
testCase.verifyEqual(motor2.wrongCommandPositionErrorSteps, 1);
testCase.verifyEqual(motor2.responseOpposesCommandSteps, 0);
testCase.verifyEqual(motor2.saturatedZeroReferenceSteps, 1);
testCase.verifyEqual(motor2.nonzeroPwmZeroControlDemandSteps, 1);
testCase.verifyEqual(motor2.saturatedZeroControlDemandSteps, 1);
testCase.verifyEqual(motor2.outwardCommandAtBoundarySteps, 1);

partitionTotal = motor1.noMotionBoundaryOrSafetySteps + ...
    motor1.noMotionInteriorZeroPwmSteps + ...
    motor1.noMotionInteriorNonzeroPwmSteps;
testCase.verifyEqual(partitionTotal, motor1.noMotionActiveSteps);
testCase.verifyEqual(height(analysis.componentTable), 6 * 4);
testCase.verifyGreaterThan(height(analysis.conditionSummary), 0);
testCase.verifyEqual(height(analysis.hypothesisEvidence), 4 * 11);
end

function testReferenceMisalignmentFailsClosed(testCase)
episodeDir = makeEpisodeDirectory(testCase, ...
    "bad_reference", "reference");
testCase.verifyError(@() analyzeNoGloveStage6BoundaryDiagnostics( ...
    episodeDir, "acceptance"), ...
    "analyzeNoGloveStage6BoundaryDiagnostics:ReferenceMisalignment");
end

function testNextEncoderMisalignmentFailsClosed(testCase)
episodeDir = makeEpisodeDirectory(testCase, ...
    "bad_next", "nextEncoder");
testCase.verifyError(@() analyzeNoGloveStage6BoundaryDiagnostics( ...
    episodeDir, "acceptance"), ...
    "analyzeNoGloveStage6BoundaryDiagnostics:NextStateMisalignment");
end

function testDisabledSafetyEpisodeIsRejected(testCase)
episodeDir = makeEpisodeDirectory(testCase, ...
    "disabled_safety", "disabledSafety");
testCase.verifyError(@() analyzeNoGloveStage6BoundaryDiagnostics( ...
    episodeDir, "acceptance"), ...
    "analyzeNoGloveStage6BoundaryDiagnostics:IncompatibleEpisode");
end

function testLauncherRejectsNoncorrectiveManifest(testCase)
inputDir = fullfile(testCase.TestData.tempDir, "bad_manifest");
mkdir(inputDir);
manifest = struct( ...
    "stage", 6, "phase", "smoke", "phaseGatePassed", false, ...
    "positionSafetyAblation", false, ...
    "simulationPositionSafety", struct("enabled", false), ...
    "referenceSource", "emgIntent", ...
    "observationVariant", "intentMarkov60", ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "simMotors", true, "hardwareUsed", false, ...
    "seedSummary", struct(), "gitCommit", "fixture");
writeText(fullfile(inputDir, "manifest.json"), jsonencode(manifest));
testCase.verifyError(@() run_no_glove_stage6b_boundary_diagnostic( ...
    struct("stage6RunRoot", inputDir)), ...
    "run_no_glove_stage6b_boundary_diagnostic:IncompatibleManifest");
end

function episodeDir = makeEpisodeDirectory(testCase, name, mutation)
episodeDir = fullfile(testCase.TestData.tempDir, name);
mkdir(episodeDir);
writeSyntheticEpisode(fullfile(episodeDir, "episode00001.mat"), mutation);
end

function writeSyntheticEpisode(filePath, mutation)
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
stepCount = 6;
stateLog = zeros(stepCount, layout.totalLength);
qBefore = zeros(stepCount, 4);
qAfter = zeros(stepCount, 4);
qReference = zeros(stepCount, 4);
vReference = zeros(stepCount, 4);
actionPwmLog = zeros(stepCount, 4);
positionSafetyInterventionLog = zeros(stepCount, 4);

% Motor 1: boundary-limited no motion, transition to interior, zero-PWM
% no motion, nonzero-PWM no motion, then motion opposing aligned PWM.
qBefore(:, 1) = [0; 0; 0.5; 0.5; 0.5; 0.49];
qAfter(:, 1) = [0; 0.5; 0.5; 0.5; 0.49; 0.49];
qReference(:, 1) = [0; 0.5; 0.7; 0.7; 0.7; 0.49];
vReference(:, 1) = [-0.1; 0; 0.1; 0.1; 0.1; 0];
actionPwmLog(:, 1) = [-96; 96; 0; 96; 96; 0];
positionSafetyInterventionLog(1, 1) = 1;

% Motor 2: PWM sign opposes velocity and position error while motion
% follows that PWM; later a saturated outward command at rest/lower bound.
qBefore(:, 2) = [0.5; 0.49; 0; 0; 0; 0];
qAfter(:, 2) = [0.49; 0; 0; 0; 0; 0];
qReference(:, 2) = [0.7; 0; 0; 0; 0; 0];
vReference(:, 2) = [0.1; 0; 0; 0; 0; 0];
actionPwmLog(:, 2) = [-96; -96; -255; 0; 0; 0];
positionSafetyInterventionLog(3, 2) = 1;

stateLog(:, layout.encoder) = qBefore;
stateLog(:, layout.referencePosition) = qReference;
stateLog(:, layout.referenceVelocity) = vReference;
trackingPredictionHistory = qAfter;
referenceHistory = qReference;
actionSatLog = actionPwmLog ./ 255;
simulationPositionSafety = struct( ...
    "enabled", true, "mode", "clipTrajectoryOutput", ...
    "positionMin", zeros(1, 4), "positionMax", ones(1, 4), ...
    "encoderScale", [26500, 11500, 8500, 9000]);
referenceSource = "emgIntent";
observationVariant = "intentMarkov60";
stateLength = layout.totalLength;

switch string(mutation)
    case "reference"
        referenceHistory(1, 1) = 0.1;
    case "nextEncoder"
        trackingPredictionHistory(1, 1) = 0.1;
    case "disabledSafety"
        simulationPositionSafety.enabled = false;
end

save(filePath, "stateLog", "trackingPredictionHistory", ...
    "referenceHistory", "actionPwmLog", "actionSatLog", ...
    "positionSafetyInterventionLog", "simulationPositionSafety", ...
    "referenceSource", "observationVariant", "stateLength");
end

function writeText(filePath, value)
fid = fopen(filePath, "w");
if fid < 0
    error("testNoGloveStage6BoundaryDiagnostic:WriteFailed", ...
        "Could not write %s.", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", value);
end
