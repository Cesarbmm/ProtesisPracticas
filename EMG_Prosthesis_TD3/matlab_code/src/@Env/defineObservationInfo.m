function obsInfo = defineObservationInfo()
%defineObservationInfo() is a static method that retuns the limits and
%dimension of the observation of the environment.
%The observation is defined as the concatenation of EMG features with
%cinematic info. The EMG features is a F-by-1 vector from EMG features.
%The cinematic info is a 4-by-1 vector with the encoder position of every
%motor.
%
% Examples
%   obsInfo = Env.defineObservation()
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona!
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

12 October 2021

Mod 2024/jan/3
%}

%% aux vars
%unpacking
params = configurables();
hardware = definitions();

numEMGFeatures = params.numEMGFeatures;
numMotors = hardware.numMotors;

stateLength = params.stateLength;
emgHistoryLength = params.emgHistoryLength;
observationVariant = string(params.observationVariant);
layout = buildObservationLayout(observationVariant, ...
    numEMGFeatures, emgHistoryLength, numMotors);
if layout.totalLength ~= stateLength
    error("Env:ObservationLayoutMismatch", ...
        "stateLength=%d does not match %s (%d).", ...
        stateLength, observationVariant, layout.totalLength);
end

farMinEncoderValue = params.encodersLimits(1);
farMaxEncoderValue = params.encodersLimits(2);

EMGFeaturesMin = params.EMGFeaturesLimits(1);
EMGFeaturesMax = params.EMGFeaturesLimits(2);
encoderLower = params.encoder2state_scale(farMinEncoderValue * ones(numMotors, 1));
encoderUpper = params.encoder2state_scale(farMaxEncoderValue * ones(numMotors, 1));

%% creating observation space
obsInfo = rlNumericSpec([stateLength 1]); % col-wise


%% limits
switch observationVariant
case "legacy44"
    obsInfo.LowerLimit = [EMGFeaturesMin*ones(numEMGFeatures, 1);
        repmat(farMinEncoderValue, numMotors, 1)];
    obsInfo.UpperLimit = [EMGFeaturesMax*ones(numEMGFeatures, 1);
        repmat(farMaxEncoderValue, numMotors, 1)];
    obsInfo.Description = sprintf(...
        'State defined with %d EMG features and %d encoder positions',...
        numEMGFeatures, numMotors);
case "markov52"
    deltaLower = -ones(numMotors, 1);
    deltaUpper = ones(numMotors, 1);
    prevActionLower = -ones(numMotors, 1);
    prevActionUpper = ones(numMotors, 1);

    obsInfo.LowerLimit = [EMGFeaturesMin*ones(numEMGFeatures, 1);
        encoderLower;
        deltaLower;
        prevActionLower];
    obsInfo.UpperLimit = [EMGFeaturesMax*ones(numEMGFeatures, 1);
        encoderUpper;
        deltaUpper;
        prevActionUpper];
    obsInfo.Description = sprintf(...
        ['State defined with %d EMG features, %d encoder positions, ' ...
        '%d encoder deltas and %d previous effective actions'],...
        numEMGFeatures, numMotors, numMotors, numMotors);
case "stackedEmg132"
    deltaLower = -ones(numMotors, 1);
    deltaUpper = ones(numMotors, 1);
    prevActionLower = -ones(numMotors, 1);
    prevActionUpper = ones(numMotors, 1);
    emgLower = EMGFeaturesMin*ones(numEMGFeatures*emgHistoryLength, 1);
    emgUpper = EMGFeaturesMax*ones(numEMGFeatures*emgHistoryLength, 1);

    obsInfo.LowerLimit = [emgLower;
        encoderLower;
        deltaLower;
        prevActionLower];
    obsInfo.UpperLimit = [emgUpper;
        encoderUpper;
        deltaUpper;
        prevActionUpper];
    obsInfo.Description = sprintf(...
        ['State defined with %d stacked EMG feature frames (%d each), ' ...
        '%d encoder positions, %d encoder deltas and %d previous ' ...
        'effective actions'],...
        emgHistoryLength, numEMGFeatures, numMotors, numMotors, numMotors);
case {"intentMarkov60", "intentDeclaredRestHoldMarkov62"}
    calibrationValidation = validateIntentCalibration( ...
        params.intentCalibration, params.intentExpectedContext);
    if ~calibrationValidation.isValid
        error("Env:InvalidIntentObservationCalibration", ...
            "Cannot define %s: %s", observationVariant, ...
            strjoin(calibrationValidation.issues, "; "));
    end
    deltaLower = -ones(numMotors, 1);
    deltaUpper = ones(numMotors, 1);
    prevActionLower = -ones(numMotors, 1);
    prevActionUpper = ones(numMotors, 1);
    referenceLower = params.intentCalibration.limits.positionMin(:);
    referenceUpper = params.intentCalibration.limits.positionMax(:);
    velocityUpper = params.intentCalibration.limits.velocityMax(:);

    lowerLimit = [EMGFeaturesMin*ones(numEMGFeatures, 1);
        encoderLower;
        deltaLower;
        prevActionLower;
        referenceLower;
        -velocityUpper];
    upperLimit = [EMGFeaturesMax*ones(numEMGFeatures, 1);
        encoderUpper;
        deltaUpper;
        prevActionUpper;
        referenceUpper;
        velocityUpper];
    if observationVariant == "intentDeclaredRestHoldMarkov62"
        lowerLimit = [lowerLimit; 0; 0];
        upperLimit = [upperLimit; 1; 1];
        obsInfo.Description = sprintf(...
            ['State defined with %d EMG features, %d encoder positions, ' ...
            '%d encoder deltas, %d previous effective actions, %d causal ' ...
            'reference positions, %d causal reference velocities, one ' ...
            'declared-rest bit and one causal hold-memory bit'], ...
            numEMGFeatures, numMotors, numMotors, numMotors, ...
            numMotors, numMotors);
    else
        obsInfo.Description = sprintf(...
            ['State defined with %d EMG features, %d encoder positions, ' ...
            '%d encoder deltas, %d previous effective actions, %d causal ' ...
            'reference positions and %d causal reference velocities'], ...
            numEMGFeatures, numMotors, numMotors, numMotors, ...
            numMotors, numMotors);
    end
    obsInfo.LowerLimit = lowerLimit;
    obsInfo.UpperLimit = upperLimit;

otherwise
    error("Env:UnsupportedObservationVariant", ...
        "Unsupported observationVariant '%s'.", observationVariant);
end

obsInfo.Name = 'prosthesis_state';
end
