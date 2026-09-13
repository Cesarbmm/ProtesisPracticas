function [statsSummary, varianceSummary] = e3eAuditFeatureStatsAndVariance()
% e3eAuditFeatureStatsAndVariance: Estadísticas por sujeto (Sección 12) y
% descomposición de varianza entre-sujeto vs intención (Sección 13).
cfg = e3eConfig();
if ~isfolder(cfg.output), mkdir(cfg.output); end

a = load(cfg.dataPath, "D");
D = a.D;
S = D.samples;

% Recolectar matriz completa de features WMoos (40 x TotalSamples)
N_samples = height(S);
featuresMatrix = zeros(40, N_samples);

for e = 1:200
    epIx = find(S.episode == e);
    states = D.sequences{e}.state; % 52 x T
    assert(numel(epIx) == size(states, 2));
    featuresMatrix(:, epIx) = states(1:40, :);
end

allSubjects = [cfg.trainSubjects, cfg.validationSubjects];

%% ==========================================
% SECCIÓN 12: ESTADÍSTICAS POR SUJETO
% ==========================================
statsRows = {};

for i = 1:numel(allSubjects)
    sub = allSubjects(i);
    subMask = (S.subject == sub);

    for cond = ["all", "closing", "opening"]
        if cond == "all"
            mask = subMask;
        elseif cond == "closing"
            mask = subMask & (S.side == 1);
        else
            mask = subMask & (S.side == 2);
        end

        if ~any(mask), continue; end
        subFeats = featuresMatrix(:, mask); % 40 x N_cond

        for f = 1:40
            vals = subFeats(f, :);

            m = mean(vals);
            s = std(vals);
            med = median(vals);
            madVal = e3eStats.mad(vals);
            iqrVal = e3eStats.iqr(vals);
            p01 = e3eStats.prctile(vals, 1);
            p05 = e3eStats.prctile(vals, 5);
            p25 = e3eStats.prctile(vals, 25);
            p50 = med;
            p75 = e3eStats.prctile(vals, 75);
            p95 = e3eStats.prctile(vals, 95);
            p99 = e3eStats.prctile(vals, 99);
            minVal = min(vals);
            maxVal = max(vals);

            statsRows{end+1} = struct(...
                "subject", sub, ...
                "condition", cond, ...
                "featureIndex", f, ...
                "mean", m, ...
                "std", s, ...
                "median", med, ...
                "MAD", madVal, ...
                "IQR", iqrVal, ...
                "p01", p01, ...
                "p05", p05, ...
                "p25", p25, ...
                "p50", p50, ...
                "p75", p75, ...
                "p95", p95, ...
                "p99", p99, ...
                "min", minVal, ...
                "max", maxVal);
        end
    end
end

statsTable = struct2table([statsRows{:}]);
writetable(statsTable, fullfile(cfg.output, "feature_stats_by_subject.csv"));
save(fullfile(cfg.output, "feature_stats.mat"), "statsTable", "-v7.3");

statsSummary = struct("totalFeatureRows", height(statsTable), "numSubjects", numel(allSubjects));

%% ==========================================
% SECCIÓN 13: ENTRE-SUJETO VS INTRA-SUJETO
% ==========================================
% Cuantificar para cada feature sobre el conjunto de desarrollo TRAIN:
% Variación entre sujetos versus variación debida a la intención (opening vs closing)
% Definición matemática preregistrada:
% ANOVA de dos vías (Factor A: Sujeto, Factor B: Intención)
trainMask = (S.split == "TRAIN");
trainFeats = featuresMatrix(:, trainMask); % 40 x N_train
trainSub = categorical(S.subject(trainMask));
trainSide = categorical(S.side(trainMask));

N_tr = sum(trainMask);
K_sub = numel(unique(trainSub)); % 7 sujetos en TRAIN
K_side = numel(unique(trainSide)); % 2 intenciones (closing, opening)

