function results = evaluateCheckpointSuite(checkpointPaths, numSimulationsFast, numSimulationsFull, topK, options)
%evaluateCheckpointSuite audits checkpoints across experiments in two phases.
%
% The suite keeps backward compatibility with explicit checkpoint lists
% while also supporting experiment discovery and tail sampling policies.

arguments
    checkpointPaths = string.empty(1, 0)
    numSimulationsFast (1, 1) double {mustBeInteger, mustBePositive} = 50
    numSimulationsFull (1, 1) double {mustBeInteger, mustBePositive} = 200
    topK (1, 1) double {mustBeInteger, mustBePositive} = 3
    options = struct()
end

close all
clc
rng("default");

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

options = normalizeAuditOptions(options, repoRoot);
[resolvedCheckpointPaths, selectionInfo] = resolveCheckpointSelection( ...
    checkpointPaths, options, repoRoot);
benchmark = getAgent7250Benchmark();

try
    resultsRoot = resolveResultsRoot(options, repoRoot);
    mkdir(resultsRoot);

    phaseAFolder = fullfile(resultsRoot, "phaseA_fast");
    phaseBFolder = fullfile(resultsRoot, "phaseB_full");
    mkdir(phaseAFolder);
    mkdir(phaseBFolder);

    phaseASimOpts = rlSimulationOptions( ...
        'MaxSteps', options.maxSteps, ...
        'NumSimulations', numSimulationsFast, ...
        'StopOnError', 'on', ...
        'UseParallel', false);
    phaseBSimOpts = rlSimulationOptions( ...
        'MaxSteps', options.maxSteps, ...
        'NumSimulations', numSimulationsFull, ...
        'StopOnError', 'on', ...
        'UseParallel', false);

    phaseATable = runCheckpointBatch( ...
        resolvedCheckpointPaths, phaseAFolder, phaseASimOpts, benchmark);
    phaseATable = rankResultsTable(phaseATable);

    shortlistCount = min(topK, height(phaseATable));
    shortlistPaths = string(phaseATable.checkpointPath(1:shortlistCount));
    phaseBTable = runCheckpointBatch( ...
        shortlistPaths, phaseBFolder, phaseBSimOpts, benchmark);
    phaseBTable = rankResultsTable(phaseBTable);

    results = struct( ...
        "resultsRoot", string(resultsRoot), ...
        "selectionInfo", selectionInfo, ...
        "benchmark", benchmark, ...
        "phaseATable", phaseATable, ...
        "phaseBTable", phaseBTable, ...
        "bestCheckpointPath", string(phaseBTable.checkpointPath(1)), ...
        "bestCheckpointLabel", string(phaseBTable.checkpointLabel(1)), ...
        "bestCheckpointEpisode", double(phaseBTable.checkpointEpisode(1)));

    summaryText = buildCheckpointAuditSummary(results);

    writetable(phaseATable, fullfile(resultsRoot, "checkpoint_audit_phaseA.csv"));
    writetable(phaseBTable, fullfile(resultsRoot, "checkpoint_audit_phaseB.csv"));
    writeTextFile(fullfile(resultsRoot, "checkpoint_audit_summary.txt"), summaryText);
    save(fullfile(resultsRoot, "checkpoint_audit_results.mat"), ...
        "results", "phaseATable", "phaseBTable", ...
        "resolvedCheckpointPaths", "numSimulationsFast", ...
        "numSimulationsFull", "topK", "selectionInfo", "options", "benchmark");

    clearConfigurablesOverride();

    if options.verbose
        disp(phaseATable)
        disp(phaseBTable)
        fprintf("Best checkpoint by protocol: %s\n", results.bestCheckpointPath);
        fprintf("Results saved to %s\n", resultsRoot);
    end
catch ME
    clearConfigurablesOverride();
    rethrow(ME);
end
end

function options = normalizeAuditOptions(options, repoRoot)
if nargin < 1 || isempty(options)
    options = struct();
end

defaults = struct( ...
    "experimentDir", "", ...
    "checkpointPaths", string.empty(1, 0), ...
    "samplingPolicy", struct(), ...
    "resultsRoot", "", ...
    "experimentsRoot", fullfile(repoRoot, "Agentes", "trainedAgentsProtesisTest", "td3", "_"), ...
    "maxSteps", 500, ...
    "verbose", true);

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.experimentDir = string(options.experimentDir);
options.checkpointPaths = string(options.checkpointPaths);
options.resultsRoot = string(options.resultsRoot);
options.experimentsRoot = string(options.experimentsRoot);

