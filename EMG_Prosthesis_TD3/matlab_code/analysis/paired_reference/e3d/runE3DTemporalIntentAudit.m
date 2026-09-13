function result=runE3DTemporalIntentAudit(stage)
arguments,stage (1,1) string {mustBeMember(stage,["preflight","train","evaluate","figures","tests","testsCore","testsArtifacts"])};end
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
oldPath=path;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(oldPath,oldRng,old)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3c"),fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
cfg=e3dConfig;s=load(fullfile(cfg.e3bRun,"config.mat"),"o");o=s.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
e3axAssertEnvContract(configurables());assert(isfile(fullfile(cfg.output,"historical_hashes_before.csv")));
a=load(fullfile(pr,"e3c_results","supervised_data.mat"),"D");D=a.D;
if stage=="preflight"
    assert(isequal(cfg.seeds,[20260923 20260924 20260925]));
    ids=find(D.samples.split=="TRAIN" & D.samples.length==8,3);
    for kind=cfg.models
        rng(cfg.seeds(1));net=e3dNetwork(kind);[X,M,Y,labels]=e3dBatch(D,ids,kind);
        [loss,g,parts]=dlfeval(@e3dLoss,net,X,M,Y,labels);assert(all(isfinite(extractdata(parts))));
        assert(all(cellfun(@(x) all(isfinite(extractdata(x)),"all"),g.Value)));disp([kind,string(double(extractdata(loss)))]);
        actor=E3DProbeActor(net,kind);getAction(actor,{D.sequences{1}.state(:,1)});reset(actor);assert(isempty(actor.EMGHistory));
    end
    e2cWriteJSON(fullfile(cfg.output,"preflight.json"),struct("result","PASS","validationMeasured",false,"trainingExecuted",false));result=true;
elseif startsWith(stage,"tests")
    suite=testsuite(fullfile(root,"tests","paired_reference","testE3DTemporalIntent.m"));
    graphical=contains(string({suite.Name}),["Compact","Annotated","Viewer"]);
    if stage=="testsCore",suite=suite(~graphical);elseif stage=="testsArtifacts",suite=suite(graphical);end
    r=run(suite);T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
    writetable(T,fullfile(cfg.output,stage+"_results.csv"));assert(all(T.Passed));result=T;
else
    for seed=cfg.seeds
        for kind=cfg.models
            file=fullfile(cfg.output,kind+"_"+seed,"checkpoints","ProbeEpoch040.mat");
            if stage=="train"
                if isfile(file),fprintf("Probe existente; no reentrenar: %s\n",file);else,e3dTrainProbe(D,cfg,kind,seed,o);end
            elseif stage=="evaluate",assert(isfile(file));e3dEvaluateProbe(file,D,cfg);
            elseif stage=="figures",assert(isfile(file));e3dCreateFigures(file,D,cfg);
            end
        end
    end
    result=struct("stage",stage,"completed",true,"RLTrainingExecuted",false);
end
end
function restore(p,r,o),setConfigurablesOverride(o);rng(r);path(p);end
