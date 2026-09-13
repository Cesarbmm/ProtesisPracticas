function summary=e2gRunTests
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2g_results");
oldPath=path;oldRng=rng;oldDir=pwd;cleanup=onCleanup(@() restore(oldPath,oldRng,oldDir)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"));cd(root);e2gVerifyHistory();
assert(~isappdata(0,"E2DTestOutputDirectory") && ~isappdata(0,"E2ETestOutputDirectory"));
prior=e2cRunTests(outputDir=fullfile(out,"previous_tests"));assert(prior.passed==81);
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(here);
old=readtable(fullfile(out,"previous_tests","test_results.csv"),TextType="string");
for f=["Passed","Failed","Incomplete"],old.(f)=logical(old.(f));end
for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m"]
    r=runtests(fullfile(root,"tests","paired_reference",file));old=[old;asTable(r)]; %#ok<AGROW>
end
assert(height(old)==169);new=asTable(runtests(fullfile(root,"tests","paired_reference","testPairedReferenceE2G.m")));
combined=[old;new];writetable(old,fullfile(out,"previous_test_results.csv"));writetable(combined,fullfile(out,"test_results.csv"));
I=e2gVerifyHistory();writetable(I,fullfile(out,"historical_integrity.csv"));
summary=struct("previousTests",169,"previousPassed",nnz(old.Passed),"newE2GTests",height(new),"newE2GPassed",nnz(new.Passed), ...
    "totalTests",height(combined),"passed",nnz(combined.Passed),"failed",nnz(combined.Failed),"incomplete",nnz(combined.Incomplete), ...
    "historicalFilesProtected",height(I),"historicalFilesUnchanged",all(I.unchanged),"matlabVersion",string(version));
e2cWriteJSON(fullfile(out,"test_summary.json"),summary);disp(summary);
assert(all(combined.Passed) && ~any(combined.Failed) && ~any(combined.Incomplete),"E2G:TestsFailed");
end
function T=asTable(r)
T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
end
function restore(p,r,d)
path(p);rng(r);cd(d);
end
