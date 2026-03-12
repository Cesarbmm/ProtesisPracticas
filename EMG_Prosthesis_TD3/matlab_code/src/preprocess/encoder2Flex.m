function [encoderData, finishEpisode] = encoder2Flex(encoderData)
%encoder2Flex() converts the given encoder values and converts them to flex
%for later use in the reward calculation.
%It also returns a flag when the values are outside the breaking limit.
%
% Inputs
%   encoderData     -m-by-4 double
%
% Outputs
%   encoderData     -m-by-4 double
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

04 January 2022
Matlab R2021b.
%}

%%
persistent fingers motorIdx gap flexs_low_lim breakLimit ...
    linear_transform flex_max_lim

if isempty(fingers)
    fingers = definitions("fingers");
end

if isempty(motorIdx)
    motorIdx = definitions('motorIdx');
end
if isempty(gap)
    gap = definitions("gap");
end
if isempty(flexs_low_lim)
    flexs_low_lim = definitions("flex_low_lim");
end
if isempty(breakLimit)
    breakLimit = definitions("breakLimit");
end
if isempty(flex_max_lim)
    flex_max_lim = definitions("flex_max_lim");
end
if isempty(linear_transform)
    for fCell = fingers
        f = fCell{1}; % name of the finger
        m =  (flex_max_lim.(f) - flexs_low_lim.(f)) / (breakLimit.(f) - gap.(f));
        b = flex_max_lim.(f) - m * breakLimit.(f);
        linear_transform.(f) = [m, b];
    end
end

%% loop by DoF
finishEpisode = false;

for fCell = fingers
    f = fCell{1}; % name of the finger
    idx = motorIdx.(f);

    x = abs( encoderData(:, idx) );
    xF = x; % final value

    % --- gap zone
    idxGap = x < gap.(f);
    xF(idxGap) = flexs_low_lim.(f);

    % --- working uphill part
    idx_linear = x >= gap.(f) & x <= breakLimit.(f);
    xF(idx_linear) = polyval( linear_transform.(f), x(idx_linear) );

    % --- saturation zone
    idxSat = x > breakLimit.(f);
    xF(idxSat) = flex_max_lim.(f);

    finishEpisode = any(idxSat) || finishEpisode;

    % outputing
    encoderData(:, idx) = xF;
end
