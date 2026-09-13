function [R,macro,subjects,directions,motors,groups]=e2fReachability(traces,graphs,out)
% Los 15 destinos al mismo teacher posterior; límite local, no global.
rows={};
for col=1:size(traces,2)
    tables={};controller=traces{1,col}.metadata.controller;
    for episode=1:size(traces,1)
        t=traces{episode,col};md=t.metadata;n=size(t.pwm,1);
        for m=1:4
            g=graphs{m};[found,idx]=ismember(t.q(1:n,m),g.q);assert(all(found));
            next=g.next(idx,:);Q=g.q(next);h=g.h(next);target=t.reference(:,m);
            currentH=encoder2Flex(t.q(1:n,:))./[4092 2046 1023 2046];
            currentError=abs(currentH(:,m)-target);errors=abs(h-target);best=min(errors,[],2);
            uniqueDest=zeros(n,1);for k=1:n,uniqueDest(k)=numel(unique(Q(k,:)));end
            rows{end+1}=struct("controller",controller,"subject",md.subject,"repetition",md.repetition,"side",md.side, ...
                "steps",n,"motor",m,"minimumReachableError",mean(best),"minimumReachableMSE",mean(best.^2), ...
                "reachableTargetFraction",mean(best<currentError-1e-12),"within005Fraction",mean(best<=.05), ...
                "alreadyWithin005Fraction",mean(currentError<=.05),"distinctEndpoints",mean(uniqueDest), ...
                "activeHoldFraction",mean(abs(Q(:,2:end)-t.q(1:n,m))<=1e-9,"all"), ...
                "bestErrorMin",min(best),"bestErrorMax",max(best)); %#ok<AGROW>
            steps=repelem((1:n)',15);a=repmat((1:15)',n,1);
            key=table(repmat(controller,n*15,1),repmat(md.subject,n*15,1),repmat(md.repetition,n*15,1), ...
                repmat(md.side,n*15,1),steps,repmat(m,n*15,1), ...
                VariableNames=["controller","subject","repetition","side","step","motor"]);
            vals=[repelem(idx,15),reshape(next',[],1),repelem(t.q(1:n,m),15),reshape(g.actions(a),[],1),reshape(Q',[],1),reshape(h',[],1), ...
                repelem(target,15),reshape(errors',[],1),repelem(currentError,15),repelem(best,15), ...
                reshape((errors<currentError-1e-12)',[],1)];
            tables{end+1}=[key array2table(vals,VariableNames=["qIndex","nextIndex","qBefore","pwm","qAfter","hAfter","referenceAfter", ...
                "absoluteError","currentError","bestOneStepError","improvesCurrent"])]; %#ok<AGROW>
        end
    end
    T=vertcat(tables{:});writetable(T,fullfile(out,"reachability_"+controller+".csv"));
    fprintf("E2F alcanzabilidad %s: %d destinos.\n",controller,height(T));
end
R=struct2table([rows{:}]);
% Ponderación macro E2B mediante episodio (media de cuatro motores).
keys=unique(R(:,["controller","subject","repetition","side","steps"]),"rows","stable");erows={};
fields=setdiff(string(R.Properties.VariableNames),["controller","subject","repetition","side","steps","motor"],"stable");
for k=1:height(keys)
    key=keys(k,:);mask=R.controller==key.controller & R.subject==key.subject & R.repetition==key.repetition & R.side==key.side;
    row=table2struct(key);for f=fields,row.(f)=mean(R.(f)(mask),"omitnan");end;erows{end+1}=row; %#ok<AGROW>
end
E=struct2table([erows{:}]);[macro,subjects,directions,motors,groups]=e2fAggregate(E,R);
writetable(R,fullfile(out,"reachability_episode_motor.csv"));writetable(macro,fullfile(out,"reachability_summary.csv"));
writetable(motors,fullfile(out,"reachability_motor_summary.csv"));writetable(subjects,fullfile(out,"reachability_subject_summary.csv"));
writetable(directions,fullfile(out,"reachability_direction_summary.csv"));
end
