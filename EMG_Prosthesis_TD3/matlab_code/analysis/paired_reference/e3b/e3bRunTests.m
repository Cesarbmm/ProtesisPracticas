function summary=e3bRunTests(options)
arguments,options.reusePrevious (1,1) logical=false;end
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));out=fullfile(pr,"e3b_preparation","tests");if ~isfolder(out),mkdir(out);end
oldPath=path;oldRng=rng;oldDir=pwd;c=onCleanup(@() restore(oldPath,oldRng,oldDir)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));cd(root);
if options.reusePrevious
    T=readtable(fullfile(out,"previous_test_results.csv"),TextType="string",Delimiter=",");
    for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end
    assert(height(T)==258 && all(T.Passed));
else
    first=e2cRunTests(outputDir=fullfile(out,"e0p_e2a_e2b_e2c"));assert(first.passed==81);
    T=readtable(fullfile(out,"e0p_e2a_e2b_e2c","test_results.csv"),TextType="string",Delimiter=",");
    for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end
    for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m","testPairedReferenceE2G.m", ...
            "testE3AXInfrastructure.m","testE3AXPlotHelpers.m","testE3AXEvaluationArtifacts.m","testE3AXPostTraining.m","testCAP192Diagnostic.m"]
        T=[T;asTable(runtests(fullfile(root,"tests","paired_reference",file)))]; %#ok<AGROW>
    end
end
assert(height(T)==258);writetable(T,fullfile(out,"previous_test_results.csv"));
N=asTable(runtests(fullfile(root,"tests","paired_reference","testE3BCategorical.m")));
writetable(N,fullfile(out,"new_test_results.csv"));A=[T;N];writetable(A,fullfile(out,"all_test_results.csv"));
summary=struct("previousTests",height(T),"previousPassed",nnz(T.Passed),"newTests",height(N),"newPassed",nnz(N.Passed), ...
    "totalTests",height(A),"passed",nnz(A.Passed),"failed",nnz(A.Failed),"incomplete",nnz(A.Incomplete),"reusedPrevious",options.reusePrevious);
e2cWriteJSON(fullfile(out,"summary.json"),summary);disp(summary);assert(all(A.Passed) && ~any(A.Failed | A.Incomplete),"E3B:Tests","Revisar all_test_results.csv.");
end
function T=asTable(r)
T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
end
function restore(p,r,d),path(p);rng(r);cd(d);end
