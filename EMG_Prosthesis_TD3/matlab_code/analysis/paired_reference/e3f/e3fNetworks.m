function [actor,critic,discriminator]=e3fNetworks(cfg)
arguments
    cfg struct
end
% 1. Actor con ramas separadas EMG (40) y Mecanica (12)
lg=layerGraph();
lg=addLayers(lg,featureInputLayer(40,Normalization="none",Name="emg"));
lg=addLayers(lg,fullyConnectedLayer(cfg.hidden,Name="emg_fc1"));
lg=addLayers(lg,reluLayer(Name="emg_relu1"));
lg=addLayers(lg,fullyConnectedLayer(cfg.hidden,Name="emg_fc2"));
lg=addLayers(lg,reluLayer(Name="emg_latent"));

lg=connectLayers(lg,"emg","emg_fc1");
lg=connectLayers(lg,"emg_fc1","emg_relu1");
lg=connectLayers(lg,"emg_relu1","emg_fc2");
lg=connectLayers(lg,"emg_fc2","emg_latent");

lg=addLayers(lg,featureInputLayer(12,Normalization="none",Name="mech"));
lg=addLayers(lg,concatenationLayer(1,2,Name="concat"));
lg=connectLayers(lg,"emg_latent","concat/in1");
lg=connectLayers(lg,"mech","concat/in2");

lg=addLayers(lg,fullyConnectedLayer(cfg.hidden,Name="ctrl_fc1"));
lg=addLayers(lg,reluLayer(Name="ctrl_relu1"));
lg=connectLayers(lg,"concat","ctrl_fc1");
lg=connectLayers(lg,"ctrl_fc1","ctrl_relu1");

for m=1:4
    headName="head"+m;
    lg=addLayers(lg,fullyConnectedLayer(15,Name=headName));
    lg=connectLayers(lg,"ctrl_relu1",headName);
end
actor=dlnetwork(lg);

% 2. Critic independiente V(s) 52 -> 64 -> 64 -> 1
criticLayers=[
    featureInputLayer(52,Normalization="none",Name="state")
    fullyConnectedLayer(cfg.hidden,Name="value1")
    reluLayer(Name="valueRelu1")
    fullyConnectedLayer(cfg.hidden,Name="value2")
    reluLayer(Name="valueRelu2")
    fullyConnectedLayer(1,Name="value")
];
critic=dlnetwork(criticLayers);

% 3. Domain Discriminator con Gradient Reversal Layer
discLayers=[
    featureInputLayer(cfg.hidden,Normalization="none",Name="disc_in")
    e3fGradientReversalLayer("grl",cfg.lambdaAdv)
    fullyConnectedLayer(32,Name="disc_fc1")
    reluLayer(Name="disc_relu1")
    fullyConnectedLayer(numel(cfg.trainSubjects),Name="subject_logits")
];
discriminator=dlnetwork(discLayers);
end
