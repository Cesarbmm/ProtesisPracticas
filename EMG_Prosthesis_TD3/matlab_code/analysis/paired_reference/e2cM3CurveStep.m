function [next,startIndex]=e2cM3CurveStep(q,curve,limits)
% Evaluador OFFLINE del primer cruce closing, Ts=.2 / sampling=.14.
% No sustituye el simulador. runE2CM3 verifica igualdad contra su API real.
arguments
    q (:,1) double {mustBeFinite}
    curve (:,1) double {mustBeFinite}
    limits (1,2) double {mustBeFinite}
end
assert(~isempty(curve) && limits(1)<=limits(2));
records=find([true;diff(cummax(curve))>0]);
thresholds=curve(records);
clamped=min(limits(2),max(limits(1),q));
bin=discretize(clamped,[-Inf;thresholds;Inf],IncludedEdge="right");
found=bin<=numel(records);
startIndex=zeros(size(q)); startIndex(found)=records(bin(found));
next=q; next(found)=curve(min(startIndex(found)+200,numel(curve)));
end
