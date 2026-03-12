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
actionLog = this.actionLog(1:this.c,:);
actionSatLog = this.actionSatLog(1:this.c,:);
encoderLog = this.encoderLog(1:this.c);
encoderAdjustedLog = this.encoderAdjustedLog(1:this.c);
emgLog = this.emgLog(1:this.c);
repetitionId = this.repetitionId;
flexConvertedLog = this.flexConvertedLog(1:this.c);
episodeTimestamp = this.episodeTimestamp;

save(sprintf('%s\\episode%05d.mat',this.episode_folder,this.episodeCounter) ...
    ,"rewardLog","actionLog", "actionSatLog", "encoderLog", ...
    "flexConvertedLog", "repetitionId", "episodeTimestamp", ...
    'encoderAdjustedLog', 'emgLog');
