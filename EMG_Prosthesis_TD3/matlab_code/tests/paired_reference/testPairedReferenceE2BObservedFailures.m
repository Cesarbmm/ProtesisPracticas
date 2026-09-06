function tests=testPairedReferenceE2BObservedFailures
% Regresiones de CARACTERIZACION anadidas DESPUES del resultado E2B FAIL.
% No son criterios de aceptacion de planta: conservan defectos medidos.
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.TestData.oldPath=path;
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testCharacterizesMotor3ReversalAtOperationalPeriod(t)
initial=[0 0 7584.5 0];
trajectory=SimController.prosthesis_simulator(initial,[0 0 255 0],.2,.14, ...
    plantSource="patternCurveCanonical");
verifyLessThan(t,trajectory(end,3),initial(3));
verifyEqual(t,trajectory(end,3),7566.666666666667,"AbsTol",1e-9);
verifyEqual(t,trajectory(end,[1 2 4]),initial([1 2 4]));
end
function testCharacterizesObservedMotor3TwoCycle(t)
q=[0 0 1541.666666666667 0];
expected=[7532.5 1541.666666666667 7532.5 1541.666666666667];
commands=[224 -64 224 -64];
for k=1:4
    q=SimController.prosthesis_simulator(q,[0 0 commands(k) 0],.2,.14, ...
        plantSource="patternCurveCanonical");
    verifyEqual(t,q(end,3),expected(k),"AbsTol",1e-9);
end
end
function testCharacterizesObservedMotor4TwoCycle(t)
q=[0 0 0 6049.75];
expected=[2976.333333333333 6049.75 2976.333333333333 6049.75];
commands=[-64 96 -64 96];
for k=1:4
    q=SimController.prosthesis_simulator(q,[0 0 0 commands(k)],.2,.14, ...
        plantSource="patternCurveCanonical");
    verifyEqual(t,q(end,4),expected(k),"AbsTol",1e-9);
end
end
