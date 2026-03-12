function [] = loop(this, agent)
%loop() runs the agent in a loop by episode. There is no learning here,
%just using agent.
%
% Usage
%   [] = env.loop(agent);
%
% Inputs
%   agent   RL trained matlab agent
%
% Outputs
%
% Examples
%    >> env.loop(agent)
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: z_tja
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

23 February 2022
Matlab 9.11.0.1837725 (R2021b) Update 2.
%}

%%
resetEnv = true; % prealloc
while true
    if resetEnv
        obs = this.reset();
        agent.reset();
    end
    action = agent.getAction(obs);
    [obs, ~, resetEnv , ~] = this.step(action);
end