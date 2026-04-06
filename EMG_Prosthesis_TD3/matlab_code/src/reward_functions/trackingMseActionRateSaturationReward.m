function [reward, rewardVector, rewardInfo] = ...
    trackingMseActionRateSaturationReward(this, action, ~)
%trackingMseActionRateSaturationReward extends the current baseline reward
%with a stable saturation penalty over effective actions.

lambdaAction = configurables("rewardActionWeight");
lambdaDeltaAction = configurables("rewardDeltaActionWeight");
lambdaSat = configurables("rewardSaturationWeight");
satThreshold = configurables("rewardSaturationThreshold");

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
saturationExcess = max(0, abs(action) - satThreshold);
saturationPenaltyVector = lambdaSat * (saturationExcess.^2);

rewardVector = -( ...
    err.^2 + ...
    actionPenaltyVector + ...
    deltaActionPenaltyVector + ...
    saturationPenaltyVector);
reward = mean(rewardVector);

rewardInfo = struct( ...
    "trackingMse", trackingMse, ...
    "trackingMae", trackingMae, ...
    "actionL2", actionL2, ...
    "progressTerm", 0, ...
    "smoothnessPenalty", mean(deltaActionPenaltyVector), ...
    "deltaActionL2", deltaActionL2, ...
    "saturationFraction", mean(abs(action) >= 0.95), ...
    "saturationPenalty", mean(saturationPenaltyVector));
end
