function [regions,cells]=e2cM3ReversalIntervals(curve,limits,domain)
% Intervalos exactos delta_q<0 del mapa de primer cruce, no rejilla estimada.
% Las celdas normales son (lower,upper]; se conserva inclusion en el dominio.
arguments
    curve (:,1) double {mustBeFinite}
    limits (1,2) double {mustBeFinite}
    domain (1,2) double {mustBeFinite}
end
assert(domain(1)<domain(2));
records=find([true;diff(cummax(curve))>0]);
thresholds=curve(records);
thresholds=thresholds(thresholds>=limits(1) & thresholds<=limits(2));
edges=unique([domain(:);limits(:);thresholds]);
edges=edges(edges>=domain(1) & edges<=domain(2));
rows={};
% Un dominio que empieza exactamente en un record puede contener solamente
% ese punto de reversal, seguido de HOLD. No perder ese singleton cerrado.
[firstValue,firstIndex]=e2cM3CurveStep(domain(1),curve,limits);
if firstValue<domain(1)
    rows{end+1}=struct("lower",domain(1),"upper",domain(1),"lowerIncluded",true, ...
        "upperIncluded",true,"qNext",firstValue,"startIndex",firstIndex, ...
        "endIndex",min(firstIndex+200,numel(curve)));
end
for k=1:numel(edges)-1
    a=edges(k); b=edges(k+1); mid=a+(b-a)/2;
    [f,idx]=e2cM3CurveStep(mid,curve,limits);
    if idx==0,continue,end % HOLD conserva posicion: no es celda constante.
    assert(e2cM3CurveStep(b,curve,limits)==f);
    lo=max(a,f);
    if b<=lo,continue,end
    includeLo=a==domain(1) && lo==a && a>f && ...
        e2cM3CurveStep(a,curve,limits)==f;
    rows{end+1}=struct("lower",lo,"upper",b,"lowerIncluded",includeLo, ...
        "upperIncluded",true,"qNext",f,"startIndex",idx, ...
        "endIndex",min(idx+200,numel(curve))); %#ok<AGROW>
end
if isempty(rows)
    cells=table(zeros(0,1),zeros(0,1),false(0,1),false(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        VariableNames=["lower","upper","lowerIncluded","upperIncluded","qNext","startIndex","endIndex"]);
else
    cells=struct2table([rows{:}]);
end
regions=cells(:,["lower","upper","lowerIncluded","upperIncluded"]);
if isempty(regions),return,end
keep=true(height(regions),1); previous=1;
for k=2:height(regions)
    if regions.lower(k)<=regions.upper(previous)
        regions.upper(previous)=regions.upper(k);
        regions.upperIncluded(previous)=regions.upperIncluded(k);
        keep(k)=false;
    else
        previous=k;
    end
end
regions=regions(keep,:);
end
