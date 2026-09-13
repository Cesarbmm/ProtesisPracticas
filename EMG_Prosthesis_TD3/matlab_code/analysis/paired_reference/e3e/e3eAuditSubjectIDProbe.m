function subjectIDSummary = e3eAuditSubjectIDProbe(customFeatures)
% e3eAuditSubjectIDProbe: Evalúa qué tan predecible es la identidad del sujeto
% a partir de WMoos40 en el conjunto TRAIN mediante 5-fold cross validation por episodio.
% Si se pasa customFeatures (40 x N_total), se usa en lugar del WMoos original.
arguments
    customFeatures = [];
end

cfg = e3eConfig();
if ~isfolder(cfg.output), mkdir(cfg.output); end
figDir = fullfile(cfg.output, "figures");
if ~isfolder(figDir), mkdir(figDir); end

a = load(cfg.dataPath, "D");
D = a.D;
S = D.samples;

% Filtrar sólo TRAIN
trainMask = (S.split == "TRAIN");
S_train = S(trainMask, :);
N_train = height(S_train);

% Extraer features
if isempty(customFeatures)
    X = zeros(40, N_train, 'single');
    for e = 1:200
        if D.episodes{e}.split ~= "TRAIN", continue; end
        epIx = find(S_train.episode == e);
        states = D.sequences{e}.state;
        X(:, epIx) = single(states(1:40, :));
    end
    probeType = "ORIGINAL";
else
    X = single(customFeatures(:, trainMask));
    probeType = "NORMALIZED";
end

% Mapeo de sujetos TRAIN a índices 1..7
trainSubjects = cfg.trainSubjects;
K = numel(trainSubjects); % 7
y = zeros(1, N_train, 'int32');
for k = 1:K
    y(S_train.subject == trainSubjects(k)) = k;
end
assert(all(y >= 1 & y <= K));

% 5-fold cross-validation por episodios
% Cada sujeto tiene 20 episodios en TRAIN. En cada fold, 4 episodios de test y 16 de train por sujeto.
uniqueEps = unique(S_train.episode); % 140 episodios
epSubject = strings(numel(uniqueEps), 1);
for i = 1:numel(uniqueEps)
    e = uniqueEps(i);
    epSubject(i) = S_train.subject(find(S_train.episode == e, 1));
end

rng(20260923); % Semilla congelada
folds = zeros(numel(uniqueEps), 1);
for k = 1:K
    subEps = find(epSubject == trainSubjects(k));
    assert(numel(subEps) == 20);
    p = randperm(20);
    for fold = 1:5
        idxInSub = p((fold-1)*4 + 1 : fold*4);
        folds(subEps(idxInSub)) = fold;
    end
end
assert(all(folds >= 1 & folds <= 5));

% Asignar fold a cada muestra según su episodio
sampleFold = zeros(N_train, 1);
for i = 1:numel(uniqueEps)
    e = uniqueEps(i);
    sampleFold(S_train.episode == e) = folds(i);
end

% Salidas fuera de pliegue (out-of-fold)
oof_preds = zeros(1, N_train);
oof_probs = zeros(K, N_train, 'single');

for fold = 1:5
    trainIdx = find(sampleFold ~= fold);
    valIdx = find(sampleFold == fold);

    X_tr = dlarray(X(:, trainIdx));
    y_tr = y(trainIdx);

    X_va = dlarray(X(:, valIdx));

    % Inicializar modelo lineal simple: W (K x 40), b (K x 1)
    rng(20260923 + fold);
    W = dlarray(randn(K, 40, 'single') * 0.01);
    b = dlarray(zeros(K, 1, 'single'));

    lr = 0.01;
    batchSize = 64;
    numBatches = ceil(numel(trainIdx) / batchSize);

    % Adam optimizer states
    avgG_W = []; avgGsq_W = [];
    avgG_b = []; avgGsq_b = [];

    for epoch = 1:40
        p = randperm(numel(trainIdx));
        for b_idx = 1:numBatches
            batch_sel = p((b_idx-1)*batchSize + 1 : min(b_idx*batchSize, numel(trainIdx)));
            X_b = X_tr(:, batch_sel);
            y_b = y_tr(batch_sel);

            [loss, g_W, g_b] = dlfeval(@linearLoss, W, b, X_b, y_b);

            [W, avgG_W, avgGsq_W] = adamupdate(W, g_W, avgG_W, avgGsq_W, (epoch-1)*numBatches + b_idx, lr);
            [b, avgG_b, avgGsq_b] = adamupdate(b, g_b, avgG_b, avgGsq_b, (epoch-1)*numBatches + b_idx, lr);
        end
    end

    % Evaluar en el pliegue de validación
    logits_va = W * X_va + b;
    probs_va = softmax(logits_va);
    probs_mat = extractdata(probs_va);
    [~, pred_va] = max(probs_mat, [], 1);

    oof_preds(valIdx) = pred_va;
    oof_probs(:, valIdx) = probs_mat;
