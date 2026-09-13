function measurement=runE2DMeasurements
% Comparaciones preregistradas, sobre teacher E2B y planta real, sin RL.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2d_results");
assert(isfolder(out));
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2D.md");
assert(e2cSHA256(prereg)=="9a9527571f9fac8524aa8b3ef90ee0110ed1bfce075146596868b7e5cd1ee8c9");
verifyHistory(root,out);
had=isappdata(0,"configurables_override");old=struct();if had,old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restoreOverride(old,had)); %#ok<NASGU>
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
[remap,remapCleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
p=configurables();assert(p.rewardActionWeight==.01 && p.rewardDeltaActionWeight==.05 && p.observationVariant=="markov52");
pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
source=fullfile(here,"e2b_results","trajectories.mat");data=load(source,"trajectories");
baselines={};for k=1:numel(data.trajectories)
    t=data.trajectories{k};if t.metadata.controller=="P_2",baselines{end+1,1}=t;end %#ok<AGROW>
end
assert(numel(baselines)==200);grid=[0 .03 .05 .08 .12];
trajectories=cell(200,numel(grid));metricRows={};motorRows={};cycleRows={};
baselineMaxQ=0;baselineMaxRaw=0;baselineMaxReward=0;baselineExact=true;
for g=1:numel(grid)
    for episode=1:200
        base=baselines{episode};t=e2dRollout(base,grid(g),remap);trajectories{episode,g}=t;
        [mot,met]=e2bControlMetrics(t);md=base.metadata;
        key=struct("epsilon",grid(g),"subject",md.subject,"repetition",md.repetition,"side",md.side,"steps",size(t.pwm,1));
        metricRows{end+1}=combine(key,met); %#ok<AGROW>
        for motor=1:4,motorRows{end+1}=combine(key,mot(motor));end %#ok<AGROW>
        assert(isequal(t.cycleMask(end,:),logical([mot.persistentTwoCycle])));
        if g==1
            baselineMaxQ=max(baselineMaxQ,max(abs(t.q-base.q),[],"all"));
            baselineMaxRaw=max(baselineMaxRaw,max(abs(t.rawAction-base.rawAction),[],"all"));
            baselineMaxReward=max(baselineMaxReward,max(abs(t.reward-base.reward)));
            baselineExact=baselineExact && isequal(t.q,base.q) && isequal(t.rawAction,base.rawAction) && ...
                isequal(t.effectiveAction,base.effectiveAction) && isequal(t.pwm,base.pwm);
        end
        baseMask=e2dCycleScan(base.q,base.pwm);
        [ends,motors]=find(t.cycleMask);
        for c=1:numel(ends)
            k=ends(c);m=motors(c);pair=sort(t.q(k-3:k-2,m));
            baseSame=baseMask(k,m) && max(abs(pair-sort(base.q(k-3:k-2,m))))<=1e-9;
            cycleRows{end+1}=combine(key,struct("motor",m,"endStep",k,"terminal",k==size(t.pwm,1), ...
                "qLow",pair(1),"qHigh",pair(2),"newVersusBaselineAtSameWindow",~baseSame)); %#ok<AGROW>
        end
    end
    fprintf("E2D epsilon %.2f: 200 episodios medidos.\n",grid(g));
end
assert(baselineExact && baselineMaxReward<1e-12,"E2D:BaselineMismatch","epsilon0 debe reproducir P2.");
metrics=struct2table([metricRows{:}]);motors=struct2table([motorRows{:}]);cycles=struct2table([cycleRows{:}]);
[macro,subjects,directions,motorSummary,groups]=summarize(metrics,motors,grid);
assert(abs(macro.trackingMSE(1)-.025400336373607925)<1e-12);
assert(abs(macro.rewardMean(1)+.03272837710980499)<1e-12);
[zeroing,pwmDistribution]=zeroSummaries(trajectories,baselines,grid);
gateRows={};degradationRows={};
for g=1:numel(grid)
    e=grid(g);r=macro(g,:);b=macro(1,:);
    mseChange=changeMSE(r.trackingMSE,b.trackingMSE);rewardChange=changeReward(r.rewardMean,b.rewardMean);
    counts=zeros(1,3);flatChanges=r.flat_response-b.flat_response;noMotionChanges=r.action_no_motion-b.action_no_motion;
    tables={subjects,motorSummary,directions};kind=["subject","motor","direction"];
    idFields=["subject","motor","side"];
    for type=1:3
        T=tables{type};a=T(T.epsilon==e,:);z=T(T.epsilon==0,:);
        assert(isequal(a.(idFields(type)),z.(idFields(type))));
        for j=1:height(a)
            dm=changeMSE(a.trackingMSE(j),z.trackingMSE(j));dr=changeReward(a.rewardMean(j),z.rewardMean(j));
            degraded=dm>5+1e-12 || dr>5+1e-12;counts(type)=counts(type)+degraded;
            degradationRows{end+1}=struct("epsilon",e,"kind",kind(type),"group",string(a.(idFields(type))(j)), ...
                "mseChangePct",dm,"rewardChangePct",dr,"degraded",degraded, ...
                "flatIncrease",a.flat_response(j)-z.flat_response(j), ...
                "noMotionIncrease",a.action_no_motion(j)-z.action_no_motion(j)); %#ok<AGROW>
        end
        if type>1
            flatChanges=[flatChanges;a.flat_response-z.flat_response]; %#ok<AGROW>
            noMotionChanges=[noMotionChanges;a.action_no_motion-z.action_no_motion]; %#ok<AGROW>
        end
    end
    cyclesFinal=sum(metrics.persistentTwoCycle(metrics.epsilon==e));
    newCycles=nnz(cycles.epsilon==e & cycles.terminal & cycles.newVersusBaselineAtSameWindow);
    rev=0;for episode=1:200,t=trajectories{episode,g};rev=rev+nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0);end
    z=zeroing(zeroing.epsilon==e & zeroing.kind=="total",:);
    f=struct("cycles",cyclesFinal,"mseChangePct",mseChange,"rewardChangePct",rewardChange, ...
        "subjectDegradations",counts(1),"motorDegradations",counts(2),"directionDegradations",counts(3), ...
        "m3Reversals",rev,"maxFlatIncrease",max(flatChanges),"maxNoMotionIncrease",max(noMotionChanges), ...
        "motionMetricsDefined",all(isfinite(flatChanges)) && all(isfinite(noMotionChanges)), ...
        "pairedZeroedActiveFraction",z.pairedZeroedActiveFraction);
    flags=e2dCandidateGate(f);
    details=struct("epsilon",e,"trackingMSE",r.trackingMSE,"rewardMean",r.rewardMean,"newCycles",newCycles, ...
        "slidingCycleWindows",nnz(cycles.epsilon==e),"newSlidingCycleWindows",nnz(cycles.epsilon==e & cycles.newVersusBaselineAtSameWindow), ...
        "zeroedActionFraction",z.directZeroedFraction,"pairedZeroedFraction",z.pairedZeroedFraction, ...
        "inactiveEpisodeMotors",nnz(motors.epsilon==e & motors.activeCommands==0));
    gateRows{end+1}=combine(combine(details,f),flags); %#ok<AGROW>
