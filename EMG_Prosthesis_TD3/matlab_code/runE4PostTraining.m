function summary = runE4PostTraining(outDir)
% runE4PostTraining ejecuta la evaluacion y generacion de figuras completas
% para E4_FINAL sin entrenar ni modificar los checkpoints congelados.

arguments
    outDir (1, 1) string = ""
end

root = string(fileparts(mfilename("fullpath")));
pr = fullfile(root, "analysis", "paired_reference");
e4Dir = fullfile(pr, "e4");

if strlength(outDir) == 0
    pointer = fullfile(pr, "e4_results", "last_run_path.txt");
    if isfile(pointer)
        outDir = erase(strtrim(string(fileread(pointer))), char(65279));
    else
        outDir = "C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e4_final_development\run_20260910_084228_108_8176e5a9";
    end
end

assert(isfolder(outDir), "E4:InvalidRunDir", "El directorio %s no existe.", outDir);

oldPath = path;
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
cleanup = onCleanup(@() restoreEnv(oldPath, oldOverride)); %#ok<NASGU>

addpath(root, pr, fullfile(pr, "e3ax"), fullfile(pr, "e3b"), fullfile(pr, "e3f"), e4Dir, fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));

% Asegurar que no se ejecute entrenamiento
s = load(fullfile(outDir, "config.mat"), "cfg", "o");
o = s.o;
o.run_training = false;
o.newTraining = false;
setConfigurablesOverride(o);

fprintf("=== Postprocesado y Evaluacion In-Sample E4 (POSTPROCESS_ONLY = YES) ===\n");
fprintf("Directorio: %s\n", outDir);

% Ejecutar pipeline de generacion
res = e4GenerateFinalEvaluation(outDir);

% Ejecutar verificacion rigurosa de archivos y metricas
checkReport = e4CheckPostProcessing(outDir);

summary = struct("status", "COMPLETE", ...
                 "postprocessOnly", true, ...
                 "trainingExecuted", false, ...
                 "checkpoint", 500000, ...
                 "finalAgentSHA256", fileread(fullfile(outDir, "FINAL_AGENT_SHA256.txt")), ...
                 "episodes", checkReport.episodes, ...
                 "trainEpisodes", checkReport.trainEpisodes, ...
                 "validationEpisodes", checkReport.validationEpisodes, ...
                 "macroMSE", res.macroMSE, ...
                 "compactPng", checkReport.compactPng, ...
                 "compactFig", checkReport.compactFig, ...
                 "proPng", checkReport.proPng, ...
                 "proFig", checkReport.proFig, ...
                 "classicPng", checkReport.classicPng, ...
                 "classicFig", checkReport.classicFig, ...
                 "annotatedCount", checkReport.annotatedCount, ...
                 "traceMatch", checkReport.traceMatch, ...
                 "pwmMatch", checkReport.pwmMatch, ...
                 "metricsMatch", checkReport.metricsMatch, ...
                 "htmlReport", res.html, ...
                 "sealedSubjectsUntouched", checkReport.sealedSubjectsUntouched);

e2cWriteJSON(fullfile(outDir, "POST_TRAINING_STATUS.json"), summary);
fprintf("Postprocesado y evaluacion in-sample E4 completado exitosamente.\n");
fprintf("Development Macro MSE: %.6f\n", res.macroMSE);
end

function restoreEnv(oldP, oldO)
setConfigurablesOverride(oldO);
path(oldP);
end
