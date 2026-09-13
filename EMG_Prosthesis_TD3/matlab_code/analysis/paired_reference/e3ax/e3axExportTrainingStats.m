function files = e3axExportTrainingStats(trainingStats, out)
%e3axExportTrainingStats guarda el resultado completo y curvas registradas.
% Reutiliza las series historicas de createTrainingProgressFigure en
% src/evaluation/analyzeExperimentRun.m. No recalcula AverageReward ni Q0.
% Los campos opcionales ausentes conservan su panel vacio y se identifican.
% No busca, captura ni cierra la ventana del monitor de entrenamiento.

arguments
    trainingStats
    out (1, 1) string
end

if ~isfolder(out), mkdir(out); end
stem = string(fullfile(out, "trainingStats"));
figureStem = string(fullfile(out, "training_progress"));
files = struct("mat", stem + ".mat", "csv", stem + ".csv", ...
    "fig", figureStem + ".fig", "png", figureStem + ".png", "svg", figureStem + ".svg", ...
    "pdf", figureStem + ".pdf");
save(files.mat, "trainingStats", "-v7.3");

if isstruct(trainingStats)
    assert(isscalar(trainingStats), "E3AX:TrainingStatsShape");
    available = string(fieldnames(trainingStats));
elseif istable(trainingStats)
    available = string(trainingStats.Properties.VariableNames);
elseif isobject(trainingStats) && isscalar(trainingStats)
    available = string(properties(trainingStats));
else
    error("E3AX:TrainingStatsType", "Se requiere resultado de entrenamiento, struct o tabla.");
end
candidates = ["EpisodeIndex", "EpisodeReward", "AverageReward", "EpisodeSteps", ...
    "AverageSteps", "EpisodeQ0", "TotalAgentSteps"];
recorded = struct();
n = [];
for field = candidates
    if ~ismember(field, available), continue; end
    value = trainingStats.(field);
    if isempty(value), continue; end
    assert((isnumeric(value) || islogical(value)) && isreal(value) && isvector(value), ...
        "E3AX:TrainingStatsColumn", "El campo %s debe ser un vector real.", field);
    if isempty(n), n = numel(value); end
    assert(numel(value) == n, "E3AX:TrainingStatsLength", ...
        "Los campos registrados tienen longitudes diferentes: %s.", field);
    recorded.(field) = value(:);
end
assert(~isempty(n), "E3AX:TrainingStatsEmpty", "No hay series de episodios registradas.");
if ismember("EvaluationStatistic", available)
    value = trainingStats.EvaluationStatistic;
    if isnumeric(value) && isreal(value) && isvector(value) && numel(value) == n
        recorded.EvaluationStatistic = value(:);
    end
end
% Una fila por episodio, sin convertir cada vector en una celda de tabla.
T = table();
for field = string(fieldnames(recorded))'
    T.(field) = recorded.(field);
end
writetable(T, files.csv);
if isfield(recorded, "EpisodeIndex")
    x = recorded.EpisodeIndex;
    xLabel = "Episodio registrado";
else
    x = (1:n)';
    xLabel = "Fila registrada (EpisodeIndex no disponible)";
end

f = figure(Visible="off", Color="w", Position=[100 100 1250 860]);
cleanup = onCleanup(@() closeOwnFigure(f)); %#ok<NASGU>
layout = tiledlayout(f, 2, 2, TileSpacing="compact", Padding="compact");
plotRecorded(nexttile(layout), x, recorded, "EpisodeReward", ...
    "Reward por episodio", "Reward", xLabel, [.45 .80 1.00]);
plotRecorded(nexttile(layout), x, recorded, "AverageReward", ...
    "Reward medio registrado", "AverageReward", xLabel, [0 .45 .74]);
ax = nexttile(layout);
plotRecorded(ax, x, recorded, "EpisodeSteps", ...
    "Pasos por episodio", "Pasos", xLabel, [.25 .6 .35]);
if isfield(recorded, "AverageSteps")
    hold(ax, "on");
    plot(ax, x, recorded.AverageSteps, "--", Color=[.15 .35 .15], LineWidth=1.4, ...
        DisplayName="AverageSteps", Tag="AverageSteps");
    hold(ax, "off");
    title(ax, "Pasos registrados", Interpreter="none");
    legend(ax, Location="best", Box="off", Interpreter="none");
end
plotRecorded(nexttile(layout), x, recorded, "EpisodeQ0", ...
    "Q0 registrado", "EpisodeQ0", xLabel, [.93 .69 .13]);
title(layout, "Estadisticas de entrenamiento registradas", Interpreter="none");
exportgraphics(f, files.png, Resolution=180);
savefig(f, files.fig);
print(f, files.svg, "-dsvg");
exportgraphics(f, files.pdf, ContentType="vector");
end

function plotRecorded(ax, x, recorded, field, heading, yLabel, xLabel, color)
if isfield(recorded, field)
    plot(ax, x, recorded.(field), Color=color, LineWidth=1.4, ...
        DisplayName=field, Tag=field);
    title(ax, heading, Interpreter="none");
else
    title(ax, heading + " (no registrado)", Interpreter="none");
end
xlabel(ax, xLabel, Interpreter="none");
ylabel(ax, yLabel, Interpreter="none");
grid(ax, "on");
end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
