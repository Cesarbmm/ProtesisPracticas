function [reward, rewardVector, rewardInfo] = ...
    trackingIntentHoldActionReward(env, action, rewardContext)
%trackingIntentHoldActionReward adds causal effort during at-target hold.
%
% The hold indicator uses q, q_ref and v_ref that were visible when action_t
% was selected. In Env.step, decisionPositionPrediction is q from state_t;
% trackingPrediction may already contain the result of applying action_t.

requiredFields = ["decisionPositionPrediction", "trackingTarget", ...
    "trackingVelocityTarget", "referenceSource"];
if ~isstruct(rewardContext) || ~isscalar(rewardContext) || ...
        ~all(isfield(rewardContext, requiredFields))
    error("trackingIntentHoldActionReward:InvalidContext", ...
        "The causal hold reward context is incomplete.");
end
referenceSource = string(rewardContext.referenceSource);
if ~isscalar(referenceSource) || ismissing(referenceSource) || ...
        referenceSource ~= "emgIntent"
    error("trackingIntentHoldActionReward:InvalidReferenceSource", ...
        "trackingIntentHoldActionReward is restricted to emgIntent.");
end

decisionPosition = validateFourVector( ...
    rewardContext.decisionPositionPrediction, ...
    "decisionPositionPrediction");
positionTarget = validateFourVector( ...
    rewardContext.trackingTarget, "trackingTarget");
velocityTarget = validateFourVector( ...
    rewardContext.trackingVelocityTarget, "trackingVelocityTarget");
action = validateFourVector(action, "action");

[~, rewardVector, rewardInfo] = ...
    trackingIntentActionRateReward(env, action, rewardContext);

wHold = configurables("intentHoldActionWeight");
velocityTolerance = configurables("intentHoldVelocityTolerance");
positionMseTolerance = configurables( ...
    "intentHoldPositionMseTolerance");
decisionPositionError = decisionPosition-positionTarget;
holdVelocityMaxAbs = max(abs(velocityTarget));
holdPositionMse = mean(decisionPositionError.^2);
holdActive = holdVelocityMaxAbs <= velocityTolerance && ...
    holdPositionMse <= positionMseTolerance;
holdActionVector = double(holdActive).*action.^2;
holdPenaltyVector = wHold.*holdActionVector;

rewardVector = rewardVector-holdPenaltyVector;
reward = mean(rewardVector);
rewardInfo.holdActive = double(holdActive);
rewardInfo.holdVelocityMaxAbs = holdVelocityMaxAbs;
rewardInfo.holdPositionMse = holdPositionMse;
rewardInfo.holdActionL2 = mean(holdActionVector);
rewardInfo.holdActionPenalty = mean(holdPenaltyVector);
end

function value = validateFourVector(value, fieldName)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 4 || ...
        any(~isfinite(value), "all")
    error("trackingIntentHoldActionReward:InvalidVector", ...
        "%s must be a finite real numeric four-vector.", fieldName);
end
value = double(value(:)');
end
