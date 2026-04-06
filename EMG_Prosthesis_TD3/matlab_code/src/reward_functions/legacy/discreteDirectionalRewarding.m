%%
%----- defs and configs
opts.regionStop = 200; % inside 200 flex points it does not move.
% when it wants to go in the breaking dir,
rewards.breaking = -3;

% when it want to go to the very other dir
rewards.dirInverse = -2;

% 1) when it is in climbable state but it wants to stop
% 2) must be stop but moves in the correct direction
rewards.wrongStop = -1;

%
rewards.goodMove = 2;

rewardVector = zeros(1, 4);

%-- reading
% flexing pos
if this.c == 1
    flexConv = reduceFlexDimension(this.paramsDecodeFlex, ...
        this.flexData);
else
    flexConv = this.flexConvertedLog{this.c - 1};
end
pos = this.motorData(end, :);
posFlex = encoder2Flex(this.paramsDecodeFlex, pos);

%----- avoiding breaking moves
%gap and limit
belowGap = pos < this.gapValues;
aboveLimit = pos > this.limitValues;

%- when too far away
idxBreak = aboveLimit & (action >= 1);
rewardVector(idxBreak) = rewards.breaking;
action(idxBreak) = 0; %& removing stoping

%-- when inverse direction
idxInvDir = belowGap & (action <= -1);
rewardVector(idxInvDir) = rewards.dirInverse;
action(idxInvDir) = 0; %& removing stoping

%----- not changing action space
idxCalculate = ~idxInvDir & ~idxBreak;

%- loop by motor
for i = find(idxCalculate)
    if abs( posFlex(i) - flexConv(end, i) ) > opts.regionStop
        %--- should move
        
        %- getting correct
        if posFlex(i) < flexConv(end, i)
            % goal is infront, should go forward
            correctAction = 1;
        else
            correctAction = -1;
        end
        
        %- rewarding
        if action(i) == correctAction
            rewardVector(i) = rewards.goodMove;
        elseif action(i) == 0
            rewardVector(i) = rewards.wrongStop;
        else
            rewardVector(i) = rewards.dirInverse;
        end
        
    else
        %--- should be quiet
        
        %- getting correct
        correctAction = 0;
        
        
        %- rewarding
        if action(i) == correctAction
            rewardVector(i) = rewards.goodMove;
        else
            rewardVector(i) = rewards.wrongStop;
        end
    end
end

fprintf('%rs=[%2d %2d %2d %2d]\n', rewardVector);
reward = sum(rewardVector);