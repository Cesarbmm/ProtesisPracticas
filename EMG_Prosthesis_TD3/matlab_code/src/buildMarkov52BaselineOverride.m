function override = buildMarkov52BaselineOverride(baseConfigs, patchStruct)
%buildMarkov52BaselineOverride builds a reproducible baseline override.
%
% The helper freezes the current valid baseline around markov52 + TD3
% feedforward + trackingMseActionRateReward, and then applies an optional
% patch struct on top.

arguments
    baseConfigs struct
    patchStruct struct = struct()
end

override = struct();
override.run_training = true;
override.newTraining = true;
override.usePrerecorded = true;
override.simMotors = true;
override.connect_glove = false;
override.observationVariant = "markov52";
override.rewardType = 'trackingMseActionRateReward';
override.rewardActionWeight = 0.01;
override.rewardDeltaActionWeight = 0.05;
override.quantizeCommandsForSimulation = true;
override.plotEpisodeOnTest = false;
override.enableDetailedActionDiagnostics = false;
override.savePerMotorMetrics = true;
override.unifyActions = baseConfigs.unifyActions;
override.speeds = baseConfigs.speeds;
override.actionInterfaceVariant = baseConfigs.actionInterfaceVariant;
override.actionCommandActivationThreshold = ...
    baseConfigs.actionCommandActivationThreshold;
override.actionCommandLevels = baseConfigs.actionCommandLevels;
override.actionWarpDeadzone = baseConfigs.actionWarpDeadzone;
override.actionWarpOutputLevels = baseConfigs.actionWarpOutputLevels;
override.dataset = baseConfigs.dataset;
override.dataset_folder = baseConfigs.dataset_folder;
override.randomSeed = baseConfigs.randomSeed;
override.numEMGFeatures = baseConfigs.numEMGFeatures;
override.emgHistoryLength = baseConfigs.emgHistoryLength;
override.td3 = baseConfigs.td3;
override.td3Residual = baseConfigs.td3Residual;
override.td3.useRecurrent = false;

patchFields = fieldnames(patchStruct);
for i = 1:numel(patchFields)
    override.(patchFields{i}) = patchStruct.(patchFields{i});
end
end
