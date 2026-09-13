function summary = e2cRunTests(options)
% Regresiones E2C sin agregar directorios ajenos al experimento principal.
% Los tests historicos conservan sus bytes. Sus genpath(root) se interceptan
% en una fixture temporal que solo enumera directorios cientificos permitidos.
arguments
    options.outputDir (1,1) string = ""
    options.previousOnly (1,1) logical = false
end
here = string(fileparts(mfilename("fullpath")));
root = fileparts(fileparts(here));
if options.outputDir == "", options.outputDir = fullfile(here,"e2c_results"); end
out = options.outputDir;
if ~isfolder(out), mkdir(out); end
oldPath = path; oldRng = rng; oldDir = pwd;
cleanup = onCleanup(@() restoreContext(oldPath,oldRng,oldDir)); %#ok<NASGU>
assert(~contains(lower(string(oldPath)),"sandbox"), ...
    "E2C:ForbiddenPath","Usar un proceso MATLAB con rutas cientificas selectivas.");
cd(root);

% No se editan los tests ni la instalacion MATLAB. La funcion original se
% copia a TEMP con otro nombre y conserva su algoritmo para las demas rutas.
temporary = string(tempname); mkdir(temporary);
originalPath = fullfile(matlabroot,"toolbox","matlab","general","genpath.m");
original = fileread(originalPath);
renamed = regexprep(original,'\bgenpath\b','e2cOriginalGenpath');
writeText(fullfile(temporary,"e2cOriginalGenpath.m"),renamed);
writeText(fullfile(temporary,"genpath.m"),wrapperSource(root));
addpath(temporary,"-begin");
assert(strcmp(which("genpath"),fullfile(temporary,"genpath.m")), ...
    "E2C:PathIsolationFailed","El wrapper temporal no tiene precedencia.");
setappdata(0,"E2CWhitelistGenpathUsed",false);
addpath(genpath(root));

names = ["testPairedReferenceGloveFreeExecution.m", ...
    "testPairedReferencePlantCanonicalSource.m", ...
    "testPairedReferencePlantHoldOutsideCurve.m", ...
    "testPairedReferenceStage0PlantSanity.m", ...
    "testPairedReferenceTeacherAvailability.m", ...
    "testPairedReferenceControlMetrics.m", ...
    "testPairedReferenceProportionalAction.m", ...
    "testPairedReferenceE2BObservedFailures.m"];
testDir = fullfile(root,"tests","paired_reference");
if ~options.previousOnly
    additional = dir(fullfile(testDir,"testPairedReferenceE2C*.m"));
    assert(~isempty(additional),"E2C:MissingTests","Faltan los tests E2C.");
    names = [names, sort(string({additional.name}))];
end
integrityBefore = verifyHistoricalHashes(root,here);
results = runtests(fullfile(testDir,names));
T = table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','Duration'});
writetable(T,fullfile(out,"test_results.csv"));
integrityAfter = verifyHistoricalHashes(root,here);
writetable(integrityAfter,fullfile(out,"historical_integrity.csv"));
assert(~contains(lower(string(path)),"sandbox"));
assert(getappdata(0,"E2CWhitelistGenpathUsed"));

isE2A = startsWith(T.Name,"testPairedReferenceGloveFreeExecution/");
isE0P = startsWith(T.Name,"testPairedReferencePlantCanonicalSource/") | ...
    startsWith(T.Name,"testPairedReferencePlantHoldOutsideCurve/") | ...
    startsWith(T.Name,"testPairedReferenceStage0PlantSanity/");
isE2C = startsWith(T.Name,"testPairedReferenceE2C");
isE2B = ~isE2A & ~isE0P & ~isE2C;
assert(nnz(isE2A)==13 && nnz(isE0P)==24 && nnz(isE2B)==22, ...
    "E2C:HistoricalTestCountChanged","La bateria previa debe conservar 13+24+22 tests.");
summary = struct("previousTests",nnz(~isE2C),"newE2CTests",nnz(isE2C), ...
    "totalTests",height(T),"passed",nnz(T.Passed),"failed",nnz(T.Failed), ...
    "incomplete",nnz(T.Incomplete),"e2aTests",nnz(isE2A),"e0pTests",nnz(isE0P), ...
    "e2bTests",nnz(isE2B),"historicalFilesProtected",height(integrityBefore), ...
    "historicalFilesUnchanged",all(integrityAfter.unchanged), ...
    "sandboxInPath",false,"historicalTestsEdited",false, ...
    "pathIsolation","TEMP_GENPATH_WHITELIST", ...
    "temporaryHarness",temporary,"matlabVersion",string(version));
writeText(fullfile(out,"test_summary.json"),jsonencode(summary,PrettyPrint=true));
assert(all(T.Passed) && ~any(T.Failed) && ~any(T.Incomplete), ...
    "E2C:RegressionFailed","Las regresiones deben pasar completamente.");
end

function T = verifyHistoricalHashes(root,here)
manifest = fullfile(here,"e2c_results","historical_hashes_before.csv");
T = readtable(manifest,TextType="string");
T.currentSHA256 = strings(height(T),1);
for k = 1:height(T)
    relative = T.path(k);
    assert(~contains(lower(relative),"sandbox"));
    source = fullfile(root,relative);
    assert(isfile(source),"E2C:HistoricalFileMissing","Archivo historico ausente: %s",relative);
    T.currentSHA256(k) = sha256(source);
end
T.unchanged = T.sha256 == T.currentSHA256;
assert(all(T.unchanged),"E2C:HistoricalFileChanged", ...
    "La auditoria E2C no permite cambiar archivos historicos protegidos.");
end

function source = wrapperSource(root)
escaped = replace(root,"'","''");
lines = ["function p = genpath(d)"; ...
    "% Fixture temporal E2C: lista explicita, sin recorrer carpetas ajenas."; ...
    "if nargin == 0, p=e2cOriginalGenpath(); return; end"; ...
    "root = '" + escaped + "';"; ...
    "assert(~contains(lower(string(d)),'sandbox'),'E2C:ForbiddenPath','Ruta no autorizada.');"; ...
    "if strcmpi(char(d),root)"; ...
    "    allowed={'src','config','lib','analysis/paired_reference','tests/paired_reference','agents'};"; ...
    "    p=[root pathsep];"; ...
    "    for k=1:numel(allowed), p=[p e2cOriginalGenpath(fullfile(root,allowed{k}))]; end"; ...
    "    setappdata(0,'E2CWhitelistGenpathUsed',true);"; ...
    "else"; ...
    "    p=e2cOriginalGenpath(d);"; ...
    "end"; ...
    "assert(~contains(lower(string(p)),'sandbox'),'E2C:ForbiddenPath','Ruta no autorizada.');"; ...
    "end"];
source = char(join(lines,newline));
end

function digest = sha256(file)
fid = fopen(file,"rb"); assert(fid>=0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,"*uint8");
md = java.security.MessageDigest.getInstance("SHA-256"); md.update(bytes);
digest = string(lower(reshape(dec2hex(typecast(md.digest(),"uint8"),2).',1,[])));
end

function writeText(file,text)
fid = fopen(file,"w","n","UTF-8"); assert(fid>=0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s",text);
end

function restoreContext(oldPath,oldRng,oldDir)
path(oldPath); rng(oldRng); cd(oldDir);
if isappdata(0,"E2CWhitelistGenpathUsed"), rmappdata(0,"E2CWhitelistGenpathUsed"); end
end
