function [agent, name] = agentTd3(observationInfo, actionInfo)
%createAgentTD3 Configura y devuelve un agente TD3.
%
% Ejemplo:
% [agent, name] = createAgentTD3(observationInfo, actionInfo);
%
%{
Laboratorio de Inteligencia y VisiÃ³n Artificial
ESCUELA POLITÃ‰CNICA NACIONAL
Quito - Ecuador
Adaptado a TD3 - Fecha actual
%}
name = 'td3_agent';
td3 = configurables('td3');
hL = @reluLayer;
numHiddenUnits = td3.numHiddenUnits;

% --- Red crÃ­tica 1 ---
statePath1 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs1")
    hL("Name", "relu_obs1")
];

actionPath1 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act1")
    hL("Name", "relu_act1")
];

commonPath1 = [
    concatenationLayer(1,2, "Name", "concat1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_common1")
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

% --- Red crÃ­tica 2 ---
statePath2 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs2")
    hL("Name", "relu_obs2")
];

actionPath2 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act2")
    hL("Name", "relu_act2")
];

commonPath2 = [
    concatenationLayer(1,2, "Name", "concat2")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_common2")
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

%% Red de polÃ­tica (actor)
actorNetwork = [
    featureInputLayer(observationInfo.Dimension(1), 'Name', 'observation')
    fullyConnectedLayer(numHiddenUnits, 'Name', 'fc1')
    hL('Name', 'relu1')
    fullyConnectedLayer(numHiddenUnits, 'Name', 'fc2')
    hL('Name', 'relu2')
    fullyConnectedLayer(actionInfo.Dimension(1), 'Name', 'action')
    tanhLayer('Name', 'scaledAction')
];

actor = rlContinuousDeterministicActor(actorNetwork, observationInfo, actionInfo);

%% Opciones del agente TD3
agentOptions = rlTD3AgentOptions(...
    'TargetSmoothFactor', td3.targetSmoothFactor, ...
    'ExperienceBufferLength', td3.experienceBufferLength, ...
    'MiniBatchSize', td3.miniBatchSize, ...
    'SampleTime', td3.sampleTime, ...
    'DiscountFactor', td3.discountFactor, ...
    'PolicyUpdateFrequency', td3.policyUpdateFrequency, ...
    'TargetUpdateFrequency', td3.targetUpdateFrequency);

actorOptimizerOptions = rlOptimizerOptions(...
    'LearnRate', td3.actorLearnRate, ...
    'GradientThreshold', td3.gradientThreshold, ...
    'L2RegularizationFactor', td3.actorL2Regularization);
criticOptimizerOptions = [...
    rlOptimizerOptions(...
        'LearnRate', td3.criticLearnRate, ...
        'GradientThreshold', td3.gradientThreshold, ...
        'L2RegularizationFactor', td3.criticL2Regularization), ...
    rlOptimizerOptions(...
        'LearnRate', td3.criticLearnRate, ...
        'GradientThreshold', td3.gradientThreshold, ...
        'L2RegularizationFactor', td3.criticL2Regularization)];
agentOptions.ActorOptimizerOptions = actorOptimizerOptions;
agentOptions.CriticOptimizerOptions = criticOptimizerOptions;

explorationModel = rl.option.GaussianActionNoise;
explorationModel.StandardDeviation = td3.explorationStd;
explorationModel.StandardDeviationDecayRate = td3.explorationStdDecayRate;
explorationModel.StandardDeviationMin = td3.explorationStdMin;
agentOptions.ExplorationModel = explorationModel;

targetPolicyModel = rl.option.GaussianActionNoise;
targetPolicyModel.StandardDeviation = td3.targetPolicyStd;
targetPolicyModel.StandardDeviationDecayRate = 0;
targetPolicyModel.StandardDeviationMin = td3.targetPolicyStd;
targetPolicyModel.LowerLimit = -td3.targetPolicyNoiseClip;
targetPolicyModel.UpperLimit = td3.targetPolicyNoiseClip;
agentOptions.TargetPolicySmoothModel = targetPolicyModel;

%% Crear el agente TD3
agent = rlTD3Agent(actor, [critic1 critic2], agentOptions);
agent.AgentOptions.ActorOptimizerOptions = actorOptimizerOptions;
agent.AgentOptions.CriticOptimizerOptions = criticOptimizerOptions;
agent.AgentOptions.ExplorationModel = explorationModel;
agent.AgentOptions.TargetPolicySmoothModel = targetPolicyModel;
end
