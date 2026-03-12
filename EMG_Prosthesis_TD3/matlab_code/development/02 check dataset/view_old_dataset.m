%view_old_dataset 

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: Jonathan Zea
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

02 January 2024
%}

clear all
% close all
clc
%% Configs


%% Aux and dependent variables
% libs
addpath(genpath('src'))

%% 
[emg, glove, metadata] = getDataset("jona_2022");

%%
close all
i = 30;

plot_open_close(emg(i, :), glove(i, :), "title", sprintf("jona 2022: %d", i))

%%
i = 40;

plot_open_close(emg(i, :), glove(i, :), "title", sprintf("jona 2022: %d", i))

%%
i = 193;

plot_open_close(emg(i, :), glove(i, :), "title", sprintf("jona 2022: %d", i))