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

farMinEncoderValue = params.encodersLimits(1);
farMaxEncoderValue = params.encodersLimits(2);

EMGFeaturesMin = params.EMGFeaturesLimits(1);
EMGFeaturesMax = params.EMGFeaturesLimits(2);
encoderLower = params.encoder2state_scale(farMinEncoderValue * ones(numMotors, 1));
encoderUpper = params.encoder2state_scale(farMaxEncoderValue * ones(numMotors, 1));

%% creating observation space
obsInfo = rlNumericSpec([stateLength 1]); % col-wise


%% limits
if stateLength == numEMGFeatures + numMotors
    obsInfo.LowerLimit = [EMGFeaturesMin*ones(numEMGFeatures, 1);
        repmat(farMinEncoderValue, numMotors, 1)];
    obsInfo.UpperLimit = [EMGFeaturesMax*ones(numEMGFeatures, 1);
        repmat(farMaxEncoderValue, numMotors, 1)];
    obsInfo.Description = sprintf(...
        'State defined with %d EMG features and %d encoder positions',...
        numEMGFeatures, numMotors);
elseif stateLength == numEMGFeatures + 3*numMotors
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
else
    error('Unsupported stateLength=%d for %d motors', stateLength, numMotors);
end

obsInfo.Name = 'prosthesis_state';
end
