function summary=e3cRunRegressionTests
% Reusa los tests anteriores, con salidas nuevas y fuentes inalteradas.
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));out=fullfile(pr,"e3c_results","regression_tests");if ~isfolder(out),mkdir(out);end
old=path;c=onCleanup(@() path(old)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
r=e2cRunTests(outputDir=fullfile(out,"e0p_e2a_e2b_e2c"));assert(r.passed==81);
T=readtable(fullfile(out,"e0p_e2a_e2b_e2c","test_results.csv"),TextType="string",Delimiter=",");
for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end
for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m","testPairedReferenceE2G.m", ...
        "testE3AXInfrastructure.m","testE3AXPlotHelpers.m","testE3AXEvaluationArtifacts.m","testE3AXPostTraining.m","testCAP192Diagnostic.m","testE3BCategorical.m"]
    r=runtests(fullfile(root,"tests","paired_reference",file));
    N=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
    T=[T;N]; %#ok<AGROW>
end
assert(height(T)==294);writetable(T,fullfile(out,"test_results.csv"));
summary=struct("total",height(T),"passed",nnz(T.Passed),"failed",nnz(T.Failed),"incomplete",nnz(T.Incomplete));
e2cWriteJSON(fullfile(out,"summary.json"),summary);assert(all(T.Passed));
end
