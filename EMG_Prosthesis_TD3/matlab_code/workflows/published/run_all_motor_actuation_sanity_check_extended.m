function results = run_all_motor_actuation_sanity_check_extended(options)
%run_all_motor_actuation_sanity_check_extended probes M1-M4 actuation.
%
% This workflow is simulation-only. It applies direct per-motor actions from
% home, mid and closed positions and compares encoder2Flex variants without
% training or hardware.

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

allRows = cell(numel(options.encoder2FlexVariant) * ...
    numel(options.modeNames) * 4 * numel(options.levels), 1);
aggregateRows = cell(numel(options.encoder2FlexVariant) * ...
    numel(options.modeNames) * 4, 1);
rowIdx = 0;
aggregateIdx = 0;

for variantIdx = 1:numel(options.encoder2FlexVariant)
    variantName = options.encoder2FlexVariant(variantIdx);
    override = struct( ...
        "run_training", false, ...
        "newTraining", false, ...
        "usePrerecorded", true, ...
        "simMotors", true, ...
        "connect_glove", false, ...
        "unifyActions", false, ...
        "quantizeCommandsForSimulation", true, ...
        "actionInterfaceVariant", "baselineQuantized", ...
        "encoder2FlexVariant", variantName, ...
        "motor2Encoder2FlexGapOffset", options.motor2Encoder2FlexGapOffset);
    setConfigurablesOverride(override);
    clear configurables
    cleanup = onCleanup(@() clearConfigurablesOverride());
    configs = configurables();

    for modeIdx = 1:numel(options.modeNames)
        modeName = options.modeNames(modeIdx);
        initialEncoder = localInitialEncoderForMode(modeName);
        initialFlexRaw = encoder2FlexVariant(initialEncoder, configs);
        initialFlex = configs.flexJoined_scale(initialFlexRaw);
        modeRows = cell(4 * numel(options.levels), 1);
        modeRowIdx = 0;

        for motorIdx = 1:4
            for levelIdx = 1:numel(options.levels)
                rawAction = options.levels(levelIdx);
                action = zeros(1, 4);
                action(motorIdx) = rawAction;
                [effectiveAction, appliedPwm] = localRemapAction(action, configs);
                encoderTrajectory = SimController.prosthesis_simulator( ...
                    initialEncoder, appliedPwm, options.duration, ...
                    options.samplingPeriod);
                encoderTrajectory = [initialEncoder; encoderTrajectory]; %#ok<AGROW>
                encoder2FlexTrajectory = encoder2FlexVariant(encoderTrajectory, configs);
                normalizedFlexTrajectory = configs.flexJoined_scale( ...
                    encoder2FlexTrajectory);

                encoderRange = localRange(encoderTrajectory(:, motorIdx));
                encoder2FlexRange = localRange(encoder2FlexTrajectory(:, motorIdx));
                normalizedFlexRange = localRange(normalizedFlexTrajectory(:, motorIdx));
                finalFlexDelta = normalizedFlexTrajectory(end, motorIdx) - ...
                    initialFlex(motorIdx);
                if rawAction == 0
                    responseGain = NaN;
                else
                    responseGain = finalFlexDelta / rawAction;
                end
                actionNoMotion = abs(effectiveAction(motorIdx)) > 0 && ...
                    normalizedFlexRange <= options.deadzoneFlexThreshold;

                rowIdx = rowIdx + 1;
                modeRowIdx = modeRowIdx + 1;
                row = struct( ...
                    "encoder2FlexVariant", variantName, ...
                    "initialMode", modeName, ...
                    "motor", motorIdx, ...
                    "rawAction", rawAction, ...
                    "effectiveAction", effectiveAction(motorIdx), ...
                    "appliedPwm", appliedPwm(motorIdx), ...
                    "encoderRange", encoderRange, ...
                    "encoder2FlexRange", encoder2FlexRange, ...
                    "normalizedFlexRange", normalizedFlexRange, ...
                    "finalFlexDelta", finalFlexDelta, ...
                    "responseGain", responseGain, ...
                    "signEstimate", sign(finalFlexDelta), ...
                    "actionNoMotion", actionNoMotion);
                allRows{rowIdx, 1} = row;
                modeRows{modeRowIdx, 1} = row;
            end
        end

        modeTable = struct2table(vertcat(modeRows{:}));
        for motorIdx = 1:4
            motorRows = modeTable(modeTable.motor == motorIdx, :);
            positiveRows = motorRows(motorRows.rawAction > 0, :);
            negativeRows = motorRows(motorRows.rawAction < 0, :);
            aggregateIdx = aggregateIdx + 1;
            aggregateRows{aggregateIdx, 1} = struct( ...
                "encoder2FlexVariant", variantName, ...
                "initialMode", modeName, ...
                "motor", motorIdx, ...
                "deadzonePositive", localDeadzoneThreshold( ...
                    positiveRows.rawAction, positiveRows.normalizedFlexRange, ...
                    options.deadzoneFlexThreshold), ...
                "deadzoneNegative", localDeadzoneThreshold( ...
                    negativeRows.rawAction, negativeRows.normalizedFlexRange, ...
                    options.deadzoneFlexThreshold), ...
                "signConsistency", localSignConsistency( ...
                    positiveRows.finalFlexDelta, negativeRows.finalFlexDelta), ...
                "actionNoMotionRatio", mean(motorRows.actionNoMotion, "omitnan"), ...
                "responseGainPositive", mean(positiveRows.responseGain, "omitnan"), ...
                "responseGainNegative", mean(negativeRows.responseGain, "omitnan"), ...
                "meanEncoderRange", mean(motorRows.encoderRange, "omitnan"), ...
                "meanEncoder2FlexRange", ...
                    mean(motorRows.encoder2FlexRange, "omitnan"), ...
                "meanNormalizedFlexRange", ...
                    mean(motorRows.normalizedFlexRange, "omitnan"));
        end
    end
    clear cleanup
    clearConfigurablesOverride();
