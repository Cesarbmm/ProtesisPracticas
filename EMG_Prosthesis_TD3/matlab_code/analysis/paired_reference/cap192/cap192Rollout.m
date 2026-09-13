function [t,r]=cap192Rollout(actor,episode,enabled)
% Teacher se lee para metricas DESPUES de terminar la ejecucion solo EMG.
r=cap192Runtime(actor,episode.emg,episode.base.q(1,:),enabled);
t=episode.base;n=size(t.reference,1);assert(size(r.pwm,1)>=n,"CAP192:CommonHorizon","Falta horizonte comun con teacher.");
t.q=r.q(1:n+1,:);t.rawAction=r.rawAction(1:n,:);t.desiredRaw=r.desiredRaw(1:n,:);
t.commandRaw=t.rawAction;t.effectiveAction=r.effectiveAction(1:n,:);t.pwm=r.pwm(1:n,:);
t.prediction=encoder2Flex(t.q(2:end,:))./[4092 2046 1023 2046];
u=t.effectiveAction;du=[u(1,:);diff(u)];t.trackingTerm=-(t.prediction-t.reference).^2;
t.actionPenalty=.01*u.^2;t.deltaActionPenalty=.05*du.^2;
t.rewardVector=t.trackingTerm-t.actionPenalty-t.deltaActionPenalty;t.reward=mean(t.rewardVector,2);
t.metadata.split=episode.split;r.metadata=t.metadata;r.teacherMetricSteps=n;
end
