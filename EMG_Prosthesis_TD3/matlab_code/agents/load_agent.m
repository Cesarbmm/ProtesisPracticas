function agent = load_agent(observationInfo, actionInfo, agent_id, ...
    param_name, param_value)
%load_agent() returns the agent with the given param. Assumes every agent
%is parameterized by only 1 parameter.
%
% # INPUTS
%  observationInfo
%  actionInfo
%  agent_id         string of the type of agent.
%  param_name       name of an hyper parameter.
%  param_value      value of the previous hyper parameter
%                   Both of these fields, depend on the agent.
%
% # OUTPUTS
%  agent            RL agent
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Jonathan Zea
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

03 January 2024
%}

%% Input Validation
arguments
    observationInfo
    actionInfo
    agent_id (1, 1) string
    param_name
    param_value
end

%%
switch agent_id
    case "00_oldy"
        % test the old agent. it not tests parameters.
        agent = agent_00_oldy(observationInfo, actionInfo);

    case "td3"
        % test the td3 agent. it not tests parameters.
        agent = agentTd3(observationInfo, actionInfo);

    case "td3_residual7250"
        agent = agentTd3Residual7250(observationInfo, actionInfo);

    case "td3_residual_lift"
        agent = agentTd3ResidualLift(observationInfo, actionInfo);

    case "sac"
        % test the sac agent. it not tests parameters.
        agent = rlSac(observationInfo,actionInfo)
    

    otherwise
        disp(param_name)
        disp(param_value)
        error("Agent '%s' not defined.", agent_id)
end
