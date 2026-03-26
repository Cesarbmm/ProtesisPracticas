function build_charla_divulgativa_figures()
%BUILD_CHARLA_DIVULGATIVA_FIGURES Create simple figures for the outreach PDF.
%
% This script is optional. The figures it produces are already tracked in
% Git, but the generator is kept as source documentation for local rebuilds
% when the original experiment outputs are available in Agentes/.

scriptsDir = fileparts(mfilename("fullpath"));
docsRoot = fileparts(scriptsDir);
projectRoot = fileparts(docsRoot);
repoRoot = fileparts(projectRoot);
figRoot = fullfile(docsRoot, "figures");
if ~exist(figRoot, "dir")
    mkdir(figRoot);
end

trainingInfoFile = fullfile(repoRoot, "Agentes", "agent7250_residual_policy_pilot", ...
    "26-03-25 17 08 56", "training_run", "26-03-25 17 9 8", "training_info.mat");
episodeFile = fullfile(repoRoot, "Agentes", "agent7250_residual_policy_pilot", ...
    "26-03-25 17 08 56", "visual_test", "26-03-25 17 39 30", "episode00049.mat");

buildTimelineFigure(fullfile(figRoot, "charla_linea_proyecto_20260326.png"));
buildTrainingFigure(trainingInfoFile, fullfile(figRoot, "charla_training_residual_20260326.png"));
buildTestFigure(episodeFile, fullfile(figRoot, "charla_test_residual_20260326.png"));
buildComparisonFigure(fullfile(figRoot, "charla_comparacion_final_20260326.png"));
buildProjectComparisonFigure(fullfile(figRoot, "charla_comparacion_base_a_final_20260326.png"));
end

function buildTimelineFigure(outFile)
f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 420]);
ax = axes(f, "Position", [0.03 0.12 0.94 0.78]);
axis(ax, [0 1 0 1]);
axis(ax, "off");

boxes = [
    0.03 0.60 0.18 0.22
    0.28 0.60 0.18 0.22
    0.53 0.60 0.18 0.22
    0.78 0.60 0.18 0.22
    0.16 0.20 0.20 0.22
    0.46 0.20 0.20 0.22
    0.76 0.20 0.20 0.22];
labels = {
    'Base conceptual', 'Articulo base + TD3 continuo'
    'Limpieza del problema', 'Reward mas clara + fix del simulador'
    'Benchmark valido', 'Corrida de 8000 episodios -> Agent7250'
    'Exploraciones post-7250', 'Baja exploracion, saturacion, offline, warp'
    'Idea residual', 'No reemplazar la politica: corregirla'
    'Barridos alpha', '0.10, 0.20, 0.30 y refinamiento fino'
    'Punto final', 'Residual Agent1850 con alpha = 0.20'};
colors = [
    0.85 0.93 1.00
    0.92 0.96 0.86
    1.00 0.94 0.82
    0.97 0.89 0.89
    0.88 0.94 0.98
    0.94 0.90 0.98
    0.86 0.97 0.90];

for i = 1:size(boxes, 1)
    rectangle(ax, "Position", boxes(i, :), "Curvature", 0.04, ...
        "FaceColor", colors(i, :), "EdgeColor", [0.2 0.2 0.2], "LineWidth", 1.4);
    text(ax, boxes(i, 1)+0.01, boxes(i, 2)+boxes(i, 4)-0.05, labels{i, 1}, ...
        "FontWeight", "bold", "FontSize", 13, "Interpreter", "none");
    text(ax, boxes(i, 1)+0.01, boxes(i, 2)+0.05, labels{i, 2}, ...
        "FontSize", 11, "Interpreter", "none");
end

arrows = [
    0.21 0.71 0.07 0
    0.46 0.71 0.07 0
    0.71 0.71 0.07 0
    0.21 0.60 -0.02 -0.18
    0.46 0.60 0 -0.18
    0.71 0.60 0.07 -0.18];
for i = 1:size(arrows, 1)
    annotation(f, "arrow", [arrows(i, 1) arrows(i, 1)+arrows(i, 3)], ...
        [arrows(i, 2) arrows(i, 2)+arrows(i, 4)], "LineWidth", 1.6, ...
        "Color", [0.25 0.25 0.25]);
end

title(ax, "Linea simple del proyecto: de la base conceptual al resultado final", ...
    "FontSize", 16, "FontWeight", "bold");
exportgraphics(f, outFile, "Resolution", 180);
close(f);
end

function buildTrainingFigure(trainingInfoFile, outFile)
s = load(trainingInfoFile, "trainingInfo");
ti = s.trainingInfo;
episodes = ti.EpisodeIndex;
episodeReward = ti.EpisodeReward;
averageReward = ti.AverageReward;
episodeQ0 = ti.EpisodeQ0;

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1200 560]);
yyaxis left
plot(episodes, episodeReward, "Color", [0.00 0.45 0.74], "LineWidth", 1.0);
hold on
plot(episodes, averageReward, "Color", [0.93 0.69 0.13], "LineWidth", 2.2);
ylabel("Reward");

yyaxis right
plot(episodes, episodeQ0, "Color", [0.30 0.75 0.93], "LineWidth", 1.2);
ylabel("Q0");

xline(1850, "--k", "Agent1850", "LineWidth", 1.3, ...
    "LabelVerticalAlignment", "bottom", "LabelHorizontalAlignment", "left");
xlabel("Episodio");
grid on
title("Grafica de aprendizaje del mejor residual: azul, amarillo y celeste", ...
    "FontWeight", "bold");
