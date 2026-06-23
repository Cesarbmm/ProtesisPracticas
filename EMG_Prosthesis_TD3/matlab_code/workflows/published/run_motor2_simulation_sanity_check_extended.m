function results = run_motor2_simulation_sanity_check_extended(options)
%run_motor2_simulation_sanity_check_extended probes per-motor gain/sign.
%
% The workflow is simulation-only. It can run from home, mid and closed
% encoder positions so opening commands are not judged only from home.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

resultsRoot = fullfile(workspaceRoot, "Agentes", ...
    "motor2_simulation_sanity_check_extended", ...
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
initialMode = lower(string(localGetOption(options, "initialMode", "home")));
modeNames = localResolveModeNames(initialMode);
variantName = string(localGetOption(options, "encoder2FlexVariant", "baseline"));
if ~ismember(variantName, ["baseline", "motor2Calibrated"])
    error("Unsupported encoder2FlexVariant '%s'.", variantName);
end

override = struct( ...
    "run_training", false, ...
    "newTraining", false, ...
    "usePrerecorded", true, ...
    "simMotors", true, ...
    "connect_glove", false, ...
    "unifyActions", false, ...
    "quantizeCommandsForSimulation", true, ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "encoder2FlexVariant", variantName);
setConfigurablesOverride(override);
clear configurables
cleanup = onCleanup(@() clearConfigurablesOverride());

configs = configurables();
modeResults = struct();
primaryMode = modeNames(1);

for modeIdx = 1:numel(modeNames)
    modeName = modeNames(modeIdx);
    initialEncoder = localInitialEncoderForMode(modeName);
    modeResult = localRunMode(configs, levels, duration, ...
        samplingPeriod, initialEncoder, modeName);

    csvPath = fullfile(summaryRoot, "motor2_sanity_" + modeName + ".csv");
    signPath = fullfile(summaryRoot, "motor2_sign_" + modeName + ".csv");
    figurePath = fullfile(figuresRoot, ...
        "motor_response_gain_matrix_" + modeName + ".png");
    writetable(modeResult.gainTable, csvPath);
    writetable(modeResult.signTable, signPath);
    localCreateGainFigure(figurePath, levels, ...
        modeResult.responseRangeFlexMatrix, modeResult.gainMatrix, ...
        modeResult.finalFlexDeltaMatrix);

    modeResult.gainCsvPath = string(csvPath);
    modeResult.signCsvPath = string(signPath);
    modeResult.figurePath = string(figurePath);
    modeResults.(char(modeName)) = modeResult;
end

primary = modeResults.(char(primaryMode));
gainCsvPath = fullfile(resultsRoot, "motor_response_gain_matrix.csv");
signCsvPath = fullfile(resultsRoot, "motor_sign_check.csv");
figurePath = fullfile(resultsRoot, "motor_response_gain_matrix.png");
writetable(primary.gainTable, gainCsvPath);
writetable(primary.signTable, signCsvPath);
localCreateGainFigure(figurePath, levels, primary.responseRangeFlexMatrix, ...
    primary.gainMatrix, primary.finalFlexDeltaMatrix);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.gainCsvPath = string(gainCsvPath);
results.signCsvPath = string(signCsvPath);
results.figurePath = string(figurePath);
results.levels = levels;
results.duration = duration;
results.samplingPeriod = samplingPeriod;
results.initialMode = initialMode;
results.modeNames = modeNames;
results.encoder2FlexVariant = variantName;
results.modeResults = modeResults;
results.gainTable = primary.gainTable;
results.signTable = primary.signTable;
results.responseRangeFlexMatrix = primary.responseRangeFlexMatrix;
results.responseRangeEncoderMatrix = primary.responseRangeEncoderMatrix;
results.gainMatrix = primary.gainMatrix;
results.finalFlexDeltaMatrix = primary.finalFlexDeltaMatrix;

save(fullfile(resultsRoot, "motor2_extended_sanity_check.mat"), "results");
end

function modeResult = localRunMode(configs, levels, duration, ...
        samplingPeriod, initialEncoder, modeName)
numMotors = 4;
numLevels = numel(levels);
initialFlex = configs.flexJoined_scale( ...
    encoder2FlexVariant(initialEncoder, configs));

rows = cell(numMotors * numLevels, 1);
responseRangeFlexMatrix = nan(numMotors, numLevels);
responseRangeEncoderMatrix = nan(numMotors, numLevels);
gainMatrix = nan(numMotors, numLevels);
finalFlexDeltaMatrix = nan(numMotors, numLevels);
rowIdx = 0;

for motorIdx = 1:numMotors
    for levelIdx = 1:numLevels
        action = zeros(1, numMotors);
        action(motorIdx) = levels(levelIdx);
        [effectiveAction, appliedPwm] = localRemapAction(action, configs);
        trajectory = SimController.prosthesis_simulator( ...
            initialEncoder, appliedPwm, duration, samplingPeriod);
        trajectory = [initialEncoder; trajectory]; %#ok<AGROW>
        flexTrajectory = configs.flexJoined_scale( ...
            encoder2FlexVariant(trajectory, configs));

        responseRangeEncoder = localRange(trajectory(:, motorIdx));
        responseRangeFlex = localRange(flexTrajectory(:, motorIdx));
        finalEncoder = trajectory(end, motorIdx);
        finalFlex = flexTrajectory(end, motorIdx);
        finalFlexDelta = finalFlex - initialFlex(motorIdx);
        if levels(levelIdx) == 0
            gain = NaN;
        else
            gain = finalFlexDelta / levels(levelIdx);
        end

        responseRangeFlexMatrix(motorIdx, levelIdx) = responseRangeFlex;
        responseRangeEncoderMatrix(motorIdx, levelIdx) = responseRangeEncoder;
        gainMatrix(motorIdx, levelIdx) = gain;
        finalFlexDeltaMatrix(motorIdx, levelIdx) = finalFlexDelta;

        rowIdx = rowIdx + 1;
        rows{rowIdx} = struct( ...
            "initialMode", modeName, ...
            "encoder2FlexVariant", string(configs.encoder2FlexVariant), ...
            "initialEncoder", localVectorString(initialEncoder), ...
            "motor", motorIdx, ...
            "level", levels(levelIdx), ...
            "appliedPwm", appliedPwm(motorIdx), ...
            "effectiveAction", effectiveAction(motorIdx), ...
            "responseRangeEncoder", responseRangeEncoder, ...
            "responseRangeFlex", responseRangeFlex, ...
            "finalEncoder", finalEncoder, ...
            "finalFlex", finalFlex, ...
            "finalFlexDelta", finalFlexDelta, ...
            "signEstimate", sign(finalFlexDelta), ...
            "gainApprox", gain);
    end
end

gainTable = struct2table(vertcat(rows{:}));
signTable = localBuildSignTable(gainTable, numMotors);

modeResult = struct();
modeResult.initialMode = modeName;
modeResult.initialEncoder = initialEncoder;
modeResult.initialFlex = initialFlex;
modeResult.gainTable = gainTable;
modeResult.signTable = signTable;
modeResult.responseRangeFlexMatrix = responseRangeFlexMatrix;
modeResult.responseRangeEncoderMatrix = responseRangeEncoderMatrix;
modeResult.gainMatrix = gainMatrix;
modeResult.finalFlexDeltaMatrix = finalFlexDeltaMatrix;
end

function value = localGetOption(options, fieldName, defaultValue)
if isfield(options, fieldName) && ~isempty(options.(fieldName))
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function modeNames = localResolveModeNames(initialMode)
validModes = ["home", "mid", "closed", "all"];
if ~ismember(initialMode, validModes)
    error("Unsupported initialMode '%s'.", initialMode);
end
if initialMode == "all"
    modeNames = ["home", "mid", "closed"];
else
    modeNames = initialMode;
end
end

function initialEncoder = localInitialEncoderForMode(modeName)
motorIdx = definitions("motorIdx");
gap = definitions("gap");
breakLimit = definitions("breakLimit");
fingers = string(definitions("fingers"));
initialEncoder = zeros(1, 4);

for fingerIdx = 1:numel(fingers)
    fingerName = char(fingers(fingerIdx));
    motor = motorIdx.(fingerName);
    switch modeName
        case "home"
            value = 0;
        case "mid"
            value = gap.(fingerName) + ...
                0.5 * (breakLimit.(fingerName) - gap.(fingerName));
        case "closed"
            value = breakLimit.(fingerName);
        otherwise
            error("Unsupported initial mode '%s'.", modeName);
    end
    initialEncoder(motor) = value;
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
    pwmMagnitude = nonZeroLevels(idx);
    appliedPwm(motorIdx) = sign(actionValue) * pwmMagnitude;
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

function signTable = localBuildSignTable(gainTable, numMotors)
rows = cell(numMotors, 1);
for motorIdx = 1:numMotors
    motorRows = gainTable(gainTable.motor == motorIdx, :);
    positiveRows = motorRows(motorRows.level > 0, :);
    negativeRows = motorRows(motorRows.level < 0, :);
    positiveMeanDelta = mean(positiveRows.finalFlexDelta, "omitnan");
    negativeMeanDelta = mean(negativeRows.finalFlexDelta, "omitnan");
    positiveMeanRange = mean(positiveRows.responseRangeFlex, "omitnan");
    negativeMeanRange = mean(negativeRows.responseRangeFlex, "omitnan");
    rows{motorIdx} = struct( ...
        "motor", motorIdx, ...
        "positiveMeanDelta", positiveMeanDelta, ...
        "negativeMeanDelta", negativeMeanDelta, ...
        "positiveMeanRangeFlex", positiveMeanRange, ...
        "negativeMeanRangeFlex", negativeMeanRange, ...
        "positiveSign", sign(positiveMeanDelta), ...
        "negativeSign", sign(negativeMeanDelta), ...
        "positiveGainMean", mean(positiveRows.gainApprox, "omitnan"), ...
        "negativeGainMean", mean(negativeRows.gainApprox, "omitnan"));
end
signTable = struct2table(vertcat(rows{:}));
end

function localCreateGainFigure(figurePath, levels, responseRangeFlex, ...
        gainMatrix, finalFlexDelta)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 850]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");

localHeatmap(nexttile, levels, responseRangeFlex, "Response range flex");
localHeatmap(nexttile, levels, abs(gainMatrix), "Absolute gain");
localHeatmap(nexttile, levels, finalFlexDelta, "Final flex delta");

sgtitle(f, "Extended motor response sanity check");
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

function textValue = localVectorString(values)
textValue = strjoin(compose("%.9g", double(values(:))'), " ");
end
