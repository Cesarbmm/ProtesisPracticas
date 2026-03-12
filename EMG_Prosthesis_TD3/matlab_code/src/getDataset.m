function [emg, glove, metadata] = getDataset(datasetName_s, folderData)
%getDataset returns EMG and glove data from a formed dataset or various
%datasets. It also returns the metadata of the datasets.
%
% Inputs
%   datasetName_s   char with name, or cell of chars. Every char must
%                   correspond to a file. The files must have emgs, gloves
%                   and metadata fields.
%
% Outputs
%   emg             N-by- 2 cell, N samples, 1st col closing, 2nd opening.
%                   Every sample is m-by-8 double.
%   glove           cell of n struct with fields
%   metadata        struct by id, each field has the metadata of its
%                   dataset.

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

29 December 2021
Matlab R2021b.

New ver modified after 2nd January 2024. 
%}

%% Input Validation
arguments
    datasetName_s
    folderData (1, 1) string = '.\data\datasets\';
end

%% configs
if ~iscell(datasetName_s)
    datasetName_s = {datasetName_s};
end

%% loading
emg = {};
glove = {};

for f = datasetName_s
    vars = load( fullfile( folderData, f{1} ) );
    emg = [emg; vars.emgs];
    glove = [glove; vars.gloves];
    metadata.(f{1}) = vars.metadata;
end
