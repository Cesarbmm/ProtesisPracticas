%evalRandomAgent sims the random agent for evaluation.

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

5 / april / 2021
Matlab r2021b.
%}

close all
clear all
clc

% warning off backtrace

%% configs
usePrerecorded = true;


%% loading prerecordings
[emg, glove] = getDataset({'dataset1_sep', 'dataset2_extended'}); %200

%% Agent
%- creating agent
observationInfo = Env.defineObservationInfo();
actionInfo = Env.defineActionInfo();

[agent, name] = cMomen2_createAgent(observationInfo, actionInfo);



%% Env
if usePrerecorded
    env = Env(name, true, emg, glove);
else
    env = Env(name);
end

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

%% ---- saving
numEpisodes = simOpts.NumSimulations;

save(sprintf(".\\data\\evaluation\\%s\\%s %s_%d.mat", name ...
    , datestr(datetime, 'yy-mm-dd HH MM'), name, numEpisodes), ...
    "options", "agent", "trainingInfo");