end

sanityTable = struct2table(vertcat(allRows{:}));
byModeTable = struct2table(vertcat(aggregateRows{:}));

csvPath = fullfile(options.summaryRoot, "all_motor_actuation_sanity.csv");
byModeCsvPath = fullfile(options.summaryRoot, ...
    "all_motor_actuation_sanity_by_initial_mode.csv");
matPath = fullfile(options.summaryRoot, "all_motor_actuation_sanity_results.mat");
deadzoneFigurePath = fullfile(options.figuresRoot, "all_motor_deadzone_matrix.png");
gainFigurePath = fullfile(options.figuresRoot, "all_motor_gain_matrix.png");
motor4FigurePath = fullfile(options.figuresRoot, "motor4_actuation_detail.png");

writetable(sanityTable, csvPath);
writetable(byModeTable, byModeCsvPath);
localCreateDeadzoneFigure(byModeTable, deadzoneFigurePath);
localCreateGainFigure(byModeTable, gainFigurePath);
localCreateMotor4DetailFigure(sanityTable, motor4FigurePath);

results = struct();
results.resultsRoot = string(options.resultsRoot);
results.summaryRoot = string(options.summaryRoot);
results.figuresRoot = string(options.figuresRoot);
results.options = options;
results.sanityTable = sanityTable;
results.byInitialModeTable = byModeTable;
results.paths = struct( ...
    "sanityCsv", string(csvPath), ...
    "byModeCsv", string(byModeCsvPath), ...
    "mat", string(matPath), ...
    "deadzoneFigure", string(deadzoneFigurePath), ...
    "gainFigure", string(gainFigurePath), ...
    "motor4Figure", string(motor4FigurePath));

save(matPath, "results", "sanityTable", "byModeTable", "options");
end

function options = localNormalizeOptions(options, workspaceRoot)
defaults = struct( ...
    "levels", [-1.00 -0.75 -0.50 -0.25 0 0.25 0.50 0.75 1.00], ...
    "initialMode", "all", ...
    "encoder2FlexVariant", ["baseline", "motor2Calibrated"], ...
    "duration", 2.0, ...
    "samplingPeriod", 0.14, ...
    "deadzoneFlexThreshold", 0.03, ...
    "motor2Encoder2FlexGapOffset", -256, ...
    "resultsRoot", "");
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
options.levels = double(options.levels(:))';
options.initialMode = lower(string(options.initialMode));
options.modeNames = localResolveModeNames(options.initialMode);
if ischar(options.encoder2FlexVariant) && size(options.encoder2FlexVariant, 1) > 1
    options.encoder2FlexVariant = string(cellstr(options.encoder2FlexVariant));
else
    options.encoder2FlexVariant = string(options.encoder2FlexVariant);
end
options.duration = double(options.duration);
options.samplingPeriod = double(options.samplingPeriod);
options.deadzoneFlexThreshold = double(options.deadzoneFlexThreshold);
options.motor2Encoder2FlexGapOffset = double(options.motor2Encoder2FlexGapOffset);
if any(~ismember(options.encoder2FlexVariant, ["baseline", "motor2Calibrated"]))
    error("Unsupported encoder2FlexVariant value.");
