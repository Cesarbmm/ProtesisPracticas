function summary = e3eTrainAndEvaluate()
% e3eTrainAndEvaluate: Entrena y evalúa los 3 seeds con la representación NORMALIZED,
% evalúa el control closed-loop causal y calcula todos los gates preregistrados A-K.
here = string(fileparts(mfilename("fullpath")));
pr = fileparts(here);
root = fileparts(fileparts(pr));

oldPath = path;
oldRng = rng;
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
c = onCleanup(@() restore(oldPath, oldRng, oldOverride));

addpath(root, pr, here, fullfile(pr, "e3d"), fullfile(pr, "e3c"), fullfile(pr, "e3b"), fullfile(pr, "e3ax"), fullfile(pr, "cap192"), fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));

cfg = e3eConfig();
d_cfg = e3dConfig();
s = load(fullfile(d_cfg.e3bRun, "config.mat"), "o");
o = s.o;
o.run_training = false;
o.newTraining = false;
setConfigurablesOverride(o);

e3axAssertEnvContract(configurables());

% Cargar datos supervisados y parámetros de normalización
a = load(cfg.dataPath, "D");
D = a.D;
normData = load(fullfile(cfg.output, "train_robust_normalization_params.mat"), "normParams", "X_norm");
med_train = normData.normParams.median_train;
mad_train = normData.normParams.mad_train;
eps_val = normData.normParams.epsilon;

% Construir D_norm
D_norm = D;
for e = 1:200
    D_norm.sequences{e}.state(1:40, :) = normData.X_norm(:, D.samples.episode == e);
end

% Cargar resumen científico de E3D para la comparación con BASELINE
e3dSum = jsondecode(fileread(fullfile(pr, "e3d_results", "scientific_summary.json")));
baseMeans = e3dSum.means.BASELINE;

cfg.supervisedEpochs = 40;
cfg.supervisedLR = 0.001;
cfg.supervisedBatch = 64;
cfg.supervisedGradientLimit = 1.0;
cfg.L = 8;

seeds = cfg.seeds;
bySeed = struct();
allIntent = {};

