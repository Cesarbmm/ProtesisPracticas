%runProsthesis executes in real time the prosthesis control agent.
%
%INSTRUCTIONS
% 1. Check and calibrate the options in configurables()
% 2. Define the agent file and name in Configs section of this script
% 2. Execute this script with:
%   >> runProsthesis

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: z_tja
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

%}
%% Aux and dependent variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%% NOT MODIFY FROM HERE %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% libs
addpath(genpath('.\src\'))
addpath(genpath('.\config\'))
addpath(genpath('.\lib\'))
addpath(genpath('.\agents\'))

cc

%% Configs
%--- from sim, not working
% agentFile  = ".\trainedAgents\22-02-22 13 54 cDQN_slower_1132.mat";

% %--WTF?
% agentFile  = ...
%     ".\trainedAgents\22-02-22 21 59 cDQN_slower_RT_distanceRewarding_19.mat";
% 
% name = 'cDQN_slower_RT_distanceRewarding';
%--WTF?

agentFile  = "C:\Users\joseg\Documents\Tesis\Agent341200.mat";
name = 'FINAL';

%% Define the base directory and the episode directory
baseDir = "C:\Users\david\Documents\GitHub\prosthesis_v2\prosthesis_code\lib\prosthesis_v2\matlab_code\episodes";
episodeDir = fullfile(baseDir, name);

% Create the base directory if it doesn't exist
if ~isfolder(baseDir)
    mkdir(baseDir);
end

% Create the episode directory if it doesn't exist
if ~isfolder(episodeDir)
    mkdir(episodeDir);
end

%% loading agent and env
aux = load(agentFile, "saved_agent");
agent = aux.saved_agent;

agent.AgentOptions.ResetExperienceBufferBeforeTraining = true;

%%
env = Env(episodeDir, false, {}, {}); % Pasar los argumentos requeridos por el constructor

%% Loop
env.loop(agent);
