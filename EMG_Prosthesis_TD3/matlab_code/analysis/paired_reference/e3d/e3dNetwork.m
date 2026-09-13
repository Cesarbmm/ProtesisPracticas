function net=e3dNetwork(kind)
if kind=="BASELINE"
    layers=[featureInputLayer(40,Normalization="none",Name="emg");fullyConnectedLayer(64,Name="emg_fc");reluLayer(Name="emg_context")];
elseif kind=="TEMPORAL_EMG"
    layers=[sequenceInputLayer(40,Normalization="none",Name="emg");gruLayer(64,OutputMode="last",Name="emg_context")];
else,error("E3D:Kind","Modelo fuera de preregistro.");end
g=layerGraph(layers);g=addLayers(g,featureInputLayer(12,Normalization="none",Name="mechanical_current"));
g=addLayers(g,[concatenationLayer(1,2,Name="concat");fullyConnectedLayer(64,Name="shared");reluLayer(Name="latent")]);
g=connectLayers(g,"emg_context","concat/in1");g=connectLayers(g,"mechanical_current","concat/in2");
for m=1:4,name="head"+m;g=addLayers(g,fullyConnectedLayer(15,Name=name));g=connectLayers(g,"latent",name);end
g=addLayers(g,fullyConnectedLayer(2,Name="direction"));g=connectLayers(g,"latent","direction");
g=addLayers(g,fullyConnectedLayer(6,Name="phase_direction"));g=connectLayers(g,"latent","phase_direction");net=dlnetwork(g);
end
