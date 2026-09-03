function buildNoGloveStage7uTrainingFigures(runRoot, trainingSubdir, outDir)
%buildNoGloveStage7uTrainingFigures reconstructs training-time figures for
%a completed ETAPA 7U long-training campaign from already-saved artifacts
%(training_info.mat + sampled episode*.mat logs). Does not retrain.
arguments
    runRoot (1,1) string
    trainingSubdir (1,1) string
    outDir (1,1) string
end
if ~isfolder(outDir)
    mkdir(outDir);
end
trainingRunDir = fullfile(runRoot, "training", trainingSubdir);
ti = load(fullfile(trainingRunDir, "training_info.mat"));
tinfo = ti.trainingInfo;
n = numel(tinfo.EpisodeReward);
reward = tinfo.EpisodeReward(:);
q0 = tinfo.EpisodeQ0(:);
episodeIdx = (1:n)';
checkpointEpisodes = 500:500:(500*floor(n/500));

% Sampled per-episode metrics from saved training episode*.mat logs
files = dir(fullfile(trainingRunDir, "episode*.mat"));
[~, order] = sort({files.name});
files = files(order);
m = numel(files);
sampledEp = zeros(m,1);
trkMse = nan(m,1); actL2raw = nan(m,1); actL2eff = nan(m,1);
dActL2 = nan(m,1); satFrac = nan(m,1); safetyCount = nan(m,1);
activeFrac = nan(m,1); restRawL2 = nan(m,1);
for i = 1:m
    tok = regexp(files(i).name, '(\d+)', 'tokens', 'once');
    sampledEp(i) = str2double(tok{1});
    e = load(fullfile(files(i).folder, files(i).name), ...
        "rewardInfoLog", "motionPermissionLog", "actionLog", ...
        "positionSafetyInterventionLog");
    info = e.rewardInfoLog;
    trkMse(i) = mean(cellfun(@(s) s.trackingMse, info), "omitnan");
    actL2eff(i) = mean(cellfun(@(s) s.actionL2, info), "omitnan");
    actL2raw(i) = mean(e.actionLog.^2, "all");
    dActL2(i) = mean(cellfun(@(s) s.deltaActionL2, info), "omitnan");
    satFrac(i) = mean(cellfun(@(s) s.saturationFraction, info), "omitnan");
    safetyCount(i) = sum(e.positionSafetyInterventionLog, "all");
    permission = logical(e.motionPermissionLog(:));
    activeFrac(i) = mean(permission);
    restRawL2(i) = mean(e.actionLog(~permission, :).^2, "all", "omitnan");
end

movAvgWindow = 200;
rewardMovAvg = movmean(reward, movAvgWindow);

commonStyle = @(ax) set(ax, "Box", "on", "FontSize", 10);

%% 1. Reward vs episode (+ moving average overlaid)
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(episodeIdx, reward, "Color", [0.7 0.7 0.9], "LineWidth", 0.5); hold on
plot(episodeIdx, rewardMovAvg, "Color", [0.1 0.2 0.7], "LineWidth", 2);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio"); ylabel("Reward"); title("Reward por episodio (10 000 episodios)");
legend(["Reward por episodio", sprintf("Media movil (%d ep)", movAvgWindow)], "Location", "best");
commonStyle(gca);
saveas(f, fullfile(outDir, "01_reward_vs_episode.png")); close(f);

%% 2. Moving average alone, larger
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(episodeIdx, rewardMovAvg, "Color", [0.1 0.2 0.7], "LineWidth", 2);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio"); ylabel(sprintf("Reward (media movil %d ep)", movAvgWindow));
title("Tendencia del reward"); commonStyle(gca);
saveas(f, fullfile(outDir, "02_reward_moving_average.png")); close(f);

%% 3. EpisodeQ0 vs episode
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(episodeIdx, q0, "Color", [0.8 0.5 0.9], "LineWidth", 0.5); hold on
plot(episodeIdx, movmean(q0, movAvgWindow), "Color", [0.5 0.1 0.6], "LineWidth", 2);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio"); ylabel("Q0 (estimacion del critico en el estado inicial)");
title("Evolucion de Q0"); legend(["Q0 por episodio", "Media movil"], "Location", "best");
commonStyle(gca);
saveas(f, fullfile(outDir, "03_episodeQ0_vs_episode.png")); close(f);

