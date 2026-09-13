function audit=e3bAuditRun(out)
% Auditoria posterior, exclusivamente inferencia. No escribe en la corrida.
out=string(out);here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
dest=fullfile(pr,"e3b_run_audit");if ~isfolder(dest),mkdir(dest);end
oldPath=path;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(oldPath,oldRng,old)); %#ok<NASGU>
addpath(root,pr,here,fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
saved=load(fullfile(out,"config.mat"),"cfg","o");cfg=saved.cfg;o=saved.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
e3axAssertEnvContract(configurables());assert(cfg.mode=="long" && cfg.seed==20260910 && cfg.maxAgentSteps==1e6);
assert(isequal(cfg.trainSubjects,["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"]));
assert(isequal(cfg.validationSubjects,["JOE","JONATHAN","KHAROL"]));
assert(isequal(cfg.categories,[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255]));
data=e3axLoadData(cfg,dest);assert(numel(data.evaluation)==200);
selection=readtable(fullfile(out,"evaluation_selection.csv"),TextType="string",Delimiter=",");
assert(isequaln(selection,readtable(fullfile(dest,"evaluation_selection.csv"),TextType="string",Delimiter=",")));
training=readtable(fullfile(out,"training_incremental.csv"));updates=readtable(fullfile(out,"update_stats.csv"));
tm=load(fullfile(out,"trainingStats.mat"));um=load(fullfile(out,"updateStats.mat"));
assert(isequal(size(tm.trainingStats),size(training)) && height(um.updateStats)==height(updates));
for f=string(training.Properties.VariableNames)
    assert(max(abs(double(training.(f))-double(tm.trainingStats.(f))))<=1e-9);
end
assert(isequal(training.EpisodeIndex,(1:height(training))') && sum(training.EpisodeSteps)==1e6);
assert(isequal(cumsum(training.EpisodeSteps),training.TotalAgentSteps));
assert(all(training.TeacherDone(1:end-1)) && ~training.TeacherDone(end) && training.BudgetTruncated(end));
assert(nnz(training.BudgetTruncated)==1 && all(isfinite(training{:,:}),"all"));
assert(all(isfinite(updates{:,:}),"all") && all(updates.allFinite));
assert(updates.firstStep(1)==1 && updates.lastStep(end)==1e6);
assert(all(updates.firstStep(2:end)==updates.lastStep(1:end-1)+1));
assert(all(updates.samples==updates.lastStep-updates.firstStep+1) && all(updates.samples<=cfg.rolloutLength));
assert(all(updates.minibatches==cfg.epochs*ceil(updates.samples/cfg.minibatch)));
assert(all(updates{:,"headGradientMax_"+(1:4)}>0,"all"));
R=readtable(fullfile(out,"checkpoint_validation.csv"),TextType="string",Delimiter=",");
assert(isequal(R.steps',cfg.checkpointSteps));classification=e3bClassify(R,cfg);
storedSummary=jsondecode(fileread(fullfile(out,"summary.json")));
assert(classification.classification==string(storedSummary.classification.classification) && classification.bestSteps==storedSummary.bestSteps);
records={};rollouts={};events={};intermediateMatches=0;allRolloutSteps=0;
initial=load(fullfile(out,"initial_networks.mat"));
for ci=1:height(R)
    checkpoint=R.checkpoint(ci);a=load(checkpoint);b=a.rollout;n=numel(b.reward);
    assert(a.checkpointInfo.agentSteps==R.steps(ci) && a.checkpointInfo.episode==R.episode(ci));
    assert(a.checkpointInfo.rolloutUpdatedBeforeSave && ~a.checkpointInfo.fullTrainingResumeAvailable);
    assert(a.optimizer.iteration==sum(updates.minibatches(updates.lastStep<=R.steps(ci))));
    assert(b.step(end)==R.steps(ci) && all(diff(b.step)==1) && numel(unique(b.policyVersion))==1);
    assert(all(isfinite([b.state(:);b.nextState(:);b.logp(:);b.headEntropy(:);b.value(:);b.nextValue(:)])));
    assert(isequal(e3bCategoryPWM(b.category),b.pwm));
    assert(isequal(b.state(49:52,:),b.previousEffective) && isequal(b.nextState(49:52,:),b.pwm/255));
    expectedReward=mean(-(b.prediction-b.reference).^2-.01*(b.pwm/255).^2-.05*(b.pwm/255-b.previousEffective).^2,1);
    assert(difference(expectedReward,b.reward)<=1e-12);
    [adv,ret]=e3bGAE(b.reward,b.value,b.nextValue,b.done,cfg.gamma,cfg.gaeLambda);
    assert(all(isfinite([adv ret])) && abs(ret(end)-(b.reward(end)+cfg.gamma*~b.done(end)*b.nextValue(end)))<1e-12);
    for k=1:n-1
        if ~b.done(k),assert(b.episode(k)==b.episode(k+1) && isequal(b.nextState(:,k),b.state(:,k+1)));end
    end
    assert(~isequaln(initial.initialActor.Learnables.Value,a.saved_actor.Network.Learnables.Value));
    assert(~isequaln(initial.initialCritic.Learnables.Value,a.saved_critic.Learnables.Value));
    allRolloutSteps=allRolloutSteps+n;
    rollouts{end+1}=struct("steps",R.steps(ci),"episode",R.episode(ci),"samples",n,"teacherDoneAtEnd",b.done(end), ...
        "optimizerIterations",a.optimizer.iteration,"rewardDiff",difference(expectedReward,b.reward),"pass",true); %#ok<AGROW>
    fullKind="";if R.steps(ci)==storedSummary.bestSteps,fullKind="best_checkpoint";elseif R.steps(ci)==storedSummary.lastSteps,fullKind="last_checkpoint";end
    intermediate=fullfile(out,"evaluation","checkpoints",compose("Step%09d",R.steps(ci)));
    if fullKind=="",folder=intermediate;episodes=data.evaluation(cellfun(@(e) e.split=="VALIDATION",data.evaluation));
    else,folder=fullfile(out,"evaluation",fullKind);episodes=data.evaluation;end
    original=load(fullfile(folder,"metrics","trajectories.mat"));assert(numel(original.traces)==numel(episodes));
    E=readtable(fullfile(folder,"metrics","episode_metrics.csv"),TextType="string",Delimiter=",");
    M=readtable(fullfile(folder,"metrics","episode_motor_metrics.csv"),TextType="string",Delimiter=",");
    D=readtable(fullfile(folder,"metrics","categorical_episode_motor.csv"),TextType="string",Delimiter=",");
    before=getLearnableParameters(a.saved_actor);
    for e=1:numel(episodes)
        [t,r]=e3axRollout(a.saved_actor,episodes{e});prev=original.traces{e};prv=original.runtimeTraces{e};md=t.metadata;
        assert(string(md.subject)==string(prev.metadata.subject) && md.repetition==prev.metadata.repetition && md.side==prev.metadata.side);
        assert(isequal(t.reference,prev.reference) && isequal(t.referenceBefore,prev.referenceBefore));
        [mot,met]=e2bControlMetrics(t);ei=E.subject==string(md.subject) & E.repetition==md.repetition & E.side==md.side;assert(nnz(ei)==1);
        metricDiff=metricDifference(met,E(ei,:));N=size(t.pwm,1);[p,h]=a.saved_actor.distribution(r.state(1:N,:)');
        [~,cats]=max(p,[],1);cats=reshape(cats,4,[]);assert(isequal(e3bCategoryPWM(cats)',t.pwm));
        cycle=e2dCycleScan(t.q,t.pwm);
        for m=1:4
            mi=M.subject==string(md.subject) & M.repetition==md.repetition & M.side==md.side & M.motor==m;assert(nnz(mi)==1);
            metricDiff=max(metricDiff,metricDifference(mot(m),M(mi,:)));
            di=D.subject==string(md.subject) & D.row==md.repetition & D.side==md.side & D.motor==m;assert(nnz(di)==1);
            measured=struct("headEntropy",mean(h(m,:)),"fraction255",mean(abs(t.pwm(:,m))==255), ...
                "cycles",double(cycle(end,m)),"cycleWindows",sum(cycle(:,m)),"periodic",double(e2fPeriodicTrace(t.q,t.pwm,m,false)>0), ...
                "m3Reversals",double(m==3)*nnz(t.pwm(:,m)>0 & diff(t.q(:,m))<0));
            for category=1:15,measured.("category"+category)=nnz(cats(m,:)==category);end
            metricDiff=max(metricDiff,metricDifference(measured,D(di,:)));
        end
        row=struct("steps",R.steps(ci),"split",string(md.split),"subject",string(md.subject),"row",md.repetition,"side",md.side, ...
            "stateDiff",difference(r.state,prv.state),"rawDiff",difference(r.rawAction,prv.rawAction),"effectiveDiff",difference(r.effectiveAction,prv.effectiveAction), ...
            "pwmDiff",difference(r.pwm,prv.pwm),"qDiff",difference(r.q,prv.q),"rewardDiff",difference(t.reward,prev.reward),"metricsCsvDiff",metricDiff, ...
            "teacherSteps",N,"emgOnlySteps",size(r.pwm,1),"m3Reversals",nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0));
        assert(max([row.stateDiff row.rawDiff row.effectiveDiff row.pwmDiff row.qDiff])==0 && row.rewardDiff<=1e-12 && metricDiff<=1e-9);
        assert(r.termination=="EMG_ONLY" && isequal(r.state(2:end,49:52),r.effectiveAction));
        records{end+1}=row; %#ok<AGROW>
        for k=find(t.pwm(:,3)>0 & diff(t.q(:,3))<0)'
            events{end+1}=struct("checkpointSteps",R.steps(ci),"split",string(md.split),"subject",string(md.subject),"row",md.repetition,"side",md.side, ...
                "step",k,"pwm",t.pwm(k,3),"qBefore",t.q(k,3),"qAfter",t.q(k+1,3),"deltaQ",t.q(k+1,3)-t.q(k,3)); %#ok<AGROW>
        end
        if mod(e,25)==0 || e==numel(episodes),fprintf("AUDITORIA %d pasos: %d/%d replays exactos.\n",R.steps(ci),e,numel(episodes));end
    end
    assert(isequaln(before,getLearnableParameters(a.saved_actor)));
    if fullKind~=""
        partial=load(fullfile(intermediate,"metrics","trajectories.mat"));val=find(cellfun(@(e) e.split=="VALIDATION",episodes));
        assert(numel(val)==60 && numel(partial.traces)==60);
        for j=1:60
            for field=["q","state","rawAction","effectiveAction","pwm"]
                assert(isequal(partial.runtimeTraces{j}.(field),original.runtimeTraces{val(j)}.(field)));
            end
            assert(isequal(partial.traces{j}.reward,original.traces{val(j)}.reward));intermediateMatches=intermediateMatches+1;
        end
    end
end
Rplays=struct2table([records{:}]);writetable(Rplays,fullfile(dest,"deterministic_replay.csv"));
writetable(struct2table([rollouts{:}]),fullfile(dest,"checkpoint_rollout_audit.csv"));
writetable(struct2table([events{:}]),fullfile(dest,"m3_reversal_events.csv"));
inventory=e3axCheckEvaluationFiles(out);writetable(inventory,fullfile(dest,"verified_figures.csv"));
audit=struct("result","PASS","episodesReplayed",height(Rplays),"intermediateFinalValidationMatches",intermediateMatches, ...
    "maxStateDiff",max(Rplays.stateDiff),"maxRawDiff",max(Rplays.rawDiff),"maxEffectiveDiff",max(Rplays.effectiveDiff), ...
    "maxPwmDiff",max(Rplays.pwmDiff),"maxQDiff",max(Rplays.qDiff),"maxRewardDiff",max(Rplays.rewardDiff), ...
    "maxMetricsCsvDiff",max(Rplays.metricsCsvDiff),"metricsCsvTolerance",1e-9,"checkpointRolloutTransitionsAudited",allRolloutSteps, ...
    "agentSteps",sum(training.EpisodeSteps),"episodesStarted",height(training),"teacherCompletedEpisodes",nnz(training.TeacherDone), ...
    "budgetTruncatedEpisodes",nnz(training.BudgetTruncated),"rollouts",height(updates),"optimizerUpdates",sum(updates.minibatches), ...
    "verifiedPNG",height(inventory),"verifiedFIG",height(inventory),"classification",classification, ...
    "trainingExecuted",false,"finalTestExecuted",false,"MATEO_SANDRA_SEALED",true);
e2cWriteJSON(fullfile(dest,"replay_summary.json"),audit);disp(audit);
end
function d=difference(a,b)
assert(isequal(size(a),size(b)));d=max(abs(a-b),[],'all');
end
function d=metricDifference(values,row)
d=0;for f=string(fieldnames(values))'
    a=values.(f);b=row.(f);assert(isequal(isnan(a),isnan(b)));if ~isnan(a),d=max(d,abs(a-b));end
end
end
function restore(p,r,o)
setConfigurablesOverride(o);rng(r);path(p);
end
