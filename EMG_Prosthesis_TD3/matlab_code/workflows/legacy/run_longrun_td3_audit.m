function results = run_longrun_td3_audit(options)
%run_longrun_td3_audit audits a plain TD3 long-run and optionally bridges to residual.

arguments
    options = struct()
end

options = normalizeOptions(options);

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
projectRoot = char(paths.projectRoot);

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

[docsRoot, figuresDir] = resolveDocsDirs(options.docsRoot, projectRoot);

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
    struct("label", "LongRunBaseBest", "kind", "long_run_base", "checkpointPath", bestLongCheckpointPath, "checkpointEpisode", bestLongCheckpointEpisode, "figurePath", string(bestVisualFigurePath))];

candidateResults = cell(numel(candidateDefs), 1);
comparisonRows = cell(numel(candidateDefs), 1);
for i = 1:numel(candidateDefs)
    candidateResults{i} = evaluateCandidate(candidateDefs(i), analysisRoot, benchmark, options);
    comparisonRows{i} = candidateResults{i}.summaryRow;
end

comparisonTable = struct2table(vertcat(comparisonRows{:}));
comparisonTable = sortrows(comparisonTable, "candidateLabel", "ascend");
createCandidateComparisonFigure(comparisonTable, comparisonFigurePath);

promotion = buildPromotionDecision(comparisonTable, benchmark);
bridgeResults = struct( ...
    "executed", false, ...
    "promotedBaseLabel", "", ...
    "baseCheckpointPath", "", ...
    "residualPilot", struct(), ...
    "comparisonTable", table(), ...
    "comparisonFigurePath", "", ...
    "baseVisualFigurePath", "", ...
    "residualVisualFigurePath", "");

if promotion.promoteToWorkBase && logical(options.launchResidualIfPromoted)
    bridgeResults = launchResidualBridge( ...
        bestLongCheckpointPath, bestLongCheckpointEpisode, analysisRoot, figuresDir, benchmark, options);
end

results = struct( ...
    "experimentDir", string(options.experimentDir), ...
    "analysisRoot", string(analysisRoot), ...
    "docsRoot", string(docsRoot), ...
    "benchmark", benchmark, ...
    "trainingAnalysis", trainingAnalysis, ...
    "auditResults", auditResults, ...
    "bestLongCheckpointPath", bestLongCheckpointPath, ...
    "bestLongCheckpointEpisode", bestLongCheckpointEpisode, ...
    "comparisonTable", comparisonTable, ...
    "candidateResults", {candidateResults}, ...
    "promotion", promotion, ...
    "bridgeResults", bridgeResults, ...
    "figurePaths", struct( ...
        "training", string(trainingFigurePath), ...
        "audit", string(auditFigurePath), ...
        "comparison", string(comparisonFigurePath), ...
        "bestVisual", string(bestVisualFigurePath), ...
        "benchmarkVisual", string(benchmarkVisualFigurePath)));

    writetable(comparisonTable, fullfile(analysisRoot, "candidate_comparison.csv"));
    save(fullfile(analysisRoot, "longrun_td3_audit_results.mat"), ...
        "results", "comparisonTable", "promotion", "trainingAnalysis", "auditResults");
    writeTextFile(fullfile(analysisRoot, "longrun_td3_audit_summary.txt"), buildSummaryText(results));

    if logical(options.generateReport)
        reportPaths = generateTutorReport(results, options, docsRoot);
        results.reportPaths = reportPaths;
        save(fullfile(analysisRoot, "longrun_td3_audit_results.mat"), ...
            "results", "comparisonTable", "promotion", "trainingAnalysis", "auditResults");
    end
end

function options = normalizeOptions(options)
defaults = struct( ...
    "experimentDir", inferLatestExperimentDir(), ...
    "docsRoot", "", ...
    "auditFastSimulations", 20, ...
    "auditFullSimulations", 50, ...
    "auditTopK", 5, ...
    "comparisonSimulations", 50, ...
    "comparisonPlotEpisodes", true, ...
    "launchResidualIfPromoted", false, ...
    "residualPilotEpisodes", 2000, ...
    "residualTrainingSaveEvery", 50, ...
    "residualEpisodeSaveFreq", 50, ...
    "residualTrainingPlots", "none", ...
    "residualRandomSeed", NaN, ...
    "generateReport", true, ...
    "compileReport", true, ...
    "dateTag", string(datetime("today", "Format", "yyyyMMdd")));

fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end

options.experimentDir = string(options.experimentDir);
options.docsRoot = string(options.docsRoot);
options.residualTrainingPlots = string(options.residualTrainingPlots);
options.dateTag = string(options.dateTag);

if strlength(options.experimentDir) == 0 || ~isfolder(options.experimentDir)
    error("Long-run TD3 experiment directory not found: %s", options.experimentDir);
end

options.trainingFigureName = "agent7250_longrun_training_progress_" + options.dateTag + ".png";
options.auditFigureName = "agent7250_longrun_checkpoint_evolution_" + options.dateTag + ".png";
options.comparisonFigureName = "agent7250_longrun_candidate_comparison_" + options.dateTag + ".png";
options.bestVisualFigureName = "agent7250_longrun_best_visual_" + options.dateTag + ".png";
options.benchmarkVisualFigureName = "agent7250_longrun_benchmark_visual_" + options.dateTag + ".png";
options.bridgeComparisonFigureName = "agent7250_longrun_promoted_residual_comparison_" + options.dateTag + ".png";
options.bridgeBaseVisualFigureName = "agent7250_longrun_promoted_base_visual_" + options.dateTag + ".png";
options.bridgeResidualVisualFigureName = "agent7250_longrun_promoted_residual_visual_" + options.dateTag + ".png";
options.reportBaseName = "reporte_corrida_larga_base_agent7250_" + options.dateTag;
end

function [docsRoot, figuresDir] = resolveDocsDirs(requestedDocsRoot, projectRoot)
requestedDocsRoot = string(requestedDocsRoot);
if strlength(requestedDocsRoot) > 0
    docsRoot = char(requestedDocsRoot);
else
    docsRoot = fullfile(projectRoot, "docs", "td3_training_report");
end
figuresDir = fullfile(docsRoot, "figures");
if ~exist(docsRoot, "dir")
    mkdir(docsRoot);
end
if ~exist(figuresDir, "dir")
    mkdir(figuresDir);
end
end

function experimentDir = inferLatestExperimentDir()
paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
repoRoot = char(paths.workspaceRoot);
candidateRoots = [ ...
    fullfile(repoRoot, "Agentes", "agent7250_longrun"); ...
    fullfile(repoRoot, "Agentes", "td3_longrun")];

experimentDir = "";
bestDatenum = -inf;
for i = 1:numel(candidateRoots)
    rootDir = candidateRoots(i);
    if ~isfolder(rootDir)
        continue;
    end
    dirInfo = dir(rootDir);
    dirInfo = dirInfo([dirInfo.isdir]);
    dirInfo = dirInfo(~ismember({dirInfo.name}, {'.', '..'}));
    for j = 1:numel(dirInfo)
        runDir = fullfile(dirInfo(j).folder, dirInfo(j).name);
        if isfile(fullfile(runDir, "training_info.mat")) && dirInfo(j).datenum > bestDatenum
            experimentDir = string(runDir);
            bestDatenum = dirInfo(j).datenum;
        end
    end
end
end

function candidateResult = evaluateCandidate(candidate, analysisRoot, benchmark, options)
resultsRoot = fullfile(analysisRoot, "comparative_tests", char(candidate.label));
if ~exist(resultsRoot, "dir")
    mkdir(resultsRoot);
end

runCheckpointTest(candidate.checkpointPath, options.comparisonSimulations, logical(options.comparisonPlotEpisodes), struct( ...
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

function promotion = buildPromotionDecision(comparisonTable, benchmark)
longRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "LongRunBaseBest"), :));
singleRunRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Agent1850"), :));
seed22Row = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Seed22"), :));

longVsBenchmark = classifyBenchmarkAcceptance(struct( ...
    "trackingMseMean", longRow.trackingMseMean, ...
    "saturationFractionMean", longRow.saturationFractionMean, ...
    "actionL2Mean", longRow.actionL2Mean, ...
    "deltaActionL2Mean", longRow.deltaActionL2Mean), benchmark);