legend({"Azul: reward de cada episodio", ...
        "Amarillo: promedio de reward", ...
        "Celeste: estimacion Q0 del critico", ...
        "Checkpoint final elegido"}, ...
        "Location", "southoutside", "NumColumns", 2);
exportgraphics(f, outFile, "Resolution", 180);
close(f);
end

function buildTestFigure(episodeFile, outFile)
s = load(episodeFile);
n = numel(s.flexConvertedLog);
t = 1:n;
gloveMean = zeros(n, 1);
prosthesisMean = zeros(n, 1);
actionMean = zeros(n, 1);

for k = 1:n
    gloveBlock = s.flexConvertedLog{k};
    prosthesisBlock = s.encoderAdjustedLog{k};
    gloveMean(k) = mean(gloveBlock(end, :));
    prosthesisMean(k) = mean(prosthesisBlock(end, :));
    actionMean(k) = mean(abs(s.effectiveActionLog(k, :)));
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1200 700]);
tiledlayout(f, 2, 1, "TileSpacing", "compact", "Padding", "compact");

nexttile
plot(t, gloveMean, "-o", "Color", [0.20 0.65 0.20], "LineWidth", 2.0, "MarkerSize", 5);
hold on
plot(t, prosthesisMean, "-s", "Color", [0.00 0.45 0.74], "LineWidth", 2.0, "MarkerSize", 5);
grid on
ylabel("Apertura media normalizada");
title("Grafica simple de test: referencia vs protesis", "FontWeight", "bold");
legend({"Verde: referencia del glove", "Azul: movimiento de la protesis"}, ...
    "Location", "southoutside", "NumColumns", 2);

nexttile
plot(t, actionMean, "-d", "Color", [0.85 0.33 0.10], "LineWidth", 2.0, "MarkerSize", 5);
grid on
xlabel("Paso del episodio");
ylabel("Magnitud media de la accion");
title("Grafica de accion: cuanto empuja el controlador", "FontWeight", "bold");
legend({"Naranja: accion efectiva media"}, "Location", "southoutside");

exportgraphics(f, outFile, "Resolution", 180);
close(f);
end

function buildComparisonFigure(outFile)
labels = categorical({'trackingMSE', 'actionL2', 'saturationFraction', 'deltaActionL2'});
labels = reordercats(labels, cellstr(labels));
agent7250 = [0.043045 0.596444 0.392086 0.321385];
residual = [0.043445 0.523597 0.272637 0.299262];

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1100 520]);
b = bar(labels, [agent7250; residual]');
b(1).FaceColor = [0.35 0.35 0.85];
b(2).FaceColor = [0.20 0.65 0.20];
grid on
ylabel("Valor de la metrica");
title("Comparacion final: benchmark vs residual final", "FontWeight", "bold");
legend({"Agent7250", "Residual Agent1850"}, "Location", "northwest");
text((1:4) - 0.18, agent7250 + 0.012, compose("%.3f", agent7250), "FontSize", 10, "Rotation", 90);
text((1:4) + 0.02, residual + 0.012, compose("%.3f", residual), "FontSize", 10, "Rotation", 90);
annotation(f, "textbox", [0.61 0.72 0.32 0.15], "String", ...
    "Lectura: en estas cuatro metricas, mas bajo es mejor. El residual casi no empeora tracking y mejora claramente esfuerzo y saturacion.", ...
    "FitBoxToText", "on", "BackgroundColor", [1 1 0.92], "EdgeColor", [0.6 0.6 0.4]);
exportgraphics(f, outFile, "Resolution", 180);
close(f);
end

function buildProjectComparisonFigure(outFile)
metrics = categorical({'trackingMSE', 'trackingMAE', 'actionL2', 'saturation'});
metrics = reordercats(metrics, cellstr(metrics));
baseline2000 = [0.052805 0.179093 0.674957 0.474999];
agent7250 = [0.043045 0.160336 0.596444 0.392086];
residual = [0.043445 0.163542 0.523597 0.272637];

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1280 620]);
b = bar(metrics, [baseline2000; agent7250; residual]');
b(1).FaceColor = [0.82 0.82 0.82];
b(2).FaceColor = [0.35 0.35 0.85];
b(3).FaceColor = [0.20 0.65 0.20];
grid on
ylabel("Valor de la metrica");
title("Comparacion de la linea valida: 2000 episodios, Agent7250 y residual final", ...
    "FontWeight", "bold");
legend({"Post-fix 2000", "Agent7250", "Residual Agent1850"}, ...
    "Location", "northwest");

annotation(f, "textbox", [0.60 0.70 0.30 0.16], "String", ...
    "Articulo base: MAE medio = 0.1553 y error aproximado del 10 al 15 por ciento. El paper no reporta actionL2 ni saturationFraction, asi que se usa solo como referencia historica.", ...
    "FitBoxToText", "on", "BackgroundColor", [0.97 0.96 0.88], ...
    "EdgeColor", [0.70 0.66 0.42]);

annotation(f, "textbox", [0.59 0.48 0.27 0.13], "String", ...
    "Lectura: desde 2000 episodios hasta el residual final, el tracking mejora fuerte frente al baseline inicial y el residual baja aun mas esfuerzo y saturacion respecto a Agent7250.", ...
    "FitBoxToText", "on", "BackgroundColor", [0.90 0.96 1.00], ...
    "EdgeColor", [0.45 0.62 0.78]);

exportgraphics(f, outFile, "Resolution", 180);
close(f);
end
