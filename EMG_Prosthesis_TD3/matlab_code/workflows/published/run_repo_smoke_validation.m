function results = run_repo_smoke_validation(options)
%run_repo_smoke_validation validates the migrated MATLAB repo in simulation mode.

arguments
    options = struct()
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
projectRoot = char(paths.projectRoot);
workspaceRoot = char(paths.workspaceRoot);

cd(matlabRoot);
addpath(genpath(matlabRoot));
clearConfigurablesOverride();

resultsRoot = fullfile(workspaceRoot, "Agentes", "repo_smoke_validation");
if isfield(options, "resultsRoot") && strlength(string(options.resultsRoot)) > 0
    resultsRoot = char(string(options.resultsRoot));
end
ensureDirectoryExists(resultsRoot);

checkpointRoot = fullfile(resultsRoot, "checkpoint_smoke");
stopbandRoot = fullfile(resultsRoot, "stopband_confirmation_smoke");

toolboxNames = string({ver().Name});
requiredToolboxes = [ ...
    "MATLAB", ...
    "Deep Learning Toolbox", ...
    "Reinforcement Learning Toolbox", ...
    "Signal Processing Toolbox"];

missingToolboxes = requiredToolboxes(~ismember(requiredToolboxes, toolboxNames));
if ~isempty(missingToolboxes)
    error("Missing required toolboxes: %s", strjoin(missingToolboxes, ", "));
end

configs = configurables();
agent7250Path = string(getAgent7250CheckpointPath());
residualFinalPath = string(getResidualFinalCheckpointPath());

if ~isfolder(fullfile(matlabRoot, "data", "datasets", "Denis Dataset"))
    error("Dataset folder not found under matlab_code/data/datasets/Denis Dataset");
end
if ~isfile(agent7250Path)
    error("Canonical Agent7250 checkpoint not found: %s", agent7250Path);
end
if ~isfile(residualFinalPath)
    error("Canonical residual checkpoint not found: %s", residualFinalPath);
end

runCheckpointTest(agent7250Path, 2, false, struct("resultsRoot", checkpointRoot));

stopbandOptions = struct( ...
    "stopBandEpisode", 2000, ...
    "stopBandWindow", [1750 2250], ...
    "seeds", 66, ...
    "trainingEpisodes", 200, ...
    "trainingSaveEvery", 100, ...
    "episodeSaveFreq", 100, ...
    "auditFastSimulations", 2, ...
    "auditFullSimulations", 2, ...
    "auditTopK", 1, ...
    "comparisonSimulations", 2, ...
    "generateReport", false, ...
    "compileReport", false, ...
    "resultsRoot", stopbandRoot);
stopbandOptions = mergeStructs(stopbandOptions, options);
stopbandOptions.resultsRoot = stopbandRoot;
stopbandResults = run_residual_lift_stopband_confirmation(stopbandOptions);

results = struct();
results.repoRoot = string(workspaceRoot);
results.projectRoot = string(projectRoot);
results.matlabRoot = string(matlabRoot);
results.resultsRoot = string(resultsRoot);
results.matlabVersion = string(version);
results.requiredToolboxes = requiredToolboxes;
results.detectedToolboxes = toolboxNames;
results.datasetFolder = string(configs.dataset_folder);
results.agent7250Path = agent7250Path;
results.residualFinalPath = residualFinalPath;
results.checkpointSmokeRoot = string(checkpointRoot);
results.stopbandSmokeRoot = string(stopbandRoot);
results.stopbandStatus = string(stopbandResults.summary.aggregateBenchmarkDecision.status);
results.stopbandResults = stopbandResults;

save(fullfile(resultsRoot, "repo_smoke_validation_results.mat"), "results");
end

function merged = mergeStructs(baseStruct, patchStruct)
merged = baseStruct;
fields = fieldnames(patchStruct);
for i = 1:numel(fields)
    merged.(fields{i}) = patchStruct.(fields{i});
end
end
