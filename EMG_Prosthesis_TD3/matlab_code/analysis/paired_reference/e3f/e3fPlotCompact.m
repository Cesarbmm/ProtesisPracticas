function files = e3fPlotCompact(trace, folder)
% e3fPlotCompact genera figura de formato COMPACT para un episodio medido.
% 4 paneles verticales (M1-M4), h(q) solida, Teacher discontinua, leyenda global unica.
% Guarda PNG y FIG con nomenclatura: {SUBJECT}_row{ROW:04d}_{DIRECTION}_compact.png/fig

arguments
    trace (1, 1) struct
    folder (1, 1) string
end

assert(all(isfield(trace, ["metadata", "reference", "prediction"])), ...
    "E3F:CompactPlotSchema", "Faltan metadata, reference o prediction.");
ref = trace.reference;
pred = trace.prediction;
assert(isnumeric(ref) && isnumeric(pred) && size(ref, 2) == 4 && size(pred, 2) == 4, ...
    "E3F:CompactPlotShape", "Reference y prediction deben ser Nx4.");

md = trace.metadata;
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3F:CompactPlotMetadata", "Falta repetition o row en metadata.");
end
subject = string(md.subject);
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
directionLabels = ["CIERRE", "APERTURA"];
dirStr = directions(md.side);
dirLabel = directionLabels(md.side);

stem = safeSubject + compose("_row%04d_", row) + dirStr + "_compact";
if ~isfolder(folder), mkdir(folder); end
files = struct("png", string(fullfile(folder, stem + ".png")), ...
               "fig", string(fullfile(folder, stem + ".fig")));

f = figure(Visible="off", Color="w", Position=[100 100 1100 950]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>

layout = tiledlayout(f, 4, 1, TileSpacing="compact", Padding="compact");
n = size(ref, 1);
x = 1:n;

for m = 1:4
    ax = nexttile(layout);
    plot(ax, x, pred(:, m), "-", Color=[0 0.447 0.741], LineWidth=1.8, ...
        DisplayName="Protesis h(q)", Tag="prediction");
    hold(ax, "on");
    plot(ax, x, ref(:, m), "--", Color=[0.85 0.325 0.098], LineWidth=1.8, ...
        DisplayName="Teacher", Tag="reference");
    hold(ax, "off");
    grid(ax, "on");
    ax.GridAlpha = 0.25;
    title(ax, sprintf("Motor %d", m), FontWeight="bold", FontSize=10, Interpreter="none");
    ylabel(ax, "Escala h / teacher", FontSize=9);
    xlim(ax, [0.8 n + 0.2]);
    yMin = min([pred(:, m); ref(:, m)]) - 0.05;
    yMax = max([pred(:, m); ref(:, m)]) + 0.05;
    ylim(ax, [yMin yMax]);

    if m == 1
        legend(ax, Location="northwest", Orientation="horizontal", Box="off", FontSize=9);
    end
    if m == 4
        xlabel(ax, "Paso del episodio", FontWeight="bold", FontSize=9);
    else
        ax.XTickLabel = [];
    end
end

header = sprintf("E3F FINAL | %s | fila %d | %s", subject, row, dirLabel);
title(layout, header, FontSize=11, FontWeight="bold", Interpreter="none");

exportgraphics(f, files.png, Resolution=150);
savefig(f, files.fig);
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
