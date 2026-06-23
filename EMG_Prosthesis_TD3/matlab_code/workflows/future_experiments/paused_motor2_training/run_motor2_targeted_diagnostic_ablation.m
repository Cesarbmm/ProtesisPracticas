function results = run_motor2_targeted_diagnostic_ablation(options)
%run_motor2_targeted_diagnostic_ablation orchestrates motor-2 diagnostics.

arguments
    options = struct()
end

options = localNormalizeOptions(options);

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
workspaceRoot = char(paths.workspaceRoot);
cd(matlabRoot);
addpath(genpath(matlabRoot));
clearConfigurablesOverride();

resultsRoot = localResolveResultsRoot(options.resultsRoot, workspaceRoot);
summaryRoot = fullfile(resultsRoot, "summary");
figuresRoot = fullfile(resultsRoot, "figures");
ensureDirectoryExists(resultsRoot);
ensureDirectoryExists(summaryRoot);
ensureDirectoryExists(figuresRoot);

gpuInfo = configureGpuForTraining(options.useGpu);

sanityResults = run_motor2_simulation_sanity_check_extended(struct( ...
    "resultsRoot", fullfile(resultsRoot, "sanity_extended")));

mappingAuditPath = fullfile(summaryRoot, "motor2_mapping_audit.txt");
localWriteTextFile(mappingAuditPath, localBuildMappingAuditText(sanityResults));

agent7250Results = localEvaluateCheckpointWithDiagnostics( ...
    "Agent7250", getAgent7250CheckpointPath(), options.finalTestEpisodes, ...
    fullfile(resultsRoot, "agent7250_diagnostic"), figuresRoot, true);

recentResults = localEvaluateRecentCampaignCheckpoints( ...
    options.longCampaignRoot, options.seeds, options.finalTestEpisodes, ...
    fullfile(resultsRoot, "recent_campaign_checkpoints"), figuresRoot);

ablationResults = struct();
if options.runAblation
    ablationResults = run_motor2_reward_ablation(struct( ...
        "mode", options.mode, ...
        "seeds", options.seeds, ...
        "trainingEpisodes", options.trainingEpisodes, ...
        "trainingSaveEvery", options.trainingSaveEvery, ...
        "episodeSaveFreq", options.episodeSaveFreq, ...
        "auditFastSimulations", options.auditFastSimulations, ...
        "auditFullSimulations", options.auditFullSimulations, ...
        "auditTopK", options.auditTopK, ...
        "finalTestEpisodes", options.finalTestEpisodes, ...
        "plotEpisodeOnTest", true, ...
        "useGpu", options.useGpu, ...
        "selectionMode", "motor2_aware", ...
        "resultsRoot", fullfile(resultsRoot, "reward_ablation")));
end

summaryText = localBuildTargetedSummaryText( ...
    options, gpuInfo, sanityResults, agent7250Results, recentResults, ablationResults);
localWriteTextFile(fullfile(summaryRoot, "targeted_diagnostic_summary.txt"), summaryText);

results = struct();
results.resultsRoot = string(resultsRoot);
results.summaryRoot = string(summaryRoot);
results.figuresRoot = string(figuresRoot);
results.options = options;
results.gpuInfo = gpuInfo;
results.sanityResults = sanityResults;
results.mappingAuditPath = string(mappingAuditPath);
results.agent7250Results = agent7250Results;
results.recentResults = recentResults;
results.ablationResults = ablationResults;
results.summaryTextPath = string(fullfile(summaryRoot, "targeted_diagnostic_summary.txt"));

save(fullfile(summaryRoot, "targeted_diagnostic_results.mat"), "results");
end

function options = localNormalizeOptions(options)
paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
defaultCampaignRoot = fullfile(paths.workspaceRoot, "Agentes", ...
    "benchmark_td3_seeded_retrain_motor2_diagnostic", "26-05-27_23-44-39");

defaults = struct( ...
    "mode", "smoke", ...
    "seeds", [11 55], ...
    "trainingEpisodes", 300, ...
    "trainingSaveEvery", 100, ...
    "episodeSaveFreq", 100, ...
    "auditFastSimulations", 2, ...
    "auditFullSimulations", 2, ...
    "auditTopK", 1, ...
    "finalTestEpisodes", 5, ...
    "useGpu", true, ...
    "runAblation", true, ...
    "longCampaignRoot", string(defaultCampaignRoot), ...
    "resultsRoot", "");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.mode = lower(string(options.mode));
