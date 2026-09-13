function cfg=e3cConfig
cfg=e3bConfig("long");cfg.stage="E3C";cfg.seeds=[20260912 20260913 20260914];cfg.L=8;
cfg.supervisedEpochs=40;cfg.supervisedLR=.001;cfg.supervisedBatch=64;cfg.supervisedGradientLimit=1;
cfg.phaseEpochs=40;cfg.bootstrapSeed=20260922;cfg.bootstrapReplicates=5000;
cfg.output=fullfile(cfg.root,"analysis","paired_reference","e3c_results");
cfg.e3bRun=fullfile(cfg.root,"results","e3b_long","run_20260909_002700_470_a733a786");
end