promoteToWorkBase = longVsBenchmark.meetsConditionA || longVsBenchmark.meetsConditionB;
beatsAgent1850 = isBetterRun(longRow, singleRunRow);
beatsSeed22 = isBetterRun(longRow, seed22Row);

if promoteToWorkBase
    conclusion = "La corrida larga base produjo una nueva base de trabajo single-run, pero Agent7250 sigue siendo el benchmark oficial.";
else
    conclusion = "Entrenar mas tiempo la base no basto para mejorar de forma final al benchmark; la corrida larga base queda como exploracion temporal.";
end

promotion = struct( ...
    "promoteToWorkBase", logical(promoteToWorkBase), ...
    "benchmarkStatus", string(longVsBenchmark.status), ...
    "beatsAgent1850", logical(beatsAgent1850), ...
    "beatsSeed22", logical(beatsSeed22), ...
    "conclusion", string(conclusion));
end

function bridgeResults = launchResidualBridge(bestLongCheckpointPath, bestLongCheckpointEpisode, analysisRoot, figuresDir, benchmark, options)
bridgeRoot = fullfile(analysisRoot, "promoted_base_residual");
if ~exist(bridgeRoot, "dir")
    mkdir(bridgeRoot);
end

baseLabel = inferCheckpointStem(bestLongCheckpointPath);
residualResults = run_residual_lift_pilot(struct( ...
    "baseCheckpointPath", string(bestLongCheckpointPath), ...
    "baseLabel", string(baseLabel), ...
    "trainingEpisodes", options.residualPilotEpisodes, ...
    "trainingSaveEvery", options.residualTrainingSaveEvery, ...
    "trainingPlots", string(options.residualTrainingPlots), ...
    "episodeSaveFreq", options.residualEpisodeSaveFreq, ...
    "randomSeed", options.residualRandomSeed, ...
    "resultsRoot", fullfile(bridgeRoot, "residual_pilot")));

bestResidualPath = string(residualResults.consolidatedTable.bestCheckpointPath(1));
bestResidualEpisode = double(residualResults.consolidatedTable.bestCheckpointEpisode(1));

baseVisualFigurePath = fullfile(figuresDir, options.bridgeBaseVisualFigureName);
residualVisualFigurePath = fullfile(figuresDir, options.bridgeResidualVisualFigureName);
comparisonFigurePath = fullfile(figuresDir, options.bridgeComparisonFigureName);

candidateDefs = [ ...
    struct("label", "Agent7250", "kind", "benchmark", "checkpointPath", string(getAgent7250CheckpointPath()), "checkpointEpisode", benchmark.checkpointEpisode, "figurePath", ""); ...
    struct("label", "Agent1850", "kind", "single_run", "checkpointPath", string(getResidualFinalCheckpointPath()), "checkpointEpisode", 1850, "figurePath", ""); ...
    struct("label", "Seed22", "kind", "reproducible_seed", "checkpointPath", string(getResidualSeed22CheckpointPath()), "checkpointEpisode", 1850, "figurePath", ""); ...
    struct("label", "PromotedBase", "kind", "promoted_base", "checkpointPath", string(bestLongCheckpointPath), "checkpointEpisode", double(bestLongCheckpointEpisode), "figurePath", string(baseVisualFigurePath)); ...
    struct("label", "PromotedBaseResidual", "kind", "promoted_base_residual", "checkpointPath", bestResidualPath, "checkpointEpisode", bestResidualEpisode, "figurePath", string(residualVisualFigurePath))];

candidateResults = cell(numel(candidateDefs), 1);
comparisonRows = cell(numel(candidateDefs), 1);
for i = 1:numel(candidateDefs)
    candidateResults{i} = evaluateCandidate( ...
        candidateDefs(i), bridgeRoot, benchmark, struct("comparisonSimulations", 50));
    comparisonRows{i} = candidateResults{i}.summaryRow;
end

