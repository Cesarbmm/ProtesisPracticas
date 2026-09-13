function file=e3fCheckpoint(out,actor,critic,disc,opt,cfg,o,steps,episode,done,env,rollout)
file=fullfile(out,"checkpoints",compose("CategoricalStep%09d.mat",steps));
assert(~isfile(file),"E3F:CheckpointExists","No sobrescribir checkpoint.");
saved_actor=E3FActor(actor);saved_critic=critic;saved_discriminator=disc;optimizer=opt;rngState=rng; %#ok<NASGU>
h=env.Historical;
environmentSnapshot=struct("state",h.State,"q",h.motorData(end,:),"episodeCounter",h.episodeCounter, ...
    "repetitionId",h.repetitionId,"episodes_shuffled",h.episodes_shuffled,"episodeType",string(h.episodeType),"c",h.c); %#ok<NASGU>
checkpointInfo=struct("agentSteps",steps,"episode",episode,"episodeComplete",done,"algorithm",cfg.algorithm, ...
    "agentCheckpointAvailable",true,"fullTrainingResumeAvailable",false,"rolloutUpdatedBeforeSave",true); %#ok<NASGU>
temporary=file+".writing.mat";
save(temporary,"saved_actor","saved_critic","saved_discriminator","optimizer","cfg","o","rngState","environmentSnapshot","checkpointInfo","rollout","-v7.3");
assert(~isfile(file));[ok,msg]=movefile(temporary,file);assert(ok,"E3F:CheckpointWrite","%s",msg);
e2cWriteJSON(file+".json",checkpointInfo);fprintf("Checkpoint invariante E3F: %d pasos, episodio %d.\n",steps,episode);
end
