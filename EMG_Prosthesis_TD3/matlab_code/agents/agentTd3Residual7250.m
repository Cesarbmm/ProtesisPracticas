function agent = agentTd3Residual7250(observationInfo, actionInfo)
%agentTd3Residual7250 builds a residual TD3 agent on top of Agent7250.
%
% The base actor branch is copied from Agent7250 and frozen. A small
% learnable residual branch receives [obs; a_base] and outputs a bounded
% correction. This preserves the benchmark policy exactly at initialization
% while allowing TD3 to learn local corrections.

configs = configurables();
td3 = configs.td3;
td3Residual = configs.td3Residual;

if strlength(string(td3Residual.baseCheckpointPath)) == 0
    td3Residual.baseCheckpointPath = getAgent7250CheckpointPath();
end

baseAgent = loadSavedAgent(string(td3Residual.baseCheckpointPath));
baseActor = getActor(baseAgent);
baseCritics = getCritic(baseAgent);

actor = buildResidualActor(baseActor, observationInfo, actionInfo, td3Residual);
agentOptions = buildResidualAgentOptions(baseAgent, td3);

agent = rlTD3Agent(actor, baseCritics, agentOptions);

% Reassign mutable options after construction to keep toolbox behavior
% deterministic across resume/new-agent flows.
agent.AgentOptions.ActorOptimizerOptions = agentOptions.ActorOptimizerOptions;
agent.AgentOptions.CriticOptimizerOptions = agentOptions.CriticOptimizerOptions;
agent.AgentOptions.ExplorationModel = agentOptions.ExplorationModel;
agent.AgentOptions.TargetPolicySmoothModel = agentOptions.TargetPolicySmoothModel;
if isprop(agent.AgentOptions, "SequenceLength") && isprop(agentOptions, "SequenceLength")
    agent.AgentOptions.SequenceLength = agentOptions.SequenceLength;
end
if isprop(agent.AgentOptions, "NumStepsToLookAhead") && isprop(agentOptions, "NumStepsToLookAhead")
    agent.AgentOptions.NumStepsToLookAhead = agentOptions.NumStepsToLookAhead;
end
if isprop(agent.AgentOptions, "ResetExperienceBufferBeforeTraining") && ...
        isprop(agentOptions, "ResetExperienceBufferBeforeTraining")
    agent.AgentOptions.ResetExperienceBufferBeforeTraining = ...
        agentOptions.ResetExperienceBufferBeforeTraining;
end
end

function actor = buildResidualActor(baseActor, observationInfo, actionInfo, td3Residual)
baseModel = getModel(baseActor);
if ~isa(baseModel, "dlnetwork")
    error("Expected Agent7250 actor model to be a dlnetwork, got %s.", class(baseModel));
end

baseLayers = baseModel.Layers;
obsDim = observationInfo.Dimension(1);
actDim = actionInfo.Dimension(1);
hiddenUnits = td3Residual.hiddenUnits;
residualScale = td3Residual.residualScale;

baseFc1Source = findLayerByName(baseLayers, "fc1");
baseFc2Source = findLayerByName(baseLayers, "fc2");
baseActionSource = findLayerByName(baseLayers, "action");

observationLayer = featureInputLayer(obsDim, ...
    "Name", "observation", "Normalization", "none");

baseFc1 = fullyConnectedLayer(size(baseFc1Source.Weights, 1), "Name", "base_fc1");
baseFc1.Weights = baseFc1Source.Weights;
baseFc1.Bias = baseFc1Source.Bias;
baseFc1.WeightLearnRateFactor = 0;
baseFc1.BiasLearnRateFactor = 0;

baseRelu1 = reluLayer("Name", "base_relu1");

baseFc2 = fullyConnectedLayer(size(baseFc2Source.Weights, 1), "Name", "base_fc2");
baseFc2.Weights = baseFc2Source.Weights;
baseFc2.Bias = baseFc2Source.Bias;
baseFc2.WeightLearnRateFactor = 0;
baseFc2.BiasLearnRateFactor = 0;

baseRelu2 = reluLayer("Name", "base_relu2");

baseAction = fullyConnectedLayer(actDim, "Name", "base_action");
baseAction.Weights = baseActionSource.Weights;
baseAction.Bias = baseActionSource.Bias;
baseAction.WeightLearnRateFactor = 0;
baseAction.BiasLearnRateFactor = 0;

baseTanh = tanhLayer("Name", "base_tanh");

residualConcat = concatenationLayer(1, 2, "Name", "residual_concat");
residualFc1 = fullyConnectedLayer(hiddenUnits, "Name", "residual_fc1");
residualRelu1 = reluLayer("Name", "residual_relu1");
residualFc2 = fullyConnectedLayer(hiddenUnits, "Name", "residual_fc2");
residualRelu2 = reluLayer("Name", "residual_relu2");

