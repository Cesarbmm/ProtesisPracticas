% al negative distances.


%----- defs and configs
% the distance is reduced by this factor. Thumb has only 1 sensor.
% mult by 2 for goodMove adjustment.
opts.distanceConversion = [2 2 1 2]/1100 * 2;

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
action(idxBreak) = 0; %& removing stoping

%-- when inverse direction
idxInvDir = belowGap & (action <= -1);
action(idxInvDir) = 0; %& removing stoping

%-- Added. calculing penalty with distance
distance = abs( posFlex - flexConv(end, :) );

rewardVector = - distance.*opts.distanceConversion;

reward = sum(rewardVector);