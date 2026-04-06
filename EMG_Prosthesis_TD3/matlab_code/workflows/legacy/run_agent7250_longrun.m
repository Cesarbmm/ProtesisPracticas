function results = run_agent7250_longrun(options)
%run_agent7250_longrun resumes the canonical benchmark for long exploratory training.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
repoRoot = char(paths.workspaceRoot);

if ~isfield(options, "baseCheckpointPath") || isempty(options.baseCheckpointPath)
    options.baseCheckpointPath = getAgent7250CheckpointPath();
end
if ~isfield(options, "baseLabel") || isempty(options.baseLabel)
    options.baseLabel = "Agent7250";
end
if ~isfield(options, "resultsRoot") || isempty(options.resultsRoot)
    options.resultsRoot = fullfile( ...
        repoRoot, "Agentes", "agent7250_longrun", ...
        string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end

results = run_td3_longrun(options);
end
