function tests = testPairedReferenceGloveFreeExecution
% Gates deterministas E2A: teacher durante aprendizaje, ejecucion sin guante.
% No entrena, no cambia reward/planta/interfaz y nunca abre sujetos sellados.
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
[testCase.TestData.actor, testCase.TestData.policyManifest, testCase.TestData.agent] = ...
    loadE2AFrozenActor();
testCase.TestData.syntheticEmg = reshape(sin((1:800)/13), 100, 8);
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

function testSealedSubjectsRejectedBeforeAnyLoad(testCase)
calls = 0;
for subject = ["MATEO", "SANDRA"]
    verifyError(testCase, @() loadE2ADevelopmentEpisode(subject, 1, 1, ...
        includeTeacher=true, variableLoader=@spy), ...
        "ProtesisPracticas:E2ADevelopmentOnly");
end
verifyEqual(testCase, calls, 0);
    function loaded = spy(varargin) %#ok<INUSD>
        calls = calls + 1;
        loaded = struct();
        error("E2ATest:UnexpectedIO", "El sujeto sellado llego al loader.");
    end
end

function testAbsentLoaderWorksWithEmgOnlyMatFile(testCase)
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
emgs = {testCase.TestData.syntheticEmg, testCase.TestData.syntheticEmg}; %#ok<NASGU>
save(fullfile(temporary.Folder, "BLANCA.mat"), "emgs");
[emg, teacher, provenance] = loadE2ADevelopmentEpisode("BLANCA", 1, 2, ...
    datasetFolder=string(temporary.Folder));
verifyEqual(testCase, emg, testCase.TestData.syntheticEmg);
verifyEmpty(testCase, teacher);
verifyEqual(testCase, provenance.loadedVariables, "emgs");
verifyFalse(testCase, provenance.includeTeacher);
verifyFalse(testCase, isfield(provenance, "teacherSamples"));
verifyFalse(testCase, isfield(provenance, "teacherSHA256"));
verifyEqual(testCase, strlength(provenance.emgSHA256), 64);
end

function testLoaderRequestsOnlyAuthorizedVariables(testCase)
requests = strings(0, 1);
[emgB, teacherB, manifestB] = loadE2ADevelopmentEpisode("BLANCA", 1, 1, ...
    variableLoader=@spy);
verifyEqual(testCase, requests, "emgs");
verifyEmpty(testCase, teacherB);
requests = strings(0, 1);
[emgA, teacherA, manifestA] = loadE2ADevelopmentEpisode("BLANCA", 1, 1, ...
    includeTeacher=true, variableLoader=@spy);
verifyEqual(testCase, requests, ["emgs"; "gloves"]);
verifyEqual(testCase, emgA, emgB);
verifyEqual(testCase, teacherA, testCase.TestData.teacher);
verifyEqual(testCase, manifestA.emgSHA256, manifestB.emgSHA256);
    function loaded = spy(~, variableName)
        requests(end+1, 1) = variableName;
        switch variableName
            case "emgs"
                loaded = struct("emgs", {{testCase.TestData.emg, testCase.TestData.emg}});
            case "gloves"
                loaded = struct("gloves", {{testCase.TestData.teacher, testCase.TestData.teacher}});
            otherwise
                error("E2ATest:UnexpectedVariable", "Variable no autorizada: %s", variableName);
        end
    end
end

function testFrozenActorIsDeterministicAndUsesOnly52Inputs(testCase)
actor = testCase.TestData.actor;
verifyEqual(testCase, actor.ObservationInfo.Dimension, [52 1]);
verifyEqual(testCase, actor.ActionInfo.Dimension, [4 1]);
verifyEqual(testCase, string(actor.UseDevice), "cpu");
network = getModel(actor);
verifyEqual(testCase, string(network.InputNames), "observation");
verifyEmpty(testCase, network.State);
verifyEqual(testCase, getAction(actor, {zeros(52,1)}), ...
    getAction(actor, {zeros(52,1)}));
verifyEqual(testCase, testCase.TestData.policyManifest.checkpointSHA256, ...
    "0e6b986b76fcaa63b067ea023809864d5da9db038b756c4726e02a59c106fd54");
end

function testMarkov52InitialStateDoesNotUseTeacher(testCase)
emg = testCase.TestData.emg;
teacher = testCase.TestData.teacher;
counterfactual = teacher(end:-1:1);
verifyNotEqual(testCase, counterfactual, teacher);
envA = Env("", true, {emg, emg}, {teacher, teacher});
envC = Env("", true, {emg, emg}, {counterfactual, counterfactual});
rng(62001, "twister"); stateA = reset(envA);
rng(62001, "twister"); stateC = reset(envC);
runtime = GloveFreePolicyRuntime(emg, zeros(1,4));
verifyEqual(testCase, stateA, stateC);
verifyEqual(testCase, runtime.state, stateA);
verifySize(testCase, stateA, [52 1]);
p = configurables();
verifyEqual(testCase, stateA(1:40), p.fGetFeatures(emg(1:40,:)));
verifyEqual(testCase, stateA(41:44), zeros(4,1));
verifyEqual(testCase, stateA(45:48), zeros(4,1));
verifyEqual(testCase, stateA(49:52), zeros(4,1));
end

