function [agent, name] = agentTd3(observationInfo, actionInfo)
%agentTd3 Configura y devuelve un agente TD3.
%
% The agent supports both the historical feed-forward actor/critics and a
% recurrent LSTM-based variant selected through configurables(). The
% recurrent path uses dlnetwork + rlContinuousDeterministicActor /
% rlQValueFunction so that SequenceLength can be used by TD3.

name = 'td3_agent';
td3 = configurables('td3');

if isfield(td3, "useRecurrent") && td3.useRecurrent
    [actor, critics] = buildRecurrentTd3Networks(observationInfo, actionInfo, td3);
else
    [actor, critics] = buildFeedforwardTd3Networks(observationInfo, actionInfo, td3);
end

agentOptions = buildTd3AgentOptions(td3);
agent = rlTD3Agent(actor, critics, agentOptions);

% Reassign after construction to avoid toolbox/version-dependent defaults.
agent.AgentOptions.ActorOptimizerOptions = agentOptions.ActorOptimizerOptions;
agent.AgentOptions.CriticOptimizerOptions = agentOptions.CriticOptimizerOptions;
agent.AgentOptions.ExplorationModel = agentOptions.ExplorationModel;
agent.AgentOptions.TargetPolicySmoothModel = agentOptions.TargetPolicySmoothModel;
if isprop(agent.AgentOptions, "SequenceLength")
    agent.AgentOptions.SequenceLength = agentOptions.SequenceLength;
end
if isprop(agent.AgentOptions, "NumStepsToLookAhead")
    agent.AgentOptions.NumStepsToLookAhead = agentOptions.NumStepsToLookAhead;
end
end

function [actor, critics] = buildFeedforwardTd3Networks(observationInfo, actionInfo, td3)
hL = @reluLayer;
numHiddenUnits = td3.numHiddenUnits;

statePath1 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs1", "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs1")
    hL("Name", "relu_obs1")
    ];

actionPath1 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act1", "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act1")
    hL("Name", "relu_act1")
    ];

commonPath1 = [
    concatenationLayer(1, 2, "Name", "concat1")
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

statePath2 = [
    featureInputLayer(observationInfo.Dimension(1), "Name", "obs2", "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs2")
    hL("Name", "relu_obs2")
    ];

actionPath2 = [
    featureInputLayer(actionInfo.Dimension(1), "Name", "act2", "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_act2")
    hL("Name", "relu_act2")
    ];

commonPath2 = [
    concatenationLayer(1, 2, "Name", "concat2")
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

actorNetwork = [
    featureInputLayer(observationInfo.Dimension(1), 'Name', 'observation', "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, 'Name', 'fc1')
    hL('Name', 'relu1')
    fullyConnectedLayer(numHiddenUnits, 'Name', 'fc2')
    hL('Name', 'relu2')
    fullyConnectedLayer(actionInfo.Dimension(1), 'Name', 'action')
    tanhLayer('Name', 'scaledAction')
    ];

actor = rlContinuousDeterministicActor(actorNetwork, observationInfo, actionInfo);
critics = [critic1 critic2];
end

function [actor, critics] = buildRecurrentTd3Networks(observationInfo, actionInfo, td3)
obsDim = observationInfo.Dimension(1);
actDim = actionInfo.Dimension(1);
numHiddenUnits = td3.numHiddenUnits;
numRecurrentUnits = td3.recurrentUnits;

actorLayers = [
    sequenceInputLayer(obsDim, "Name", "observation", "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc1")
    reluLayer("Name", "relu1")
    lstmLayer(numRecurrentUnits, "Name", "lstm_actor", "OutputMode", "sequence")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc2")
    reluLayer("Name", "relu2")
    fullyConnectedLayer(actDim, "Name", "action")
    tanhLayer("Name", "scaledAction")
    ];
actorNet = dlnetwork(layerGraph(actorLayers));
actor = rlContinuousDeterministicActor( ...
    actorNet, observationInfo, actionInfo, ...
    ObservationInputNames="observation");

critic1 = buildRecurrentCritic("1", observationInfo, actionInfo, numHiddenUnits, numRecurrentUnits);
critic2 = buildRecurrentCritic("2", observationInfo, actionInfo, numHiddenUnits, numRecurrentUnits);
critics = [critic1 critic2];
end

function critic = buildRecurrentCritic(suffix, observationInfo, actionInfo, numHiddenUnits, numRecurrentUnits)
obsName = "obs" + suffix;
actName = "act" + suffix;
obsFc2Name = "fc_obs" + suffix + "_2";
actFcName = "fc_act" + suffix;
concatName = "concat" + suffix;

obsPath = [
    sequenceInputLayer(observationInfo.Dimension(1), "Name", obsName, "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_obs" + suffix + "_1")
    reluLayer("Name", "relu_obs" + suffix)
    fullyConnectedLayer(numHiddenUnits, "Name", obsFc2Name)
    ];

actPath = [
    sequenceInputLayer(actionInfo.Dimension(1), "Name", actName, "Normalization", "none")
    fullyConnectedLayer(numHiddenUnits, "Name", actFcName)
    ];

commonPath = [
    concatenationLayer(1, 2, "Name", concatName)
    reluLayer("Name", "relu_common" + suffix)
    lstmLayer(numRecurrentUnits, "Name", "lstm_critic" + suffix, "OutputMode", "sequence")
    fullyConnectedLayer(1, "Name", "q" + suffix)
    ];

criticLG = layerGraph(obsPath);
criticLG = addLayers(criticLG, actPath);
criticLG = addLayers(criticLG, commonPath);
criticLG = connectLayers(criticLG, obsFc2Name, concatName + "/in1");
criticLG = connectLayers(criticLG, actFcName, concatName + "/in2");

criticNet = dlnetwork(criticLG);
critic = rlQValueFunction(criticNet, observationInfo, actionInfo, ...
    ObservationInputNames=obsName, ActionInputNames=actName);
end

function agentOptions = buildTd3AgentOptions(td3)
agentOptions = rlTD3AgentOptions( ...
    'TargetSmoothFactor', td3.targetSmoothFactor, ...
    'ExperienceBufferLength', td3.experienceBufferLength, ...
    'MiniBatchSize', td3.miniBatchSize, ...
    'SampleTime', td3.sampleTime, ...
    'DiscountFactor', td3.discountFactor, ...
    'PolicyUpdateFrequency', td3.policyUpdateFrequency, ...
    'TargetUpdateFrequency', td3.targetUpdateFrequency);

if isfield(td3, "useRecurrent") && td3.useRecurrent
    if isfield(td3, "sequenceLength")
        agentOptions.SequenceLength = td3.sequenceLength;
    end
    if isfield(td3, "numStepsToLookAhead")
        agentOptions.NumStepsToLookAhead = td3.numStepsToLookAhead;
    end
else
    agentOptions.SequenceLength = 1;
    if isprop(agentOptions, "NumStepsToLookAhead")
        agentOptions.NumStepsToLookAhead = 1;
    end
end

actorOptimizerOptions = rlOptimizerOptions( ...
    'LearnRate', td3.actorLearnRate, ...
    'GradientThreshold', td3.gradientThreshold, ...
    'L2RegularizationFactor', td3.actorL2Regularization);
criticOptimizerOptions = [ ...
    rlOptimizerOptions( ...
        'LearnRate', td3.criticLearnRate, ...
        'GradientThreshold', td3.gradientThreshold, ...
        'L2RegularizationFactor', td3.criticL2Regularization), ...
    rlOptimizerOptions( ...
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
end
