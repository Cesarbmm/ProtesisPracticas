function results = run_longrun_residual_audit(options)
%run_longrun_residual_audit audits a long Residual Lift experiment end-to-end.

arguments
    options = struct()
end

options = normalizeOptions(options);

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
projectRoot = char(paths.projectRoot);
workspaceRoot = char(paths.workspaceRoot);

cd(matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

benchmark = getAgent7250Benchmark();
analysisRoot = fullfile(char(options.experimentDir), "analysis");
if ~exist(analysisRoot, "dir")
    mkdir(analysisRoot);
end
figuresDir = fullfile(projectRoot, "docs", "td3_training_report", "figures");
if ~exist(figuresDir, "dir")
    mkdir(figuresDir);
end

trainingFigurePath = fullfile(figuresDir, options.trainingFigureName);
auditFigurePath = fullfile(figuresDir, options.auditFigureName);
comparisonFigurePath = fullfile(figuresDir, options.comparisonFigureName);
bestVisualFigurePath = fullfile(figuresDir, options.bestVisualFigureName);
benchmarkVisualFigurePath = fullfile(figuresDir, options.benchmarkVisualFigureName);

trainingAnalysis = analyzeExperimentRun(string(options.experimentDir), string(trainingFigurePath));

auditResultsRoot = fullfile(analysisRoot, "checkpoint_audit");
auditResultsMatPath = fullfile(auditResultsRoot, "checkpoint_audit_results.mat");
if isfile(auditResultsMatPath)
    auditData = load(auditResultsMatPath, "results");
    auditResults = auditData.results;
else
    auditResults = runCheckpointAudit( ...
        options.auditFastSimulations, ...
        options.auditFullSimulations, ...
        options.auditTopK, ...
        struct( ...
            "experimentDir", string(options.experimentDir), ...
            "samplingPolicy", struct("mode", "all"), ...
            "resultsRoot", auditResultsRoot, ...
            "verbose", false));
end

createAuditEvolutionFigure(auditResults.phaseATable, benchmark, auditFigurePath);

bestLongCheckpointPath = string(auditResults.phaseBTable.checkpointPath(1));
bestLongCheckpointEpisode = double(auditResults.phaseBTable.checkpointEpisode(1));

candidateDefs = [ ...
    struct("label", "Agent7250", "kind", "benchmark", "checkpointPath", string(getAgent7250CheckpointPath()), "checkpointEpisode", benchmark.checkpointEpisode, "figurePath", string(benchmarkVisualFigurePath)); ...
    struct("label", "Agent1850", "kind", "single_run", "checkpointPath", string(getResidualFinalCheckpointPath()), "checkpointEpisode", 1850, "figurePath", ""); ...
    struct("label", "Seed22", "kind", "reproducible_seed", "checkpointPath", string(getResidualSeed22CheckpointPath()), "checkpointEpisode", 1850, "figurePath", ""); ...
    struct("label", "LongRunBest", "kind", "long_run", "checkpointPath", bestLongCheckpointPath, "checkpointEpisode", bestLongCheckpointEpisode, "figurePath", string(bestVisualFigurePath))];

comparisonRows = cell(numel(candidateDefs), 1);
candidateResults = cell(numel(candidateDefs), 1);

for i = 1:numel(candidateDefs)
    candidate = candidateDefs(i);
    candidateResults{i} = evaluateCandidate( ...
        candidate, analysisRoot, benchmark, options, workspaceRoot);
    comparisonRows{i} = candidateResults{i}.summaryRow;
end

comparisonTable = struct2table(vertcat(comparisonRows{:}));
comparisonTable = sortrows(comparisonTable, "candidateLabel", "ascend");
createCandidateComparisonFigure(comparisonTable, comparisonFigurePath);

verdict = buildLongrunVerdict(comparisonTable, benchmark);

results = struct( ...
    "experimentDir", string(options.experimentDir), ...
    "analysisRoot", string(analysisRoot), ...
    "benchmark", benchmark, ...
    "trainingAnalysis", trainingAnalysis, ...
    "auditResults", auditResults, ...
    "bestLongCheckpointPath", bestLongCheckpointPath, ...
    "bestLongCheckpointEpisode", bestLongCheckpointEpisode, ...
    "comparisonTable", comparisonTable, ...
    "candidateResults", {candidateResults}, ...
    "verdict", verdict, ...
    "figurePaths", struct( ...
        "training", string(trainingFigurePath), ...
        "audit", string(auditFigurePath), ...
        "comparison", string(comparisonFigurePath), ...
        "bestVisual", string(bestVisualFigurePath), ...
        "benchmarkVisual", string(benchmarkVisualFigurePath)));

    writetable(comparisonTable, fullfile(analysisRoot, "candidate_comparison.csv"));
save(fullfile(analysisRoot, "longrun_residual_audit_results.mat"), "results", "comparisonTable", "verdict", "trainingAnalysis", "auditResults");
writeTextFile(fullfile(analysisRoot, "longrun_residual_audit_summary.txt"), buildSummaryText(results));
end

function options = normalizeOptions(options)
defaults = struct( ...
    "experimentDir", "C:/Users/pc/Desktop/PROTESIS_PRACTICAS/Agentes/agente_corrida_larga26-04-01 19 14 56", ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 5, ...
    "comparisonSimulations", 50, ...
    "trainingFigureName", "longrun_residual_training_progress_20260402.png", ...
    "auditFigureName", "longrun_residual_checkpoint_evolution_20260402.png", ...
    "comparisonFigureName", "longrun_residual_candidate_comparison_20260402.png", ...
    "bestVisualFigureName", "longrun_residual_best_visual_20260402.png", ...
    "benchmarkVisualFigureName", "longrun_residual_benchmark_visual_20260402.png");

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.experimentDir = string(options.experimentDir);
end

function candidateResult = evaluateCandidate(candidate, analysisRoot, benchmark, options, workspaceRoot)
resultsRoot = fullfile(analysisRoot, "comparative_tests", char(candidate.label));
if ~exist(resultsRoot, "dir")
    mkdir(resultsRoot);
end

runCheckpointTest(candidate.checkpointPath, options.comparisonSimulations, true, struct( ...
    "resultsRoot", resultsRoot));
runDir = findNewestSubdir(resultsRoot);
analysis = analyzeExperimentRun(string(runDir));
decision = classifyBenchmarkAcceptance(analysis.episodeSummary, benchmark);

copiedFigurePath = "";
if strlength(string(candidate.figurePath)) > 0
    copiedFigurePath = createRepresentativeEpisodeFigure(string(runDir), string(candidate.figurePath));
end

summaryRow = struct( ...
    "candidateLabel", string(candidate.label), ...
    "candidateKind", string(candidate.kind), ...
    "checkpointPath", string(candidate.checkpointPath), ...
    "checkpointEpisode", double(candidate.checkpointEpisode), ...
    "runDir", string(runDir), ...
    "trackingMseMean", double(analysis.episodeSummary.trackingMseMean), ...
    "trackingMaeMean", double(analysis.episodeSummary.trackingMaeMean), ...
    "actionL2Mean", double(analysis.episodeSummary.actionL2Mean), ...
    "saturationFractionMean", double(analysis.episodeSummary.saturationFractionMean), ...
    "deltaActionL2Mean", double(analysis.episodeSummary.deltaActionL2Mean), ...
    "benchmarkStatus", string(decision.status), ...
    "meetsConditionA", logical(decision.meetsConditionA), ...
    "meetsConditionB", logical(decision.meetsConditionB), ...
    "trackingMsePctVsBenchmark", double(decision.trackingMsePctVsBenchmark), ...
    "saturationFractionPctVsBenchmark", double(decision.saturationFractionPctVsBenchmark), ...
    "actionL2PctVsBenchmark", double(decision.actionL2PctVsBenchmark), ...
    "deltaActionL2PctVsBenchmark", double(decision.deltaActionL2PctVsBenchmark), ...
    "representativeFigurePath", string(copiedFigurePath));

candidateResult = struct( ...
    "candidate", candidate, ...
    "runDir", string(runDir), ...
    "analysis", analysis, ...
    "decision", decision, ...
    "summaryRow", summaryRow);
end

function figurePath = createRepresentativeEpisodeFigure(runDir, targetPath)
figurePath = "";
preferredEpisodeFiles = ["episode00049.mat", "episode00050.mat"];
episodeFile = "";

for i = 1:numel(preferredEpisodeFiles)
    candidatePath = fullfile(runDir, preferredEpisodeFiles(i));
    if isfile(candidatePath)
        episodeFile = candidatePath;
        break;
    end
end

if strlength(episodeFile) == 0
    episodeFiles = dir(fullfile(runDir, "episode*.mat"));
    if isempty(episodeFiles)
        return;
    end
    [~, idx] = max([episodeFiles.datenum]);
    episodeFile = fullfile(episodeFiles(idx).folder, episodeFiles(idx).name);
end

data = load(episodeFile);
if ~isfield(data, "encoderAdjustedLog") || ~isfield(data, "flexConvertedLog")
    return;
end

prosthesisPosition = cat(1, data.encoderAdjustedLog{:});
glovePosition = cat(1, data.flexConvertedLog{:});
actions = [];
if isfield(data, "effectiveActionLog")
    actions = data.effectiveActionLog;
elseif isfield(data, "actionSatLog")
    actions = data.actionSatLog;
elseif isfield(data, "actionLog")
    actions = data.actionLog;
end

nGlove = size(glovePosition, 1);
nProsthesis = size(prosthesisPosition, 1);
if nProsthesis ~= nGlove
    xProsthesis = linspace(1, nGlove, nProsthesis);
    xGlove = 1:nGlove;
    prosthesisInterp = interp1(xProsthesis, prosthesisPosition, xGlove);
else
    prosthesisInterp = prosthesisPosition;
end

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1300 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");
motorNames = ["Pulgar", "Indice", "Medio", "Pulgar rotacion"];

for i = 1:4
    nexttile;
    plot(prosthesisInterp(:, i), "-", "LineWidth", 2.0, "Color", [0.00 0.45 0.74]);
    hold on
    plot(glovePosition(:, i), "--", "LineWidth", 2.0, "Color", [0.85 0.33 0.10]);
    if ~isempty(actions)
        actionIdx = linspace(1, size(glovePosition, 1), size(actions, 1));
        scatter(actionIdx, prosthesisInterp(round(actionIdx), i), 24, actions(:, i), "filled");
        colormap(gca, parula);
    end
    hold off
    grid on
    title(string(motorNames(i)))
    xlabel("Paso")
    ylabel("Posicion normalizada")
end

exportgraphics(f, targetPath, "Resolution", 220);
close(f);
figurePath = targetPath;
end

function newestDir = findNewestSubdir(parentDir)
dirInfo = dir(parentDir);
dirInfo = dirInfo([dirInfo.isdir]);
dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
if isempty(dirInfo)
    error("No subdirectories found in %s", parentDir);
end
[~, idx] = max([dirInfo.datenum]);
newestDir = fullfile(dirInfo(idx).folder, dirInfo(idx).name);
end

function createAuditEvolutionFigure(phaseATable, benchmark, figurePath)
episodes = double(phaseATable.checkpointEpisode);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plotMetricTrace(episodes, double(phaseATable.trackingMseMean), benchmark.trackingMse, ...
    "trackingMSE", "trackingMSE", false);

nexttile;
plotMetricTrace(episodes, double(phaseATable.actionL2Mean), benchmark.actionL2, ...
    "actionL2", "actionL2", false);

nexttile;
plotMetricTrace(episodes, double(phaseATable.saturationFractionMean), benchmark.saturationFraction, ...
    "saturationFraction", "saturationFraction", false);

nexttile;
plotMetricTrace(episodes, double(phaseATable.deltaActionL2Mean), benchmark.deltaActionL2, ...
    "deltaActionL2", "deltaActionL2", false);

exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function plotMetricTrace(episodes, metricValues, benchmarkValue, titleText, yLabelText, useLogScale)
plot(episodes, metricValues, "-o", "Color", [0.00 0.45 0.74], "LineWidth", 1.8, "MarkerSize", 4);
hold on
yline(benchmarkValue, "--", "Color", [0.85 0.33 0.10], "LineWidth", 1.6);
hold off
grid on
xlabel("Checkpoint episode")
ylabel(yLabelText)
title(titleText)
legend({"corrida larga", "Agent7250"}, "Location", "best")
if useLogScale
    set(gca, "YScale", "log");
end
end

function createCandidateComparisonFigure(comparisonTable, figurePath)
labels = string(comparisonTable.candidateLabel);
metrics = { ...
    "trackingMseMean", "trackingMSE"; ...
    "actionL2Mean", "actionL2"; ...
    "saturationFractionMean", "saturationFraction"; ...
    "deltaActionL2Mean", "deltaActionL2"};

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

for i = 1:size(metrics, 1)
    nexttile;
    values = double(comparisonTable.(metrics{i, 1}));
    b = bar(categorical(labels), values, 0.6, "FaceColor", [0.12 0.47 0.71]);
    b.FaceAlpha = 0.85;
    ylabel(metrics{i, 2});
    title(metrics{i, 2});
    grid on
end

exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function verdict = buildLongrunVerdict(comparisonTable, benchmark)
longRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "LongRunBest"), :));
singleRunRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Agent1850"), :));
seed22Row = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Seed22"), :));