function testRuntimeNeverConstructsGloveOrProvidesRlInterface(testCase)
profile clear
profile on
stopProfiler = onCleanup(@() profile("off")); %#ok<NASGU>
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg);
[~, ~, record] = runtime.advance([0.4; -0.4; 0.6; -0.6]);
profile off
profileData = profile("info");
functions = string({profileData.FunctionTable.FunctionName});
verifyFalse(testCase, any(contains(functions, "RecordedGlove")));
verifyFalse(testCase, any(contains(functions, "FakeGlove")));
verifyFalse(testCase, any(contains(functions, "Glove.Glove")));
verifyFalse(testCase, isprop(runtime, "glove"));
verifyFalse(testCase, isprop(runtime, "gloveSet"));
verifyFalse(testCase, isa(runtime, "rl.env.MATLABEnvironment"));
verifyFalse(testCase, ismethod(runtime, "step"));
verifyFalse(testCase, isfield(record, "reward"));
verifyFalse(testCase, isfield(record, "trackingMse"));
end

function testRuntimeTerminationDependsOnlyOnEmgExhaustion(testCase)
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg);
verifyEqual(testCase, runtime.c, 0);
verifyFalse(testCase, runtime.exhausted); % reset consume 40 de 100
[~, firstDone] = runtime.advance(zeros(4,1)); % otras 40
verifyFalse(testCase, firstDone);
[~, secondDone, record] = runtime.advance(zeros(4,1)); % las 20 finales
verifyTrue(testCase, secondDone);
verifyTrue(testCase, runtime.exhausted);
verifyEqual(testCase, runtime.c, 2);
p = configurables();
verifyEqual(testCase, record.stateAfter(1:40), ...
    p.fGetFeatures(testCase.TestData.syntheticEmg(81:100,:)));
verifyError(testCase, @() runtime.advance(zeros(4,1)), "E2A:EmgExhausted");
end

function testPreviousEffectiveActionAndEncoderDeltaContract(testCase)
initial = [5000 3000 2000 3000]; % unidades reales de encoder
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg, initial);
rawAction = [0.25; -0.4; 0.9; 0.03];
[state, ~, record] = runtime.advance(rawAction);
p = configurables();
verifyEqual(testCase, state(41:44), p.encoder2state_scale(record.q'));
verifyEqual(testCase, state(45:48), ...
    max(-1, min(1, p.encoder2state_scale(record.q') - p.encoder2state_scale(initial'))));
verifyEqual(testCase, state(49:52), record.effectiveAction);
verifyEqual(testCase, record.rawAction, rawAction);
verifyEqual(testCase, record.effectiveAction, record.pwm/255);
verifyEqual(testCase, record.pwm, [64; -96; 224; 0]);
end

function testTrainingPurposeRejected(testCase)
verifyError(testCase, @() GloveFreePolicyRuntime(testCase.TestData.syntheticEmg, ...
    zeros(1,4), purpose="training"), "E2A:TrainingForbidden");
end

function testTrainingConfigurationRejectedAtConstructionAndAdvance(testCase)
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg);
override = testCase.TestData.override;
override.run_training = true;
restore = onCleanup(@() setConfigurablesOverride(testCase.TestData.override)); %#ok<NASGU>
setConfigurablesOverride(override);
verifyError(testCase, @() GloveFreePolicyRuntime(testCase.TestData.syntheticEmg), ...
    "E2A:TrainingForbidden");
verifyError(testCase, @() runtime.advance(zeros(4,1)), "E2A:TrainingForbidden");
end

function testTrainingApiExplicitlyRejectedIncludingTd3Dispatch(testCase)
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg);
verifyError(testCase, @() train(runtime), "E2A:TrainingForbidden");
verifyError(testCase, @() train(testCase.TestData.agent, runtime), "E2A:TrainingForbidden");
end

function testRuntimePersistsE0PManifest(testCase)
temporary = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
manifestPath = string(fullfile(temporary.Folder, "plant_manifest.json"));
runtime = GloveFreePolicyRuntime(testCase.TestData.syntheticEmg, zeros(1,4), ...
    outputManifestPath=manifestPath);
