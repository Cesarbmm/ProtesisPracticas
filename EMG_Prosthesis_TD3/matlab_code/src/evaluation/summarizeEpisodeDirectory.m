function summary = summarizeEpisodeDirectory(episodeDir)
%summarizeEpisodeDirectory aggregates episode-level metrics saved to disk.

arguments
    episodeDir (1, 1) string
end

episodeFiles = dir(fullfile(episodeDir, "episode*.mat"));
if isempty(episodeFiles)
    error("No episode files found in %s", episodeDir);
end

numEpisodes = numel(episodeFiles);
numMotors = 4;

episodeReward = nan(numEpisodes, 1);
trackingMseMean = nan(numEpisodes, 1);
trackingMaeMean = nan(numEpisodes, 1);
velocityMseMean = nan(numEpisodes, 1);
actionL2Mean = nan(numEpisodes, 1);
absPwmMean = nan(numEpisodes, 1);
saturationFractionMean = nan(numEpisodes, 1);
deltaActionL2Mean = nan(numEpisodes, 1);
saturationPenaltyMean = nan(numEpisodes, 1);
softSaturationPenaltyMean = nan(numEpisodes, 1);
thresholdNullFractionMean = nan(numEpisodes, 1);
rawEffectiveActionErrorMean = nan(numEpisodes, 1);
rawToWarpedActionErrorMean = nan(numEpisodes, 1);
rawDeadzoneToFirstLevelFractionMean = nan(numEpisodes, 1);
saturationRunLengthMean = nan(numEpisodes, 1);
saturationRunLengthMax = nan(numEpisodes, 1);
signFlipFractionMean = nan(numEpisodes, 1);
residualActionL2Mean = nan(numEpisodes, 1);
residualFractionNearCapMean = nan(numEpisodes, 1);
baseToFinalActionDeltaMean = nan(numEpisodes, 1);
signOverrideFractionMean = nan(numEpisodes, 1);
stepsPerEpisode = nan(numEpisodes, 1);
referenceSources = strings(numEpisodes, 1);

trackingMseByMotor = nan(numEpisodes, numMotors);
trackingMaeByMotor = nan(numEpisodes, numMotors);
meanAbsActionByMotor = nan(numEpisodes, numMotors);
saturationFractionByMotor = nan(numEpisodes, numMotors);
deltaActionL2ByMotor = nan(numEpisodes, numMotors);
signFlipFractionByMotor = nan(numEpisodes, numMotors);
residualByMotorMean = nan(numEpisodes, numMotors);

pwmLevels = [];
pwmLevelFractions = [];
pwmLevelFractionsByMotor = [];
warpedActionLevels = [];
warpedActionLevelFractions = [];
warpedActionLevelFractionsByMotor = [];
effectiveActionLevels = [];
effectiveActionLevelFractions = [];
effectiveActionLevelFractionsByMotor = [];