longBeatsSingleRun = isBetterRun(longRow, singleRunRow);
longBeatsSeed22 = isBetterRun(longRow, seed22Row);
longVsBenchmark = classifyBenchmarkAcceptance(struct( ...
    "trackingMseMean", longRow.trackingMseMean, ...
    "saturationFractionMean", longRow.saturationFractionMean, ...
    "actionL2Mean", longRow.actionL2Mean, ...
    "deltaActionL2Mean", longRow.deltaActionL2Mean), benchmark);

if longVsBenchmark.meetsConditionA || longVsBenchmark.meetsConditionB
    conclusion = "La corrida larga produjo un mejor candidato single-run, pero Agent7250 sigue siendo el benchmark oficial.";
elseif longBeatsSingleRun && longBeatsSeed22
    conclusion = "La corrida larga produjo un nuevo mejor residual single-run por continuacion larga, pero sin reemplazar el benchmark oficial.";
else
    conclusion = "Agent7250 sigue siendo el benchmark estable y la corrida larga queda como exploracion temporal.";
end

verdict = struct( ...
    "longBeatsSingleRun", logical(longBeatsSingleRun), ...
    "longBeatsSeed22", logical(longBeatsSeed22), ...
    "longBenchmarkStatus", string(longVsBenchmark.status), ...
    "conclusion", string(conclusion));