%% 4. trackingMSE (sampled episodes)
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, trkMse, "o-", "Color", [0.1 0.6 0.2], "MarkerSize", 3, "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado cada 10)"); ylabel("trackingMSE");
title("trackingMSE durante entrenamiento (episodios guardados)"); commonStyle(gca);
saveas(f, fullfile(outDir, "04_trackingMSE_vs_episode.png")); close(f);

%% 5. actionL2 (raw y efectivo)
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, actL2raw, "-", "Color", [0.8 0.2 0.2], "LineWidth", 1); hold on
plot(sampledEp, actL2eff, "-", "Color", [0.2 0.2 0.8], "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado)"); ylabel("actionL2");
title("actionL2: u\_actor\_raw vs accion efectiva (post-gate)");
legend(["actionL2(u\_actor\_raw)", "actionL2(efectiva)"], "Location", "best");
commonStyle(gca);
saveas(f, fullfile(outDir, "05_actionL2_vs_episode.png")); close(f);

%% 6. deltaActionL2
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, dActL2, "-", "Color", [0.6 0.3 0.1], "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado)"); ylabel("deltaActionL2");
title("deltaActionL2 durante entrenamiento"); commonStyle(gca);
saveas(f, fullfile(outDir, "06_deltaActionL2_vs_episode.png")); close(f);

%% 7. saturationFraction
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, satFrac, "-", "Color", [0.9 0.1 0.1], "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado)"); ylabel("Fraccion de saturacion (|u_{eff}|>=0.95)");
title("Saturacion de la accion efectiva durante entrenamiento"); commonStyle(gca);
ylim([0 1]);
saveas(f, fullfile(outDir, "07_saturationFraction_vs_episode.png")); close(f);

%% 8. safety interventions
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, safetyCount, "-", "Color", [0.3 0.3 0.3], "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado)"); ylabel("Intervenciones de seguridad por episodio");
title("Intervenciones de seguridad durante entrenamiento"); commonStyle(gca);
saveas(f, fullfile(outDir, "08_safetyInterventions_vs_episode.png")); close(f);

%% 9. motionPermission active fraction
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, activeFrac, "-", "Color", [0.1 0.5 0.5], "LineWidth", 1);
addCheckpointLines(checkpointEpisodes);
xlabel("Episodio (muestreado)"); ylabel("Fraccion de pasos con motionPermission activo");
title("Fraccion de pasos activos (gate) por episodio de entrenamiento");
ylim([0 1]); commonStyle(gca);
saveas(f, fullfile(outDir, "09_motionPermission_activeFraction_vs_episode.png")); close(f);

%% 10. u_actor_raw during REST specifically (the pathology-during-rest check)
f = figure("Visible", "off", "Position", [0 0 1000 500]);
plot(sampledEp, restRawL2, "-", "Color", [0.85 0.4 0.0], "LineWidth", 1.2);
addCheckpointLines(checkpointEpisodes);
yline(1, "--", "saturacion maxima posible (|u|=1)", "Color", [0.5 0.5 0.5]);
xlabel("Episodio (muestreado)"); ylabel("Media de u\_actor\_raw^2 en pasos con permiso inactivo");
title("Magnitud de u\_actor\_raw durante reposo (aunque el permiso lo bloquea)");
ylim([0 1.05]); commonStyle(gca);
saveas(f, fullfile(outDir, "10_restRawActionL2_vs_episode.png")); close(f);

% Save the underlying sampled-metric table for reproducibility/LaTeX use
sampledTable = table(sampledEp, trkMse, actL2raw, actL2eff, dActL2, ...
    satFrac, safetyCount, activeFrac, restRawL2, ...
    'VariableNames', ["episode", "trackingMse", "actionL2Raw", ...
    "actionL2Effective", "deltaActionL2", "saturationFraction", ...
    "safetyInterventions", "activeFraction", "restRawActionL2"]);
writetable(sampledTable, fullfile(outDir, "training_sampled_metrics.csv"));

fprintf("Figures written to %s\n", outDir);
end

function addCheckpointLines(checkpointEpisodes)
hold on
yl = ylim;
for c = checkpointEpisodes
    xline(c, ":", "Color", [0.6 0.6 0.6], "LineWidth", 0.5);
end
ylim(yl);
end
