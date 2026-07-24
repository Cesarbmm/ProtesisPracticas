function results = run_motor2_conversion_fix_diagnostic(options)
%run_motor2_conversion_fix_diagnostic compares encoder2Flex variants.
%
% This workflow is simulation-only and does not train agents. It compares
% baseline conversion against the experimental motor2Calibrated conversion
% across all motors, command levels and initial positions.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));

options = localNormalizeOptions(options, workspaceRoot);
ensureDirectoryExists(options.resultsRoot);
ensureDirectoryExists(options.summaryRoot);
ensureDirectoryExists(options.figuresRoot);

override = struct( ...
    "run_training", false, ...
    "newTraining", false, ...
    "usePrerecorded", true, ...
    "simMotors", true, ...
    "connect_glove", false, ...
    "unifyActions", false, ...
    "quantizeCommandsForSimulation", true, ...
    "actionInterfaceVariant", "baselineQuantized", ...
    "encoder2FlexVariant", "baseline", ...
    "motor2Encoder2FlexGapOffset", options.motor2Encoder2FlexGapOffset, ...
    "motor2Encoder2FlexBreakOffset", options.motor2Encoder2FlexBreakOffset, ...
    "motor2Encoder2FlexMinEffectiveEncoder", ...
        options.motor2Encoder2FlexMinEffectiveEncoder);
setConfigurablesOverride(override);
clear configurables
cleanup = onCleanup(@() clearConfigurablesOverride());
baseConfigs = configurables();

allRows = {};
allTrajectories = {};
rowIdx = 0;
trajectoryIdx = 0;

for variantIdx = 1:numel(options.encoder2FlexVariant)
    variantName = options.encoder2FlexVariant(variantIdx);
    configs = baseConfigs;
    configs.encoder2FlexVariant = variantName;
    configs.motor2Encoder2FlexGapOffset = options.motor2Encoder2FlexGapOffset;
    configs.motor2Encoder2FlexBreakOffset = options.motor2Encoder2FlexBreakOffset;
    configs.motor2Encoder2FlexMinEffectiveEncoder = ...
        options.motor2Encoder2FlexMinEffectiveEncoder;

    for modeIdx = 1:numel(options.modeNames)
        modeName = options.modeNames(modeIdx);
        initialEncoder = localInitialEncoderForMode(modeName);
        [modeRows, trajectoryRows] = localRunVariantMode( ...
            configs, variantName, modeName, initialEncoder, ...
            options.levels, options.duration, options.samplingPeriod, ...
            options);
        for i = 1:numel(modeRows)
            rowIdx = rowIdx + 1;
            allRows{rowIdx, 1} = modeRows{i}; %#ok<AGROW>
        end
        for i = 1:numel(trajectoryRows)
            trajectoryIdx = trajectoryIdx + 1;
            allTrajectories{trajectoryIdx, 1} = trajectoryRows{i}; %#ok<AGROW>
        end
    end
end

beforeAfterTable = struct2table(vertcat(allRows{:}));
baselineRows = beforeAfterTable(beforeAfterTable.encoder2FlexVariant == "baseline", :);
calibratedRows = beforeAfterTable(beforeAfterTable.encoder2FlexVariant == ...
    "motor2Calibrated", :);
regression = compareAllMotorRegression(baselineRows, calibratedRows, struct( ...
    "rangeThreshold", options.normalizedFlatThreshold, ...
    "regressionTolerance", 0.10));

csvPath = fullfile(options.summaryRoot, "motor_conversion_before_after.csv");
txtPath = fullfile(options.summaryRoot, "motor_conversion_before_after.txt");
matPath = fullfile(options.summaryRoot, "motor_conversion_fix_results.mat");
regressionCsvPath = fullfile(options.summaryRoot, ...
    "all_motor_regression_summary.csv");
matrixFigurePath = fullfile(options.figuresRoot, ...
    "motor_conversion_before_after_matrix.png");
deadzoneFigurePath = fullfile(options.figuresRoot, ...
    "motor2_deadzone_before_after.png");
regressionFigurePath = fullfile(options.figuresRoot, ...
    "all_motors_regression_check.png");

writetable(beforeAfterTable, csvPath);
writetable(regression.perMotorTable, regressionCsvPath);
localWriteTextFile(txtPath, localBuildSummaryText( ...
    options, regression, beforeAfterTable));
