function tests = testSandboxViewerDeterminism
% Gate G2 del sandbox: el visor es una funcion determinista de q y no toca
% nada mas. Las pruebas corren sin abrir figuras (createFigure=false).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
here = fileparts(mfilename("fullpath"));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
testCase.TestData.oldPath = path;
testCase.TestData.oldDir = cd(matlabRoot);
addpath(genpath(matlabRoot));
testCase.TestData.hadOverride = isappdata(0, "configurables_override");
if testCase.TestData.hadOverride
    testCase.TestData.previousOverride = getappdata(0, "configurables_override");
end
setConfigurablesOverride(struct("run_training", false, "usePrerecorded", true, ...
    "simMotors", true, "observationVariant", "markov52", ...
    "simPlantSource", "patternCurveCanonical", ...
    "actionInterfaceVariant", "baselineQuantized"));
testCase.TestData.model = handKinematicModel();
testCase.TestData.encoderLimits = [26500 11500 8500 9000];
end

function teardownOnce(testCase)
if testCase.TestData.hadOverride
    setConfigurablesOverride(testCase.TestData.previousOverride);
else
    clearConfigurablesOverride();
end
cd(testCase.TestData.oldDir);
path(testCase.TestData.oldPath);
end

function testSameQGivesIdenticalPose(testCase)
q = [8000 3000 4000 3500];
first = HandKinematicViewer.poseFromQ(q, testCase.TestData.model, "encoder");
other = HandKinematicViewer.poseFromQ([0 0 0 0], testCase.TestData.model, "encoder"); %#ok<NASGU>
second = HandKinematicViewer.poseFromQ(q, testCase.TestData.model, "encoder");
verifyTrue(testCase, isequal(first, second), ...
    "La pose debe ser identica bit a bit para la misma q.");
end

function testViewerUpdateIsPurelyAFunctionOfQ(testCase)
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
a = viewer.update([9000 3200 4100 3600]);
viewer.update([0 0 0 0]);
b = viewer.update([9000 3200 4100 3600]);
verifyTrue(testCase, isequal(a, b), ...
    "El visor no debe acumular estado entre llamadas.");
end

function testGloveOverlayNeverChangesProsthesisPose(testCase)
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
withoutGlove = viewer.update([9000 3200 4100 3600]);
withGlove = viewer.update([9000 3200 4100 3600], [0.9 0.1 0.5 0.2]);
verifyTrue(testCase, isequal(withoutGlove, withGlove), ...
    "El guante es overlay: no puede alterar la pose de la protesis.");
end

function testGloveOverlayRejectsEncoderUnits(testCase)
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
verifyError(testCase, @() viewer.update([0 0 0 0], [17000 6000 7000 6000]), ...
    "Sandbox:GloveOverlayUnits");
verifyError(testCase, @() viewer.update([0 0 0 0], [0.5 0.5 0.5]), ...
    "Sandbox:GloveOverlayShape");
end

function testUnitsContractIsExplicitAndConsistent(testCase)
model = testCase.TestData.model;
qEncoder = [11000 5000 6000 5200];
qNormalized = qEncoder ./ testCase.TestData.encoderLimits;
a = HandKinematicViewer.poseFromQ(qEncoder, model, "encoder");
b = HandKinematicViewer.poseFromQ(qNormalized, model, "normalized");
verifyEqual(testCase, b.flexionByMotor, a.flexionByMotor, ...
    "Declarar unidades distintas para la misma posicion debe dar la misma pose.", ...
    RelTol = 1e-12);
end

function testFlexionIsMonotonicInQ(testCase)
model = testCase.TestData.model;
range = model.qRangeEncoder;
for motor = 1:4
    samples = linspace(range(1, motor), range(2, motor), 25);
    flexion = zeros(size(samples));
    tip = zeros(size(samples));
    fingerIndex = find([model.fingers.motor] == motor, 1);
    for k = 1:numel(samples)
        q = range(1, :);
        q(motor) = samples(k);
        pose = HandKinematicViewer.poseFromQ(q, model, "encoder");
        flexion(k) = pose.flexionByMotor(motor);
        joints = pose.fingers(fingerIndex).joints;
        tip(k) = norm(joints(end, :) - joints(1, :));
    end
    verifyGreaterThanOrEqual(testCase, diff(flexion), 0, ...
        sprintf("La flexion del motor %d debe crecer con q.", motor));
    verifyLessThanOrEqual(testCase, diff(tip), 1e-9, ...
        sprintf("La punta del dedo del motor %d debe curvarse en un solo sentido.", motor));
