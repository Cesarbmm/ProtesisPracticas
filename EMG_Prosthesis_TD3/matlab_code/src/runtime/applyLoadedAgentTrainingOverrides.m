function [agent, appliedOverrides] = applyLoadedAgentTrainingOverrides(agent, configs)
%applyLoadedAgentTrainingOverrides reapplies mutable TD3 options to a loaded agent.
%
% Saved checkpoints persist their own agent options. When resuming
% training, we want the active experiment configuration to control
% exploration noise and optional replay-buffer reset without rebuilding the
% policy from scratch.

arguments
    agent
    configs struct
end

appliedOverrides = struct( ...
    "explorationStd", NaN, ...
    "explorationStdMin", NaN, ...
    "explorationStdDecayRate", NaN, ...
    "resetExperienceBufferBeforeTraining", NaN, ...
    "supportsResetExperienceBuffer", false);

if ~isfield(configs, "td3") || ~isstruct(configs.td3)
    return;
end

if ~isprop(agent, "AgentOptions") || isempty(agent.AgentOptions)
    return;
end

td3 = configs.td3;

if isprop(agent.AgentOptions, "ExplorationModel") && ~isempty(agent.AgentOptions.ExplorationModel)
    explorationModel = agent.AgentOptions.ExplorationModel;
    if isfield(td3, "explorationStd")
        explorationModel.StandardDeviation = td3.explorationStd;
        appliedOverrides.explorationStd = td3.explorationStd;
    end
    if isfield(td3, "explorationStdMin")
        explorationModel.StandardDeviationMin = td3.explorationStdMin;
        appliedOverrides.explorationStdMin = td3.explorationStdMin;
    end
    if isfield(td3, "explorationStdDecayRate")
        explorationModel.StandardDeviationDecayRate = td3.explorationStdDecayRate;
        appliedOverrides.explorationStdDecayRate = td3.explorationStdDecayRate;
    end
    agent.AgentOptions.ExplorationModel = explorationModel;
end

if isprop(agent.AgentOptions, "ResetExperienceBufferBeforeTraining")
    appliedOverrides.supportsResetExperienceBuffer = true;
    if isfield(td3, "resetExperienceBufferBeforeTraining")
        resetValue = logical(td3.resetExperienceBufferBeforeTraining);
        agent.AgentOptions.ResetExperienceBufferBeforeTraining = resetValue;
        appliedOverrides.resetExperienceBufferBeforeTraining = resetValue;
    end
end
end