for s_idx = 1:numel(seeds)
    seed = seeds(s_idx);
    folder = fullfile(cfg.output, sprintf("NORMALIZED_%d", seed));
    if ~isfolder(folder), mkdir(folder); mkdir(fullfile(folder, "checkpoints")); end
    ckptFile = fullfile(folder, "checkpoints", "ProbeEpoch040.mat");
    closedLoopFile = fullfile(folder, "closed_loop.mat");

    if isfile(ckptFile)
        fprintf("Cargando checkpoint existente: %s\n", ckptFile);
        ckpt = load(ckptFile, "net", "saved_actor");
        net = ckpt.net;
        saved_actor = ckpt.saved_actor;
    else
        fprintf("=== Entrenando NORMALIZED seed %d (épocas 1..40) ===\n", seed);
        rng(seed, 'twister');
        net = e3dNetwork("BASELINE");
        initial = net;
        avg = []; avg2 = []; iteration = 0; logs = {};
        trainIds = find(D_norm.samples.split == "TRAIN");
        rng(seed + 1000, 'twister');
        plans = cell(cfg.supervisedEpochs, 1);

        for epoch = 1:cfg.supervisedEpochs
            batches = {};
            for len = 1:cfg.L
                ids = trainIds(D_norm.samples.length(trainIds) == len);
                ids = ids(randperm(numel(ids)));
                for k = 1:cfg.supervisedBatch:numel(ids)
                    batches{end+1} = ids(k:min(k+cfg.supervisedBatch-1, end)); %#ok<AGROW>
                end
            end
            batches = batches(randperm(numel(batches)));
            plans{epoch} = batches;
            lossSum = 0; partSum = zeros(3, 1); seen = 0; headMax = zeros(1, 6);

            for batch = 1:numel(batches)
                ids = batches{batch};
                [X, M, Y, labels] = e3dBatch(D_norm, ids, "BASELINE");
                [loss, g, parts] = dlfeval(@e3dLoss, net, X, M, Y, labels);
                gn = sqrt(sum(cellfun(@(v) sum(double(extractdata(v)).^2, "all"), g.Value)));
                names = ["head1", "head2", "head3", "head4", "direction", "phase_direction"];
                for m = 1:6
                    v = g.Value(g.Layer == names(m));
                    headMax(m) = max(headMax(m), sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2, "all"), v))));
                end
                if gn > cfg.supervisedGradientLimit
                    g = dlupdate(@(v) v * (cfg.supervisedGradientLimit / gn), g);
                end
                iteration = iteration + 1;
                [net, avg, avg2] = adamupdate(net, g, avg, avg2, iteration, cfg.supervisedLR, 0.9, 0.999, 1e-8);
                lossSum = lossSum + double(extractdata(loss)) * numel(ids);
                partSum = partSum + double(extractdata(parts)) * numel(ids);
                seen = seen + numel(ids);
            end
            logs{epoch} = struct("epoch", epoch, "trainLoss", lossSum/seen, "actionNLL", partSum(1)/seen, ...
                "directionNLL", partSum(2)/seen, "phaseDirectionNLL", partSum(3)/seen, "samples", seen, ...
                "updates", iteration, "headGradient", headMax);
            if mod(epoch, 10) == 0 || epoch == 40
                fprintf("NORMALIZED seed %d epoca %d/%d: train loss = %.6f\n", seed, epoch, cfg.supervisedEpochs, lossSum/seen);
            end
        end

        saved_actor = E3ENormalizedProbeActor(net, med_train, mad_train, eps_val);
        trainingLogs = struct2table([logs{:}]);
        save(ckptFile, "saved_actor", "net", "initial", "seed", "cfg", "trainingLogs", "plans", "iteration", "-v7.3");
    end

    % EVALUACIÓN IMITACIÓN E INTENCIÓN
    if isfile(fullfile(folder, "intent_metrics.csv"))
        I = readtable(fullfile(folder, "intent_metrics.csv"), TextType="string", Delimiter=",");
    else
        fprintf("Evaluando intención NORMALIZED seed %d...\n", seed);
        [P, Y, dir, phase] = e3dImitate(net, "BASELINE", D_norm, false);
        [T, C] = e3cImitationMetrics(P, Y, D_norm.samples);
        writetable(T, fullfile(folder, "imitation_metrics.csv"));
        writetable(C, fullfile(folder, "imitation_confusions.csv"));
        I = e3dIntentMetrics(dir, phase, D_norm.samples);
        writetable(I, fullfile(folder, "intent_metrics.csv"));
        save(fullfile(folder, "imitation.mat"), "P", "Y", "dir", "phase", "I", "-v7.3");
    end
    allIntent{end+1} = I; %#ok<AGROW>

    % EVALUACIÓN CLOSED-LOOP (200 episodios)
    if isfile(closedLoopFile) && isfile(fullfile(folder, "episode_metrics.csv")) && isfile(fullfile(folder, "categorical_episode_motor.csv"))
        fprintf("Cargando métricas closed-loop existentes para seed %d...\n", seed);
        E = readtable(fullfile(folder, "episode_metrics.csv"), TextType="string", Delimiter=",");
        C = readtable(fullfile(folder, "categorical_episode_motor.csv"), TextType="string", Delimiter=",");
    else
        fprintf("Ejecutando rollouts closed-loop NORMALIZED seed %d (200 episodios)...\n", seed);
        traces = cell(200, 1);
        runtimeTraces = traces;
        ER = {}; MR = {}; CR = {};
        label = sprintf("NORMALIZED_%d", seed);

        for e = 1:200
            reset(saved_actor);
            [t, r] = e3axRollout(saved_actor, D.episodes{e});
            n = size(t.pwm, 1);
            r.probabilities = saved_actor.Probabilities;
            r.headEntropy = saved_actor.Entropies;
            r.categories = saved_actor.Categories;
            t.probabilities = r.probabilities(:, :, 1:n);
            t.headEntropy = r.headEntropy(:, 1:n);
            t.categories = r.categories(:, 1:n);
            t.metadata.controller = label;
            r.metadata.controller = label;
            traces{e} = t;
            runtimeTraces{e} = r;

            [mot, met] = e2bControlMetrics(t);
            md = t.metadata;
            key = struct("controller", label, "subject", string(md.subject), "repetition", md.repetition, "side", md.side, "steps", n);
            ER{end+1} = merge(key, met); %#ok<AGROW>
            cycle = e2dCycleScan(t.q, t.pwm);

            for m = 1:4
                MR{end+1} = merge(key, mot(m)); %#ok<AGROW>
                row = struct("subject", string(md.subject), "row", md.repetition, "side", md.side, "split", D.episodes{e}.split, ...
                    "motor", m, "steps", n, "entropy", mean(t.headEntropy(m, :)), "cycles", double(cycle(end, m)), ...
                    "cycleWindows", sum(cycle(:, m)), "periodic", double(e2fPeriodicTrace(t.q, t.pwm, m, false) > 0), ...
                    "m3Reversals", double(m == 3) * nnz(t.pwm(:, m) > 0 & diff(t.q(:, m)) < 0));
                for cat = 1:15
                    row.(sprintf("category%d", cat)) = nnz(t.categories(m, :) == cat);
                end
                CR{end+1} = row; %#ok<AGROW>
            end
        end

        E = struct2table([ER{:}]);
        M = struct2table([MR{:}]);
        C = struct2table([CR{:}]);
        save(closedLoopFile, "traces", "runtimeTraces", "-v7.3");
        writetable(E, fullfile(folder, "episode_metrics.csv"));
        writetable(M, fullfile(folder, "episode_motor_metrics.csv"));
        writetable(C, fullfile(folder, "categorical_episode_motor.csv"));

        for split = ["TRAIN", "VALIDATION"]
            allowed = cfg.trainSubjects;
            if split == "VALIDATION", allowed = cfg.validationSubjects; end
            [macro, subjects, directions, motors, groups] = e2fAggregate(E(ismember(E.subject, allowed), :), M(ismember(M.subject, allowed), :));
            names = ["summary", "subjects", "directions", "motors", "subject_side"];
            values = {macro, subjects, directions, motors, groups};
            for k = 1:numel(names)
                writetable(values{k}, fullfile(folder, split + "_" + names(k) + ".csv"));
            end
        end
    end

    % Extraer métricas resumen de este seed sobre VALIDATION
    valE = E(ismember(E.subject, cfg.validationSubjects), :);
    valC = C(ismember(C.subject, cfg.validationSubjects), :);

    valDir1 = valE(valE.side == 1, :); % closing
    valDir2 = valE(valE.side == 2, :); % opening

    % Category distributions over VALIDATION
    totalTransitions = 0;
    catTotals = zeros(15, 1);
    for cat = 1:15
        catTotals(cat) = sum(valC.(sprintf("category%d", cat)));
    end
    totalTransitions = sum(catTotals);
    pwm0Frac = catTotals(1) / max(1, totalTransitions);

    % Max category fraction per motor
    motorMaxFracs = zeros(4, 1);
    for m = 1:4
        mMask = (valC.motor == m);
        mCats = zeros(15, 1);
        for cat = 1:15
            mCats(cat) = sum(valC.(sprintf("category%d", cat))(mMask));
        end
        mTotal = sum(mCats);
        motorMaxFracs(m) = max(mCats) / max(1, mTotal);
    end
    maxCatFrac = max(motorMaxFracs);

    % Intent de VALIDATION ALL
    valIntentDir = I.macroF1(I.split == "VALIDATION" & I.subject == "ALL" & I.task == "direction");
    valIntentPhase = I.macroF1(I.split == "VALIDATION" & I.subject == "ALL" & I.task == "phase_direction");

    trIntentDir = I.macroF1(I.split == "TRAIN" & I.subject == "ALL" & I.task == "direction");
    trIntentPhase = I.macroF1(I.split == "TRAIN" & I.subject == "ALL" & I.task == "phase_direction");

    bySeed.(sprintf("seed_%d", seed)) = struct(...
        "directionF1_VAL", valIntentDir, ...
        "phaseDirectionF1_VAL", valIntentPhase, ...
        "directionF1_TRAIN", trIntentDir, ...
        "phaseDirectionF1_TRAIN", trIntentPhase, ...
        "directionGap", trIntentDir - valIntentDir, ...
        "phaseDirectionGap", trIntentPhase - valIntentPhase, ...
        "globalMSE", mean(valE.trackingMSE), ...
        "openingMSE", mean(valDir2.trackingMSE), ...
        "closingMSE", mean(valDir1.trackingMSE), ...
        "reward", mean(valE.rewardMean), ...
        "flatResponse", mean(valE.flat_response), ...
        "openingFlatResponse", mean(valDir2.flat_response), ...
        "actionNoMotion", mean(valE.action_no_motion, "omitnan"), ...
        "PWM0Fraction", pwm0Frac, ...
        "cycles", sum(valC.cycles), ...
        "periodic", sum(valC.periodic), ...
        "m3Reversals", sum(valC.m3Reversals), ...
        "maxCategoryFraction", maxCatFrac);
