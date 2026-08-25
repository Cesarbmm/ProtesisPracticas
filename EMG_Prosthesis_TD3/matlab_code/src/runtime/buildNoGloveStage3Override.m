function override = buildNoGloveStage3Override( ...
        calibration, expectedContext, randomSeed)
%buildNoGloveStage3Override returns the simulation-only ETAPA 3 profile.

arguments
    calibration (1, 1) struct
    expectedContext (1, 1) struct
    randomSeed (1, 1) double {mustBeInteger, mustBeNonnegative} = 11
end

validation = validateIntentCalibration(calibration, expectedContext);
if ~validation.isValid
    error("buildNoGloveStage3Override:InvalidCalibration", ...
        "ETAPA 3 requires a valid compatible calibration: %s", ...
        strjoin(validation.issues, "; "));
end

override = buildNoGloveStage1Override(randomSeed);
override.observationVariant = "intentMarkov60";
override.intentDecoderEnabled = true;
override.intentCalibration = calibration;
override.intentExpectedContext = expectedContext;
override.period = calibration.limits.deltaT;
override.maxNumberStepsInEpisodes = 80;

% Repeat safety-critical values after deriving the profile so callers can
% audit the effective stage without relying on inherited defaults.
override.referenceSource = "emgIntent";
override.run_training = false;
override.newTraining = false;
override.usePrerecorded = true;
override.simMotors = true;
override.connect_glove = false;
override.actionInterfaceVariant = "baselineQuantized";
override.rewardType = "trackingMseActionRateReward";
override.flagSaveTraining = false;
override.plotEpisodeOnTest = false;
end