options.seeds = double(options.seeds(:))';
options.trainingEpisodes = double(options.trainingEpisodes);
options.trainingSaveEvery = double(options.trainingSaveEvery);
options.episodeSaveFreq = double(options.episodeSaveFreq);
options.auditFastSimulations = max(1, double(options.auditFastSimulations));
options.auditFullSimulations = max(1, double(options.auditFullSimulations));
options.auditTopK = max(1, double(options.auditTopK));
options.finalTestEpisodes = max(1, double(options.finalTestEpisodes));
options.useGpu = logical(options.useGpu);
options.runAblation = logical(options.runAblation);
options.longCampaignRoot = string(options.longCampaignRoot);
options.resultsRoot = string(options.resultsRoot);
end

function result = localEvaluateCheckpointWithDiagnostics(label, checkpointPath, numEpisodes, outputRoot, figuresRoot, plotEpisode)
ensureDirectoryExists(outputRoot);
testRoot = fullfile(outputRoot, "test");
runCheckpointTest(string(checkpointPath), numEpisodes, logical(plotEpisode), struct( ...
    "resultsRoot", string(testRoot)));
testRunDir = localFindNewestSubdir(testRoot);
figurePath = fullfile(figuresRoot, sprintf("%s_motor_diagnostic.png", matlab.lang.makeValidName(char(label))));
[motorDiagnostic, motorTable] = analyzeMotor2Diagnostic(string(testRunDir), string(figurePath));
permutationResults = checkMotorReferencePermutation(string(testRunDir), struct( ...
    "resultsRoot", fullfile(outputRoot, "permutation")));

result = struct( ...
    "label", string(label), ...
    "checkpointPath", string(checkpointPath), ...
    "testRunDir", string(testRunDir), ...
    "motorDiagnostic", motorDiagnostic, ...
    "motorTable", motorTable, ...
    "motorDiagnosticFigurePath", string(figurePath), ...
    "permutationResults", permutationResults);
end

function recentResults = localEvaluateRecentCampaignCheckpoints(campaignRoot, seeds, numEpisodes, outputRoot, figuresRoot)
recentResults = struct("campaignRoot", string(campaignRoot), "rows", table(), "evaluations", {{}});
summaryPath = fullfile(campaignRoot, "summary", "benchmark_seeded_summary.csv");
if strlength(campaignRoot) == 0 || ~isfile(summaryPath)
    return;
end

summaryTable = readtable(summaryPath, "TextType", "string");
summaryTable = summaryTable(ismember(double(summaryTable.seed), double(seeds)), :);
recentResults.rows = summaryTable;
evaluations = cell(height(summaryTable), 1);

for i = 1:height(summaryTable)
    seedLabel = sprintf("seed_%03d", summaryTable.seed(i));
    runDir = string(summaryTable.finalTestRunDir(i));
    if strlength(runDir) == 0 || ~isfolder(runDir)
        checkpointPath = string(summaryTable.selectedCheckpointPath(i));
        evaluations{i} = localEvaluateCheckpointWithDiagnostics( ...
            seedLabel, checkpointPath, numEpisodes, ...
            fullfile(outputRoot, seedLabel), figuresRoot, true);
    else
        figurePath = fullfile(figuresRoot, seedLabel + "_recent_motor_diagnostic.png");
        [motorDiagnostic, motorTable] = analyzeMotor2Diagnostic(runDir, figurePath);
        permutationResults = checkMotorReferencePermutation(runDir, struct( ...
            "resultsRoot", fullfile(outputRoot, seedLabel, "permutation")));
        evaluations{i} = struct( ...
            "label", string(seedLabel), ...
            "checkpointPath", string(summaryTable.selectedCheckpointPath(i)), ...
            "testRunDir", runDir, ...
            "motorDiagnostic", motorDiagnostic, ...
            "motorTable", motorTable, ...
            "motorDiagnosticFigurePath", string(figurePath), ...
            "permutationResults", permutationResults);
    end
end

recentResults.evaluations = evaluations;
end

function textValue = localBuildMappingAuditText(sanityResults)
configs = configurables();
defs = definitions();
lines = strings(0, 1);
lines(end+1) = "Motor 2 mapping audit";
lines(end+1) = "=====================";
lines(end+1) = "";
lines(end+1) = "Scope: software/simulation only; no hardware ports are touched.";
lines(end+1) = "";
lines(end+1) = "Current scales and mappings:";
lines(end+1) = "encoder2state_scale denominators in configurables.m: [26500 11500 8500 9000]";
lines(end+1) = "flexJoined_scale denominators in configurables.m: [4092 2046 1023 2046]";
lines(end+1) = sprintf("actionCommandLevels: %s", mat2str(configs.actionCommandLevels));
lines(end+1) = sprintf("fingers order from definitions(): %s", strjoin(string(defs.fingers), ", "));
lines(end+1) = sprintf("motorIdx.little=%d, motorIdx.idx=%d, motorIdx.thumb=%d, motorIdx.mid=%d", ...
    defs.motorIdx.little, defs.motorIdx.idx, defs.motorIdx.thumb, defs.motorIdx.mid);
