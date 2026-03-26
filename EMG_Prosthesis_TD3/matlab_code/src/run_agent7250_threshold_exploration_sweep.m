function results = run_agent7250_threshold_exploration_sweep(options)
%run_agent7250_threshold_exploration_sweep runs staged threshold-aware exploration sweeps.

arguments
    options = struct()
end

options = normalizeThresholdSweepOptions(options);

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

baseRoot = resolveStageResultsRoot(options.resultsRoot, repoRoot, options.stage);
mkdir(baseRoot);

switch options.stage
    case "stage1"
        launchOptions = buildStage1LaunchOptions(options, baseRoot);
    case "stage2"
        stage1Reference = resolveStageReference(options, repoRoot, "stage1");
        launchOptions = buildStage2LaunchOptions(options, baseRoot, stage1Reference);
    case "stage3"
        stage2Reference = resolveStageReference(options, repoRoot, "stage2");
        launchOptions = buildStage3LaunchOptions(options, baseRoot, stage2Reference);
    otherwise
        error("Unsupported stage '%s'.", string(options.stage));
end

results = run_agent7250_low_exploration_finetune(launchOptions);
stageSummary = struct( ...
    "stage", string(options.stage), ...
    "resultsRoot", string(baseRoot), ...
    "launchOptions", launchOptions, ...
    "results", results);

save(fullfile(baseRoot, "threshold_exploration_stage_results.mat"), "stageSummary");
writeTextFile(fullfile(baseRoot, "threshold_exploration_stage_summary.txt"), ...
    buildStageSummaryText(stageSummary));
end

function options = normalizeThresholdSweepOptions(options)
defaults = struct( ...
    "stage", "stage1", ...
    "checkpointPath", getAgent7250CheckpointPath(), ...
    "resultsRoot", "", ...
    "trainingEpisodes", 1500, ...
    "trainingSaveEvery", 50, ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 2, ...
    "auditEveryK", 50, ...
    "auditTailCount", 12, ...
    "bestExplorationStd", NaN, ...
    "bestExplorationStdMin", NaN, ...
    "bestExplorationStdDecayRate", NaN);

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.stage = string(options.stage);
options.checkpointPath = string(options.checkpointPath);
options.bestExplorationStd = double(options.bestExplorationStd);
options.bestExplorationStdMin = double(options.bestExplorationStdMin);
options.bestExplorationStdDecayRate = double(options.bestExplorationStdDecayRate);
end

function launchOptions = buildStage1LaunchOptions(options, baseRoot)
launchOptions = struct( ...
    "checkpointPath", options.checkpointPath, ...
    "explorationStdValues", [0.03 0.04 0.05 0.06], ...
    "explorationStdMinValues", 0.005, ...
    "explorationStdDecayRateValues", 1e-4, ...
    "resetBufferValues", false, ...
    "trainingEpisodes", options.trainingEpisodes, ...
    "trainingSaveEvery", options.trainingSaveEvery, ...
    "trainingPlots", "none", ...
    "auditFastSimulations", options.auditFastSimulations, ...
    "auditFullSimulations", options.auditFullSimulations, ...
    "auditTopK", options.auditTopK, ...
    "auditEveryK", options.auditEveryK, ...
    "auditTailCount", options.auditTailCount, ...
    "thresholdAware", true, ...
    "resultsRoot", baseRoot);
end

function launchOptions = buildStage2LaunchOptions(options, baseRoot, stageReference)
bestStd = options.bestExplorationStd;
if isnan(bestStd)
    bestStd = stageReference.bestExplorationStd;
end
if isnan(bestStd)
    error("Stage 2 requires a best explorationStd from stage 1.");
end

launchOptions = struct( ...
    "checkpointPath", options.checkpointPath, ...
    "explorationStdValues", bestStd, ...
    "explorationStdMinValues", 0.005, ...
    "explorationStdDecayRateValues", [0 5e-5 1e-4], ...
    "resetBufferValues", false, ...
    "trainingEpisodes", options.trainingEpisodes, ...
    "trainingSaveEvery", options.trainingSaveEvery, ...
    "trainingPlots", "none", ...
    "auditFastSimulations", options.auditFastSimulations, ...
    "auditFullSimulations", options.auditFullSimulations, ...
    "auditTopK", options.auditTopK, ...
    "auditEveryK", options.auditEveryK, ...
    "auditTailCount", options.auditTailCount, ...
    "thresholdAware", true, ...
    "resultsRoot", baseRoot);
end

function launchOptions = buildStage3LaunchOptions(options, baseRoot, stageReference)
bestStd = options.bestExplorationStd;
bestDecay = options.bestExplorationStdDecayRate;
bestStdMin = options.bestExplorationStdMin;

