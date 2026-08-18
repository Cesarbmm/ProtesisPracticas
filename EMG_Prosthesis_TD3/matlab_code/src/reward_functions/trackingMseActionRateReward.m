function [reward, rewardVector, rewardInfo] = ...
    trackingMseActionRateReward(this, action, rewardContext)
%trackingMseActionRateReward penalizes normalized tracking error, action
%magnitude and action rate using only information observable to the agent.

lambdaAction = configurables("rewardActionWeight");
lambdaDeltaAction = configurables("rewardDeltaActionWeight");

action = double(action(:)');
if isempty(rewardContext)
    % Historical glove path. Keep these inputs and arithmetic unchanged.
    target = this.flexConverted(end, :);
    pred = this.adjustEnc(end, :);
else
    requiredFields = ["trackingTarget", "trackingPrediction", "referenceSource"];
    if ~isstruct(rewardContext) || ~isscalar(rewardContext) || ...
            ~all(isfield(rewardContext, requiredFields))
        error("trackingMseActionRateReward:InvalidContext", ...
            "EMG-intent reward context is incomplete.");
    end
    if string(rewardContext.referenceSource) ~= "emgIntent"
        error("trackingMseActionRateReward:InvalidReferenceSource", ...
            "Nonempty reward context is reserved for emgIntent.");
    end
    target = double(rewardContext.trackingTarget(:)');
    pred = double(rewardContext.trackingPrediction(:)');
    if numel(target) ~= 4 || numel(pred) ~= 4 || ...
            any(~isfinite(target)) || any(~isfinite(pred))
        error("trackingMseActionRateReward:InvalidTrackingData", ...
            "Tracking target and prediction must be finite four-vectors.");
    end
end

err = pred - target;
trackingMse = mean(err.^2);
trackingMae = mean(abs(err));
actionL2 = mean(action.^2);

prevAction = double(this.prevAction(:)');
deltaAction = action - prevAction;
deltaActionL2 = mean(deltaAction.^2);

actionPenaltyVector = lambdaAction * (action.^2);
deltaActionPenaltyVector = lambdaDeltaAction * (deltaAction.^2);

rewardVector = -(err.^2 + actionPenaltyVector + deltaActionPenaltyVector);
reward = mean(rewardVector);

rewardInfo = struct(...
    "trackingMse", trackingMse, ...
    "trackingMae", trackingMae, ...
    "actionL2", actionL2, ...
    "progressTerm", 0, ...
    "smoothnessPenalty", mean(deltaActionPenaltyVector), ...
    "deltaActionL2", deltaActionL2, ...
    "saturationFraction", mean(abs(action) >= 0.95), ...
    "saturationPenalty", 0);
end
