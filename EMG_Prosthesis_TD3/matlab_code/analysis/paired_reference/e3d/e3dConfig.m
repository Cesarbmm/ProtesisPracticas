function cfg=e3dConfig
cfg=e3cConfig;cfg.stage="E3D";cfg.seeds=[20260923 20260924 20260925];
cfg.output=fullfile(cfg.root,"analysis","paired_reference","e3d_results");
cfg.lossWeights=[1 1 1];cfg.models=["BASELINE","TEMPORAL_EMG"];
end