saved = jsondecode(fileread(manifestPath));
verifyEqual(testCase, string(saved.simPlantSource), "patternCurveCanonical");
verifyEqual(testCase, string(saved.patternCurveSHA256), ...
    "a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590");
verifyEqual(testCase, string(saved.patternCurvePath), runtime.plantManifest.patternCurvePath);
verifyTrue(testCase, isfield(saved, "fitC2Present"));
verifyTrue(testCase, isfield(saved, "curveFittingToolboxPresent"));
end

function testTeacherAbsentAndCounterfactualCausalIdentity(testCase)
emg = testCase.TestData.emg;
teacher = testCase.TestData.teacher;
actor = testCase.TestData.actor;
traceA = teacherRollout(emg, teacher, actor);
traceC = teacherRollout(emg, teacher(end:-1:1), actor);
[emgB, absent] = loadE2ADevelopmentEpisode("BLANCA", 1, 1);
verifyEmpty(testCase, absent);
verifyEqual(testCase, emgB, emg);
traceB = absentRollout(emgB, actor, traceA.q(1,:));
common = min([traceA.steps, traceB.steps, traceC.steps]);
verifyGreaterThan(testCase, common, 0);
% La muestra BLANCA elegida tiene guante mas corto: no igualar horizontes.
verifyLessThan(testCase, traceA.steps, traceB.steps);
verifyEqual(testCase, traceB.state(1:common+1,:), traceA.state(1:common+1,:));
verifyEqual(testCase, traceC.state(1:common+1,:), traceA.state(1:common+1,:));
verifyEqual(testCase, traceB.rawAction(1:common,:), traceA.rawAction(1:common,:));
verifyEqual(testCase, traceC.rawAction(1:common,:), traceA.rawAction(1:common,:));
verifyEqual(testCase, traceB.effectiveAction(1:common,:), traceA.effectiveAction(1:common,:));
verifyEqual(testCase, traceC.effectiveAction(1:common,:), traceA.effectiveAction(1:common,:));
verifyEqual(testCase, traceB.pwm(1:common,:), traceA.pwm(1:common,:));
verifyEqual(testCase, traceC.pwm(1:common,:), traceA.pwm(1:common,:));
verifyEqual(testCase, traceB.q(1:common+1,:), traceA.q(1:common+1,:));
verifyEqual(testCase, traceC.q(1:common+1,:), traceA.q(1:common+1,:));
verifyGreaterThan(testCase, max(abs(traceC.reward(1:common)-traceA.reward(1:common))), 0);
verifyGreaterThan(testCase, max(abs(traceC.tracking(1:common)-traceA.tracking(1:common))), 0);
end

function trace = teacherRollout(emg, teacher, actor)
env = Env("", true, {emg, emg}, {teacher, teacher});
rng(62001, "twister");
state = reset(env);
encoder = env.prosthesis.read();
trace = newTrace(state, encoder(end,:));
done = false;
while ~done
    action = getAction(actor, {state});
    [state, reward, done] = step(env, action);
    stepIndex = env.c;
    assert(stepIndex <= 50, "E2ATest:Runaway", "Episodio teacher no termina.");
    encoder = env.encoderLog{stepIndex};
    trace.state(stepIndex+1,:) = state';
    trace.rawAction(stepIndex,:) = env.actionLog(stepIndex,:);
    trace.effectiveAction(stepIndex,:) = env.actionSatLog(stepIndex,:);
    trace.pwm(stepIndex,:) = env.actionPwmLog(stepIndex,:);
    trace.q(stepIndex+1,:) = encoder(end,:);
    trace.reward(stepIndex,1) = reward;
    trace.tracking(stepIndex,1) = env.trackingMseLog(stepIndex);
end
trace.steps = env.c;
end

function trace = absentRollout(emg, actor, initialPosition)
rng(62001, "twister");
runtime = GloveFreePolicyRuntime(emg, initialPosition);
trace = newTrace(runtime.state, runtime.q);
while ~runtime.exhausted
    action = getAction(actor, {runtime.state});
    [state, ~, record] = runtime.advance(action);
    stepIndex = runtime.c;
    assert(stepIndex <= 50, "E2ATest:Runaway", "Episodio EMG no termina.");
    trace.state(stepIndex+1,:) = state';
    trace.rawAction(stepIndex,:) = record.rawAction';
    trace.effectiveAction(stepIndex,:) = record.effectiveAction';
    trace.pwm(stepIndex,:) = record.pwm';
    trace.q(stepIndex+1,:) = record.q;
end
trace.steps = runtime.c;
end

function trace = newTrace(state, initialPosition)
trace = struct("state", state', "rawAction", zeros(0,4), ...
    "effectiveAction", zeros(0,4), "pwm", zeros(0,4), ...
    "q", initialPosition, "steps", 0);
end
