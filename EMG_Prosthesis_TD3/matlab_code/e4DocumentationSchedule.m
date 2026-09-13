function s = e4DocumentationSchedule(cfg, steps, completedEpisodes, done, bufferCount)
% Guardar no modifica PPO: update/stop siguen exactamente e4Schedule.
s = e4Schedule(cfg, steps, completedEpisodes, done, bufferCount);
s.checkpoint = ismember(steps, cfg.checkpointSteps);
end
