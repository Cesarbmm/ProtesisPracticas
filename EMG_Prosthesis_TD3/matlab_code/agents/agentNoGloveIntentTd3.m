function agent = agentNoGloveIntentTd3(observationInfo, actionInfo)
%agentNoGloveIntentTd3 creates a fresh feedforward ETAPA 6 TD3 agent.

configs = configurables();
if configs.referenceSource ~= "emgIntent" || ...
        configs.observationVariant ~= "intentMarkov60" || ...
        configs.stateLength ~= 60 || ...
        ~isequal(observationInfo.Dimension, [60, 1])
    error("agentNoGloveIntentTd3:InvalidObservationContract", ...
        "The no-glove TD3 agent requires intentMarkov60 with 60 inputs.");
end
if configs.td3.useRecurrent
    error("agentNoGloveIntentTd3:RecurrentNotAuthorized", ...
        "ETAPA 6 requires the initial feedforward TD3 architecture.");
end
if ~configs.newTraining || strlength(string(configs.agentFile)) > 0
    error("agentNoGloveIntentTd3:HistoricalCheckpointForbidden", ...
        "The ETAPA 6 agent must be initialized from scratch.");
end
if isfield(configs.td3Residual, "enabled") && configs.td3Residual.enabled
    error("agentNoGloveIntentTd3:ResidualBaseForbidden", ...
        "ETAPA 6 cannot use a residual or frozen historical base.");
end

agent = agentTd3(observationInfo, actionInfo);
end
