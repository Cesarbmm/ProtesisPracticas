function result=e3axFinalEvaluation(session)
cfg=session.cfg;out=session.out;R=struct2table(session.records);
fprintf("INICIO TEST COMPORTAMENTAL: BEST y LAST, TRAIN/VALIDATION; MATEO/SANDRA sellados.\n");
assert(~isempty(R),"E3AX:NoCheckpoints");R=sortrows(R,["reward","mse","episode"],["descend","ascend","ascend"]);
best=R(1,:);lastEpisode=max(R.episode);last=R(R.episode==lastEpisode,:);
bestEval=e3axEvaluate(best.checkpoint,session.data.evaluation,fullfile(out,"evaluation","best_checkpoint"),"BEST_TD3",true);
lastEval=e3axEvaluate(last.checkpoint,session.data.evaluation,fullfile(out,"evaluation","last_checkpoint"),"LAST_TD3",true);
b=load(fullfile(bestEval.output,"metrics","trajectories.mat"),"traces");l=load(fullfile(lastEval.output,"metrics","trajectories.mat"),"traces");
all=[session.data.comparators,b.traces,l.traces];labels=["ZERO","Agent7250","P2","Oracle_H5","BEST_TD3","LAST_TD3"];
for split=["ALL","TRAIN","VALIDATION"]
    use=true(size(all,1),1);if split~="ALL",use=cellfun(@(x) x.split==split,session.data.evaluation);end
    E={};M={};m3=zeros(1,6);cycles=zeros(1,6);
    for col=1:6
        for e=find(use)'
            t=all{e,col};md=t.metadata;[mot,met]=e2bControlMetrics(t);key=struct("controller",labels(col),"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",size(t.pwm,1));
            E{end+1}=merge(key,met);for m=1:4,M{end+1}=merge(key,mot(m));end %#ok<AGROW>
            m3(col)=m3(col)+nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0);cycles(col)=cycles(col)+met.persistentTwoCycle;
        end
    end
    [macro,subjects,directions,motors]=e2fAggregate(struct2table([E{:}]),struct2table([M{:}]));
    for j=1:height(macro),col=find(labels==macro.controller(j));macro.m3Reversals(j)=m3(col);macro.persistentTwoCycle(j)=cycles(col);end
    folder=fullfile(out,"evaluation","comparison",split);mkdir(folder);writetable(macro,fullfile(folder,"metrics.csv"));
    writetable(subjects,fullfile(folder,"subjects.csv"));writetable(directions,fullfile(folder,"directions.csv"));writetable(motors,fullfile(folder,"motors.csv"));
    e3axPlotComparison(macro,folder);
end
result=struct("bestCheckpoint",best.checkpoint,"bestEpisode",best.episode,"bestValidationReward",best.reward, ...
    "lastCheckpoint",last.checkpoint,"lastEpisode",lastEpisode,"selection","Máximo reward macro VALIDATION; empate MSE y episodio", ...
    "bestEvaluation",bestEval,"lastEvaluation",lastEval,"completedRequestedEpisodes",lastEpisode==cfg.maxEpisodes);
e2cWriteJSON(fullfile(out,"evaluation","final_summary.json"),result);
result.behavioralTest=e3axPublishBehavioralTest(out);
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
