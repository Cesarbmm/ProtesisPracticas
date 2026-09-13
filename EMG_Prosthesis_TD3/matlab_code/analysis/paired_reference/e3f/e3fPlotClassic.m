function files = e3fPlotClassic(trace, folder)
% e3fPlotClassic genera la figura de formato CLASSIC (4x2, formato historico de test)
% 4 filas (Motores 1-4) x 2 columnas:
% LEFT:  POLICY / CATEGORY VIEW (h(q), Teacher, red dot, effectiveAction = PWM/255, prob)
% RIGHT: EFFECTIVE PWM VIEW (h(q), Teacher, red 'x', effectiveAction = PWM/255, PWM)
%
% Nombres: {SUBJECT}_row{ROW:04d}_{DIRECTION}_classic.png/fig

arguments
    trace (1, 1) struct
    folder (1, 1) string
end

assert(all(isfield(trace, ["metadata", "reference", "prediction", "pwm", "effectiveAction"])), ...
    "E3F:ClassicPlotSchema", "Faltan campos requeridos.");
ref = trace.reference;
pred = trace.prediction;
pwm = trace.pwm;
eff = trace.effectiveAction;
n = size(ref, 1);
assert(n >= 1 && size(ref, 2) == 4 && size(pred, 2) == 4, "E3F:ClassicPlotShape", "Dimensiones invalidas.");

md = trace.metadata;
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3F:ClassicPlotMetadata", "Falta repetition o row en metadata.");
end
subject = string(md.subject);
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
directionLabels = ["CIERRE", "APERTURA"];
dirStr = directions(md.side);
dirLabel = directionLabels(md.side);

stem = safeSubject + compose("_row%04d_", row) + dirStr + "_classic";
if ~isfolder(folder), mkdir(folder); end
files = struct("png", string(fullfile(folder, stem + ".png")), ...
               "fig", string(fullfile(folder, stem + ".fig")));

f = figure(Visible="off", Color="w", Position=[50 50 1450 1050]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>

isLegacyTD3 = isfield(trace, "rawAction") && ~isfield(trace, "selectedProbability");

for i = 1:4
    % Columna Izquierda
    ax1 = subplot(4, 2, 2*i-1, "Parent", f);
    cla(ax1); hold(ax1, "on");
    plot(ax1, pred(:, i), "-", "Color", [0 0.447 0.741], "LineWidth", 1.6, "DisplayName", "Protesis h(q)");
    plot(ax1, ref(:, i), "--", "Color", [0.85 0.325 0.098], "LineWidth", 1.6, "DisplayName", "Teacher");

    for j = 1:n
        plot(ax1, j, pred(j, i), "r.", "MarkerSize", 8, "HandleVisibility", "off");
        if isLegacyTD3
            valStr = sprintf("%.2f", trace.rawAction(j, i));
            text(ax1, j, pred(j, i), valStr, ...
                "VerticalAlignment", "bottom", "HorizontalAlignment", "right", "FontSize", 9.5);
        else
            effVal = eff(j, i);
            if abs(effVal) < 1e-6, effVal = 0; end
            valStr = sprintf("%.2f", effVal);
            text(ax1, j, pred(j, i), valStr, ...
                "VerticalAlignment", "bottom", "HorizontalAlignment", "right", "FontSize", 9.5, ...
                "Color", [0.1 0.1 0.1]);
            if isfield(trace, "selectedProbability")
                pVal = trace.selectedProbability(j, i);
                text(ax1, j, pred(j, i), sprintf("p=%.2f", pVal), ...
                    "VerticalAlignment", "top", "HorizontalAlignment", "center", ...
                    "FontSize", 6.5, "Color", [0.15 0.15 0.7]);
            end
        end
    end
    grid(ax1, "on"); ax1.GridAlpha = 0.2;
    ylabel(ax1, sprintf("Motor %d", i), "FontWeight", "bold");
    xlim(ax1, [0.5 n + 0.5]);
    yMin = min([pred(:, i); ref(:, i)]) - 0.06;
    yMax = max([pred(:, i); ref(:, i)]) + 0.08;
    ylim(ax1, [yMin yMax]);

    % Columna Derecha
    ax2 = subplot(4, 2, 2*i, "Parent", f);
    cla(ax2); hold(ax2, "on");
    plot(ax2, pred(:, i), "-", "Color", [0 0.447 0.741], "LineWidth", 1.6, "DisplayName", "Protesis h(q)");
    plot(ax2, ref(:, i), "--", "Color", [0.85 0.325 0.098], "LineWidth", 1.6, "DisplayName", "Teacher");

    for j = 1:n
        plot(ax2, j, pred(j, i), "rx", "MarkerSize", 6, "LineWidth", 1.2, "HandleVisibility", "off");
        if isLegacyTD3
            satVal = trace.effectiveAction(j, i);
            text(ax2, j, pred(j, i), sprintf("%.2f", satVal), ...
                "VerticalAlignment", "bottom", "HorizontalAlignment", "left", "FontSize", 9.5, "Color", "black");
            if isfield(trace, "reward") && numel(trace.reward) >= j
                text(ax2, j, pred(j, i), sprintf("%.2f", trace.reward(j)), ...
                    "VerticalAlignment", "top", "HorizontalAlignment", "center", "FontSize", 6.5, "Color", [0.3 0.3 0.3]);
            end
        else
            effVal = eff(j, i);
            if abs(effVal) < 1e-6, effVal = 0; end
            valStr = sprintf("%.2f", effVal);
            text(ax2, j, pred(j, i), valStr, ...
                "VerticalAlignment", "bottom", "HorizontalAlignment", "left", "FontSize", 9.5, "Color", "black");
            pwmVal = pwm(j, i);
            text(ax2, j, pred(j, i), sprintf("PWM:%+d", pwmVal), ...
                "VerticalAlignment", "top", "HorizontalAlignment", "center", ...
                "FontSize", 6.5, "Color", [0.1 0.5 0.1]);
        end
    end
    grid(ax2, "on"); ax2.GridAlpha = 0.2;
    ylabel(ax2, sprintf("Motor %d", i), "FontWeight", "bold");
    xlim(ax2, [0.5 n + 0.5]);
    ylim(ax2, [yMin yMax]);

    if i == 1
        if isLegacyTD3
            title(ax1, sprintf("LEGACY TD3 | %s | row %d | LEFT: RAW ACTION", subject, row), "FontWeight", "bold", "FontSize", 10.5);
            title(ax2, sprintf("LEGACY TD3 | %s | row %d | RIGHT: EFFECTIVE ACTION & REWARD", subject, row), "FontWeight", "bold", "FontSize", 10.5);
        else
            title(ax1, sprintf("E3F CLASSIC | %s | fila %d | %s | LEFT: POLICY / CATEGORY VIEW", subject, row, dirLabel), "FontWeight", "bold", "FontSize", 10.5);
            title(ax2, sprintf("E3F CLASSIC | %s | fila %d | %s | RIGHT: EFFECTIVE PWM VIEW", subject, row, dirLabel), "FontWeight", "bold", "FontSize", 10.5);
        end
        legend(ax1, "Location", "northwest", "Orientation", "horizontal", "Box", "off", "FontSize", 8.5);
    elseif i == 4
        xlabel(ax1, "Step in episode", "FontWeight", "bold");
        xlabel(ax2, "Step in episode", "FontWeight", "bold");
    else
        ax1.XTickLabel = [];
        ax2.XTickLabel = [];
    end
end

exportgraphics(f, files.png, Resolution=140);
savefig(f, files.fig);
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