for i = 1:numEpisodes
    episodeFile = fullfile(episodeFiles(i).folder, episodeFiles(i).name);
    data = loadEpisodeData(episodeFile);
    referenceSources(i) = getEpisodeReferenceSource(data, episodeFile);
    validateEpisodeReferenceSchema(data, referenceSources(i), episodeFile);

    validSteps = ~isnan(data.rewardLog);
    stepsPerEpisode(i) = sum(validSteps);
    episodeReward(i) = sum(data.rewardLog(validSteps), "omitnan");
    trackingMseMean(i) = mean(data.trackingMseLog(~isnan(data.trackingMseLog)), ...
        "omitnan");
    trackingMaeMean(i) = mean(data.trackingMaeLog(~isnan(data.trackingMaeLog)), ...
        "omitnan");
    if isfield(data, "velocityMseLog") && ~isempty(data.velocityMseLog)
        velocityMseMean(i) = mean(data.velocityMseLog( ...
            ~isnan(data.velocityMseLog)), "omitnan");
    end
    actionL2Mean(i) = mean(data.actionL2Log(~isnan(data.actionL2Log)), ...
        "omitnan");

    validPwm = ~isnan(data.actionPwmLog);
    absPwmMean(i) = mean(abs(data.actionPwmLog(validPwm)), "omitnan");

    validSat = ~isnan(data.actionSatLog);
    saturationFractionMean(i) = mean(abs(data.actionSatLog(validSat)) >= 0.95, ...
        "omitnan");

    actionSat = data.actionSatLog;
    validRows = all(~isnan(actionSat), 2);
    actionSat = actionSat(validRows, :);
    if size(actionSat, 1) >= 2
        delta = diff(actionSat, 1, 1);
        deltaActionL2Mean(i) = mean(sum(delta.^2, 2), "omitnan");
    else
        deltaActionL2Mean(i) = 0;
    end

    if isfield(data, "saturationPenaltyLog") && ~isempty(data.saturationPenaltyLog)
        saturationPenaltyMean(i) = mean(data.saturationPenaltyLog(~isnan(data.saturationPenaltyLog)), ...
            "omitnan");
    else
        saturationPenaltyMean(i) = 0;
    end
    if isfield(data, "softSaturationPenaltyLog") && ...
            ~isempty(data.softSaturationPenaltyLog)
        softSaturationPenaltyMean(i) = mean( ...
            data.softSaturationPenaltyLog( ...
            ~isnan(data.softSaturationPenaltyLog)), "omitnan");
    else
        % Old episodes predate this raw diagnostic. The reward did not use
        % the new soft term, so zero is the compatibility-neutral value.
        softSaturationPenaltyMean(i) = 0;
    end

    if isfield(data, "episodeDiagnostics")
        diagnostics = data.episodeDiagnostics;
    else
        [targetLog, predictionLog] = resolveTrackingLogs(data);
        diagnostics = computeEpisodeActionDiagnostics( ...
            data.actionLog, data.actionSatLog, data.actionPwmLog, ...
            targetLog, predictionLog, ...
            configurables("actionCommandActivationThreshold"), ...
            configurables("actionCommandLevels"), ...
            true, true, data.actionWarpLog, ...
            configurables("actionWarpOutputLevels"), ...
            configurables("actionWarpDeadzone"));
    end

    thresholdNullFractionMean(i) = getDiagnosticField(diagnostics, "thresholdNullFraction", NaN);
    rawEffectiveActionErrorMean(i) = getDiagnosticField(diagnostics, "meanRawEffectiveActionError", NaN);
    rawToWarpedActionErrorMean(i) = getDiagnosticField(diagnostics, "rawToWarpedActionErrorMean", NaN);
    rawDeadzoneToFirstLevelFractionMean(i) = getDiagnosticField(diagnostics, "rawDeadzoneToFirstLevelFraction", NaN);
    saturationRunLengthMean(i) = getDiagnosticField(diagnostics, "saturationRunMean", NaN);
    saturationRunLengthMax(i) = getDiagnosticField(diagnostics, "saturationRunMax", NaN);
    signFlipFractionMean(i) = getDiagnosticField(diagnostics, "signFlipFractionMean", NaN);
    residualActionL2Mean(i) = getDiagnosticField(diagnostics, "residualActionL2Mean", NaN);
    residualFractionNearCapMean(i) = getDiagnosticField(diagnostics, "residualFractionNearCap", NaN);
    baseToFinalActionDeltaMean(i) = getDiagnosticField(diagnostics, "baseToFinalActionDeltaMean", NaN);
    signOverrideFractionMean(i) = getDiagnosticField(diagnostics, "signOverrideFraction", NaN);

    trackingMseByMotor(i, :) = getVectorDiagnosticField(diagnostics, "trackingMseByMotor", numMotors);
    trackingMaeByMotor(i, :) = getVectorDiagnosticField(diagnostics, "trackingMaeByMotor", numMotors);
    meanAbsActionByMotor(i, :) = getVectorDiagnosticField(diagnostics, "meanAbsActionByMotor", numMotors);
    saturationFractionByMotor(i, :) = getVectorDiagnosticField(diagnostics, "saturationFractionByMotor", numMotors);
    deltaActionL2ByMotor(i, :) = getVectorDiagnosticField(diagnostics, "deltaActionL2ByMotor", numMotors);
    signFlipFractionByMotor(i, :) = getVectorDiagnosticField(diagnostics, "signFlipFractionByMotor", numMotors);
    residualByMotorMean(i, :) = getVectorDiagnosticField(diagnostics, "residualByMotorMean", numMotors);

    [pwmLevels, pwmLevelFractions, pwmLevelFractionsByMotor] = ...
        assignLevelDiagnostics(diagnostics, i, ...
        "pwmLevels", "pwmLevelFractions", "pwmLevelFractionsByMotor", ...
        numEpisodes, numMotors, pwmLevels, pwmLevelFractions, pwmLevelFractionsByMotor);

    [warpedActionLevels, warpedActionLevelFractions, warpedActionLevelFractionsByMotor] = ...
        assignLevelDiagnostics(diagnostics, i, ...
        "warpedActionLevels", "warpedActionLevelFractions", "warpedActionLevelFractionsByMotor", ...
        numEpisodes, numMotors, warpedActionLevels, warpedActionLevelFractions, warpedActionLevelFractionsByMotor);

    [effectiveActionLevels, effectiveActionLevelFractions, effectiveActionLevelFractionsByMotor] = ...
        assignLevelDiagnostics(diagnostics, i, ...
        "effectiveActionLevels", "effectiveActionLevelFractions", "effectiveActionLevelFractionsByMotor", ...
        numEpisodes, numMotors, effectiveActionLevels, effectiveActionLevelFractions, effectiveActionLevelFractionsByMotor);
