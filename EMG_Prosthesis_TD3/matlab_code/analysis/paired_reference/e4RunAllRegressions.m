function summary = e4RunAllRegressions()
% e4RunAllRegressions ejecuta la bateria completa y limpia de todas las suites vigentes
% antes de la implementacion y entrenamiento de E4.
% Incluye:
% - E0P, E2A, E2B, E2C (via e2cRunTests: 81 tests con proteccion de hashes historicos)
% - E2D, E2E, E2F, E2G
% - E3A-X (Infrastructure, PlotHelpers, EvaluationArtifacts, PostTraining)
% - CAP192
% - E3B (Categorical)
% - E3C (Temporal)
% - E3D (Temporal Intent)
% - E3E (Domain Audit)
% - E3F (Subject-Invariant PPO)
% - E3F Post-Training (COMPACT, PRO, ANNOTATED, CLASSIC, fixture 15 PWM)

here = string(fileparts(mfilename("fullpath")));
root = fileparts(fileparts(here));
out = fullfile(here, "e4_results", "regression_tests");
if ~isfolder(out), mkdir(out); end

oldPath = path;
priorOverride = struct();
if isappdata(0, "configurables_override")
    priorOverride = getappdata(0, "configurables_override");
end
cleanup = onCleanup(@() restoreEnv(oldPath, priorOverride)); %#ok<NASGU>

addpath(root, here, fullfile(here, "e3ax"), fullfile(here, "e3b"), fullfile(here, "e3c"), ...
    fullfile(here, "e3d"), fullfile(here, "e3e"), fullfile(here, "e3f"), fullfile(here, "cap192"), ...
    fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));

% 1. Regresiones previas (81 tests E0P, E2A, E2B, E2C)
fprintf("=== 1. Ejecutando e2cRunTests (E0P, E2A, E2B, E2C) ===\n");
rE2C = e2cRunTests(outputDir=fullfile(out, "e0p_e2a_e2b_e2c"));
assert(rE2C.passed == 81, "E4:Regr:E2CFailed", "e2cRunTests no paso 81 tests.");
T = readtable(fullfile(out, "e0p_e2a_e2b_e2c", "test_results.csv"), TextType="string", Delimiter=",");
for f = ["Passed", "Failed", "Incomplete"]
    T.(f) = logical(T.(f));
end

% 2. Suites intermedias y posteriores
suites = [ ...
    "testPairedReferenceE2D.m", ...
    "testPairedReferenceE2E.m", ...
    "testPairedReferenceE2F.m", ...
    "testPairedReferenceE2G.m", ...
    "testE3AXInfrastructure.m", ...
    "testE3AXPlotHelpers.m", ...
    "testE3AXEvaluationArtifacts.m", ...
    "testE3AXPostTraining.m", ...
    "testCAP192Diagnostic.m", ...
    "testE3BCategorical.m", ...
    "testE3CTemporal.m", ...
    "testE3DTemporalIntent.m", ...
    "testE3EDomainAudit.m", ...
    "testE3FSubjectInvariantPPO.m", ...
    "testE3FPostTraining.m", ...
    "testE4FinalDevelopment.m" ...
];

fprintf("=== 2. Ejecutando suites vigentes (%d archivos) ===\n", numel(suites));
for sIdx = 1:numel(suites)
    file = suites(sIdx);
    fprintf("Ejecutando suite: %s...\n", file);
    if file == "testE3CTemporal.m"
        cfg = e3cConfig;
        s = load(fullfile(cfg.e3bRun, "config.mat"), "o");
        o = s.o; o.run_training = false; o.newTraining = false;
        setConfigurablesOverride(o);
    end
    r = runtests(fullfile(root, "tests", "paired_reference", file));
    N = table(string({r.Name})', [r.Passed]', [r.Failed]', [r.Incomplete]', [r.Duration]', ...
        VariableNames=["Name", "Passed", "Failed", "Incomplete", "Duration"]);
    T = [T; N]; %#ok<AGROW>
end

writetable(T, fullfile(out, "all_test_results.csv"));
summary = struct("total", height(T), "passed", nnz(T.Passed), "failed", nnz(T.Failed), ...
    "incomplete", nnz(T.Incomplete), "suitesRun", 1 + numel(suites));
e2cWriteJSON(fullfile(out, "summary.json"), summary);
fprintf("\n==================================================\n");
fprintf("REGRESION COMPLETA PRE-E4: %d/%d PASS (0 fallos)\n", summary.passed, summary.total);
fprintf("==================================================\n");
assert(all(T.Passed) && ~any(T.Failed) && ~any(T.Incomplete), "E4:Regr:Failed", "Hubo fallos en la regresion.");
end

function restoreEnv(oldP, oldO)
setConfigurablesOverride(oldO);
path(oldP);
end