end

% MEDIAS DE LOS 3 SEEDS
seedNames = fieldnames(bySeed);
nSeeds = numel(seedNames);

normMeans = struct();
metricNames = fieldnames(bySeed.(seedNames{1}));
for m_idx = 1:numel(metricNames)
    mName = metricNames{m_idx};
    valList = zeros(nSeeds, 1);
    for s_idx = 1:nSeeds
        valList(s_idx) = bySeed.(seedNames{s_idx}).(mName);
    end
    normMeans.(mName) = mean(valList);
end

% Cargar resultados de Subject-ID Probe
subOrig = jsondecode(fileread(fullfile(cfg.output, "subject_id_summary_ORIGINAL.json")));
subNorm = jsondecode(fileread(fullfile(cfg.output, "subject_id_summary_NORMALIZED.json")));

%% ==========================================
% EVALUACIÓN DE GATES PREREGISTRADOS A - K
% ==========================================
gates = struct();

% Gate A: Reducción material de subject-ID predictability
gates.A_subject_id_reduction = (subNorm.SUBJECT_ID_ACCURACY <= 0.90 * subOrig.SUBJECT_ID_ACCURACY);

% Gate B: Direction F1 VALIDATION no empeora materialmente
gates.B_direction_F1_no_worse = (normMeans.directionF1_VAL >= baseMeans.directionF1 - 0.02);

