function t=e2fRollout(base,H,graphs,remap)
% Oracle privilegiado con teacher futuro, sin guard ni modificación de Env.
n=size(base.reference,1);t=struct("q",zeros(n+1,4),"referenceBefore",base.referenceBefore, ...
    "reference",base.reference,"prediction",zeros(n,4),"rawAction",zeros(n,4), ...
    "effectiveAction",zeros(n,4),"pwm",zeros(n,4),"reward",zeros(n,1), ...
    "rewardVector",zeros(n,4),"trackingTerm",zeros(n,4),"actionPenalty",zeros(n,4), ...
    "deltaActionPenalty",zeros(n,4),"plannedCost",zeros(n,4),"metadata",base.metadata);
t.metadata.controller="ORACLE_H"+H;t.metadata.horizon=H;t.q(1,:)=base.q(1,:);
qi=zeros(1,4);previousIndex=ones(1,4);previous=zeros(1,4);
cache=cell(1,4);for m=1:4,cache{m}=containers.Map('KeyType','char','ValueType','any');end
for m=1:4,qi(m)=find(graphs{m}.q==t.q(1,m),1);end
for k=1:n
    indices=zeros(1,4);pwm=zeros(1,4);next=zeros(1,4);
    for m=1:4
        g=graphs{m};targets=base.reference(k:min(n,k+H-1),m);
        key=[sprintf('%d/%d/',qi(m),previousIndex(m)),reshape(num2hex(targets)',1,[])];
        if isKey(cache{m},key)
            answer=cache{m}(key);indices(m)=answer(1);t.plannedCost(k,m)=answer(2);
        else
            [indices(m),t.plannedCost(k,m)]=e2fOracleAction(g,qi(m),previousIndex(m),targets);
            cache{m}(key)=[indices(m),t.plannedCost(k,m)];
        end
        pwm(m)=g.actions(indices(m));qi(m)=g.next(qi(m),indices(m));next(m)=g.q(qi(m));
    end
    raw=pwm/255;[effective,remapped]=remap(raw);effective=effective';remapped=remapped';
    assert(isequal(remapped,pwm) && isequal(effective,raw),"E2F:RemapMismatch");
    api=SimController.prosthesis_simulator(t.q(k,:),pwm,.2,.14,plantSource="patternCurveCanonical");
    assert(isequal(next,api),"E2F:GraphMismatch");
    pred=encoder2Flex(next)./[4092 2046 1023 2046];
    ctx=struct("flexConverted",base.reference(k,:),"adjustEnc",pred,"prevAction",previous);
    [reward,vector]=trackingMseActionRateReward(ctx,effective,[]);
    t.q(k+1,:)=next;t.prediction(k,:)=pred;t.rawAction(k,:)=raw;t.effectiveAction(k,:)=effective;t.pwm(k,:)=pwm;
    t.reward(k)=reward;t.rewardVector(k,:)=vector;t.trackingTerm(k,:)=-(pred-base.reference(k,:)).^2;
    t.actionPenalty(k,:)=.01*effective.^2;t.deltaActionPenalty(k,:)=.05*(effective-previous).^2;
    previous=effective;previousIndex=indices;
end
end
