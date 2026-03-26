function diagnostics = reconstructResidualPolicyDiagnostics(stateLog, actionLog, td3Residual)
%reconstructResidualPolicyDiagnostics rebuilds residual-control diagnostics.
%
% The environment only sees the final action emitted by the residual actor.
% To understand how much the learnable branch is changing Agent7250, this
% helper replays the frozen base actor on the saved state trajectory and
% decomposes final action = base action + residual correction.

arguments
    stateLog double
    actionLog double
    td3Residual struct
end

diagnostics = struct();
if isempty(stateLog) || isempty(actionLog)
    return;
end

if ~isfield(td3Residual, "baseCheckpointPath") || ...
        strlength(string(td3Residual.baseCheckpointPath)) == 0
    return;
end

[baseActor, residualScale] = getCachedBaseActor(td3Residual);

numSteps = size(actionLog, 1);
numActions = size(actionLog, 2);
baseActionLog = nan(numSteps, numActions);
validRows = all(~isnan(stateLog), 2) & all(~isnan(actionLog), 2);

validIdx = find(validRows);
for i = 1:numel(validIdx)
    rowIdx = validIdx(i);
    obs = double(stateLog(rowIdx, :)).';
    actorAction = getAction(baseActor, {obs});
    baseActionLog(rowIdx, :) = reshape(double(actorAction{1}), 1, []);
end

residualActionLog = actionLog - baseActionLog;
validResidualMask = ~isnan(residualActionLog) & ~isnan(baseActionLog);
if ~any(validResidualMask, "all")
    diagnostics.baseActionLog = baseActionLog;
    diagnostics.residualActionLog = residualActionLog;
    return;
end

residualThreshold = 0.8 * residualScale;
if residualThreshold <= 0
    residualThreshold = 0.8;
end

residualActionL2PerStep = sum(residualActionLog.^2, 2, "omitnan");
signOverrideMask = abs(baseActionLog) > 1e-6 & abs(actionLog) > 1e-6 & ...
    sign(baseActionLog) ~= sign(actionLog);

diagnostics.baseActionLog = baseActionLog;
diagnostics.residualActionLog = residualActionLog;
diagnostics.residualActionL2Mean = mean(residualActionL2PerStep, "omitnan");
diagnostics.residualFractionNearCap = mean(abs(residualActionLog(validResidualMask)) >= residualThreshold, "omitnan");
diagnostics.baseToFinalActionDeltaMean = mean(abs(residualActionLog(validResidualMask)), "omitnan");
diagnostics.signOverrideFraction = mean(signOverrideMask(validResidualMask), "omitnan");
diagnostics.residualByMotorMean = mean(abs(residualActionLog), 1, "omitnan");
diagnostics.baseActionL2Mean = mean(sum(baseActionLog.^2, 2, "omitnan"), "omitnan");
end

function [baseActor, residualScale] = getCachedBaseActor(td3Residual)
persistent cachedPath cachedActor cachedResidualScale

checkpointPath = string(td3Residual.baseCheckpointPath);
residualScale = 0.20;
if isfield(td3Residual, "residualScale")
    residualScale = double(td3Residual.residualScale);
end

if ~isempty(cachedActor) && strlength(cachedPath) > 0 && cachedPath == checkpointPath
    baseActor = cachedActor;
    cachedResidualScale = residualScale;
    return;
end

baseAgent = loadSavedAgent(checkpointPath);
baseActor = getActor(baseAgent);
cachedPath = checkpointPath;
cachedActor = baseActor;
cachedResidualScale = residualScale;
end
