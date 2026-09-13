function trace=e2eRollout(base,enabled,remap)
% P privilegiado separado del guard; mismo horizonte teacher y planta histórica.
n=size(base.reference,1);
trace=struct("q",zeros(n+1,4),"referenceBefore",base.referenceBefore,"reference",base.reference, ...
    "prediction",zeros(n,4),"rawAction",zeros(n,4),"desiredEffectiveAction",zeros(n,4), ...
    "desiredPwm",zeros(n,4),"previousAppliedPwm",zeros(n,4),"pendingBefore",zeros(n,4), ...
    "pendingAfter",zeros(n,4),"effectiveAction",zeros(n,4),"pwm",zeros(n,4), ...
    "request",false(n,4),"neutralized",false(n,4),"confirmed",false(n,4),"cancelled",false(n,4), ...
    "errorBefore",zeros(n,4),"reward",zeros(n,1),"rewardVector",zeros(n,4), ...
    "trackingTerm",zeros(n,4),"actionPenalty",zeros(n,4),"deltaActionPenalty",zeros(n,4), ...
    "metadata",base.metadata);
trace.metadata.guardEnabled=logical(enabled);trace.q(1,:)=base.q(1,:);
previous=zeros(1,4);previousPwm=zeros(1,4);pending=zeros(1,4);
for k=1:n
    q=trace.q(k,:);before=encoder2Flex(q)./[4092 2046 1023 2046];
    err=base.referenceBefore(k,:)-before;raw=min(max(2*err,-1),1);
    [desiredEffective,desired]=remap(raw);desired=desired';desiredEffective=desiredEffective';
    [applied,pendingNext,event]=e2eReversalGuard(desired,previousPwm,pending,enabled);
    effective=applied/255;
    next=SimController.prosthesis_simulator(q,applied,.2,.14,plantSource="patternCurveCanonical");
    pred=encoder2Flex(next)./[4092 2046 1023 2046];
    context=struct("flexConverted",base.reference(k,:),"adjustEnc",pred,"prevAction",previous);
    [reward,vector]=trackingMseActionRateReward(context,effective,[]);
    trace.q(k+1,:)=next;trace.prediction(k,:)=pred;trace.rawAction(k,:)=raw;
    trace.desiredEffectiveAction(k,:)=desiredEffective;trace.desiredPwm(k,:)=desired;
    trace.previousAppliedPwm(k,:)=previousPwm;trace.pendingBefore(k,:)=pending;trace.pendingAfter(k,:)=pendingNext;
    trace.effectiveAction(k,:)=effective;trace.pwm(k,:)=applied;
    for f=["request","neutralized","confirmed","cancelled"],trace.(f)(k,:)=event.(f);end
    trace.errorBefore(k,:)=err;trace.reward(k)=reward;trace.rewardVector(k,:)=vector;
    trace.trackingTerm(k,:)=-(pred-base.reference(k,:)).^2;
    trace.actionPenalty(k,:)=.01*effective.^2;trace.deltaActionPenalty(k,:)=.05*(effective-previous).^2;
    previous=effective;previousPwm=applied;pending=pendingNext;
end
trace.cycleMask=e2dCycleScan(trace.q,trace.pwm);
end
