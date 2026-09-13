function measurement=runE2EMeasurements
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2e_results");
e2eVerifyHistory();[remap,cleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
p=configurables();assert(p.rewardActionWeight==.01 && p.rewardDeltaActionWeight==.05 && p.observationVariant=="markov52");
pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
source=fullfile(here,"e2b_results","trajectories.mat");data=load(source,"trajectories");
mask=cellfun(@(x) x.metadata.controller=="P_2",data.trajectories);baselines=data.trajectories(mask);baselines=baselines(:);
assert(numel(baselines)==200);trajectories=cell(200,2);metricRows={};motorRows={};cycleRows={};stepTables={};pwmRows={};
baselineMaxReward=0;baselineExact=true;
for enabled=[0 1]
    for episode=1:200
        base=baselines{episode};t=e2eRollout(base,enabled,remap);trajectories{episode,enabled+1}=t;
        [mot,met]=e2bControlMetrics(t);md=base.metadata;
        key=struct("enabled",enabled,"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",size(t.pwm,1));
        metricRows{end+1}=combine(key,met); %#ok<AGROW>
        for motor=1:4,motorRows{end+1}=combine(key,mot(motor));end %#ok<AGROW>
        assert(isequal(t.cycleMask(end,:),logical([mot.persistentTwoCycle])));
        if ~enabled
            baselineMaxReward=max(baselineMaxReward,max(abs(t.reward-base.reward)));
            baselineExact=baselineExact && isequal(t.q,base.q) && isequal(t.rawAction,base.rawAction) && ...
                isequal(t.effectiveAction,base.effectiveAction) && isequal(t.pwm,base.pwm);
        end
        baseMask=e2dCycleScan(base.q,base.pwm);[ends,motors]=find(t.cycleMask);
        for c=1:numel(ends)
            k=ends(c);m=motors(c);pair=sort(t.q(k-3:k-2,m));
            baseSame=baseMask(k,m) && max(abs(pair-sort(base.q(k-3:k-2,m))))<=1e-9;
            cycleRows{end+1}=combine(key,struct("motor",m,"endStep",k,"terminal",k==size(t.pwm,1), ...
                "qLow",pair(1),"qHigh",pair(2),"newVersusBaselineAtSameWindow",~baseSame)); %#ok<AGROW>
        end
        stepTables{end+1}=e2eStepTable(t,base,enabled); %#ok<AGROW>
        for motor=1:4
            for pwm=[-255 -224 -192 -160 -128 -96 -64 0 64 96 128 160 192 224 255]
                pwmRows{end+1}=combine(key,struct("motor",motor,"pwm",pwm,"count",nnz(t.pwm(:,motor)==pwm))); %#ok<AGROW>
            end
        end
    end
    fprintf("E2E guard %d: 200 episodios medidos.\n",enabled);
end
assert(baselineExact && baselineMaxReward<=1e-12,"E2E:BaselineMismatch");
metrics=struct2table([metricRows{:}]);motors=struct2table([motorRows{:}]);cycles=struct2table([cycleRows{:}]);T=vertcat(stepTables{:});
[macro,subjects,directions,motorSummary,groups]=e2eAggregate(metrics,motors);events=e2eEventSummary(T);
assert(abs(macro.trackingMSE(1)-.025400336373607925)<1e-12);
assert(abs(macro.rewardMean(1)+.03272837710980499)<1e-12);
gateRows={};degradationRows={};
for enabled=[0 1]
    r=macro(enabled+1,:);b=macro(1,:);counts=zeros(1,3);
    flatChanges=r.flat_response-b.flat_response;noMotionChanges=r.action_no_motion-b.action_no_motion;
    tables={subjects,motorSummary,directions};kind=["subject","motor","direction"];idFields=["subject","motor","side"];
    for type=1:3
        A=tables{type};a=A(A.enabled==enabled,:);z=A(A.enabled==0,:);
        assert(isequal(a.(idFields(type)),z.(idFields(type))));
        for j=1:height(a)
            dm=change(a.trackingMSE(j),z.trackingMSE(j),false);dr=change(a.rewardMean(j),z.rewardMean(j),true);
            degraded=dm>5+1e-12 || dr>5+1e-12;counts(type)=counts(type)+degraded;
            degradationRows{end+1}=struct("enabled",enabled,"kind",kind(type),"group",string(a.(idFields(type))(j)), ...
                "mseChangePct",dm,"rewardChangePct",dr,"degraded",degraded, ...
                "flatIncrease",a.flat_response(j)-z.flat_response(j),"noMotionIncrease",a.action_no_motion(j)-z.action_no_motion(j)); %#ok<AGROW>
        end
        if type>1
            flatChanges=[flatChanges;a.flat_response-z.flat_response]; %#ok<AGROW>
            noMotionChanges=[noMotionChanges;a.action_no_motion-z.action_no_motion]; %#ok<AGROW>
        end
    end
    S=T(T.enabled==enabled,:);z=events(events.enabled==enabled & events.kind=="total",:);
    f=struct("cycles",sum(metrics.persistentTwoCycle(metrics.enabled==enabled)), ...
        "newCycles",nnz(cycles.enabled==enabled & cycles.terminal & cycles.newVersusBaselineAtSameWindow), ...
        "mseChangePct",change(r.trackingMSE,b.trackingMSE,false),"rewardChangePct",change(r.rewardMean,b.rewardMean,true), ...
        "subjectDegradations",counts(1),"motorDegradations",counts(2),"directionDegradations",counts(3), ...
        "m3Reversals",nnz(S.motor==3 & S.pwm>0 & S.qAfter<S.qBefore), ...
        "zeroMotionFailures",nnz(S.pwm==0 & abs(S.qAfter-S.qBefore)>1e-9), ...
        "maxFlatIncrease",max(flatChanges),"maxNoMotionIncrease",max(noMotionChanges), ...
        "flatDefined",all(isfinite(flatChanges)),"noMotionDefined",all(isfinite(noMotionChanges)), ...
        "neutralStepFractionOfActiveBaseline",z.neutralStepFractionOfActiveBaseline);
    flags=e2eCandidateGate(f);
    details=struct("enabled",enabled,"trackingMSE",r.trackingMSE,"rewardMean",r.rewardMean, ...
        "slidingCycleWindows",nnz(cycles.enabled==enabled), ...
        "newSlidingCycleWindows",nnz(cycles.enabled==enabled & cycles.newVersusBaselineAtSameWindow), ...
        "inactiveEpisodeMotors",nnz(motors.enabled==enabled & motors.activeCommands==0));
    gateRows{end+1}=combine(combine(details,f),flags); %#ok<AGROW>
end
gates=struct2table([gateRows{:}]);degradations=struct2table([degradationRows{:}]);
names=["episode_metrics","episode_motor_metrics","mode_summary","subject_summary","direction_summary", ...
    "motor_summary","subject_side_summary","event_summary","cycle_windows","subgroup_degradations","candidate_gates","step_traces"];
values={metrics,motors,macro,subjects,directions,motorSummary,groups,events,cycles,degradations,gates,T};
for k=1:numel(names),writetable(values{k},fullfile(out,names(k)+".csv"));end
writetable(struct2table([pwmRows{:}]),fullfile(out,"pwm_distribution.csv"));
save(fullfile(out,"trajectories.mat"),"trajectories","baselines","gates","-v7.3");
measurement=struct("episodes",200,"commandsPerMode",height(T)/2,"baselineExact",baselineExact, ...
    "baselineMaxRewardError",baselineMaxReward,"baselineMSE",macro.trackingMSE(1),"baselineReward",macro.rewardMean(1), ...
    "baselineCycles",gates.cycles(1),"selectionRequiresFinalTests",true, ...
    "preregistrationSHA256",strtrim(string(fileread(fullfile(out,"preregistration.sha256")))), ...
    "sourceSHA256",e2cSHA256(source),"RL_AUTHORIZED",false);
e2cWriteJSON(fullfile(out,"measurement_summary.json"),measurement);e2eVerifyHistory();disp(gates);disp(events(events.kind=="total",:));
end
function v=change(a,b,isReward)
d=a-b;if isReward,d=-d;end
if abs(b)<=1e-12,if d<=1e-12,v=0;else,v=Inf;end;else,v=100*d/abs(b);end
end
function c=combine(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