localCreateBeforeAfterMatrixFigure(beforeAfterTable, options.levels, ...
    matrixFigurePath);
localCreateMotor2DeadzoneFigure(beforeAfterTable, deadzoneFigurePath);
localCreateRegressionFigure(regression.perMotorTable, regression.summaryTable, ...
    regressionFigurePath);

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.options = options;
results.beforeAfterTable = beforeAfterTable;
results.trajectoryRows = vertcat(allTrajectories{:});
results.regression = regression;
results.csvPath = string(csvPath);
results.txtPath = string(txtPath);
results.matPath = string(matPath);
results.figurePaths = struct( ...
    "beforeAfterMatrix", string(matrixFigurePath), ...
    "motor2Deadzone", string(deadzoneFigurePath), ...
    "allMotorRegression", string(regressionFigurePath));

save(matPath, "results", "beforeAfterTable", "allTrajectories", ...
    "regression", "options");
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "encoder2FlexVariant", ["baseline", "motor2Calibrated"], ...
    "initialMode", "all", ...
    "levels", [-1.00 -0.75 -0.50 -0.25 0 0.25 0.50 0.75 1.00], ...
    "duration", 2.0, ...
    "samplingPeriod", 0.14, ...
    "encoderFlatThreshold", 1.0, ...
    "encoder2FlexFlatThreshold", 1e-6, ...
    "normalizedFlatThreshold", 1e-4, ...
    "motor2Encoder2FlexGapOffset", -64, ...
    "motor2Encoder2FlexBreakOffset", 0, ...
    "motor2Encoder2FlexMinEffectiveEncoder", 0, ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.encoder2FlexVariant = string(options.encoder2FlexVariant);
validVariants = ["baseline", "motor2Calibrated"];
if any(~ismember(options.encoder2FlexVariant, validVariants))
    error("Unsupported encoder2FlexVariant.");
end
if ~ismember("baseline", options.encoder2FlexVariant) || ...
        ~ismember("motor2Calibrated", options.encoder2FlexVariant)
    error("Diagnostic requires baseline and motor2Calibrated variants.");
end

options.initialMode = lower(string(options.initialMode));
options.modeNames = localResolveModeNames(options.initialMode);
options.levels = double(options.levels(:))';
options.duration = double(options.duration);
options.samplingPeriod = double(options.samplingPeriod);
options.encoderFlatThreshold = double(options.encoderFlatThreshold);
options.encoder2FlexFlatThreshold = double(options.encoder2FlexFlatThreshold);
options.normalizedFlatThreshold = double(options.normalizedFlatThreshold);
options.motor2Encoder2FlexGapOffset = double(options.motor2Encoder2FlexGapOffset);
options.motor2Encoder2FlexBreakOffset = double(options.motor2Encoder2FlexBreakOffset);
options.motor2Encoder2FlexMinEffectiveEncoder = ...
    double(options.motor2Encoder2FlexMinEffectiveEncoder);

if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = char(string(options.resultsRoot));
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "motor2_conversion_fix_diagnostic", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
end

function [rows, trajectoryRows] = localRunVariantMode(configs, variantName, ...
        modeName, initialEncoder, levels, duration, samplingPeriod, options)
numMotors = 4;
numLevels = numel(levels);
rows = cell(numMotors * numLevels, 1);
trajectoryRows = cell(numMotors * numLevels, 1);
initialFlexRaw = encoder2FlexVariant(initialEncoder, configs);
initialFlexNorm = configs.flexJoined_scale(initialFlexRaw);
rowIdx = 0;

