function s=e3fSchedule(cfg,steps,completed,done,buffered)
if cfg.mode=="smoke"
    assert(completed<=cfg.smokeEpisodes);
    stop=completed==cfg.smokeEpisodes;
    checkpoint=done && ismember(completed,cfg.smokeCheckpointEpisodes);
else
    assert(steps<=cfg.maxAgentSteps,"E3F:Budget","Se excedio el presupuesto exacto.");
    stop=steps==cfg.maxAgentSteps;
    checkpoint=ismember(steps,cfg.checkpointSteps);
end
s=struct("stop",stop,"checkpoint",checkpoint,"update",buffered==cfg.rolloutLength || checkpoint || stop,"terminal",done);
end
