function files = e3axPlotEpisode(trace, folder, label)
%e3axPlotEpisode exporta un episodio ya medido, sin ejecutar la politica.
% Derivado del bloque compacto createRepresentativeEpisodeFigure de
% workflows/legacy/run_longrun_td3_audit.m. Conserva sus dos curvas y colores;
% usa cuatro paneles verticales, escala h/teacher ya calculada, sin interpolar
% ni anotar acciones por muestra. Corrige sus etiquetas historicas de motor.
% folder debe separar checkpoint y split para evitar colisiones BEST/LAST.
% reference y prediction son Nx4, alineadas DESPUES de cada accion.

arguments
    trace (1, 1) struct
    folder (1, 1) string
    label (1, 1) string = ""
end

assert(all(isfield(trace, ["metadata", "reference", "prediction"])), ...
    "E3AX:EpisodePlotSchema", "Faltan metadata, reference o prediction.");
reference = trace.reference;
prediction = trace.prediction;
assert(isnumeric(reference) && isnumeric(prediction) && isreal(reference) && ...
    isreal(prediction) && isequal(size(reference), size(prediction)) && ...
    size(reference, 2) == 4 && size(reference, 1) >= 1 && ...
    all(isfinite(reference), "all") && all(isfinite(prediction), "all"), ...
    "E3AX:EpisodePlotShape", "Reference y prediction deben ser Nx4 finitas y alineadas.");
md = trace.metadata;
assert(isstruct(md) && isscalar(md) && all(isfield(md, ["subject", "side"])), ...
    "E3AX:EpisodePlotMetadata");
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3AX:EpisodePlotMetadata", "Falta repetition o row original del dataset.");
end
assert(isscalar(row) && isfinite(row) && row >= 1 && row == fix(row), ...
    "E3AX:EpisodePlotMetadata");
assert(isscalar(md.side) && ismember(md.side, [1 2]), "E3AX:EpisodePlotMetadata");
subject = string(md.subject);
assert(isscalar(subject) && ~ismissing(subject) && strlength(subject) > 0, ...
    "E3AX:EpisodePlotMetadata");
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
directionLabels = ["cierre", "apertura"];
stem = safeSubject + compose("_row%04d_", row) + directions(md.side);
if ~isfolder(folder), mkdir(folder); end
files = struct("png", string(fullfile(folder, stem + ".png")), ...
    "fig", string(fullfile(folder, stem + ".fig")));

f = figure(Visible="off", Color="w", Position=[100 100 1100 940]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>
f.UserData = struct("metadata", md, "label", label, ...
    "alignment", "reference_after versus h(q_after), unchanged recorded samples");
layout = tiledlayout(f, 4, 1, TileSpacing="compact", Padding="compact");
x = (1:size(reference, 1))';
for motor = 1:4
    ax = nexttile(layout);
    plot(ax, x, prediction(:, motor), "-", Color=[0 .45 .74], LineWidth=1.6, ...
        DisplayName="Protesis h(q)", Tag="prediction");
    hold(ax, "on");
    plot(ax, x, reference(:, motor), "--", Color=[.85 .33 .10], LineWidth=1.6, ...
        DisplayName="Referencia posterior", Tag="reference");
    hold(ax, "off");
    grid(ax, "on");
    title(ax, "Motor " + motor, Interpreter="none");
    ylabel(ax, "Escala h / teacher");
    if numel(x) > 1, xlim(ax, [x(1) x(end)]); end
    if motor == 1, legend(ax, Location="best", Box="off"); end
    if motor == 4, xlabel(ax, "Paso del episodio"); end
end
heading = [label, subject + compose(" | fila %d | ", row) + directionLabels(md.side)];
title(layout, strjoin(heading(strlength(heading) > 0), " | "), Interpreter="none");
exportgraphics(f, files.png, Resolution=180);
savefig(f, files.fig);
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