for motorIdx = 1:numMotors
    for levelIdx = 1:numLevels
        action = zeros(1, numMotors);
        action(motorIdx) = levels(levelIdx);
        [effectiveAction, appliedPwm] = localRemapAction(action, configs);
        encoderTrajectory = SimController.prosthesis_simulator( ...
            initialEncoder, appliedPwm, duration, samplingPeriod);
        encoderTrajectory = [initialEncoder; encoderTrajectory]; %#ok<AGROW>
        encoder2FlexTrajectory = encoder2FlexVariant(encoderTrajectory, configs);
        normalizedFlexTrajectory = configs.flexJoined_scale( ...
            encoder2FlexTrajectory);

        encoderRange = localRange(encoderTrajectory(:, motorIdx));
        encoder2FlexRange = localRange(encoder2FlexTrajectory(:, motorIdx));
        normalizedFlexRange = localRange(normalizedFlexTrajectory(:, motorIdx));
        finalFlexDelta = normalizedFlexTrajectory(end, motorIdx) - ...
            initialFlexNorm(motorIdx);
        stage = localClassifyFlattening(encoderRange, encoder2FlexRange, ...
            normalizedFlexRange, options);

        rowIdx = rowIdx + 1;
        rows{rowIdx} = struct( ...
            "encoder2FlexVariant", variantName, ...
            "initialMode", modeName, ...
            "motor", motorIdx, ...
            "rawAction", levels(levelIdx), ...
            "effectiveAction", effectiveAction(motorIdx), ...
            "appliedPwm", appliedPwm(motorIdx), ...
            "encoderRange", encoderRange, ...
            "encoder2FlexRange", encoder2FlexRange, ...
            "normalizedFlexRange", normalizedFlexRange, ...
            "finalFlexDelta", finalFlexDelta, ...
            "signConsistency", sign(finalFlexDelta), ...
            "flattenStage", stage, ...
            "initialEncoder", localVectorString(initialEncoder), ...
            "encoderTrajectory", localVectorString( ...
                encoderTrajectory(:, motorIdx)), ...
            "encoder2FlexTrajectory", localVectorString( ...
                encoder2FlexTrajectory(:, motorIdx)), ...
            "normalizedFlexTrajectory", localVectorString( ...
                normalizedFlexTrajectory(:, motorIdx)));
        trajectoryRows{rowIdx} = struct( ...
            "encoder2FlexVariant", variantName, ...
            "initialMode", modeName, ...
            "motor", motorIdx, ...
            "rawAction", levels(levelIdx), ...
            "appliedPwm", appliedPwm(motorIdx), ...
            "encoderTrajectory", encoderTrajectory, ...
            "encoder2FlexTrajectory", encoder2FlexTrajectory, ...
            "normalizedFlexTrajectory", normalizedFlexTrajectory);
    end
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
if any(~isfinite([encoderRange, encoder2FlexRange, normalizedFlexRange]))
    stage = "unknown";
elseif encoderRange <= options.encoderFlatThreshold
    stage = "encoder_flat";
elseif encoder2FlexRange <= options.encoder2FlexFlatThreshold
    stage = "encoder2Flex_flat";
elseif normalizedFlexRange <= options.normalizedFlatThreshold
    stage = "flexJoined_scale_flat";
else
    stage = "responsive";
end
end

function textValue = localVectorString(values)
textValue = strjoin(compose("%.9g", double(values(:))'), " ");
end

function localCreateBeforeAfterMatrixFigure(tableValue, levels, figurePath)
localEnsureFigureDir(figurePath);
variants = ["baseline", "motor2Calibrated"];
metricNames = ["encoderRange", "encoder2FlexRange", "normalizedFlexRange"];
titles = ["Encoder range", "encoder2Flex range", "Normalized flex range"];

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 900]);
tiledlayout(f, numel(metricNames), numel(variants), ...
    "TileSpacing", "compact", "Padding", "compact");
for metricIdx = 1:numel(metricNames)
    for variantIdx = 1:numel(variants)
        ax = nexttile;
        matrixValue = localMeanMatrix(tableValue, variants(variantIdx), ...
            metricNames(metricIdx), levels);
        imagesc(ax, levels, 1:4, matrixValue);
        colorbar(ax);
        grid(ax, "on");
        title(ax, titles(metricIdx) + " - " + variants(variantIdx));
        xlabel(ax, "Raw action level");
        ylabel(ax, "Motor");
        set(ax, "YTick", 1:4, "YTickLabel", ["M1", "M2", "M3", "M4"]);
    end
end
sgtitle(f, "Motor conversion before/after matrix");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateMotor2DeadzoneFigure(tableValue, figurePath)
localEnsureFigureDir(figurePath);
variants = ["baseline", "motor2Calibrated"];
modes = unique(string(tableValue.initialMode), "stable");

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
tiledlayout(f, 1, numel(modes), "TileSpacing", "compact", "Padding", "compact");
for modeIdx = 1:numel(modes)
    ax = nexttile;
    hold(ax, "on");
    for variantIdx = 1:numel(variants)
        subset = tableValue(tableValue.motor == 2 & ...
            tableValue.encoder2FlexVariant == variants(variantIdx) & ...
            string(tableValue.initialMode) == modes(modeIdx), :);
        plot(ax, subset.rawAction, subset.normalizedFlexRange, "-o", ...
            "LineWidth", 1.2);
    end
    hold(ax, "off");
    grid(ax, "on");
    title(ax, "Motor 2 - " + modes(modeIdx));
    xlabel(ax, "Raw action level");
    ylabel(ax, "Normalized flex range");
    legend(ax, variants, "Location", "best");