comparisonTable = struct2table(vertcat(comparisonRows{:}));
comparisonTable = sortrows(comparisonTable, "candidateLabel", "ascend");
createCandidateComparisonFigure(comparisonTable, comparisonFigurePath);
save(fullfile(bridgeRoot, "promoted_base_residual_results.mat"), ...
    "residualResults", "comparisonTable");
    writetable(comparisonTable, fullfile(bridgeRoot, "promoted_base_residual_comparison.csv"));

bridgeResults = struct( ...
    "executed", true, ...
    "promotedBaseLabel", string(baseLabel), ...
    "baseCheckpointPath", string(bestLongCheckpointPath), ...
    "residualPilot", residualResults, ...
    "comparisonTable", comparisonTable, ...
    "comparisonFigurePath", string(comparisonFigurePath), ...
    "baseVisualFigurePath", string(baseVisualFigurePath), ...
    "residualVisualFigurePath", string(residualVisualFigurePath), ...
    "candidateResults", {candidateResults});
end

function reportPaths = generateTutorReport(results, options, docsRoot)
reportBaseName = char(options.reportBaseName);
reportTexPath = fullfile(docsRoot, [reportBaseName '.tex']);
reportPdfPath = fullfile(docsRoot, [reportBaseName '.pdf']);

texContent = buildTutorReportTex(results, options);
writeTextFile(reportTexPath, texContent);

compiled = false;
if logical(options.compileReport)
    compiled = tryCompileLatexReport(docsRoot, reportTexPath);
end

reportPaths = struct( ...
    "tex", string(reportTexPath), ...
    "pdf", string(reportPdfPath), ...
    "compiled", logical(compiled));
end

function texContent = buildTutorReportTex(results, options)
trainingSummary = results.trainingAnalysis.trainingSummary;
bestAuditRow = table2struct(results.auditResults.phaseBTable(1, :));
comparisonTable = results.comparisonTable;
longRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "LongRunBaseBest"), :));
agent1850Row = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Agent1850"), :));
seed22Row = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "Seed22"), :));
benchmark = results.benchmark;
promotion = results.promotion;
bridge = results.bridgeResults;

