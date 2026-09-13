function pcaSummary = e3eAuditPCA()
% e3eAuditPCA: PCA diagnóstica ajustada SÓLO en TRAIN y proyectada en TRAIN y VALIDATION.
cfg = e3eConfig();
if ~isfolder(cfg.output), mkdir(cfg.output); end
figDir = fullfile(cfg.output, "figures");
if ~isfolder(figDir), mkdir(figDir); end

a = load(cfg.dataPath, "D");
D = a.D;
S = D.samples;

N_samples = height(S);
X = zeros(N_samples, 40);

for e = 1:200
    epIx = find(S.episode == e);
    states = D.sequences{e}.state; % 52 x T
    X(epIx, :) = states(1:40, :)';
end

trainMask = (S.split == "TRAIN");
valMask = (S.split == "VALIDATION");

% FIT PCA: TRAIN SOLAMENTE (sin tocar VALIDATION)
X_train = X(trainMask, :);
mu_train = mean(X_train, 1);
std_train = std(X_train, 0, 1);
std_train(std_train < 1e-12) = 1;

% Estandarización basada únicamente en TRAIN
X_train_std = (X_train - mu_train) ./ std_train;
[coeff, score_train, latent, explained] = e3eStats.pca(X_train_std);

% Proyección de VALIDATION sin refit
X_val = X(valMask, :);
X_val_std = (X_val - mu_train) ./ std_train;
score_val = X_val_std * coeff;

% Combinar proyecciones para visualización y análisis
score_all = zeros(N_samples, size(coeff, 2));
score_all(trainMask, :) = score_train;
score_all(valMask, :) = score_val;

% Guardar datos de PCA
pcaData = struct(...
    "coeff", coeff, ...
    "mu_train", mu_train, ...
    "std_train", std_train, ...
    "explained", explained, ...
    "score_all", score_all, ...
    "split", S.split, ...
    "subject", S.subject, ...
    "side", S.side);
save(fullfile(cfg.output, "pca_diagnostic_data.mat"), "pcaData", "-v7.3");

%% ==========================================
% FIGURAS DIAGNÓSTICAS
% ==========================================
set(0, 'DefaultFigureVisible', 'off');

% Figura A: Proyección PCA coloreada por SUJETO
figA = figure('Position', [100 100 1000 700], 'Visible', 'off');
hold on; grid on; box on;
allSubs = [cfg.trainSubjects, cfg.validationSubjects];
colors = lines(numel(allSubs));

for i = 1:numel(allSubs)
    sub = allSubs(i);
    subIx = (S.subject == sub);
    isVal = ismember(sub, cfg.validationSubjects);
    marker = 'o';
    if isVal, marker = '^'; end
    scatter(score_all(subIx, 1), score_all(subIx, 2), 20, colors(i, :), marker, ...
        'filled', 'DisplayName', sprintf("%s (%s)", sub, ternary(isVal, "VAL", "TRAIN")), ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.2);
end
xlabel(sprintf("PC1 (%.2f%% varianza TRAIN)", explained(1)), 'FontSize', 12, 'FontWeight', 'bold');
ylabel(sprintf("PC2 (%.2f%% varianza TRAIN)", explained(2)), 'FontSize', 12, 'FontWeight', 'bold');
title("E3E — Proyección PCA de WMoos40 coloreada por Sujeto (Fit en TRAIN)", 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'eastoutside', 'FontSize', 9);
saveas(figA, fullfile(figDir, "pca_by_subject.png"));
savefig(figA, fullfile(figDir, "pca_by_subject.fig"));
close(figA);

% Figura B: Proyección PCA coloreada por INTENCIÓN (Opening vs Closing)
figB = figure('Position', [100 100 1000 700], 'Visible', 'off');
hold on; grid on; box on;

% TRAIN
trClose = trainMask & (S.side == 1);
trOpen = trainMask & (S.side == 2);
valClose = valMask & (S.side == 1);
valOpen = valMask & (S.side == 2);

scatter(score_all(trClose, 1), score_all(trClose, 2), 15, [0.2 0.4 0.8], 'o', 'filled', ...
    'DisplayName', 'TRAIN Closing', 'MarkerFaceAlpha', 0.5);
scatter(score_all(trOpen, 1), score_all(trOpen, 2), 15, [0.8 0.2 0.2], 'o', 'filled', ...
    'DisplayName', 'TRAIN Opening', 'MarkerFaceAlpha', 0.5);
scatter(score_all(valClose, 1), score_all(valClose, 2), 25, [0.1 0.2 0.9], '^', 'filled', ...
    'DisplayName', 'VALIDATION Closing', 'MarkerEdgeColor', 'k');
scatter(score_all(valOpen, 1), score_all(valOpen, 2), 25, [0.9 0.1 0.1], '^', 'filled', ...
    'DisplayName', 'VALIDATION Opening', 'MarkerEdgeColor', 'k');

xlabel(sprintf("PC1 (%.2f%% varianza TRAIN)", explained(1)), 'FontSize', 12, 'FontWeight', 'bold');
ylabel(sprintf("PC2 (%.2f%% varianza TRAIN)", explained(2)), 'FontSize', 12, 'FontWeight', 'bold');
title("E3E — Proyección PCA de WMoos40 coloreada por Intención (Fit en TRAIN)", 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
saveas(figB, fullfile(figDir, "pca_by_intent.png"));
savefig(figB, fullfile(figDir, "pca_by_intent.fig"));
close(figB);

pcaSummary = struct(...
    "PC1_explained", explained(1), ...
    "PC2_explained", explained(2), ...
    "PC1_to_PC5_explained", sum(explained(1:5)), ...
    "PC1_to_PC10_explained", sum(explained(1:10)));

fid = fopen(fullfile(cfg.output, "pca_summary.json"), "w");
fprintf(fid, "%s", jsonencode(pcaSummary, PrettyPrint=true));
fclose(fid);

fprintf("PCA diagnóstica completada exitosamente.\n");
end

function res = ternary(cond, a, b)
if cond, res = a; else, res = b; end
end