end
gates=struct2table([gateRows{:}]);degradations=struct2table([degradationRows{:}]);
writetable(metrics,fullfile(out,"episode_metrics.csv"));writetable(motors,fullfile(out,"episode_motor_metrics.csv"));
writetable(macro,fullfile(out,"epsilon_summary.csv"));writetable(subjects,fullfile(out,"subject_summary.csv"));
writetable(directions,fullfile(out,"direction_summary.csv"));writetable(motorSummary,fullfile(out,"motor_summary.csv"));
writetable(groups,fullfile(out,"subject_side_summary.csv"));writetable(zeroing,fullfile(out,"zeroed_actions.csv"));
writetable(pwmDistribution,fullfile(out,"pwm_distribution.csv"));writetable(cycles,fullfile(out,"cycle_windows.csv"));
writetable(degradations,fullfile(out,"subgroup_degradations.csv"));writetable(gates,fullfile(out,"candidate_gates.csv"));
save(fullfile(out,"trajectories.mat"),"trajectories","baselines","grid","gates","-v7.3");
exportSteps(trajectories,baselines,grid,out);
measurement=struct("grid",grid,"episodes",200,"motorStepsPerEpsilon",4*sum(cellfun(@(x) size(x.pwm,1),baselines)), ...
    "baselineExact",baselineExact,"baselineMaxQError",baselineMaxQ,"baselineMaxRawError",baselineMaxRaw, ...
    "baselineMaxRewardError",baselineMaxReward,"baselineMSE",macro.trackingMSE(1),"baselineReward",macro.rewardMean(1), ...
    "baselineCycles",gates.cycles(1),"provisionalSelectedEpsilon",e2dSelectEpsilon(grid,gates.passed'), ...
    "selectionRequiresFinalTests",true,"preregistrationSHA256",e2cSHA256(prereg), ...
    "sourceSHA256",e2cSHA256(source),"RL_AUTHORIZED",false);
e2cWriteJSON(fullfile(out,"measurement_summary.json"),measurement);verifyHistory(root,out);
disp(gates(:,["epsilon","trackingMSE","mseChangePct","rewardMean","rewardChangePct","cycles","newCycles","passA","passB","passC","passD","passE","passF","passed"]));
end
function [macro,subjects,directions,motorsOut,groups]=summarize(metrics,motors,grid)
fields=setdiff(string(metrics.Properties.VariableNames),["epsilon","subject","repetition","side","steps"],"stable");
gRows={};mRows={};sRows={};dRows={};aRows={};
for e=grid
    for subject=unique(metrics.subject)'
        for side=1:2
            mask=metrics.epsilon==e & metrics.subject==subject & metrics.side==side;
            gRows{end+1}=means(struct("epsilon",e,"subject",subject,"side",side),metrics(mask,:),fields); %#ok<AGROW>
        end
    end
end
groups=struct2table([gRows{:}]);
for e=grid
    aRows{end+1}=means(struct("epsilon",e),groups(groups.epsilon==e,:),fields); %#ok<AGROW>
    for subject=unique(groups.subject)'
        sRows{end+1}=means(struct("epsilon",e,"subject",subject),groups(groups.epsilon==e & groups.subject==subject,:),fields); %#ok<AGROW>
    end
    for side=1:2
        dRows{end+1}=means(struct("epsilon",e,"side",side),groups(groups.epsilon==e & groups.side==side,:),fields); %#ok<AGROW>
    end
    for motor=1:4
        temp={};
        for subject=unique(groups.subject)'
            for side=1:2
                mask=motors.epsilon==e & motors.subject==subject & motors.side==side & motors.motor==motor;
                temp{end+1}=means(struct("motor",motor),motors(mask,:),fields); %#ok<AGROW>
            end
        end
        mRows{end+1}=means(struct("epsilon",e,"motor",motor),struct2table([temp{:}]),fields); %#ok<AGROW>
    end
end
macro=struct2table([aRows{:}]);subjects=struct2table([sRows{:}]);directions=struct2table([dRows{:}]);motorsOut=struct2table([mRows{:}]);
end
function row=means(row,T,fields)
for field=fields,row.(field)=mean(T.(field),"omitnan");end
end
function [Z,P]=zeroSummaries(traces,bases,grid)
rows={};pwmRows={};
for g=1:numel(grid)
    for kind=["total","motor","direction","motor_direction"]
        if contains(kind,"motor"),motorSet=1:4;else,motorSet=0;end
        if contains(kind,"direction"),sideSet=1:2;else,sideSet=0;end
        for motor=motorSet
            for side=sideSet
                counts=zeros(1,5);
                for e=1:200
                    t=traces{e,g};b=bases{e};if side~=0 && b.metadata.side~=side,continue,end
                    m=1:4;if motor~=0,m=motor;end
                    counts=counts+[numel(t.pwm(:,m)),nnz(t.zeroedDirect(:,m)),nnz(t.historicalPwmSameState(:,m)), ...
                        nnz(t.zeroedVersusBaseline(:,m)),nnz(b.pwm(:,m))];
                end
                rows{end+1}=struct("epsilon",grid(g),"kind",kind,"motor",motor,"side",side,"commands",counts(1), ...
                    "directZeroed",counts(2),"historicalSameStateActive",counts(3), ...
                    "pairedZeroed",counts(4),"baselineActive",counts(5), ...
                    "directZeroedFraction",counts(2)/counts(1),"directZeroedActiveFraction",counts(2)/counts(3), ...
                    "pairedZeroedFraction",counts(4)/counts(1),"pairedZeroedActiveFraction",counts(4)/counts(5)); %#ok<AGROW>
            end
        end
    end
    for e=1:200
        t=traces{e,g};md=t.metadata;
        for m=1:4
            for pwm=[-255 -224 -192 -160 -128 -96 -64 0 64 96 128 160 192 224 255]
                pwmRows{end+1}=struct("epsilon",grid(g),"subject",md.subject,"repetition",md.repetition, ...
                    "side",md.side,"motor",m,"pwm",pwm,"count",nnz(t.pwm(:,m)==pwm),"steps",size(t.pwm,1)); %#ok<AGROW>
            end
        end
    end
end
Z=struct2table([rows{:}]);P=struct2table([pwmRows{:}]);
end
function exportSteps(traces,baselines,grid,out)
tables={};
for g=1:numel(grid)
    for e=1:200
        t=traces{e,g};b=baselines{e};n=size(t.pwm,1);md=t.metadata;
        for m=1:4
            key=table(repmat(grid(g),n,1),repmat(md.subject,n,1),repmat(md.repetition,n,1), ...
                repmat(md.side,n,1),(1:n)',repmat(m,n,1), ...
                VariableNames=["epsilon","subject","repetition","side","step","motor"]);
            vals=[t.referenceBefore(:,m),t.reference(:,m),t.errorBefore(:,m),t.rawHistorical(:,m),t.rawAction(:,m), ...
                t.effectiveAction(:,m),t.pwm(:,m),t.historicalPwmSameState(:,m),b.pwm(:,m), ...
                t.q(1:n,m),t.q(2:end,m),t.prediction(:,m),t.zeroedDirect(:,m),t.zeroedVersusBaseline(:,m), ...
                t.trackingTerm(:,m),t.actionPenalty(:,m),t.deltaActionPenalty(:,m),t.rewardVector(:,m),t.reward];
            names=["referenceBefore","referenceAfter","errorBefore","rawHistoricalSameState","rawDeadband", ...
                "effective","pwm","historicalPwmSameState","baselinePwm","qBefore","qAfter","hAfter", ...
                "zeroedDirect","zeroedVersusBaseline","trackingTermMotor","actionPenaltyMotor", ...
                "deltaPenaltyMotor","rewardMotor","rewardEpisode"];
            tables{end+1}=[key array2table(vals,VariableNames=names)]; %#ok<AGROW>
        end
    end
end
T=vertcat(tables{:});writetable(T,fullfile(out,"step_traces.csv"));
mask=T.subject=="BLANCA" & T.repetition==1 & T.side==1 & T.motor==3 | ...
    T.subject=="IVANNA" & T.repetition==104 & T.side==2 & T.motor==4;
writetable(T(mask,:),fullfile(out,"known_cycle_case_traces.csv"));
end
function v=changeMSE(a,b)
if abs(b)<=1e-12,if a-b<=1e-12,v=0;else,v=Inf;end;else,v=100*(a-b)/b;end
end
function v=changeReward(a,b)
if abs(b)<=1e-12,if b-a<=1e-12,v=0;else,v=Inf;end;else,v=100*(b-a)/abs(b);end
end
function c=combine(a,b)
c=a;for f=string(fieldnames(b))',c.(f)=b.(f);end
end
function verifyHistory(root,out)
T=readtable(fullfile(out,"historical_hashes_before.csv"),TextType="string");
for k=1:height(T),assert(e2cSHA256(fullfile(root,T.path(k)))==T.sha256(k),"E2D:HistoricalMutation","Fuente historica alterada.");end
end
function restoreOverride(old,had)
if had,setConfigurablesOverride(old);else,clearConfigurablesOverride();end
end
