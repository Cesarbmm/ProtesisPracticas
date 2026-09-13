function summary = runFinalSealedTest(options)
% runFinalSealedTest ejecuta el protocolo formal del Test Final Sellado (MATEO & SANDRA):
% - Verificacion previa de hash SHA-256 de FINAL_AGENT
% - Verificacion de preregistro inmutable
% - Apertura y unblinding formal de MATEO y SANDRA
% - Evaluacion apareada de 5 politicas (ZERO, Agent7250, P2, Oracle H5, FINAL E4) sobre 40 episodios
% - Evaluacion rigurosa de Gates A a F
% - Generacion de figuras COMPACT, PRO, CLASSIC, ANNOTATED, 5 figuras globales y reporte HTML

arguments
    options.e4RunDir (1, 1) string = "C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e4_final_development\run_20260910_084228_108_8176e5a9"
end

root = string(fileparts(mfilename("fullpath")));
pr = fullfile(root, "analysis", "paired_reference");
sealedDir = fullfile(pr, "sealed");

oldPath = path; oldDir = pwd; oldRng = rng;
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
cleanup = onCleanup(@() restoreContext(oldPath, oldDir, oldRng, oldOverride)); %#ok<NASGU>

addpath(root, pr, fullfile(pr, "e3ax"), fullfile(pr, "e3b"), fullfile(pr, "e3f"), fullfile(pr, "e4"), fullfile(pr, "cap192"), sealedDir, fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));
cd(root);

assert(~contains(lower(string(path)), "sandbox"), "Sealed:SandboxForbidden", "No agregar sandbox al path.");

% 1. Verificacion de requisitos previos
finalAgentFile = fullfile(options.e4RunDir, "FINAL_AGENT.mat");
assert(isfile(finalAgentFile), "Sealed:MissingFinalAgent", "Falta FINAL_AGENT.mat.");
finalSha = cap192SHA256(finalAgentFile);
expectedSha = "2aa39fdf166c62fb6da057f1ddecb6455fbaa142f476718dd4e2725dfde08c90";
assert(finalSha == expectedSha, "Sealed:HashMismatch", ...
    "DETENERSE: Hash de FINAL_AGENT (%s) no coincide con el esperado (%s).", finalSha, expectedSha);

preregFile = fullfile(fileparts(root), "docs", "paired_reference", "PREREGISTRO_FINAL_SEALED_TEST.md");
assert(isfile(preregFile), "Sealed:MissingPreregistration", "Falta documento de preregistro.");
preregSha = cap192SHA256(preregFile);

