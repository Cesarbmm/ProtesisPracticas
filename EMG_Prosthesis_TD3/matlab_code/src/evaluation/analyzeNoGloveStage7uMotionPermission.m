function analysis = analyzeNoGloveStage7uMotionPermission(data, options)
%analyzeNoGloveStage7uMotionPermission counterfactual audit of a
%motionPermission gate inserted between u_actor_raw and quantization.
%
% Binary per-step gating (permission in {0,1}) commutes exactly with warp
% and quantization at permission=0 (any deadzone/warp maps 0 to 0, and
% |0|<activationThreshold) and is a no-op at permission=1. So the gated
% effective action/PWM is recovered exactly from already-logged values
% without recomputing quantization or re-running the simulator:
%   effectiveGated = permission .* effectiveBaseline
%   pwmGated       = permission .* pwmBaseline
% u_actor_raw is reported unchanged in both conditions - this analysis never
% claims the actor itself improved.

arguments
    data (1, 1) struct
    options.saturationThreshold (1, 1) double ...
        {mustBeInRange(options.saturationThreshold, 0, 1)} = 0.95
end

required = ["restEvidence", "restGateActive", "acceptanceEpisodes", ...
    "actorLoaded", "environmentUsed", "simulationUsed", "trainingUsed"];
if ~all(isfield(data, cellstr(required))) || data.actorLoaded || ...
        data.environmentUsed || data.simulationUsed || data.trainingUsed
    error("analyzeNoGloveStage7uMotionPermission:InvalidEvidence", ...
        "A validated, actor-free, simulation-free ETAPA 7U input is required.");
end

%% Rest cohort (primary, exact)
corpus = data.restEvidence.corpus;
restRows = find(corpus.metadata.source == "steadyRest");
[~, order] = sort(corpus.metadata.episode(restRows)*100 + ...
    corpus.metadata.step(restRows));
restRows = restRows(order);

gateActiveByRow = vertcat(data.restGateActive{:});
if numel(gateActiveByRow) ~= numel(restRows)
    error("analyzeNoGloveStage7uMotionPermission:RestGateLength", ...
        "Rest gateActive log does not match the rest cohort row count.");
end
restGateActiveAllFalse = ~any(gateActiveByRow);

