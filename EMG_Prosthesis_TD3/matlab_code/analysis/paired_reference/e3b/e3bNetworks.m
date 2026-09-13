function [actor,critic]=e3bNetworks(cfg)
trunk=[featureInputLayer(52,Normalization="none",Name="state");fullyConnectedLayer(cfg.hidden,Name="shared1"); ...
    reluLayer(Name="relu1");fullyConnectedLayer(cfg.hidden,Name="shared2");reluLayer(Name="relu2")];
g=layerGraph(trunk);
for m=1:4
    name="head"+m;g=addLayers(g,fullyConnectedLayer(15,Name=name));g=connectLayers(g,"relu2",name);
end
actor=dlnetwork(g);
critic=dlnetwork([featureInputLayer(52,Normalization="none",Name="state");fullyConnectedLayer(cfg.hidden,Name="value1"); ...
    reluLayer(Name="valueRelu1");fullyConnectedLayer(cfg.hidden,Name="value2");reluLayer(Name="valueRelu2");fullyConnectedLayer(1,Name="value")]);
end
