function [state, enc] = calculateState(this, emg, motorData)
%obj.calculateState returns the current state of the prosthesis. It
%requires the EMG and cinematic data. The state uses the lattest cinematic
%info. Output is normilized
%
%# Inputs
%
%# Outputs
%* state        -F-by-1 feature state vector. It has EMG feature data and
%               the last motor data
%

% # ---- emg feature extraction. Applies the bag of functions to the emg
% raw signal.
emgFeatures = this.featureCalculator(emg); % E-by-8 -> F-by-1

enc = this.encoderNormCalculator(motorData(end, :)');
stateLength = configurables("stateLength");
emgHistoryLength = configurables("emgHistoryLength");

if stateLength == numel(emgFeatures) + numel(enc)
    state = [emgFeatures; enc];
elseif stateLength == numel(emgFeatures) + 3*numel(enc)
    deltaEnc = enc - this.prevEncoderNorm(:);
    deltaEnc = max(-1, min(1, deltaEnc));
    prevEffectiveAction = max(-1, min(1, this.prevEffectiveActionForState(:)));
    state = [emgFeatures; enc; deltaEnc; prevEffectiveAction];
elseif stateLength == numel(emgFeatures) * emgHistoryLength + 3*numel(enc)
    if isempty(this.emgFeatureHistory) || ...
            size(this.emgFeatureHistory, 1) ~= numel(emgFeatures) || ...
            size(this.emgFeatureHistory, 2) ~= emgHistoryLength
        this.emgFeatureHistory = repmat(emgFeatures(:), 1, emgHistoryLength);
    end
    deltaEnc = enc - this.prevEncoderNorm(:);
    deltaEnc = max(-1, min(1, deltaEnc));
    prevEffectiveAction = max(-1, min(1, this.prevEffectiveActionForState(:)));
    state = [reshape(this.emgFeatureHistory, [], 1); enc; deltaEnc; prevEffectiveAction];
else
    error('Unsupported stateLength=%d for calculateState', stateLength);
end

a = this.getObservationInfo;
try
    assert(all(state >= a.LowerLimit) && all(state <= a.UpperLimit), ...
        'state outside of range')
catch
    this.prosthesis.stop();
end
end
