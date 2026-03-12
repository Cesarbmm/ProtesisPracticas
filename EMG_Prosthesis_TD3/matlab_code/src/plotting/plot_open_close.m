function plot_open_close(EMG, gloveData, format, options)
%plot_open_close() plots the a given EMG and glove data of a sample. It
%does the conversion of the glove data.
%
%
% # INPUTS
%  EMG
%  gloveData
%  options      Name-value pairs of options

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

%% Input Validation
arguments
    EMG         (1, 2) cell
    gloveData   (1, 2) cell
    format      (1, 1) string = "sum_by_finger";
    options.title (1, 1) string = "";
end

%%
[~, f] = figurePRO();

ax = cell(2, 2);
for i = 1:2
    ax{i} = subplot(2, 2, i, "Parent", f, "fontSize", 25);
    hold(ax{i}, "on")
end

%%
plot(ax{1}, EMG{1})
plot(ax{2}, EMG{2})
ax{1}.YLim = [-1 1];
ax{2}.YLim = [-1 1];
title(ax{2}, options.title)

%%
subplot(2, 2, 3, "Parent", f, "fontSize", 25);
glove_tb = Glove.change_format(gloveData{1}, format);
stackedplot(glove_tb)

subplot(2, 2, 4, "Parent", f, "fontSize", 25);
glove_tb = Glove.change_format(gloveData{2}, format);
stackedplot(glove_tb)