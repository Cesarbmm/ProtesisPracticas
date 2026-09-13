function summary=e3dRunRegressionTests(retryFailed)
arguments,retryFailed logical=false;end
% Reusa los tests anteriores, con salidas nuevas y fuentes inalteradas.
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));out=fullfile(pr,"e3d_results","regression_tests");if ~isfolder(out),mkdir(out);end
old=path;prior=struct();if isappdata(0,"configurables_override"),prior=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(old,prior)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3b"),fullfile(pr,"e3c"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
if retryFailed
    T=readtable(fullfile(out,"test_results.csv"),TextType="string",Delimiter=",");for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end
    if ~isfile(fullfile(out,"test_results_initial.csv")),copyfile(fullfile(out,"test_results.csv"),fullfile(out,"test_results_initial.csv"));copyfile(fullfile(out,"summary.json"),fullfile(out,"summary_initial.json"));end
    ix=find(~T.Passed);assert(~isempty(ix) && all(startsWith(T.Name(ix),"testE3CTemporal/")));
    inferenceContext;S=testsuite(fullfile(root,"tests","paired_reference","testE3CTemporal.m"));S=S(ismember(string({S.Name}),T.Name(ix)));
    r=run(S);N=resultTable(r);for k=1:height(N),T(T.Name==N.Name(k),:)=N(k,:);end
    writetable(N,fullfile(out,"corrected_inference_context_retry.csv"));
else
r=e2cRunTests(outputDir=fullfile(out,"e0p_e2a_e2b_e2c"));assert(r.passed==81);
T=readtable(fullfile(out,"e0p_e2a_e2b_e2c","test_results.csv"),TextType="string",Delimiter=",");
for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end
for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m","testPairedReferenceE2G.m", ...
        "testE3AXInfrastructure.m","testE3AXPlotHelpers.m","testE3AXEvaluationArtifacts.m","testE3AXPostTraining.m","testCAP192Diagnostic.m","testE3BCategorical.m","testE3CTemporal.m"]
    if file=="testE3CTemporal.m",inferenceContext;end
    r=runtests(fullfile(root,"tests","paired_reference",file));
    N=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
    T=[T;N]; %#ok<AGROW>
end
end
assert(height(T)==326);writetable(T,fullfile(out,"test_results.csv"));
summary=struct("total",height(T),"passed",nnz(T.Passed),"failed",nnz(T.Failed),"incomplete",nnz(T.Incomplete));
e2cWriteJSON(fullfile(out,"summary.json"),summary);assert(all(T.Passed));
end
function inferenceContext
cfg=e3cConfig;s=load(fullfile(cfg.e3bRun,"config.mat"),"o");o=s.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
end
function T=resultTable(r)
T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
end
function restore(p,o),setConfigurablesOverride(o);path(p);end
