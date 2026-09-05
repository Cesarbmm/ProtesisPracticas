function results = run_paired_reference_stage0_toolbox_manifest(options)
%run_paired_reference_stage0_toolbox_manifest A.1 del cierre de E0.
%
%   Registra la configuracion de toolboxes y como interpreta ESTA
%   instalacion de MATLAB los 56 objetos ws de fit_C2.mat, y fija los hashes
%   de las fuentes de la planta.
%
%   No modifica nada. Solo lee y escribe un manifiesto.
%
%   results = run_paired_reference_stage0_toolbox_manifest()

arguments
    options.outputRoot (1,1) string = ""
end

here = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(here));
projectRoot = fileparts(matlabRoot);
workspaceRoot = fileparts(projectRoot);
addpath(genpath(matlabRoot));
oldDir = cd(matlabRoot);
restoreDir = onCleanup(@() cd(oldDir)); %#ok<NASGU>

if strlength(options.outputRoot) > 0
    outRoot = char(options.outputRoot);
else
    outRoot = fullfile(workspaceRoot, "Agentes", "paired_reference", "stage0");
end
ensureDirectoryExists(outRoot);

results = struct();
results.timestamp = string(datetime("now", Format="yyyy-MM-dd HH:mm:ss"));
results.matlabVersion = string(version);
results.matlabRelease = string(version("-release"));
results.computer = string(computer);

% ------------------------------------------------------------ ver
v = ver();
results.toolboxNames = string({v.Name});
results.toolboxVersions = string({v.Version});
fprintf("=== ver ===\n");
for i = 1:numel(v)
    fprintf("  %-45s %s\n", v(i).Name, v(i).Version);
end

% ------------------------------------------- Curve Fitting Toolbox
results.licenseCurveFitting = false;
try
    results.licenseCurveFitting = logical(license("test", "Curve_Fitting_Toolbox"));
catch ME
    fprintf("license() fallo: %s\n", ME.message);
end
results.cfitClassExists = exist("cfit", "class") == 8;
results.whichCfit = string(which("cfit", "-all"));
results.curveFittingInstalled = any(contains(results.toolboxNames, "Curve Fitting"));

fprintf("\n=== Curve Fitting Toolbox ===\n");
fprintf("  aparece en ver()            : %d\n", results.curveFittingInstalled);
fprintf("  license('test', ...)        : %d\n", results.licenseCurveFitting);
fprintf("  exist('cfit','class') == 8  : %d\n", results.cfitClassExists);
fprintf("  which cfit -all             :\n");
for i = 1:numel(results.whichCfit)
    fprintf("    %s\n", results.whichCfit(i));
end

% --------------------------------------------- inspeccion de los 56 ws
simDir = fullfile(matlabRoot, "src", "@SimController");
fitFile = fullfile(simDir, "fit_C2.mat");
curveFile = fullfile(simDir, "pattern_curve.mat");

warnState = warning("off", "all");
lastwarn("");
fitData = load(fitFile);
[lastMsg, lastId] = lastwarn();
warning(warnState);
results.loadWarningMessage = string(lastMsg);
results.loadWarningId = string(lastId);
if strlength(results.loadWarningMessage) > 0
    fprintf("\nAviso de MATLAB al cargar fit_C2.mat:\n  [%s] %s\n", ...
        results.loadWarningId, results.loadWarningMessage);
end

speedsTxt = ["sp_3F" "sp_5F" "sp_7F" "sp_9F" "sp_BF" "sp_DF" "sp_FF"];
dirs = ["closing" "opening"];
rows = struct("speedTxt", {}, "direction", {}, "motor", {}, "wsClass", {}, ...
    "wsRows", {}, "wsCols", {}, "wsNumel", {}, "wsIsEmpty", {}, ...
    "wsIsNumeric", {}, "simulatorBranch", {});

for spTxt = speedsTxt
    if ~isfield(fitData.params, spTxt)
        continue
    end
    for dirName = dirs
        for m = 1:4
            ws = fitData.params.(spTxt).(dirName).(sprintf("m_%d", m)).ws;
            sz = size(ws);
            if numel(ws) == 0
                branch = "pattern_curve";   % useCurveFallback = true
            else
                branch = "ws";              % useCurveFallback = false
            end
            rows(end+1) = struct("speedTxt", spTxt, "direction", dirName, ...
                "motor", m, "wsClass", string(class(ws)), ...
                "wsRows", sz(1), "wsCols", sz(2), "wsNumel", numel(ws), ...
                "wsIsEmpty", isempty(ws), "wsIsNumeric", isnumeric(ws), ...
                "simulatorBranch", branch); %#ok<AGROW>
        end
    end
