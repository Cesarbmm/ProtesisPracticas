function [agent, name] = dSum_createAgent(observationInfo, actionInfo)
% returns a configured agent.
%
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org
Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
Ahora solo lo sabe dios.

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

Matlab r2021b.
%}
numHiddenUnits = 10;
name = '19Summ-LSTM10';
hL = @reluLayer;

%% newtork
criticNetwork = [
    sequenceInputLayer(44,"Name","observation")
    % featureInputLayer(44, "Name", "observation")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_1")
    hL("Name", "hL1")
    fullyConnectedLayer(numHiddenUnits, "Name", "fc_2")
    hL("Name", "hL2")
    lstmLayer(16,"Name","lstm")
    fullyConnectedLayer(81, "Name", "output")];

opt = rlRepresentationOptions('LearnRate', 0.005);

critic = rlQValueRepresentation(criticNetwork, observationInfo, ...
    actionInfo, 'Observation', {'observation'}, opt);
%, 'Action', {'action'}

%% agent options
agentOptions = rlDQNAgentOptions(...
    'UseDoubleDQN', true, ... % default true
    'SequenceLength', 10, ... % default 1, Maximum batch-training trajectory length when using a recurrent neural network for the critic, specified as a positive integer. This value must be greater than 1 when using a recurrent neural network for the critic and 1 otherwise.
    'TargetSmoothFactor',1e-3, ... % Smoothing factor for target critic updates, specified as a positive scalar less than or equal to 1.
    'TargetUpdateFrequency', 1, ... %def
    'ResetExperienceBufferBeforeTraining', false,...
    'SaveExperienceBufferWithAgent', true, ... % not default
    'MiniBatchSize', 1024, ...
    'NumStepsToLookAhead', 1, ...
    'ExperienceBufferLength', 10000, ... % default
    'DiscountFactor', 0.99);% default

agentOptions.EpsilonGreedyExploration.EpsilonDecay = 5e-3;
% agentOptions.EpsilonGreedyExploration.Epsilon = 1; % default
% agentOptions.EpsilonGreedyExploration.EpsilonMin = 0.01; % default

agent = rlDQNAgent(critic, agentOptions);

