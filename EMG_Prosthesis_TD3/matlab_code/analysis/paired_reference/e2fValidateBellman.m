function T=e2fValidateBellman
here=string(fileparts(mfilename("fullpath")));out=fullfile(here,"e2f_results");d=load(fullfile(out,"graphs.mat"));rows={};
for m=1:4
    g=d.graphs{m};
    for H=1:3
        q=min(numel(g.q),1+floor((H-1)*numel(g.q)/3));previous=2*H-1;
        targets=linspace(.35,.65,H)';[a,v,plan]=e2fOracleAction(g,q,previous,targets);
        [expected,expectedA]=enumerate(g,q,previous,targets);
        assert(abs(v-expected)<=1e-12 && a==expectedA,"E2F:BellmanMismatch");
        assert(abs(sum(plan.stageCosts)-v)<1e-12);
        rows{end+1}=struct("motor",m,"horizon",H,"qIndex",q,"previousIndex",previous, ...
            "actionIndex",a,"exhaustiveActionIndex",expectedA,"cost",v,"exhaustiveCost",expected,"error",abs(v-expected)); %#ok<AGROW>
    end
end
T=struct2table([rows{:}]);writetable(T,fullfile(out,"bellman_validation.csv"));disp(T);
end
function [v,ai]=enumerate(g,q,previous,targets)
a=g.actions/255;costs=zeros(1,15);
for j=1:15
    dest=g.next(q,j);costs(j)=(g.h(dest)-targets(1))^2+.01*a(j)^2+.05*(a(j)-a(previous))^2;
    if numel(targets)>1,costs(j)=costs(j)+enumerate(g,dest,j,targets(2:end));end
end
[v,ai]=min(costs);
end
