function summary=e2eRunTests(options)
% 107 pruebas historicas sin sobrescribir resultados anteriores; nuevas E2E.
arguments
    options.outputDir (1,1) string = ""
end
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));
out=options.outputDir;if out=="",out=fullfile(here,"e2e_results");end
assert(contains(replace(lower(out),"\","/"),"e2e_results"),"E2E:TestOutputScope");
if ~isfolder(out),mkdir(out);end
oldPath=path;oldRng=rng;oldDir=pwd;
hadE2D=isappdata(0,"E2DTestOutputDirectory");oldE2D="";
if hadE2D,oldE2D=getappdata(0,"E2DTestOutputDirectory");rmappdata(0,"E2DTestOutputDirectory");end
hadE2E=isappdata(0,"E2ETestOutputDirectory");oldE2E="";
if hadE2E,oldE2E=getappdata(0,"E2ETestOutputDirectory");end
cleanup=onCleanup(@() restoreContext(oldPath,oldRng,oldDir,hadE2D,oldE2D,hadE2E,oldE2E)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"),"E2E:ForbiddenPath");
cd(root);before=verifyProtected(root,out); %#ok<NASGU>
previousDir=fullfile(out,"previous_tests");
prior=e2cRunTests(outputDir=previousDir);
assert(prior.totalTests==81 && prior.passed==81,"E2E:HistoricalTestCount");
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(here);
% El archivo E2D no escribe: carga su directorio historico de forma natural.
e2d=runtests(fullfile(root,"tests","paired_reference","testPairedReferenceE2D.m"));
e2dTable=asTable(e2d);assert(height(e2dTable)==26,"E2E:HistoricalTestCount");
oldTable=readtable(fullfile(previousDir,"test_results.csv"),TextType="string");
for name=["Passed","Failed","Incomplete"],oldTable.(name)=logical(oldTable.(name));end
historical=[oldTable;e2dTable];
assert(height(historical)==107,"E2E:HistoricalTestCount");
setappdata(0,"E2ETestOutputDirectory",out);
results=runtests(fullfile(root,"tests","paired_reference","testPairedReferenceE2E.m"));
newTable=asTable(results);combined=[historical;newTable];
writetable(historical,fullfile(out,"previous_test_results.csv"));
writetable(combined,fullfile(out,"test_results.csv"));
integrity=verifyProtected(root,out);writetable(integrity,fullfile(out,"historical_integrity.csv"));
summary=struct("previousTests",height(historical),"previousPassed",nnz(historical.Passed), ...
    "newE2ETests",height(newTable),"newE2EPassed",nnz(newTable.Passed), ...
    "totalTests",height(combined),"passed",nnz(combined.Passed), ...
    "failed",nnz(combined.Failed),"incomplete",nnz(combined.Incomplete), ...
    "e2aTests",13,"e0pTests",24,"e2bTests",22,"e2cTests",22,"e2dTests",26, ...
    "historicalFilesProtected",height(integrity),"historicalFilesUnchanged",all(integrity.unchanged), ...
    "historicalTestsEdited",false,"sandboxInPath",false,"matlabVersion",string(version));
e2cWriteJSON(fullfile(out,"test_summary.json"),summary);
assert(all(combined.Passed) && ~any(combined.Failed) && ~any(combined.Incomplete), ...
    "E2E:RegressionFailed","Todas las pruebas deben pasar sin incompletas.");
assert(all(integrity.unchanged),"E2E:HistoricalFileChanged");
end

function T=asTable(results)
T=table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
end

function T=verifyProtected(root,out)
T=readtable(fullfile(out,"historical_hashes_before.csv"),TextType="string");
T.currentSHA256=strings(height(T),1);
for k=1:height(T)
    assert(~contains(lower(T.path(k)),"sandbox"),"E2E:ForbiddenPath");
    file=fullfile(root,T.path(k));assert(isfile(file),"E2E:HistoricalFileMissing");
    T.currentSHA256(k)=e2cSHA256(file);
end
T.unchanged=T.sha256==T.currentSHA256;
assert(all(T.unchanged),"E2E:HistoricalFileChanged");
end

function restoreContext(oldPath,oldRng,oldDir,hadE2D,oldE2D,hadE2E,oldE2E)
path(oldPath);rng(oldRng);cd(oldDir);
if hadE2D,setappdata(0,"E2DTestOutputDirectory",oldE2D);
elseif isappdata(0,"E2DTestOutputDirectory"),rmappdata(0,"E2DTestOutputDirectory");end
if hadE2E,setappdata(0,"E2ETestOutputDirectory",oldE2E);
elseif isappdata(0,"E2ETestOutputDirectory"),rmappdata(0,"E2ETestOutputDirectory");end
end
