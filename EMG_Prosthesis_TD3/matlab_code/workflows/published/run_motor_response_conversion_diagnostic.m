function results = run_motor_response_conversion_diagnostic(options)
%run_motor_response_conversion_diagnostic isolates encoder-to-flex conversion.
%
% This workflow is simulation-only. It applies direct per-motor commands and
% stores encoder, encoder2Flex and normalized flex trajectories separately.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

resultsRoot = fullfile(workspaceRoot, "Agentes", ...
    "motor_response_conversion_diagnostic", ...
    string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
if isfield(options, "resultsRoot") && strlength(string(options.resultsRoot)) > 0
    resultsRoot = char(string(options.resultsRoot));
end
summaryRoot = fullfile(resultsRoot, "summary");
figuresRoot = fullfile(resultsRoot, "figures");
ensureDirectoryExists(resultsRoot);
ensureDirectoryExists(summaryRoot);
ensureDirectoryExists(figuresRoot);

levels = [-1.00 -0.75 -0.50 -0.25 0 0.25 0.50 0.75 1.00];
if isfield(options, "levels") && ~isempty(options.levels)
    levels = double(options.levels(:))';
end
duration = localGetOption(options, "duration", 2.0);
samplingPeriod = localGetOption(options, "samplingPeriod", 0.14);
initialEncoder = localGetOption(options, "initialEncoder", [0 0 0 0]);
initialEncoder = double(initialEncoder(:))';

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
cleanup = onCleanup(@() clearConfigurablesOverride()); %#ok<NASGU>

configs = configurables();
numMotors = 4;
numLevels = numel(levels);
rows = cell(numMotors * numLevels, 1);
trajectoryRows = cell(numMotors * numLevels, 1);
encoderRangeMatrix = nan(numMotors, numLevels);
encoder2FlexRangeMatrix = nan(numMotors, numLevels);
normalizedFlexRangeMatrix = nan(numMotors, numLevels);
finalFlexDeltaMatrix = nan(numMotors, numLevels);
stageMatrix = strings(numMotors, numLevels);
rowIdx = 0;

initialFlexRaw = encoder2Flex(initialEncoder);
initialFlexNorm = configs.flexJoined_scale(initialFlexRaw);

for motorIdx = 1:numMotors
    for levelIdx = 1:numLevels
        action = zeros(1, numMotors);
        action(motorIdx) = levels(levelIdx);
        [effectiveAction, appliedPwm] = localRemapAction(action, configs);

        encoderTrajectory = SimController.prosthesis_simulator( ...
            initialEncoder, appliedPwm, duration, samplingPeriod);
        encoderTrajectory = [initialEncoder; encoderTrajectory]; %#ok<AGROW>
        encoder2FlexTrajectory = encoder2Flex(encoderTrajectory);
        normalizedFlexTrajectory = configs.flexJoined_scale(encoder2FlexTrajectory);

        encoderRange = localRange(encoderTrajectory(:, motorIdx));
        encoder2FlexRange = localRange(encoder2FlexTrajectory(:, motorIdx));
        normalizedFlexRange = localRange(normalizedFlexTrajectory(:, motorIdx));
        finalFlexDelta = normalizedFlexTrajectory(end, motorIdx) - ...
            initialFlexNorm(motorIdx);
        flattenStage = localClassifyFlattening( ...
            encoderRange, encoder2FlexRange, normalizedFlexRange, options);

        encoderRangeMatrix(motorIdx, levelIdx) = encoderRange;
        encoder2FlexRangeMatrix(motorIdx, levelIdx) = encoder2FlexRange;
        normalizedFlexRangeMatrix(motorIdx, levelIdx) = normalizedFlexRange;
        finalFlexDeltaMatrix(motorIdx, levelIdx) = finalFlexDelta;
        stageMatrix(motorIdx, levelIdx) = flattenStage;

        rowIdx = rowIdx + 1;
        rows{rowIdx} = struct( ...
            "motor", motorIdx, ...
            "rawAction", levels(levelIdx), ...
            "effectiveAction", effectiveAction(motorIdx), ...
            "appliedPwm", appliedPwm(motorIdx), ...
            "encoderRange", encoderRange, ...
            "encoder2FlexRange", encoder2FlexRange, ...
            "normalizedFlexRange", normalizedFlexRange, ...
            "finalFlexDelta", finalFlexDelta, ...
            "flattenStage", flattenStage, ...
            "encoderTrajectory", localVectorString(encoderTrajectory(:, motorIdx)), ...
            "encoder2FlexTrajectory", localVectorString(encoder2FlexTrajectory(:, motorIdx)), ...
            "normalizedFlexTrajectory", localVectorString(normalizedFlexTrajectory(:, motorIdx)));
        trajectoryRows{rowIdx} = struct( ...
            "motor", motorIdx, ...
            "rawAction", levels(levelIdx), ...
            "appliedPwm", appliedPwm(motorIdx), ...
            "encoderTrajectory", encoderTrajectory, ...
            "encoder2FlexTrajectory", encoder2FlexTrajectory, ...
            "normalizedFlexTrajectory", normalizedFlexTrajectory);
    end
end

diagnosticTable = struct2table(vertcat(rows{:}));
csvPath = fullfile(summaryRoot, "motor_response_conversion_diagnostic.csv");
matPath = fullfile(summaryRoot, "motor_response_conversion_diagnostic.mat");
curvesPath = fullfile(figuresRoot, "motor_response_conversion_curves.png");
gainPath = fullfile(figuresRoot, "motor_response_conversion_gain_matrix.png");

writetable(diagnosticTable, csvPath);
localCreateCurvesFigure(curvesPath, levels, encoderRangeMatrix, ...
    encoder2FlexRangeMatrix, normalizedFlexRangeMatrix);
localCreateGainFigure(gainPath, levels, encoderRangeMatrix, ...
    encoder2FlexRangeMatrix, normalizedFlexRangeMatrix, finalFlexDeltaMatrix);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.csvPath = string(csvPath);
results.matPath = string(matPath);
results.curvesFigurePath = string(curvesPath);
results.gainFigurePath = string(gainPath);
results.levels = levels;
results.duration = duration;
results.samplingPeriod = samplingPeriod;
results.initialEncoder = initialEncoder;
results.initialFlexRaw = initialFlexRaw;
results.initialFlexNorm = initialFlexNorm;
results.diagnosticTable = diagnosticTable;
results.trajectoryRows = vertcat(trajectoryRows{:});
results.encoderRangeMatrix = encoderRangeMatrix;
results.encoder2FlexRangeMatrix = encoder2FlexRangeMatrix;
results.normalizedFlexRangeMatrix = normalizedFlexRangeMatrix;
results.finalFlexDeltaMatrix = finalFlexDeltaMatrix;
results.stageMatrix = stageMatrix;

save(matPath, "results", "diagnosticTable", "trajectoryRows", ...
    "encoderRangeMatrix", "encoder2FlexRangeMatrix", ...
    "normalizedFlexRangeMatrix", "finalFlexDeltaMatrix", "stageMatrix");
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
    if magnitude < configs.actionCommandActivationThreshold || isempty(nonZeroLevels)
        continue;
    end
    targetPwm = magnitude * maxPwm;
    [~, idx] = min(abs(nonZeroLevels - targetPwm));
    appliedPwm(motorIdx) = sign(actionValue) * nonZeroLevels(idx);
    effectiveAction(motorIdx) = appliedPwm(motorIdx) / maxPwm;
end

effectiveAction = effectiveAction(:).';
appliedPwm = appliedPwm(:).';
end

function value = localRange(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x) - min(x);
end
end

function stage = localClassifyFlattening(encoderRange, encoder2FlexRange, ...
        normalizedFlexRange, options)
encoderFlatThreshold = localGetOption(options, "encoderFlatThreshold", 1.0);
flexFlatThreshold = localGetOption(options, "flexFlatThreshold", 1e-6);
normalizedFlatThreshold = localGetOption(options, "normalizedFlatThreshold", 1e-4);

if any(~isfinite([encoderRange, encoder2FlexRange, normalizedFlexRange]))
    stage = "unknown";
elseif encoderRange <= encoderFlatThreshold
    stage = "encoder_flat";
elseif encoder2FlexRange <= flexFlatThreshold
    stage = "encoder2Flex_flat";
elseif normalizedFlexRange <= normalizedFlatThreshold
    stage = "flexJoined_scale_flat";
else
    stage = "responsive";
end
end

function textValue = localVectorString(values)
values = double(values(:))';
textValue = strjoin(compose("%.9g", values), " ");
end

function localCreateCurvesFigure(figurePath, levels, encoderRange, ...
        encoder2FlexRange, normalizedFlexRange)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 3, 1, "TileSpacing", "compact", "Padding", "compact");