if isnan(bestStd)
    bestStd = stageReference.bestExplorationStd;
end
if isnan(bestDecay)
    bestDecay = stageReference.bestExplorationStdDecayRate;
end
if isnan(bestStdMin)
    bestStdMin = stageReference.bestExplorationStdMin;
end

if isnan(bestStd) || isnan(bestDecay)
    error("Stage 3 requires a best explorationStd and best explorationStdDecayRate from stage 2.");
end
if isnan(bestStdMin)
    bestStdMin = 0.005;
end

launchOptions = struct( ...
    "checkpointPath", options.checkpointPath, ...
    "explorationStdValues", bestStd, ...
    "explorationStdMinValues", bestStdMin, ...
    "explorationStdDecayRateValues", bestDecay, ...
    "resetBufferValues", true, ...
    "trainingEpisodes", options.trainingEpisodes, ...
    "trainingSaveEvery", options.trainingSaveEvery, ...
    "trainingPlots", "training-progress", ...
    "auditFastSimulations", options.auditFastSimulations, ...
    "auditFullSimulations", options.auditFullSimulations, ...
    "auditTopK", options.auditTopK, ...
    "auditEveryK", options.auditEveryK, ...
    "auditTailCount", options.auditTailCount, ...
    "thresholdAware", true, ...
    "resultsRoot", baseRoot);
end

function stageReference = resolveStageReference(options, repoRoot, requiredStage)
stageReference = struct( ...
    "stageRoot", "", ...
    "bestExplorationStd", NaN, ...
    "bestExplorationStdMin", NaN, ...
    "bestExplorationStdDecayRate", NaN);

root = fullfile(repoRoot, "Agentes", "agent7250_threshold_exploration_sweep");
if ~isfolder(root)
    error("No prior threshold exploration results found for %s.", string(requiredStage));
end

dirInfo = dir(root);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No threshold exploration stage directories found for %s.", string(requiredStage));
end

stageRoots = strings(0, 1);
stageTimes = [];
for i = 1:numel(dirInfo)
    currentDir = fullfile(dirInfo(i).folder, dirInfo(i).name);
    summaryFile = fullfile(currentDir, "threshold_exploration_stage_results.mat");
    if ~isfile(summaryFile)
        continue;
    end
    aux = load(summaryFile, "stageSummary");
    if ~isfield(aux, "stageSummary")
        continue;
    end
    if string(aux.stageSummary.stage) ~= string(requiredStage)
        continue;
    end
    stageRoots(end+1, 1) = string(currentDir); %#ok<AGROW>
    stageTimes(end+1, 1) = dirInfo(i).datenum; %#ok<AGROW>
end

if isempty(stageRoots)
    error("No threshold exploration results found for %s.", string(requiredStage));
end

[~, idx] = max(stageTimes);
stageRoot = stageRoots(idx);
aux = load(fullfile(stageRoot, "threshold_exploration_stage_results.mat"), "stageSummary");
stageSummary = aux.stageSummary;
bestRow = table2struct(stageSummary.results.consolidatedTable(1, :));

stageReference.stageRoot = stageRoot;
stageReference.bestExplorationStd = double(bestRow.explorationStd);
stageReference.bestExplorationStdMin = double(bestRow.explorationStdMin);
stageReference.bestExplorationStdDecayRate = double(bestRow.explorationStdDecayRate);

if ~isNearAcceptance(bestRow, stageSummary.results.benchmark)
    error("Best %s result is not near enough to benchmark to justify %s.", ...
        string(requiredStage), string(options.stage));
end
end

function tf = isNearAcceptance(bestRow, benchmark)
trackingOk = double(bestRow.trackingMseMean) <= benchmark.trackingMse * 1.05;
saturationOk = double(bestRow.saturationFractionMean) <= benchmark.saturationFraction;
actionOk = double(bestRow.actionL2Mean) <= benchmark.actionL2;
tf = trackingOk && saturationOk && actionOk;
end

function resultsRoot = resolveStageResultsRoot(requestedRoot, repoRoot, stage)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    resultsRoot = char(requestedRoot);
else
    resultsRoot = fullfile( ...
        repoRoot, "Agentes", "agent7250_threshold_exploration_sweep", ...
        sprintf("%s__%s", string(datetime("now", "Format", "yy-MM-dd HH mm ss")), stage));
end
end

function textValue = buildStageSummaryText(stageSummary)
lines = strings(0, 1);
lines(end+1) = sprintf("Threshold exploration stage: %s", string(stageSummary.stage));
lines(end+1) = sprintf("Results root: %s", string(stageSummary.resultsRoot));
lines(end+1) = "";
lines(end+1) = strtrim(string(evalc("disp(stageSummary.results.consolidatedTable)")));
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
