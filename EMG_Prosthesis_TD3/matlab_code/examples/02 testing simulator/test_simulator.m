%test_simulator

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

07 March 2024
%}

clear all
close all
clc

%% Configs


%% Aux and dependent variables
% libs
addpath(genpath('src'))

%%
%%
% speeds = [0, 255, -100, 40
%     100 127 -200 100
%     0 0 0 0
%     -200 -50 100 100];
% delays = 0.1;
% for i = 1:size(speeds, 1)
%     prosthesis.sendAllSpeed(speeds(i, 1), speeds(i, 2), speeds(i, 3), ...
%         speeds(i, 4));
%
%     pause(delays)
% end
% data = prosthesis.read;
%

%%
clc
% prosthesis.sendSpeed(1, 100);
initial_pos = [0 0 0 0];
speeds = [100 100 100 100];
duration = 1;
ys = SimController.prosthesis_simulator(initial_pos, speeds, duration);

figure,
plot(ys, "o:")


%%
initial_pos = [10000 6000 4000 7000];
speeds = [100 -255 40 -50];
duration = 1;
ys = SimController.prosthesis_simulator(initial_pos, speeds, duration, 0.01);
figure
plot(ys, "o:")
legend("1", "2", "3", "4")


%% complex figure


initial_pos = [    10000 6000 4000 7000    ];
speeds = [...
    100 -255   40 -50
    255  100 -255  0
    0     0   0    -100
    150 150 150    150];

sampling_period = 0.01;

% ----
duration = 1;
for r = 1:size(speeds, 1)
    initial_pos = [initial_pos; SimController.prosthesis_simulator( ...
        initial_pos(end, :), speeds(r, :), duration, sampling_period)];
end

figure
plot(0:(length(initial_pos) - 1), initial_pos, "o:")
legend("1", "2", "3", "4")
xline((1:4)/sampling_period, "HandleVisibility","off")
% --
ax = gca;
ax.FontSize = 30;
ylabel("Encoder count")
xlabel("Time [10 ms]")


%% complex figure
initial_pos = [0 0 0 0];
speeds = [...
    100 -255   40 -50
    255  100 -255  0
    0     0   0    -100
    150 150 150    150];

sampling_period = 0.01;

% ----
duration = 1;
for r = 1:size(speeds, 1)
    initial_pos = [initial_pos; SimController.prosthesis_simulator( ...
        initial_pos(end, :), speeds(r, :), duration, sampling_period)];
end

figure
plot(0:(length(initial_pos) - 1), initial_pos, "o:")
legend("1", "2", "3", "4")
xline((1:4)/sampling_period, "HandleVisibility","off")
% --
ax = gca;
ax.FontSize = 30;
ylabel("Encoder count")
xlabel("Time [10 ms]")
