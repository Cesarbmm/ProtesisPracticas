function cfg=e3bConfig(mode)
arguments,mode (1,1) string {mustBeMember(mode,["long","smoke"])}="long";end
cfg=e3axConfig(mode);cfg.algorithm="FACTORIZED_MULTICATEGORICAL_PPO";cfg.actionRepresentation="4x15_categorical";
cfg.categories=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
cfg.seed=20260910;cfg.maxAgentSteps=1000000;cfg.checkpointSteps=[50000 100000 250000 500000 750000 1000000];
cfg.smokeEpisodes=6;cfg.smokeCheckpointEpisodes=[3 6];cfg.hidden=64;cfg.gamma=.99;cfg.gaeLambda=.95;
cfg.rolloutLength=1024;cfg.epochs=4;cfg.minibatch=64;cfg.clip=.2;cfg.entropyWeight=.01;
cfg.actorLR=3e-4;cfg.criticLR=1e-3;cfg.adamBeta1=.9;cfg.adamBeta2=.999;cfg.adamEpsilon=1e-8;cfg.gradientLimit=.5;
cfg.advantageNormalization=true;cfg.observationNormalization="HISTORICAL_ONLY";cfg.rewardNormalization=false;
cfg.maxCategoryFraction=.90;cfg.strongMSE=.051598;cfg.learningMSE=.059980845;
cfg.outputParent=fullfile(cfg.root,"results","e3b_"+mode);cfg.selection="MIN_VALIDATION_MSE_THEN_REWARD_THEN_STEPS";
cfg.plots="custom-training-progress-monitor";cfg.monitorType="trainingProgressMonitor";
cfg=rmfield(cfg,["maxEpisodes","checkpoints","evaluationFrequency"]);cfg.fullTrainingResumeAvailable=false;
if mode=="smoke",cfg.seed=20260911;end
end
