function trajectory = prosthesis_simulator( ...
    initial_position, speeds, duration, sampling_period)
%prosthesis_simulator() simulates the prosthesis dynamics. It returns the
%trajectory of the motors given an initial position, the speed and the
%duration of the movement.

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
end

% ------ auxs vars
n_points = round(duration/sampling_period);
delta_ms = duration*1000/n_points;

% ------ loop
trajectory = nan(n_points, 4);

for i = 1:4
    trajectory(:, i) = predict_1dim(initial_position(i), speeds(i), ...
        i, n_points, delta_ms);
end
end

%% ########################################################################
function t_i = predict_1dim(pos, speed, i, n_points, delta_ms)

persistent sim_params tail_length PATTERN_CURVE
if isempty(sim_params)
    f_name = "src\@SimController\fit_C2.mat";
    f = load(f_name);
    sim_params = f.params;
    tail_length = f.tail_length;

    f_name = "src\@SimController\pattern_curve.mat";
    PATTERN_CURVE = load(f_name, "avgs").avgs;
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
if ws_len == 0
    t_i = repmat(pos, n_points, 1);
    return;
end

y_sat = sat(pos, min_l, max_l);

% find init time in curve
curve = PATTERN_CURVE.(sp_txt).(dir).(m_txt).avg;

t = numel(curve);
for t_search = 1:numel(curve)
    if dir == "closing"
        if curve(t_search) >= y_sat
            t = t_search;
            break;
        end
    else
        if y_sat >= curve(t_search)
            t = t_search;
            break;
        end
    end
end

% --- clamp x_0
x_0 = tail_length + t;
x_0 = max(1, min(x_0, ws_len));

%---
t_i = nan(n_points, 1);
for t = 1:n_points
    idx = round(x_0 + delta_ms * t);
    idx = max(1, min(idx, ws_len));
    t_i(t) = ws(idx);
end

end