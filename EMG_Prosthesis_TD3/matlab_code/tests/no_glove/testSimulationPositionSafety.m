function tests = testSimulationPositionSafety
%testSimulationPositionSafety deterministic simulation-boundary tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
end

function setup(~)
clearConfigurablesOverride();
end

function teardown(~)
clearConfigurablesOverride();
end

function testDisabledAdapterIsExactIdentity(testCase)
config = nominalConfig(false);
encoder = [-100, 12000, 4250, 10000; ...
    13250, 5750, 9000, -1];
[actual, info] = limitSimulationPosition(encoder, config);
testCase.verifyEqual(actual, encoder);
testCase.verifyEqual(info.interventionCount, 0);
testCase.verifyEqual(info.interventionCountByMotor, zeros(1, 4));
end

function testEnabledAdapterClipsEachMotorAndCounts(testCase)
config = nominalConfig(true);
encoder = [-100, 12000, 4250, 10000; ...
    13250, 5750, 9000, -1];
[actual, info] = limitSimulationPosition(encoder, config);
expected = [0, 11500, 4250, 9000; ...
    13250, 5750, 8500, 0];
testCase.verifyEqual(actual, expected);
testCase.verifyEqual(info.interventionCountByMotor, [1, 1, 1, 2]);
testCase.verifyEqual(info.interventionCount, 5);
end

function testEnabledAdapterDoesNotHideNonfiniteData(testCase)
config = nominalConfig(true);
encoder = [NaN, Inf, -Inf, 4500];
[actual, info] = limitSimulationPosition(encoder, config);
testCase.verifyTrue(isnan(actual(1)));
testCase.verifyEqual(actual(2), Inf);
testCase.verifyEqual(actual(3), -Inf);
testCase.verifyEqual(actual(4), 4500);
testCase.verifyEqual(info.interventionCount, 0);
end

function testHardwareProfileCannotEnableSimulationAdapter(testCase)
override = struct( ...
    "simMotors", false, ...
    "simulationPositionSafety", nominalConfig(true));
setConfigurablesOverride(override);
testCase.verifyError(@() configurables(), ...
    "configurables:SimulationSafetyRequiresSimulator");
end

function config = nominalConfig(enabled)
config = struct( ...
    "enabled", logical(enabled), ...
    "mode", "clipTrajectoryOutput", ...
    "positionMin", zeros(1, 4), ...
    "positionMax", ones(1, 4), ...
    "encoderScale", [26500, 11500, 8500, 9000]);
end
