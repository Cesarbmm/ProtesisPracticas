function result=e3bEvaluate(checkpoint,episodes,out,label,fullPlots)
% Reutiliza inferencia y plotter E3AX; agrega diagnosticos categoricos.
result=e3axEvaluate(checkpoint,episodes,out,label,fullPlots);
a=load(checkpoint,"saved_actor");actor=a.saved_actor;d=load(fullfile(out,"metrics","trajectories.mat"));rows={};
for e=1:numel(episodes)
    t=d.traces{e};r=d.runtimeTraces{e};n=size(t.pwm,1);[p,h]=actor.distribution(r.state(1:n,:)');
    [~,cats]=max(p,[],1);cats=reshape(cats,4,[]);assert(isequal(e3bCategoryPWM(cats)',t.pwm));
    mask=e2dCycleScan(t.q,t.pwm);
    for m=1:4
        md=t.metadata;row=struct("controller",label,"subject",string(md.subject),"row",md.repetition,"side",md.side,"split",string(md.split), ...
            "motor",m,"steps",n,"headEntropy",mean(h(m,:)),"fraction255",mean(abs(t.pwm(:,m))==255), ...
            "cycles",double(mask(end,m)),"cycleWindows",sum(mask(:,m)),"periodic",double(e2fPeriodicTrace(t.q,t.pwm,m,false)>0), ...
            "m3Reversals",double(m==3)*nnz(t.pwm(:,m)>0 & diff(t.q(:,m))<0));
        for c=1:15,row.("category"+c)=nnz(cats(m,:)==c);end
        rows{end+1}=row; %#ok<AGROW>
    end
end
D=struct2table([rows{:}]);writetable(D,fullfile(out,"metrics","categorical_episode_motor.csv"));
G={};F={};
for split=["ALL","TRAIN","VALIDATION"]
    T=D;if split~="ALL",T=D(D.split==split,:);end;if isempty(T),continue;end
    for dim=["motor","subject_motor","direction_motor"]
        values="ALL";if dim=="subject_motor",values=unique(T.subject)';elseif dim=="direction_motor",values=string(1:2);end
        for value=values
            for m=1:4
                A=T(T.motor==m,:);if dim=="subject_motor",A=A(A.subject==value,:);elseif dim=="direction_motor",A=A(A.side==str2double(value),:);end
                if isempty(A),continue;end
                count=zeros(1,15);for c=1:15,count(c)=sum(A.("category"+c));end
                total=sum(count);row=struct("split",split,"dimension",dim,"value",value,"motor",m,"commands",total, ...
                    "headEntropy",sum(A.headEntropy.*A.steps)/total,"fraction255",(count(14)+count(15))/total, ...
                    "maxCategoryFraction",max(count)/total,"cycles",sum(A.cycles),"cycleWindows",sum(A.cycleWindows), ...
                    "periodic",sum(A.periodic),"m3Reversals",sum(A.m3Reversals));
                G{end+1}=row; %#ok<AGROW>
                for c=1:15
                    cr=row;cr.category=c;levels=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
                    cr.pwm=levels(c);cr.count=count(c);cr.fraction=count(c)/total;F{end+1}=cr; %#ok<AGROW>
                end
            end
        end
    end
end
G=struct2table([G{:}]);F=struct2table([F{:}]);writetable(G,fullfile(out,"metrics","categorical_grouped.csv"));writetable(F,fullfile(out,"metrics","category_distribution.csv"));
globalRows=G(G.split=="ALL" & G.dimension=="motor",:);
result.headEntropy=globalRows.headEntropy';result.maxCategoryFraction=globalRows.maxCategoryFraction';
result.m3Reversals=sum(globalRows.m3Reversals);result.cycles=sum(globalRows.cycles);result.periodic=sum(globalRows.periodic);
result.cycleWindows=sum(globalRows.cycleWindows);result.referenceContractValidated=false;result.algorithm="FACTORIZED_MULTICATEGORICAL_PPO";
e3bComparison(d.traces,out);
fig=figure(Visible="off",Color="w",Position=[50 50 1100 650]);tiledlayout(2,2,TileSpacing="compact");
for m=1:4
    nexttile;A=F(F.split=="ALL" & F.dimension=="motor" & F.motor==m,:);bar(1:15,A.fraction);
    xticks(1:15);xticklabels(string(A.pwm));xtickangle(45);ylim([0 1]);title("Motor"+m+"; H="+sprintf("%.3f",result.headEntropy(m)));ylabel("Fraccion");xlabel("PWM");
end
exportgraphics(fig,fullfile(out,"categorical_summary.png"),Resolution=130);close(fig);
e2cWriteJSON(fullfile(out,"summary.json"),result);
end
