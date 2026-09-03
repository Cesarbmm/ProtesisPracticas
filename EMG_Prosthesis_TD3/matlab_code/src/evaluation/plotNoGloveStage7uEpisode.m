function figureHandle = plotNoGloveStage7uEpisode(episodeMatPath, outPngPath, options)
%plotNoGloveStage7uEpisode readable, separated-panel figure for one saved
%ETAPA 7U episode: q/q_ref, v_ref, u_actor_raw, u_requested/u_effective,
%PWM, motionPermission, safety intervention - one signal family per panel,
%no per-sample numeric labels (only safety-intervention step markers).

arguments
    episodeMatPath (1, 1) string
    outPngPath (1, 1) string
    options.title (1, 1) string = ""
end

e = load(episodeMatPath, "stateLog", "referenceHistory", ...
    "trackingPredictionHistory", "actionLog", "actionWarpLog", ...
    "actionSatLog", "actionPwmLog", "motionPermissionLog", ...
    "positionSafetyInterventionLog", "referenceHistoryCount");
n = e.referenceHistoryCount;
if n == 0
    n = size(e.actionLog, 1);
end
step = (1:n)';
q = e.trackingPredictionHistory(1:n, :);
qRef = e.referenceHistory(1:n, :);
vRef = e.stateLog(1:n, 57:60);
uRaw = e.actionLog(1:n, :);
uRequested = e.actionWarpLog(1:n, :);
uEffective = e.actionSatLog(1:n, :);
pwm = e.actionPwmLog(1:n, :);
permission = double(e.motionPermissionLog(1:n));
safety = e.positionSafetyInterventionLog(1:n, :);

motorColors = [0.85 0.20 0.20; 0.20 0.55 0.85; 0.30 0.70 0.30; 0.60 0.35 0.75];
motorNames = ["M1", "M2", "M3", "M4"];

f = figure("Visible", "off", "Position", [0 0 1000 1400]);
tl = tiledlayout(f, 7, 1, "TileSpacing", "compact", "Padding", "compact");

ax1 = nexttile(tl); hold(ax1, "on");
for m = 1:4
    plot(ax1, step, q(:, m), "Color", motorColors(m, :), "LineWidth", 1.2);
    plot(ax1, step, qRef(:, m), "--", "Color", motorColors(m, :), "LineWidth", 0.9);
end
ylabel(ax1, "q, q_{ref}"); title(ax1, "Posicion vs referencia (linea solida=q, punteada=q_{ref})");
legend(ax1, motorNames, "Location", "eastoutside", "NumColumns", 1);

ax2 = nexttile(tl); hold(ax2, "on");
for m = 1:4
    plot(ax2, step, vRef(:, m), "Color", motorColors(m, :), "LineWidth", 1);
end
ylabel(ax2, "v_{ref}"); title(ax2, "Velocidad de referencia causal");

ax3 = nexttile(tl); hold(ax3, "on");
for m = 1:4
    plot(ax3, step, uRaw(:, m), "Color", motorColors(m, :), "LineWidth", 1);
end
yline(ax3, [-1 1], ":", "Color", [0.5 0.5 0.5]);
ylabel(ax3, "u_{actor,raw}"); title(ax3, "Salida cruda del actor (nunca alterada por el gate)");
ylim(ax3, [-1.05 1.05]);

ax4 = nexttile(tl); hold(ax4, "on");
for m = 1:4
    plot(ax4, step, uRequested(:, m), "-", "Color", motorColors(m, :), "LineWidth", 1.4);
    plot(ax4, step, uEffective(:, m), ":", "Color", motorColors(m, :), "LineWidth", 1);
end
ylabel(ax4, "u_{req}, u_{eff}");
title(ax4, "Accion solicitada (post-gate, solida) vs efectiva (post-cuantizacion, punteada)");

ax5 = nexttile(tl); hold(ax5, "on");
for m = 1:4
    stairs(ax5, step, pwm(:, m), "Color", motorColors(m, :), "LineWidth", 1);
end
ylabel(ax5, "PWM"); title(ax5, "Comando PWM aplicado");

ax6 = nexttile(tl);
stairs(ax6, step, permission, "Color", [0.1 0.1 0.1], "LineWidth", 1.4);
ylim(ax6, [-0.1 1.1]); yticks(ax6, [0 1]); yticklabels(ax6, ["inactivo", "activo"]);
ylabel(ax6, "motionPermission"); title(ax6, "Permiso de movimiento (gate causal)");

ax7 = nexttile(tl); hold(ax7, "on");
safetyStep = sum(safety, 2);
stem(ax7, step(safetyStep > 0), safetyStep(safetyStep > 0), ...
    "filled", "Color", [0.75 0.1 0.1], "MarkerSize", 4);
if all(safetyStep == 0)
    text(ax7, mean(step), 0.5, "sin intervenciones de seguridad en este episodio", ...
        "HorizontalAlignment", "center", "FontSize", 9, "Color", [0.4 0.4 0.4]);
    ylim(ax7, [0 1]);
end
ylabel(ax7, "safety"); xlabel(ax7, "Paso del episodio");
title(ax7, "Intervenciones de seguridad (solo marcadas cuando ocurren)");

if strlength(options.title) > 0
    title(tl, options.title, "FontWeight", "bold");
end

outDir = fileparts(outPngPath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end
exportgraphics(f, outPngPath, "Resolution", 150);
figureHandle = f;
close(f);
end
