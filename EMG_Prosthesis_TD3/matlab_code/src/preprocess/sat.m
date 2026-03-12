function x = sat(x, minx, maxx, showW)
%sat returns the value x coerced in the ranges [minx, maxx]. showW is flag
%to display the outside values.
% x may be an scalar or an array.
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona
jonathan.a.zea@ieee.org
Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
Ahora solo lo sabe dios.

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

02 December 2021
Matlab r2021b.
%}

%% Input Validation
arguments
    x       (:, :) double
    minx    (1, 1) double
    maxx    (1, 1) double
    showW   (1, 1) logical = false; % display warning of outside values
end

%% prealloc
showx = false; % changed to true if any value outside
x0 = []; % prechanged values

%%
lows = x < minx;

if any(lows)
    x0 = x(lows);
    x(lows) = minx;
    showx = true;
end

%%
highs = x > maxx;
if any(highs)
    if isrow(highs)
        x0 = [x0 x(highs)];
    else
        x0 = [x0; x(highs)];
    end
    showx = true;
    x(highs) = maxx;
end

if showW && showx
    % does not work with arrays
    warning(['Values [ ' repmat('%d ', 1, numel(x0)) ...
        '] outside of range [%d %d]'], x0, minx, maxx);
end