end
sgtitle(f, "Motor 2 deadzone before/after");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateRegressionFigure(perMotorTable, summaryTable, figurePath)
localEnsureFigureDir(figurePath);
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 800]);
tiledlayout(f, 1, 3, "TileSpacing", "compact", "Padding", "compact");

bar(nexttile, categorical("M" + string(perMotorTable.motor)), ...
    [perMotorTable.normalizedFlexRangeBefore, ...
    perMotorTable.normalizedFlexRangeAfter]);
title("Mean normalized flex range");
legend(["baseline", "motor2Calibrated"], "Location", "best");
grid on;

bar(nexttile, categorical("M" + string(perMotorTable.motor)), ...
    perMotorTable.percentChange);
title("Percent change");
ylabel("%");
grid on;

flags = [summaryTable.motor1_regression, ...
    summaryTable.motor3_regression, summaryTable.motor4_regression, ...
    summaryTable.motor2_improved, summaryTable.sign_error_detected, ...
    summaryTable.calibration_accepted];
bar(nexttile, categorical(["M1 reg", "M3 reg", "M4 reg", ...
    "M2 improved", "Sign error", "Accepted"]), double(flags));
ylim([0 1.2]);
title("Regression flags");
grid on;

sgtitle(f, "All motors regression check");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function matrixValue = localMeanMatrix(tableValue, variantName, metricName, levels)
matrixValue = nan(4, numel(levels));
for motorIdx = 1:4
    for levelIdx = 1:numel(levels)
        idx = tableValue.encoder2FlexVariant == variantName & ...
            tableValue.motor == motorIdx & ...
            abs(tableValue.rawAction - levels(levelIdx)) < 1e-12;
        if any(idx)
            matrixValue(motorIdx, levelIdx) = mean( ...
                tableValue.(metricName)(idx), "omitnan");
        end
    end
end
end

function text = localBuildSummaryText(options, regression, tableValue)
motor2Base = tableValue(tableValue.encoder2FlexVariant == "baseline" & ...
    tableValue.motor == 2, :);
motor2Cal = tableValue(tableValue.encoder2FlexVariant == "motor2Calibrated" & ...
    tableValue.motor == 2, :);
lines = strings(0, 1);
lines(end+1) = "Motor 2 conversion fix diagnostic";
lines(end+1) = "Results root: " + string(options.resultsRoot);
lines(end+1) = "Variants: " + strjoin(options.encoder2FlexVariant, ", ");
lines(end+1) = "Initial modes: " + strjoin(options.modeNames, ", ");
lines(end+1) = "Motor 2 gap offset: " + ...
    string(options.motor2Encoder2FlexGapOffset);
lines(end+1) = "";
lines(end+1) = sprintf("Motor2 normalizedFlexRange baseline mean: %.6f", ...
    mean(motor2Base.normalizedFlexRange, "omitnan"));
lines(end+1) = sprintf("Motor2 normalizedFlexRange calibrated mean: %.6f", ...
    mean(motor2Cal.normalizedFlexRange, "omitnan"));
lines(end+1) = sprintf("Calibration accepted: %d", ...
    regression.summary.calibration_accepted);
lines(end+1) = sprintf("Motor2 improved: %d", ...
    regression.summary.motor2_improved);
lines(end+1) = sprintf("Sign error detected: %d", ...
    regression.summary.sign_error_detected);
lines(end+1) = sprintf("M1/M3/M4 regression: %d / %d / %d", ...
    regression.summary.motor1_regression, ...
    regression.summary.motor3_regression, ...
    regression.summary.motor4_regression);
text = strjoin(lines, newline);
end

function localEnsureFigureDir(figurePath)
[figureDir, ~, ~] = fileparts(figurePath);
if strlength(string(figureDir)) > 0 && ~exist(figureDir, "dir")
    mkdir(figureDir);
end
end

function localWriteTextFile(filePath, text)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not write %s", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", text);
end
