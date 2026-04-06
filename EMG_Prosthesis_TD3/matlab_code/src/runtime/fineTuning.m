%fineTunning uses a pretrained agent to fine tune with the real prosthesis

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

27 / 3 / 2021
Matlab r2021b.
%}

close all
clear all
clc

% warning off backtrace

%% configs
usePrerecorded = false;


%% continueTraining
%true para iniciar con un entrenamiento false para continuar desde un
%agente ya entrenado
% newTraning = true;
newTraning = false;

agentFile  = "";
name = 'final_eps0.3_alf1e-5';

if ~newTraning && strlength(agentFile) == 0
    error("Set 'agentFile' in src/fineTuning.m before executing this script.");
end

%% Agent
if newTraning
    %- creating agent
    observationInfo = Env.defineObservationInfo();
    actionInfo = Env.defineActionInfo();

    % [agent, name] = createAgent0(observationInfo, actionInfo); % 0.01 default
    % [agent, name] = createAgent1_5(observationInfo, actionInfo); % 0.001

    % no baseline and 0.005
    %[agent, name] = createAgent1(neurons, observationInfo, actionInfo);
    % [agent, name] = createAgent_brainer([], observationInfo, actionInfo);

    %%--- DQN
    % [agent, name] = createAgentDQN(observationInfo, actionInfo);
    % [agent, name] = aRNN_createAgent(observationInfo, actionInfo);

    % [agent, name] = aMin_createAgent(observationInfo, actionInfo);
    % [agent, name] = aTiny_createAgent(observationInfo, actionInfo);
    % [agent, name] = aAvg_createAgent(observationInfo, actionInfo);
    % [agent, name] = aDQNs_createAgent(observationInfo, actionInfo);
    [agent, name] = cMomen2_createAgent(observationInfo, actionInfo);
else
    %- loading agent
    aux = load (agentFile, "agent");
    agent = aux.agent;
    
    %---
    agent.AgentOptions.EpsilonGreedyExploration.Epsilon = 0.3;
    critic = agent.getCritic();
    critic.Options.LearnRate = 1e-5;%1e-3
    agent = agent.setCritic(critic);

%     agent.AgentOptions.ResetExperienceBufferBeforeTraining = true;
end


%% Env
if usePrerecorded
    env = Env(name, true, emg, glove);
else
    env = Env(name);
end
% env.prosthesis.goHomePosition(true,true);
% pause(0.5)
drawnow;
pos = env.prosthesis.read();
env.log(sprintf("Reseting Initial position from [%d %d %d %d] to 0", ...
    pos(end, 1), pos(end, 2), pos(end, 3), pos(end, 4)));

env.prosthesis.resetEncoder(); % home position at zero
drawnow

%% training
opts = configurables('trainingOptions');

% including agent name--- %saving not in onedrive, backup
opts.SaveAgentDirectory = sprintf('%s_%s\\', opts.SaveAgentDirectory,name);

% --- training
% trainingInfo = train(agent, env, opts);

%--- sim
simOpts = configurables('simOpts');
trainingInfo = sim(agent, env, simOpts);

%% ---- saving
try
    numEpisodes = trainingInfo.EpisodeIndex(end);
catch
    numEpisodes = simOpts.NumSimulations;
end

%     numEpisodes = 56;
% end

save(sprintf(".\\trainedAgents\\%s %s_%d.mat", datestr(datetime, ...
    'yy-mm-dd HH MM'), name, numEpisodes), "agent", "trainingInfo");% );%





