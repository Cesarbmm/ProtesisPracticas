function files = e3fPlotPro(trace, folder, split)
% e3fPlotPro genera figura PRO de calidad publicacion para un episodio medido.
% Incluye por cada motor:
% A) Panel principal: Teacher (discontinua) y h(q) (solida).
% B) Informacion de error: error_t = teacher_t - h(q_t) como linea fina alrededor de cero.
% C) Accion aplicada: PWM como stair plot en banda inferior con niveles reales.
% D) Marcadores UNICAMENTE en cambios de categoria PWM.
% E) Resumen por motor en caja: MSE, MAE, PWM0 %, DominantPWM, MaxCategoryFraction, M3 rev (en M3).
% Informacion global en encabezado/pie.
% Guarda PNG y FIG con nomenclatura: {SUBJECT}_row{ROW:04d}_{DIRECTION}_pro.png/fig

arguments
    trace (1, 1) struct
    folder (1, 1) string
    split (1, 1) string = "VALIDATION"
end

assert(all(isfield(trace, ["metadata", "reference", "prediction", "pwm"])), ...
    "E3F:ProPlotSchema", "Faltan metadata, reference, prediction o pwm.");
ref = trace.reference;
pred = trace.prediction;
pwm = trace.pwm;
q = trace.q;
n = size(ref, 1);
assert(n >= 1 && size(ref, 2) == 4 && size(pred, 2) == 4 && size(pwm, 2) == 4, ...
    "E3F:ProPlotShape", "Dimensiones invalidas.");

md = trace.metadata;
if isfield(md, "repetition")
    row = double(md.repetition);
elseif isfield(md, "row")
    row = double(md.row);
else
    error("E3F:ProPlotMetadata", "Falta repetition o row en metadata.");
end
subject = string(md.subject);
safeSubject = regexprep(subject, "[^A-Za-z0-9_-]", "_");
directions = ["closing", "opening"];
directionLabels = ["cierre", "apertura"];
dirStr = directions(md.side);
dirLabel = directionLabels(md.side);

stem = safeSubject + compose("_row%04d_", row) + dirStr + "_pro";
if ~isfolder(folder), mkdir(folder); end
files = struct("png", string(fullfile(folder, stem + ".png")), ...
               "fig", string(fullfile(folder, stem + ".fig")));

f = figure(Visible="off", Color="w", Position=[100 100 1200 1400]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>

layout = tiledlayout(f, 4, 1, TileSpacing="compact", Padding="compact");
x = 1:n;

for m = 1:4
    sub = tiledlayout(layout, 3, 1, TileSpacing="tight", Padding="none");
    sub.Layout.Tile = m;

    % Panel superior: Tracking y Error
    axTrack = nexttile(sub, [2 1]);
    plot(axTrack, x, pred(:, m), "-", Color=[0 0.447 0.741], LineWidth=2.0, ...
        DisplayName="h(q)", Tag="prediction");
    hold(axTrack, "on");
    plot(axTrack, x, ref(:, m), "--", Color=[0.85 0.325 0.098], LineWidth=2.0, ...
        DisplayName="Teacher", Tag="reference");

    err = ref(:, m) - pred(:, m);
    yline(axTrack, 0, ":", Color=[0.7 0.7 0.7], LineWidth=0.8, HandleVisibility="off");
    plot(axTrack, x, err, "-.", Color=[0.45 0.45 0.45], LineWidth=1.2, ...
        DisplayName="Error (teacher - h)", Tag="error");

    grid(axTrack, "on");
    axTrack.GridAlpha = 0.2;
    ylabel(axTrack, sprintf("M%d: Escala h", m), FontWeight="bold", FontSize=9);
    xlim(axTrack, [0.8 n + 0.2]);
    yMin = min([pred(:, m); ref(:, m); err; 0]) - 0.06;
    yMax = max([pred(:, m); ref(:, m); err; 0]) + 0.25;
    ylim(axTrack, [yMin yMax]);
    axTrack.XTickLabel = [];

    % Calculo exacto de metricas por motor
    mse_m = mean(err.^2);
    mae_m = mean(abs(err));
    pwm0_pct = 100 * nnz(pwm(:, m) == 0) / n;
    [uvals, ~, uidx] = unique(pwm(:, m));
    counts = accumarray(uidx, 1);
    [maxc, maxci] = max(counts);
    domPwm = uvals(maxci);
    maxCatFrac = maxc / n;

    boxStr = {sprintf("MSE = %.4f", mse_m), ...
              sprintf("MAE = %.4f", mae_m), ...
              sprintf("PWM0 %% = %.1f%%", pwm0_pct), ...
              sprintf("DominantPWM = %+d", domPwm), ...
              sprintf("MaxCategoryFraction = %.2f", maxCatFrac)};
    if m == 3
        revCount = nnz(pwm(:, 3) > 0 & diff(q(:, 3)) < 0);
        boxStr{end+1} = sprintf("M3 reversal count = %d", revCount);
    end

    text(axTrack, n + 0.15, yMax - 0.01, boxStr, VerticalAlignment="top", ...
        HorizontalAlignment="right", FontSize=7.5, FontName="Arial", ...
        BackgroundColor=[1 1 1 0.90], EdgeColor=[0.75 0.75 0.75], Tag="metricsBox");

    if m == 1
        legend(axTrack, Location="northwest", Orientation="horizontal", Box="off", FontSize=9);
    end
    title(axTrack, sprintf("Motor %d", m), FontWeight="bold", FontSize=10, HorizontalAlignment="left");

    % Banda inferior compacta: PWM
    axPwm = nexttile(sub, [1 1]);
    stairs(axPwm, x, pwm(:, m), "-", Color=[0.2 0.6 0.25], LineWidth=1.5, Tag="pwmStairs");
    hold(axPwm, "on");
    yline(axPwm, 0, "-", Color=[0.6 0.6 0.6], LineWidth=0.7);

    % Marcadores UNICAMENTE en cambios de categoria PWM
    trans = [true; diff(pwm(:, m)) ~= 0];
    plot(axPwm, x(trans), pwm(trans, m), "s", MarkerSize=5.5, ...
        MarkerFaceColor=[0.2 0.6 0.25], MarkerEdgeColor=[0.1 0.35 0.1], Tag="pwmTransition");

    xlim(axPwm, [0.8 n + 0.2]);
    ylim(axPwm, [-280 280]);
    yticks(axPwm, [-255 -128 0 128 255]);
    ylabel(axPwm, "PWM", FontSize=8);
    grid(axPwm, "on");
    axPwm.GridAlpha = 0.2;

    if m == 4
        xlabel(axPwm, "Paso del episodio", FontWeight="bold", FontSize=9);
    else
        axPwm.XTickLabel = [];
    end
end

epMSE = mean((pred(:) - ref(:)).^2);
epReward = mean(trace.reward);
header = sprintf("Policy = E3F FINAL | Checkpoint = 1,000,000 steps | Subject = %s | Row = %d | Direction = %s | Episode MSE = %.6f | Episode Reward = %.4f | Split = %s", ...
    subject, row, dirLabel, epMSE, epReward, split);
title(layout, header, FontSize=11, FontWeight="bold", Interpreter="none");

exportgraphics(f, files.png, Resolution=150);
savefig(f, files.fig);
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