end

uniqueReferenceSources = unique(referenceSources);
if numel(uniqueReferenceSources) ~= 1
    error("summarizeEpisodeDirectory:MixedReferenceSources", ...
        "Episode directory mixes non-comparable reference sources: %s", ...
        strjoin(uniqueReferenceSources, ", "));
end
referenceSource = uniqueReferenceSources(1);

summary = struct( ...
    "numEpisodes", numEpisodes, ...
    "referenceSource", referenceSource, ...
    "episodeRewardMean", mean(episodeReward, "omitnan"), ...
    "episodeRewardStd", std(episodeReward, 0, "omitnan"), ...
    "trackingMseMean", mean(trackingMseMean, "omitnan"), ...
    "trackingMseStd", std(trackingMseMean, 0, "omitnan"), ...
    "trackingMaeMean", mean(trackingMaeMean, "omitnan"), ...
    "trackingMaeStd", std(trackingMaeMean, 0, "omitnan"), ...
    "velocityMseMean", mean(velocityMseMean, "omitnan"), ...
    "velocityMseStd", std(velocityMseMean, 0, "omitnan"), ...
    "actionL2Mean", mean(actionL2Mean, "omitnan"), ...
    "actionL2Std", std(actionL2Mean, 0, "omitnan"), ...
    "absPwmMean", mean(absPwmMean, "omitnan"), ...
    "absPwmStd", std(absPwmMean, 0, "omitnan"), ...
    "saturationFractionMean", mean(saturationFractionMean, "omitnan"), ...
    "saturationFractionStd", std(saturationFractionMean, 0, "omitnan"), ...
    "deltaActionL2Mean", mean(deltaActionL2Mean, "omitnan"), ...
    "deltaActionL2Std", std(deltaActionL2Mean, 0, "omitnan"), ...
    "saturationPenaltyMean", mean(saturationPenaltyMean, "omitnan"), ...
    "saturationPenaltyStd", std(saturationPenaltyMean, 0, "omitnan"), ...
    "softSaturationPenaltyMean", ...
        mean(softSaturationPenaltyMean, "omitnan"), ...
    "softSaturationPenaltyStd", ...
        std(softSaturationPenaltyMean, 0, "omitnan"), ...
    "thresholdNullFractionMean", mean(thresholdNullFractionMean, "omitnan"), ...
    "thresholdNullFractionStd", std(thresholdNullFractionMean, 0, "omitnan"), ...
    "rawEffectiveActionErrorMean", mean(rawEffectiveActionErrorMean, "omitnan"), ...
    "rawEffectiveActionErrorStd", std(rawEffectiveActionErrorMean, 0, "omitnan"), ...
    "rawToWarpedActionErrorMean", mean(rawToWarpedActionErrorMean, "omitnan"), ...
    "rawToWarpedActionErrorStd", std(rawToWarpedActionErrorMean, 0, "omitnan"), ...
    "rawDeadzoneToFirstLevelFractionMean", mean(rawDeadzoneToFirstLevelFractionMean, "omitnan"), ...
    "rawDeadzoneToFirstLevelFractionStd", std(rawDeadzoneToFirstLevelFractionMean, 0, "omitnan"), ...
    "saturationRunLengthMean", mean(saturationRunLengthMean, "omitnan"), ...
    "saturationRunLengthStd", std(saturationRunLengthMean, 0, "omitnan"), ...
    "saturationRunLengthMaxMean", mean(saturationRunLengthMax, "omitnan"), ...
    "saturationRunLengthMaxStd", std(saturationRunLengthMax, 0, "omitnan"), ...
    "signFlipFractionMean", mean(signFlipFractionMean, "omitnan"), ...
    "signFlipFractionStd", std(signFlipFractionMean, 0, "omitnan"), ...
    "residualActionL2Mean", mean(residualActionL2Mean, "omitnan"), ...
    "residualActionL2Std", std(residualActionL2Mean, 0, "omitnan"), ...
    "residualFractionNearCapMean", mean(residualFractionNearCapMean, "omitnan"), ...
    "residualFractionNearCapStd", std(residualFractionNearCapMean, 0, "omitnan"), ...
    "baseToFinalActionDeltaMean", mean(baseToFinalActionDeltaMean, "omitnan"), ...
    "baseToFinalActionDeltaStd", std(baseToFinalActionDeltaMean, 0, "omitnan"), ...
    "signOverrideFractionMean", mean(signOverrideFractionMean, "omitnan"), ...
    "signOverrideFractionStd", std(signOverrideFractionMean, 0, "omitnan"), ...
    "stepsPerEpisodeMean", mean(stepsPerEpisode, "omitnan"), ...
    "stepsPerEpisodeStd", std(stepsPerEpisode, 0, "omitnan"));

