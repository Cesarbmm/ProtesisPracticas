%% Calculates the reward based on the motor previous state and
%---- definitions
% when it wants to go forward, trying to break the finger
rewards.breaking = -2;
% when it is relaxed but wants to move in reverse direction
rewards.dirInverse = -2;
% when it is in climbable state but it moves in the wrong dir
rewards.wrongMove = -1;

rewards.goodMove = 2; % previously 1

%---- definitions
% flexing pos
if this.c == 1
    flexConv = reduceFlexDimension(this.paramsDecodeFlex, ...
        this.flexData);
else
    flexConv = this.flexConvertedLog{this.c - 1};
end
pos = this.motorData(end, :);

%---gap and limit
belowGap = pos < this.gapValues;
aboveLimit = pos > this.limitValues;

%------ saturating action and calculating reward
rewardVector = zeros(1, 4);

%-- when too far away
idxBreak = aboveLimit & (action >= 1);
rewardVector(idxBreak) = rewards.breaking;
action(idxBreak) = 0; %& removing stoping

%-- when inverse direction
idxInvDir = belowGap & (action <= -1);
rewardVector(idxInvDir) = rewards.dirInverse;
action(idxInvDir) = 0; %& removing stoping

%----- not changing action space
idxCalculate = ~idxInvDir & ~idxBreak;

%---- loop by motor
for i = find(idxCalculate)
    f = this.fingers{i};
    climbable = false;
    if flexConv(end, i) < this.flexsLimit.(f)(1)
        % is relaxed
        correctAction = 0;
    elseif flexConv(end, i) > this.flexsLimit.(f)(2)
        % is closed hand
        correctAction = 0;
    else
        % climbable
        climbable = true;
        if this.episodeType
            % hand open->training to gesture close
            correctAction = 1;
        else
            % closed->training gesture open
            correctAction = -1;
        end
    end
    
    if action(i) == correctAction
        rewardVector(i) = rewards.goodMove;
    else % all are wrong
        if climbable % zone to move!
            % Reward detailed implementation
            switch abs(correctAction - action(i))
                case 2
                    % very wrong!
                    rewardVector(i) = rewards.dirInverse;
                case 1 % stop instead of moving
                    rewardVector(i) = rewards.wrongMove;
                case 0 % unreachable
                    rewardVector(i) = rewards.goodMove;
                    assert(false, 'should not be here')
                otherwise
                    error('something wrong calculating reward')
            end
            
        else
            % the very wrong cases where already handled
            rewardVector(i) = rewards.wrongMove;
        end
    end
end
fprintf('%rs=[%2d %2d %2d %2d]\n', rewardVector);
reward = sum(rewardVector);