if ~isstruct(options.samplingPolicy)
    error("options.samplingPolicy must be a struct.");
end
end

function [resolvedCheckpointPaths, selectionInfo] = resolveCheckpointSelection(checkpointPaths, options, repoRoot)
selectionMode = "";
resolvedExperimentDir = "";

checkpointPaths = string(checkpointPaths);
if ~isempty(checkpointPaths)
    resolvedCheckpointPaths = checkpointPaths(:);
    selectionMode = "explicit_checkpoint_paths";
elseif ~isempty(options.checkpointPaths)
    resolvedCheckpointPaths = options.checkpointPaths(:);
    selectionMode = "explicit_checkpoint_paths";
elseif strlength(options.experimentDir) > 0
    resolvedExperimentDir = options.experimentDir;
    resolvedCheckpointPaths = discoverCheckpointsInExperiment( ...
        resolvedExperimentDir, options.samplingPolicy);
    selectionMode = "experiment_dir";
else
    resolvedExperimentDir = inferLatestExperimentDir(options.experimentsRoot);
    resolvedCheckpointPaths = discoverCheckpointsInExperiment( ...
        resolvedExperimentDir, options.samplingPolicy);
    selectionMode = "latest_experiment";
end

resolvedCheckpointPaths = unique(string(resolvedCheckpointPaths), "stable");
if isempty(resolvedCheckpointPaths)
    error("No checkpoints resolved for audit.");
end

if strlength(resolvedExperimentDir) == 0 && ~isempty(resolvedCheckpointPaths)
    resolvedExperimentDir = string(fileparts(resolvedCheckpointPaths(1)));
end

selectionInfo = struct( ...
    "mode", selectionMode, ...
    "experimentDir", resolvedExperimentDir, ...
    "experimentsRoot", string(options.experimentsRoot), ...
    "samplingPolicy", options.samplingPolicy, ...
    "checkpointCount", numel(resolvedCheckpointPaths));
end

function resultsRoot = resolveResultsRoot(options, repoRoot)
if strlength(options.resultsRoot) > 0
    resultsRoot = char(options.resultsRoot);
    return;
end

resultsRoot = fullfile( ...
    repoRoot, "Agentes", ...
    "checkpoint_audit", ...
    string(datetime("now", "Format", "yy-MM-dd HH mm ss")));
end

function experimentDir = inferLatestExperimentDir(experimentsRoot)
if strlength(experimentsRoot) == 0 || ~isfolder(experimentsRoot)
    error("Could not infer latest experiment: experiments root '%s' not found.", experimentsRoot);
end

dirInfo = dir(experimentsRoot);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("Could not infer latest experiment from '%s': no experiment directories found.", experimentsRoot);
end

candidatePaths = strings(0, 1);
candidateTimes = [];
for i = 1:numel(dirInfo)
    currentDir = fullfile(dirInfo(i).folder, dirInfo(i).name);
    if ~isempty(dir(fullfile(currentDir, "Agent*.mat")))
        candidatePaths(end+1, 1) = string(currentDir); %#ok<AGROW>
        candidateTimes(end+1, 1) = dirInfo(i).datenum; %#ok<AGROW>
    end
end

if isempty(candidatePaths)
    error("Could not infer latest experiment from '%s': no directories with Agent*.mat were found.", experimentsRoot);
end

[~, idx] = max(candidateTimes);
experimentDir = candidatePaths(idx);
end

function resultsTable = runCheckpointBatch(checkpointPaths, outputRoot, simOpts, benchmark)
rows = cell(numel(checkpointPaths), 1);

for i = 1:numel(checkpointPaths)
    rows{i} = runSingleCheckpointAudit( ...
        string(checkpointPaths(i)), outputRoot, i, simOpts, benchmark);
end

resultsTable = struct2table(vertcat(rows{:}));
end

function row = runSingleCheckpointAudit(checkpointPath, outputRoot, rowIndex, simOpts, benchmark)
if ~isfile(checkpointPath)
    error("Checkpoint not found: %s", checkpointPath);
end

checkpointLabel = buildCheckpointLabel(checkpointPath);
runDir = fullfile(outputRoot, sprintf("%02d_%s", rowIndex, checkpointLabel));
mkdir(runDir);

