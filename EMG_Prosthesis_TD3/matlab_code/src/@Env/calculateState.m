function state = calculateState(this, emg, motorData)
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

state = [emg; enc];

a = this.getObservationInfo;
try
    assert(all(state > a.LowerLimit) && all(state < a.UpperLimit), ...
        'state outside of range')
catch
    this.prosthesis.stop();
end
end
