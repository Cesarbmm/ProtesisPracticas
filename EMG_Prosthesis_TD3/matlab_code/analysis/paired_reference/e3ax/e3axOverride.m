function o=e3axOverride(cfg)
p=configurables();o=buildMarkov52BaselineOverride(p);
o.run_training=true;o.newTraining=true;o.flagSaveTraining=false;o.plotEpisodeOnTest=false;o.verbose=false;
o.dataset=cellstr(cfg.trainSubjects);o.randomSeed=cfg.seed;o.trainingMaxEpisodes=cfg.maxEpisodes;o.trainingPlots="training-progress";
o.simPlantSource="patternCurveCanonical";o.actionInterfaceVariant="baselineQuantized";o.unifyActions=false;
o.actionCommandLevels=[0 64 96 128 160 192 224 255];o.actionCommandActivationThreshold=.05;o.speeds=255*ones(1,4);o.period=.2;
o.maxNumberStepsInEpisodes=50;o.rewardType='trackingMseActionRateReward';o.rewardActionWeight=.01;o.rewardDeltaActionWeight=.05;
o.td3.useRecurrent=false;o.td3Residual.enabled=false;o.usePrerecorded=true;o.simMotors=true;o.connect_glove=false;
end
