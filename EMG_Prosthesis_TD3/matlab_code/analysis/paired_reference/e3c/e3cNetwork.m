function net=e3cNetwork(kind)
if kind=="FF"
    layers=[featureInputLayer(52,Normalization="none",Name="input");fullyConnectedLayer(64,Name="shared1");reluLayer(Name="relu1"); ...
        fullyConnectedLayer(64,Name="shared2");reluLayer(Name="latent")];
elseif kind=="GRU"
    layers=[sequenceInputLayer(52,Normalization="none",Name="input");gruLayer(64,OutputMode="last",Name="memory"); ...
        fullyConnectedLayer(64,Name="shared");reluLayer(Name="latent")];
else,error("E3C:Kind","Familia no preregistrada.");end
g=layerGraph(layers);for m=1:4,name="head"+m;g=addLayers(g,fullyConnectedLayer(15,Name=name));g=connectLayers(g,"latent",name);end
net=dlnetwork(g);
end
