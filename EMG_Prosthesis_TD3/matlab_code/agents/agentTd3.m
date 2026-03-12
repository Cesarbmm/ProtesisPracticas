function [agent, name] = agentTd3(observationInfo, actionInfo)
%createAgentTD3 Configura y devuelve un agente TD3.
%
% Ejemplo:
% [agent, name] = createAgentTD3(observationInfo, actionInfo);
%
%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador
Adaptado a TD3 - Fecha actual
%}
name = 'td3_agent';
hL = @reluLayer;
numHiddenUnits = 64; % probar 128

% --- Red crítica 1 ---
statePath1 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs1")
    fullyConnectedLayer(64, "Name", "fc_obs1")
    hL("Name", "relu_obs1")
];

actionPath1 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act1")
    fullyConnectedLayer(64, "Name", "fc_act1")
    hL("Name", "relu_act1")
];

commonPath1 = [
    concatenationLayer(1,2, "Name", "concat1")
    fullyConnectedLayer(64, "Name", "fc_common1")
    hL("Name", "relu_common1")
    fullyConnectedLayer(1, "Name", "q1")
];

criticNet1 = layerGraph(statePath1);
criticNet1 = addLayers(criticNet1, actionPath1);
criticNet1 = addLayers(criticNet1, commonPath1);
criticNet1 = connectLayers(criticNet1, "relu_obs1", "concat1/in1");
criticNet1 = connectLayers(criticNet1, "relu_act1", "concat1/in2");

critic1 = rlQValueRepresentation(criticNet1, observationInfo, actionInfo, ...
    'Observation', {'obs1'}, 'Action', {'act1'});

% --- Red crítica 2 (idéntica estructura) ---
statePath2 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs2")
    fullyConnectedLayer(64, "Name", "fc_obs2")
    hL("Name", "relu_obs2")
];

actionPath2 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act2")
    fullyConnectedLayer(64, "Name", "fc_act2")
    hL("Name", "relu_act2")
];

commonPath2 = [
    concatenationLayer(1,2, "Name", "concat2")
    fullyConnectedLayer(64, "Name", "fc_common2")
    hL("Name", "relu_common2")
    fullyConnectedLayer(1, "Name", "q2")
];

criticNet2 = layerGraph(statePath2);
criticNet2 = addLayers(criticNet2, actionPath2);
criticNet2 = addLayers(criticNet2, commonPath2);
criticNet2 = connectLayers(criticNet2, "relu_obs2", "concat2/in1");
criticNet2 = connectLayers(criticNet2, "relu_act2", "concat2/in2");

critic2 = rlQValueRepresentation(criticNet2, observationInfo, actionInfo, ...
    'Observation', {'obs2'}, 'Action', {'act2'});

%% Red de política (actor)
actorNetwork = [
 featureInputLayer(observationInfo.Dimension(1), 'Name', 'observation')
 fullyConnectedLayer(numHiddenUnits, 'Name', 'fc1')
 hL('Name', 'relu1')
 fullyConnectedLayer(numHiddenUnits, 'Name', 'fc2')
 hL('Name', 'relu2')
 fullyConnectedLayer(actionInfo.Dimension(1), 'Name', 'action')
 tanhLayer('Name', 'scaledAction')
];

% Crear representación del actor
actor = rlContinuousDeterministicActor(actorNetwork, observationInfo, actionInfo);

%% Opciones del agente TD3
agentOptions = rlTD3AgentOptions(...
'TargetSmoothFactor', 5e-3, ...
'ExperienceBufferLength', 1e6, ...
'MiniBatchSize', 256, ...
'SampleTime', 0.2, ... %revisar que concuerde con el params.period 
'CriticOptimizerOptions', rlOptimizerOptions('LearnRate', 1e-3, 'GradientThreshold', 1), ...
'ActorOptimizerOptions', rlOptimizerOptions('LearnRate', 1e-4, 'GradientThreshold', 1), ...
'DiscountFactor', 0.95, ...     
'TargetUpdateFrequency', 2);

agentOptions.ExplorationModel = rl.option.GaussianActionNoise;
agentOptions.ExplorationModel.StandardDeviation = 0.4;
agentOptions.ExplorationModel.StandardDeviationDecayRate = 1e-5;
agentOptions.ExplorationModel.StandardDeviationMin = 0.01;


%% Crear el agente TD3
agent = rlTD3Agent(actor, [critic1 critic2], agentOptions);
end