localLinePlot(nexttile, levels, encoderRange, "Encoder range");
localLinePlot(nexttile, levels, encoder2FlexRange, "encoder2Flex range");
localLinePlot(nexttile, levels, normalizedFlexRange, "Normalized flex range");
sgtitle(f, "Motor response conversion curves");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localLinePlot(ax, levels, values, plotTitle)
plot(ax, levels, values.', "-o", "LineWidth", 1.2);
grid(ax, "on");
title(ax, plotTitle);
xlabel(ax, "Raw action level");
ylabel(ax, "Range");
legend(ax, ["M1", "M2", "M3", "M4"], "Location", "bestoutside");
end

function localCreateGainFigure(figurePath, levels, encoderRange, ...
        encoder2FlexRange, normalizedFlexRange, finalFlexDelta)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
localHeatmap(nexttile, levels, encoderRange, "Encoder range");
localHeatmap(nexttile, levels, encoder2FlexRange, "encoder2Flex range");
localHeatmap(nexttile, levels, normalizedFlexRange, "Normalized flex range");
localHeatmap(nexttile, levels, finalFlexDelta, "Final normalized flex delta");
sgtitle(f, "Motor response conversion gain matrix");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localHeatmap(ax, levels, matrixValues, plotTitle)
imagesc(ax, levels, 1:4, matrixValues);
colorbar(ax);
grid(ax, "on");
title(ax, plotTitle);
xlabel(ax, "Raw action level");
ylabel(ax, "Motor");
set(ax, "YTick", 1:4, "YTickLabel", ["M1", "M2", "M3", "M4"]);
end
