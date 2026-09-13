function e3eCreateFigures()
% e3eCreateFigures: Genera las figuras diagnósticas completas de E3E.
cfg = e3eConfig();
figDir = fullfile(cfg.output, "figures");
if ~isfolder(figDir), mkdir(figDir); end

set(0, 'DefaultFigureVisible', 'off');

%% 1. FIGURA: ESTADÍSTICAS WMOOS POR SUJETO (Distribución de features por sujeto)
fprintf("Generando figura de estadísticas WMoos por sujeto...\n");
stats = load(fullfile(cfg.output, "feature_stats.mat"), "statsTable").statsTable;
allSubs = [cfg.trainSubjects, cfg.validationSubjects];

figStats = figure('Position', [100 100 1100 650], 'Visible', 'off');
% Graficamos la media de cada feature por sujeto (condición "all")
allStats = stats(stats.condition == "all", :);
subMeansMatrix = zeros(40, numel(allSubs));
for s = 1:numel(allSubs)
    subRows = allStats(allStats.subject == allSubs(s), :);
    subMeansMatrix(:, s) = subRows.mean;
end

subplot(2, 1, 1);
imagesc(subMeansMatrix');
colormap(parula);
colorbar;
yticks(1:numel(allSubs));
yticklabels(cellstr(allSubs));
xlabel("Índice de Feature WMoos (1..40)", 'FontWeight', 'bold');
title("E3E — Medias de Features WMoos40 por Sujeto (Firma de Identidad)", 'FontWeight', 'bold', 'FontSize', 12);

% Varianza entre sujetos vs intención (ANOVA eta-squared)
subplot(2, 1, 2);
vDecomp = readtable(fullfile(cfg.output, "variance_decomposition_by_feature.csv"));
bar([vDecomp.eta2_subject, vDecomp.eta2_intent]);
grid on; box on;
xlabel("Índice de Feature WMoos (1..40)", 'FontWeight', 'bold');
ylabel("Proporción de Varianza (\eta^2)", 'FontWeight', 'bold');
legend(["Sujeto (Identidad)", "Intención (Apertura vs Cierre)"], 'Location', 'northwest');
title("Descomposición de Varianza en TRAIN: Sujeto vs Intención", 'FontWeight', 'bold', 'FontSize', 12);

saveas(figStats, fullfile(figDir, "wmoos_stats_and_variance.png"));
savefig(figStats, fullfile(figDir, "wmoos_stats_and_variance.fig"));
close(figStats);

%% 2. FIGURA: COMPARACIÓN ORIGINAL VS NORMALIZED
fprintf("Generando figura comparativa ORIGINAL vs NORMALIZED...\n");
summary = jsondecode(fileread(fullfile(cfg.output, "scientific_summary.json")));
bm = summary.BASELINE_means;
nm = summary.NORMALIZED_means;

figComp = figure('Position', [100 100 1000 600], 'Visible', 'off');

% Panel 1: Métricas de Intención (Macro-F1)
subplot(1, 2, 1);
categories = categorical(["Direction VAL", "Phase-Dir VAL", "Subject-ID TRAIN"]);
categories = reordercats(categories, ["Direction VAL", "Phase-Dir VAL", "Subject-ID TRAIN"]);
barData1 = [
    bm.directionF1, nm.directionF1_VAL;
    bm.phaseDirectionF1, nm.phaseDirectionF1_VAL;
    summary.subjectID_original.SUBJECT_ID_ACCURACY, summary.subjectID_normalized.SUBJECT_ID_ACCURACY
];
b1 = bar(categories, barData1);
grid on; box on;
ylabel("Score / Precisión", 'FontWeight', 'bold');
legend(["ORIGINAL", "NORMALIZED"], 'Location', 'northwest');
title("Métricas de Intención y Firma de Sujeto", 'FontWeight', 'bold', 'FontSize', 12);
ylim([0 1.0]);

% Panel 2: Métricas de Control Closed-Loop (MSE y Reward)
subplot(1, 2, 2);
catClosed = categorical(["MSE Global", "MSE Apertura", "MSE Cierre"]);
catClosed = reordercats(catClosed, ["MSE Global", "MSE Apertura", "MSE Cierre"]);
barData2 = [
    bm.MSE, nm.globalMSE;
    bm.openingMSE, nm.openingMSE;
    bm.closingMSE, nm.closingMSE
];
b2 = bar(catClosed, barData2);
grid on; box on;
ylabel("MSE en VALIDATION", 'FontWeight', 'bold');
legend(["ORIGINAL", "NORMALIZED"], 'Location', 'northeast');
title("Control Closed-Loop en VALIDATION", 'FontWeight', 'bold', 'FontSize', 12);

saveas(figComp, fullfile(figDir, "original_vs_normalized_comparison.png"));
savefig(figComp, fullfile(figDir, "original_vs_normalized_comparison.fig"));
close(figComp);

%% 3. FIGURA: TRAZA CLOSED-LOOP REPRESENTATIVA (EPISODIO APERTURA Y CIERRE)
fprintf("Generando figura de trazas closed-loop representativas...\n");
clData = load(fullfile(cfg.output, "NORMALIZED_20260923", "closed_loop.mat"), "traces");
traces = clData.traces;

% Seleccionar un episodio de apertura de VALIDATION (ej. episodio 141 - JOE apertura)
% y uno de cierre (ej. episodio 142)
epOpen = traces{141};
epClose = traces{142};

figTrace = figure('Position', [100 100 1100 700], 'Visible', 'off');

% Apertura
subplot(2, 2, 1);
plot(epOpen.reference, 'k--', 'LineWidth', 1.5); hold on; grid on; box on;
plot(epOpen.prediction, 'LineWidth', 1.5);
title(sprintf("NORMALIZED seed 20260923 — Ep 141 (%s Apertura)", epOpen.metadata.subject), 'FontWeight', 'bold');
xlabel("Paso de Control", 'FontWeight', 'bold'); ylabel("Posición Normalizada", 'FontWeight', 'bold');
legend(["Ref 1", "Ref 2", "Ref 3", "Ref 4", "Pred 1", "Pred 2", "Pred 3", "Pred 4"], 'Location', 'eastoutside', 'FontSize', 8);

subplot(2, 2, 3);
stairs(epOpen.pwm, 'LineWidth', 1.2); grid on; box on;
xlabel("Paso de Control", 'FontWeight', 'bold'); ylabel("PWM Comandado", 'FontWeight', 'bold');
title("Comandos PWM Motores 1..4 (Apertura)", 'FontWeight', 'bold');

% Cierre
subplot(2, 2, 2);
plot(epClose.reference, 'k--', 'LineWidth', 1.5); hold on; grid on; box on;
plot(epClose.prediction, 'LineWidth', 1.5);
title(sprintf("NORMALIZED seed 20260923 — Ep 142 (%s Cierre)", epClose.metadata.subject), 'FontWeight', 'bold');
xlabel("Paso de Control", 'FontWeight', 'bold'); ylabel("Posición Normalizada", 'FontWeight', 'bold');

subplot(2, 2, 4);
stairs(epClose.pwm, 'LineWidth', 1.2); grid on; box on;
xlabel("Paso de Control", 'FontWeight', 'bold'); ylabel("PWM Comandado", 'FontWeight', 'bold');
title("Comandos PWM Motores 1..4 (Cierre)", 'FontWeight', 'bold');

saveas(figTrace, fullfile(figDir, "closed_loop_representative_traces.png"));
savefig(figTrace, fullfile(figDir, "closed_loop_representative_traces.fig"));
close(figTrace);

fprintf("Todas las figuras diagnósticas de E3E fueron generadas exitosamente en %s.\n", figDir);
end
