function trajectory = prosthesis_simulator( ...
    initial_position, speeds, duration, sampling_period, options)
%prosthesis_simulator() simulates the prosthesis dynamics. It returns the
%trajectory of the motors given an initial position, the speed and the
%duration of the movement.
%
%   ETAPA E0P: la fuente de la dinamica es ahora EXPLICITA.
%
%     "legacyAuto"             semantica historica: carga fit_C2.mat y decide
%                              la rama segun numel(ws). Se conserva para
%                              reproduccion y diagnostico.
%     "patternCurveCanonical"  ruta reproducible de la linea paired-reference:
%                              usa SOLO pattern_curve.mat y la tabla de limites
%                              plant_limits_canonical.csv. NO carga fit_C2.mat,
%                              NO inspecciona objetos cfit y NO consulta
%                              license(). Su salida no puede depender de que
%                              Curve Fitting Toolbox este instalada.
%
%   Por que hacia falta: con fit_C2.mat, `ws` se almacena como objeto cfit.
%   Sin Curve Fitting Toolbox MATLAB lo carga como [], numel(ws)==0, se activa
%   el respaldo a pattern_curve y hay dinamica. Con la toolbox instalada
%   numel(ws)==1, el respaldo no se activa y el clamp min(idx, ws_len) deja la
%   trayectoria constante. Una misma revision de git producia dos fisicas.
%
%   La fuente por defecto se lee de configurables("simPlantSource"). Si el
%   campo no existe (por ejemplo en main) se usa "legacyAuto", de modo que el
%   comportamiento historico no cambia en ninguna rama que no lo declare.
%   La seleccion se valida en cada llamada; respeta overrides de configuracion.
%
%   Argumentos opcionales nombrados, pensados para los tests:
%     plantSource, canonicalCurvePath, canonicalLimitsPath, fitC2Path

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador
%}

%% Input Validation
arguments
    initial_position (1, 4) double {mustBeReal}
    speeds (1, 4) double {mustBeInRange(speeds, -255, 255)}
    duration (1, 1) double {mustBePositive}
    sampling_period (1, 1) double {mustBePositive} = 0.1;
    options.plantSource (1, 1) string {mustBeMember(options.plantSource, ...
        ["", "legacyAuto", "patternCurveCanonical"])} = "";
    options.canonicalCurvePath (1, 1) string = "";
    options.canonicalLimitsPath (1, 1) string = "";
    options.fitC2Path (1, 1) string = "";
end

plantSource = resolveSimPlantSource(options.plantSource);

% ------ auxs vars
n_points = round(duration/sampling_period);
delta_ms = duration*1000/n_points;

% ------ loop
trajectory = nan(n_points, 4);

for i = 1:4
    if plantSource == "patternCurveCanonical"
        trajectory(:, i) = predict_1dim_canonical(initial_position(i), ...
            speeds(i), i, n_points, delta_ms, ...
            options.canonicalCurvePath, options.canonicalLimitsPath);
    else
        trajectory(:, i) = predict_1dim(initial_position(i), speeds(i), ...
            i, n_points, delta_ms, options.fitC2Path);
    end
end
end

%% ########################################################################
function root = simControllerDir()
root = fileparts(mfilename("fullpath"));
end

%% ########################################################################
%  RUTA CANONICA: solo pattern_curve.mat + tabla de limites
%  ########################################################################
function t_i = predict_1dim_canonical(pos, speed, i, n_points, delta_ms, ...
    curvePath, limitsPath)

persistent CURVE LIMITS cachedCurvePath cachedLimitsPath

if curvePath == ""
    curvePath = string(fullfile(simControllerDir(), "pattern_curve.mat"));
else
    curvePath = resolveSimPlantPath(curvePath);
end
if limitsPath == ""
    limitsPath = string(fullfile(simControllerDir(), "plant_limits_canonical.csv"));
else
    limitsPath = resolveSimPlantPath(limitsPath);
end

if isempty(CURVE) || ~isequal(cachedCurvePath, curvePath)
    CURVE = load(curvePath, "avgs").avgs;
    cachedCurvePath = curvePath;
end
if isempty(LIMITS) || ~isequal(cachedLimitsPath, limitsPath)
    LIMITS = readCanonicalLimits(limitsPath);
    cachedLimitsPath = limitsPath;
end

