function tests = testPairedReferenceTeacherAvailability
% Contrato teacher/done E2B; fixtures sin cargar datasets ni agentes.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
matlabRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
testCase.TestData.oldPath = path;
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(fullfile(matlabRoot, "analysis", "paired_reference"));
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function testFormulaMatchesActualReadersAtBoundaries(testCase)
for nEmg = [1 2 31 40 41 80 81 82 400 401]
    for nGlove = [1 2 3 4 5 6 18 20 21 22]
        actual = runReaders(nEmg, nGlove);
        expected = e2bTeacherAvailability(nEmg, nGlove);
        verifyTrue(testCase, expected.valid);
        for field = string(fieldnames(actual))'
            verifyEqual(testCase, expected.(field), actual.(field), ...
                sprintf("N=%d M=%d campo=%s", nEmg, nGlove, field));
        end
    end
end
end

function testTeacherDiscardAndReaderResidualAreSeparated(testCase)
result = e2bTeacherAvailability(401, 18);
verifyEqual(testCase, result.hHistorical, 8);
verifyEqual(testCase, result.hEmg, 9);
verifyEqual(testCase, result.emgResetConsumed, 40);
verifyEqual(testCase, result.emgConsumedHistorical, 360);
verifyEqual(testCase, result.unusedEmgSamples, 41);
verifyEqual(testCase, result.teacherDiscardedEmgSamples, 40);
verifyEqual(testCase, result.emgReaderResidualSamples, 1);
verifyEqual(testCase, result.unusedEmgFraction, 41 / 401);
verifyEqual(testCase, result.teacherDiscardedEmgFraction, 40 / 401);
verifyEqual(testCase, result.terminationCause, "TEACHER_ONLY");
verifyEqual(testCase, result.bootstrapFactorDifference, 0.95);
end

function testAllTerminationCauses(testCase)
emgFirst = e2bTeacherAvailability(80, 20);
both = e2bTeacherAvailability(400, 20);
teacherFirst = e2bTeacherAvailability(400, 18);
verifyEqual(testCase, emgFirst.terminationCause, "EMG_ONLY");
verifyEqual(testCase, both.terminationCause, "EMG_AND_TEACHER");
verifyEqual(testCase, teacherFirst.terminationCause, "TEACHER_ONLY");
verifyEqual(testCase, emgFirst.bootstrapFactorDifference, 0);
verifyEqual(testCase, both.bootstrapFactorDifference, 0);
verifyEqual(testCase, teacherFirst.bootstrapFactorDifference, 0.95);
end

function testResetExhaustionDoesNotHideHistoricalFirstStep(testCase)
result = e2bTeacherAvailability(31, 2);
verifyTrue(testCase, result.emgExhaustedAtReset);
verifyTrue(testCase, result.teacherExhaustedAtReset);
verifyEqual(testCase, result.hEmg, 0);
verifyEqual(testCase, result.hHistorical, 1);
verifyEqual(testCase, result.emgOnlySeconds, 0);
verifyEqual(testCase, result.historicalSeconds, 0.2);
end

function testNominalTimeIncludesResetButControlHorizonDoesNot(testCase)
result = e2bTeacherAvailability(400, 18);
verifyEqual(testCase, result.emgNominalSeconds, 2);
verifyEqual(testCase, result.teacherNominalSeconds, 1.8);
verifyEqual(testCase, result.emgOnlySeconds, 1.8);
verifyEqual(testCase, result.historicalSeconds, 1.6);
verifyFalse(testCase, result.reachesHistoricalMaxSteps50);
long = e2bTeacherAvailability(2040, 102);
verifyTrue(testCase, long.reachesHistoricalMaxSteps50);
end

function testInvalidLengthsRemainExplicit(testCase)
invalidLengths = {[], 0, -1, NaN, Inf, 1.5, [80 81], "80", 1 + 1i};
for index = 1:numel(invalidLengths)
    for side = 1:2
        if side == 1
            result = e2bTeacherAvailability(invalidLengths{index}, 18);
        else
            result = e2bTeacherAvailability(400, invalidLengths{index});
        end
        verifyFalse(testCase, result.valid);
        verifyNotEmpty(testCase, result.invalidReason);
        verifyTrue(testCase, isnan(result.hHistorical));
        verifyTrue(testCase, isnan(result.unusedEmgFraction));
        verifyEqual(testCase, result.terminationCause, "INVALID_LENGTH");
    end
end
end

function result = runReaders(nEmg, nGlove)
myo = RecordedMyo(zeros(nEmg, 8));
teacher = RecordedGlove(repmat(struct("fixture", 0), nGlove, 1));
myo.readEmg(0.2);
teacher.read(0.2);
result = struct("emgResetConsumed", myo.j - 1, ...
    "teacherResetConsumed", teacher.j - 1, ...
    "emgExhaustedAtReset", myo.exhausted, ...
    "teacherExhaustedAtReset", teacher.exhausted);
historical = 0;
% Env.reset sets isDone=false even when a reader already exhausted at reset.
while true
    myo.readEmg(0.2);
    teacher.read(0.2);
    historical = historical + 1;
    if myo.exhausted || teacher.exhausted, break; end
end
result.hHistorical = historical;
result.emgConsumedHistorical = myo.j - 1;
result.teacherConsumedHistorical = teacher.j - 1;
result.emgExhaustedHistorical = myo.exhausted;
result.teacherExhaustedHistorical = teacher.exhausted;
myo.resetBuffer();
myo.readEmg(0.2);
runtime = 0;
while ~myo.exhausted
    myo.readEmg(0.2);
    runtime = runtime + 1;
end
result.hEmg = runtime;
result.emgConsumedRuntime = myo.j - 1;
teacher.resetBuffer();
teacher.read(0.2);
teacherHorizon = 0;
while ~teacher.exhausted
    teacher.read(0.2);
    teacherHorizon = teacherHorizon + 1;
end
result.hTeacher = teacherHorizon;
end