summary = appendMotorSummary(summary, "trackingMseMotor", trackingMseByMotor);
summary = appendMotorSummary(summary, "trackingMaeMotor", trackingMaeByMotor);
summary = appendMotorSummary(summary, "meanAbsActionMotor", meanAbsActionByMotor);
summary = appendMotorSummary(summary, "saturationFractionMotor", saturationFractionByMotor);
summary = appendMotorSummary(summary, "deltaActionL2Motor", deltaActionL2ByMotor);
summary = appendMotorSummary(summary, "signFlipFractionMotor", signFlipFractionByMotor);
summary = appendMotorSummary(summary, "residualActionMotor", residualByMotorMean);

if ~isempty(pwmLevels)
    summary.pwmLevels = pwmLevels;
    summary.pwmLevelFractionMean = mean(pwmLevelFractions, 1, "omitnan");
    summary.pwmLevelFractionByMotorMean = squeeze(mean(pwmLevelFractionsByMotor, 1, "omitnan"));
end

if ~isempty(warpedActionLevels)
    summary.warpedActionLevels = warpedActionLevels;
    summary.warpedActionLevelFractionMean = mean(warpedActionLevelFractions, 1, "omitnan");
    summary.warpedActionLevelFractionByMotorMean = squeeze(mean(warpedActionLevelFractionsByMotor, 1, "omitnan"));
end

if ~isempty(effectiveActionLevels)
    summary.effectiveActionLevels = effectiveActionLevels;
    summary.effectiveActionLevelFractionMean = mean(effectiveActionLevelFractions, 1, "omitnan");
    summary.effectiveActionLevelFractionByMotorMean = squeeze(mean(effectiveActionLevelFractionsByMotor, 1, "omitnan"));
