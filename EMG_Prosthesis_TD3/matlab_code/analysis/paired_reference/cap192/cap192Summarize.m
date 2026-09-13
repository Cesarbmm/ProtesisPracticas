function result=cap192Summarize(out,cfg)
d=load(fullfile(out,"measurements.mat"));E=d.E;M=d.M;C=d.C;rows={};countRows={};pwmRows={};
for split=["ALL","TRAIN","VALIDATION"]
    mask=true(height(E),1);mm=true(height(M),1);cm=true(height(C),1);
    if split~="ALL"
        subjects=cfg.trainSubjects;if split=="VALIDATION",subjects=cfg.validationSubjects;end
        mask=ismember(E.subject,subjects);mm=ismember(M.subject,subjects);cm=C.split==split;
    end
    [macro,subjects,directions,motors,groups]=e2fAggregate(E(mask,:),M(mm,:));
    dest=fullfile(out,split);if ~isfolder(dest),mkdir(dest);end
    names=["macro","subject","direction","motor","subject_direction"];tables={macro,subjects,directions,motors,groups};
    for i=1:numel(names),writetable(tables{i},fullfile(dest,names(i)+"_metrics.csv"));end
    for k=1:height(macro)
        label=macro.controller(k);c=C(cm & C.controller==label & C.horizon=="COMMON",:);r=C(cm & C.controller==label & C.horizon=="EMG_ONLY",:);
        row=table2struct(macro(k,:));row.split=split;
        row.m3Reversals=sum(c.positiveReversals(c.motor==3));row.finalCycles=sum(c.finalCycles);row.periodicTrajectories=nnz(c.period);
        row.cycleWindows=sum(c.cycleWindows);row.newCycleWindows=sum(c.newCycleWindows);
        row.newFinalCycles=sum(c.newFinalCycle);row.newFinalPeriodic=sum(c.newFinalPeriodic);
        row.newRuntimeFinalCycles=sum(r.newFinalCycle);row.newRuntimeFinalPeriodic=sum(r.newFinalPeriodic);
        row.boundHitFraction192=sum(c.boundHits)/sum(c.commands);row.clippedDesiredFraction=sum(c.clipped)/sum(c.commands);
        row.zeroMotionFailures=sum(c.zeroMotionFailures);rows{end+1}=row; %#ok<AGROW>
    end
    % Fracciones agrupadas por comandos, tanto horizonte teacher como EMG completo.
    for label=d.labels
        for horizon=["COMMON","EMG_ONLY"]
            c=C(cm & C.controller==label & C.horizon==horizon,:);
            for dimension=["global","motor","direction","subject"]
                values="ALL";
                if dimension=="motor",values=string(1:4);elseif dimension=="direction",values=string(1:2);elseif dimension=="subject",values=unique(c.subject)';end
                for value=values
                    g=c;
                    if dimension=="motor",g=c(c.motor==str2double(value),:);elseif dimension=="direction",g=c(c.side==str2double(value),:);elseif dimension=="subject",g=c(c.subject==value,:);end
                    cr=struct("controller",label,"split",split,"horizon",horizon,"dimension",dimension,"value",value, ...
                        "commands",sum(g.commands),"boundHits192",sum(g.boundHits),"boundHitFraction192",sum(g.boundHits)/sum(g.commands), ...
                        "clippedDesiredFraction",sum(g.clipped)/sum(g.commands),"m3Reversals",sum(g.positiveReversals(g.motor==3)), ...
                        "finalCycles",sum(g.finalCycles),"periodicTrajectories",nnz(g.period),"cycleWindows",sum(g.cycleWindows), ...
                        "newCycleWindows",sum(g.newCycleWindows),"newFinalCycles",sum(g.newFinalCycle),"newFinalPeriodic",sum(g.newFinalPeriodic));
                    countRows{end+1}=cr; %#ok<AGROW>
                end
            end
        end
    end
end
S=struct2table([rows{:}]);writetable(S,fullfile(out,"comparison.csv"));writetable(struct2table([countRows{:}]),fullfile(out,"grouped_counts.csv"));
% Distribucion completa por episodio y motor permite cualquier agregacion sin perder counts.
for label=d.labels
    a=load(fullfile(out,label,"trajectories.mat"),"traces");
    for e=1:200
        t=a.traces{e};md=t.metadata;
        for m=1:4
            for level=[-255 -224 -192 -160 -128 -96 -64 0 64 96 128 160 192 224 255]
                pwmRows{end+1}=struct("controller",label,"subject",string(md.subject),"row",md.repetition,"side",md.side,"split",string(md.split), ...
                    "motor",m,"pwm",level,"count",nnz(t.pwm(:,m)==level),"commands",size(t.pwm,1)); %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table([pwmRows{:}]),fullfile(out,"pwm_distribution.csv"));
o=S(S.controller=="BEST_OFF" & S.split=="VALIDATION",:);c=S(S.controller=="BEST_CAP192" & S.split=="VALIDATION",:);
original=struct("mse",o.trackingMSE,"reward",o.rewardMean,"m3",o.m3Reversals);
candidate=struct("mse",c.trackingMSE,"reward",c.rewardMean,"m3",c.m3Reversals,"boundHitFraction192",c.boundHitFraction192, ...
    "newFinalCycles",c.newFinalCycles,"newFinalPeriodic",c.newFinalPeriodic,"newRuntimeFinalCycles",c.newRuntimeFinalCycles, ...
    "newRuntimeFinalPeriodic",c.newRuntimeFinalPeriodic,"zeroMotionFailures",c.zeroMotionFailures);
checks=struct("offReproduced",height(d.R)==400 && all(d.R.rewardDiff<=1e-12),"testsPass",false,"hashesIntact",false);
g=cap192Gate(original,candidate,checks);result=struct("original",original,"candidate",candidate,"gate",g,"status","MEASURED_PENDING_TESTS");
e2cWriteJSON(fullfile(out,"gate_measurement.json"),result);
disp(S(:,["controller","split","trackingMSE","rewardMean","m3Reversals","finalCycles","periodicTrajectories","boundHitFraction192"]));
end
