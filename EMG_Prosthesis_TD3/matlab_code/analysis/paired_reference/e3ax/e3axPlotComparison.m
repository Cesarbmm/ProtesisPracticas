function files = e3axPlotComparison(macro, out)
%e3axPlotComparison dibuja las seis politicas de una misma particion.
% Estilo derivado de createCandidateComparisonFigure en el audit TD3 historico
% y e2fPlotResults. Usa las metricas agregadas suministradas, sin reagregarlas.
% m3Reversals debe ser explicito: directionFailures global no es un sustituto.

arguments
    macro table
    out (1, 1) string
end

names = string(macro.Properties.VariableNames);
assert(height(macro) == 6 && ismember("controller", names), ...
    "E3AX:ComparisonPolicies", "Se requieren seis filas con controller.");
if ismember("rewardMean", names)
    rewardField = "rewardMean";
elseif ismember("reward", names)
    rewardField = "reward";
else
    error("E3AX:ComparisonMetrics", "Falta rewardMean o reward.");
end
fields = ["trackingMSE", rewardField, "actionL2", "deltaActionL2", ...
    "saturationFraction", "persistentTwoCycle", "m3Reversals"];
assert(all(ismember(fields, names)), "E3AX:ComparisonMetrics", ...
    "Faltan metricas; m3Reversals debe suministrarse por separado.");
controllers = string(macro.controller);
assert(numel(unique(controllers)) == 6, "E3AX:ComparisonPolicies", ...
    "Las seis politicas deben ser distintas.");
labels = controllers;
for i = 1:numel(labels)
    code = upper(controllers(i));
    if contains(code, "ORACLE")
        labels(i) = controllers(i) + " (privilegiado: teacher futuro)";
    elseif ismember(code, ["P2", "P_2", "P_2.0"])
        labels(i) = controllers(i) + " (privilegiado: teacher)";
    end
end
titles = ["Tracking MSE", "Reward", "Magnitud de accion", "Cambio de accion", ...
    "Fraccion de saturacion", "Ciclos persistentes", "Reversiones de direccion M3"];
yLabels = ["MSE", rewardField, "actionL2", "deltaActionL2", "saturationFraction", ...
    "persistentTwoCycle (conteo)", "m3Reversals (conteo)"];
if ~isfolder(out), mkdir(out); end
stem = string(fullfile(out, "policy_comparison"));
files = struct("fig", stem + ".fig", "png", stem + ".png", ...
    "svg", stem + ".svg", "pdf", stem + ".pdf");
f = figure(Visible="off", Color="w", Position=[100 100 1650 1000]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>
layout = tiledlayout(f, 2, 4, TileSpacing="compact", Padding="compact");
for i = 1:numel(fields)
    values = macro.(fields(i));
    assert(isnumeric(values) && isreal(values) && isequal(size(values), [6 1]), ...
        "E3AX:ComparisonMetrics", "La metrica %s debe contener seis valores.", fields(i));
    ax = nexttile(layout);
    bar(ax, 1:6, values, .65, FaceColor=[.12 .47 .71]);
    xticks(ax, 1:6);
    xticklabels(ax, labels);
    ax.TickLabelInterpreter = "none";
    xtickangle(ax, 45);
    ylabel(ax, yLabels(i), Interpreter="none");
    title(ax, titles(i), Interpreter="none");
    grid(ax, "on");
end
title(layout, "Seis politicas sobre los mismos episodios", Interpreter="none");
exportgraphics(f, files.png, Resolution=180);
savefig(f, files.fig);
print(f, files.svg, "-dsvg");
exportgraphics(f, files.pdf, ContentType="vector");
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
