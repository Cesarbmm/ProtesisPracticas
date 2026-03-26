function results = run_markov52_offline_to_online_experiment(options)
%run_markov52_offline_to_online_experiment fine-tunes from the best offline checkpoint.

arguments
    options = struct()
end

options = normalizeOnlineOptions(options);

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

clearConfigurablesOverride();

benchmark = getAgent7250Benchmark();
baseConfigs = configurables();
warmstartCheckpointPath = resolveWarmstartCheckpoint(options, repoRoot);

resultsRoot = resolveResultsRoot(options.resultsRoot, repoRoot, "markov52_offline_to_online");
onlineBaseDir = fullfile(resultsRoot, "training_run");
mkdir(resultsRoot);
mkdir(onlineBaseDir);

override = buildMarkov52BaselineOverride(baseConfigs, struct( ...
    "run_training", true, ...
    "newTraining", false, ...
    "agentFile", warmstartCheckpointPath, ...
    "agent_id", "td3", ...
    "trainingMaxEpisodes", options.onlineEpisodes, ...
    "trainingSaveAgentEvery", options.trainingSaveEvery, ...
    "trainingPlots", string(options.trainingPlots), ...
    "plotEpisodeOnTest", false, ...
    "verbose", false));
override.agents_directory = @(agent_id, variant) fullfile( ...
    onlineBaseDir, string(datetime("now", "Format", "yy-MM-dd HH m s")));

setConfigurablesOverride(override);
evalin('base', 'clear classes');
clear configurables
cleanup = onCleanup(@() clearConfigurablesOverride()); %#ok<NASGU>

trainInterface("td3", "offlineWarmstart", "");
clearConfigurablesOverride();

runDir = findNewestSubdir(onlineBaseDir);
analysis = analyzeExperimentRun(runDir);

auditOptions = struct( ...
    "experimentDir", runDir, ...
    "samplingPolicy", struct("mode", "tail_every_k_last_n", ...
        "k", options.auditEveryK, "n", options.auditTailCount), ...
    "resultsRoot", fullfile(runDir, "audit"), ...
    "verbose", false);
auditResults = runCheckpointAudit( ...
    options.auditFastSimulations, ...
    options.auditFullSimulations, ...
    options.auditTopK, ...
    auditOptions);

bestRow = table2struct(auditResults.phaseBTable(1, :));
results = struct( ...
    "resultsRoot", string(resultsRoot), ...
    "runDir", string(runDir), ...
    "warmstartCheckpointPath", string(warmstartCheckpointPath), ...
    "trainingSummary", analysis.trainingSummary, ...
    "episodeSummary", analysis.episodeSummary, ...
    "auditResults", auditResults, ...
    "benchmark", benchmark, ...
    "bestCheckpointPath", string(bestRow.checkpointPath), ...
    "bestCheckpointEpisode", double(bestRow.checkpointEpisode));

save(fullfile(resultsRoot, "offline_to_online_results.mat"), ...
    "results", "analysis", "auditResults", "bestRow", "benchmark", "options");
writeTextFile(fullfile(resultsRoot, "offline_to_online_summary.txt"), ...
    buildOnlineSummaryText(results, bestRow, benchmark));
end

function options = normalizeOnlineOptions(options)
defaults = struct( ...
    "warmstartCheckpointPath", "", ...
    "offlineResultsRoot", "", ...
    "onlineEpisodes", 4000, ...
    "trainingSaveEvery", 100, ...
    "trainingPlots", "training-progress", ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 2, ...
    "auditEveryK", 100, ...
    "auditTailCount", 10, ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
end

function checkpointPath = resolveWarmstartCheckpoint(options, repoRoot)
if strlength(string(options.warmstartCheckpointPath)) > 0
    checkpointPath = string(options.warmstartCheckpointPath);
    return;
end

offlineRoot = string(options.offlineResultsRoot);
if strlength(offlineRoot) == 0
    offlineExperimentsRoot = fullfile(repoRoot, "Agentes", "markov52_offline_bc_warmstart");
    offlineRoot = inferLatestExperimentDir(string(offlineExperimentsRoot));
end

resultsFile = fullfile(offlineRoot, "offline_bc_warmstart_results.mat");
if ~isfile(resultsFile)
    error("Could not resolve warm-start checkpoint: %s not found.", resultsFile);
end

data = load(resultsFile, "results");
checkpointPath = string(data.results.bestCheckpointPath);
if strlength(checkpointPath) == 0 || ~isfile(checkpointPath)
    error("Warm-start checkpoint from %s is invalid.", resultsFile);
end
end

function experimentDir = inferLatestExperimentDir(experimentsRoot)
dirInfo = dir(experimentsRoot);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No offline warm-start experiment directories found in %s", experimentsRoot);
end
[~, idx] = max([dirInfo.datenum]);
experimentDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function newestDir = findNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No training subdirectory found in %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
newestDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function resultsRoot = resolveResultsRoot(requestedRoot, repoRoot, folderName)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    resultsRoot = char(requestedRoot);
else
    resultsRoot = fullfile(repoRoot, "Agentes", folderName, ...
        string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end
end

function textValue = buildOnlineSummaryText(results, bestRow, benchmark)
lines = strings(0, 1);
lines(end+1) = "markov52 offline-to-online experiment";
lines(end+1) = "===================================";
lines(end+1) = "";
lines(end+1) = sprintf("Warm-start checkpoint: %s", results.warmstartCheckpointPath);
lines(end+1) = sprintf("Run dir: %s", results.runDir);
lines(end+1) = sprintf("Best online checkpoint: %s", string(bestRow.checkpointPath));
lines(end+1) = sprintf("Best online trackingMSE: %.6f", double(bestRow.trackingMseMean));
lines(end+1) = sprintf("Best online saturationFraction: %.6f", double(bestRow.saturationFractionMean));
lines(end+1) = sprintf("Benchmark trackingMSE: %.6f", benchmark.trackingMse);
lines(end+1) = sprintf("Benchmark saturationFraction: %.6f", benchmark.saturationFraction);
lines(end+1) = sprintf("Benchmark status: %s", string(bestRow.benchmarkStatus));
textValue = strjoin(lines, newline);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end
