function tests = testPairedReferenceProportionalAction
% P E2B en el espacio historico de reward y con teacher causal ya leido.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));
testCase.TestData.oldPath = path;
testCase.TestData.oldRng = rng;
testCase.TestData.oldDir = cd(matlabRoot);
addpath(genpath(matlabRoot));
testCase.TestData.hadOverride = isappdata(0, "configurables_override");
if testCase.TestData.hadOverride
    testCase.TestData.previousOverride = getappdata(0, "configurables_override");
end
testCase.TestData.override = struct("run_training", false, ...
    "flagSaveTraining", false, "plotEpisodeOnTest", false, "verbose", false, ...
    "usePrerecorded", true, "simMotors", true, "observationVariant", "markov52", ...
    "simPlantSource", "patternCurveCanonical", ...
    "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(testCase.TestData.override);
[testCase.TestData.emg, testCase.TestData.teacher] = ...
    loadE2ADevelopmentEpisode("BLANCA", 1, 1, includeTeacher=true);
end

function teardownOnce(testCase)
if testCase.TestData.hadOverride
    setConfigurablesOverride(testCase.TestData.previousOverride);
else
    clearConfigurablesOverride();
end
cd(testCase.TestData.oldDir);
path(testCase.TestData.oldPath);
rng(testCase.TestData.oldRng);
end

function setup(testCase)
setConfigurablesOverride(testCase.TestData.override);
end

function testZeroEncoderUsesHistoricalNonzeroFlexMinimum(testCase)
minimum = [1800/4092 900/2046 300/1023 900/2046];
teacher = teacherAtReference(minimum);
verifyEqual(testCase, e2bProportionalAction(zeros(1,4), teacher, 2), zeros(4,1));
% El recorrido libre previo al gap no modifica la flexion de reward.
verifyEqual(testCase, e2bProportionalAction([7499 3649 3999 3549], teacher, 2), ...
    zeros(4,1));
% No se confunde el encoder normalizado del estado con flexion de reward.
raw = e2bProportionalAction(zeros(1,4), teacherAtReference(ones(1,4)), .5);
verifyEqual(testCase, raw, .5*(1-minimum)', "AbsTol", 1e-14);
end

function testWorkingRangeAndClippingHaveCorrectDirection(testCase)
minimum = [1800/4092 900/2046 300/1023 900/2046];
midpoint = [17000 7575 6250 6275]; % mitad entre gap y breakLimit
up = e2bProportionalAction(midpoint, teacherAtReference(ones(1,4)), 1);
down = e2bProportionalAction(midpoint, teacherAtReference(minimum), 1);
verifyEqual(testCase, up, .5*(1-minimum)', "AbsTol", 1e-14);
verifyEqual(testCase, down, -.5*(1-minimum)', "AbsTol", 1e-14);
verifyEqual(testCase, e2bProportionalAction(midpoint, ...
    teacherAtReference(ones(1,4)), 8), ones(4,1));
verifyEqual(testCase, e2bProportionalAction(midpoint, ...
    teacherAtReference(minimum), 8), -ones(4,1));
verifyEqual(testCase, e2bProportionalAction([26500 11500 8500 9000], ...
    teacherAtReference(ones(1,4)), 1), zeros(4,1), "AbsTol", 1e-14);
end

function testOnlyLastAlreadyReadReferenceDeterminesCurrentAction(testCase)
teacher = [teacherAtReference(zeros(1,4)); teacherAtReference(.75*ones(1,4))];
q = [10000 5000 4500 4500];
original = e2bProportionalAction(q, teacher, 1);
teacher(1) = teacherAtReference(ones(1,4));
verifyEqual(testCase, e2bProportionalAction(q, teacher, 1), original);
verifyEqual(testCase, e2bProportionalAction(q, teacher(end), 1), original);
end

function testPureProportionalGainDoesNotQuantizeOrRateLimit(testCase)
minimum = [1800/4092 900/2046 300/1023 900/2046];
teacher = teacherAtReference(minimum + [.1 -.1 .2 -.2]);
q = zeros(1,4);
raw1 = e2bProportionalAction(q, teacher, .5);
raw2 = e2bProportionalAction(q, teacher, 1);
verifySize(testCase, raw2, [4 1]);
verifyEqual(testCase, raw2, [.1; -.1; .2; -.2], "AbsTol", 1e-14);
verifyEqual(testCase, raw2, 2*raw1);
verifyEqual(testCase, e2bProportionalAction(q, teacher, 0), zeros(4,1));
verifyEqual(testCase, e2bProportionalAction(q, teacher, 1), raw2);
% .1 no se transforma en 64/255 aqui: ese trabajo pertenece a Env.step.
verifyGreaterThan(testCase, abs(raw2(1)-64/255), .1);
end

function testUnavailableOrNonfiniteTeacherIsRejected(testCase)
verifyError(testCase, @() e2bProportionalAction(zeros(1,4), repmat(struct(),0,1), 1), ...
    "E2B:TeacherUnavailable");
teacher = teacherAtReference(ones(1,4));
teacher.thumb = NaN;
verifyError(testCase, @() e2bProportionalAction(zeros(1,4), teacher, 1), ...
    "E2B:InvalidTeacher");
end

function testHelperPreservesInputsAndEvaluationConfiguration(testCase)
q = [8000 4000 4100 3600];
teacher = testCase.TestData.teacher(1:2);
originalQ = q;
originalTeacher = teacher;
overrideBefore = getappdata(0, "configurables_override");
e2bProportionalAction(q, teacher, 2);
verifyEqual(testCase, q, originalQ);
verifyEqual(testCase, teacher, originalTeacher);
verifyEqual(testCase, getappdata(0, "configurables_override"), overrideBefore);
verifyFalse(testCase, configurables("run_training"));
end

function testChangingFutureTeacherCannotChangeCurrentActionOrTransition(testCase)
emg = testCase.TestData.emg;
teacherA = testCase.TestData.teacher;
teacherB = teacherA;
mapping = definitions("flexMapping");
fingers = definitions("fingers");
% Solo registros aun no leidos: reset lee 1:2, el primer step lee 3:4.
% Una referencia artificial grande garantiza una diferencia de reward clara.
for finger = fingers
    for sensor = mapping.(finger{1})
        for sample = 3:numel(teacherB)
            teacherB(sample).(sensor{1}) = 10000;
        end
    end
end
verifyEqual(testCase, teacherA(1:2), teacherB(1:2));
envA = Env("", true, {emg, emg}, {teacherA, teacherA});
envB = Env("", true, {emg, emg}, {teacherB, teacherB});
rng(20260905, "twister"); stateA = reset(envA);
rng(20260905, "twister"); stateB = reset(envB);
verifyEqual(testCase, envA.glove.j, 3);
verifyEqual(testCase, envB.glove.j, 3);
verifyEqual(testCase, stateA, stateB);
qA = envA.motorData(end,:);
qB = envB.motorData(end,:);
verifyEqual(testCase, qA, qB);
actionA = e2bProportionalAction(qA, envA.flexData, 1);
actionB = e2bProportionalAction(qB, envB.flexData, 1);
verifyEqual(testCase, actionA, actionB);
[nextA, rewardA, doneA] = step(envA, actionA);
[nextB, rewardB, doneB] = step(envB, actionB);
verifyEqual(testCase, nextA, nextB);
verifyEqual(testCase, doneA, doneB);
verifyEqual(testCase, envA.actionLog(1,:), envB.actionLog(1,:));
verifyEqual(testCase, envA.actionSatLog(1,:), envB.actionSatLog(1,:));
verifyEqual(testCase, envA.actionPwmLog(1,:), envB.actionPwmLog(1,:));
verifyEqual(testCase, envA.encoderLog{1}, envB.encoderLog{1});
verifyGreaterThan(testCase, abs(rewardA-rewardB), 1);
% El helper tampoco ha consumido una muestra adicional de ninguno de los lectores.
verifyEqual(testCase, envA.glove.j, 5);
verifyEqual(testCase, envB.glove.j, 5);
verifyFalse(testCase, configurables("run_training"));
end

function teacher = teacherAtReference(reference)
% Fixture independiente: nueve sensores, en el orden de los motores reales.
flex = reference .* [4092 2046 1023 2046];
teacher = struct("thumb", flex(3), "indexUp", flex(2)/2, ...
    "indexDown", flex(2)/2, "middleUp", flex(4)/2, ...
    "middleDown", flex(4)/2, "ringUp", flex(1)/4, ...
    "ringDown", flex(1)/4, "pinkyUp", flex(1)/4, "pinkyDown", flex(1)/4);
end
