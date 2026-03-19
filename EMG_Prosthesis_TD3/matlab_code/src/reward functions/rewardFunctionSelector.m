function [reward, rewardVector, rewardInfo] = rewardFunctionSelector(this, rewardType, ...
    action, user_data)
%rewardFunctionSelector() is a switch function that calculates the reward
%on each step of the episode. The reward function does not modify the
%action anymore.
%
% Inputs
%   rewardType      char that switches the different reward functions
%                   configured. More info in each switch case.
%   action         vector, in case of using a preexecution reward
%                   calculation.
%   user_data       uise it to pass data between step and reward.
%
% Outputs
%   reward          double
%   action         vector, in case of modfiying action.
%
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: z_tja
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

20 February 2022
Matlab 9.11.0.1837725 (R2021b) Update 2.
%}

%%
switch rewardType
    case 'trackingMseActionRateReward'
        [reward, rewardVector, rewardInfo] = ...
            trackingMseActionRateReward(this, action, user_data);
        return;

    case 'trackingMseProgressSmoothReward'
        [reward, rewardVector, rewardInfo] = ...
            trackingMseProgressSmoothReward(this, action, user_data);
        return;

    case 'trackingMseActionReward'
        [reward, rewardVector, rewardInfo] = ...
            trackingMseActionReward(this, action, user_data);
        return;

    case 'legacy_distanceRewarding'
        [reward, rewardVector] = legacy_distanceRewarding(this, action);
        rewardInfo = buildRewardInfo(this, action);
        return;

        % case 'pureDistanceRewarding'
        %     return;

        % case 'discreteDirectionalRewarding'
        %     return; % to clarify

        % case 'flexionZoning'
        %     return;

    otherwise
        error('Reward type %s unrecognized', rewardType)
end
end

function rewardInfo = buildRewardInfo(this, action)
action = double(action(:)');
rewardInfo = struct(...
    "trackingMse", NaN, ...
    "trackingMae", NaN, ...
    "actionL2", mean(action.^2), ...
    "progressTerm", 0, ...
    "smoothnessPenalty", 0, ...
    "deltaActionL2", 0, ...
    "saturationFraction", mean(abs(action) >= 0.95));

if isempty(this.flexConverted) || isempty(this.adjustEnc)
    return;
end

target = this.flexConverted(end, :);
pred = this.adjustEnc(end, :);
err = pred - target;

rewardInfo.trackingMse = mean(err.^2);
rewardInfo.trackingMae = mean(abs(err));
end
