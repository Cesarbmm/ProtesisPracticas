function results = runCheckpointAudit(numSimulationsFast, numSimulationsFull, topK, options)
%runCheckpointAudit runs the checkpoint audit suite with flexible selection.
%
% Supported usage patterns:
%   runCheckpointAudit()
%   runCheckpointAudit(50, 200, 3)
%   runCheckpointAudit(50, 200, 3, struct("experimentDir", runDir))
%   runCheckpointAudit(50, 200, 3, struct("checkpointPaths", paths))
%   runCheckpointAudit(50, 200, 3, struct( ...
%       "experimentDir", runDir, ...
%       "samplingPolicy", struct("mode", "tail_last_n", "n", 8)))

arguments
    numSimulationsFast (1, 1) double {mustBeInteger, mustBePositive} = 50
    numSimulationsFull (1, 1) double {mustBeInteger, mustBePositive} = 200
    topK (1, 1) double {mustBeInteger, mustBePositive} = 3
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

results = evaluateCheckpointSuite( ...
    string.empty(1, 0), ...
    numSimulationsFast, ...
    numSimulationsFull, ...
    topK, ...
    options);
end
