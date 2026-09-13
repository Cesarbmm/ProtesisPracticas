function result=runCAP192Diagnostic
% Diagnostico congelado: 2 checkpoints x OFF/CAP x200. Nunca entrena.
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
oldPath=path;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(oldPath,oldRng,old)); %#ok<NASGU>
addpath(root,pr,fullfile(pr,"e3ax"));addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(genpath(fullfile(root,"lib")));
out=fullfile(pr,"cap192_results");assert(isfile(fullfile(out,"historical_hashes_before.csv")),"CAP192:PreregisterFirst","Primero preregistrar y congelar hashes.");
assert(~isfile(fullfile(out,"measurements.mat")),"CAP192:AlreadyMeasured","No sobrescribir las comparaciones.");
run=fullfile(root,"results","e3ax_long","run_20260908_141321_916_6ebf347b");
saved=load(fullfile(run,"config.mat"),"cfg","o");o=saved.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
e3axVerifyHistory();rng(20260908);
data=e3axLoadData(saved.cfg,out);episodes=data.evaluation;clear data;
assert(numel(episodes)==200);save(fullfile(out,"config.mat"),"saved","o");
e2cWriteJSON(fullfile(out,"config.json"),struct("seed",20260908,"cap",192/255,"episodes",200,"checkpoints",[10000 20000], ...
    "sourceRun",run,"trainingExecuted",false,"preregisteredBoundLimit",.50,"referenceContractValidated",false));
metricRows={};motorRows={};countRows={};replayRows={};prefixRows={};
allTraces=cell(200,4);allRuntime=cell(200,4);labels=["BEST_OFF","BEST_CAP192","LAST_OFF","LAST_CAP192"];
for checkpoint=1:2
    episodeNumber=[10000 20000];kind=["best_checkpoint","last_checkpoint"];
    checkpointFile=fullfile(run,"checkpoints",compose("AgentEpisode%06d.mat",episodeNumber(checkpoint)));
    a=load(checkpointFile,"saved_actor");actor=a.saved_actor;before=getLearnableParameters(actor);clear a;
    original=load(fullfile(run,"evaluation",kind(checkpoint),"metrics","trajectories.mat"));
    for cap=0:1
        col=2*(checkpoint-1)+cap+1;label=labels(col);
        for e=1:200
            [t,r]=cap192Rollout(actor,episodes{e},logical(cap));
            t.metadata.controller=label;r.metadata.controller=label;md=t.metadata;
            if cap==0
                prev=original.traces{e};prevRuntime=original.runtimeTraces{e};
                row=struct("checkpoint",kind(checkpoint),"subject",string(md.subject),"row",md.repetition,"side",md.side);
                for f=["state","rawAction","effectiveAction","pwm","q"]
                    assert(isequal(r.(f),prevRuntime.(f)),"CAP192:OffMismatch","OFF distinto: %s",f);
                    row.(f+"Diff")=max(abs(r.(f)-prevRuntime.(f)),[],"all");
                end
                row.rewardDiff=max(abs(t.reward-prev.reward));assert(row.rewardDiff<=1e-12);
                assert(isequal(t.reference,prev.reference) && isequal(t.referenceBefore,prev.referenceBefore));
                assert(string(md.subject)==string(prev.metadata.subject) && md.repetition==prev.metadata.repetition && md.side==prev.metadata.side);
                replayRows{end+1}=row; %#ok<AGROW>
            end
            allTraces{e,col}=t;allRuntime{e,col}=r;
            [mot,met]=e2bControlMetrics(t);
            key=struct("controller",label,"subject",string(md.subject),"repetition",md.repetition,"side",md.side,"steps",size(t.pwm,1));
            metricRows{end+1}=merge(key,met);for m=1:4,motorRows{end+1}=merge(key,mot(m));end %#ok<AGROW>
            for horizon=["COMMON","EMG_ONLY"]
                v=t;off=allTraces{e,2*(checkpoint-1)+1};
                if horizon=="EMG_ONLY",v=r;off=allRuntime{e,2*(checkpoint-1)+1};end
                c=cap192Counts(v.q,v.pwm,v.desiredRaw,v.rawAction);
                oc=cap192Counts(off.q,off.pwm,off.desiredRaw,off.rawAction);
                masks=e2dCycleScan(v.q,v.pwm);om=e2dCycleScan(off.q,off.pwm);
                for m=1:4
                    cr=struct("controller",label,"subject",string(md.subject),"row",md.repetition,"side",md.side, ...
                        "split",string(episodes{e}.split),"horizon",horizon,"motor",m);
                    for f=string(fieldnames(c))',cr.(f)=double(c.(f)(m));end
                    cr.newFinalCycle=double(c.finalCycles(m) && ~oc.finalCycles(m));
                    cr.newFinalPeriodic=double(c.period(m)>0 && oc.period(m)==0);
                    cr.newCycleWindows=nnz(masks(:,m) & ~om(:,m));
                    countRows{end+1}=cr; %#ok<AGROW>
                    for k=find(masks(:,m))'
                        prefixRows{end+1}=merge(cr,struct("endStep",k,"isFinal",k==size(v.pwm,1),"newVsOff",~om(k,m))); %#ok<AGROW>
                    end
                end
            end
            if mod(e,25)==0,fprintf("CAP192 %s: %d/200 episodios completos.\n",label,e);end
        end
        assert(isequaln(before,getLearnableParameters(actor)),"CAP192:ActorChanged","La evaluacion no permite cambiar pesos.");
        traces=allTraces(:,col);runtimeTraces=allRuntime(:,col);
        dest=fullfile(out,label);mkdir(dest);save(fullfile(dest,"trajectories.mat"),"traces","runtimeTraces","-v7.3");
        steps=cell(200,1);
        for e=1:200
            S=e2fTraceTable(traces{e});t=traces{e};
            % e2fTraceTable es formato largo: una fila por paso/motor.
            S.desiredRaw=reshape(t.desiredRaw,[],1);S.commandRaw=reshape(t.rawAction,[],1);steps{e}=S;
        end
        writetable(vertcat(steps{:}),fullfile(dest,"step_traces.csv"));
    end
end
E=struct2table([metricRows{:}]);M=struct2table([motorRows{:}]);C=struct2table([countRows{:}]);R=struct2table([replayRows{:}]);
writetable(E,fullfile(out,"episode_metrics.csv"));writetable(M,fullfile(out,"episode_motor_metrics.csv"));
writetable(C,fullfile(out,"counts_by_episode_motor.csv"));writetable(R,fullfile(out,"off_reproduction.csv"));
if isempty(prefixRows),P=table();else,P=struct2table([prefixRows{:}]);end
writetable(P,fullfile(out,"cycle_windows.csv"));
save(fullfile(out,"measurements.mat"),"E","M","C","R","P","labels","-v7.3");
result=cap192Summarize(out,saved.cfg);
e3axVerifyHistory();e2cWriteJSON(fullfile(out,"measurement_status.json"),struct("complete",true,"runtimeEpisodes",800,"offReplays",400,"trainingExecuted",false));
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
function restore(p,r,o)
setConfigurablesOverride(o);rng(r);path(p);
end
