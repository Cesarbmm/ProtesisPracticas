%view_glove views the limits and ranges of the flex data

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Laboratorio IA
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

03 April 2024
%}

% cc
%% Configs
% configs.dataset_folder = '.\data\datasets\Denis Dataset\';
% configs.dataset = {"BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA", "JOE", "JONATHAN", "KHAROL", "MATEO", "SANDRA"}; % or a cell of names.

configs.dataset_folder = '.\data\datasets\';
configs.dataset = {"jona_2022"}; % or a cell of names.

[emg, gloveDataset] = getDataset(configs.dataset, configs.dataset_folder);

%% Aux and dependent variables
% libs
addpath(genpath('src'))


%%
% close all
clc
ax = figurePRO(1);
glove_sample = gloveDataset{14};

flexData = reduceFlexDimension(glove_sample)

plot(flexData, ":o")
fingers = definitions("fingers")
legend(fingers, "Location", "best")

xlabel("Time [100 ms]")
ylabel("Flexion")
%%

figurePRO(2);

for ax = 1:8
    axs{ax} = subplot(4, 2, ax, "fontsize", 20);
    hold(axs{ax}, "on")
    ii = ceil(ax/2);
    ylabel(fingers{ii })
end

% --------
for i = 1:size(gloveDataset, 1)
    for j = 1:2
        glove_sample = gloveDataset{i, j};

        flexData = reduceFlexDimension(glove_sample);

        for ax = 1:4
            plot(axs{2*(ax - 1) + j}, flexData(:, ax),":")
        end
    end


    % plot(flexData, ".")
    % fingers = definitions("fingers")
    % legend(fingers, "Location", "best")
end

%%
r_red = cellfun(@(x) reduceFlexDimension(x), gloveDataset, "UniformOutput", false);

%
ax = figurePRO(3);

while true
    cla
    plot(ax, r_red{randi(length(r_red)), 1})
    drawnow
    pause(0.2)
end


%%
wer = {};
wer{1} = cat(1, r_red{:, 1});
wer{2} = cat(1, r_red{:, 2});

%%
ax = figurePRO(4);
for sid = 1:2
    ww = wer{sid};
    for ax = 1:4
        axs{ax} = subplot(4, 2, (ax - 1)*2 + sid, "fontsize", 20);
        hold(axs{ax}, "on")
        plot(axs{ax}, ww(:, ax),".:")

        % axs{ax}.XLim =[4100 5300];
        % ii = ceil(ax/2);
        ylabel(fingers{ax})
    end
end

%%
ax = figurePRO(5);
q = r_red';
ALL_DATA = cat(1, q{:});


for ax = 1:4
    axs{ax} = subplot(4, 1, ax, "fontsize", 20);
    hold(axs{ax}, "on")
    plot(axs{ax}, ALL_DATA(:, ax),".:")

    % axs{ax}.XLim =[4100 5300];
    % ii = ceil(ax/2);
    if ax ~= 3
        axs{ax}.YLim = [900 2046];
    else
        axs{ax}.YLim = [300 1023];
    end
    ylabel(fingers{ax})
end