lines = strings(0, 1);
lines(end+1) = "\documentclass[11pt,a4paper]{article}";
lines(end+1) = "";
lines(end+1) = "\usepackage[utf8]{inputenc}";
lines(end+1) = "\usepackage[T1]{fontenc}";
lines(end+1) = "\usepackage[spanish,es-nodecimaldot]{babel}";
lines(end+1) = "\usepackage{amsmath}";
lines(end+1) = "\usepackage{booktabs}";
lines(end+1) = "\usepackage{tabularx}";
lines(end+1) = "\usepackage{array}";
lines(end+1) = "\usepackage{graphicx}";
lines(end+1) = "\usepackage{geometry}";
lines(end+1) = "\usepackage{xcolor}";
lines(end+1) = "\usepackage{float}";
lines(end+1) = "\usepackage{hyperref}";
lines(end+1) = "\geometry{margin=2.2cm}";
lines(end+1) = "";
lines(end+1) = "\hypersetup{";
lines(end+1) = "    colorlinks=true,";
lines(end+1) = "    linkcolor=blue!50!black,";
lines(end+1) = "    urlcolor=blue!50!black,";
lines(end+1) = "    pdftitle={Reporte de corrida larga base Agent7250},";
lines(end+1) = "    pdfauthor={Cesar Zapata}";
lines(end+1) = "}";
lines(end+1) = "";
lines(end+1) = "\newcolumntype{Y}{>{\raggedright\arraybackslash}X}";
lines(end+1) = "";
lines(end+1) = "\title{Reporte de corrida larga base sobre \texttt{Agent7250}\\\large Proyecto TD3 para prótesis mioeléctrica}";
lines(end+1) = "\author{César Zapata\\Research Laboratory in Artificial Intelligence and Computer Vision ``Alan Turing''}";
lines(end+1) = "\date{" + string(datetime("today", "Format", "dd-MM-yyyy")) + "}";
lines(end+1) = "";
lines(end+1) = "\begin{document}";
lines(end+1) = "\maketitle";
lines(end+1) = "";
lines(end+1) = "\section*{Propósito}";
lines(end+1) = "Este documento registra la fase de corrida larga base realizada sobre \texttt{Agent7250} antes de abrir una nueva intervención residual. La intención fue aislar una duda metodológica central: si parte del beneficio observado en la línea residual provenía de la arquitectura residual en sí o simplemente de seguir entrenando durante mucho más tiempo una política base ya fuerte.";
lines(end+1) = "";
lines(end+1) = "\section*{Configuración}";
lines(end+1) = "La corrida continuó el checkpoint canónico \texttt{Agent7250} como TD3 plano, sin residual, manteniendo la observación \texttt{markov52}, la reward validada y guardado espaciado de checkpoints para poder auditar toda la trayectoria.";
lines(end+1) = "";
lines(end+1) = "\begin{table}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Configuración principal de la corrida larga base}";
lines(end+1) = "\begin{tabularx}{\linewidth}{lY}";
lines(end+1) = "\toprule";
lines(end+1) = "Elemento & Valor \\";
lines(end+1) = "\midrule";
lines(end+1) = "Experimento auditado & \texttt{" + texEscape(char(results.experimentDir)) + "} \\";
lines(end+1) = "Episodios de entrenamiento & " + sprintf("%d", trainingSummary.numEpisodes) + " \\";
lines(end+1) = "Mejor AverageReward & " + sprintf("%.6f en episodio %d", trainingSummary.bestAverageReward, trainingSummary.bestAverageRewardEpisode) + " \\";
lines(end+1) = "AverageReward final & " + sprintf("%.6f", trainingSummary.averageRewardFinal) + " \\";
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabularx}";
lines(end+1) = "\end{table}";
lines(end+1) = "";
lines(end+1) = "\section*{Lectura de la curva}";
lines(end+1) = "La Fig.~\ref{fig:training} muestra la evolución de \texttt{EpisodeReward}, \texttt{AverageReward} y \texttt{EpisodeQ0}. La pregunta aquí no era solo cuál fue el último checkpoint, sino si la política mejoró de forma sostenida al prolongar el entrenamiento.";
lines(end+1) = "";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(options.trainingFigureName)) + "}";
lines(end+1) = "\caption{Curva de entrenamiento de la corrida larga base sobre \texttt{Agent7250}.}";
lines(end+1) = "\label{fig:training}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "En esta ejecución, el mejor \texttt{AverageReward} apareció en el episodio " + sprintf("%d", trainingSummary.bestAverageRewardEpisode) + ", mientras que el valor final cayó a " + sprintf("%.6f", trainingSummary.averageRewardFinal) + ". Esto sugiere que prolongar la base no garantiza mejora monotónica y que puede aparecer deriva tardía.";
lines(end+1) = "";
lines(end+1) = "\section*{Auditoría completa}";
lines(end+1) = "Se auditó la trayectoria completa de checkpoints con una fase rápida de " + sprintf("%d", options.auditFastSimulations) + " simulaciones, una fase completa de " + sprintf("%d", options.auditFullSimulations) + " simulaciones y selección final del top 1 por \texttt{phaseB}.";
lines(end+1) = "";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(options.auditFigureName)) + "}";
lines(end+1) = "\caption{Evolución de métricas por checkpoint en la corrida larga base.}";
lines(end+1) = "\label{fig:audit}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "El mejor checkpoint auditado fue \texttt{" + texEscape(inferCheckpointStem(results.bestLongCheckpointPath)) + "} en el episodio " + sprintf("%d", results.bestLongCheckpointEpisode) + ". En la fase completa obtuvo \texttt{trackingMSE = " + sprintf("%.6f", bestAuditRow.trackingMseMean) + "}, \texttt{actionL2 = " + sprintf("%.6f", bestAuditRow.actionL2Mean) + "} y \texttt{saturationFraction = " + sprintf("%.6f", bestAuditRow.saturationFractionMean) + "}, con estado \texttt{" + texEscape(string(bestAuditRow.benchmarkStatus)) + "}.";
lines(end+1) = "";
lines(end+1) = "\section*{Comparación final}";
lines(end+1) = "Para el veredicto final se repitió una evaluación independiente de 50 simulaciones del mejor checkpoint largo y se comparó contra el benchmark oficial \texttt{Agent7250}, el mejor residual single-run histórico \texttt{Agent1850} y la mejor seed reproducible \texttt{seed 22}.";
lines(end+1) = "";
lines(end+1) = "\begin{figure}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(options.comparisonFigureName)) + "}";
lines(end+1) = "\caption{Comparación final entre benchmark, referencias residuales y mejor checkpoint de la corrida larga base.}";
lines(end+1) = "\label{fig:comparison}";
lines(end+1) = "\end{figure}";
lines(end+1) = "";
lines(end+1) = "\begin{table}[H]";
lines(end+1) = "\centering";
lines(end+1) = "\caption{Métricas finales de los candidatos relevantes}";
lines(end+1) = "\small";
lines(end+1) = "\begin{tabularx}{\linewidth}{l c c c c c >{\raggedright\arraybackslash}p{2.3cm}}";
lines(end+1) = "\toprule";
lines(end+1) = "Candidato & trackingMSE & trackingMAE & actionL2 & saturation & deltaActionL2 & Estado \\";
lines(end+1) = "\midrule";
lines(end+1) = "\texttt{Agent7250} & " + sprintf("%.6f", benchmark.trackingMse) + " & " + sprintf("%.6f", benchmark.trackingMae) + " & " + sprintf("%.6f", benchmark.actionL2) + " & " + sprintf("%.6f", benchmark.saturationFraction) + " & " + sprintf("%.6f", benchmark.deltaActionL2) + " & Referencia \\";
lines(end+1) = "\texttt{Agent1850} & " + sprintf("%.6f", agent1850Row.trackingMseMean) + " & " + sprintf("%.6f", agent1850Row.trackingMaeMean) + " & " + sprintf("%.6f", agent1850Row.actionL2Mean) + " & " + sprintf("%.6f", agent1850Row.saturationFractionMean) + " & " + sprintf("%.6f", agent1850Row.deltaActionL2Mean) + " & " + texEscape(string(agent1850Row.benchmarkStatus)) + " \\";
lines(end+1) = "\texttt{seed 22} & " + sprintf("%.6f", seed22Row.trackingMseMean) + " & " + sprintf("%.6f", seed22Row.trackingMaeMean) + " & " + sprintf("%.6f", seed22Row.actionL2Mean) + " & " + sprintf("%.6f", seed22Row.saturationFractionMean) + " & " + sprintf("%.6f", seed22Row.deltaActionL2Mean) + " & " + texEscape(string(seed22Row.benchmarkStatus)) + " \\";
lines(end+1) = "\texttt{" + texEscape(inferCheckpointStem(results.bestLongCheckpointPath)) + "} & " + sprintf("%.6f", longRow.trackingMseMean) + " & " + sprintf("%.6f", longRow.trackingMaeMean) + " & " + sprintf("%.6f", longRow.actionL2Mean) + " & " + sprintf("%.6f", longRow.saturationFractionMean) + " & " + sprintf("%.6f", longRow.deltaActionL2Mean) + " & " + texEscape(string(longRow.benchmarkStatus)) + " \\";
lines(end+1) = "\bottomrule";
lines(end+1) = "\end{tabularx}";
lines(end+1) = "\end{table}";
lines(end+1) = "";
lines(end+1) = "\section*{Veredicto}";
lines(end+1) = texEscape(promotion.conclusion);
lines(end+1) = "";
if promotion.promoteToWorkBase
    lines(end+1) = "El mejor checkpoint largo sí superó al benchmark bajo la regla de aceptación del proyecto, por lo que queda promovido como \textbf{nueva base de trabajo}. Sin embargo, \texttt{Agent7250} se mantiene como benchmark oficial hasta contar con evidencia más robusta que una sola corrida larga.";