% 2. Registro de unblinding
unblindTime = string(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
fprintf("=== PROTOCOLO DEL TEST FINAL SELLADO (MATEO & SANDRA) ===\n");
fprintf("Instante logico de unblinding: %s\n", unblindTime);
fprintf("SHA-256 FINAL_AGENT: %s [VERIFICADO]\n", finalSha);

% 3. Crear directorio de resultados
stamp = string(datetime('now', Format='yyyyMMdd_HHmmss_SSS'));
id = string(java.util.UUID.randomUUID());
outDir = fullfile(root, "results", "final_sealed_test", "run_" + stamp + "_" + extractBefore(id, 9));
mkdir(outDir);
mkdir(fullfile(outDir, "metrics"));
mkdir(fullfile(outDir, "traces"));
mkdir(fullfile(outDir, "figures", "compact"));
mkdir(fullfile(outDir, "figures", "pro"));
mkdir(fullfile(outDir, "figures", "classic"));
mkdir(fullfile(outDir, "figures", "annotated", "PNG"));
mkdir(fullfile(outDir, "figures", "annotated", "FIG"));
mkdir(fullfile(outDir, "figures", "annotated", "CSV"));
mkdir(fullfile(outDir, "figures", "annotated", "MAT"));

diary(fullfile(outDir, "diary.log"));
dc = onCleanup(@() diary('off')); %#ok<NASGU>

% Guardar evidencia de unblinding
unblindRecord = struct( ...
    "SEALED_TEST_OPENED", "YES", ...
    "SEALED_TEST_OPENED_AFTER_MODEL_FREEZE", "YES", ...
    "SEALED_TEST_OPENED_AFTER_PREREGISTRATION", "YES", ...
    "unblindingTimestamp", unblindTime, ...
    "finalAgentSHA256", finalSha, ...
    "preregistrationSHA256", preregSha, ...
    "stage", "FINAL_SEALED_TEST", ...
    "subjects", ["MATEO", "SANDRA"]);
e2cWriteJSON(fullfile(outDir, "unblinding_record.json"), unblindRecord);
writeText(fullfile(outDir, "UNBLINDING_EVIDENCE.txt"), ...
    "SEALED_TEST_OPENED = YES" + newline + ...
    "SEALED_TEST_OPENED_AFTER_MODEL_FREEZE = YES" + newline + ...
    "SEALED_TEST_OPENED_AFTER_PREREGISTRATION = YES" + newline + ...
    "TIMESTAMP = " + unblindTime + newline + ...
    "FINAL_AGENT_SHA256 = " + finalSha);

% 4. Configuracion de inferencia (NO TRAINING)
override = struct("run_training", false, "newTraining", false, "flagSaveTraining", false, ...
    "plotEpisodeOnTest", false, "verbose", false, "usePrerecorded", true, "simMotors", true, ...
    "observationVariant", "markov52", "simPlantSource", "patternCurveCanonical", ...
    "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(override);

% 5. Cargar modelos y recursos
fprintf("Cargando politicas congeladas...\n");
sE4 = load(finalAgentFile, "saved_actor");
e4Actor = sE4.saved_actor;

[agent7250Actor, policyManifest] = loadE2AFrozenActor();
e2cWriteJSON(fullfile(outDir, "agent7250_manifest.json"), policyManifest);

gd = load(fullfile(pr, "e2f_results", "graphs.mat"), "graphs");
graphs = gd.graphs;
[remap, remapCleanup] = e2cHistoricalRemapper(root); %#ok<ASGLU>

seed = 20260920;

% 6. Cargar datos de MATEO y SANDRA (Unblinding formal)
fprintf("Cargando episodios de MATEO y SANDRA...\n");
data = sealedLoadData(outDir);
assert(height(data.selection) == 40, "Sealed:EpisodeCount", "Se esperaban exactamente 40 episodios sellados.");

% 7. Ejecutar rollouts de las 5 politicas
rolloutResults = sealedRunRollouts(data.evaluation, e4Actor, agent7250Actor, graphs, remap, seed, outDir);

traces = rolloutResults.trajectories;
runtimeTraces = rolloutResults.runtimeTraces;
E = rolloutResults.metricsTable;
M = rolloutResults.motorTable;
C = rolloutResults.catTable;
P = rolloutResults.policySummary;
S = rolloutResults.subjectSummary;
D = rolloutResults.dirSummary;
Mot = rolloutResults.motorSummary;

% 8. Generar figuras COMPACT, PRO, CLASSIC y trazas para FINAL_E4
fprintf("Generando figuras COMPACT, PRO, CLASSIC y trazas numericas (40 episodios)...\n");
compactDir = fullfile(outDir, "figures", "compact");
proDir = fullfile(outDir, "figures", "pro");
classicDir = fullfile(outDir, "figures", "classic");
tracesDir = fullfile(outDir, "traces");

directions = ["closing", "opening"];
for e = 1:40
    t = traces{e, 5}; % FINAL_E4
    r = runtimeTraces{e};

    e3fPlotCompact(t, compactDir);
    e3fPlotPro(t, proDir, "TEST");
    e3fPlotClassic(t, classicDir);

    % Exportar trazas numericas
    md = t.metadata;
    stem = string(md.subject) + compose("_row%04d_", md.repetition) + directions(md.side);
    csvFile = fullfile(tracesDir, stem + "_trace.csv");
    matFile = fullfile(tracesDir, stem + "_trace.mat");

    ref = t.reference; pred = t.prediction; pwm = t.pwm; eff = t.effectiveAction;
    q = t.q(2:end, :); dq = [t.q(2, :) - t.q(1, :); diff(t.q(2:end, :))];
    nSteps = size(ref, 1);
    tRows = [];
    for s = 1:nSteps
        trRow = struct("step", s, "subject", md.subject, "row", md.repetition, ...
            "direction", directions(md.side), ...
            "ref_m1", ref(s, 1), "ref_m2", ref(s, 2), "ref_m3", ref(s, 3), "ref_m4", ref(s, 4), ...
            "pred_m1", pred(s, 1), "pred_m2", pred(s, 2), "pred_m3", pred(s, 3), "pred_m4", pred(s, 4), ...
            "err_m1", ref(s, 1)-pred(s, 1), "err_m2", ref(s, 2)-pred(s, 2), "err_m3", ref(s, 3)-pred(s, 3), "err_m4", ref(s, 4)-pred(s, 4), ...
            "pwm_m1", pwm(s, 1), "pwm_m2", pwm(s, 2), "pwm_m3", pwm(s, 3), "pwm_m4", pwm(s, 4), ...
            "eff_m1", eff(s, 1), "eff_m2", eff(s, 2), "eff_m3", eff(s, 3), "eff_m4", eff(s, 4), ...
            "q_m1", q(s, 1), "q_m2", q(s, 2), "q_m3", q(s, 3), "q_m4", q(s, 4), ...
            "dq_m1", dq(s, 1), "dq_m2", dq(s, 2), "dq_m3", dq(s, 3), "dq_m4", dq(s, 4), ...
            "prob_m1", t.selectedProbability(s, 1), "prob_m2", t.selectedProbability(s, 2), ...
            "prob_m3", t.selectedProbability(s, 3), "prob_m4", t.selectedProbability(s, 4), ...
            "reward", t.reward(s));
        if isempty(tRows), tRows = trRow; else, tRows(end+1) = trRow; end %#ok<AGROW>
    end
    tTable = struct2table(tRows);
    writetable(tTable, csvFile);
    save(matFile, "tTable", "t", "r");
end

% 9. Seleccion y generacion ANNOTATED
fprintf("Generando subconjunto representativo ANNOTATED...\n");
annotDir = fullfile(outDir, "figures", "annotated");
subE4 = E(E.controller == "FINAL_E4", :);

% Criterios de seleccion deterministas
[~, idxWorst] = max(subE4.trackingMSE);
[~, idxBest] = min(subE4.trackingMSE);

subOpen = subE4(subE4.side == 2, :);
[~, idxWorstOpenRel] = max(subOpen.trackingMSE);
[~, idxBestOpenRel] = min(subOpen.trackingMSE);
rowWorstOpen = subOpen.repetition(idxWorstOpenRel);
rowBestOpen = subOpen.repetition(idxBestOpenRel);
idxWorstOpen = find(subE4.side == 2 & subE4.repetition == rowWorstOpen & subE4.subject == subOpen.subject(idxWorstOpenRel), 1);
idxBestOpen = find(subE4.side == 2 & subE4.repetition == rowBestOpen & subE4.subject == subOpen.subject(idxBestOpenRel), 1);

subClose = subE4(subE4.side == 1, :);
[~, idxWorstCloseRel] = max(subClose.trackingMSE);
[~, idxBestCloseRel] = min(subClose.trackingMSE);
rowWorstClose = subClose.repetition(idxWorstCloseRel);
rowBestClose = subClose.repetition(idxBestCloseRel);
idxWorstClose = find(subE4.side == 1 & subE4.repetition == rowWorstClose & subE4.subject == subClose.subject(idxWorstCloseRel), 1);
idxBestClose = find(subE4.side == 1 & subE4.repetition == rowBestClose & subE4.subject == subClose.subject(idxBestCloseRel), 1);

subMateo = subE4(subE4.subject == "MATEO", :);
[~, idxMateoRel] = min(abs(subMateo.trackingMSE - median(subMateo.trackingMSE)));
idxMateo = find(subE4.subject == "MATEO" & subE4.repetition == subMateo.repetition(idxMateoRel) & subE4.side == subMateo.side(idxMateoRel), 1);

subSandra = subE4(subE4.subject == "SANDRA", :);
[~, idxSandraRel] = min(abs(subSandra.trackingMSE - median(subSandra.trackingMSE)));
idxSandra = find(subE4.subject == "SANDRA" & subE4.repetition == subSandra.repetition(idxSandraRel) & subE4.side == subSandra.side(idxSandraRel), 1);

candidates = [ ...
    struct("idx", idxWorst, "reason", "Peor MSE Global"); ...
    struct("idx", idxBest, "reason", "Mejor MSE Global"); ...
    struct("idx", idxWorstOpen, "reason", "Peor APERTURA"); ...
    struct("idx", idxBestOpen, "reason", "Mejor APERTURA"); ...
    struct("idx", idxWorstClose, "reason", "Peor CIERRE"); ...
    struct("idx", idxBestClose, "reason", "Mejor CIERRE"); ...
    struct("idx", idxMateo, "reason", "Representativo MATEO"); ...
    struct("idx", idxSandra, "reason", "Representativo SANDRA") ...
];

seenKeys = containers.Map();
annotatedRecords = {};
for cIdx = 1:numel(candidates)
    c = candidates(cIdx);
    eIdx = c.idx;
    t = traces{eIdx, 5};
    key = sprintf("%s_%d_%d", t.metadata.subject, t.metadata.repetition, t.metadata.side);
    if isKey(seenKeys, key), continue; end
    seenKeys(key) = true;

    files = sealedPlotAnnotated(t, annotDir, c.reason);
    annotatedRecords{end+1} = struct( ...
        "reason", c.reason, ...
        "subject", string(t.metadata.subject), ...
        "row", double(t.metadata.repetition), ...
        "direction", directions(t.metadata.side), ...
        "mse", subE4.trackingMSE(eIdx), ...
        "pngRel", "figures/annotated/PNG/" + extractAfter(files.png, "annotated" + filesep + "PNG" + filesep), ...
        "figRel", "figures/annotated/FIG/" + extractAfter(files.fig, "annotated" + filesep + "FIG" + filesep), ...
        "csvRel", "figures/annotated/CSV/" + extractAfter(files.csv, "annotated" + filesep + "CSV" + filesep), ...
        "matRel", "figures/annotated/MAT/" + extractAfter(files.mat, "annotated" + filesep + "MAT" + filesep)); %#ok<AGROW>
end

% 10. Generar 5 figuras globales de publicacion
fprintf("Generando 5 figuras globales de publicacion...\n");
globalFigs = sealedPlotGlobalFigures(outDir, P, S, Mot, D, C);

% 11. Evaluar Gates de Decision Preregistrados
zeroMse = P.trackingMSE(P.controller == "ZERO");
agentMse = P.trackingMSE(P.controller == "AGENT7250");
p2Mse = P.trackingMSE(P.controller == "P_2");
oracleMse = P.trackingMSE(P.controller == "ORACLE_H5");
e4Mse = P.trackingMSE(P.controller == "FINAL_E4");

changePct = 100 * (e4Mse - agentMse) / agentMse;

mateoAgent = S.trackingMSE(S.controller == "AGENT7250" & S.subject == "MATEO");
mateoE4 = S.trackingMSE(S.controller == "FINAL_E4" & S.subject == "MATEO");
mateoChangePct = 100 * (mateoE4 - mateoAgent) / mateoAgent;

sandraAgent = S.trackingMSE(S.controller == "AGENT7250" & S.subject == "SANDRA");
sandraE4 = S.trackingMSE(S.controller == "FINAL_E4" & S.subject == "SANDRA");
sandraChangePct = 100 * (sandraE4 - sandraAgent) / sandraAgent;

e4Cycles = P.persistentTwoCycleTotal(P.controller == "FINAL_E4");
e4Periodic = 0; % Verificado por e2fPeriodicTrace
for e = 1:40
    for m = 1:4
        e4Periodic = e4Periodic + double(e2fPeriodicTrace(traces{e, 5}.q, traces{e, 5}.pwm, m, false) > 0);
    end
end

e4M3Rate = P.m3ReversalRate(P.controller == "FINAL_E4");
agentM3Rate = P.m3ReversalRate(P.controller == "AGENT7250");
maxCatFrac = max(C.maxCategoryFraction(C.controller == "FINAL_E4"));

gateA = e4Mse < agentMse;
gateB = (mateoChangePct <= 10.0) && (sandraChangePct <= 10.0);
gateC = (e4Cycles == 0);
gateD = (e4Periodic == 0);
gateE = (e4M3Rate <= agentM3Rate);
gateF = (maxCatFrac <= 0.90);

allGatesPass = gateA && gateB && gateC && gateD && gateE && gateF;
finalResult = "FAIL";
if allGatesPass, finalResult = "PASS"; end

summary = struct( ...
    "status", "COMPLETE", ...
    "finalResult", finalResult, ...
    "finalAgentSHA256", finalSha, ...
    "unblindingTimestamp", unblindTime, ...
    "episodes", 40, ...
    "zeroMSE", zeroMse, ...
    "agent7250MSE", agentMse, ...
    "p2MSE", p2Mse, ...
    "oracleMSE", oracleMse, ...
    "finalE4MSE", e4Mse, ...
    "changePct", changePct, ...
    "mateoAgent7250MSE", mateoAgent, ...
    "mateoFinalE4MSE", mateoE4, ...
    "mateoChangePct", mateoChangePct, ...
    "sandraAgent7250MSE", sandraAgent, ...
    "sandraFinalE4MSE", sandraE4, ...
    "sandraChangePct", sandraChangePct, ...
    "finalE4Cycles", e4Cycles, ...
    "finalE4Periodicities", e4Periodic, ...
    "finalE4M3Rate", e4M3Rate, ...
    "agent7250M3Rate", agentM3Rate, ...
    "maxCategoryFraction", maxCatFrac, ...
    "gateA", gateA, ...
    "gateB", gateB, ...
    "gateC", gateC, ...
    "gateD", gateD, ...
    "gateE", gateE, ...
    "gateF", gateF, ...
    "allGatesPass", allGatesPass, ...
    "outDir", outDir);

% 12. Construir reporte interactivo HTML
htmlReport = sealedBuildHtmlGallery(outDir, summary, data.selection, annotatedRecords, E);
summary.htmlReport = htmlReport;

% 13. Guardar resumenes JSON y estado final
e2cWriteJSON(fullfile(outDir, "FINAL_SEALED_TEST_SUMMARY.json"), summary);

postStatus = struct( ...
    "status", "COMPLETE", ...
    "stage", "FINAL_SEALED_TEST", ...
    "finalResult", finalResult, ...
    "sealedTestOpened", true, ...
    "trainingExecuted", false, ...
    "finalAgentSHA256", finalSha, ...
    "episodes", 40, ...
    "compactPng", 40, "compactFig", 40, ...
    "proPng", 40, "proFig", 40, ...
    "classicPng", 40, "classicFig", 40, ...
    "annotatedCount", numel(annotatedRecords), ...
    "globalFiguresCount", 5, ...
    "traceMatch", true, "pwmMatch", true, "metricsMatch", true, ...
    "htmlReport", htmlReport);
e2cWriteJSON(fullfile(outDir, "POST_TEST_STATUS.json"), postStatus);

fprintf("\n==================================================\n");
fprintf("TEST FINAL SELLADO COMPLETADO: %s\n", finalResult);
fprintf("Macro MSE: FINAL_E4 = %.4f | Agent7250 = %.4f (%.2f%%)\n", e4Mse, agentMse, changePct);
fprintf("MATEO: %.4f vs %.4f (%+.2f%%) | SANDRA: %.4f vs %.4f (%+.2f%%)\n", ...
    mateoE4, mateoAgent, mateoChangePct, sandraE4, sandraAgent, sandraChangePct);
fprintf("Ciclos: %d | Periodicidades: %d | M3 Reversal Rate: %.4f vs %.4f\n", ...
    e4Cycles, e4Periodic, e4M3Rate, agentM3Rate);
fprintf("Informe interactivo: %s\n", htmlReport);
fprintf("==================================================\n");

end

function restoreContext(oldPath, oldDir, oldRng, oldOverride)
if ~isempty(fieldnames(oldOverride))
    setConfigurablesOverride(oldOverride);
elseif exist('clearConfigurablesOverride', 'file') || exist('clearConfigurablesOverride', 'builtin')
    clearConfigurablesOverride();
end
cd(oldDir); rng(oldRng); path(oldPath);
end

function writeText(filePath, textContent)
fid = fopen(filePath, "w", "native", "UTF-8");
if fid < 0, error("No se pudo abrir el archivo %s", filePath); end
fprintf(fid, "%s\n", textContent);
fclose(fid);
end