end

% Métricas out-of-fold globales
cm = accumarray([double(y)', oof_preds'], 1, [K K]);
f1 = zeros(K, 1);
for k = 1:K
    den = sum(cm(k, :)) + sum(cm(:, k));
    if den > 0
        f1(k) = 2 * cm(k, k) / den;
    end
end

accuracy = mean(oof_preds == double(y));
macroF1 = mean(f1);
chanceLevel = 1 / K;

% Guardar matriz de confusión
cmTable = array2table(cm, 'RowNames', cellstr(trainSubjects), 'VariableNames', cellstr(trainSubjects));
writetable(cmTable, fullfile(cfg.output, sprintf("subject_id_confusion_%s.csv", probeType)), 'WriteRowNames', true);

% Figura de matriz de confusión
set(0, 'DefaultFigureVisible', 'off');
fig = figure('Position', [100 100 700 600], 'Visible', 'off');
imagesc(cm);
colormap(flipud(gray));
colorbar;
xticks(1:K); xticklabels(cellstr(trainSubjects)); xtickangle(45);
yticks(1:K); yticklabels(cellstr(trainSubjects));
title(sprintf("Matriz de Confusión Subject-ID Probe (%s)\nAccuracy = %.2f%% | Macro-F1 = %.4f | Chance = %.2f%%", ...
    probeType, accuracy*100, macroF1, chanceLevel*100), 'FontSize', 12, 'FontWeight', 'bold');
xlabel("Predicción del Probe", 'FontWeight', 'bold');
ylabel("Sujeto Real", 'FontWeight', 'bold');

% Escribir valores en celdas
for r = 1:K
    for c_idx = 1:K
        text(c_idx, r, sprintf("%d", cm(r, c_idx)), ...
            'HorizontalAlignment', 'center', ...
            'Color', ternary(cm(r, c_idx) > max(cm(:))/2, 'w', 'k'), ...
            'FontWeight', 'bold');
    end
end

saveas(fig, fullfile(figDir, sprintf("subject_id_confusion_%s.png", probeType)));
savefig(fig, fullfile(figDir, sprintf("subject_id_confusion_%s.fig", probeType)));
close(fig);

subjectIDSummary = struct(...
    "probeType", probeType, ...
    "SUBJECT_ID_ACCURACY", accuracy, ...
    "SUBJECT_ID_MACRO_F1", macroF1, ...
    "CHANCE_LEVEL", chanceLevel, ...
    "F1_by_subject", f1);

fid = fopen(fullfile(cfg.output, sprintf("subject_id_summary_%s.json", probeType)), "w");
fprintf(fid, "%s", jsonencode(subjectIDSummary, PrettyPrint=true));
fclose(fid);

fprintf("Subject-ID Probe (%s) completado: Accuracy = %.4f (%.2f%%), Macro-F1 = %.4f (Chance = %.2f%%)\n", ...
    probeType, accuracy, accuracy*100, macroF1, chanceLevel*100);
end

function [loss, g_W, g_b] = linearLoss(W, b, X, y)
logits = W * X + b;
% Cross entropy
logits_stab = logits - max(logits, [], 1);
logp = logits_stab - log(sum(exp(logits_stab), 1));
mask = zeros(size(logits), 'single');
mask(sub2ind(size(mask), y, 1:numel(y))) = 1;
loss = -mean(sum(logp .* mask, 1));
[g_W, g_b] = dlgradient(loss, W, b);
end

function p = softmax(z)
z = z - max(z, [], 1);
p = exp(z) ./ sum(exp(z), 1);
end

function res = ternary(cond, a, b)
if cond, res = a; else, res = b; end
end
