function summary = e2dRunTests(options)
% Ejecuta 81 regresiones intactas y los tests E2D, escribiendo solo en E2D.
arguments
    options.outputDir (1,1) string = ""
end
here = string(fileparts(mfilename("fullpath")));
root = fileparts(fileparts(here));
if options.outputDir=="", options.outputDir=fullfile(here,"e2d_results"); end
out = options.outputDir;
assert(contains(replace(lower(out),"\","/"),"e2d_results"), ...
    "E2D:TestOutputScope","La bateria E2D solo escribe bajo e2d_results.");
if ~isfolder(out), mkdir(out); end
oldPath=path; oldRng=rng; oldDir=pwd;
hadOutput=isappdata(0,"E2DTestOutputDirectory"); oldOutput="";
if hadOutput,oldOutput=getappdata(0,"E2DTestOutputDirectory");end
cleanup=onCleanup(@() restoreContext(oldPath,oldRng,oldDir,hadOutput,oldOutput)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"),"E2D:ForbiddenPath");
cd(root);
previousDir=fullfile(out,"previous_tests");
previous=e2cRunTests(outputDir=previousDir);
assert(previous.totalTests==81 && previous.passed==81 && previous.newE2CTests==22, ...
    "E2D:PreviousTestCount","Deben conservarse las 81 regresiones anteriores.");
addpath(genpath(fullfile(root,"src")));
addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
setappdata(0,"E2DTestOutputDirectory",out);
results=runtests(fullfile(root,"tests","paired_reference","testPairedReferenceE2D.m"));
newTable=table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
oldTable=readtable(fullfile(previousDir,"test_results.csv"),TextType="string");
for name=["Passed","Failed","Incomplete"]
    oldTable.(name)=logical(oldTable.(name));
end
combined=[oldTable;newTable];
writetable(combined,fullfile(out,"test_results.csv"));
integrity=verifyProtectedSources(root,out);
writetable(integrity,fullfile(out,"historical_integrity.csv"));
summary=struct("previousTests",height(oldTable),"previousPassed",nnz(oldTable.Passed), ...
    "newE2DTests",height(newTable),"newE2DPassed",nnz(newTable.Passed), ...
    "totalTests",height(combined),"passed",nnz(combined.Passed), ...
    "failed",nnz(combined.Failed),"incomplete",nnz(combined.Incomplete), ...
    "e2aTests",previous.e2aTests,"e0pTests",previous.e0pTests, ...
    "e2bTests",previous.e2bTests,"e2cTests",previous.newE2CTests, ...
    "historicalFilesProtected",height(integrity), ...
    "historicalFilesUnchanged",all(integrity.unchanged), ...
    "historicalTestsEdited",false,"sandboxInPath",false, ...
    "matlabVersion",string(version));
writeJson(fullfile(out,"test_summary.json"),summary);
assert(~contains(lower(string(path)),"sandbox"),"E2D:ForbiddenPath");
assert(all(combined.Passed) && ~any(combined.Failed) && ~any(combined.Incomplete), ...
    "E2D:RegressionFailed","Todas las regresiones deben pasar sin incompletos.");
assert(all(integrity.unchanged),"E2D:HistoricalFileChanged");
end

function T=verifyProtectedSources(root,out)
T=readtable(fullfile(out,"historical_hashes_before.csv"),TextType="string");
T.currentSHA256=strings(height(T),1);
for k=1:height(T)
    assert(~contains(lower(T.path(k)),"sandbox"),"E2D:ForbiddenPath");
    file=fullfile(root,T.path(k));
    assert(isfile(file),"E2D:HistoricalFileMissing","Archivo ausente: %s",T.path(k));
    T.currentSHA256(k)=sha256(file);
end
T.unchanged=T.sha256==T.currentSHA256;
end

function value=sha256(file)
fid=fopen(file,"rb");assert(fid>=0);cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
digest=java.security.MessageDigest.getInstance("SHA-256");digest.update(fread(fid,Inf,"*uint8"));
value=string(lower(reshape(dec2hex(typecast(digest.digest(),"uint8"),2).',1,[])));
end

function writeJson(file,value)
fid=fopen(file,"w","n","UTF-8");assert(fid>=0);cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end

function restoreContext(oldPath,oldRng,oldDir,hadOutput,oldOutput)
path(oldPath);rng(oldRng);cd(oldDir);
if hadOutput,setappdata(0,"E2DTestOutputDirectory",oldOutput);
elseif isappdata(0,"E2DTestOutputDirectory"),rmappdata(0,"E2DTestOutputDirectory");end
end
