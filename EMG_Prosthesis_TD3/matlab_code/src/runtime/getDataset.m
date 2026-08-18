function [emg, glove, metadata] = getDataset(datasetName_s, folderData, referenceSource)
%getDataset returns EMG and glove data from a formed dataset or various
%datasets. It also returns the metadata of the datasets.
%
% Inputs
%   datasetName_s   char with name, or cell of chars. Every char must
%                   correspond to a file.
%   folderData      dataset folder.
%   referenceSource "glove" requires emgs, gloves and metadata;
%                   "emgIntent" loads only emgs and metadata.
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
    referenceSource (1, 1) string = "glove";
end

if ~any(referenceSource == ["glove", "emgIntent"])
    error("getDataset:InvalidReferenceSource", ...
        "referenceSource must be either 'glove' or 'emgIntent'.");
end

%% configs
if ~iscell(datasetName_s)
    datasetName_s = {datasetName_s};
end

folderData = resolveDatasetFolder(folderData);

%% loading
emg = {};
glove = {};
metadata = struct();

for f = datasetName_s
    datasetPath = fullfile(folderData, f{1});
    availableVariables = string(who('-file', datasetPath));
    if ~any(availableVariables == "emgs")
        error("getDataset:MissingEmg", ...
            "Dataset %s does not contain 'emgs'.", string(f{1}));
    end
    if ~any(availableVariables == "metadata")
        error("getDataset:MissingMetadata", ...
            "Dataset %s does not contain 'metadata'.", string(f{1}));
    end
    if referenceSource == "glove" && ~any(availableVariables == "gloves")
        error("getDataset:MissingGloves", ...
            "Dataset %s does not contain 'gloves'.", string(f{1}));
    end

    if referenceSource == "glove"
        vars = load(datasetPath, "emgs", "gloves", "metadata");
    else
        % Do not materialize or require glove data in EMG-only mode.
        vars = load(datasetPath, "emgs", "metadata");
    end
    emg = [emg; vars.emgs];
    if referenceSource == "glove"
        glove = [glove; vars.gloves];
    end
    metadata.(f{1}) = vars.metadata;
end

end

function folderData = resolveDatasetFolder(folderData)
folderData = string(folderData);
if isfolder(folderData)
    return;
end

runtimeDir = fileparts(mfilename("fullpath"));
srcRoot = fileparts(runtimeDir);
matlabRoot = fileparts(srcRoot);
candidate = fullfile(matlabRoot, char(folderData));
if isfolder(candidate)
    folderData = string(candidate);
end
end
