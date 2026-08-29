function override = buildNoGloveStage7mOverride( ...
        calibration, expectedContext, randomSeed)
%buildNoGloveStage7mOverride returns the simulation-only ETAPA 7M profile.

arguments
    calibration (1, 1) struct
    expectedContext (1, 1) struct
    randomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 11
end

override = buildNoGloveStage4Override( ...
    calibration, expectedContext, randomSeed);
override.observationVariant = "intentDeclaredRestHoldMarkov62";
override.intentDeclaredRestHoldPositionMseTolerance = 1e-4;
override.maxNumberStepsInEpisodes = 40;

% Repeat the experimental boundary explicitly for manifest auditability.
override.referenceSource = "emgIntent";
override.intentDecoderEnabled = true;
override.run_training = false;
override.newTraining = false;
override.usePrerecorded = true;
override.simMotors = true;
override.connect_glove = false;
override.actionInterfaceVariant = "baselineQuantized";
override.flagSaveTraining = false;
override.plotEpisodeOnTest = false;
end
