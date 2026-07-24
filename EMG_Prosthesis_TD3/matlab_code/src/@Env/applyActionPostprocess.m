function actionOut = applyActionPostprocess(this, actionIn)
%applyActionPostprocess applies optional simulation-only action corrections.
%
% The default path returns the action unchanged. The motor2-only heuristic is
% intentionally narrow: it adjusts only action(2), so M1, M3 and M4 remain
% exactly as emitted by the loaded policy.

actionOut = max(-1, min(1, double(actionIn(:))));
variant = string(this.actionPostprocessVariant);

switch variant
    case "none"
        return
    case "motor2OnlyHeuristicCorrection"
        actionOut = localApplyMotor2OnlyHeuristic(this, actionOut);
    otherwise
        error("Unsupported actionPostprocessVariant '%s'.", variant);
end
end

function actionOut = localApplyMotor2OnlyHeuristic(this, actionOut)
if numel(actionOut) < 2 || isempty(this.flexData) || isempty(this.motorData)
    return
end

try
    target = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
    current = this.flexJoined_scaler( ...
        encoder2FlexVariant(this.motorData, configurables()));
catch
    return
end

if isempty(target) || isempty(current) || size(target, 2) < 2 || ...
        size(current, 2) < 2
    return
end

target2 = double(target(end, 2));
current2 = double(current(end, 2));
error2 = target2 - current2;

if abs(error2) < double(this.motor2OnlyCorrectionMinError)
    return
end

flatZone = current2 <= double(this.motor2OnlyCorrectionFlatUpper);
delta = double(this.motor2OnlyCorrectionGain) * error2;
delta = max(-double(this.motor2OnlyCorrectionMaxDelta), ...
    min(double(this.motor2OnlyCorrectionMaxDelta), delta));

if flatZone && abs(delta) < double(this.motor2OnlyCorrectionMinBoost)
    delta = sign(error2) * double(this.motor2OnlyCorrectionMinBoost);
end

actionOut(2) = max(-1, min(1, actionOut(2) + delta));
end
