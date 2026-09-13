function summary=e3axRunTests(options)
% Batería sin entrenamiento. Históricos inmutables, salidas sólo E3AX.
arguments,options.reusePrevious (1,1) logical = false;end
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
out=fullfile(pr,"e3ax_preparation","regression");if ~isfolder(out),mkdir(out);end
oldPath=path;oldRng=rng;oldDir=pwd;c=onCleanup(@() restore(oldPath,oldRng,oldDir)); %#ok<NASGU>
addpath(pr);addpath(here);cd(root);e3axVerifyHistory();
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(pr);addpath(here);
if options.reusePrevious
    old=readtable(fullfile(out,"previous_test_results.csv"),TextType="string",Delimiter=",");
    for f=["Passed","Failed","Incomplete"],old.(f)=logical(old.(f));end
    assert(height(old)==196 && all(old.Passed) && ~any(old.Failed | old.Incomplete),"E3AX:PreviousTestsRequired","Se requieren las196 regresiones previamente aprobadas y hashes intactos.");
else
    prior=e2cRunTests(outputDir=fullfile(out,"previous_tests"));assert(prior.passed==81);
    old=readtable(fullfile(out,"previous_tests","test_results.csv"),TextType="string");
    for f=["Passed","Failed","Incomplete"],old.(f)=logical(old.(f));end
    for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m","testPairedReferenceE2G.m"]
        old=[old;asTable(runtests(fullfile(root,"tests","paired_reference",file)))]; %#ok<AGROW>
    end
end
assert(height(old)==196);
new=asTable(runtests(fullfile(root,"tests","paired_reference",["testE3AXInfrastructure.m","testE3AXPlotHelpers.m","testE3AXEvaluationArtifacts.m"])));
combined=[old;new];writetable(old,fullfile(out,"previous_test_results.csv"));writetable(new,fullfile(out,"new_test_results.csv"));writetable(combined,fullfile(out,"test_results.csv"));
I=e3axVerifyHistory();writetable(I,fullfile(out,"historical_integrity.csv"));
summary=struct("previousTests",height(old),"previousPassed",nnz(old.Passed),"newE3AXTests",height(new),"newE3AXPassed",nnz(new.Passed), ...
    "totalTests",height(combined),"passed",nnz(combined.Passed),"failed",nnz(combined.Failed),"incomplete",nnz(combined.Incomplete), ...
    "historicalFilesProtected",height(I),"historicalFilesUnchanged",all(I.unchanged),"matlabVersion",string(version),"trainingExecuted",false,"previousResultsReused",options.reusePrevious);
e2cWriteJSON(fullfile(out,"test_summary.json"),summary);save(fullfile(out,"test_results.mat"),"combined","summary");disp(summary);
assert(all(combined.Passed) && ~any(combined.Failed) && ~any(combined.Incomplete),"E3AX:TestsFailed","Revisar test_results.csv.");
end
function T=asTable(r)
T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
end
function restore(p,r,d)
path(p);rng(r);cd(d);
end
