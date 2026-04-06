function checkpointPath = getResidualFinalCheckpointPath()
%getResidualFinalCheckpointPath resolves the tracked final residual checkpoint.

canonicalRoot = getCanonicalCheckpointRoot();
canonicalPath = fullfile( ...
    canonicalRoot, "Agent1850_residual_alpha020", ...
    "Agent1850_residual_alpha020.mat");

if isfile(canonicalPath)
    checkpointPath = string(canonicalPath);
    return;
end

srcDir = fileparts(mfilename("fullpath"));
srcRoot = fileparts(srcDir);
matlabRoot = fileparts(srcRoot);
repoRoot = fileparts(fileparts(matlabRoot));
legacyPath = fullfile( ...
    repoRoot, "Agentes", "agent7250_residual_policy_pilot", ...
    "26-03-25 17 08 56", "training_run", "26-03-25 17 9 8", ...
    "Agent1850.mat");

checkpointPath = string(legacyPath);
end
