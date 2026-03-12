function params = definitions(field)
%definitions() returns a struct with the definitions of the prosthesis
%hardware.
%definitions(field) returns only the required field, instead of the whole
%struct.
%
% IMPORTANT:
%Do not change! This values must match hardware design.
%
% Outputs
%   params      -struct with fields, or variable
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona!
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth
%}


%% motor finger map 1-4
params.numMotors = 4;

% refactored
params.motorIdx.thumb = 3;
params.motorIdx.idx = 2;
params.motorIdx.mid = 4;
params.motorIdx.little = 1;

params.fingers = {'little', 'idx', 'thumb', 'mid'}; % names in order!


% --- gaps. Free moving space in the middle of the rest position, it is
% because the loose tension with fingers and motors
% Note: Is the middle of total range 
params.gap.thumb = 4000;
params.gap.idx = 3650;
params.gap.mid = 3550;
params.gap.little = 7500;

%--- Mony feat Denis architecture
% Based on encoders limit in ESP32 software
params.breakLimit.thumb = 8500;
params.breakLimit.idx = 11500;
params.breakLimit.mid = 9000;
params.breakLimit.little = 26500;

%% flexs
% Related values of the glove measurements. Flex is the given name to the
% accumulated data of the related sensors in the glove for every degree of
% freedom. From lower value to higher value that is climbable
% NOTE: not part of the prosthesis, but related.
% uses a simplified model
% minimum value of the sensor when still
params.flex_low_lim.thumb = 300;
params.flex_low_lim.idx = 900;
params.flex_low_lim.mid = 900;
params.flex_low_lim.little = 1800;

% max values reached by saturation of the sensor
params.flex_max_lim.thumb = 1023;
params.flex_max_lim.idx = 2046;
params.flex_max_lim.mid = 2046;
params.flex_max_lim.little = 4092;

% --- data protocol
% Warning check this value matches the arduino code
params.period = 0.1; % not used in env, used in manual operation

%% glove
params.flexMapping.thumb = {'thumb'};
params.flexMapping.idx = {'indexUp', 'indexDown'};
params.flexMapping.mid = {'middleUp', 'middleDown'};
params.flexMapping.little = {'ringUp', 'ringDown', 'pinkyUp', 'pinkyDown'};


%% Getting specific field
if nargin == 1
    if isfield(params, field)
        params = params.(field);
    else
        error('in property %s', field)
    end
end

