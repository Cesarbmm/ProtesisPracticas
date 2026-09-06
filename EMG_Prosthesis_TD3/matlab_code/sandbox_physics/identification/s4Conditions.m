function conditions = s4Conditions(options)
%s4Conditions estructura por condicion (motor x direccion x PWM) para S4.
%
%   Campos: motor, direction, pwm, t (segundos), fit (L x nFit), val (L x nVal),
%   fitReps, valReps, stroke (carrera medida sobre la media FIT) y limits
%   (EMPIRICAL REACHABLE RANGE del motor, de sandboxPlantReachableRange).
%
%   El split FIT/VALIDATION es el congelado en el preregistro: repeticiones
%   impares para ajuste, pares para validacion. Aqui se reconstruye con la misma
%   regla y se comprueba contra el CSV versionado si existe.

arguments
    options.curvePath (1, 1) string = ""
    options.splitPath (1, 1) string = ""
end

here = string(fileparts(mfilename("fullpath")));
sandboxRoot = fileparts(here);
matlabRoot = fileparts(sandboxRoot);
if options.curvePath == ""
    options.curvePath = string(fullfile(matlabRoot, "src", "@SimController", "pattern_curve.mat"));
end
if options.splitPath == ""
    options.splitPath = string(fullfile(here, "s4_repetition_split.csv"));
end

loaded = load(options.curvePath, "avgs", "sampling_period_ms");
assert(loaded.sampling_period_ms == 1, "Sandbox:S4SamplingPeriod", ...
    "S4 asume indice de curva en milisegundos.");
avgs = loaded.avgs;
range = sandboxPlantReachableRange();

speedFields = ["sp_3F", "sp_5F", "sp_7F", "sp_9F", "sp_BF", "sp_DF", "sp_FF"];
pwmOf = [64 96 128 160 192 224 255];
directions = ["closing", "opening"];

conditions = struct("motor", {}, "direction", {}, "pwm", {}, "t", {}, ...
    "fit", {}, "val", {}, "fitReps", {}, "valReps", {}, "stroke", {}, "limits", {});

for s = 1:numel(speedFields)
    for d = 1:numel(directions)
        for m = 1:4
            data = double(avgs.(speedFields(s)).(directions(d)).(sprintf("m_%d", m)).data);
            [lengthMs, nRep] = size(data);
            fitReps = 1:2:nRep;
            valReps = 2:2:nRep;
            fitData = data(:, fitReps);
            conditions(end + 1) = struct( ...
                "motor", m, "direction", directions(d), "pwm", pwmOf(s), ...
                "t", (0:lengthMs - 1)' / 1000, ...
                "fit", fitData, "val", data(:, valReps), ...
                "fitReps", fitReps, "valReps", valReps, ...
                "stroke", max(mean(fitData, 2)) - min(mean(fitData, 2)), ...
                "limits", range(:, m)'); %#ok<AGROW>
        end
    end
end

if isfile(options.splitPath)
    stored = readtable(options.splitPath, "TextType", "string");
    for i = 1:numel(conditions)
        c = conditions(i);
        rows = stored(stored.motor == c.motor & stored.direction == c.direction & ...
            stored.pwm == c.pwm, :);
        storedFit = sort(rows.repetition(rows.role == "FIT"))';
        storedVal = sort(rows.repetition(rows.role == "VALIDATION"))';
        assert(isequal(storedFit, c.fitReps) && isequal(storedVal, c.valReps), ...
            "Sandbox:S4SplitDrift", ...
            "El split reconstruido no coincide con s4_repetition_split.csv (motor %d, %s, PWM %d).", ...
            c.motor, c.direction, c.pwm);
    end
end
end
