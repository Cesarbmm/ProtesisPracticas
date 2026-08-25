function override = buildNoGloveStage4Override( ...
        calibration, expectedContext, randomSeed)
%buildNoGloveStage4Override returns the simulation-only ETAPA 4 profile.

arguments
    calibration (1, 1) struct
    expectedContext (1, 1) struct
    randomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 11
end

override = buildNoGloveStage3Override( ...
    calibration, expectedContext, randomSeed);

% This profile changes only the reward family and records every coefficient
% explicitly. w_v=0 isolates the new target/reward boundary in the first
% causal ablation; velocityMse remains observable in logs.
override.rewardType = "trackingIntentActionRateReward";
override.intentRewardPositionWeight = 1.00;
override.intentRewardVelocityWeight = 0.00;
override.intentRewardActionWeight = 0.01;
override.intentRewardDeltaActionWeight = 0.05;
override.intentRewardSaturationWeight = 0.02;
override.intentRewardSoftActionLimit = 0.90;

% Repeat the invariant controls for manifest-level auditability.
override.referenceSource = "emgIntent";
override.observationVariant = "intentMarkov60";
override.run_training = false;
override.newTraining = false;
override.usePrerecorded = true;
override.simMotors = true;
override.connect_glove = false;
override.actionInterfaceVariant = "baselineQuantized";
override.flagSaveTraining = false;
override.plotEpisodeOnTest = false;
end