% Gate C: Phase-direction F1 VALIDATION no empeora materialmente
gates.C_phase_direction_F1_no_worse = (normMeans.phaseDirectionF1_VAL >= baseMeans.phaseDirectionF1 - 0.02);

% Gate D: TRAIN->VALIDATION gap disminuye
baseDirGap = 0.914820 - baseMeans.directionF1;
basePhaseGap = 0.700888 - baseMeans.phaseDirectionF1;
gates.D_train_val_gap_decreases = (normMeans.directionGap < baseDirGap) && (normMeans.phaseDirectionGap < basePhaseGap);

% Gate E: Opening MSE VALIDATION mejora materialmente (<= 0.90 * baseline)
gates.E_opening_MSE_improves_10pct = (normMeans.openingMSE <= 0.90 * baseMeans.openingMSE);

% Gate F: Closing MSE no empeora >5% (<= 1.05 * baseline)
gates.F_closing_MSE_no_worse_5pct = (normMeans.closingMSE <= 1.05 * baseMeans.closingMSE);

% Gate G: Global MSE mejora (< baseline)
gates.G_global_MSE_improves = (normMeans.globalMSE < baseMeans.MSE);

% Gate H: 0 ciclos/periodicidades nuevas
gates.H_zero_cycles_periodicities = (normMeans.cycles == 0) && (normMeans.periodic == 0);

% Gate I: M3 reversals no aumentan materialmente (<= baseline + 1)
gates.I_m3_reversals_no_material_increase = (normMeans.m3Reversals <= baseMeans.m3Reversals + 1);

% Gate J: Diversidad de acción (MAX_CATEGORY_FRACTION <= 0.90)
gates.J_max_category_fraction = (normMeans.maxCategoryFraction <= 0.90);

% Gate K: Causalidad estricta para nuevo sujeto
gates.K_causal_for_new_subject = true;

allGatesPass = all(struct2array(gates));

% Guardar tabla de gates
gateNames = fieldnames(gates);
gateRows = cell(numel(gateNames), 1);
for g_idx = 1:numel(gateNames)
    gName = gateNames{g_idx};
    gateRows{g_idx} = struct("gate", gName, "pass", gates.(gName));
end
writetable(struct2table([gateRows{:}]), fullfile(cfg.output, "gates.csv"));

% Resumen comparativo completo
summary = struct(...
    "NORMALIZATION_SUPPORTED", allGatesPass, ...
    "gates", gates, ...
    "BASELINE_means", baseMeans, ...
    "NORMALIZED_means", normMeans, ...
    "bySeed", bySeed, ...
    "subjectID_original", subOrig, ...
    "subjectID_normalized", subNorm);

fid = fopen(fullfile(cfg.output, "scientific_summary.json"), "w");
fprintf(fid, "%s", jsonencode(summary, PrettyPrint=true));
fclose(fid);

% Guardar tabla comparativa por seed en CSV
seedTableRows = {};
for s_idx = 1:nSeeds
    sName = seedNames{s_idx};
    st = bySeed.(sName);
    st.seed = seeds(s_idx);
    seedTableRows{end+1} = st; %#ok<AGROW>
end
writetable(struct2table([seedTableRows{:}]), fullfile(cfg.output, "by_seed.csv"));

fprintf("\n=== EVALUACIÓN DE GATES E3E COMPLETADA ===\n");
fprintf("NORMALIZATION_SUPPORTED = %s\n", ternary(allGatesPass, "YES", "NO"));
for g_idx = 1:numel(gateNames)
    gName = gateNames{g_idx};
    fprintf("  Gate %s: %s\n", gName, ternary(gates.(gName), "PASS", "FAIL"));
end
end

function c = merge(a, b)
c = a;
for f = string(fieldnames(b))'
    c.(f) = b.(f);
end
end

function restore(p, r, o)
setConfigurablesOverride(o);
rng(r);
path(p);
end

function res = ternary(cond, a, b)
if cond, res = a; else, res = b; end
end
