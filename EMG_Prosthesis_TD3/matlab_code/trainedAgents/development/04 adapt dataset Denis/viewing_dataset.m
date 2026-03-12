%viewing_dataset checks Denis data.

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

18 January 2024
%}

cc all
%% Configs
dataset_denis = "./development/04 adapt dataset Denis/datos_guante/";
users = {"CECILIA", "GABI", "JOE", "MATEO", "DENIS", "GABRIEL", "JONATHAN", "SANDRA", "BLANCA", "EMILIA", "IVANNA", "KHAROL"};
speeds = {"FAST", "SLOW", "MEDIUM"};
% %% Aux and dependent variables
% % libs
% addpath(genpath('src'))

%% 
for u = users
    for s = speeds
        f = dir(fullfile(dataset_denis, u{1}, s{1}));
        if size(f, 1) ~= 202
            fprintf("%s %s has %d files!\n", u{1}, s{1}, size(f, 1) - 2);
        end
    end
end

%% people with more data. Dennis dataset v1
% GABI MEDIUM has 220 files!
% JOE SLOW has 220 files!
% JOE MEDIUM has 260 files!
% MATEO MEDIUM has 220 files!
% JONATHAN SLOW has 201 files!
% SANDRA FAST has 220 files!
% SANDRA SLOW has 220 files!
% SANDRA MEDIUM has 220 files!
% BLANCA SLOW has 220 files!
% BLANCA MEDIUM has 220 files!
% IVANNA SLOW has 220 files!
% KHAROL SLOW has 220 files!
% KHAROL MEDIUM has 240 files!


%% people with more data. Dennis dataset v2
% GABI MEDIUM has 220 files!
% JOE SLOW has 220 files!
% JOE MEDIUM has 240 files!
% MATEO MEDIUM has 220 files!
% SANDRA FAST has 220 files!
% SANDRA MEDIUM has 220 files!
% BLANCA SLOW has 220 files!
% IVANNA SLOW has 220 files!
% KHAROL MEDIUM has 240 files!