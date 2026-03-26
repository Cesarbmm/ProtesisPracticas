function saveEpisode(this)
%saveEpisode() saves the tracking vars per episode
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org
Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
Ahora solo lo sabe dios.

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

05 January 2022

%}

%% skipping some episodes
if mod(this.episodeCounter, this.episode_save_freq) ~= 0
    return
end

%%
%saving episode
rewardLog = this.rewardLog(1:this.c);
rewardVectorLog = this.rewardVectorLog(1:this.c,:);
trackingMseLog = this.trackingMseLog(1:this.c);
trackingMaeLog = this.trackingMaeLog(1:this.c);
actionL2Log = this.actionL2Log(1:this.c);
progressTermLog = this.progressTermLog(1:this.c);
smoothnessPenaltyLog = this.smoothnessPenaltyLog(1:this.c);
deltaActionL2Log = this.deltaActionL2Log(1:this.c);
saturationFractionLog = this.saturationFractionLog(1:this.c);
saturationPenaltyLog = this.saturationPenaltyLog(1:this.c);
actionLog = this.actionLog(1:this.c,:);
actionWarpLog = this.actionWarpLog(1:this.c,:);
actionSatLog = this.actionSatLog(1:this.c,:);
actionPwmLog = this.actionPwmLog(1:this.c,:);
rawActionLog = actionLog;
warpedActionLog = actionWarpLog;
effectiveActionLog = actionSatLog;
appliedPwmLog = actionPwmLog;
encoderLog = this.encoderLog(1:this.c);
encoderAdjustedLog = this.encoderAdjustedLog(1:this.c);
stateLog = this.stateLog(1:this.c, :);
emgLog = this.emgLog(1:this.c);
repetitionId = this.repetitionId;
flexConvertedLog = this.flexConvertedLog(1:this.c);
episodeTimestamp = this.episodeTimestamp;
episodeDiagnostics = computeEpisodeActionDiagnostics( ...
    actionLog, actionSatLog, actionPwmLog, ...
    flexConvertedLog, encoderAdjustedLog, ...
    this.actionCommandActivationThreshold, this.actionCommandLevels, ...
    this.enableDetailedActionDiagnostics, this.savePerMotorMetrics, ...
    actionWarpLog, configurables("actionWarpOutputLevels"), ...
    configurables("actionWarpDeadzone"));

baseActionLog = [];
residualActionLog = [];
td3Residual = configurables("td3Residual");
if isstruct(td3Residual) && isfield(td3Residual, "enabled") && td3Residual.enabled && ...
        (~isfield(td3Residual, "logDiagnostics") || td3Residual.logDiagnostics)
    residualDiagnostics = reconstructResidualPolicyDiagnostics( ...
        stateLog, actionLog, td3Residual);
    episodeDiagnostics = mergeStructs(episodeDiagnostics, residualDiagnostics);
    if isfield(residualDiagnostics, "baseActionLog")
        baseActionLog = residualDiagnostics.baseActionLog;
    end
    if isfield(residualDiagnostics, "residualActionLog")
        residualActionLog = residualDiagnostics.residualActionLog;
    end
end

save(sprintf('%s\\episode%05d.mat',this.episode_folder,this.episodeCounter) ...
    ,"rewardLog","rewardVectorLog","trackingMseLog","trackingMaeLog", ...
    "actionL2Log","progressTermLog","smoothnessPenaltyLog", ...
    "deltaActionL2Log","saturationFractionLog","saturationPenaltyLog", ...
    "actionLog", "actionWarpLog", "actionSatLog", "actionPwmLog", ...
    "rawActionLog", "warpedActionLog", "effectiveActionLog", "appliedPwmLog", ...
    "encoderLog", "stateLog", ...
    "flexConvertedLog", "repetitionId", "episodeTimestamp", ...
    'encoderAdjustedLog', 'emgLog', 'episodeDiagnostics', ...
    'baseActionLog', 'residualActionLog');
end

function merged = mergeStructs(baseStruct, patchStruct)
merged = baseStruct;
patchFields = fieldnames(patchStruct);
for i = 1:numel(patchFields)
    merged.(patchFields{i}) = patchStruct.(patchFields{i});
end
end
