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
emgFeatures = emgFeatures(:);
if numel(emgFeatures) ~= this.numEMGFeatures || ...
        ~isreal(emgFeatures) || any(~isfinite(emgFeatures))
    error("Env:InvalidEmgFeatures", ...
        "Feature calculator must return %d finite real values.", ...
        this.numEMGFeatures);
end

enc = this.encoderNormCalculator(motorData(end, :)');
enc = enc(:);
numMotors = numel(enc);
layout = buildObservationLayout(this.observationVariant, ...
    this.numEMGFeatures, this.emgHistoryLength, numMotors);
if layout.totalLength ~= this.stateLength
    error("Env:StateLayoutMismatch", ...
        "Configured stateLength=%d but %s requires %d.", ...
        this.stateLength, this.observationVariant, layout.totalLength);
end

deltaEnc = enc - this.prevEncoderNorm(:);
deltaEnc = max(-1, min(1, deltaEnc));
prevEffectiveAction = max(-1, ...
    min(1, this.prevEffectiveActionForState(:)));

switch this.observationVariant
    case "legacy44"
        state = [emgFeatures; enc];

    case "markov52"
        state = [emgFeatures; enc; deltaEnc; prevEffectiveAction];

    case "stackedEmg132"
        if isempty(this.emgFeatureHistory) || ...
                size(this.emgFeatureHistory, 1) ~= numel(emgFeatures) || ...
                size(this.emgFeatureHistory, 2) ~= this.emgHistoryLength
            this.emgFeatureHistory = repmat( ...
                emgFeatures, 1, this.emgHistoryLength);
        end
        state = [reshape(this.emgFeatureHistory, [], 1); ...
            enc; deltaEnc; prevEffectiveAction];

    case "intentMarkov60"
        referencePosition = this.intentTarget(:);
        referenceVelocity = this.intentVelocity(:);
        if numel(referencePosition) ~= numMotors || ...
                numel(referenceVelocity) ~= numMotors || ...
                any(~isfinite(referencePosition)) || ...
                any(~isfinite(referenceVelocity))
            error("Env:InvalidIntentState", ...
                "q_ref and v_ref must be finite four-vectors.");
        end
        state = [emgFeatures; enc; deltaEnc; prevEffectiveAction; ...
            referencePosition; referenceVelocity];

    otherwise
        error("Env:UnsupportedObservationVariant", ...
            "Unsupported observationVariant '%s'.", this.observationVariant);
end

if numel(state) ~= this.stateLength
    error("Env:StateDimensionMismatch", ...
        "Calculated %d state values; expected %d.", ...
        numel(state), this.stateLength);
end
if ~isreal(state) || any(~isfinite(state))
    error("Env:NonfiniteState", ...
        "Observation must contain finite real values.");
end

a = this.getObservationInfo;
if any(state < a.LowerLimit) || any(state > a.UpperLimit)
    this.prosthesis.stop();
    error("Env:StateOutsideBounds", ...
        "Observation lies outside the declared numeric specification.");
end
end
