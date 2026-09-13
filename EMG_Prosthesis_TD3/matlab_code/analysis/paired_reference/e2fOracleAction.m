function [actionIndex,value,planned]=e2fOracleAction(graph,qIndex,previousIndex,targets)
% Bellman exacto en (q,accion previa), horizonte finito, sin descuento.
% Empates exactos: primer indice del orden de acciones preregistrado.
arguments
    graph struct
    qIndex (1,1) double {mustBeInteger,mustBePositive}
    previousIndex (1,1) double {mustBeInteger,mustBePositive}
    targets (:,1) double {mustBeFinite}
end
n=numel(graph.q);a=graph.actions/255;na=numel(a);H=numel(targets);
assert(H>=1 && H<=5,"E2F:OracleHorizon");
assert(qIndex<=n && previousIndex<=na,"E2F:OracleStateIndex");
assert(isequal(size(graph.next),[n na]),"E2F:OracleGraphShape");
assert(all(graph.next>=1 & graph.next<=n,"all"),"E2F:GraphNotClosed");
V=zeros(n,na);policies=cell(H,1);
% Sólo capas alcanzables desde la raíz; exacto, sin poda por coste ni beam.
reachable=cell(H,1);reachable{1}=qIndex;
for k=2:H,reachable{k}=unique(graph.next(reachable{k-1},:));end
rate=.05*(a(:)-a).^2;
for k=H:-1:1
    states=reachable{k};destinations=graph.next(states,:);
    futureIndices=destinations+(0:na-1)*n;hNext=reshape(graph.h(destinations),size(destinations));
    costs=(hNext-targets(k)).^2+.01*a.^2+V(futureIndices);
    nextV=zeros(n,na);policy=zeros(n,na);
    for previous=1:na
        [nextV(states,previous),policy(states,previous)]=min(costs+rate(previous,:),[],2);
    end
    V=nextV;policies{k}=policy;
end
actionIndex=policies{1}(qIndex,previousIndex);value=V(qIndex,previousIndex);
if nargout>2
    planned=struct("actionIndices",zeros(H,1),"pwm",zeros(H,1), ...
        "qIndices",zeros(H+1,1),"stageCosts",zeros(H,1),"totalCost",value);
    planned.qIndices(1)=qIndex;state=qIndex;previous=previousIndex;
    for k=1:H
        ai=policies{k}(state,previous);destination=graph.next(state,ai);
        planned.actionIndices(k)=ai;planned.pwm(k)=graph.actions(ai);
        planned.qIndices(k+1)=destination;
        planned.stageCosts(k)=(graph.h(destination)-targets(k))^2+.01*a(ai)^2+ ...
            .05*(a(ai)-a(previous))^2;
        state=destination;previous=ai;
    end
end
end
