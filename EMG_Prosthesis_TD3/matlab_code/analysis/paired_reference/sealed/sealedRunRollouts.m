function results = sealedRunRollouts(evalData, e4Actor, agent7250Actor, graphs, remap, seed, outDir)
% sealedRunRollouts ejecuta la evaluacion apareada de las 5 politicas preregistradas:
% 1. ZERO (Control Basal)
% 2. AGENT7250 (Baseline Historico TD3)
% 3. P_2 (Docente Privilegiado)
% 4. ORACLE_H5 (Oraculo Cinematico Privilegiado)
% 5. FINAL_E4 (PPO Categorico Congelado)

arguments
    evalData cell
    e4Actor
    agent7250Actor
    graphs
    remap
    seed (1, 1) double
    outDir (1, 1) string
end

nEp = numel(evalData);
controllers = ["ZERO", "AGENT7250", "P_2", "ORACLE_H5", "FINAL_E4"];
nCtrl = numel(controllers);
trajectories = cell(nEp, nCtrl);
runtimeTraces = cell(nEp, 1);

metricRows = {};
motorRows = {};
stepTables = {};
catMotorRows = {};

levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];

fprintf("Iniciando rollouts apareados de 5 politicas sobre %d episodios sellados...\n", nEp);

for e = 1:nEp
    item = evalData{e};
    subj = string(item.subject);
    rep = double(item.repetition);
    side = double(item.side);
    dataset = item.pairData;

    % 1. ZERO
    tZero = rolloutTeacherLocal(agent7250Actor, dataset, side, "ZERO", 0, seed);
    tZero.metadata = struct("controller", "ZERO", "subject", subj, "repetition", rep, ...
        "side", side, "split", "TEST", "steps", size(tZero.rawAction, 1));
    trajectories{e, 1} = tZero;

    % 2. AGENT7250
    tAgent = rolloutTeacherLocal(agent7250Actor, dataset, side, "AGENT7250", NaN, seed);
    tAgent.metadata = struct("controller", "AGENT7250", "subject", subj, "repetition", rep, ...
        "side", side, "split", "TEST", "steps", size(tAgent.rawAction, 1));
    trajectories{e, 2} = tAgent;

    % 3. P_2
    tP2 = rolloutTeacherLocal(agent7250Actor, dataset, side, "P_2", 2, seed);
    tP2.metadata = struct("controller", "P_2", "subject", subj, "repetition", rep, ...
        "side", side, "split", "TEST", "steps", size(tP2.rawAction, 1));
    trajectories{e, 3} = tP2;

    % 4. ORACLE_H5
    tOracle = e2fRollout(tP2, 5, graphs, remap);
    tOracle.metadata = struct("controller", "ORACLE_H5", "subject", subj, "repetition", rep, ...
        "side", side, "split", "TEST", "steps", size(tOracle.pwm, 1));
    trajectories{e, 4} = tOracle;

    % 5. FINAL_E4
    epStruct = struct("base", tP2, "emg", item.emg, "split", "TEST");
    [tE4, rE4] = e3axRollout(e4Actor, epStruct);
    tE4.metadata = struct("controller", "FINAL_E4", "subject", subj, "repetition", rep, ...
        "side", side, "split", "TEST", "steps", size(tE4.pwm, 1));
    rE4.metadata = tE4.metadata;

    nSteps = size(tE4.pwm, 1);
    [p, h] = e4Actor.distribution(rE4.state(1:nSteps, :)');
    selectedProb = zeros(nSteps, 4);
    headEnt = zeros(nSteps, 4);
    for m = 1:4
        headEnt(:, m) = h(m, :)';
        for k = 1:nSteps
            cIdx = find(levels == tE4.pwm(k, m), 1);
            if isempty(cIdx), cIdx = 1; end
            selectedProb(k, m) = p(cIdx, m, k);
        end
    end
    tE4.selectedProbability = selectedProb;
    tE4.headEntropy = headEnt;

    trajectories{e, 5} = tE4;
    runtimeTraces{e} = rE4;

    % Diagnosticos de categorias para FINAL_E4
    for m = 1:4
        motPwm = tE4.pwm(:, m);
        catRow = struct("controller", "FINAL_E4", "subject", subj, "repetition", rep, ...
            "side", side, "motor", m, "steps", nSteps);
        for k = 1:15
            fld = sprintf("pwm_%d", levels(k));
            fld = strrep(fld, "-", "m");
            catRow.(fld) = nnz(motPwm == levels(k));
        end
        catRow.maxCategoryFraction = max(struct2array(rmfield(catRow, ["controller", "subject", "repetition", "side", "motor", "steps"]))) / nSteps;
        catMotorRows{end+1} = catRow; %#ok<AGROW>
    end

    % Calcular metricas para todas las 5 politicas
    for c = 1:nCtrl
        tr = trajectories{e, c};
        md = tr.metadata;
        [mot, met] = e2bControlMetrics(tr);
        key = struct("controller", md.controller, "subject", md.subject, ...
            "repetition", md.repetition, "side", md.side, "steps", size(tr.pwm, 1));

        m3Rev = nnz(tr.pwm(:, 3) > 0 & diff(tr.q(:, 3)) < 0);
        met.m3Reversals = m3Rev;

        metricRows{end+1} = mergeStructs(key, met); %#ok<AGROW>
        for m = 1:4
            mot(m).m3Reversals = double(m == 3) * m3Rev;
            motorRows{end+1} = mergeStructs(key, mot(m)); %#ok<AGROW>
        end
        if c == 5
            stepTables{end+1} = e2fTraceTable(tr); %#ok<AGROW>
        end
    end

    if mod(e, 10) == 0 || e == nEp
        fprintf("Progreso rollouts sellados: %d/%d episodios completados.\n", e, nEp);
    end
end

metricsTable = struct2table([metricRows{:}]);
motorTable = struct2table([motorRows{:}]);
catTable = struct2table([catMotorRows{:}]);

metricsDir = fullfile(outDir, "metrics");
if ~isfolder(metricsDir), mkdir(metricsDir); end

% Agregaciones
[policySummary, subjectSummary, dirSummary, motorSummary] = computeAggregates(metricsTable, motorTable);

% Guardar tablas CSV y trajectories.mat
writetable(metricsTable, fullfile(metricsDir, "episode_metrics.csv"));
writetable(motorTable, fullfile(metricsDir, "episode_motor_metrics.csv"));
writetable(catTable, fullfile(metricsDir, "categorical_episode_motor.csv"));
writetable(policySummary, fullfile(metricsDir, "controller_summary.csv"));
writetable(subjectSummary, fullfile(metricsDir, "subject_summary.csv"));
writetable(dirSummary, fullfile(metricsDir, "direction_summary.csv"));
writetable(motorSummary, fullfile(metricsDir, "motor_summary.csv"));
if ~isempty(stepTables)
    writetable(vertcat(stepTables{:}), fullfile(metricsDir, "step_traces.csv"));
end

save(fullfile(metricsDir, "trajectories.mat"), "trajectories", "runtimeTraces", "controllers", "-v7.3");

results = struct("trajectories", {trajectories}, "runtimeTraces", {runtimeTraces}, ...
    "metricsTable", metricsTable, "motorTable", motorTable, "catTable", catTable, ...
    "policySummary", policySummary, "subjectSummary", subjectSummary, ...
    "dirSummary", dirSummary, "motorSummary", motorSummary);
end

function [policySum, subjSum, dirSum, motSum] = computeAggregates(E, M)
ctrls = unique(E.controller, "stable");
pRows = {};
sRows = {};
dRows = {};
mRows = {};

for c = 1:numel(ctrls)
    ctrl = ctrls(c);
    subE = E(E.controller == ctrl, :);
    subM = M(M.controller == ctrl, :);

    % Policy aggregate
    pRows{c} = struct("controller", ctrl, ...
        "trackingMSE", mean(subE.trackingMSE), ...
        "medianMSE", median(subE.trackingMSE), ...
        "minMSE", min(subE.trackingMSE), ...
        "maxMSE", max(subE.trackingMSE), ...
        "MAE", mean(subE.MAE), ...
        "rewardMean", mean(subE.rewardMean), ...
        "actionL2", mean(subE.actionL2), ...
        "deltaActionL2", mean(subE.deltaActionL2), ...
        "saturationFraction", mean(subE.saturationFraction), ...
        "flat_response", mean(subE.flat_response), ...
        "action_no_motion", mean(subE.action_no_motion), ...
        "m3ReversalsTotal", sum(subE.m3Reversals), ...
        "m3ReversalRate", sum(subE.m3Reversals) / sum(subE.steps), ...
        "persistentTwoCycleTotal", sum(subE.persistentTwoCycle));

    % Subject aggregate
    subjs = unique(subE.subject, "stable");
    for s = 1:numel(subjs)
        sName = subjs(s);
        subES = subE(subE.subject == sName, :);
        sRows{end+1} = struct("controller", ctrl, "subject", sName, ...
            "trackingMSE", mean(subES.trackingMSE), ...
            "MAE", mean(subES.MAE), ...
            "rewardMean", mean(subES.rewardMean), ...
            "m3Reversals", sum(subES.m3Reversals), ...
            "persistentTwoCycle", sum(subES.persistentTwoCycle)); %#ok<AGROW>
    end

    % Direction aggregate
    sides = [1 2];
    for si = 1:2
        sideVal = sides(si);
        subED = subE(subE.side == sideVal, :);
        dRows{end+1} = struct("controller", ctrl, "side", sideVal, ...
            "trackingMSE", mean(subED.trackingMSE), ...
            "MAE", mean(subED.MAE), ...
            "rewardMean", mean(subED.rewardMean), ...
            "flat_response", mean(subED.flat_response), ...
            "action_no_motion", mean(subED.action_no_motion)); %#ok<AGROW>
    end

    % Motor aggregate
    for m = 1:4
        subMM = subM(subM.motor == m, :);
        mRows{end+1} = struct("controller", ctrl, "motor", m, ...
            "trackingMSE", mean(subMM.trackingMSE), ...
            "MAE", mean(subMM.MAE), ...
            "flat_response", mean(subMM.flat_response), ...
            "action_no_motion", mean(subMM.action_no_motion), ...
            "m3Reversals", sum(subMM.m3Reversals)); %#ok<AGROW>
    end
end

policySum = struct2table([pRows{:}]);
subjSum = struct2table([sRows{:}]);
dirSum = struct2table([dRows{:}]);
motSum = struct2table([mRows{:}]);
end

function trace = rolloutTeacherLocal(actor, data, side, controller, kp, seed)
rng(seed, "twister");
env = Env("", true, data.emgs, data.teachers);
for resetIndex = 1:side
    state = reset(env);
end
trace = struct("state", state', "q", env.motorData(end, :), ...
    "rawAction", zeros(0, 4), "effectiveAction", zeros(0, 4), "pwm", zeros(0, 4), ...
    "referenceBefore", zeros(0, 4), "reference", zeros(0, 4), "prediction", zeros(0, 4), ...
    "reward", zeros(0, 1), "plantTrajectory", {{}});
done = false;
while ~done
    before = env.flexJoined_scaler(reduceFlexDimension(env.flexData));
    if controller == "ZERO"
        raw = zeros(4, 1);
    elseif controller == "AGENT7250"
        val = getAction(actor, {state});
        if iscell(val), val = cell2mat(val); end
        raw = double(val(:));
    else
        raw = e2bProportionalAction(env.motorData(end, :), env.flexData, kp);
    end
    [state, reward, done] = step(env, raw);
    k = env.c;
    trace.state(end+1, :) = state';
    trace.q(end+1, :) = env.motorData(end, :);
    trace.rawAction(end+1, :) = raw(:)';
    trace.effectiveAction(end+1, :) = env.actionSatLog(k, :);
    trace.pwm(end+1, :) = env.actionPwmLog(k, :);
    trace.referenceBefore(k, :) = before(end, :);
    trace.reference(k, :) = env.flexConverted(end, :);
    trace.prediction(k, :) = env.adjustEnc(end, :);
    trace.reward(k, 1) = reward;
    trLog = env.encoderLog{k};
    trace.plantTrajectory{k} = trLog(2:end, :);
    assert(k < 1000, "Sealed:Runaway", "Horizonte inesperado.");
end
trace.emgExhausted = env.myo.exhausted;
trace.gloveExhausted = env.glove.exhausted;
end

function s = mergeStructs(a, b)
s = a;
fn = fieldnames(b);
for i = 1:numel(fn)
    s.(fn{i}) = b.(fn{i});
end
end