else
    lines(end+1) = "El mejor checkpoint largo no sostuvo una mejora final suficiente contra \texttt{Agent7250}. Eso indica que entrenar más tiempo la base, por sí solo, no bastó para producir un benchmark mejor y refuerza la hipótesis de que la mejora residual no puede explicarse solo por duración de entrenamiento.";
end
lines(end+1) = "";
lines(end+1) = "\section*{Puente hacia residual}";
if bridge.executed
    promotedBaseRow = table2struct(bridge.comparisonTable(strcmp(bridge.comparisonTable.candidateLabel, "PromotedBase"), :));
    promotedResidualRow = table2struct(bridge.comparisonTable(strcmp(bridge.comparisonTable.candidateLabel, "PromotedBaseResidual"), :));
    lines(end+1) = "Como la corrida larga base produjo una nueva base de trabajo, en esta misma fase se abrió también una residual nueva sobre \texttt{" + texEscape(bridge.promotedBaseLabel) + "}.";
    lines(end+1) = "";
    lines(end+1) = "\begin{figure}[H]";
    lines(end+1) = "\centering";
    lines(end+1) = "\includegraphics[width=\linewidth]{figures/" + texEscape(string(options.bridgeComparisonFigureName)) + "}";
    lines(end+1) = "\caption{Comparación entre la base promovida, su residual nueva y las referencias del proyecto.}";
    lines(end+1) = "\end{figure}";
    lines(end+1) = "";
    lines(end+1) = "La base promovida obtuvo \texttt{trackingMSE = " + sprintf("%.6f", promotedBaseRow.trackingMseMean) + "} y la residual nueva obtuvo \texttt{trackingMSE = " + sprintf("%.6f", promotedResidualRow.trackingMseMean) + "}.";
