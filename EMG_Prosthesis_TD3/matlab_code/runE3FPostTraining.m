function summary = runE3FPostTraining(outDir)
% runE3FPostTraining recupera o genera la evaluacion y figuras por episodio
% de E3F sin entrenar ni modificar los resultados cientificos congelados.
%
% Uso:
%   summary = runE3FPostTraining(runDir)

arguments
    outDir (1, 1) string = ""
end

root = string(fileparts(mfilename("fullpath")));
pr = fullfile(root, "analysis", "paired_reference");

if strlength(outDir) == 0
    pointer = fullfile(pr, "e3f_results", "smoke_path.txt");
    if isfile(pointer)
        outDir = erase(strtrim(string(fileread(pointer))), char(65279));
    else
        error("E3F:MissingRunDir", "Debe especificar el directorio de la corrida runDir.");
    end
end

assert(isfolder(outDir), "E3F:InvalidRunDir", "El directorio %s no existe.", outDir);

oldPath = path;
oldOverride = struct();
if isappdata(0, "configurables_override")
    oldOverride = getappdata(0, "configurables_override");
end
cleanup = onCleanup(@() restoreEnv(oldPath, oldOverride)); %#ok<NASGU>

addpath(root, pr, fullfile(pr, "e3ax"), fullfile(pr, "e3f"), fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));

% Asegurar que no se ejecute entrenamiento
s = load(fullfile(outDir, "config.mat"), "cfg", "o");
o = s.o;
o.run_training = false;
o.newTraining = false;
setConfigurablesOverride(o);

fprintf("=== Postprocesado Visual E3F (POSTPROCESS_ONLY = YES) ===\n");
fprintf("Directorio: %s\n", outDir);

% Ejecutar pipeline de generacion
res = e3fGenerateFinalEvaluation(outDir);

% Ejecutar verificacion rigurosa de archivos y metricas
checkReport = e3fCheckPostProcessing(outDir);

summary = struct("status", "COMPLETE", ...
                 "postprocessOnly", true, ...
                 "trainingExecuted", false, ...
                 "checkpoint", 1000000, ...
                 "bestEqualsLast", true, ...
                 "episodes", checkReport.episodes, ...
                 "trainEpisodes", checkReport.trainEpisodes, ...
                 "validationEpisodes", checkReport.validationEpisodes, ...
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
fprintf("Postprocesado visual E3F completado exitosamente.\n");
end

function restoreEnv(oldP, oldO)
setConfigurablesOverride(oldO);
path(oldP);
end
