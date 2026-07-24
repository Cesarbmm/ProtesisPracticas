function [reward, rewardVector, rewardInfo] = ...
    trackingMseActionRateMotorWeightedReward(this, action, ~)
%trackingMseActionRateMotorWeightedReward weights tracking error by motor.
%
% Experimental reward for motor-2 diagnostics. It does not replace the
% official trackingMseActionRateReward default.

lambdaAction = configurables("rewardActionWeight");
lambdaDeltaAction = configurables("rewardDeltaActionWeight");
motorWeights = localRowVector(configurables("rewardMotorWeights"), [1 2 1 1]);
actionMotorWeights = localRowVector(configurables("rewardActionMotorWeights"), ones(1, 4));
deltaActionMotorWeights = localRowVector(configurables("rewardDeltaActionMotorWeights"), ones(1, 4));

action = double(action(:)');
target = this.flexConverted(end, :);
pred = this.adjustEnc(end, :);

err = pred - target;
trackingMseByMotor = err.^2;
trackingMse = mean(trackingMseByMotor);
trackingMaeByMotor = abs(err);
trackingMae = mean(trackingMaeByMotor);
actionL2 = mean(action.^2);

prevAction = double(this.prevAction(:)');
deltaAction = action - prevAction;
deltaActionL2 = mean(deltaAction.^2);

trackingPenaltyVector = motorWeights .* trackingMseByMotor;
actionPenaltyVector = lambdaAction * actionMotorWeights .* (action.^2);
deltaActionPenaltyVector = lambdaDeltaAction * deltaActionMotorWeights .* (deltaAction.^2);

rewardVector = -(trackingPenaltyVector + actionPenaltyVector + deltaActionPenaltyVector);
reward = mean(rewardVector);

rewardInfo = struct( ...
    "trackingMse", trackingMse, ...
    "trackingMae", trackingMae, ...
    "actionL2", actionL2, ...
    "progressTerm", 0, ...
    "smoothnessPenalty", mean(deltaActionPenaltyVector), ...
    "deltaActionL2", deltaActionL2, ...
    "saturationFraction", mean(abs(action) >= 0.95), ...
    "saturationPenalty", 0, ...
    "trackingMseByMotor", trackingMseByMotor, ...
    "trackingMaeByMotor", trackingMaeByMotor, ...
    "rewardVectorByMotor", rewardVector, ...
    "motorWeights", motorWeights, ...
    "actionMotorWeights", actionMotorWeights, ...
    "deltaActionMotorWeights", deltaActionMotorWeights);
end

function value = localRowVector(value, defaultValue)
if isempty(value)
    value = defaultValue;
end
value = double(value(:)');
if numel(value) ~= 4
    error("Motor weight vectors must contain four values.");
end
end
