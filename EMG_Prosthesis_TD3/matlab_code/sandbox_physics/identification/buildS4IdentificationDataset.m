function [dataset, split, floorTable] = buildS4IdentificationDataset(options)
%buildS4IdentificationDataset dataset de identificacion S4 desde pattern_curve.mat.
%
%   Devuelve tres cosas:
%     dataset     tabla larga: motor, direction, pwm, repetition, time_ms, q_encoder
%     split       reparto congelado FIT / VALIDATION por repeticion
%     floorTable  repeatability floor por condicion, calculado SOLO con FIT
%
%   Reglas del preregistro que este archivo implementa:
%     * NO se ajusta contra `avg`. Se comprueba que `avg` es exactamente la
%       media de `data` y se trabaja con repeticiones individuales.
%     * Split determinista y sin semilla: FIT = repeticiones impares,
%       VALIDATION = repeticiones pares. Alternar protege frente a deriva entre
%       ensayos mejor que "primera mitad / segunda mitad".
%     * El indice temporal de pattern_curve esta en MILISEGUNDOS
%       (sampling_period_ms = 1). Se verifica al cargar.
%
%   Solo lee `pattern_curve.mat`. No lo modifica y no toca ningun otro archivo.

arguments
    options.curvePath (1, 1) string = ""
    options.outputDir (1, 1) string = ""
end

here = string(fileparts(mfilename("fullpath")));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
if options.curvePath == ""
    options.curvePath = string(fullfile(matlabRoot, "src", "@SimController", "pattern_curve.mat"));
end

loaded = load(options.curvePath, "avgs", "sampling_period_ms");
assert(isfield(loaded, "sampling_period_ms") && loaded.sampling_period_ms == 1, ...
    "Sandbox:S4SamplingPeriod", ...
    "S4 asume indice de curva en milisegundos (sampling_period_ms = 1).");
avgs = loaded.avgs;

speedFields = ["sp_3F", "sp_5F", "sp_7F", "sp_9F", "sp_BF", "sp_DF", "sp_FF"];
pwmOf = [64 96 128 160 192 224 255];
directions = ["closing", "opening"];

datasetRows = {};
splitRows = {};
floorRows = {};

for s = 1:numel(speedFields)
    for d = 1:numel(directions)
        for m = 1:4
            entry = avgs.(speedFields(s)).(directions(d)).(sprintf("m_%d", m));
            data = double(entry.data);
            avgCurve = double(entry.avg(:));
            [lengthMs, nRep] = size(data);

            assert(max(abs(mean(data, 2) - avgCurve)) < 1e-9, ...
                "Sandbox:S4AvgMismatch", ...
                "avg deberia ser la media exacta de data en %s/%s/m_%d.", ...
                speedFields(s), directions(d), m);
            assert(all(isfinite(data), "all"), "Sandbox:S4NonFinite", ...
                "pattern_curve contiene valores no finitos.");

            fitReps = 1:2:nRep;
            valReps = 2:2:nRep;
            assert(~isempty(fitReps) && ~isempty(valReps) && ...
                isempty(intersect(fitReps, valReps)), ...
                "Sandbox:S4Split", "El split FIT/VALIDATION debe ser disjunto y no vacio.");

            timeMs = (0:lengthMs - 1)';
            for r = 1:nRep
                role = "VALIDATION";
                if mod(r, 2) == 1
                    role = "FIT";
                end
                datasetRows{end + 1} = table( ...
                    repmat(m, lengthMs, 1), repmat(directions(d), lengthMs, 1), ...
                    repmat(pwmOf(s), lengthMs, 1), repmat(r, lengthMs, 1), ...
                    repmat(role, lengthMs, 1), timeMs, data(:, r), ...
                    VariableNames = ["motor", "direction", "pwm", "repetition", ...
                    "role", "time_ms", "q_encoder"]); %#ok<AGROW>
                splitRows{end + 1} = table(speedFields(s), pwmOf(s), directions(d), m, r, ...
                    role, lengthMs, VariableNames = ["speed_field", "pwm", "direction", ...
                    "motor", "repetition", "role", "length_ms"]); %#ok<AGROW>
            end

            fitData = data(:, fitReps);
            fitMean = mean(fitData, 2);
            stroke = max(fitMean) - min(fitMean);
            varOverTime = var(fitData, 0, 2);
            floorSd = sqrt(mean(varOverTime));
            nFit = numel(fitReps);
            floorRows{end + 1} = table(speedFields(s), pwmOf(s), directions(d), m, ...
                lengthMs, nRep, nFit, numel(valReps), stroke, floorSd, ...
                floorSd / stroke, floorSd * sqrt(1 + 1 / nFit), ...
                floorSd * sqrt(1 + 1 / nFit) / stroke, ...
                VariableNames = ["speed_field", "pwm", "direction", "motor", ...
                "length_ms", "n_rep", "n_fit", "n_val", "stroke", "floor_sd", ...
                "floor_nrmse", "floor_heldout_rmse", "floor_heldout_nrmse"]); %#ok<AGROW>
        end
    end
end

dataset = vertcat(datasetRows{:});
split = vertcat(splitRows{:});
floorTable = vertcat(floorRows{:});

if options.outputDir ~= ""
    if ~isfolder(options.outputDir)
        mkdir(options.outputDir);
    end
    writetable(split, fullfile(options.outputDir, "s4_repetition_split.csv"));
    writetable(floorTable, fullfile(options.outputDir, "s4_condition_floor.csv"));
end
end
