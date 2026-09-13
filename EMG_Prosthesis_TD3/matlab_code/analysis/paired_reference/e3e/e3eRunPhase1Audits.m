function results = e3eRunPhase1Audits()
% e3eRunPhase1Audits: Ejecuta la fase diagnóstica inicial de E3E (cobertura,
% ventana inicial, estadísticas por sujeto, descomposición de varianza y PCA).
here = string(fileparts(mfilename("fullpath")));
pr = fileparts(here);
root = fileparts(fileparts(pr));

oldPath = path;
c = onCleanup(@() path(oldPath));
addpath(root, pr, here, fullfile(pr, "e3d"), fullfile(pr, "e3c"), fullfile(pr, "e3b"), fullfile(pr, "e3ax"), fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));

fprintf("=== Iniciando Fase 1 de Auditoría E3E ===\n");

% 1. Cobertura de datos y ventana inicial (Secciones 17 y 18)
fprintf("[1/3] Ejecutando auditoría de cobertura de datos y ventana inicial...\n");
[covSummary, initSummary] = e3eAuditCoverageAndInitialWindow();

% 2. Estadísticas por sujeto y descomposición de varianza (Secciones 12 y 13)
fprintf("[2/3] Ejecutando estadísticas por sujeto y descomposición de varianza...\n");
[statsSummary, varSummary] = e3eAuditFeatureStatsAndVariance();

% 3. PCA diagnóstica (Sección 14)
fprintf("[3/3] Ejecutando PCA diagnóstica...\n");
pcaSummary = e3eAuditPCA();

results = struct(...
    "coverage", covSummary, ...
    "initialWindow", initSummary, ...
    "featureStats", statsSummary, ...
    "variance", varSummary, ...
    "pca", pcaSummary);

fprintf("=== Fase 1 de Auditoría E3E completada con éxito ===\n");
end
