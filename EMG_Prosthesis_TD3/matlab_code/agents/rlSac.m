function [agent, name] = rlSac(observationInfo, actionInfo)

name = "sac_agent";

obsDim = observationInfo.Dimension(1);
actDim = actionInfo.Dimension(1);
numHiddenUnits = 64; % Basado en tu configuración de TD3

%% ============================
%            ACTOR
% ============================
% Se adapta la profundidad y unidades a la del TD3 (2 capas ocultas de 64)
actorLG = layerGraph();

actorLG = addLayers(actorLG, featureInputLayer(obsDim, "Name", "state"));

body = [
    fullyConnectedLayer(numHiddenUnits, "Name", "fc1")
    reluLayer("Name", "relu1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc2")
    reluLayer("Name", "relu2")
    % La salida va a una activación para procesar la distribución
    tanhLayer("Name", "actor_tanh") 
];
actorLG = addLayers(actorLG, body);
actorLG = connectLayers(actorLG, "state", "fc1");

% Rama de la Media (Mean)
meanLayer = fullyConnectedLayer(actDim, "Name", "actor_mean");
actorLG = addLayers(actorLG, meanLayer);
actorLG = connectLayers(actorLG, "actor_tanh", "actor_mean");

% Rama de la Desviación Estándar (STD)
stdLayers = [
    fullyConnectedLayer(actDim, "Name", "actor_std_fc")
    softplusLayer("Name", "actor_std")
];
actorLG = addLayers(actorLG, stdLayers);
actorLG = connectLayers(actorLG, "actor_tanh", "actor_std_fc");

actor = rlContinuousGaussianActor( ...
    actorLG, observationInfo, actionInfo, ...
    "ObservationInputNames", "state", ...
    "ActionMeanOutputNames", "actor_mean", ...
    "ActionStandardDeviationOutputNames", "actor_std");

%% ============================
%          CRITIC 1
% ============================
% Estructura exacta de tu TD3 (Capa obs -> 64, Capa act -> 64, Concat -> 64)
statePath1 = [
    featureInputLayer(obsDim, "Name", "obs1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs1")
    reluLayer("Name", "relu_obs1")
];

actionPath1 = [
    featureInputLayer(actDim, "Name", "act1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act1")
    reluLayer("Name", "relu_act1")
];

common1 = [
    concatenationLayer(1, 2, "Name", "concat1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_common1")
    reluLayer("Name", "relu_common1")
    fullyConnectedLayer(1, "Name", "q1")
];

criticLG1 = layerGraph(statePath1);
criticLG1 = addLayers(criticLG1, actionPath1);
criticLG1 = addLayers(criticLG1, common1);

criticLG1 = connectLayers(criticLG1, "relu_obs1", "concat1/in1");
criticLG1 = connectLayers(criticLG1, "relu_act1", "concat1/in2");

critic1 = rlQValueFunction(criticLG1, observationInfo, actionInfo, ...
    "Observation", "obs1", "Action", "act1");

%% ============================
%          CRITIC 2
% ============================
statePath2 = [
    featureInputLayer(obsDim, "Name", "obs2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs2")
    reluLayer("Name", "relu_obs2")
];

actionPath2 = [
    featureInputLayer(actDim, "Name", "act2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act2")
    reluLayer("Name", "relu_act2")
];

common2 = [
    concatenationLayer(1, 2, "Name", "concat2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_common2")
    reluLayer("Name", "relu_common2")
    fullyConnectedLayer(1, "Name", "q2")
];

criticLG2 = layerGraph(statePath2);
criticLG2 = addLayers(criticLG2, actionPath2);
criticLG2 = addLayers(criticLG2, common2);

criticLG2 = connectLayers(criticLG2, "relu_obs2", "concat2/in1");
criticLG2 = connectLayers(criticLG2, "relu_act2", "concat2/in2");

critic2 = rlQValueFunction(criticLG2, observationInfo, actionInfo, ...
    "Observation", "obs2", "Action", "act2");

%% ============================
%          SAC OPTIONS
% ============================
% Sincronizado con tus hiperparámetros de TD3
agentOpts = rlSACAgentOptions( ...
    "SampleTime", 0.2, ...
    "DiscountFactor", 0.95, ...           % Actualizado a 0.95 como tu TD3
    "MiniBatchSize", 256, ...             % Actualizado a 256 como tu TD3
    "ExperienceBufferLength", 1e6, ...
    "TargetSmoothFactor", 5e-3, ...       % Actualizado a 5e-3 como tu TD3
    "TargetUpdateFrequency", 1, ...
    "CriticOptimizerOptions", rlOptimizerOptions( ...
         "LearnRate", 1e-3, ...           % Actualizado a 1e-3 como tu TD3
         "GradientThreshold", 1), ...
    "ActorOptimizerOptions", rlOptimizerOptions( ...
         "LearnRate", 1e-4, ...           % Mantenido 1e-4
         "GradientThreshold", 1) ...
     );

agent = rlSACAgent(actor, [critic1 critic2], agentOpts);

end