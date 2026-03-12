%evalTrainedAgent runs in real time the agent for evaluation.

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

6 / april / 2021
Matlab r2021b.
%}

close all
clear all
clc

% warning off backtrace


%% Agent

agentFile  = ".\trainedAgents\22-03-27 18 46 final_eps0.3_alf5e-5_161.mat";

name = 'final_eps0.3_alf1e-5';



%- loading agent
aux = load (agentFile, "agent");
agent = aux.agent;

%--- just in case, maybe not needed
agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = 0.1;
agent.AgentOptions.EpsilonGreedyExploration.Epsilon = 0.01;
agent.AgentOptions.EpsilonGreedyExploration.EpsilonMin = 0.01;

%% Env
env = Env(name);
pause(0.5)
drawnow;
pos = env.prosthesis.read();
env.log(sprintf("Reseting Initial position from [%d %d %d %d] to 0", ...
    pos(end, 1), pos(end, 2), pos(end, 3), pos(end, 4)));

env.prosthesis.resetEncoder(); % home position at zero
drawnow

%% training
options = configurables();
simOpts = options.simOpts;

%--- sim
trainingInfo = sim(agent, env, simOpts);
env.prosthesis.goHomePosition
%% ---- saving
numEpisodes = simOpts.NumSimulations;

save(sprintf(".\\data\\evaluation\\%s\\%s %s_%d.mat", name ...
    , datestr(datetime, 'yy-mm-dd HH MM'), name, numEpisodes), ...
    "options", "agent", "trainingInfo");