SIM_SPEEDS = [0 64 96 128 160 192 224 256];
speeds_txt = ["sp_zeroF" "sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];

if sign(speed) > 0
    dir = "closing";
elseif sign(speed) < 0
    dir = "opening";
else
    t_i = repmat(pos, n_points, 1);
    return
end

sp = snapSpeed(abs(speed), SIM_SPEEDS);
if sp == 0
    t_i = repmat(pos, n_points, 1);
    return
end

sp_txt = speeds_txt(SIM_SPEEDS == sp);
m_txt = sprintf("m_%d", i);

curve = CURVE.(sp_txt).(dir).(m_txt).avg;
lims = LIMITS.(sp_txt).(dir).(m_txt);
y_sat = sat(pos, lims(1), lims(2));

% --- busqueda de la posicion inicial dentro del recorrido de la curva
t = numel(curve);
foundStart = false;
for t_search = 1:numel(curve)
    if dir == "closing"
        if curve(t_search) >= y_sat
            t = t_search;
            foundStart = true;
            break;
        end
    else
        if y_sat >= curve(t_search)
            t = t_search;
            foundStart = true;
            break;
        end
    end
end

% --- fix de ETAPA E0, conservado: posicion fuera del recorrido de la curva.
% El motor esta mas alla del extremo lejano en la direccion pedida y no puede
% avanzar mas. Mantener posicion; nunca saltar al final de la curva.
if ~foundStart
    t_i = repmat(pos, n_points, 1);
    return
end

curve_len = numel(curve);
x_0 = max(1, min(t, curve_len));

t_i = nan(n_points, 1);
for t = 1:n_points
    idx = round(x_0 + delta_ms * t);
    idx = max(1, min(idx, curve_len));
    t_i(t) = curve(idx);
end
end

%% ------------------------------------------------------------------------
function L = readCanonicalLimits(limitsPath)
%readCanonicalLimits tabla de limites extraida de fit_C2 en la ETAPA E0P.
% Se extrajeron los campos numericos min_lim/max_lim tal cual; no se
% reinterpretan ni se reajustan los objetos cfit. El archivo es texto plano y
% versionable, y su hash entra en el manifiesto.
T = readtable(limitsPath, "TextType", "string");
L = struct();
for r = 1:height(T)
    sp = T.speed_field(r);
    d = T.direction(r);
    m = sprintf("m_%d", T.motor(r));
    L.(sp).(d).(m) = [T.min_lim(r), T.max_lim(r)];
end
end

%% ------------------------------------------------------------------------
function spSnapped = snapSpeed(sp, SIM_SPEEDS)
spSnapped = sp;
for i_2 = 2:numel(SIM_SPEEDS)
    b = SIM_SPEEDS(i_2);
    a = SIM_SPEEDS(i_2 - 1);
    if sp <= b
        if sp >= a
            r = (sp - a)/(b - a);
            if r >= 0.5
                spSnapped = b;
            else
                spSnapped = a;
            end
        else
            spSnapped = 0;
        end
        return
    end
end
end

%% ########################################################################
%  RUTA HISTORICA (legacyAuto): sin cambios de semantica
%  ########################################################################
function t_i = predict_1dim(pos, speed, i, n_points, delta_ms, fitC2Path)

persistent sim_params tail_length PATTERN_CURVE cachedFitPath
if fitC2Path == ""
    fitC2Path = string(fullfile(simControllerDir(), "fit_C2.mat"));
else
    fitC2Path = resolveSimPlantPath(fitC2Path);
end
if isempty(sim_params) || ~isequal(cachedFitPath, fitC2Path)
    f = load(fitC2Path);
    sim_params = f.params;
    tail_length = f.tail_length;
    cachedFitPath = fitC2Path;

    PATTERN_CURVE = load(fullfile(simControllerDir(), "pattern_curve.mat"), ...
        "avgs").avgs;
end

% ------ defaults
SIM_SPEEDS = [0 64 96 128 160 192 224 256];
speeds_txt = ["sp_zeroF" "sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];

%--
if sign(speed) > 0
    dir = "closing";
elseif sign(speed) < 0
    dir = "opening";
else
    t_i = repmat(pos, n_points, 1);
    return
end

sp = abs(speed);

%-- get closest speed
for i_2 = 2:numel(SIM_SPEEDS)
    b = SIM_SPEEDS(i_2);
    a = SIM_SPEEDS(i_2 - 1);
    if sp <= b
        if sp >= a
            r = (sp - a)/(b - a);
            if r >= 0.5
                sp = b;
            else
                sp = a;
            end
        else
            sp = 0;
        end
        break;
    end
end

%- slow speed
if sp == 0
    t_i = repmat(pos, n_points, 1);
    return;
end

%--- getting signal
sp_txt = speeds_txt(SIM_SPEEDS == sp);
m_txt = sprintf("m_%d", i);

% extracting
ws     = sim_params.(sp_txt).(dir).(m_txt).ws;
min_l  = sim_params.(sp_txt).(dir).(m_txt).min_lim;
max_l  = sim_params.(sp_txt).(dir).(m_txt).max_lim;
ws_len = numel(ws);

% --- si ws está vacío, el motor no puede moverse: mantener posición
y_sat = sat(pos, min_l, max_l);

% find init time in curve
curve = PATTERN_CURVE.(sp_txt).(dir).(m_txt).avg;
curve_len = numel(curve);

useCurveFallback = ws_len == 0;
if useCurveFallback
    % ``fit_C2.mat`` currently stores empty ``ws`` trajectories. Reuse the
    % average pattern curve so the simulator still produces motion.
    ws = curve;
    ws_len = curve_len;
end

t = numel(curve);
foundStart = false;
for t_search = 1:numel(curve)
    if dir == "closing"
        if curve(t_search) >= y_sat
            t = t_search;
            foundStart = true;
            break;
        end
    else
        if y_sat >= curve(t_search)
            t = t_search;
            foundStart = true;
            break;
        end
    end
end

% --- ETAPA E0 (paired-reference): posicion fuera del recorrido de la curva.
% Si la busqueda no encuentra punto, la posicion actual esta MAS ALLA del
% extremo lejano de la curva en la direccion pedida y el motor no puede
% avanzar mas. El valor por defecto t = numel(curve) hacia arrancar al FINAL
% de la curva y producia un salto en direccion CONTRARIA al comando.
% Medido en E0: 73 de 1176 casos del paso operativo (6.2%). Mantener la
% posicion es la respuesta fisica y es el cambio minimo posible.
if ~foundStart
    t_i = repmat(pos, n_points, 1);
    return
end

% --- clamp x_0
x_0 = t;
if ~useCurveFallback
    x_0 = tail_length + t;
end
x_0 = max(1, min(x_0, ws_len));

%---
t_i = nan(n_points, 1);
for t = 1:n_points
    idx = round(x_0 + delta_ms * t);
    idx = max(1, min(idx, ws_len));
    t_i(t) = ws(idx);
end

end
