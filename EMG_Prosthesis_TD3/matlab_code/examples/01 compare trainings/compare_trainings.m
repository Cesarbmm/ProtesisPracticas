%compare_trainings plots the rewards between 2 different training sessions.
% It assumes that you saved the train_data variable of the sessions. 
%

% For example:
% random = trainInterface("00_random", "Param", "random");
% best = trainInterface("00_random", "Param", "best");
% (Check the saved files). 

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: z_tja
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

28 February 2024
%}

% random = trainInterface("00_random", "", "random");
% best = trainInterface("00_random", "Param", "best");

clear all
close all
clc
%% Data
best = load('best.mat');
best = best.train_data;


random = load('random.mat');
random = random.train_data;


%% 
best_rewards = [best.Reward];
random_rewards = [random.Reward];

%%
random_data = {random_rewards(:).Data};
best_data = {best_rewards(:).Data};

%%
random_avg = cellfun(@(x)mean(x),random_data);
best_avg = cellfun(@(x)mean(x),best_data);

%%
random_std = cellfun(@(x)std(x),random_data);
best_std = cellfun(@(x)std(x),best_data);
%%
f = figure();
ax = gca();
hold on

% errorbar(ax, random_avg, random_std)
% errorbar(ax, best_avg, best_std)
plot(ax, random_avg)
plot(ax, best_avg)
legend("random", "best")