end

function tf = isBetterRun(candidateRow, referenceRow)
candidateRank = mapStatusToRank(candidateRow.benchmarkStatus);
referenceRank = mapStatusToRank(referenceRow.benchmarkStatus);

if candidateRank ~= referenceRank
    tf = candidateRank > referenceRank;
    return;
end
if candidateRow.trackingMseMean ~= referenceRow.trackingMseMean
    tf = candidateRow.trackingMseMean < referenceRow.trackingMseMean;
    return;
end
if candidateRow.saturationFractionMean ~= referenceRow.saturationFractionMean
    tf = candidateRow.saturationFractionMean < referenceRow.saturationFractionMean;
    return;
end
if candidateRow.deltaActionL2Mean ~= referenceRow.deltaActionL2Mean
    tf = candidateRow.deltaActionL2Mean < referenceRow.deltaActionL2Mean;
    return;
end
tf = candidateRow.actionL2Mean < referenceRow.actionL2Mean;
end

function rank = mapStatusToRank(status)
switch string(status)
    case "ConditionA"
        rank = 2;
    case "ConditionB"
        rank = 1;
    otherwise
        rank = 0;
end
end

function summaryText = buildSummaryText(results)
trainingSummary = results.trainingAnalysis.trainingSummary;
bestAuditRow = table2struct(results.auditResults.phaseBTable(1, :));
comparisonTable = results.comparisonTable;
longRow = comparisonTable(strcmp(comparisonTable.candidateLabel, "LongRunBest"), :);
longRow = table2struct(longRow);

