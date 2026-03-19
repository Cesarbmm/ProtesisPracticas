function [reward, rewardVector, rewardInfo] = ...
    trackingMseProgressSmoothReward(this, action, ~)
%trackingMseProgressSmoothReward adds progress and smoothness shaping to
%the normalized tracking reward.

lambdaAction = configurables("rewardActionWeight");
lambdaProgress = configurables("rewardProgressWeight");
lambdaSmooth = configurables("rewardSmoothnessWeight");

action = double(action(:)');
target = this.flexConverted(end, :);
pred = this.adjustEnc(end, :);

err = pred - target;
trackingMse = mean(err.^2);
trackingMae = mean(abs(err));
actionL2 = mean(action.^2);

baseVector = -(err.^2 + lambdaAction * (action.^2));

if this.hasPrevRewardState
    deltaAction = action - this.prevAction(:)';
    progressTerm = lambdaProgress * (this.prevTrackingMse - trackingMse);
    smoothnessVector = lambdaSmooth * (deltaAction.^2);
    smoothnessPenalty = mean(smoothnessVector);
    deltaActionL2 = mean(deltaAction.^2);
else
    deltaAction = zeros(size(action));
    progressTerm = 0;
    smoothnessVector = zeros(size(action));
    smoothnessPenalty = 0;
    deltaActionL2 = 0;
end

rewardVector = baseVector - smoothnessVector + progressTerm;
reward = mean(rewardVector);

rewardInfo = struct(...
    "trackingMse", trackingMse, ...
    "trackingMae", trackingMae, ...
    "actionL2", actionL2, ...
    "progressTerm", progressTerm, ...
    "smoothnessPenalty", smoothnessPenalty, ...
    "deltaActionL2", deltaActionL2, ...
    "saturationFraction", mean(abs(action) >= 0.95));
end
