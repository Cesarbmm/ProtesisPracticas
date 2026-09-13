function summary=runE3BCategoricalTraining(options)
% Comando manual. La IA ejecuta exclusivamente mode="smoke".
arguments,options.mode (1,1) string {mustBeMember(options.mode,["long","smoke"])}="long";end
root=string(fileparts(mfilename("fullpath")));pr=fullfile(root,"analysis","paired_reference");
if options.mode=="long",assert(usejava('desktop'),"E3B:Desktop","Abrir MATLAB Desktop para la corrida manual.");end
oldPath=path;oldDir=pwd;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(oldPath,oldDir,oldRng,old)); %#ok<NASGU>
addpath(root,pr,fullfile(pr,"e3ax"),fullfile(pr,"e3b"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));cd(root);
assert(~contains(lower(string(path)),"sandbox"),"E3B:Path","No agregar sandbox.");
cfg=e3bConfig(options.mode);clearConfigurablesOverride();bc=e3axConfig(options.mode);bc.seed=cfg.seed;o=e3axOverride(bc);setConfigurablesOverride(o);
e3axAssertEnvContract(configurables());e3axVerifyHistory();
stamp=string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'));id=string(java.util.UUID.randomUUID());out=fullfile(cfg.outputParent,"run_"+stamp+"_"+extractBefore(id,9));
assert(~isfolder(out));mkdir(out);mkdir(fullfile(out,"checkpoints"));diary(fullfile(out,"diary.log"));dc=onCleanup(@() diary('off')); %#ok<NASGU>
save(fullfile(out,"config.mat"),"cfg","o");e2cWriteJSON(fullfile(out,"config.json"),cfg);
e2cWriteJSON(fullfile(out,"split.json"),struct("TRAIN",cfg.trainSubjects,"VALIDATION",cfg.validationSubjects,"SEALED",["MATEO","SANDRA"]));
writematrix(cfg.seed,fullfile(out,"seed.txt"));write(fullfile(out,"STARTED.txt"),"E3B "+cfg.mode+"; referencia ORIGINAL no validada.");
manifest=pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
manifest.preregistrationSHA256=cap192SHA256(fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E3B_CATEGORICAL.md"));e2cWriteJSON(fullfile(out,"manifest.json"),manifest);
fprintf("PPO categórico %s. Salida: %s\n",cfg.mode,out);
monitor=[];if usejava('desktop')
    monitor=trainingProgressMonitor(Metrics=["EpisodeReward","AverageReward","ActorLoss","CriticLoss","ValidationMSE"],Info=["Episode","AgentSteps"],XLabel="Agent steps");
    setappdata(0,"E3BTrainingMonitor_"+extractBefore(id,9),monitor); % Mantener ventana al retornar.
end
try
    data=e3axLoadData(cfg,out);rng(cfg.seed,'twister');[actor,critic]=e3bNetworks(cfg);initialActor=actor;initialCritic=critic;
    save(fullfile(out,"initial_networks.mat"),"initialActor","initialCritic");
    opt=struct("iteration",0,"actorAverage",[],"actorSquared",[],"criticAverage",[],"criticSquared",[]);
    env=E3BTrainingEnv(data.emgs,data.gloves);state=reset(env);episode=1;completed=0;steps=0;episodeSteps=0;episodeReward=0;
    episodeV0=value(critic,state);logs={};updates={};records=struct([]);buffer=emptyBuffer();episodeDone=false;headGradientMax=zeros(1,4);
    recentRewards=[];recentLengths=[];
    while true
        if ~isempty(monitor) && monitor.Stop,error("E3B:UserStopped","Interrupcion solicitada; checkpoints ya escritos se conservan.");end
        if episodeDone,state=reset(env);episode=episode+1;episodeSteps=0;episodeReward=0;episodeV0=value(critic,state);episodeDone=false;end
        v=value(critic,state);[category,lp,entropy]=e3bSample(actor,state);
        [next,reward,done,record]=step(env,category);nv=value(critic,next);
        steps=steps+1;episodeSteps=episodeSteps+1;episodeReward=episodeReward+reward;
        k=numel(buffer.reward)+1;buffer.state(:,k)=state;buffer.nextState(:,k)=next;buffer.category(:,k)=category;
        buffer.logp(k)=lp;buffer.value(k)=v;buffer.nextValue(k)=nv;buffer.reward(k)=reward;buffer.done(k)=done;
        buffer.pwm(:,k)=record.pwm;buffer.previousEffective(:,k)=record.previousEffective;buffer.reference(:,k)=record.reference';
        buffer.prediction(:,k)=record.prediction';buffer.qBefore(:,k)=record.qBefore';buffer.qAfter(:,k)=record.q';
        buffer.headEntropy(:,k)=entropy;buffer.step(k)=steps;buffer.episode(k)=episode;buffer.policyVersion(k)=opt.iteration;
        state=next;episodeDone=done;assert(episodeSteps<=cfg.maxSteps,"E3B:Horizon","No truncar silenciosamente el protocolo teacher.");
        if done,completed=completed+1;end
        schedule=e3bSchedule(cfg,steps,completed,done,k);stop=schedule.stop;checkpoint=schedule.checkpoint;
        if done || stop
            recentRewards=[recentRewards episodeReward];recentLengths=[recentLengths episodeSteps];
            keep=max(1,numel(recentRewards)-99):numel(recentRewards);recentRewards=recentRewards(keep);recentLengths=recentLengths(keep);
            row=struct("EpisodeIndex",episode,"EpisodeReward",episodeReward,"AverageReward",mean(recentRewards), ...
                "EpisodeSteps",episodeSteps,"AverageSteps",mean(recentLengths),"EpisodeV0",episodeV0,"TotalAgentSteps",steps, ...
                "TeacherDone",done,"BudgetTruncated",stop && ~done);
            logs{end+1}=row;append(fullfile(out,"training_incremental.csv"),struct2table(row)); %#ok<AGROW>
            if cfg.mode=="smoke" || mod(episode,100)==0,fprintf("Episodio%d; pasos%d; reward%.5f; total%d.\n",episode,episodeSteps,episodeReward,steps);end
        end
        if schedule.update
            assert(numel(unique(buffer.policyVersion))==1,"E3B:OnPolicy","El actor cambio durante la recoleccion.");
            [actor,critic,opt,info]=e3bUpdate(actor,critic,opt,buffer,cfg);headGradientMax=max(headGradientMax,info.headGradientMax);
            info.firstStep=buffer.step(1);info.lastStep=steps;info.episode=episode;updates{end+1}=info; %#ok<AGROW>
            append(fullfile(out,"update_stats.csv"),struct2table(info));
            lastRollout=buffer;save(fullfile(out,"last_rollout.mat"),"lastRollout","-v7.3");
            if cfg.mode=="smoke",save(fullfile(out,compose("smoke_rollout_%09d.mat",steps)),"lastRollout","-v7.3");end
            if ~isempty(monitor)
                recordMetrics(monitor,steps,EpisodeReward=episodeReward,AverageReward=mean(recentRewards),ActorLoss=info.actorLoss,CriticLoss=info.criticLoss);
                updateInfo(monitor,Episode=episode,AgentSteps=steps);monitor.Progress=100*steps/cfg.maxAgentSteps;
                if cfg.mode=="smoke",monitor.Progress=100*completed/cfg.smokeEpisodes;end
            end
            if checkpoint
                file=e3bCheckpoint(out,actor,critic,opt,cfg,o,steps,episode,done,env,buffer);
                validation=data.evaluation(cellfun(@(e) e.split=="VALIDATION",data.evaluation));
                evaluation=e3bEvaluate(file,validation,fullfile(out,"evaluation","checkpoints",compose("Step%09d",steps)),"Categorical_"+steps,false);
                rec=struct("steps",steps,"episode",episode,"mse",evaluation.mse,"reward",evaluation.reward,"checkpoint",file, ...
                    "m3Reversals",evaluation.m3Reversals,"cycles",evaluation.cycles,"periodic",evaluation.periodic,"maxCategoryFraction",max(evaluation.maxCategoryFraction));
                if isempty(records),records=rec;else,records(end+1)=rec;end
                writetable(struct2table(records),fullfile(out,"checkpoint_validation.csv"));
                if ~isempty(monitor),recordMetrics(monitor,steps,ValidationMSE=evaluation.mse);end
            end
            buffer=emptyBuffer();
        end
        if stop,break;end
    end
    trainingStats=struct2table([logs{:}]);updateStats=struct2table([updates{:}]);save(fullfile(out,"trainingStats.mat"),"trainingStats","updateStats","-v7.3");
    save(fullfile(out,"updateStats.mat"),"updateStats","-v7.3"); % El exportador historico reescribe trainingStats.mat.
    learning=struct("actorChanged",~isequaln(initialActor.Learnables.Value,actor.Learnables.Value), ...
        "criticChanged",~isequaln(initialCritic.Learnables.Value,critic.Learnables.Value),"headGradientMax",headGradientMax,"allHeadsReceivedGradient",all(headGradientMax>0),"updates",opt.iteration);
    e2cWriteJSON(fullfile(out,"learning_check.json"),learning);
    assert(learning.actorChanged && learning.criticChanged && learning.allHeadsReceivedGradient,"E3B:NoLearning","El smoke/loop debe actualizar las cuatro cabezas y critic.");
    write(fullfile(out,"TRAINING_COMPLETED.txt"),"Training guardado; evaluacion final pendiente.");
    e3axExportTrainingStats(trainingStats,out);summary=e3bFinalEvaluation(out,cfg,data,records);
    summary.outputDirectory=out;summary.mode=cfg.mode;summary.episodes=episode;summary.completedEpisodes=completed;summary.agentSteps=steps;summary.learning=learning;
    summary.longTrainingStartedByAI=false;summary.referenceContractValidated=false;summary.hardwareAuthorized=false;summary.fullTrainingResumeAvailable=false;
    e2cWriteJSON(fullfile(out,"summary.json"),summary);save(fullfile(out,"summary.mat"),"summary");
    write(fullfile(out,"COMPLETED.txt"),"Evaluacion y figuras verificadas. Informe: "+fullfile(out,"TEST_COMPORTAMENTAL.html"));
    if cfg.mode=="smoke",write(fullfile(pr,"e3b_preparation","smoke_path.txt"),out);end
    fprintf("PPO %s terminado. Informe: %s\n",cfg.mode,fullfile(out,"TEST_COMPORTAMENTAL.html"));disp(summary);
catch ex
    if isfile(fullfile(out,"TRAINING_COMPLETED.txt"))
        e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","FAILED","message",ex.message, ...
            "recoveryCommand","runE3BPostTraining('"+out+"')","trainingCompleted",true));
        fprintf("Training guardado; recuperar evaluacion sin entrenar: runE3BPostTraining('%s')\n",out);
    end
    write(fullfile(out,"FAILED.txt"),string(getReport(ex,'extended','hyperlinks','off')));rethrow(ex);
end
end
function b=emptyBuffer
b=struct("state",zeros(52,0),"nextState",zeros(52,0),"category",zeros(4,0),"logp",zeros(1,0), ...
    "value",zeros(1,0),"nextValue",zeros(1,0),"reward",zeros(1,0),"done",false(1,0),"pwm",zeros(4,0), ...
    "previousEffective",zeros(4,0),"reference",zeros(4,0),"prediction",zeros(4,0),"qBefore",zeros(4,0),"qAfter",zeros(4,0), ...
    "headEntropy",zeros(4,0),"step",zeros(1,0),"episode",zeros(1,0),"policyVersion",zeros(1,0));
end
function v=value(net,s)
v=double(extractdata(forward(net,dlarray(single(s),"CB"))));assert(isfinite(v),"E3B:Value","Valor no finito.");
end
function append(file,T)
if isfile(file),writetable(T,file,WriteMode="append",WriteVariableNames=false);else,writetable(T,file);end
end
function write(file,s)
f=fopen(file,'w','n','UTF-8');assert(f>=0);c=onCleanup(@() fclose(f));fprintf(f,'%s',s); %#ok<NASGU>
end
function restore(p,d,r,o)
setConfigurablesOverride(o);rng(r);cd(d);path(p);
end
