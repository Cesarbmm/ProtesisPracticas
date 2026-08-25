function advanceIntentReference(this, emg)
%advanceIntentReference builds the next causal reference from the new EMG.
%
% This method is called only after reward_t has been evaluated against the
% q_ref/v_ref stored in state_t. Therefore EMG read during transition t is
% visible in state_(t+1), never retroactively in reward_t.

if this.referenceSource ~= "emgIntent" || ~this.intentDecoderEnabled
    return;
end

[desiredVelocity, ~, nextGateState, decoderDetails] = ...
    mapEmgToIntentVelocity(emg, this.intentCalibration, ...
    this.intentExpectedContext, this.intentGateState);
if size(desiredVelocity, 1) ~= 1 || ...
        decoderDetails.discardedSampleCount ~= 0
    error("Env:IntentWindowAlignment", ...
        ["Each environment transition must provide exactly one complete " ...
        "causal raw-EMG window."]);
end

[referencePosition, referenceVelocity] = updateIntentReference( ...
    this.intentTarget(:)', desiredVelocity, this.intentCalibration, ...
    decoderDetails.isRest, this.intentVelocity(:)');

this.intentTarget = referencePosition(end, :)';
this.intentVelocity = referenceVelocity(end, :)';
this.intentGateState = nextGateState;
this.referenceTarget = this.intentTarget;
end
