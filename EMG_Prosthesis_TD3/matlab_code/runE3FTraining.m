function summary=runE3FTraining(options)
arguments,options.mode (1,1) string {mustBeMember(options.mode,["long","smoke"])}="long";end
root=string(fileparts(mfilename("fullpath")));pr=fullfile(root,"analysis","paired_reference");
if options.mode=="long",assert(usejava('desktop'),"E3F:Desktop","Abrir MATLAB Desktop para la corrida manual.");end
oldPath=path;oldDir=pwd;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(oldPath,oldDir,oldRng,old)); %#ok<NASGU>
addpath(root,pr,fullfile(pr,"e3f"),fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));cd(root);
assert(~contains(lower(string(path)),"sandbox"),"E3F:Path","No agregar sandbox.");
cfg=e3fConfig(options.mode);clearConfigurablesOverride();bc=e3axConfig(options.mode);bc.seed=cfg.seed;o=e3axOverride(bc);setConfigurablesOverride(o);
e3axAssertEnvContract(configurables());
stamp=string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'));id=string(java.util.UUID.randomUUID());out=fullfile(cfg.outputParent,"run_"+stamp+"_"+extractBefore(id,9));
assert(~isfolder(out));mkdir(out);mkdir(fullfile(out,"checkpoints"));diary(fullfile(out,"diary.log"));dc=onCleanup(@() diary('off')); %#ok<NASGU>
save(fullfile(out,"config.mat"),"cfg","o");e2cWriteJSON(fullfile(out,"config.json"),cfg);
e2cWriteJSON(fullfile(out,"split.json"),struct("TRAIN",cfg.trainSubjects,"VALIDATION",cfg.validationSubjects,"SEALED",["MATEO","SANDRA"]));
writematrix(cfg.seed,fullfile(out,"seed.txt"));write(fullfile(out,"STARTED.txt"),"E3F "+cfg.mode+"; PPO Invariante al Sujeto con GRL.");
manifest=pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
manifest.preregistrationSHA256=cap192SHA256(fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E3F_SUBJECT_INVARIANT_PPO.md"));e2cWriteJSON(fullfile(out,"manifest.json"),manifest);
fprintf("PPO invariante al sujeto %s. Salida: %s\n",cfg.mode,out);
monitor=[];if usejava('desktop')
    monitor=trainingProgressMonitor(Metrics=["EpisodeReward","AverageReward","ActorLoss","CriticLoss","SubjectLoss","ValidationMSE"],Info=["Episode","AgentSteps"],XLabel="Agent steps");
    setappdata(0,"E3FTrainingMonitor_"+extractBefore(id,9),monitor);
end
try
    data=e3fLoadData(cfg,out);rng(cfg.seed,'twister');
    [actor,critic,disc]=e3fNetworks(cfg);
    initialActor=actor;initialCritic=critic;initialDisc=disc;
    save(fullfile(out,"initial_networks.mat"),"initialActor","initialCritic","initialDisc");
    opt=struct("iteration",0,"actorAverage",[],"actorSquared",[],"criticAverage",[],"criticSquared",[],"discAverage",[],"discSquared",[]);
    env=e3fTrainingEnv(data.emgs,data.gloves,data.subjectMap);
    state=reset(env);episode=1;completed=0;steps=0;episodeSteps=0;episodeReward=0;
    episodeV0=value(critic,state);logs={};updates={};records=struct([]);buffer=emptyBuffer();episodeDone=false;headGradientMax=zeros(1,4);
    recentRewards=[];recentLengths=[];
    while true
        if ~isempty(monitor) && monitor.Stop,error("E3F:UserStopped","Interrupcion solicitada; checkpoints ya escritos se conservan.");end
        if episodeDone,state=reset(env);episode=episode+1;episodeSteps=0;episodeReward=0;episodeV0=value(critic,state);episodeDone=false;end
        v=value(critic,state);
        [category,lp,entropy]=e3fSample(actor,state);
        [next,reward,done,record]=step(env,category);nv=value(critic,next);
        steps=steps+1;episodeSteps=episodeSteps+1;episodeReward=episodeReward+reward;
        k=numel(buffer.reward)+1;
        buffer.state(:,k)=state;buffer.nextState(:,k)=next;buffer.category(:,k)=category;buffer.subject(k)=record.subject;
        buffer.logp(k)=lp;buffer.value(k)=v;buffer.nextValue(k)=nv;buffer.reward(k)=reward;buffer.done(k)=done;
        buffer.pwm(:,k)=record.pwm;buffer.previousEffective(:,k)=record.previousEffective;buffer.reference(:,k)=record.reference';
        buffer.prediction(:,k)=record.prediction';buffer.qBefore(:,k)=record.qBefore';buffer.qAfter(:,k)=record.q';
        buffer.headEntropy(:,k)=entropy;buffer.step(k)=steps;buffer.episode(k)=episode;buffer.policyVersion(k)=opt.iteration;
        state=next;episodeDone=done;assert(episodeSteps<=cfg.maxSteps,"E3F:Horizon","No truncar silenciosamente el protocolo teacher.");
        if done,completed=completed+1;end
        schedule=e3fSchedule(cfg,steps,completed,done,k);stop=schedule.stop;checkpoint=schedule.checkpoint;
        if done || stop
            recentRewards=[recentRewards episodeReward];recentLengths=[recentLengths episodeSteps];
            keep=max(1,numel(recentRewards)-99):numel(recentRewards);recentRewards=recentRewards(keep);recentLengths=recentLengths(keep);
            row=struct("EpisodeIndex",episode,"EpisodeReward",episodeReward,"AverageReward",mean(recentRewards), ...
                "EpisodeSteps",episodeSteps,"AverageSteps",mean(recentLengths),"EpisodeV0",episodeV0,"TotalAgentSteps",steps, ...
                "TeacherDone",done,"BudgetTruncated",stop && ~done);
            logs{end+1}=row;append(fullfile(out,"training_incremental.csv"),struct2table(row)); %#ok<AGROW>
            if cfg.mode=="smoke" || mod(episode,100)==0,fprintf("Episodio %d; pasos %d; reward %.5f; total %d.\n",episode,episodeSteps,episodeReward,steps);end
        end
        if schedule.update
            assert(numel(unique(buffer.policyVersion))==1,"E3F:OnPolicy","El actor cambio durante la recoleccion.");
            [actor,critic,disc,opt,info]=e3fUpdate(actor,critic,disc,opt,buffer,cfg);
            headGradientMax=max(headGradientMax,info.headGradientMax);
            info.firstStep=buffer.step(1);info.lastStep=steps;info.episode=episode;updates{end+1}=info; %#ok<AGROW>
            append(fullfile(out,"update_stats.csv"),struct2table(info));
            lastRollout=buffer;save(fullfile(out,"last_rollout.mat"),"lastRollout","-v7.3");
            if cfg.mode=="smoke",save(fullfile(out,compose("smoke_rollout_%09d.mat",steps)),"lastRollout","-v7.3");end
            if ~isempty(monitor)
                recordMetrics(monitor,steps,EpisodeReward=episodeReward,AverageReward=mean(recentRewards),ActorLoss=info.actorLoss,CriticLoss=info.criticLoss,SubjectLoss=info.subjectLoss);
                updateInfo(monitor,Episode=episode,AgentSteps=steps);monitor.Progress=100*steps/cfg.maxAgentSteps;
                if cfg.mode=="smoke",monitor.Progress=100*completed/cfg.smokeEpisodes;end
            end
            if checkpoint
                file=e3fCheckpoint(out,actor,critic,disc,opt,cfg,o,steps,episode,done,env,buffer);
                validation=data.evaluation(cellfun(@(e) e.split=="VALIDATION",data.evaluation));
                evalRes=e3fEvaluate(file,validation,fullfile(out,"evaluation","checkpoints",compose("Step%09d",steps)),"E3F_"+steps,false);
                rec=struct("steps",steps,"episode",episode,"mse",evalRes.mse,"reward",evalRes.reward,"checkpoint",file, ...
                    "m3Reversals",evalRes.m3Reversals,"cycles",evalRes.cycles,"periodic",evalRes.periodic,"maxCategoryFraction",max(evalRes.maxCategoryFraction));
                if isempty(records),records=rec;else,records(end+1)=rec;end
                writetable(struct2table(records),fullfile(out,"checkpoint_validation.csv"));
                if ~isempty(monitor),recordMetrics(monitor,steps,ValidationMSE=evalRes.mse);end
            end
            buffer=emptyBuffer();
        end
        if stop,break;end
    end
    trainingStats=struct2table([logs{:}]);updateStats=struct2table([updates{:}]);
    save(fullfile(out,"trainingStats.mat"),"trainingStats","updateStats","-v7.3");
    save(fullfile(out,"updateStats.mat"),"updateStats","-v7.3");

    % Verificacion de aprendizaje
    actorChanged=~isequaln(initialActor.Learnables.Value,actor.Learnables.Value);
    criticChanged=~isequaln(initialCritic.Learnables.Value,critic.Learnables.Value);
    discChanged=~isequaln(initialDisc.Learnables.Value,disc.Learnables.Value);
    encLayers=["emg_fc1","emg_fc2"];
    encInit=initialActor.Learnables.Value(ismember(initialActor.Learnables.Layer,encLayers));
    encFinal=actor.Learnables.Value(ismember(actor.Learnables.Layer,encLayers));
    encoderChanged=~isequaln(encInit,encFinal);

    learning=struct("actorChanged",actorChanged,"criticChanged",criticChanged,"discChanged",discChanged, ...
        "encoderChanged",encoderChanged,"headGradientMax",headGradientMax,"allHeadsReceivedGradient",all(headGradientMax>0),"updates",opt.iteration);
    e2cWriteJSON(fullfile(out,"learning_check.json"),learning);
    assert(actorChanged && criticChanged && discChanged && encoderChanged && all(headGradientMax>0),"E3F:NoLearning","Todos los modulos deben actualizar.");

    write(fullfile(out,"TRAINING_COMPLETED.txt"),"Training guardado; evaluacion final pendiente.");
    e3axExportTrainingStats(trainingStats,out);
    summary=e3fFinalEvaluation(out,cfg,data,records);
    summary.outputDirectory=out;summary.mode=cfg.mode;summary.episodes=episode;summary.completedEpisodes=completed;summary.agentSteps=steps;summary.learning=learning;
    summary.longTrainingStartedByAI=false;summary.referenceContractValidated=false;summary.hardwareAuthorized=false;summary.fullTrainingResumeAvailable=false;
    e2cWriteJSON(fullfile(out,"summary.json"),summary);save(fullfile(out,"summary.mat"),"summary");
    write(fullfile(out,"COMPLETED.txt"),"Evaluacion y figuras verificadas. Informe: "+fullfile(out,"TEST_COMPORTAMENTAL.html"));
    if cfg.mode=="smoke",write(fullfile(pr,"e3f_results","smoke_path.txt"),out);end
    fprintf("PPO invariante al sujeto %s terminado. Informe: %s\n",cfg.mode,fullfile(out,"TEST_COMPORTAMENTAL.html"));disp(summary);
catch ex
    if isfile(fullfile(out,"TRAINING_COMPLETED.txt"))
        e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","FAILED","message",ex.message,"trainingCompleted",true));
    end
    rethrow(ex);
end
end

function b=emptyBuffer()
b=struct("state",zeros(52,0,"single"),"nextState",zeros(52,0,"single"),"category",zeros(4,0,"int32"),"subject",zeros(1,0,"int32"), ...
    "logp",zeros(1,0,"single"),"value",zeros(1,0,"single"),"nextValue",zeros(1,0,"single"),"reward",zeros(1,0,"single"),"done",false(1,0), ...
    "pwm",zeros(4,0,"double"),"previousEffective",zeros(4,0,"double"),"reference",zeros(4,0,"double"),"prediction",zeros(4,0,"double"), ...
    "qBefore",zeros(4,0,"double"),"qAfter",zeros(4,0,"double"),"headEntropy",zeros(4,0,"single"),"step",zeros(1,0,"double"), ...
    "episode",zeros(1,0,"double"),"policyVersion",zeros(1,0,"double"));
end
function v=value(net,state)
v=double(extractdata(forward(net,dlarray(single(state),"CB"))));
end
function restore(p,d,r,o)
setConfigurablesOverride(o);rng(r);cd(d);path(p);
end
function write(file,text)
fid=fopen(file,"w","n","utf-8");assert(fid~=-1,"E3F:FileOpen","No se pudo abrir %s",file);fprintf(fid,"%s\n",text);fclose(fid);
end
function append(file,tbl)
writetable(tbl,file,WriteMode="append",WriteVariableNames=~isfile(file));
end
