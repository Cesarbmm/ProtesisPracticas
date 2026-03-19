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
actionLog = this.actionLog(1:this.c,:);
actionSatLog = this.actionSatLog(1:this.c,:);
actionPwmLog = this.actionPwmLog(1:this.c,:);
encoderLog = this.encoderLog(1:this.c);
encoderAdjustedLog = this.encoderAdjustedLog(1:this.c);
emgLog = this.emgLog(1:this.c);
repetitionId = this.repetitionId;
flexConvertedLog = this.flexConvertedLog(1:this.c);
episodeTimestamp = this.episodeTimestamp;

save(sprintf('%s\\episode%05d.mat',this.episode_folder,this.episodeCounter) ...
    ,"rewardLog","rewardVectorLog","trackingMseLog","trackingMaeLog", ...
    "actionL2Log","progressTermLog","smoothnessPenaltyLog", ...
    "deltaActionL2Log","saturationFractionLog", ...
    "actionLog", "actionSatLog", "actionPwmLog", ...
    "encoderLog", ...
    "flexConvertedLog", "repetitionId", "episodeTimestamp", ...
    'encoderAdjustedLog', 'emgLog');
