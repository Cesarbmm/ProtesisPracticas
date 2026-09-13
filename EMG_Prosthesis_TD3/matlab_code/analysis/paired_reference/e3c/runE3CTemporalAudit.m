function result=runE3CTemporalAudit(stage)
arguments,stage (1,1) string {mustBeMember(stage,["data","train","evaluate","figures","tests","testsCore","testsArtifacts"])};end
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
oldPath=path;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(oldPath,oldRng,old)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
cfg=e3cConfig;s=load(fullfile(cfg.e3bRun,"config.mat"),"o");o=s.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
e3axAssertEnvContract(configurables());assert(isfile(fullfile(cfg.output,"historical_hashes_before.csv")) && isfile(fullfile(cfg.output,"diagnostic_selection.csv")));
if stage=="data"
    assert(~isfile(fullfile(cfg.output,"supervised_data.mat")));result=e3cBuildData(cfg);
elseif startsWith(stage,"tests")
    suite=testsuite(fullfile(root,"tests","paired_reference","testE3CTemporal.m"));
    graphical=contains(string({suite.Name}),["Compact","Annotated","Viewer"]);
    if stage=="testsCore",suite=suite(~graphical);elseif stage=="testsArtifacts",suite=suite(graphical);end
    r=run(suite);
    T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
    writetable(T,fullfile(cfg.output,stage+"_results.csv"));assert(all(T.Passed));result=T;
else
    a=load(fullfile(cfg.output,"supervised_data.mat"),"D");D=a.D;
    for seed=cfg.seeds
        for kind=["FF","GRU"]
            file=fullfile(cfg.output,kind+"_"+seed,"checkpoints","ProbeEpoch040.mat");
            if stage=="train"
                if isfile(file),fprintf("Probe ya guardado: %s. No reentrenar.\n",file);else,e3cTrainProbe(D,cfg,kind,seed,o);end
            elseif stage=="evaluate"
                assert(isfile(file));e3cEvaluateProbe(file,D,cfg);
            elseif stage=="figures"
                assert(isfile(file));e3cCreateFigures(file,D,cfg);
            end
        end
    end
    result=struct("stage",stage,"completed",true,"RLTrainingExecuted",false);
end
end
function restore(p,r,o),setConfigurablesOverride(o);rng(r);path(p);end
