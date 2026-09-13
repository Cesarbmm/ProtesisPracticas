function s = e4Schedule(cfg, steps, completedEpisodes, episodeDone, bufferCount)
% e4Schedule gestiona los disparadores de actualizacion, checkpoint y parada para E4.

arguments
    cfg (1, 1) struct
    steps (1, 1) double
    completedEpisodes (1, 1) double
    episodeDone (1, 1) logical
    bufferCount (1, 1) double
end

if cfg.mode == "smoke"
    stop = (completedEpisodes >= cfg.smokeEpisodes);
    checkpoint = ismember(completedEpisodes, cfg.smokeCheckpointEpisodes) && episodeDone;
    update = (bufferCount >= cfg.rolloutLength) || (episodeDone && bufferCount >= cfg.minibatch) || stop;
else
    stop = (steps >= cfg.maxAgentSteps);
    checkpoint = any(steps >= cfg.checkpointSteps & (steps - bufferCount) < cfg.checkpointSteps);
    update = (bufferCount >= cfg.rolloutLength) || stop;
end

s = struct("update", update, "checkpoint", checkpoint, "stop", stop);
end