df_sub = K_sub - 1;       % 6
df_intent = K_side - 1;   % 1
df_inter = df_sub * df_intent; % 6
df_error = N_tr - (K_sub * K_side);

varDecompRows = {};
ratios = zeros(40, 1);
eta2SubList = zeros(40, 1);
eta2IntentList = zeros(40, 1);

for f = 1:40
    y = trainFeats(f, :)';

    % Gran media
    y_grand = mean(y);
    SS_total = sum((y - y_grand).^2);

    % Medias por sujeto
    subMeans = accumarray(double(trainSub), y, [K_sub 1], @mean);
    subCounts = accumarray(double(trainSub), 1, [K_sub 1]);
    SS_sub = sum(subCounts .* (subMeans - y_grand).^2);

    % Medias por intención
    intentMeans = accumarray(double(trainSide), y, [K_side 1], @mean);
    intentCounts = accumarray(double(trainSide), 1, [K_side 1]);
    SS_intent = sum(intentCounts .* (intentMeans - y_grand).^2);

    % Medias de celda (sujeto x intención)
    subSideCode = double(trainSub) + K_sub * (double(trainSide) - 1);
    cellMeans = accumarray(subSideCode, y, [K_sub * K_side 1], @mean);
    cellCounts = accumarray(subSideCode, 1, [K_sub * K_side 1]);

    % Sum of squares model
    SS_model = sum(cellCounts .* (cellMeans - y_grand).^2);
    SS_inter = max(0, SS_model - SS_sub - SS_intent);
    SS_error = max(0, SS_total - SS_model);

    MS_sub = SS_sub / df_sub;
    MS_intent = SS_intent / df_intent;
    MS_error = SS_error / df_error;

    % SUBJECT_TO_INTENT_VARIANCE_RATIO
    ratio = MS_sub / max(MS_intent, 1e-12);
    ratios(f) = ratio;

    eta2_sub = SS_sub / max(SS_total, 1e-12);
    eta2_intent = SS_intent / max(SS_total, 1e-12);

    eta2SubList(f) = eta2_sub;
    eta2IntentList(f) = eta2_intent;

    varDecompRows{end+1} = struct(...
        "featureIndex", f, ...
        "SS_total", SS_total, ...
        "SS_subject", SS_sub, ...
        "SS_intent", SS_intent, ...
        "SS_interaction", SS_inter, ...
        "SS_error", SS_error, ...
        "MS_subject", MS_sub, ...
        "MS_intent", MS_intent, ...
        "MS_error", MS_error, ...
        "subjectToIntentRatio", ratio, ...
        "eta2_subject", eta2_sub, ...
        "eta2_intent", eta2_intent);
end

varDecompTable = struct2table([varDecompRows{:}]);
writetable(varDecompTable, fullfile(cfg.output, "variance_decomposition_by_feature.csv"));

varianceSummary = struct(...
    "SUBJECT_TO_INTENT_VARIANCE_RATIO_MEAN", mean(ratios), ...
    "SUBJECT_TO_INTENT_VARIANCE_RATIO_MEDIAN", median(ratios), ...
    "SUBJECT_TO_INTENT_VARIANCE_RATIO_MIN", min(ratios), ...
    "SUBJECT_TO_INTENT_VARIANCE_RATIO_MAX", max(ratios), ...
    "ETA2_SUBJECT_MEAN", mean(eta2SubList), ...
    "ETA2_SUBJECT_MEDIAN", median(eta2SubList), ...
    "ETA2_INTENT_MEAN", mean(eta2IntentList), ...
    "ETA2_INTENT_MEDIAN", median(eta2IntentList), ...
    "NUM_FEATURES_SUBJECT_DOMINANT", sum(ratios > 1.0));

fid = fopen(fullfile(cfg.output, "variance_summary.json"), "w");
fprintf(fid, "%s", jsonencode(varianceSummary, PrettyPrint=true));
fclose(fid);

fprintf("Estadísticas por sujeto y descomposición de varianza completadas exitosamente.\n");
end
