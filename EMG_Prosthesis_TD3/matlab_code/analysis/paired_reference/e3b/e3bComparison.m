function e3bComparison(current,out)
% Comparadores congelados; mismos identificadores, nunca volver a entrenarlos.
here=string(fileparts(mfilename("fullpath")));pr=fileparts(here);root=fileparts(fileparts(pr));
d=load(fullfile(pr,"e2f_results","trajectories.mat"),"trajectories");
run=fullfile(root,"results","e3ax_long","run_20260908_141321_916_6ebf347b");
b=load(fullfile(run,"evaluation","best_checkpoint","metrics","trajectories.mat"),"traces");
l=load(fullfile(run,"evaluation","last_checkpoint","metrics","trajectories.mat"),"traces");
E={};M={};counts={};labels=["ZERO","Agent7250","P2","Oracle_H5","TD3_BEST","TD3_LAST","Categorical"];
for e=1:numel(current)
    t=current{e};md=t.metadata;idx=find(cellfun(@(x) string(x.metadata.subject)==string(md.subject) && x.metadata.repetition==md.repetition && x.metadata.side==md.side,d.trajectories(:,2)));
    assert(isscalar(idx));traces=[d.trajectories(idx,[1 3 2 7]),b.traces(idx),l.traces(idx),{t}];
    for j=1:7
        x=traces{j};[mot,met]=e2bControlMetrics(x);key=struct("controller",labels(j),"subject",string(md.subject),"repetition",md.repetition,"side",md.side,"steps",size(x.pwm,1));
        E{end+1}=merge(key,met);for m=1:4,M{end+1}=merge(key,mot(m));end %#ok<AGROW>
        counts{end+1}=struct("controller",labels(j),"subject",string(md.subject),"side",md.side, ...
            "m3Reversals",nnz(x.pwm(:,3)>0 & diff(x.q(:,3))<0),"cycles",met.persistentTwoCycle); %#ok<AGROW>
    end
end
E=struct2table([E{:}]);M=struct2table([M{:}]);C=struct2table([counts{:}]);
cfg=e3bConfig;
for split=["ALL","TRAIN","VALIDATION"]
    subjects=unique(E.subject);if split=="TRAIN",subjects=cfg.trainSubjects;elseif split=="VALIDATION",subjects=cfg.validationSubjects;end
    mask=ismember(E.subject,subjects);if ~any(mask),continue;end
    [macro,subj,dirs,motor]=e2fAggregate(E(mask,:),M(ismember(M.subject,subjects),:));
    for j=1:height(macro),c=C(C.controller==macro.controller(j) & ismember(C.subject,subjects),:);macro.m3Reversals(j)=sum(c.m3Reversals);macro.persistentTwoCycle(j)=sum(c.cycles);end
    dest=fullfile(out,"comparison",split);if ~isfolder(dest),mkdir(dest);end
    writetable(macro,fullfile(dest,"metrics.csv"));writetable(subj,fullfile(dest,"subjects.csv"));writetable(dirs,fullfile(dest,"directions.csv"));writetable(motor,fullfile(dest,"motors.csv"));
    fig=figure(Visible="off",Color="w",Position=[50 50 1250 750]);tiledlayout(2,4,TileSpacing="compact");
    names=["trackingMSE","rewardMean","actionL2","deltaActionL2","saturationFraction","persistentTwoCycle","m3Reversals"];
    for field=names
        nexttile;bar(macro.(field));xticks(1:7);lab=macro.controller;lab(lab=="P2")="P2 (teacher)";lab(lab=="Oracle_H5")="Oracle (teacher futuro)";
        xticklabels(lab);xtickangle(40);title(field,Interpreter="none");grid on;
    end
    exportgraphics(fig,fullfile(dest,"comparison.png"),Resolution=120);close(fig);
end
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
