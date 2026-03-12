function [agent, name] = aAlphas_createAgent(observationInfo, actionInfo)
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
numHiddenUnits = 16;
name = '10Alphas_ss';

%% configs
initOpts = rlAgentInitializationOptions('NumHiddenUnit', numHiddenUnits,...
    'UseRNN', false);


%Para Deep Q Learning
agentOptions = rlDQNAgentOptions(...
    'UseDoubleDQN', true, ... % default
    'SequenceLength', 1, ... % default, Maximum batch-training trajectory length when using a recurrent neural network for the critic, specified as a positive integer. This value must be greater than 1 when using a recurrent neural network for the critic and 1 otherwise.
    'TargetSmoothFactor',1e-3, ... % Smoothing factor for target critic updates, specified as a positive scalar less than or equal to 1.
    'TargetUpdateFrequency', 1, ... %def
    'ResetExperienceBufferBeforeTraining', false,...%default
    'SaveExperienceBufferWithAgent', true, ... % not default
    'MiniBatchSize', 512, ... 
    'NumStepsToLookAhead', 10, ...
    'ExperienceBufferLength', 10000, ... % default
    'DiscountFactor', 0.7 );% default


% agentOptions.EpsilonGreedyExploration.EpsilonDecay = 1e-4;
% agentOptions.EpsilonGreedyExploration.Epsilon = 1; % default
% agentOptions.EpsilonGreedyExploration.EpsilonMin = 0.01; % default

agent = rlDQNAgent(observationInfo,actionInfo, initOpts, agentOptions);

critic = agent.getCritic;
critic.Options.LearnRate = 0.00001;
agent = agent.setCritic(critic);
end
