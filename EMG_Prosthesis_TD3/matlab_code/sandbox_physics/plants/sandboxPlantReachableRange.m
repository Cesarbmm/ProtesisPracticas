function [range, provenance] = sandboxPlantReachableRange(options)
%sandboxPlantReachableRange recorrido real de la planta canonica por motor.
%
%   range = 2x4 [minEncoder; maxEncoder] recorriendo TODAS las curvas empiricas
%   de pattern_curve.mat (7 niveles PWM x 2 direcciones x 4 motores).
%
%   Por que existe esta funcion: el estado normaliza el encoder con
%   [26500 11500 8500 9000] (config/configurables.m:277), pero las curvas de
%   caracterizacion no llegan a esos valores. Medido en la auditoria S0:
%
%       motor 1  [ -788.7 , 17246.5 ]   ->  65.1 % del limite de firmware
%       motor 2  [ -437.3 ,  6665.7 ]   ->  58.0 %
%       motor 3  [ -681.3 ,  7672.2 ]   ->  90.3 %
%       motor 4  [ -562.2 ,  6280.8 ]   ->  69.8 %
%
%   Consecuencia para el visor: q normalizada NUNCA alcanza 1 en la planta
%   canonica. Un visor que asuma [0,1] dibuja una mano que jamas se cierra.
%   Consecuencia para identificacion (S4): este es el soporte de los datos; un
%   modelo reducido no debe extrapolar fuera de el.
%
%   No modifica nada: solo lee pattern_curve.mat.

arguments
    options.curvePath (1, 1) string = ""
end

persistent CACHED CACHED_PATH

curvePath = options.curvePath;
if curvePath == ""
    here = string(fileparts(mfilename("fullpath")));
    matlabRoot = fileparts(fileparts(here));   % .../matlab_code
    curvePath = string(fullfile(matlabRoot, "src", "@SimController", "pattern_curve.mat"));
end
if ~isfile(curvePath)
    error("Sandbox:PatternCurveMissing", ...
        "No se encontro pattern_curve.mat en %s", curvePath);
end

if ~isempty(CACHED) && isequal(CACHED_PATH, curvePath)
    range = CACHED;
else
    loaded = load(curvePath, "avgs");
    avgs = loaded.avgs;
    speedFields = string(fieldnames(avgs));
    range = [inf(1, 4); -inf(1, 4)];
    for s = 1:numel(speedFields)
        directions = string(fieldnames(avgs.(speedFields(s))));
        for d = 1:numel(directions)
            for m = 1:4
                curve = avgs.(speedFields(s)).(directions(d)).(sprintf("m_%d", m)).avg;
                range(1, m) = min(range(1, m), min(curve));
                range(2, m) = max(range(2, m), max(curve));
            end
        end
    end
    CACHED = range;
    CACHED_PATH = curvePath;
end

if nargout > 1
    encoderLimits = [26500 11500 8500 9000];
    provenance = struct( ...
        "curvePath", curvePath, ...
        "minEncoder", range(1, :), ...
        "maxEncoder", range(2, :), ...
        "maxNormalized", range(2, :) ./ encoderLimits, ...
        "fractionOfFirmwareLimitPercent", 100 * range(2, :) ./ encoderLimits, ...
        "note", "recorrido de las curvas empiricas; no es un limite mecanico medido");
end
end