checkpointMeta = loadCheckpointMetadata(checkpointPath);
applyConfigurablesOverride(checkpointMeta.override);
setappdata(0, "checkpoint_audit_reload_context", struct( ...
    "checkpointPath", checkpointPath, ...
    "checkpointLabel", checkpointLabel, ...
    "runDir", string(runDir), ...
    "checkpointMeta", checkpointMeta, ...
    "simOpts", simOpts, ...
    "benchmark", benchmark));
clear classes
clear configurables
reloadContext = getappdata(0, "checkpoint_audit_reload_context");
rmappdata(0, "checkpoint_audit_reload_context");

checkpointPath = string(reloadContext.checkpointPath);
checkpointLabel = string(reloadContext.checkpointLabel);
runDir = char(reloadContext.runDir);
checkpointMeta = reloadContext.checkpointMeta;
simOpts = reloadContext.simOpts;
benchmark = reloadContext.benchmark;
configs = configurables();
hardware = definitions();
[emg, glove] = getDataset(configs.dataset, configs.dataset_folder);

agent = loadSavedAgent(checkpointPath);
env = Env(runDir, true, emg, glove);
env.log(sprintf("Checkpoint audit for %s", checkpointLabel));

trainingInfo = sim(agent, env, simOpts); %#ok<NASGU>
summary = summarizeEpisodeDirectory(runDir);
benchmarkDecision = classifyBenchmarkAcceptance(summary, benchmark);

save(fullfile(runDir, "audit_run.mat"), ...
    "summary", "benchmarkDecision", "checkpointPath", "checkpointLabel", ...
    "configs", "hardware", "simOpts", "checkpointMeta");

row = buildResultRow( ...
    checkpointLabel, checkpointPath, checkpointMeta, summary, benchmarkDecision);
clear env agent trainingInfo
end

function row = buildResultRow(checkpointLabel, checkpointPath, checkpointMeta, summary, benchmarkDecision)
row = struct( ...
    "checkpointLabel", string(checkpointLabel), ...
    "checkpointPath", string(checkpointPath), ...
    "experimentDir", string(fileparts(checkpointPath)), ...
    "checkpointEpisode", inferEpisodeFromCheckpointName(checkpointPath), ...
    "configPath", string(checkpointMeta.configPath), ...
    "rewardType", string(getMetaField(checkpointMeta.override, "rewardType", "")), ...
    "rewardActionWeight", double(getMetaField(checkpointMeta.override, "rewardActionWeight", NaN)), ...
    "rewardDeltaActionWeight", double(getMetaField(checkpointMeta.override, "rewardDeltaActionWeight", NaN)), ...
    "rewardSaturationWeight", double(getMetaField(checkpointMeta.override, "rewardSaturationWeight", NaN)), ...
    "rewardSaturationThreshold", double(getMetaField(checkpointMeta.override, "rewardSaturationThreshold", NaN)), ...
    "observationVariant", string(getMetaField(checkpointMeta.override, "observationVariant", "")), ...
    "quantizeCommandsForSimulation", logical(getMetaField(checkpointMeta.override, "quantizeCommandsForSimulation", false)), ...
    "actionInterfaceVariant", string(getMetaField(checkpointMeta.override, "actionInterfaceVariant", "")), ...
    "actionCommandActivationThreshold", double(getMetaField(checkpointMeta.override, "actionCommandActivationThreshold", NaN)), ...
    "actionWarpDeadzone", double(getMetaField(checkpointMeta.override, "actionWarpDeadzone", NaN)));

summaryFields = fieldnames(summary);
for k = 1:numel(summaryFields)
    value = summary.(summaryFields{k});
    if isscalar(value) || (isstring(value) && isscalar(value))
        row.(summaryFields{k}) = value;
    end
end

row.meetsConditionA = benchmarkDecision.meetsConditionA;
row.meetsConditionB = benchmarkDecision.meetsConditionB;
row.benchmarkStatus = benchmarkDecision.status;
row.trackingMsePctVsBenchmark = benchmarkDecision.trackingMsePctVsBenchmark;
row.saturationFractionPctVsBenchmark = benchmarkDecision.saturationFractionPctVsBenchmark;
row.actionL2PctVsBenchmark = benchmarkDecision.actionL2PctVsBenchmark;
row.deltaActionL2PctVsBenchmark = benchmarkDecision.deltaActionL2PctVsBenchmark;
end

