function e3dEvaluateProbe(file,D,cfg)
folder=fileparts(fileparts(file));done=fullfile(folder,"EVALUATION_COMPLETED.json");if isfile(done),fprintf("Evaluacion ya completa: %s\n",folder);return;end
a=load(file,"net","kind","seed","saved_actor");before=getLearnableParameters(a.saved_actor);
[P,Y,dir,phase]=e3dImitate(a.net,a.kind,D,false);[T,C]=e3cImitationMetrics(P,Y,D.samples);
writetable(T,fullfile(folder,"imitation_metrics.csv"));writetable(C,fullfile(folder,"imitation_confusions.csv"));
I=e3dIntentMetrics(dir,phase,D.samples);writetable(I,fullfile(folder,"intent_metrics.csv"));
save(fullfile(folder,"imitation.mat"),"P","Y","dir","phase","I","-v7.3");
if a.kind=="TEMPORAL_EMG"
    [Psh,Ysh,dirsh,phasesh]=e3dImitate(a.net,a.kind,D,true);assert(isequal(Ysh,Y));
    [Tsh,Csh]=e3cImitationMetrics(Psh,Y,D.samples);Ish=e3dIntentMetrics(dirsh,phasesh,D.samples);
    writetable(Tsh,fullfile(folder,"shuffled_imitation_metrics.csv"));writetable(Csh,fullfile(folder,"shuffled_confusions.csv"));
    writetable(Ish,fullfile(folder,"shuffled_intent_metrics.csv"));
    save(fullfile(folder,"shuffled_imitation.mat"),"Psh","Y","dirsh","phasesh","Ish","-v7.3");
end
traces=cell(200,1);runtimeTraces=traces;ER={};MR={};CR={};label=a.kind+"_"+a.seed;
for e=1:200
    reset(a.saved_actor);[t,r]=e3axRollout(a.saved_actor,D.episodes{e});n=size(t.pwm,1);
    r.probabilities=a.saved_actor.Probabilities;r.headEntropy=a.saved_actor.Entropies;r.categories=a.saved_actor.Categories;
    t.probabilities=r.probabilities(:,:,1:n);t.headEntropy=r.headEntropy(:,1:n);t.categories=r.categories(:,1:n);
    assert(isequal(e3bCategoryPWM(t.categories)',t.pwm));t.metadata.controller=label;r.metadata.controller=label;
    traces{e}=t;runtimeTraces{e}=r;[mot,met]=e2bControlMetrics(t);md=t.metadata;key=struct("controller",label,"subject",string(md.subject),"repetition",md.repetition,"side",md.side,"steps",n);
    ER{end+1}=merge(key,met);cycle=e2dCycleScan(t.q,t.pwm);
    for m=1:4
        MR{end+1}=merge(key,mot(m)); %#ok<AGROW>
        row=struct("subject",string(md.subject),"row",md.repetition,"side",md.side,"split",D.episodes{e}.split,"motor",m,"steps",n, ...
            "entropy",mean(t.headEntropy(m,:)),"cycles",double(cycle(end,m)),"cycleWindows",sum(cycle(:,m)),"periodic",double(e2fPeriodicTrace(t.q,t.pwm,m,false)>0), ...
            "m3Reversals",double(m==3)*nnz(t.pwm(:,m)>0 & diff(t.q(:,m))<0));
        for cat=1:15,row.("category"+cat)=nnz(t.categories(m,:)==cat);end;CR{end+1}=row; %#ok<AGROW>
    end
    if mod(e,25)==0,fprintf("E3D %s closed-loop %d/200.\n",label,e);end
end
assert(isequaln(before,getLearnableParameters(a.saved_actor)));E=struct2table([ER{:}]);M=struct2table([MR{:}]);C=struct2table([CR{:}]);
save(fullfile(folder,"closed_loop.mat"),"traces","runtimeTraces","-v7.3");writetable(E,fullfile(folder,"episode_metrics.csv"));writetable(M,fullfile(folder,"episode_motor_metrics.csv"));writetable(C,fullfile(folder,"categorical_episode_motor.csv"));
for split=["TRAIN","VALIDATION"]
    allowed=cfg.trainSubjects;if split=="VALIDATION",allowed=cfg.validationSubjects;end
    [macro,subjects,directions,motors,groups]=e2fAggregate(E(ismember(E.subject,allowed),:),M(ismember(M.subject,allowed),:));
    names=["summary","subjects","directions","motors","subject_side"];values={macro,subjects,directions,motors,groups};
    for k=1:numel(names),writetable(values{k},fullfile(folder,split+"_"+names(k)+".csv"));end
end
e2cWriteJSON(done,struct("result","COMPLETE","kind",a.kind,"seed",a.seed,"episodes",200,"runtime","EMG_ONLY","teacherInActor",false,"RLTrainingExecuted",false));
end
function c=merge(a,b),c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end;end