end
if strlength(string(options.resultsRoot)) > 0
    options.resultsRoot = char(string(options.resultsRoot));
else
    options.resultsRoot = fullfile(workspaceRoot, "Agentes", ...
        "all_motor_actuation_sanity_check_extended", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
options.summaryRoot = fullfile(options.resultsRoot, "summary");
options.figuresRoot = fullfile(options.resultsRoot, "figures");
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

function value = localDeadzoneThreshold(levels, ranges, threshold)
mask = abs(levels) > 0 & ranges > threshold;
if any(mask)
    value = min(abs(levels(mask)));
else
    value = NaN;
end
end

function value = localSignConsistency(positiveDelta, negativeDelta)
positiveMean = mean(positiveDelta, "omitnan");
negativeMean = mean(negativeDelta, "omitnan");
tol = 1e-6;
value = (isnan(positiveMean) || positiveMean >= -tol) && ...
    (isnan(negativeMean) || negativeMean <= tol);
end

function localCreateDeadzoneFigure(byModeTable, figurePath)
localEnsureParent(figurePath);
[positiveMatrix, labels] = localMetricMatrix(byModeTable, "deadzonePositive");
[negativeMatrix, ~] = localMetricMatrix(byModeTable, "deadzoneNegative");
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 800]);
tiledlayout(f, 1, 2, "TileSpacing", "compact", "Padding", "compact");
localHeatmap(nexttile, positiveMatrix, labels, "Positive deadzone threshold");
localHeatmap(nexttile, negativeMatrix, labels, "Negative deadzone threshold");
sgtitle(f, "All-motor deadzone matrix");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateGainFigure(byModeTable, figurePath)
localEnsureParent(figurePath);
[positiveMatrix, labels] = localMetricMatrix(byModeTable, "responseGainPositive");
[negativeMatrix, ~] = localMetricMatrix(byModeTable, "responseGainNegative");
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1500 800]);
tiledlayout(f, 1, 2, "TileSpacing", "compact", "Padding", "compact");
localHeatmap(nexttile, positiveMatrix, labels, "Positive response gain");
localHeatmap(nexttile, negativeMatrix, labels, "Negative response gain");
sgtitle(f, "All-motor response gain matrix");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function localCreateMotor4DetailFigure(sanityTable, figurePath)
localEnsureParent(figurePath);
subset = sanityTable(sanityTable.motor == 4, :);
groups = unique(string(subset.encoder2FlexVariant) + " / " + ...
    string(subset.initialMode), "stable");
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 850]);
ax = axes(f);
hold(ax, "on");
for groupIdx = 1:numel(groups)
    parts = split(groups(groupIdx), " / ");
    rows = subset(string(subset.encoder2FlexVariant) == parts(1) & ...
        string(subset.initialMode) == parts(2), :);
    [levels, order] = sort(rows.rawAction);
    plot(ax, levels, rows.normalizedFlexRange(order), "-o", ...
        "LineWidth", 1.2, "DisplayName", groups(groupIdx));
end
grid(ax, "on");
xlabel(ax, "Raw action level");
ylabel(ax, "Normalized flex range");
title(ax, "Motor 4 actuation detail");
legend(ax, "Location", "bestoutside");
exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function [matrixValues, labels] = localMetricMatrix(tableValue, metricName)
keys = unique(string(tableValue.encoder2FlexVariant) + " / " + ...
    string(tableValue.initialMode), "stable");
matrixValues = nan(numel(keys), 4);
for keyIdx = 1:numel(keys)
    parts = split(keys(keyIdx), " / ");
    for motorIdx = 1:4
        row = tableValue(string(tableValue.encoder2FlexVariant) == parts(1) & ...
            string(tableValue.initialMode) == parts(2) & ...
            tableValue.motor == motorIdx, :);
        if ~isempty(row)
            matrixValues(keyIdx, motorIdx) = row.(metricName)(1);
        end
    end
end
labels = keys;
end

function localHeatmap(ax, matrixValues, labels, plotTitle)
imagesc(ax, matrixValues);
colorbar(ax);
grid(ax, "on");
title(ax, plotTitle);
xlabel(ax, "Motor");
ylabel(ax, "Variant / initial mode");
set(ax, "XTick", 1:4, "XTickLabel", ["M1", "M2", "M3", "M4"]);
set(ax, "YTick", 1:numel(labels), "YTickLabel", labels);
end

function localEnsureParent(filePath)
[parent, ~, ~] = fileparts(filePath);
if strlength(string(parent)) > 0 && ~exist(parent, "dir")
    mkdir(parent);
end
end
