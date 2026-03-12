function [agent, name] = createAgent_brainer(numHiddenUnits, ...
    observationInfo, actionInfo)
%createAgent0 returns an agent.
%
% Inputs
%   nameUser		char con el nombre de la carpeta del usuario.
%
% Outputs
%   nameUser		char con el nombre de la carpeta del usuario.
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

%% configs
%From docs:
% Policy gradient agents do not support recurrent neural networks[1].
% [1] 
% >> doc rlPGAgent
numHiddenUnits = 100;
initOpts = rlAgentInitializationOptions(...
    'NumHiddenUnit', numHiddenUnits, 'UseRNN', false);

% default values
opts = rlPGAgentOptions("UseBaseline", true, ...
    "UseDeterministicExploitation", false, "DiscountFactor", 0.99, ...
    "EntropyLossWeight", 0);
% Entropy loss weight, specified as a scalar value between 0 and 1. A
% higher entropy loss weight value promotes agent exploration by applying a
% penalty for being too certain about which action to take. Doing so can
% help the agent move out of local optima.
%% creating
agent = rlPGAgent(observationInfo, actionInfo, initOpts, opts);

name = 'brainer';
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
