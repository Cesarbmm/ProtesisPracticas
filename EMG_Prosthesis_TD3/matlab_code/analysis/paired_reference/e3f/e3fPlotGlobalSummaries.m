function files = e3fPlotGlobalSummaries(outDir, episodeTable, motorTable, catTable)
% e3fPlotGlobalSummaries genera tres figuras resumen globales estilo publicacion:
% 1. MOTOR_TRACKING_SUMMARY: MSE por M1-M4 separando TRAIN y VALIDATION.
% 2. OPENING_CLOSING_SUMMARY: MSE, flat_response, action_no_motion para OPENING y CLOSING.
% 3. PWM_USAGE_HEATMAP: M1-M4 vs 15 categorias PWM (fraccion de uso), TRAIN vs VALIDATION.

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

trainMotors = zeros(4, 1);
valMotors = zeros(4, 1);
for m = 1:4
    trainMotors(m) = mean(motorTable.trackingMSE(motorTable.motor == m & motorTable.split == "TRAIN"));
    valMotors(m) = mean(motorTable.trackingMSE(motorTable.motor == m & motorTable.split == "VALIDATION"));
end

b = bar([trainMotors, valMotors], "grouped");
b(1).FaceColor = [0.2 0.5 0.8];
b(2).FaceColor = [0.9 0.4 0.2];
grid on;
ax = gca;
ax.GridAlpha = 0.25;
set(gca, "XTickLabel", {"Motor 1", "Motor 2", "Motor 3", "Motor 4"}, "FontSize", 10);
ylabel("Tracking MSE", FontWeight="bold", FontSize=11);
legend({"TRAIN (140 ep)", "VALIDATION (60 ep)"}, Location="northeast", Box="off", FontSize=10);
title("E3F FINAL: Motor Tracking MSE (TRAIN vs VALIDATION)", FontWeight="bold", FontSize=12);

exportgraphics(f1, files.motorSummaryPng, Resolution=150);
savefig(f1, files.motorSummaryFig);
if isgraphics(f1), close(f1); end

% --------------------------------------------------------------------------
% 2. OPENING_CLOSING_SUMMARY
% --------------------------------------------------------------------------
f2 = figure(Visible="off", Color="w", Position=[100 100 900 550]);
cleanup2 = onCleanup(@() closeOwnFigure(f2)); %#ok<NASGU>

% side: 1 = closing, 2 = opening
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
b2(1).FaceColor = [0.25 0.65 0.4];
b2(2).FaceColor = [0.85 0.45 0.2];
grid on;
ax2 = gca;
ax2.GridAlpha = 0.25;
set(gca, "XTickLabel", metricsLabels, "FontSize", 10);
ylabel("Magnitud / Fraccion", FontWeight="bold", FontSize=11);
legend({"CIERRE (100 ep)", "APERTURA (100 ep)"}, Location="northeast", Box="off", FontSize=10);
title("E3F FINAL: Comparacion Apertura vs Cierre", FontWeight="bold", FontSize=12);

exportgraphics(f2, files.openCloseSummaryPng, Resolution=150);
savefig(f2, files.openCloseSummaryFig);
if isgraphics(f2), close(f2); end

% --------------------------------------------------------------------------
% 3. PWM_USAGE_HEATMAP
% --------------------------------------------------------------------------
f3 = figure(Visible="off", Color="w", Position=[100 100 1200 600]);
cleanup3 = onCleanup(@() closeOwnFigure(f3)); %#ok<NASGU>

layout = tiledlayout(f3, 1, 2, TileSpacing="compact", Padding="compact");
levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
[sortedLevels, sortIdx] = sort(levels);

for sIdx = 1:2
    spl = "TRAIN";
    if sIdx == 2, spl = "VALIDATION"; end
    subT = catTable(catTable.split == spl, :);

    H = zeros(4, 15);
    for m = 1:4
        mRows = subT(subT.motor == m, :);
        totalCmds = sum(mRows.steps);
        for c = 1:15
            H(m, c) = sum(mRows.("category" + c)) / totalCmds;
        end
    end
    H_sorted = H(:, sortIdx);

    axH = nexttile(layout);
    imagesc(axH, H_sorted);
    colormap(axH, "parula");
    colorbar(axH);
    clim(axH, [0 max(H_sorted(:)) * 1.05]);

    set(axH, "XTick", 1:15, "XTickLabel", string(sortedLevels), "XTickLabelRotation", 45);
    set(axH, "YTick", 1:4, "YTickLabel", {"M1", "M2", "M3", "M4"});
    title(axH, sprintf("%s (Uso Relativo PWM)", spl), FontWeight="bold", FontSize=11);
    xlabel(axH, "Nivel PWM");
    ylabel(axH, "Motor");
end

title(layout, "E3F FINAL: Distribucion de Uso de Categorias PWM por Motor", FontWeight="bold", FontSize=12);

exportgraphics(f3, files.pwmHeatmapPng, Resolution=150);
savefig(f3, files.pwmHeatmapFig);
if isgraphics(f3), close(f3); end
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
