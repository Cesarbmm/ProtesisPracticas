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
emg = this.featureCalculator(emg); % E-by-8 -> F-by-1

enc = this.encoderNormCalculator(motorData(end, :)');
stateLength = configurables("stateLength");

if stateLength == numel(emg) + numel(enc)
    state = [emg; enc];
elseif stateLength == numel(emg) + 3*numel(enc)
    deltaEnc = enc - this.prevEncoderNorm(:);
    deltaEnc = max(-1, min(1, deltaEnc));
    prevEffectiveAction = max(-1, min(1, this.prevEffectiveActionForState(:)));
    state = [emg; enc; deltaEnc; prevEffectiveAction];
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
