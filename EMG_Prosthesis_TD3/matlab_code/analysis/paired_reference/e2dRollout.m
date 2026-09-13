function trace=e2dRollout(base,epsilon,remap)
% Replay del horizonte teacher congelado; no cambia Env, done ni runtime E2A.
n=size(base.reference,1);
trace=struct("q",zeros(n+1,4),"referenceBefore",base.referenceBefore,"reference",base.reference, ...
    "prediction",zeros(n,4),"rawAction",zeros(n,4),"rawHistorical",zeros(n,4), ...
    "effectiveAction",zeros(n,4),"pwm",zeros(n,4),"historicalPwmSameState",zeros(n,4), ...
    "errorBefore",zeros(n,4),"insideDeadband",false(n,4),"reward",zeros(n,1), ...
    "rewardVector",zeros(n,4),"trackingTerm",zeros(n,4),"actionPenalty",zeros(n,4), ...
    "deltaActionPenalty",zeros(n,4),"metadata",base.metadata);
trace.metadata.epsilon=epsilon;trace.q(1,:)=base.q(1,:);previous=zeros(1,4);
for k=1:n
    q=trace.q(k,:);before=encoder2Flex(q)./[4092 2046 1023 2046];
    err=base.referenceBefore(k,:)-before;[raw,historical,inside]=e2dDeadbandAction(err,epsilon);
    [effective,pwm]=remap(raw);[~,historicalPWM]=remap(historical);
    effective=effective';pwm=pwm';
    next=SimController.prosthesis_simulator(q,pwm,.2,.14,plantSource="patternCurveCanonical");
    pred=encoder2Flex(next)./[4092 2046 1023 2046];
    context=struct("flexConverted",base.reference(k,:),"adjustEnc",pred,"prevAction",previous);
    [reward,vector]=trackingMseActionRateReward(context,effective,[]);
    trace.q(k+1,:)=next;trace.prediction(k,:)=pred;
    trace.rawAction(k,:)=raw;trace.rawHistorical(k,:)=historical;trace.insideDeadband(k,:)=inside;
    trace.effectiveAction(k,:)=effective;trace.pwm(k,:)=pwm;trace.historicalPwmSameState(k,:)=historicalPWM';
    trace.errorBefore(k,:)=err;trace.reward(k)=reward;trace.rewardVector(k,:)=vector;
    trace.trackingTerm(k,:)=-(pred-base.reference(k,:)).^2;
    trace.actionPenalty(k,:)=.01*effective.^2;trace.deltaActionPenalty(k,:)=.05*(effective-previous).^2;
    previous=effective;
end
trace.zeroedDirect=trace.historicalPwmSameState~=0 & trace.pwm==0;
trace.zeroedVersusBaseline=base.pwm~=0 & trace.pwm==0;
trace.cycleMask=e2dCycleScan(trace.q,trace.pwm);
end
