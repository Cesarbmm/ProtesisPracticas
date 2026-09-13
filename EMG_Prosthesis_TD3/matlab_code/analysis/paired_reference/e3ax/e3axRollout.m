function [trace,runtimeTrace]=e3axRollout(actor,episode)
% Runtime sólo EMG. Teacher se usa DESPUÉS para métricas en horizonte común.
base=episode.base;rt=GloveFreePolicyRuntime(episode.emg,base.q(1,:),purpose="inference");
runtimeTrace=struct("q",rt.q,"state",rt.state',"rawAction",zeros(0,4),"effectiveAction",zeros(0,4),"pwm",zeros(0,4));
while ~rt.exhausted
    a=getAction(actor,{rt.state});if iscell(a),a=cell2mat(a);end
    [s,~,r]=rt.advance(a);runtimeTrace.q(end+1,:)=r.q;runtimeTrace.state(end+1,:)=s';
    runtimeTrace.rawAction(end+1,:)=r.rawAction';runtimeTrace.effectiveAction(end+1,:)=r.effectiveAction';runtimeTrace.pwm(end+1,:)=r.pwm';
    assert(rt.c<=100,"E3AX:RuntimeHorizon");
end
n=size(base.reference,1);assert(size(runtimeTrace.pwm,1)>=n,"E3AX:CommonHorizon");
trace=base;trace.q=runtimeTrace.q(1:n+1,:);trace.rawAction=runtimeTrace.rawAction(1:n,:);trace.effectiveAction=runtimeTrace.effectiveAction(1:n,:);
trace.pwm=runtimeTrace.pwm(1:n,:);trace.prediction=encoder2Flex(trace.q(2:end,:))./[4092 2046 1023 2046];
u=trace.effectiveAction;du=[u(1,:);diff(u)];trace.trackingTerm=-(trace.prediction-trace.reference).^2;
trace.actionPenalty=.01*u.^2;trace.deltaActionPenalty=.05*du.^2;trace.rewardVector=trace.trackingTerm-trace.actionPenalty-trace.deltaActionPenalty;
trace.reward=mean(trace.rewardVector,2);trace.metadata.controller="TD3";trace.metadata.split=episode.split;
runtimeTrace.metadata=trace.metadata;runtimeTrace.termination="EMG_ONLY";runtimeTrace.teacherMetricSteps=n;
end
