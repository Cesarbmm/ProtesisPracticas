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
benchmarkRoot = fullfile(resultsRoot, "benchmark_td3_seeded_smoke");

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

if ~isfolder(fullfile(matlabRoot, "data", "datasets", "Denis Dataset"))
    error("Dataset folder not found under matlab_code/data/datasets/Denis Dataset");
end
if ~isfile(agent7250Path)
    error("Canonical Agent7250 checkpoint not found: %s", agent7250Path);
end

runCheckpointTest(agent7250Path, 2, false, struct("resultsRoot", checkpointRoot));

benchmarkOptions = struct( ...
    "seeds", 66, ...
    "trainingEpisodes", 1, ...
    "trainingSaveEvery", 1, ...
    "episodeSaveFreq", 1, ...
    "auditFastSimulations", 1, ...
    "auditFullSimulations", 1, ...
    "auditTopK", 1, ...
    "finalTestEpisodes", 1, ...
    "plotEpisodeOnTest", true, ...
    "useGpu", false, ...
    "runMotor2SanityCheck", true, ...
    "evaluateReferenceCheckpoints", false, ...
    "generateReport", false, ...
    "compileReport", false, ...
    "resultsRoot", benchmarkRoot);
benchmarkOptions = mergeStructs(benchmarkOptions, options);
benchmarkOptions.resultsRoot = benchmarkRoot;
benchmarkResults = run_benchmark_td3_seeded_retrain_motor2_diagnostic(benchmarkOptions);

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
results.checkpointSmokeRoot = string(checkpointRoot);
results.benchmarkSmokeRoot = string(benchmarkRoot);
results.benchmarkSmokeStatus = string(benchmarkResults.aggregateSummary.aggregateDecision.status);
results.benchmarkResults = benchmarkResults;

save(fullfile(resultsRoot, "repo_smoke_validation_results.mat"), "results");
end

function merged = mergeStructs(baseStruct, patchStruct)
merged = baseStruct;
fields = fieldnames(patchStruct);
for i = 1:numel(fields)
    merged.(fields{i}) = patchStruct.(fields{i});
end
end