end
end

function value = getDiagnosticField(diagnostics, fieldName, defaultValue)
if isfield(diagnostics, fieldName)
    value = diagnostics.(fieldName);
else
    value = defaultValue;
end
end

function values = getVectorDiagnosticField(diagnostics, fieldName, width)
if isfield(diagnostics, fieldName) && numel(diagnostics.(fieldName)) == width
    values = reshape(double(diagnostics.(fieldName)), 1, width);
else
    values = nan(1, width);
end
end

function summary = appendMotorSummary(summary, prefix, valuesByEpisode)
numMotors = size(valuesByEpisode, 2);
for motorIdx = 1:numMotors
    fieldName = sprintf("%s%dMean", prefix, motorIdx);
    summary.(fieldName) = mean(valuesByEpisode(:, motorIdx), "omitnan");
end
end

function [levels, fractions, fractionsByMotor] = assignLevelDiagnostics( ...
    diagnostics, episodeIdx, levelField, fractionField, fractionByMotorField, ...
    numEpisodes, numMotors, levels, fractions, fractionsByMotor)
if isempty(levels) && isfield(diagnostics, levelField) && ~isempty(diagnostics.(levelField))
    levels = diagnostics.(levelField);
    fractions = nan(numEpisodes, numel(levels));
    fractionsByMotor = nan(numEpisodes, numMotors, numel(levels));
end

if isempty(levels)
    return;
end

if isfield(diagnostics, fractionField) && ...
        numel(diagnostics.(fractionField)) == numel(levels)
    fractions(episodeIdx, :) = reshape(double(diagnostics.(fractionField)), 1, []);
end

if isfield(diagnostics, fractionByMotorField)
    current = double(diagnostics.(fractionByMotorField));
    if isequal(size(current), [numMotors, numel(levels)])
        fractionsByMotor(episodeIdx, :, :) = current;
    end
end
end

function data = loadEpisodeData(episodeFile)
requestedVars = [ ...
    "rewardLog", "trackingMseLog", "trackingMaeLog", ...
    "velocityMseLog", "actionL2Log", ...
    "actionPwmLog", "actionSatLog", "actionLog", "actionWarpLog", ...
    "rawActionLog", "warpedActionLog", "effectiveActionLog", "appliedPwmLog", ...
    "saturationPenaltyLog", "softSaturationPenaltyLog", ...
    "episodeDiagnostics", ...
    "flexConvertedLog", "encoderAdjustedLog", ...
    "referenceSource", "referenceHistory", "referenceHistoryCount", ...
    "trackingPredictionHistory", "rewardInfoLog", ...
    "rewardInfoSchemaVersion" ...
    ];

availableVars = string(who('-file', episodeFile));
varsToLoad = intersect(requestedVars, availableVars, "stable");
data = load(episodeFile, varsToLoad{:});

if ~isfield(data, "actionLog") && isfield(data, "rawActionLog")
    data.actionLog = data.rawActionLog;
end
if ~isfield(data, "actionWarpLog") && isfield(data, "warpedActionLog")
    data.actionWarpLog = data.warpedActionLog;
end
if ~isfield(data, "actionSatLog") && isfield(data, "effectiveActionLog")
    data.actionSatLog = data.effectiveActionLog;
end
if ~isfield(data, "actionPwmLog") && isfield(data, "appliedPwmLog")
    data.actionPwmLog = data.appliedPwmLog;
end
if ~isfield(data, "actionWarpLog")
    data.actionWarpLog = [];
end
end

function [targetLog, predictionLog] = resolveTrackingLogs(data)
if isfield(data, "referenceSource") && ...
        string(data.referenceSource) == "emgIntent"
    if ~isfield(data, "referenceHistory") || ...
            ~isfield(data, "trackingPredictionHistory")
        error("summarizeEpisodeDirectory:IncompleteEmgIntentSchema", ...
            "EMG-intent episode is missing neutral tracking histories.");
    end
    targetLog = data.referenceHistory;
    predictionLog = data.trackingPredictionHistory;
    return;
