function [flexData, finishEpisode] = encoder2FlexVariant(encoderData, configs)
%encoder2FlexVariant applies the selected encoder-to-flex conversion.
%
% The default "baseline" delegates to encoder2Flex and preserves the
% historical behavior. "motor2Calibrated" is experimental and only adjusts
% the idx/motor-2 gap/break thresholds through configurables overrides.

if nargin < 2 || isempty(configs)
    configs = configurables();
end

variant = "baseline";
if isstruct(configs) && isfield(configs, "encoder2FlexVariant")
    variant = string(configs.encoder2FlexVariant);
end

switch variant
    case "baseline"
        [flexData, finishEpisode] = encoder2Flex(encoderData);
    case "motor2Calibrated"
        [flexData, finishEpisode] = localEncoder2FlexMotor2Calibrated( ...
            encoderData, configs);
    otherwise
        error("Unsupported encoder2FlexVariant '%s'.", variant);
end
end

function [flexData, finishEpisode] = localEncoder2FlexMotor2Calibrated( ...
        encoderData, configs)
fingers = definitions("fingers");
motorIdx = definitions("motorIdx");
gap = definitions("gap");
breakLimit = definitions("breakLimit");
flexLowLim = definitions("flex_low_lim");
flexMaxLim = definitions("flex_max_lim");

gap.idx = localCalibratedGap(gap.idx, breakLimit.idx, configs);
breakLimit.idx = localCalibratedBreak(gap.idx, breakLimit.idx, configs);

finishEpisode = false;
flexData = encoderData;

for fCell = fingers
    fingerName = fCell{1};
    motor = motorIdx.(fingerName);
    x = abs(flexData(:, motor));
    xF = x;

    thisGap = gap.(fingerName);
    thisBreakLimit = breakLimit.(fingerName);
    thisFlexLow = flexLowLim.(fingerName);
    thisFlexMax = flexMaxLim.(fingerName);
    slope = (thisFlexMax - thisFlexLow) / (thisBreakLimit - thisGap);
    intercept = thisFlexMax - slope * thisBreakLimit;

    idxGap = x < thisGap;
    xF(idxGap) = thisFlexLow;

    idxLinear = x >= thisGap & x <= thisBreakLimit;
    xF(idxLinear) = slope .* x(idxLinear) + intercept;

    idxSat = x > thisBreakLimit;
    xF(idxSat) = thisFlexMax;
    finishEpisode = any(idxSat) || finishEpisode;

    flexData(:, motor) = xF;
end
end

function value = localCalibratedGap(baseGap, baseBreakLimit, configs)
offset = localConfigValue(configs, "motor2Encoder2FlexGapOffset", -64);
minEffective = localConfigValue(configs, ...
    "motor2Encoder2FlexMinEffectiveEncoder", 0);
value = baseGap + offset;
if minEffective > 0
    value = min(value, minEffective);
end
value = max(1, min(value, baseBreakLimit - 1));
end

function value = localCalibratedBreak(baseGap, baseBreakLimit, configs)
offset = localConfigValue(configs, "motor2Encoder2FlexBreakOffset", 0);
value = baseBreakLimit + offset;
value = max(baseGap + 1, value);
end

function value = localConfigValue(configs, fieldName, defaultValue)
value = defaultValue;
if isstruct(configs) && isfield(configs, fieldName) && ...
        ~isempty(configs.(fieldName))
    value = double(configs.(fieldName));
end
end