end
end

function testSegmentsStayRigidAcrossTheWholeRange(testCase)
model = testCase.TestData.model;
range = model.qRangeEncoder;
worst = 0;
for alpha = linspace(0, 1, 11)
    q = range(1, :) + alpha * (range(2, :) - range(1, :));
    pose = HandKinematicViewer.poseFromQ(q, model, "encoder");
    for k = 1:numel(pose.fingers)
        joints = pose.fingers(k).joints;
        lengths = vecnorm(diff(joints, 1, 1), 2, 2)';
        worst = max(worst, max(abs(lengths - pose.fingers(k).segmentLengths)));
    end
end
verifyLessThan(testCase, worst, 1e-9, ...
    "Los segmentos deben conservar su longitud: la pose es rigida.");
end

function testExtremesProduceFiniteBoundedGeometry(testCase)
model = testCase.TestData.model;
range = model.qRangeEncoder;
for q = {range(1, :), range(2, :)}
    pose = HandKinematicViewer.poseFromQ(q{1}, model, "encoder");
    for k = 1:numel(pose.fingers)
        joints = pose.fingers(k).joints;
        verifyTrue(testCase, all(isfinite(joints), "all"), "Pose no finita.");
        reach = max(vecnorm(joints - joints(1, :), 2, 2));
        verifyLessThanOrEqual(testCase, reach, sum(pose.fingers(k).segmentLengths) + 1e-9, ...
            "Ningun dedo puede alcanzar mas que la suma de sus segmentos.");
    end
end
end

function testQOutsideDeclaredRangeSaturatesWithoutError(testCase)
model = testCase.TestData.model;
low = HandKinematicViewer.flexionFromQ(model.qRangeEncoder(1, :) - 5000, model, "encoder");
high = HandKinematicViewer.flexionFromQ(model.qRangeEncoder(2, :) + 5000, model, "encoder");
verifyEqual(testCase, low, zeros(1, 4));
verifyEqual(testCase, high, ones(1, 4));
end

function testCoupledMotorDrivesRingAndLittleTogether(testCase)
% Evidencia: config/definitions.m:80, flexMapping.little agrega anular y menique.
model = testCase.TestData.model;
q = model.qRangeEncoder(1, :);
q(1) = model.qRangeEncoder(2, 1);
pose = HandKinematicViewer.poseFromQ(q, model, "encoder");
names = [pose.fingers.name];
ring = pose.fingers(names == "ring").flexion;
little = pose.fingers(names == "little").flexion;
index = pose.fingers(names == "index").flexion;
verifyEqual(testCase, ring, little, ...
    "El motor 1 mueve anular y menique con la misma flexion.");
verifyEqual(testCase, index, 0, "El motor 1 no debe mover el indice.");
end

function testRangeModeChangesOnlyTheVisualNormalization(testCase)
plantModel = handKinematicModel(rangeMode = "plantReachable");
firmwareModel = handKinematicModel(rangeMode = "encoderLimit");
q = [17246.5 6665.166666666667 7538.666666666667 6280.833333333333];
plantPose = HandKinematicViewer.poseFromQ(q, plantModel, "encoder");
firmwarePose = HandKinematicViewer.poseFromQ(q, firmwareModel, "encoder");
verifyGreaterThan(testCase, plantPose.flexionByMotor, firmwarePose.flexionByMotor, ...
    "Con limites de firmware la mano dibujada cierra menos: la planta no los alcanza.");
verifyLessThan(testCase, max(firmwarePose.flexionByMotor), 1, ...
    "La planta canonica nunca llega a q normalizada 1.");
end

function testViewerRejectsMalformedInput(testCase)
% Se comprueba que el contrato se hace cumplir; el identificador exacto lo
% fija la validacion de MATLAB y no es parte del contrato del sandbox.
viewer = HandKinematicViewer(units = "encoder", createFigure = false);
verifyError(testCase, @() viewer.update([1 2 3]), ?MException);
verifyError(testCase, @() viewer.update([1 2 3 inf]), ?MException);
verifyError(testCase, @() HandKinematicViewer(units = "flex"), ?MException);
verifyError(testCase, @() HandKinematicViewer(rangeMode = "inventado"), ?MException);
end