end

if isfield(data, "flexConvertedLog")
    targetLog = data.flexConvertedLog;
else
    targetLog = [];
end
if isfield(data, "encoderAdjustedLog")
    predictionLog = data.encoderAdjustedLog;
else
    predictionLog = [];
end
end

function validateEpisodeReferenceSchema(data, referenceSource, episodeFile)
if isfield(data, "rewardInfoLog")
    if ~iscell(data.rewardInfoLog)
        error("summarizeEpisodeDirectory:InvalidRewardInfoLog", ...
            "Episode %s has a non-cell rewardInfoLog.", episodeFile);
    end
    for i = 1:numel(data.rewardInfoLog)
        info = data.rewardInfoLog{i};
        if isempty(info)
            continue;
        end
        if ~isstruct(info) || ~isscalar(info) || ...
                ~isfield(info, "referenceSource")
            error("summarizeEpisodeDirectory:InvalidRewardInfoLog", ...
                "Episode %s has malformed rewardInfoLog entries.", episodeFile);
        end
        infoSource = string(info.referenceSource);
        if ~isscalar(infoSource) || infoSource ~= referenceSource
            error("summarizeEpisodeDirectory:InconsistentReferenceSource", ...
                "Episode %s metadata and rewardInfoLog disagree.", episodeFile);
        end
    end
end

if referenceSource ~= "emgIntent"
    return;
end

requiredFields = { ...
    'referenceHistory', ...
    'referenceHistoryCount', ...
    'trackingPredictionHistory', ...
    'rewardInfoLog', ...
    'rewardInfoSchemaVersion'};
if ~all(isfield(data, requiredFields))
    error("summarizeEpisodeDirectory:IncompleteEmgIntentSchema", ...
        "EMG-intent episode %s is missing required schema fields.", episodeFile);
end

historyCount = data.referenceHistoryCount;
validCount = isnumeric(historyCount) && isreal(historyCount) && ...
    isscalar(historyCount) && isfinite(historyCount) && ...
    historyCount >= 1 && fix(historyCount) == historyCount;
validHistories = false;
validRewardInfo = false;
if validCount
    validHistories = isnumeric(data.referenceHistory) && ...
        isreal(data.referenceHistory) && ...
        isequal(size(data.referenceHistory), [historyCount, 4]) && ...
        all(isfinite(data.referenceHistory), "all") && ...
        isnumeric(data.trackingPredictionHistory) && ...
        isreal(data.trackingPredictionHistory) && ...
        isequal(size(data.trackingPredictionHistory), [historyCount, 4]) && ...
        all(isfinite(data.trackingPredictionHistory), "all");
    validRewardInfo = iscell(data.rewardInfoLog) && ...
        numel(data.rewardInfoLog) == historyCount && ...
        all(~cellfun(@isempty, data.rewardInfoLog));
end
validSchemaVersion = isnumeric(data.rewardInfoSchemaVersion) && ...
    isscalar(data.rewardInfoSchemaVersion) && ...
    data.rewardInfoSchemaVersion == 1;
if ~validCount || ~validHistories || ~validRewardInfo || ~validSchemaVersion
    error("summarizeEpisodeDirectory:InvalidEmgIntentSchema", ...
        "EMG-intent episode %s has inconsistent history/schema dimensions.", ...
        episodeFile);
end
end

function referenceSource = getEpisodeReferenceSource(data, episodeFile)
if isfield(data, "referenceSource")
    referenceSource = string(data.referenceSource);
else
    % Files written before ETAPA 1 always used the glove reference.
    referenceSource = "glove";
end
if ~isscalar(referenceSource) || ...
        ~any(referenceSource == ["glove", "emgIntent"])
    error("summarizeEpisodeDirectory:InvalidReferenceSource", ...
        "Episode %s has an invalid referenceSource.", episodeFile);
end
end
