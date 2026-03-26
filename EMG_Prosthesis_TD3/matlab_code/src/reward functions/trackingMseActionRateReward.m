function [reward, rewardVector, rewardInfo] = ...
    trackingMseActionRateReward(this, action, ~)
%trackingMseActionRateReward penalizes normalized tracking error, action
%magnitude and action rate using only information observable to the agent.

lambdaAction = configurables("rewardActionWeight");
lambdaDeltaAction = configurables("rewardDeltaActionWeight");

action = double(action(:)');
target = this.flexConverted(end, :);
pred = this.adjustEnc(end, :);

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