function checkpointLabel = buildCheckpointLabel(checkpointPath)
[checkpointFolder, checkpointName, ext] = fileparts(checkpointPath);
[~, experimentLabel] = fileparts(checkpointFolder);
checkpointLabel = matlab.lang.makeValidName( ...
    sprintf("%s__%s%s", experimentLabel, checkpointName, ext), ...
    'ReplacementStyle', 'delete');
checkpointLabel = string(checkpointLabel);
end

function resultsTable = rankResultsTable(resultsTable)
resultsTable = sortrows( ...
    resultsTable, ...
    {'trackingMseMean', 'saturationFractionMean', 'deltaActionL2Mean', 'actionL2Mean'}, ...
    {'ascend', 'ascend', 'ascend', 'ascend'});
end

function agent = loadSavedAgent(checkpointPath)
vars = who('-file', checkpointPath);
if any(strcmp(vars, "agent"))
    aux = load(checkpointPath, "agent");
    agent = aux.agent;
elseif any(strcmp(vars, "saved_agent"))
    aux = load(checkpointPath, "saved_agent");
    agent = aux.saved_agent;
else
    error("Checkpoint %s does not contain an agent variable", checkpointPath);
end
end

function checkpointMeta = loadCheckpointMetadata(checkpointPath)
checkpointDir = fileparts(checkpointPath);
configPath = fullfile(checkpointDir, "00_configs.mat");

checkpointMeta = struct( ...
    "configPath", string(configPath), ...
    "override", struct());

if ~isfile(configPath)
    return;
end

aux = load(configPath, "configs");
if ~isfield(aux, "configs")
    return;
end

savedConfigs = aux.configs;
overrideFields = [ ...
    "stateLength", ...
    "rewardType", ...
    "rewardActionWeight", ...
    "rewardProgressWeight", ...
    "rewardSmoothnessWeight", ...
    "rewardDeltaActionWeight", ...
    "rewardSaturationWeight", ...
    "rewardSaturationThreshold", ...
    "unifyActions", ...
    "speeds", ...
    "quantizeCommandsForSimulation", ...
    "actionInterfaceVariant", ...
    "actionCommandActivationThreshold", ...
    "actionCommandLevels", ...
    "actionWarpDeadzone", ...
    "actionWarpOutputLevels", ...
    "rf_modify_actions", ...
    "plotEpisodeOnTest", ...
    "usePrerecorded", ...
    "simMotors", ...
    "connect_glove", ...
    "dataset", ...
    "dataset_folder", ...
    "numEMGFeatures", ...
    "observationVariant", ...
    "emgHistoryLength", ...
    "encodersLimits", ...
    "EMGFeaturesLimits", ...
    "enableDetailedActionDiagnostics", ...
    "savePerMotorMetrics", ...
    "td3Residual", ...
    "agent_id" ...
    ];

override = struct();
for i = 1:numel(overrideFields)
    fieldName = overrideFields(i);
    if isfield(savedConfigs, fieldName)
        override.(fieldName) = savedConfigs.(fieldName);
    end
end
if isfield(override, "td3Residual")
    override.td3Residual = normalizeResidualConfig(override.td3Residual);
end
override.run_training = false;
override.newTraining = false;
override.plotEpisodeOnTest = false;
override.flagSaveTraining = true;
override.episode_save_freq = 1;

checkpointMeta.override = override;
end

function value = getMetaField(metaStruct, fieldName, defaultValue)
if isfield(metaStruct, fieldName)
    value = metaStruct.(fieldName);
else
    value = defaultValue;
end
end

function applyConfigurablesOverride(override)
setConfigurablesOverride(override);
end

function clearConfigurablesOverride()
if isappdata(0, 'configurables_override')
    rmappdata(0, 'configurables_override');
end
if isappdata(0, 'configurables_override_key')
    rmappdata(0, 'configurables_override_key');
end
clear configurables
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end

function td3Residual = normalizeResidualConfig(td3Residual)
if ~isstruct(td3Residual)
    return;
end
if ~isfield(td3Residual, "baseCheckpointPath") || ...
        strlength(string(td3Residual.baseCheckpointPath)) == 0 || ...
        ~isfile(string(td3Residual.baseCheckpointPath))
    td3Residual.baseCheckpointPath = getAgent7250CheckpointPath();
end
end