else
    if promotion.promoteToWorkBase
        lines(end+1) = "La base sí quedó promovida como nueva base de trabajo, pero en esta ejecución no se lanzó automáticamente la residual nueva. El siguiente paso operativo recomendado es correr \texttt{run\_longrun\_td3\_audit(..., 'launchResidualIfPromoted', true)} o abrir manualmente \texttt{run\_residual\_lift\_pilot} sobre ese checkpoint.";
    else
        lines(end+1) = "No se abrió una residual nueva después de esta auditoría, porque la corrida larga base no produjo una base suficientemente fuerte como para justificar ese paso.";
    end
end
lines(end+1) = "";
lines(end+1) = "\section*{Estado actual del proyecto}";
if promotion.promoteToWorkBase
    lines(end+1) = "El proyecto queda en un estado intermedio: \texttt{Agent7250} sigue como benchmark oficial, pero el mejor checkpoint de esta corrida larga pasa a ser la nueva base de trabajo recomendada para la próxima residual exploratoria.";
else
    lines(end+1) = "El estado del proyecto no cambia de forma estructural: \texttt{Agent7250} sigue como benchmark oficial, \texttt{seed 22} sigue como mejor residual reproducible y \texttt{Agent1850} sigue como mejor residual single-run histórico en compromiso esfuerzo-saturación.";
end
lines(end+1) = "";
lines(end+1) = "\end{document}";

texContent = strjoin(lines, newline);
end

function ok = tryCompileLatexReport(docsRoot, reportTexPath)
[~, reportName, reportExt] = fileparts(reportTexPath);
reportFile = [reportName reportExt];
[status, ~] = system("pdflatex --version >nul 2>nul");
if status ~= 0
    ok = false;
    return;
end

oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(docsRoot);
system("pdflatex -interaction=nonstopmode """ + reportFile + """ >nul");
status = system("pdflatex -interaction=nonstopmode """ + reportFile + """ >nul");
ok = status == 0;
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

function createAuditEvolutionFigure(phaseATable, benchmark, figurePath)
episodes = double(phaseATable.checkpointEpisode);

f = figure("Visible", "off", "Color", "w", "Position", [100 100 1400 900]);
tiledlayout(f, 2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
plotMetricTrace(episodes, double(phaseATable.trackingMseMean), benchmark.trackingMse, ...
    "trackingMSE", "trackingMSE");

nexttile;
plotMetricTrace(episodes, double(phaseATable.actionL2Mean), benchmark.actionL2, ...
    "actionL2", "actionL2");

nexttile;
plotMetricTrace(episodes, double(phaseATable.saturationFractionMean), benchmark.saturationFraction, ...
    "saturationFraction", "saturationFraction");

nexttile;
plotMetricTrace(episodes, double(phaseATable.deltaActionL2Mean), benchmark.deltaActionL2, ...
    "deltaActionL2", "deltaActionL2");

exportgraphics(f, figurePath, "Resolution", 220);
close(f);
end

function plotMetricTrace(episodes, metricValues, benchmarkValue, titleText, yLabelText)
plot(episodes, metricValues, "-o", "Color", [0.00 0.45 0.74], "LineWidth", 1.8, "MarkerSize", 4);
hold on
yline(benchmarkValue, "--", "Color", [0.85 0.33 0.10], "LineWidth", 1.6);
hold off
grid on
xlabel("Checkpoint episode")
ylabel(yLabelText)
title(titleText)
legend({"corrida larga base", "Agent7250"}, "Location", "best")
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

function checkpointStem = inferCheckpointStem(checkpointPath)
[~, checkpointStem, ~] = fileparts(char(checkpointPath));
checkpointStem = string(checkpointStem);
end

function textValue = buildSummaryText(results)
trainingSummary = results.trainingAnalysis.trainingSummary;
bestAuditRow = table2struct(results.auditResults.phaseBTable(1, :));
comparisonTable = results.comparisonTable;
longRow = table2struct(comparisonTable(strcmp(comparisonTable.candidateLabel, "LongRunBaseBest"), :));

lines = strings(0, 1);
lines(end+1) = "Auditoria de corrida larga base";
lines(end+1) = "==============================";
lines(end+1) = "";
lines(end+1) = sprintf("Experiment dir: %s", results.experimentDir);
lines(end+1) = sprintf("Training episodes: %d", trainingSummary.numEpisodes);
lines(end+1) = sprintf("AverageReward final: %.6f", trainingSummary.averageRewardFinal);
lines(end+1) = sprintf("Best AverageReward: %.6f (episode %d)", ...
    trainingSummary.bestAverageReward, trainingSummary.bestAverageRewardEpisode);
lines(end+1) = sprintf("Best checkpoint by audit: %s", results.bestLongCheckpointPath);
lines(end+1) = sprintf("Best checkpoint episode: %d", results.bestLongCheckpointEpisode);
lines(end+1) = sprintf("Audit trackingMSE: %.6f", bestAuditRow.trackingMseMean);
lines(end+1) = sprintf("Audit actionL2: %.6f", bestAuditRow.actionL2Mean);
lines(end+1) = sprintf("Audit saturationFraction: %.6f", bestAuditRow.saturationFractionMean);
lines(end+1) = sprintf("Audit deltaActionL2: %.6f", bestAuditRow.deltaActionL2Mean);
lines(end+1) = "";
lines(end+1) = sprintf("Final long-run base status: %s", longRow.benchmarkStatus);
lines(end+1) = sprintf("Final long-run base trackingMSE: %.6f", longRow.trackingMseMean);
lines(end+1) = sprintf("Final long-run base actionL2: %.6f", longRow.actionL2Mean);
lines(end+1) = sprintf("Final long-run base saturationFraction: %.6f", longRow.saturationFractionMean);
lines(end+1) = sprintf("Final long-run base deltaActionL2: %.6f", longRow.deltaActionL2Mean);
lines(end+1) = "";
lines(end+1) = sprintf("Promoted to new work base: %d", results.promotion.promoteToWorkBase);
lines(end+1) = sprintf("Residual bridge executed: %d", results.bridgeResults.executed);
lines(end+1) = "";
lines(end+1) = sprintf("Verdict: %s", results.promotion.conclusion);
textValue = strjoin(lines, newline);
end

function tex = texEscape(value)
value = string(value);
tex = replace(value, "\", "\textbackslash{}");
tex = replace(tex, "_", "\_");
tex = replace(tex, "%", "\%");
tex = replace(tex, "&", "\&");
tex = replace(tex, "#", "\#");
tex = replace(tex, "{", "\{");
tex = replace(tex, "}", "\}");
end

function writeTextFile(filePath, textValue)
fid = fopen(filePath, "w");
if fid < 0
    error("Could not open %s for writing.", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", textValue);
end
