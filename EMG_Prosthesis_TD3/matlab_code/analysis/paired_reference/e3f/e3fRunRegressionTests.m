function summary=e3fRunRegressionTests()
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
out=fullfile(pr,"e3f_results","regression_tests");if ~isfolder(out),mkdir(out);end
old=path;prior=struct();if isappdata(0,"configurables_override"),prior=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(old,prior)); %#ok<NASGU>

addpath(root,pr,here,fullfile(pr,"e3e"),fullfile(pr,"e3d"),fullfile(pr,"e3c"),fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));

% 1. Regresiones previas (81 tests e0p_e2a_e2b_e2c)
r=e2cRunTests(outputDir=fullfile(out,"e0p_e2a_e2b_e2c"));assert(r.passed==81);
T=readtable(fullfile(out,"e0p_e2a_e2b_e2c","test_results.csv"),TextType="string",Delimiter=",");
for f=["Passed","Failed","Incomplete"],T.(f)=logical(T.(f));end

% 2. Suites intermedias
for file=["testPairedReferenceE2D.m","testPairedReferenceE2E.m","testPairedReferenceE2F.m","testPairedReferenceE2G.m", ...
        "testE3AXInfrastructure.m","testE3AXPlotHelpers.m","testE3AXEvaluationArtifacts.m","testE3AXPostTraining.m", ...
        "testCAP192Diagnostic.m","testE3BCategorical.m","testE3CTemporal.m","testE3DTemporalIntent.m","testE3EDomainAudit.m","testE3FSubjectInvariantPPO.m"]
    if file=="testE3CTemporal.m"
        cfg=e3cConfig;s=load(fullfile(cfg.e3bRun,"config.mat"),"o");o=s.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
    end
    r=runtests(fullfile(root,"tests","paired_reference",file));
    N=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
    T=[T;N]; %#ok<AGROW>
end

writetable(T,fullfile(out,"test_results.csv"));
summary=struct("total",height(T),"passed",nnz(T.Passed),"failed",nnz(T.Failed),"incomplete",nnz(T.Incomplete));
e2cWriteJSON(fullfile(out,"summary.json"),summary);
fprintf("Regresion completa E3F: %d/%d PASS\n",summary.passed,summary.total);
assert(all(T.Passed),"Fallos en la regresion completa.");
end
function restore(p,o),setConfigurablesOverride(o);path(p);end