end

results.wsInspection = struct2table(rows);
results.nCombinations = height(results.wsInspection);
results.wsClasses = unique(results.wsInspection.wsClass);
results.nEmpty = sum(results.wsInspection.wsIsEmpty);
results.nNumeric = sum(results.wsInspection.wsIsNumeric);
results.branches = unique(results.wsInspection.simulatorBranch);
results.plantSourceAtRuntime = strjoin(results.branches(:)', "+");

fprintf("\n=== interpretacion de ws en esta instalacion ===\n");
fprintf("  combinaciones      : %d\n", results.nCombinations);
fprintf("  clases de ws       : %s\n", strjoin(results.wsClasses(:)', ", "));
fprintf("  vacios             : %d\n", results.nEmpty);
fprintf("  numericos          : %d\n", results.nNumeric);
fprintf("  rama del simulador : %s\n", results.plantSourceAtRuntime);
disp(head(results.wsInspection, 6));

% ------------------------------------------------------------ hashes
results.hashes = struct( ...
    "fit_C2_mat", localFileHash(fitFile), ...
    "pattern_curve_mat", localFileHash(curveFile), ...
    "normValues_mat", localFileHash(fullfile(matlabRoot, "config", "normValues.mat")), ...
    "prosthesis_simulator_m", localFileHash(fullfile(simDir, "prosthesis_simulator.m")));

fprintf("\n=== hashes MD5 ===\n");
f = fieldnames(results.hashes);
for i = 1:numel(f)
    fprintf("  %-26s %s\n", f{i}, results.hashes.(f{i}));
end

outFile = fullfile(outRoot, "stage0_toolbox_manifest.mat");
save(outFile, "results");
localWriteTextManifest(fullfile(outRoot, "stage0_toolbox_manifest.txt"), results);
fprintf("\nManifiesto guardado en:\n  %s\n  %s\n", outFile, ...
    fullfile(outRoot, "stage0_toolbox_manifest.txt"));
end

%% ------------------------------------------------------------------------
function h = localFileHash(f)
digest = java.security.MessageDigest.getInstance("MD5");
fid = fopen(f, "r");
raw = fread(fid, inf, "*uint8");
fclose(fid);
digest.update(raw);
h = string(lower(reshape(dec2hex(typecast(digest.digest(), "uint8"), 2)', 1, [])));
end

%% ------------------------------------------------------------------------
function localWriteTextManifest(path, results)
fid = fopen(path, "w");
fprintf(fid, "MANIFIESTO DE ENTORNO - linea paired-reference\n");
fprintf(fid, "generado: %s\n\n", results.timestamp);
fprintf(fid, "MATLAB            : %s\n", results.matlabVersion);
fprintf(fid, "computer          : %s\n\n", results.computer);
fprintf(fid, "CURVE_FITTING_TOOLBOX_PRESENT : %d\n", results.curveFittingInstalled);
fprintf(fid, "license test                  : %d\n", results.licenseCurveFitting);
fprintf(fid, "cfit class exists             : %d\n", results.cfitClassExists);
fprintf(fid, "ws vacios / total             : %d / %d\n", results.nEmpty, results.nCombinations);
fprintf(fid, "clases de ws                  : %s\n", strjoin(results.wsClasses(:)', ", "));
fprintf(fid, "PLANT_SOURCE_AT_RUNTIME       : %s\n\n", results.plantSourceAtRuntime);
fprintf(fid, "TOOLBOXES\n");
for i = 1:numel(results.toolboxNames)
    fprintf(fid, "  %-45s %s\n", results.toolboxNames(i), results.toolboxVersions(i));
end
fprintf(fid, "\nHASHES MD5\n");
f = fieldnames(results.hashes);
for i = 1:numel(f)
    fprintf(fid, "  %-26s %s\n", f{i}, results.hashes.(f{i}));
end
fclose(fid);
end
