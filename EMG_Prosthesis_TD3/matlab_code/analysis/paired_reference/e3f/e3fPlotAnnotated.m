function files = e3fPlotAnnotated(trace, folder, reason)
% e3fPlotAnnotated genera figura ANNOTATED con acciones efectivas y probabilidades
% en las transiciones de categoria PWM. Exporta PNG, FIG, CSV y MAT.
% Nombres: {SUBJECT}_row{ROW:04d}_{DIRECTION}_annotated.png/fig/csv/mat

arguments
    trace (1, 1) struct
    folder (1, 1) string
    reason (1, 1) string = ""
end

assert(all(isfield(trace, ["metadata", "reference", "prediction", "pwm", "effectiveAction"])), ...
    "E3F:AnnotatedPlotSchema", "Faltan campos requeridos.");
ref = trace.reference;
pred = trace.prediction;
pwm = trace.pwm;
eff = trace.effectiveAction;
n = size(ref, 1);

md = trace.metadata;
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3F:AnnotatedPlotMetadata", "Falta repetition o row en metadata.");
end
subject = string(md.subject);
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
directionLabels = ["CIERRE", "APERTURA"];
dirStr = directions(md.side);
dirLabel = directionLabels(md.side);

stem = safeSubject + compose("_row%04d_", row) + dirStr + "_annotated";
pngDir = fullfile(folder, "PNG");
figDir = fullfile(folder, "FIG");
csvDir = fullfile(folder, "CSV");
matDir = fullfile(folder, "MAT");
for d = [pngDir, figDir, csvDir, matDir]
    if ~isfolder(d), mkdir(d); end
end

files = struct("png", string(fullfile(pngDir, stem + ".png")), ...
               "fig", string(fullfile(figDir, stem + ".fig")), ...
               "csv", string(fullfile(csvDir, stem + ".csv")), ...
               "mat", string(fullfile(matDir, stem + ".mat")));

% Crear tabla diagnostica y guardar CSV y MAT
rows = [];
for step = 1:n
    sRow = struct("step", step, ...
        "ref_m1", ref(step, 1), "ref_m2", ref(step, 2), "ref_m3", ref(step, 3), "ref_m4", ref(step, 4), ...
        "hq_m1", pred(step, 1), "hq_m2", pred(step, 2), "hq_m3", pred(step, 3), "hq_m4", pred(step, 4), ...
        "pwm_m1", pwm(step, 1), "pwm_m2", pwm(step, 2), "pwm_m3", pwm(step, 3), "pwm_m4", pwm(step, 4), ...
        "effectiveAction_m1", eff(step, 1), "effectiveAction_m2", eff(step, 2), ...
        "effectiveAction_m3", eff(step, 3), "effectiveAction_m4", eff(step, 4));
    if isfield(trace, "selectedProbability")
        sRow.prob_m1 = trace.selectedProbability(step, 1);
        sRow.prob_m2 = trace.selectedProbability(step, 2);
        sRow.prob_m3 = trace.selectedProbability(step, 3);
        sRow.prob_m4 = trace.selectedProbability(step, 4);
    end
    if isempty(rows)
        rows = sRow;
    else
        rows(end+1) = sRow; %#ok<AGROW>
    end
end
diagnosticTable = struct2table(rows);
writetable(diagnosticTable, files.csv);
save(files.mat, "diagnosticTable", "trace", "reason");

% Generar figura ANNOTATED
f = figure(Visible="off", Color="w", Position=[80 80 1250 1100]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>

layout = tiledlayout(f, 4, 1, TileSpacing="compact", Padding="compact");
x = 1:n;

for m = 1:4
    ax = nexttile(layout);
    plot(ax, x, pred(:, m), "-o", Color=[0 0.447 0.741], LineWidth=1.6, MarkerSize=4, ...
        DisplayName="Protesis h(q)", Tag="prediction");
    hold(ax, "on");
    plot(ax, x, ref(:, m), "--", Color=[0.85 0.325 0.098], LineWidth=1.8, ...
        DisplayName="Teacher", Tag="reference");

    % Anotaciones en transiciones
    for k = 1:n
        isTrans = (k == 1) || (pwm(k, m) ~= pwm(k-1, m));
        if isTrans
            actionVal = eff(k, m);
            if actionVal == 0
                lbl = "0";
            else
                lbl = sprintf("%+.2f", actionVal);
            end
            if isfield(trace, "selectedProbability")
                pVal = trace.selectedProbability(k, m);
                lbl = sprintf("%s (p=%.2f)", lbl, pVal);
            end

            % Alternar ligeramente arriba o abajo para evitar colision
            yPos = pred(k, m) + 0.035 + 0.02 * mod(k, 2);
            text(ax, k, yPos, lbl, FontSize=7.5, Color=[0.15 0.15 0.15], ...
                HorizontalAlignment="center", Tag="effectiveActionLabel", ...
                BackgroundColor=[1 1 1 0.75], Margin=1);
        end
    end

    grid(ax, "on");
    ax.GridAlpha = 0.25;
    title(ax, sprintf("Motor %d", m), FontWeight="bold", FontSize=10, Interpreter="none");
    ylabel(ax, "Escala h / teacher", FontSize=9);
    xlim(ax, [0.5 n + 0.5]);
    yMin = min([pred(:, m); ref(:, m)]) - 0.05;
    yMax = max([pred(:, m); ref(:, m)]) + 0.12;
    ylim(ax, [yMin yMax]);

    if m == 1
        legend(ax, Location="northwest", Orientation="horizontal", Box="off", FontSize=9);
    end
    if m == 4
        xlabel(ax, "Paso del episodio | texto: accion efectiva PWM/255 (probabilidad)", FontWeight="bold", FontSize=9);
    else
        ax.XTickLabel = [];
    end
end

header = sprintf("E3F FINAL ANNOTATED | %s | fila %d | %s", subject, row, dirLabel);
if strlength(reason) > 0
    header = header + " | " + reason;
end
title(layout, header, FontSize=11, FontWeight="bold", Interpreter="none");

exportgraphics(f, files.png, Resolution=150);
savefig(f, files.fig);
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
