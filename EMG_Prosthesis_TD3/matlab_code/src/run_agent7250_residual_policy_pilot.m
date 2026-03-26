function results = run_agent7250_residual_policy_pilot(options)
%run_agent7250_residual_policy_pilot keeps the historical Agent7250 wrapper.

arguments
    options = struct()
end

if ~isfield(options, "baseCheckpointPath") && isfield(options, "checkpointPath")
    options.baseCheckpointPath = options.checkpointPath;
end
if ~isfield(options, "baseCheckpointPath") || strlength(string(options.baseCheckpointPath)) == 0
    options.baseCheckpointPath = getAgent7250CheckpointPath();
end
if ~isfield(options, "baseLabel") || strlength(strtrim(string(options.baseLabel))) == 0
    options.baseLabel = "Agent7250";
end
if ~isfield(options, "resultsRoot") || strlength(strtrim(string(options.resultsRoot))) == 0
    srcDir = fileparts(mfilename("fullpath"));
    matlabRoot = fileparts(srcDir);
    repoRoot = fileparts(fileparts(matlabRoot));
    options.resultsRoot = fullfile( ...
        repoRoot, "Agentes", "agent7250_residual_policy_pilot", ...
        string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end

results = run_residual_lift_pilot(rmfieldIfPresent(options, "checkpointPath"));
writeLegacyCompatibilityFiles(string(results.resultsRoot));
end

function s = rmfieldIfPresent(s, fieldName)
if isfield(s, fieldName)
    s = rmfield(s, fieldName);
end
end

function writeLegacyCompatibilityFiles(resultsRoot)
copyIfExists(fullfile(resultsRoot, "residual_lift_pilot_summary.csv"), ...
    fullfile(resultsRoot, "agent7250_residual_policy_pilot_summary.csv"));
copyIfExists(fullfile(resultsRoot, "residual_lift_pilot_summary.txt"), ...
    fullfile(resultsRoot, "agent7250_residual_policy_pilot_summary.txt"));
copyIfExists(fullfile(resultsRoot, "residual_lift_pilot_results.mat"), ...
    fullfile(resultsRoot, "agent7250_residual_policy_pilot_results.mat"));
end

function copyIfExists(sourcePath, targetPath)
if isfile(sourcePath)
    copyfile(sourcePath, targetPath);
end
end
