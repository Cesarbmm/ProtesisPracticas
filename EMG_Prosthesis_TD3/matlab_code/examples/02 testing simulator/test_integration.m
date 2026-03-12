%test_integration runs test with the timing and the simulator.

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

27 March 2024
%}

clear all
close all
clc
%% Configs


%% Aux and dependent variables
% libs
addpath(genpath('src'))

%%
period = 0.1;
episodeTic = Timing(false, period);

prosthesis = SimController(episodeTic);

sampling_period = 0.1; % default?

%%
speeds = [...
    100 -255   40 -50
    255  100 -255  0
    0     0   0    -100
    150 150 150    150];


periods = [10 10 10 10];
for i = 1:size(speeds, 1)

    prosthesis.sendAllSpeed(speeds(i, 1), speeds(i, 2), speeds(i, 3), ...
        speeds(i, 4));

    for p = 1:periods(i)
        episodeTic.toc();
    end
end
initial_pos = prosthesis.read;

% ---
figure
plot(0:(length(initial_pos) - 1), initial_pos, "o:")
legend("1", "2", "3", "4")
% xline((1:4)/sampling_period, "HandleVisibility","off")
% --
ax = gca;
ax.FontSize = 30;
ylabel("Encoder count")
xlabel("Time [100 ms]")