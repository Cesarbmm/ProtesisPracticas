function [agent, name] = createAgent1(observationInfo, actionInfo)
%createAgent0 returns an agent.
%
% Ejemplo
%	= createAgent0()
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

17 November 2021
Matlab r2021b.
%}
numHiddenUnits = 64;
%% configs
%From docs:
% Policy gradient agents do not support recurrent neural networks[1].
% [1] 
% >> doc rlPGAgent
initOpts = rlAgentInitializationOptions(...
    'NumHiddenUnit', numHiddenUnits, 'UseRNN', false);

% default values
opts = rlPGAgentOptions("UseBaseline", false, ...
    "UseDeterministicExploitation", false, "DiscountFactor", 0.99, ...
    "EntropyLossWeight", 0);
% Entropy loss weight, specified as a scalar value between 0 and 1. A
% higher entropy loss weight value promotes agent exploration by applying a
% penalty for being too certain about which action to take. Doing so can
% help the agent move out of local optima.
%% creating
agent = rlPGAgent(observationInfo, actionInfo, initOpts, opts);

name = 'nobase_mid';
actor = agent.getActor;
actor.Options.LearnRate = 0.005;
agent = agent.setActor(actor);
end
%
%
% function Ag = Agente0(env)
% %AGENT Construct an instance of this class
% %enviroment = Env();
%
%
% criticNetwork = [
%     sequenceInputLayer(obsInfo.Dimension(1),'Normalization','none','Name','state')
%     fullyConnectedLayer(50, 'Name', 'CriticStateFC1')
%     reluLayer('Name','CriticRelu1')
%     lstmLayer(20,'OutputMode','sequence','Name','CriticLSTM');
%     fullyConnectedLayer(20,'Name','CriticStateFC2')
%     reluLayer('Name','CriticRelu2')
%     fullyConnectedLayer(numel(actInfo.Elements),'Name','output')
%     ];
%
% criticOptions = rlRepresentationOptions('LearnRate',1e-3,'GradientThreshold',1);
% critic = rlQValueRepresentation(criticNetwork,obsInfo,actInfo,'Observation','state',criticOptions);
%
% agentOptions = rlDQNAgentOptions(...
%     'UseDoubleDQN',false, ...
%     'TargetSmoothFactor',5e-3, ...
%     'ExperienceBufferLength',1e6, ...
%     'SequenceLength',20);
% agentOptions.EpsilonGreedyExploration.EpsilonDecay = 1e-4;
%
% Ag = rlDQNAgent(critic, agentOptions);
% end