lines = strings(0, 1);
lines(end+1) = "Auditoria de corrida larga residual";
lines(end+1) = "=================================";
lines(end+1) = "";
lines(end+1) = sprintf("Experiment dir: %s", results.experimentDir);
lines(end+1) = sprintf("Training episodes: %d", trainingSummary.numEpisodes);
lines(end+1) = sprintf("AverageReward final: %.6f", trainingSummary.averageRewardFinal);
lines(end+1) = sprintf("Best AverageReward: %.6f (episode %d)", ...
    trainingSummary.bestAverageReward, trainingSummary.bestAverageRewardEpisode);
lines(end+1) = sprintf("Best checkpoint by audit: %s", string(results.bestLongCheckpointPath));
lines(end+1) = sprintf("Best checkpoint episode: %d", results.bestLongCheckpointEpisode);
lines(end+1) = sprintf("Audit trackingMSE: %.6f", double(bestAuditRow.trackingMseMean));
lines(end+1) = sprintf("Audit actionL2: %.6f", double(bestAuditRow.actionL2Mean));
lines(end+1) = sprintf("Audit saturationFraction: %.6f", double(bestAuditRow.saturationFractionMean));
lines(end+1) = sprintf("Audit deltaActionL2: %.6f", double(bestAuditRow.deltaActionL2Mean));
lines(end+1) = "";
lines(end+1) = sprintf("Long-run final test status: %s", string(longRow.benchmarkStatus));
lines(end+1) = sprintf("Long-run final test trackingMSE: %.6f", longRow.trackingMseMean);
lines(end+1) = sprintf("Long-run final test actionL2: %.6f", longRow.actionL2Mean);
lines(end+1) = sprintf("Long-run final test saturationFraction: %.6f", longRow.saturationFractionMean);
lines(end+1) = sprintf("Long-run final test deltaActionL2: %.6f", longRow.deltaActionL2Mean);
lines(end+1) = "";
lines(end+1) = sprintf("Verdict: %s", string(results.verdict.conclusion));

summaryText = strjoin(lines, newline);
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", textValue);
end
