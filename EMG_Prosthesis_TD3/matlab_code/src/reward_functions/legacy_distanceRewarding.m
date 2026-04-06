function [reward, rewardVector, action] = legacy_distanceRewarding(this, action)

persistent previousPosFlex

if isempty(previousPosFlex)
    previousPosFlex = zeros(size(action)); % Initialize posFlex registration
end

%% same action coarcing with reward reduction by distance.
%----- defs and configs
% the distance is multiplied by this factor.

opts.k = 25; % factor that balance between distance and action.
% when it wants to go to the very other direction
rewards.dirInverse = -1;
% 1) when it is in a climbable state but it wants to stop
% 2) must stop but moves in the correct direction
rewards.wrongStop = -1;

rewards.goodMove = 1;

rewards.goodMove2 = 1;

rewards.inactivityPenalty = -1;

rewards.moveIncentive = 2;

rewardVector = zeros(1, 4);

%% -- reading
% flexing pos
if this.c == 1
    flexConv = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
else
    flexConv = this.flexConvertedLog{this.c - 1};
end
pos = this.motorData(end, :);
posFlex = this.flexJoined_scaler(encoder2Flex(pos));

%%- loop by motor
for i = 1:length(action)

    %- getting correct
    if  previousPosFlex(i) < posFlex(i)
        % goal is in front, should go forward
        correctAction = 1;
    elseif previousPosFlex(i) > posFlex(i)
        correctAction = -1;
    else
        correctAction = 0;
    end

    %- rewarding
    if action(i) == correctAction
        if action(i) ~= 0
            rewardVector(i) = rewards.goodMove;
        else
            rewardVector(i) = rewards.goodMove2;
        end
    elseif action(i) == 0
        rewardVector(i) = rewards.wrongStop;
    else
        rewardVector(i) = rewards.dirInverse;
    end
end

% Update posFlex record
previousPosFlex = posFlex;

% Encourage movement if there is any action
if any(action ~= 0)
    rewardVector = rewardVector + rewards.moveIncentive;
end

%-- Added. calculating penalty with distance
distance = abs(posFlex - flexConv(end, :));
rewardVector = rewardVector - distance.*opts.k;


% Average all rewards and penalties
reward = mean(rewardVector);

end