lines(end+1) = "Action order: remapActionForActuator maps action(i) directly to appliedPwm(i).";
lines(end+1) = "Encoder order: SimController.prosthesis_simulator updates trajectory(:, i) for motor i.";
lines(end+1) = "Flex/reference order: reduceFlexDimension and encoder2Flex both iterate definitions().fingers.";
lines(end+1) = "";
lines(end+1) = "Initial suspicion:";
lines(end+1) = "- No column swap should be applied without evidence from permutation diagnostics.";
lines(end+1) = "- If motor 2 shows lower gain or asymmetric sign in extended sanity, inspect scale/model before changing reward.";
lines(end+1) = "- If permutation matrix shows glove reference 2 aligns better with response j!=2, document cross-column evidence before patching.";
lines(end+1) = "";
if isfield(sanityResults, "gainCsvPath")
    lines(end+1) = sprintf("Extended sanity CSV: %s", string(sanityResults.gainCsvPath));
    lines(end+1) = sprintf("Extended sanity sign CSV: %s", string(sanityResults.signCsvPath));
    lines(end+1) = sprintf("Extended sanity figure: %s", string(sanityResults.figurePath));
end
textValue = strjoin(lines, newline);
end

function textValue = localBuildTargetedSummaryText(options, gpuInfo, sanityResults, agent7250Results, recentResults, ablationResults)
lines = strings(0, 1);
lines(end+1) = "Motor 2 targeted diagnostic and ablation";
lines(end+1) = "========================================";
lines(end+1) = "";
lines(end+1) = sprintf("Mode: %s", string(options.mode));
lines(end+1) = sprintf("Seeds: %s", mat2str(options.seeds));
lines(end+1) = sprintf("Training episodes for ablation: %d", options.trainingEpisodes);
lines(end+1) = sprintf("Final test episodes: %d", options.finalTestEpisodes);
lines(end+1) = sprintf("GPU enabled: %d | %s", gpuInfo.gpuEnabled, string(gpuInfo.gpuName));
lines(end+1) = "";
lines(end+1) = sprintf("Extended sanity figure: %s", string(sanityResults.figurePath));
lines(end+1) = sprintf("Agent7250 motor2 MSE: %.6f", agent7250Results.motorDiagnostic.trackingMSE_motor2);
lines(end+1) = sprintf("Agent7250 motor2 response range: %.6f", agent7250Results.motorDiagnostic.responseRange_motor2);
lines(end+1) = "";
if isfield(recentResults, "evaluations") && ~isempty(recentResults.evaluations)
    lines(end+1) = "Recent campaign checkpoint diagnostics:";
    for i = 1:numel(recentResults.evaluations)
        item = recentResults.evaluations{i};
        if isempty(item)
            continue;
        end
        lines(end+1) = sprintf("%s | motor2MSE %.6f | motor2Range %.6f | flat %d | actionNoMotion %d", ...
            string(item.label), item.motorDiagnostic.trackingMSE_motor2, ...
            item.motorDiagnostic.responseRange_motor2, item.motorDiagnostic.motor2_flat_response, ...
            item.motorDiagnostic.motor2_action_no_motion); %#ok<AGROW>
    end
    lines(end+1) = "";
end
if isfield(ablationResults, "ablationSummary")
    lines(end+1) = "Ablation summary:";
    for i = 1:height(ablationResults.ablationSummary)
        row = ablationResults.ablationSummary(i, :);
        lines(end+1) = sprintf("%s | motor2MSE %.6f | motor2Range %.6f | accepted %d", ...
            string(row.configLabel), row.trackingMSE_motor2, ...
            row.responseRange_motor2, row.acceptedShortCampaign); %#ok<AGROW>
    end
end
textValue = strjoin(lines, newline);
end

function newestDir = localFindNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No subdirectories found in %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
newestDir = string(fullfile(dirInfo(idx).folder, dirInfo(idx).name));
end

function resultsRoot = localResolveResultsRoot(requestedRoot, workspaceRoot)
requestedRoot = string(requestedRoot);
if strlength(requestedRoot) > 0
    baseRoot = char(requestedRoot);
else
    baseRoot = fullfile(workspaceRoot, "Agentes", ...
        "motor2_targeted_diagnostic_ablation", ...
        string(datetime("now", "Format", "yy-MM-dd_HH-mm-ss")));
end
resultsRoot = localMakeUniqueDirectoryPath(baseRoot);
end

function uniquePath = localMakeUniqueDirectoryPath(basePath)
basePath = char(string(basePath));
if ~exist(basePath, "dir")
    uniquePath = basePath;
    return;
end
for i = 1:999
    candidatePath = sprintf("%s_%02d", basePath, i);
    if ~exist(candidatePath, "dir")
        uniquePath = candidatePath;
        return;
    end
end
error("Could not create a unique results directory for %s", basePath);
end

function localWriteTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textValue);
end
