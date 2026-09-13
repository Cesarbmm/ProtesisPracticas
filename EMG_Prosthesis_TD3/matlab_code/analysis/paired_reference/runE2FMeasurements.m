function summary=runE2FMeasurements
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2f_results");
e2fVerifyHistory();[remap,cleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
p=configurables();assert(~p.unifyActions && p.period==.2 && p.rewardActionWeight==.01 && p.rewardDeltaActionWeight==.05);
pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
d=load(fullfile(here,"e2b_results","trajectories.mat"),"trajectories");gd=load(fullfile(out,"graphs.mat"),"graphs");graphs=gd.graphs;
controllers=["ZERO","P_2","AGENT7250","ORACLE_H1","ORACLE_H2","ORACLE_H3","ORACLE_H5"];
horizons=[1 2 3 5];trajectories=cell(200,7);maxBaselineRewardError=0;
for col=1:3
    mask=cellfun(@(x) x.metadata.controller==controllers(col),d.trajectories);t=d.trajectories(mask);assert(numel(t)==200);
    trajectories(:,col)=t(:);
    for e=1:200
        t=trajectories{e,col};previous=zeros(1,4);
        for k=1:size(t.pwm,1)
            next=SimController.prosthesis_simulator(t.q(k,:),t.pwm(k,:),.2,.14,plantSource="patternCurveCanonical");
            assert(isequal(next,t.q(k+1,:)),"E2F:HistoricalPlantMismatch");
            pred=encoder2Flex(next)./[4092 2046 1023 2046];
            ctx=struct("flexConverted",t.reference(k,:),"adjustEnc",pred,"prevAction",previous);
            reward=trackingMseActionRateReward(ctx,t.effectiveAction(k,:),[]);
            maxBaselineRewardError=max(maxBaselineRewardError,abs(reward-t.reward(k)));previous=t.effectiveAction(k,:);
        end
    end
end
assert(maxBaselineRewardError<=1e-12);
for hi=1:4
    for e=1:200,trajectories{e,hi+3}=e2fRollout(trajectories{e,2},horizons(hi),graphs,remap);end
    fprintf("E2F oracle H%d: 200 episodios.\n",horizons(hi));
end
metricRows={};motorRows={};stepTables={};cycleRows={};periodRows={};pwmRows={};
save(fullfile(out,"trajectories.mat"),"trajectories","controllers","horizons","-v7.3");
for col=1:7
    for e=1:200
        t=trajectories{e,col};base=trajectories{e,2};md=t.metadata;[mot,met]=e2bControlMetrics(t);
        key=struct("controller",md.controller,"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",size(t.pwm,1));
        metricRows{end+1}=merge(key,met); %#ok<AGROW>
        mask=e2dCycleScan(t.q,t.pwm);baseMask=e2dCycleScan(base.q,base.pwm);
        for m=1:4
            motorRows{end+1}=merge(key,mot(m)); %#ok<AGROW>
            period=e2fPeriodicTrace(t.q,t.pwm,m,false);basePeriod=e2fPeriodicTrace(base.q,base.pwm,m,false);
            newPeriodic=period>0 && (basePeriod==0 || abs(min(t.q(end-4*period+1:end,m))-min(base.q(end-4*basePeriod+1:end,m)))>1e-9 || ...
                abs(max(t.q(end-4*period+1:end,m))-max(base.q(end-4*basePeriod+1:end,m)))>1e-9);
            periodRows{end+1}=merge(key,struct("motor",m,"period",period,"newVersusP2",newPeriodic)); %#ok<AGROW>
            for pwm=graphs{m}.actions
                pwmRows{end+1}=merge(key,struct("motor",m,"pwm",pwm,"count",nnz(t.pwm(:,m)==pwm))); %#ok<AGROW>
            end
        end
        [ends,motors]=find(mask);
        for j=1:numel(ends)
            k=ends(j);m=motors(j);pair=sort(t.q(k-3:k-2,m));
            same=baseMask(k,m) && max(abs(pair-sort(base.q(k-3:k-2,m))))<=1e-9;
            cycleRows{end+1}=merge(key,struct("motor",m,"endStep",k,"terminal",k==size(t.pwm,1), ...
                "qLow",pair(1),"qHigh",pair(2),"newVersusP2",~same)); %#ok<AGROW>
        end
        stepTables{end+1}=e2fTraceTable(t); %#ok<AGROW>
    end
end
metrics=struct2table([metricRows{:}]);motors=struct2table([motorRows{:}]);T=vertcat(stepTables{:});
[macro,subjects,directions,motorSummary,groups]=e2fAggregate(metrics,motors);
names=["episode_metrics","episode_motor_metrics","controller_summary","subject_summary","direction_summary","motor_summary", ...
    "subject_side_summary","step_traces","cycle_windows","periodic_trajectories","pwm_distribution"];
values={metrics,motors,macro,subjects,directions,motorSummary,groups,T,struct2table([cycleRows{:}]),struct2table([periodRows{:}]),struct2table([pwmRows{:}])};
for k=1:numel(names),writetable(values{k},fullfile(out,names(k)+".csv"));end
known=(T.subject=="BLANCA" & T.repetition==1 & T.side==1 & T.motor==3) | ...
    (T.subject=="IVANNA" & T.repetition==104 & T.side==2 & T.motor==4);
writetable(T(known,:),fullfile(out,"known_cycle_cases.csv"));
save(fullfile(out,"trajectories.mat"),"trajectories","controllers","horizons","-v7.3");
e2fReachability(trajectories,graphs,out);
summary=struct("episodesPerController",200,"horizons",horizons,"primaryHorizon",5, ...
    "baselinePlantExact",true,"baselineMaxRewardError",maxBaselineRewardError, ...
    "graphStates",cellfun(@(g) numel(g.q),graphs),"commands",height(T), ...
    "preregistrationSHA256",strtrim(string(fileread(fullfile(out,"preregistration.sha256")))),"RL_EXECUTED",false);
e2cWriteJSON(fullfile(out,"measurement_summary.json"),summary);e2fVerifyHistory();disp(macro(:,["controller","trackingMSE","rewardMean","flat_response","action_no_motion"]));
end
function c=merge(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
