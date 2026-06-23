function results = run_motor2_simulation_sanity_check(options)
%run_motor2_simulation_sanity_check probes motor mapping in simulation only.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

resultsRoot = fullfile(workspaceRoot, "Agentes", ...
    "motor2_simulation_sanity_check", ...
    string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
if isfield(options, "resultsRoot") && strlength(string(options.resultsRoot)) > 0
    resultsRoot = char(string(options.resultsRoot));
end
ensureDirectoryExists(resultsRoot);

duration = localGetOption(options, "duration", 2.0);
samplingPeriod = localGetOption(options, "samplingPeriod", 0.14);

override = struct( ...
    "run_training", false, ...
    "newTraining", false, ...
    "usePrerecorded", true, ...
    "simMotors", true, ...
    "connect_glove", false, ...
    "unifyActions", false, ...
    "quantizeCommandsForSimulation", true, ...
    "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(override);
clear configurables
cleanup = onCleanup(@() clearConfigurablesOverride());

configs = configurables();

caseNames = [ ...
    "zero"; ...
    "motor2_positive"; ...
    "motor2_negative"; ...
    "all_positive"; ...
    "motor1_positive"; ...
    "motor3_positive"; ...
    "motor4_positive"];
rawActions = [ ...
     0  0  0  0; ...
     0  1  0  0; ...
     0 -1  0  0; ...
     1  1  1  1; ...
     1  0  0  0; ...
     0  0  1  0; ...
     0  0  0  1];

numCases = size(rawActions, 1);
responseRangeEncoder = nan(numCases, 4);
responseRangeFlex = nan(numCases, 4);
finalEncoder = nan(numCases, 4);
finalFlex = nan(numCases, 4);
appliedPwm = nan(numCases, 4);
effectiveAction = nan(numCases, 4);
trajectories = cell(numCases, 1);
flexTrajectories = cell(numCases, 1);

for caseIdx = 1:numCases
    [effectiveAction(caseIdx, :), appliedPwm(caseIdx, :)] = ...
        localRemapAction(rawActions(caseIdx, :), configs);
    trajectory = SimController.prosthesis_simulator( ...
        [0 0 0 0], appliedPwm(caseIdx, :), duration, samplingPeriod);
    trajectoryWithInitial = [[0 0 0 0]; trajectory];
    flexTrajectory = configs.flexJoined_scale(encoder2Flex(trajectoryWithInitial));

    trajectories{caseIdx} = trajectoryWithInitial;
    flexTrajectories{caseIdx} = flexTrajectory;
    responseRangeEncoder(caseIdx, :) = localRangeByColumn(trajectoryWithInitial);
    responseRangeFlex(caseIdx, :) = localRangeByColumn(flexTrajectory);
    finalEncoder(caseIdx, :) = trajectoryWithInitial(end, :);
    finalFlex(caseIdx, :) = flexTrajectory(end, :);
end

summaryTable = table(caseNames, ...
    rawActions(:, 1), rawActions(:, 2), rawActions(:, 3), rawActions(:, 4), ...
    appliedPwm(:, 1), appliedPwm(:, 2), appliedPwm(:, 3), appliedPwm(:, 4), ...
    effectiveAction(:, 1), effectiveAction(:, 2), effectiveAction(:, 3), effectiveAction(:, 4), ...
    responseRangeEncoder(:, 1), responseRangeEncoder(:, 2), responseRangeEncoder(:, 3), responseRangeEncoder(:, 4), ...
    responseRangeFlex(:, 1), responseRangeFlex(:, 2), responseRangeFlex(:, 3), responseRangeFlex(:, 4), ...
    finalEncoder(:, 1), finalEncoder(:, 2), finalEncoder(:, 3), finalEncoder(:, 4), ...
    finalFlex(:, 1), finalFlex(:, 2), finalFlex(:, 3), finalFlex(:, 4), ...
    'VariableNames', { ...
    'caseName', ...
    'rawActionMotor1', 'rawActionMotor2', 'rawActionMotor3', 'rawActionMotor4', ...
    'appliedPwmMotor1', 'appliedPwmMotor2', 'appliedPwmMotor3', 'appliedPwmMotor4', ...
    'effectiveActionMotor1', 'effectiveActionMotor2', 'effectiveActionMotor3', 'effectiveActionMotor4', ...
    'responseRangeEncoderMotor1', 'responseRangeEncoderMotor2', 'responseRangeEncoderMotor3', 'responseRangeEncoderMotor4', ...
    'responseRangeFlexMotor1', 'responseRangeFlexMotor2', 'responseRangeFlexMotor3', 'responseRangeFlexMotor4', ...
    'finalEncoderMotor1', 'finalEncoderMotor2', 'finalEncoderMotor3', 'finalEncoderMotor4', ...
    'finalFlexMotor1', 'finalFlexMotor2', 'finalFlexMotor3', 'finalFlexMotor4'});

csvPath = fullfile(resultsRoot, "motor2_sanity_check.csv");
figurePath = fullfile(resultsRoot, "motor2_sanity_check.png");
writetable(summaryTable, csvPath);
localCreateSanityFigure( ...
    figurePath, caseNames, appliedPwm, responseRangeFlex, finalFlex, flexTrajectories);

results = struct();
results.resultsRoot = string(resultsRoot);
results.csvPath = string(csvPath);
results.figurePath = string(figurePath);
results.summaryTable = summaryTable;
results.duration = duration;
results.samplingPeriod = samplingPeriod;
results.trajectories = trajectories;
results.flexTrajectories = flexTrajectories;

save(fullfile(resultsRoot, "motor2_sanity_check_results.mat"), "results");
end

function value = localGetOption(options, fieldName, defaultValue)
if isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function [effectiveAction, appliedPwm] = localRemapAction(action, configs)
action = max(-1, min(1, double(action(:))));
maxPwm = max(abs(configs.speeds));
levels = sort(unique(abs(double(configs.actionCommandLevels(:)'))));
nonZeroLevels = levels(levels > 0);

effectiveAction = zeros(size(action));
appliedPwm = zeros(size(action));
for motorIdx = 1:numel(action)
    actionValue = action(motorIdx);
    magnitude = abs(actionValue);
    if magnitude < configs.actionCommandActivationThreshold
        continue;
    end
    targetPwm = magnitude * maxPwm;
    [~, idx] = min(abs(nonZeroLevels - targetPwm));
    pwmMagnitude = nonZeroLevels(idx);
    appliedPwm(motorIdx) = sign(actionValue) * pwmMagnitude;
    effectiveAction(motorIdx) = appliedPwm(motorIdx) / maxPwm;
end

effectiveAction = effectiveAction(:).';
appliedPwm = appliedPwm(:).';
end

function ranges = localRangeByColumn(values)
ranges = nan(1, size(values, 2));
for i = 1:size(values, 2)
    column = values(:, i);
    column = column(isfinite(column));
    if ~isempty(column)
        ranges(i) = max(column) - min(column);
    end
end
end

function localCreateSanityFigure(figurePath, caseNames, appliedPwm, responseRangeFlex, finalFlex, flexTrajectories)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off");
set(f, "Units", "normalized", "OuterPosition", [0 0 1 1]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

ax = nexttile;
hold(ax, "on");
plotCases = [1 2 3 4];
for idx = plotCases
    values = flexTrajectories{idx};
    plot(ax, values(:, 2), "LineWidth", 1.2);
end
grid(ax, "on");
title(ax, "Motor 2 simulated flex response");
xlabel(ax, "Simulator sample");
ylabel(ax, "Normalized flex");
legend(ax, caseNames(plotCases), "Location", "best", "Interpreter", "none");

ax = nexttile;
bar(ax, responseRangeFlex);
grid(ax, "on");
title(ax, "Response range by motor");
xlabel(ax, "Case");
ylabel(ax, "Range");
set(ax, "XTick", 1:numel(caseNames), "XTickLabel", caseNames, "XTickLabelRotation", 35);
legend(ax, ["M1", "M2", "M3", "M4"], "Location", "best");

ax = nexttile;
bar(ax, finalFlex);
grid(ax, "on");
title(ax, "Final normalized flex by motor");
xlabel(ax, "Case");
ylabel(ax, "Final flex");
set(ax, "XTick", 1:numel(caseNames), "XTickLabel", caseNames, "XTickLabelRotation", 35);
legend(ax, ["M1", "M2", "M3", "M4"], "Location", "best");

ax = nexttile;
bar(ax, appliedPwm);
grid(ax, "on");
title(ax, "Applied PWM by motor");
xlabel(ax, "Case");
ylabel(ax, "PWM");
set(ax, "XTick", 1:numel(caseNames), "XTickLabel", caseNames, "XTickLabelRotation", 35);
legend(ax, ["M1", "M2", "M3", "M4"], "Location", "best");

sgtitle(f, "Motor 2 simulator sanity check");
saveas(f, figurePath);
close(f);
end