n = numel(restRows);
episode = repelem(corpus.metadata.episode(restRows), 4, 1);
step = repelem(corpus.metadata.step(restRows), 4, 1);
motor = repmat((1:4)', n, 1);
phase = repmat("postFirst", 4*n, 1);
phase(step == 1) = "firstStep";
permission = repelem(double(gateActiveByRow(:)), 4, 1);
stateRowRepeated = repelem(restRows, 4, 1);
linear = sub2ind(size(corpus.rawAction), stateRowRepeated, motor);
rawAction = corpus.rawAction(linear);
effectiveBaseline = corpus.effectiveAction(linear);
pwmBaseline = corpus.pwm(linear);
safetyBaseline = corpus.safetyIntervention(linear);
% Ground-truth causal previous effective action, from the state's own
% dims 49:52 (intentMarkov60 layout), not a positional shift that would
% blur across episode boundaries.
prevEffectiveLinear = sub2ind(size(corpus.states), stateRowRepeated, 48 + motor);
prevEffectiveBaseline = corpus.states(prevEffectiveLinear);
effectiveGated = permission .* effectiveBaseline;
pwmGated = permission .* pwmBaseline;
% Zero PWM for an entire rest episode leaves the plant at its certified
% firstStep endpoint the whole time (ETAPA 7T amendment 2): the trajectory
% never approaches positionMin/positionMax, so limitSimulationPosition
% cannot intervene. This is a structural consequence of permission=0
% throughout, not a re-simulation.
safetyGated = zeros(size(safetyBaseline));
if ~restGateActiveAllFalse
    % Fail closed rather than silently relying on the structural argument
    % above if the ETAPA 7S design assumption (activity always < thetaOn)
    % turns out not to hold on this corpus.
    safetyGated = nan(size(safetyBaseline));
end

% Under gating, permission=0 for the entire rest cohort (verified above),
% so nothing is ever applied and the gated previous-effective-action is
% exactly zero at every step - not a positional shift, a direct consequence
% of u_requested=0 throughout.
prevEffectiveGated = zeros(size(prevEffectiveBaseline));

restTable = table(episode, step, motor, phase, rawAction, permission, ...
    effectiveBaseline, pwmBaseline, safetyBaseline, prevEffectiveBaseline, ...
    effectiveGated, pwmGated, safetyGated, prevEffectiveGated, ...
    'VariableNames', ["episode", "step", "motor", "phase", "rawAction", ...
    "permission", "effectiveBaseline", "pwmBaseline", "safetyBaseline", ...
    "prevEffectiveBaseline", "effectiveGated", "pwmGated", "safetyGated", ...
    "prevEffectiveGated"]);

restSummary = summarizeRest(restTable, options.saturationThreshold);

%% Acceptance/movement cohort (structural false-inhibition proof +
%% descriptive rest-phase-within-episode suppression)
episodes = data.acceptanceEpisodes;
violationRows = repmat(emptyViolationRow(), 0, 1);
descriptiveParts = cell(max(1, numel(episodes)), 1);
descriptiveParts{1} = emptyAcceptanceStepTable();
totalSteps = 0;
totalActiveSteps = 0;
totalFalseInhibitionSteps = 0;

for idx = 1:numel(episodes)
    ep = episodes(idx);
    totalSteps = totalSteps + ep.stepCount;
    totalActiveSteps = totalActiveSteps + sum(ep.gateActive);
    for t = 2:ep.stepCount
        if ~ep.gateActive(t)
            referenceUnchanged = isequal( ...
                ep.referenceHistory(t, :), ep.referenceHistory(t-1, :));
            if ~referenceUnchanged
                totalFalseInhibitionSteps = totalFalseInhibitionSteps + 1;
                violationRows(end+1, 1) = struct( ... %#ok<AGROW>
                    "episode", ep.episode, "step", t, ...
                    "referenceDelta", max(abs(ep.referenceHistory(t, :) - ...
                    ep.referenceHistory(t-1, :))));
            end
        end
    end

    restPhaseRows = ~ep.gateActive;
    permissionCol = double(ep.gateActive(:));
    effectiveGatedEp = permissionCol .* ep.effectiveAction;
    pwmGatedEp = permissionCol .* ep.pwm;
    descriptiveParts{idx} = table( ...
        repmat(ep.episode, ep.stepCount, 1), (1:ep.stepCount)', ...
        ep.gateActive(:), ...
        mean(abs(ep.rawAction), 2), mean(abs(ep.effectiveAction), 2), ...
        mean(abs(ep.pwm), 2), mean(abs(effectiveGatedEp), 2), ...
        mean(abs(pwmGatedEp), 2), ep.trackingMse, ...
        'VariableNames', ["episode", "step", "gateActive", ...
        "meanAbsRawAction", "meanAbsEffectiveBaseline", ...
        "meanAbsPwmBaseline", "meanAbsEffectiveGated", ...
        "meanAbsPwmGated", "trackingMse"]);
end
acceptanceStepTable = vertcat(descriptiveParts{:});
falseInhibitionViolations = struct2table(violationRows);

restPhaseRows = acceptanceStepTable.gateActive == false;
acceptanceRestPhaseDescriptive = struct( ...
    "restPhaseStepCount", sum(restPhaseRows), ...
    "restPhaseNonzeroPwmFractionBaseline", ...
        safeMean(acceptanceStepTable.meanAbsPwmBaseline(restPhaseRows) > 0), ...
    "restPhaseMeanAbsPwmBaseline", ...
        safeMean(acceptanceStepTable.meanAbsPwmBaseline(restPhaseRows)), ...
    "restPhaseMeanAbsPwmGated", ...
        safeMean(acceptanceStepTable.meanAbsPwmGated(restPhaseRows)), ...
    "downstreamTrackingMseNotRecomputed", true);

acceptanceSummary = struct( ...
    "episodeCount", numel(episodes), ...
    "totalSteps", totalSteps, ...
    "activeStepFraction", totalActiveSteps / max(1, totalSteps), ...
    "falseInhibitionStepCount", totalFalseInhibitionSteps, ...
    "falseInhibitionFraction", totalFalseInhibitionSteps / max(1, totalSteps), ...
    "falseInhibitionExactlyZero", totalFalseInhibitionSteps == 0, ...
    "activeWindowMetricsUnchangedByConstruction", true, ...
    "restPhaseDescriptive", acceptanceRestPhaseDescriptive);

%% Overall verdict
improvementValidated = "NO";
if restGateActiveAllFalse && restSummary.gated.restPWMNonZeroFraction == 0 && ...
        restSummary.gated.firstStepUnsolicitedPWMFraction == 0
    if acceptanceSummary.falseInhibitionExactlyZero
        improvementValidated = "YES";
    else
        improvementValidated = "PARTIAL";
    end
end

analysis = struct( ...
    "schemaVersion", 1, "stage", "7U", ...
    "restGateActiveAllFalse", restGateActiveAllFalse, ...
    "restTable", restTable, "restSummary", restSummary, ...
    "acceptanceStepTable", acceptanceStepTable, ...
    "acceptanceSummary", acceptanceSummary, ...
    "falseInhibitionViolations", falseInhibitionViolations, ...
    "improvementValidated", improvementValidated, ...
    "actorLoaded", false, "actorRetrained", false, ...
    "environmentUsed", false, "simulationUsed", false, ...
    "trainingUsed", false, "quantizationRecomputed", false, ...
    "safetyRecomputed", false, "rewardChanged", false, ...
    "gateChanged", false, "stateChanged", false, "datasetChanged", false);
end

function summary = summarizeRest(restTable, saturationThreshold)
baseline = perConditionSummary(restTable, "Baseline", saturationThreshold);
gated = perConditionSummary(restTable, "Gated", saturationThreshold);
first = restTable.phase == "firstStep";
summary = struct( ...
    "baseline", baseline, "gated", gated, ...
    "firstStepUnsolicitedPwmFractionBaselineByMotor", ...
        motorFraction(restTable(first, :), "pwmBaseline"), ...
    "firstStepUnsolicitedPwmFractionGatedByMotor", ...
        motorFraction(restTable(first, :), "pwmGated"));
end

function s = perConditionSummary(restTable, suffix, saturationThreshold)
effectiveCol = "effective" + suffix;
pwmCol = "pwm" + suffix;
safetyCol = "safety" + suffix;
prevCol = "prevEffective" + suffix;
effective = restTable.(effectiveCol);
pwm = restTable.(pwmCol);
safety = restTable.(safetyCol);
prevEffective = restTable.(prevCol);
first = restTable.phase == "firstStep";
s = struct( ...
    "restPWMNonZeroFraction", mean(pwm ~= 0), ...
    "firstStepUnsolicitedPWMFraction", mean(pwm(first) ~= 0), ...
    "actionL2Raw", mean(restTable.rawAction.^2), ...
    "actionL2Effective", mean(effective.^2), ...
    "deltaActionL2Effective", mean((effective - prevEffective).^2), ...
    "saturationFraction", mean(abs(effective) >= saturationThreshold), ...
    "safetyInterventionCount", sum(safety, "omitnan"), ...
    "safetyInterventionFraction", mean(safety > 0));
end

function fractions = motorFraction(restTableFirst, column)
fractions = zeros(4, 1);
for m = 1:4
    rows = restTableFirst.motor == m;
    fractions(m) = mean(restTableFirst.(column)(rows) ~= 0);
end
end

function value = safeMean(values)
if isempty(values)
    value = NaN;
else
    value = mean(values);
end
end

function row = emptyViolationRow()
row = struct("episode", 0, "step", 0, "referenceDelta", 0);
end

function t = emptyAcceptanceStepTable()
t = table(zeros(0, 1), zeros(0, 1), false(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', ["episode", "step", "gateActive", ...
    "meanAbsRawAction", "meanAbsEffectiveBaseline", ...
    "meanAbsPwmBaseline", "meanAbsEffectiveGated", ...
    "meanAbsPwmGated", "trackingMse"]);
end
