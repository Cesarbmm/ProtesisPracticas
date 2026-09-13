function files = e4PlotGlobalSummaries(outDir, episodeTable, motorTable, catTable)
% e4PlotGlobalSummaries genera tres figuras resumen globales estilo publicacion para E4:
% 1. MOTOR_TRACKING_SUMMARY: MSE por M1-M4 para los 10 sujetos DEVELOPMENT.
% 2. OPENING_CLOSING_SUMMARY: MSE, flat_response, action_no_motion para OPENING y CLOSING.
% 3. PWM_USAGE_HEATMAP: M1-M4 vs 15 categorias PWM (fraccion de uso) en DEVELOPMENT.

figFolder = fullfile(outDir, "evaluation", "final_checkpoint", "figures");
if ~isfolder(figFolder), mkdir(figFolder); end

files = struct();
files.motorSummaryPng = string(fullfile(figFolder, "MOTOR_TRACKING_SUMMARY.png"));
files.motorSummaryFig = string(fullfile(figFolder, "MOTOR_TRACKING_SUMMARY.fig"));
files.openCloseSummaryPng = string(fullfile(figFolder, "OPENING_CLOSING_SUMMARY.png"));
files.openCloseSummaryFig = string(fullfile(figFolder, "OPENING_CLOSING_SUMMARY.fig"));
files.pwmHeatmapPng = string(fullfile(figFolder, "PWM_USAGE_HEATMAP.png"));
files.pwmHeatmapFig = string(fullfile(figFolder, "PWM_USAGE_HEATMAP.fig"));

% --------------------------------------------------------------------------
% 1. MOTOR_TRACKING_SUMMARY
% --------------------------------------------------------------------------
f1 = figure(Visible="off", Color="w", Position=[100 100 800 550]);
cleanup1 = onCleanup(@() closeOwnFigure(f1)); %#ok<NASGU>

motors = zeros(4, 1);
for m = 1:4
    motors(m) = mean(motorTable.trackingMSE(motorTable.motor == m));
end

b = bar(motors, "FaceColor", [0.15 0.45 0.75], "EdgeColor", "none", "BarWidth", 0.55);
grid on;
ax = gca;
ax.GridAlpha = 0.25;
set(gca, "XTickLabel", {"Motor 1", "Motor 2", "Motor 3", "Motor 4"}, "FontSize", 10.5);
ylabel("Tracking MSE", FontWeight="bold", FontSize=11);
title("E4 FINAL DEVELOPMENT: Tracking MSE por Motor (200 ep DEVELOPMENT)", FontWeight="bold", FontSize=12);

% Anotar valores sobre las barras
for m = 1:4
    text(m, motors(m) + max(motors)*0.03, sprintf("%.4f", motors(m)), ...
        HorizontalAlignment="center", FontWeight="bold", FontSize=10, Color=[0.1 0.1 0.1]);
end
ylim([0, max(motors) * 1.15]);

exportgraphics(f1, files.motorSummaryPng, Resolution=150);
savefig(f1, files.motorSummaryFig);
if isgraphics(f1), close(f1); end

% --------------------------------------------------------------------------
% 2. OPENING_CLOSING_SUMMARY
% --------------------------------------------------------------------------
f2 = figure(Visible="off", Color="w", Position=[100 100 900 550]);
cleanup2 = onCleanup(@() closeOwnFigure(f2)); %#ok<NASGU>

closeIdx = (episodeTable.side == 1);
openIdx = (episodeTable.side == 2);

metricsLabels = ["Tracking MSE", "Flat Response Frac", "Action No Motion Frac"];
closeVals = [mean(episodeTable.trackingMSE(closeIdx)), ...
             mean(episodeTable.flat_response(closeIdx)), ...
             mean(episodeTable.action_no_motion(closeIdx))];
openVals = [mean(episodeTable.trackingMSE(openIdx)), ...
            mean(episodeTable.flat_response(openIdx)), ...
            mean(episodeTable.action_no_motion(openIdx))];

b2 = bar([closeVals; openVals]', "grouped");
b2(1).FaceColor = [0.2 0.6 0.4]; % Cierre verde azulado
b2(2).FaceColor = [0.85 0.45 0.15]; % Apertura naranja
grid on;
ax2 = gca;
ax2.GridAlpha = 0.25;
set(gca, "XTickLabel", cellstr(metricsLabels), "FontSize", 10.5);
ylabel("Magnitud / Fraccion", FontWeight="bold", FontSize=11);
legend({"CIERRE (100 ep)", "APERTURA (100 ep)"}, Location="northeast", Box="off", FontSize=10.5);
title("E4 FINAL DEVELOPMENT: Comparativa CIERRE vs APERTURA", FontWeight="bold", FontSize=12);

exportgraphics(f2, files.openCloseSummaryPng, Resolution=150);
savefig(f2, files.openCloseSummaryFig);
if isgraphics(f2), close(f2); end

% --------------------------------------------------------------------------
% 3. PWM_USAGE_HEATMAP
% --------------------------------------------------------------------------
f3 = figure(Visible="off", Color="w", Position=[100 100 1000 550]);
cleanup3 = onCleanup(@() closeOwnFigure(f3)); %#ok<NASGU>

levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
H = zeros(4, 15);
for m = 1:4
    tot = 0;
    cnt = zeros(1, 15);
    for c = 1:15
        cnt(c) = sum(catTable.("category" + c)(catTable.motor == m));
    end
    tot = sum(cnt);
    if tot > 0, H(m, :) = cnt / tot; end
end

imagesc(H);
colormap(f3, "hot");
c = colorbar;
c.Label.String = "Fraccion de uso";
c.Label.FontSize = 10;
caxis([0, max(H(:)) * 1.1]);

set(gca, "YTick", 1:4, "YTickLabel", {"Motor 1", "Motor 2", "Motor 3", "Motor 4"}, "FontSize", 10.5);
xLabels = arrayfun(@(v) sprintf("%+d", v), levels, "UniformOutput", false);
xLabels{1} = "0";
set(gca, "XTick", 1:15, "XTickLabel", xLabels, "XTickLabelRotation", 45, "FontSize", 9.5);
xlabel("Comando PWM Discreto", FontWeight="bold", FontSize=11);
title("E4 FINAL DEVELOPMENT: Mapa de Calor de Uso de PWM (10 Sujetos)", FontWeight="bold", FontSize=12);

exportgraphics(f3, files.pwmHeatmapPng, Resolution=150);
savefig(f3, files.pwmHeatmapFig);
if isgraphics(f3), close(f3); end
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