residualOut = fullyConnectedLayer(actDim, "Name", "residual_out");
residualOut.Weights = zeros(actDim, hiddenUnits, "single");
residualOut.Bias = zeros(actDim, 1, "single");
residualTanh = tanhLayer("Name", "residual_tanh");

residualScaleLayer = fullyConnectedLayer(actDim, "Name", "residual_scale");
residualScaleLayer.Weights = single(residualScale * eye(actDim));
residualScaleLayer.Bias = zeros(actDim, 1, "single");
residualScaleLayer.WeightLearnRateFactor = 0;
residualScaleLayer.BiasLearnRateFactor = 0;

residualAdd = additionLayer(2, "Name", "residual_add");
finalAction = functionLayer(@clipActionToUnitRange, ...
    "Name", "final_action", "Formattable", true);

actorLG = layerGraph();
actorLG = addLayers(actorLG, observationLayer);
actorLG = addLayers(actorLG, baseFc1);
actorLG = addLayers(actorLG, baseRelu1);
actorLG = addLayers(actorLG, baseFc2);
actorLG = addLayers(actorLG, baseRelu2);
actorLG = addLayers(actorLG, baseAction);
actorLG = addLayers(actorLG, baseTanh);
actorLG = addLayers(actorLG, residualConcat);
actorLG = addLayers(actorLG, residualFc1);
actorLG = addLayers(actorLG, residualRelu1);
actorLG = addLayers(actorLG, residualFc2);
actorLG = addLayers(actorLG, residualRelu2);
actorLG = addLayers(actorLG, residualOut);
actorLG = addLayers(actorLG, residualTanh);
actorLG = addLayers(actorLG, residualScaleLayer);
actorLG = addLayers(actorLG, residualAdd);
actorLG = addLayers(actorLG, finalAction);

actorLG = connectLayers(actorLG, "observation", "base_fc1");
actorLG = connectLayers(actorLG, "base_fc1", "base_relu1");
actorLG = connectLayers(actorLG, "base_relu1", "base_fc2");
actorLG = connectLayers(actorLG, "base_fc2", "base_relu2");
actorLG = connectLayers(actorLG, "base_relu2", "base_action");
actorLG = connectLayers(actorLG, "base_action", "base_tanh");

actorLG = connectLayers(actorLG, "observation", "residual_concat/in1");
actorLG = connectLayers(actorLG, "base_tanh", "residual_concat/in2");
actorLG = connectLayers(actorLG, "residual_concat", "residual_fc1");
actorLG = connectLayers(actorLG, "residual_fc1", "residual_relu1");
actorLG = connectLayers(actorLG, "residual_relu1", "residual_fc2");
actorLG = connectLayers(actorLG, "residual_fc2", "residual_relu2");
actorLG = connectLayers(actorLG, "residual_relu2", "residual_out");
actorLG = connectLayers(actorLG, "residual_out", "residual_tanh");
actorLG = connectLayers(actorLG, "residual_tanh", "residual_scale");

actorLG = connectLayers(actorLG, "base_tanh", "residual_add/in1");
actorLG = connectLayers(actorLG, "residual_scale", "residual_add/in2");
actorLG = connectLayers(actorLG, "residual_add", "final_action");

actorNet = dlnetwork(actorLG);
actor = rlContinuousDeterministicActor( ...
    actorNet, observationInfo, actionInfo, ...
    ObservationInputNames="observation");
end

function agentOptions = buildResidualAgentOptions(baseAgent, td3)
agentOptions = baseAgent.AgentOptions;

if isprop(agentOptions, "ExplorationModel") && ~isempty(agentOptions.ExplorationModel)
    explorationModel = agentOptions.ExplorationModel;
    explorationModel.StandardDeviation = td3.explorationStd;
    explorationModel.StandardDeviationMin = td3.explorationStdMin;
    explorationModel.StandardDeviationDecayRate = td3.explorationStdDecayRate;
    agentOptions.ExplorationModel = explorationModel;
end

if isprop(agentOptions, "ResetExperienceBufferBeforeTraining") && ...
        isfield(td3, "resetExperienceBufferBeforeTraining")
    agentOptions.ResetExperienceBufferBeforeTraining = ...
        logical(td3.resetExperienceBufferBeforeTraining);
end
end

function layer = findLayerByName(layers, layerName)
idx = find(arrayfun(@(L) string(L.Name) == string(layerName), layers), 1, "first");
if isempty(idx)
    error("Could not find layer '%s' in the base actor.", string(layerName));
end
layer = layers(idx);
end
