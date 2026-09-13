function result=e3axEvaluate(checkpoint,episodes,out,label,fullPlots)
% Evalúa copia recargada; protege override/RNG; nunca usa Env de training.
old=getappdata(0,"configurables_override");oldRng=rng;c=onCleanup(@() restore(old,oldRng)); %#ok<NASGU>
o=old;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
variables=whos('-file',checkpoint);
if any(strcmp({variables.name},'saved_actor'))
    a=load(checkpoint,"saved_actor");actor=a.saved_actor;
else
    % Checkpoints smoke anteriores conservados: recuperación sin reentrenar.
    a=load(checkpoint,"saved_agent");actor=getActor(a.saved_agent);
end
clear a;before=getLearnableParameters(actor);
mkdir(out);mkdir(fullfile(out,"metrics"));metricRows={};motorRows={};traces=cell(numel(episodes),1);runtimeTraces=traces;steps={};
for e=1:numel(episodes)
    [t,r]=e3axRollout(actor,episodes{e});t.metadata.controller=label;r.metadata.controller=label;traces{e}=t;runtimeTraces{e}=r;
    [mot,met]=e2bControlMetrics(t);md=t.metadata;key=struct("controller",label,"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",size(t.reference,1));
    metricRows{e}=merge(key,met);for m=1:4,motorRows{end+1}=merge(key,mot(m));end %#ok<AGROW>
    steps{e}=e2fTraceTable(t);
    if mod(e,25)==0 || e==numel(episodes),fprintf("TEST %s: inferencia %d/%d episodios.\n",label,e,numel(episodes));end
end
assert(isequaln(before,getLearnableParameters(actor)),"E3AX:EvaluationLearned");
E=struct2table([metricRows{:}]);M=struct2table([motorRows{:}]);[macro,subjects,directions,motors,groups]=e2fAggregate(E,M);
macro.m3Reversals=sum(cellfun(@(t) nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0),traces));
macro.persistentTwoCycle=sum(E.persistentTwoCycle);
names=["episode_metrics","episode_motor_metrics","summary","subject_summary","direction_summary","motor_summary","subject_side_summary","step_traces"];
values={E,M,macro,subjects,directions,motors,groups,vertcat(steps{:})};
for i=1:numel(names),writetable(values{i},fullfile(out,"metrics",names(i)+".csv"));end
save(fullfile(out,"metrics","trajectories.mat"),"traces","runtimeTraces","-v7.3");
% Primero persistir evidencia numérica; una exportación gráfica fallida no la pierde.
if fullPlots
    for e=1:numel(episodes)
        e3axPlotEpisode(traces{e},fullfile(out,"figures",episodes{e}.split),label);
        if mod(e,25)==0 || e==numel(episodes),fprintf("TEST %s: figuras PNG+FIG %d/%d (4 motores).\n",label,e,numel(episodes));end
    end
end
f=figure(Visible="off",Color="w");tiledlayout(1,2);nexttile;bar(motors.motor,motors.trackingMSE);xlabel("Motor");ylabel("MSE");title(label+" · referencia original");
nexttile;bar(motors.motor,motors.rewardMean);xlabel("Motor");ylabel("Reward medio");title("Evaluación determinista EMG-only");
exportgraphics(f,fullfile(out,"summary.png"),Resolution=120);close(f);
result=struct("checkpoint",checkpoint,"label",label,"reward",macro.rewardMean,"mse",macro.trackingMSE,"episodes",numel(episodes),"output",out, ...
    "actorUnchanged",true,"runtimeTermination","EMG_ONLY","commonHorizonTeacherMetrics",true);
e2cWriteJSON(fullfile(out,"summary.json"),result);
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
function restore(o,r)
setConfigurablesOverride(o);rng(r);
end
