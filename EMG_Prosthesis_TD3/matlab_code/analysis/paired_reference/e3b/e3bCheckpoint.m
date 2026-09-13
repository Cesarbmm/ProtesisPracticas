function file=e3bCheckpoint(out,actor,critic,opt,cfg,o,steps,episode,done,env,rollout)
file=fullfile(out,"checkpoints",compose("CategoricalStep%09d.mat",steps));
assert(~isfile(file),"E3B:CheckpointExists","No sobrescribir checkpoint.");
saved_actor=E3BCategoricalActor(actor);saved_critic=critic;optimizer=opt;rngState=rng; %#ok<NASGU>
h=env.Historical;
environmentSnapshot=struct("state",h.State,"q",h.motorData(end,:),"episodeCounter",h.episodeCounter, ...
    "repetitionId",h.repetitionId,"episodes_shuffled",h.episodes_shuffled,"episodeType",string(h.episodeType),"c",h.c); %#ok<NASGU>
checkpointInfo=struct("agentSteps",steps,"episode",episode,"episodeComplete",done,"algorithm",cfg.algorithm, ...
    "agentCheckpointAvailable",true,"fullTrainingResumeAvailable",false,"rolloutUpdatedBeforeSave",true); %#ok<NASGU>
temporary=file+".writing.mat";
save(temporary,"saved_actor","saved_critic","optimizer","cfg","o","rngState","environmentSnapshot","checkpointInfo","rollout","-v7.3");
assert(~isfile(file));[ok,msg]=movefile(temporary,file);assert(ok,"E3B:CheckpointWrite","%s",msg);
e2cWriteJSON(file+".json",checkpointInfo);fprintf("Checkpoint categórico: %d pasos, episodio%d.\n",steps,episode);
end
