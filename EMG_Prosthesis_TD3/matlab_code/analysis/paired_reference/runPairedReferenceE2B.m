function summary=runPairedReferenceE2B(options)
% Auditoria E2B preregistrada. No llama train ni aprende parametros.
arguments
    options.outputDir (1,1) string = ""
end
here=string(fileparts(mfilename("fullpath")));
root=fileparts(fileparts(here));
if options.outputDir=="", options.outputDir=fullfile(here,"e2b_results"); end
out=options.outputDir;
if ~isfolder(out), mkdir(out); end
oldRng=rng; oldPath=path;
hadOverride=isappdata(0,"configurables_override"); oldOverride=struct();
if hadOverride, oldOverride=getappdata(0,"configurables_override"); end
cleanup=onCleanup(@() restoreContext(oldOverride,hadOverride,oldRng,oldPath));
override=struct("run_training",false,"flagSaveTraining",false, ...
    "plotEpisodeOnTest",false,"verbose",false,"usePrerecorded",true,"simMotors",true, ...
    "observationVariant","markov52","simPlantSource","patternCurveCanonical", ...
    "actionInterfaceVariant","baselineQuantized");
setConfigurablesOverride(override);
p=configurables();
assert(~Env.flagSaveTraining && ~Env.plotEpisodeOnTest && Env.simMotors, ...
    "E2B:StaleEnv","Usar un MATLAB nuevo para la auditoria.");
assert(p.period==.2 && p.rewardActionWeight==.01 && p.rewardDeltaActionWeight==.05);
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2B.md");
assert(isfile(prereg),"E2B:MissingPreregistration","Preregistro obligatorio.");
contract=struct("startSHA","fc2e15bb931b79f41be6ce1c3c822dd88a8e9c40", ...
    "preregistrationSHA256",sha256(prereg),"seed",20260905, ...
    "period",p.period,"actionCommandLevels",p.actionCommandLevels, ...
    "speeds",p.speeds,"activationThreshold",p.actionCommandActivationThreshold, ...
    "observationVariant",p.observationVariant,"actionInterfaceVariant",p.actionInterfaceVariant, ...
    "rewardActionWeight",p.rewardActionWeight,"rewardDeltaActionWeight",p.rewardDeltaActionWeight, ...
    "trainingGloveRole","PRIVILEGED_TEACHER", ...
    "teacherTerminationDecision","PRESERVE_HISTORICAL_TEACHER_AVAILABILITY", ...
    "kpGrid",[.5 1 2 4 8],"trainingExecuted",false);
writeJson(fullfile(out,"execution_contract.json"),contract);
pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
[actor,policyManifest,agent]=loadE2AFrozenActor(); critics=getCritic(agent);
actorBefore=getLearnableParameters(actor);
criticBefore={getLearnableParameters(critics(1)),getLearnableParameters(critics(2))};
writeJson(fullfile(out,"policy_manifest.json"),policyManifest);
oracleFolder=makeOracleFixture(root);
addpath(oracleFolder,"-begin"); clear plantE0HistoricalReference;
curve=load(fullfile(root,"src","@SimController","pattern_curve.mat"),"avgs");
subjects=["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA","JOE","JONATHAN","KHAROL"];
inventoryRows={}; selectedRows={}; selectedData={}; sourceRows={};
for subject=subjects
    % Lista literal development: nunca se enumeran ni se abren archivos sellados.
    datasetPath=fullfile(root,"data","datasets","Denis Dataset",subject+".mat");
    data=load(datasetPath,"emgs","gloves");
    sourceRows{end+1}=struct("subject",subject,"path",datasetPath,"sha256",sha256(datasetPath)); %#ok<AGROW>
    rows=max(size(data.emgs,1),size(data.gloves,1)); validPairs=false(rows,1);
    for rep=1:rows
        eligible=false(1,2);
        for side=1:2
            emg=getCell(data.emgs,rep,side); teacher=getCell(data.gloves,rep,side);
            availability=e2bTeacherAvailability(size(emg,1),size(teacher,1));
            eligible(side)=isnumeric(emg) && size(emg,2)==8 && size(emg,1)>=80 && ...
                all(isfinite(emg),"all") && isstruct(teacher) && size(teacher,1)>=4;
            inventoryRows{end+1}=merge(struct("subject",subject,"repetition",rep, ...
                "side",side,"eligibleForControl",eligible(side)),availability); %#ok<AGROW>
        end
        validPairs(rep)=all(eligible);
    end
    eligibleRows=find(validPairs);
    assert(~isempty(eligibleRows),"E2B:NoEligibleData","Sujeto sin pares elegibles.");
    chosen=eligibleRows(unique(round(linspace(1,numel(eligibleRows),min(10,numel(eligibleRows))))));
    for rep=chosen(:)'
        for side=1:2
            selectedRows{end+1}=struct("subject",subject,"repetition",rep,"side",side); %#ok<AGROW>
            selectedData{end+1}=struct("emgs",{data.emgs(rep,:)},"teachers",{data.gloves(rep,:)}); %#ok<AGROW>
        end
    end
end
inventory=struct2table([inventoryRows{:}]); selected=struct2table([selectedRows{:}]);
writetable(inventory,fullfile(out,"teacher_availability.csv"));
writetable(selected,fullfile(out,"selected_episodes.csv"));
writeJson(fullfile(out,"dataset_provenance.json"),[sourceRows{:}]);
writetable(availabilitySummary(inventory),fullfile(out,"availability_by_subject_side.csv"));
fprintf("E2B inventario: %d episodios; seleccion %d; teacher temprano %d.\n", ...
    height(inventory),height(selected),nnz(inventory.earlyTeacherTermination));
controllers=["ZERO","P_0.5","P_1","P_2","P_4","P_8","AGENT7250"];
gains=[0 .5 1 2 4 8 NaN];
trajectories=cell(height(selected),numel(controllers));
metricRows={}; motorRows={}; abRows={}; doneRows={}; transitionRows={};
for episode=1:height(selected)
    id=selected(episode,:); dataset=selectedData{episode};
    qInitial=[];
    for index=1:numel(controllers)
        trace=rolloutTeacher(actor,dataset,id.side,controllers(index),gains(index),contract.seed);
        if isempty(qInitial), qInitial=trace.q(1,:); else, assert(isequal(qInitial,trace.q(1,:))); end
        [perMotor,aggregate]=e2bControlMetrics(trace);
        metadata=struct("subject",id.subject,"repetition",id.repetition,"side",id.side, ...
            "controller",controllers(index),"kp",gains(index),"steps",size(trace.rawAction,1));
        metricRows{end+1}=merge(metadata,aggregate); %#ok<AGROW>
        for m=1:4, motorRows{end+1}=merge(metadata,perMotor(m)); end %#ok<AGROW>
        trace.metadata=metadata;
        trajectories{episode,index}=trace;
        for k=1:size(trace.pwm,1)
            historical=plantE0HistoricalReference(trace.q(k,:),trace.pwm(k,:),.2,.14);
            difference=max(abs(historical-trace.plantTrajectory{k}),[],"all");
            assert(isequal(historical,trace.plantTrajectory{k}), ...
                "E2B:PlantRegression","La transicion difiere del oraculo E0.");
            [excess,entry]=jumpCharacterization(trace.q(k,:),trace.pwm(k,:),trace.q(k+1,:),curve.avgs);
            transitionRows{end+1}=merge(metadata,struct("step",k,"oracleMaxDifference",difference, ...
                "heuristicJumpExcesses",nnz(excess),"curveEntryExplained",nnz(excess & entry), ...
                "unexplainedJumpExcesses",nnz(excess & ~entry))); %#ok<AGROW>
        end
    end
    a=trajectories{episode,end};
    b=rolloutAbsent(actor,dataset.emgs{id.side},a.q(1,:),contract.seed);
    ab=compareTraces(a,b);
    abRows{end+1}=merge(table2struct(id),ab); %#ok<AGROW>
    trajectories{episode,end}.absent=b;
    nextState=a.state(end,:)'; nextAction=getAction(actor,{nextState});
    q1=double(getValue(critics(1),{nextState},nextAction));
    q2=double(getValue(critics(2),{nextState},nextAction));
    early=a.gloveExhausted && ~a.emgExhausted;
    doneRows{end+1}=merge(table2struct(id),struct("earlyTeacherTermination",early, ...
        "gamma",.95,"historicalDone",true,"emgOnlyDoneAtCommonEnd",a.emgExhausted, ...
        "onlineQ1",q1,"onlineQ2",q2,"onlineBootstrapSensitivity",.95*min(q1,q2)*double(early), ...
        "historicalRewardAtEnd",a.reward(end))); %#ok<AGROW>
    fprintf("E2B %d/%d %s rep%d lado%d: A=%d B=%d igualdad=%d\n", ...
        episode,height(selected),id.subject,id.repetition,id.side,ab.teacherSteps,ab.gloveFreeSteps,ab.exact);
end
metrics=struct2table([metricRows{:}]); motors=struct2table([motorRows{:}]);
comparisons=struct2table([abRows{:}]); doneSensitivity=struct2table([doneRows{:}]);
transitions=struct2table([transitionRows{:}]);
writetable(metrics,fullfile(out,"episode_metrics.csv"));
writetable(motors,fullfile(out,"episode_motor_metrics.csv"));
writetable(comparisons,fullfile(out,"causal_ab.csv"));
writetable(doneSensitivity,fullfile(out,"done_online_sensitivity.csv"));
writetable(transitions,fullfile(out,"transition_audit.csv"));
save(fullfile(out,"trajectories.mat"),"trajectories","selected","contract","-v7");
exportSteps(trajectories,out);
[macro,groups,motorSummary]=summarizeMetrics(metrics,motors,controllers);
writetable(macro,fullfile(out,"controller_summary.csv"));
writetable(groups,fullfile(out,"subject_side_summary.csv"));
writetable(motorSummary,fullfile(out,"motor_summary.csv"));
assert(isequaln(actorBefore,getLearnableParameters(actor)));
assert(isequaln(criticBefore{1},getLearnableParameters(critics(1))) && ...
    isequaln(criticBefore{2},getLearnableParameters(critics(2))));
tests=runtests(fullfile(root,"tests","paired_reference"));
testTable=table(tests);
writetable(testTable(:,["Name","Passed","Failed","Incomplete","Duration"]),fullfile(out,"test_results.csv"));
summary=evaluateGate(macro,groups,motorSummary,metrics,transitions,comparisons,tests);
summary.START_SHA=contract.startSHA;
summary.preregistrationSHA256=contract.preregistrationSHA256;
summary.inventoryEpisodes=height(inventory); summary.selectedEpisodes=height(selected);
summary.earlyTeacherEpisodes=nnz(inventory.earlyTeacherTermination);
summary.invalidInventoryRows=nnz(~inventory.valid);
summary.teacherDiscardedEmgFractionPooled=sum(inventory.teacherDiscardedEmgSamples(inventory.valid))/sum(inventory.nEmg(inventory.valid));
summary.teacherDiscardedEmgFractionMean=mean(inventory.teacherDiscardedEmgFraction,"omitnan");
summary.historicalMaxSteps50Reached=nnz(inventory.reachesHistoricalMaxSteps50);
summary.actorAndCriticParametersUnchanged=true;
summary.doneOnlineSensitivityLabel="ONLINE_FROZEN_NO_SMOOTHING_NOT_ACTUAL_TRAINING_TARGET";
summary.doneOnlineSensitivityMean=mean(doneSensitivity.onlineBootstrapSensitivity(doneSensitivity.earlyTeacherTermination));
summary.TRAINING_GLOVE_ROLE=contract.trainingGloveRole;
summary.TEACHER_TERMINATION_DECISION=contract.teacherTerminationDecision;
summary.E3_PREPARED=false; summary.E3_EXECUTED=false; summary.PUSH=false;
summary.MANUAL_COMMAND="NOT_PREPARED_E2B_FAIL";
if summary.RL_AUTHORIZED, summary.MANUAL_COMMAND="PENDING_REVIEWED_E3_PREPARATION"; end
writeJson(fullfile(out,"e2b_summary.json"),summary);
disp(summary);
end

function trace=rolloutTeacher(actor,data,side,controller,kp,seed)
rng(seed,"twister"); env=Env("",true,data.emgs,data.teachers);
for resetIndex=1:side, state=reset(env); end
trace=emptyTrace(state,env.motorData(end,:));
trace.referenceBefore=zeros(0,4); trace.reference=zeros(0,4); trace.prediction=zeros(0,4);
trace.reward=zeros(0,1); trace.plantTrajectory={}; done=false;
while ~done
    before=env.flexJoined_scaler(reduceFlexDimension(env.flexData));
    if controller=="ZERO", raw=zeros(4,1);
    elseif controller=="AGENT7250", raw=actorAction(actor,state);
    else, raw=e2bProportionalAction(env.motorData(end,:),env.flexData,kp); end
    [state,reward,done]=step(env,raw); k=env.c;
    trace=appendTrace(trace,state,raw,env.actionSatLog(k,:),env.actionPwmLog(k,:),env.motorData(end,:));
    trace.referenceBefore(k,:)=before(end,:); trace.reference(k,:)=env.flexConverted(end,:);
    trace.prediction(k,:)=env.adjustEnc(end,:); trace.reward(k,1)=reward;
    trajectory=env.encoderLog{k}; trace.plantTrajectory{k}=trajectory(2:end,:);
    assert(k<1000,"E2B:Runaway","Horizonte inesperado.");
end
trace.emgExhausted=env.myo.exhausted; trace.gloveExhausted=env.glove.exhausted;
end

function trace=rolloutAbsent(actor,emg,q0,seed)
rng(seed,"twister"); runtime=GloveFreePolicyRuntime(emg,q0,purpose="causalEvaluation");
trace=emptyTrace(runtime.state,runtime.q);
while ~runtime.exhausted
    raw=actorAction(actor,runtime.state);
    [state,~,record]=runtime.advance(raw);
    trace=appendTrace(trace,state,raw,record.effectiveAction,record.pwm,record.q);
end
trace.emgExhausted=runtime.exhausted;
end

function value=actorAction(actor,state)
value=getAction(actor,{state}); if iscell(value),value=cell2mat(value);end
value=double(value(:));
end
function trace=emptyTrace(state,q)
trace=struct("state",state',"q",q,"rawAction",zeros(0,4),"effectiveAction",zeros(0,4),"pwm",zeros(0,4));
end
function trace=appendTrace(trace,state,raw,effective,pwm,q)
trace.state(end+1,:)=state'; trace.q(end+1,:)=q;
trace.rawAction(end+1,:)=raw(:)'; trace.effectiveAction(end+1,:)=effective(:)'; trace.pwm(end+1,:)=pwm(:)';
end
function result=compareTraces(a,b)
n=min(size(a.rawAction,1),size(b.rawAction,1));
result=struct("teacherSteps",size(a.rawAction,1),"gloveFreeSteps",size(b.rawAction,1),"commonHorizon",n,"exact",true);
for field=["state","rawAction","effectiveAction","pwm","q"]
    count=n+double(ismember(field,["state","q"]));
    x=a.(field)(1:count,:);y=b.(field)(1:count,:);
    result.("maxDiff_"+field)=max(abs(x-y),[],"all"); result.exact=result.exact && isequal(x,y);
end
end
function result=merge(a,b)
result=a; for field=string(fieldnames(b))',result.(field)=b.(field);end
end
function value=getCell(data,row,column)
if row<=size(data,1)&&column<=size(data,2),value=data{row,column};else,value=[];end
end

function folder=makeOracleFixture(root)
% Fixture de prueba E0 con ws vacios; no altera ni reconstruye el fit real.
folder=string(tempname);mkdir(folder);
copyfile(fullfile(root,"tests","paired_reference","fixtures","plantE0HistoricalReference.m"),folder);
copyfile(fullfile(root,"src","@SimController","pattern_curve.mat"),folder);
limits=readtable(fullfile(root,"src","@SimController","plant_limits_canonical.csv"),TextType="string");
params=struct(); tail_length=0;
for row=1:height(limits)
    params.(limits.speed_field(row)).(limits.direction(row)).("m_"+limits.motor(row))= ...
        struct("ws",[],"min_lim",limits.min_lim(row),"max_lim",limits.max_lim(row));
end
save(fullfile(folder,"fit_C2.mat"),"params","tail_length");
end

function [excess,entry]=jumpCharacterization(q,pwm,next,avgs)
excess=false(1,4);entry=false(1,4);
levels=[64 96 128 160 192 224 255]; fields=["sp_3F","sp_5F","sp_7F","sp_9F","sp_BF","sp_DF","sp_FF"];
for m=1:4
    if pwm(m)==0,continue;end
    index=find(levels==abs(pwm(m)),1); assert(~isempty(index));
    direction="closing";if pwm(m)<0,direction="opening";end
    c=avgs.(fields(index)).(direction).("m_"+m).avg;
    offset=min(200,numel(c)-1);
    bound=1.5*max(abs(c(1+offset:end)-c(1:end-offset)));
    excess(m)=abs(next(m)-q(m))>bound+1e-9;
    entry(m)=(c(1)-q(m))*sign(pwm(m))>0;
end
end

function result=availabilitySummary(inventory)
rows={};
for subject=unique(inventory.subject)'
    for side=1:2
        t=inventory(inventory.subject==subject & inventory.side==side,:);
        row=struct("subject",subject,"side",side,"episodes",height(t),"validLengths",nnz(t.valid), ...
            "eligibleForControl",nnz(t.eligibleForControl),"earlyTeacherEpisodes",nnz(t.earlyTeacherTermination), ...
            "earlyTeacherFraction",mean(t.earlyTeacherTermination), ...
            "emgLengthMin",min(t.nEmg),"emgLengthMedian",median(t.nEmg),"emgLengthMax",max(t.nEmg), ...
            "teacherLengthMin",min(t.nGlove),"teacherLengthMedian",median(t.nGlove),"teacherLengthMax",max(t.nGlove), ...
            "historicalHorizonMean",mean(t.hHistorical,"omitnan"),"emgHorizonMean",mean(t.hEmg,"omitnan"), ...
            "discardedEmgFractionMean",mean(t.teacherDiscardedEmgFraction,"omitnan"), ...
            "discardedEmgFractionPooled",sum(t.teacherDiscardedEmgSamples,"omitnan")/sum(t.nEmg,"omitnan"), ...
            "discardedEmgFractionMedian",median(t.teacherDiscardedEmgFraction,"omitnan"), ...
            "discardedEmgFractionMax",max(t.teacherDiscardedEmgFraction), ...
            "teacherOnly",nnz(t.terminationCause=="TEACHER_ONLY"), ...
            "emgOnly",nnz(t.terminationCause=="EMG_ONLY"),"both",nnz(t.terminationCause=="EMG_AND_TEACHER"));
        rows{end+1}=row; %#ok<AGROW>
    end
end
result=struct2table([rows{:}]);
end

function [macro,groups,motorSummary]=summarizeMetrics(metrics,motors,controllers)
metricNames=setdiff(string(metrics.Properties.VariableNames), ...
    ["subject","repetition","side","controller","kp","steps"],"stable");
rows={}; motorRows={}; summaryRows={};
for controller=controllers
    for subject=unique(metrics.subject)'
        for side=1:2
            mask=metrics.controller==controller & metrics.subject==subject & metrics.side==side;
            row=struct("controller",controller,"subject",subject,"side",side);
            for field=metricNames,row.(field)=mean(metrics.(field)(mask),"omitnan");end
            rows{end+1}=row; %#ok<AGROW>
        end
    end
end
groups=struct2table([rows{:}]);
for controller=controllers
    mask=groups.controller==controller; row=struct("controller",controller);
    for field=metricNames,row.(field)=mean(groups.(field)(mask),"omitnan");end
    summaryRows{end+1}=row; %#ok<AGROW>
    for motor=1:4
        groupMeans=zeros(20,numel(metricNames));g=0;
        for subject=unique(motors.subject)'
            for side=1:2
                g=g+1;mask=motors.controller==controller & motors.subject==subject & motors.side==side & motors.motor==motor;
                for j=1:numel(metricNames),groupMeans(g,j)=mean(motors.(metricNames(j))(mask),"omitnan");end
            end
        end
        row=struct("controller",controller,"motor",motor);
        for j=1:numel(metricNames),row.(metricNames(j))=mean(groupMeans(:,j),"omitnan");end
        motorRows{end+1}=row; %#ok<AGROW>
    end
end
macro=struct2table([summaryRows{:}]);motorSummary=struct2table([motorRows{:}]);
end

function summary=evaluateGate(macro,groups,motors,metrics,transitions,ab,tests)
pRows=macro(startsWith(macro.controller,"P_"),:);
minimum=min(pRows.trackingMSE); candidates=find(abs(pRows.trackingMSE-minimum)<=1e-12);
[~,tie]=max(pRows.rewardMean(candidates));best=pRows(candidates(tie),:); % orden Kp ascendente resuelve empate final
zero=macro(macro.controller=="ZERO",:); bestKp=str2double(extractAfter(best.controller,"P_"));
msePass=best.trackingMSE<=.9*zero.trackingMSE; rewardPass=best.rewardMean>zero.rewardMean+1e-12;
subjectWins=0; directionPass=true;
for subject=unique(groups.subject)'
    p=groups(groups.subject==subject & groups.controller==best.controller,:);
    z=groups(groups.subject==subject & groups.controller=="ZERO",:);
    subjectWins=subjectWins+double(mean(p.trackingMSE)<mean(z.trackingMSE) && mean(p.rewardMean)>mean(z.rewardMean));
end
for side=1:2
    p=groups(groups.side==side & groups.controller==best.controller,:);
    z=groups(groups.side==side & groups.controller=="ZERO",:);
    directionPass=directionPass && mean(p.trackingMSE)<mean(z.trackingMSE) && mean(p.rewardMean)>mean(z.rewardMean);
end
p=motors(motors.controller==best.controller,:);z=motors(motors.controller=="ZERO",:);
motorWins=nnz(p.trackingMSE<z.trackingMSE);
motorNoHarm=all((z.trackingMSE>1e-12 & p.trackingMSE<=1.05*z.trackingMSE) | ...
    (z.trackingMSE<=1e-12 & p.trackingMSE<=1e-12));
cycles=sum(metrics.persistentTwoCycle(metrics.controller==best.controller));
names=string({tests.Name});
e2aMask=contains(names,"GloveFreeExecution");
e0pMask=contains(names,"PlantCanonicalSource") | contains(names,"PlantHoldOutsideCurve") | contains(names,"Stage0PlantSanity");
summary=struct("ZERO_POLICY_MSE",zero.trackingMSE,"P_BEST_KP",bestKp,"P_CONTROLLER_MSE",best.trackingMSE, ...
    "P_MSE_RELATIVE_IMPROVEMENT",1-best.trackingMSE/zero.trackingMSE, ...
    "ZERO_REWARD_MEAN",zero.rewardMean,"P_REWARD_MEAN",best.rewardMean, ...
    "P_BEATS_ZERO",msePass,"P_REWARD_BEATS_ZERO",rewardPass, ...
    "P_SUBJECT_WINS",subjectWins,"P_DIRECTION_COHERENT",directionPass,"P_MOTOR_WINS",motorWins, ...
    "P_NO_MOTOR_HARM_ABOVE_5_PERCENT",motorNoHarm,"P_PERSISTENT_TWO_CYCLES",cycles, ...
    "DIRECTION_FAILURES",sum(metrics.directionFailures),"ZERO_MOTION_FAILURES",sum(metrics.zeroMotionFailures), ...
    "E0_TRANSITION_MAX_ERROR",max(transitions.oracleMaxDifference), ...
    "UNEXPLAINED_JUMP_EXCESSES",sum(transitions.unexplainedJumpExcesses), ...
    "KNOWN_CURVE_ENTRY_EXCESSES",sum(transitions.curveEntryExplained), ...
    "CAUSAL_AB_EXACT",all(ab.exact),"E2A_REGRESSION",nnz(e2aMask)==13 && all([tests(e2aMask).Passed]), ...
    "E0P_REGRESSION",nnz(e0pMask)==24 && all([tests(e0pMask).Passed]),"TESTS",numel(tests),"TESTS_PASSED",nnz([tests.Passed]), ...
    "GLOVE_IN_OBSERVATION",false,"GLOVE_IN_ACTOR_INPUT",false,"GLOVE_IN_PLANT_TRANSITION",false, ...
    "GLOVE_IN_REWARD",true,"GLOVE_IN_TERMINATION",true,"GLOVE_IN_RESET_AVAILABILITY",true, ...
    "TRAIN_RUNTIME_MISMATCH_QUANTIFIED",true,"AGENT7250_DIAGNOSTIC_ONLY",true, ...
    "MATEO_SANDRA_SEALED",true,"FINAL_TEST_EXECUTED",false,"E2B_RESULT","FAIL","RL_AUTHORIZED",false);
passed=msePass && rewardPass && subjectWins>=8 && directionPass && motorWins>=3 && motorNoHarm && ...
    cycles==0 && summary.DIRECTION_FAILURES==0 && summary.ZERO_MOTION_FAILURES==0 && ...
    summary.UNEXPLAINED_JUMP_EXCESSES==0 && summary.E0_TRANSITION_MAX_ERROR==0 && ...
    summary.CAUSAL_AB_EXACT && summary.E2A_REGRESSION && summary.E0P_REGRESSION && all([tests.Passed]);
if passed,summary.E2B_RESULT="PASS";summary.RL_AUTHORIZED=true;end
end

function exportSteps(traces,out)
stepTables=cell(size(traces));pwmRows={};
for episode=1:size(traces,1)
    for controller=1:size(traces,2)
        trace=traces{episode,controller};n=size(trace.pwm,1);m=trace.metadata;
        metadata=table(repmat(m.subject,n,1),repmat(m.repetition,n,1),repmat(m.side,n,1), ...
            repmat(m.controller,n,1),(1:n)',VariableNames=["subject","repetition","side","controller","step"]);
        u=trace.effectiveAction;du=[u(1,:);diff(u,1,1)];
        values=[trace.q(1:n,:) trace.q(2:end,:) trace.referenceBefore trace.reference trace.prediction ...
            trace.rawAction u trace.pwm trace.reward -mean((trace.prediction-trace.reference).^2,2) ...
            .01*mean(u.^2,2) .05*mean(du.^2,2)];
        names=["qBefore_"+(1:4),"qAfter_"+(1:4),"referenceBefore_"+(1:4),"reference_"+(1:4), ...
            "prediction_"+(1:4),"raw_"+(1:4),"effective_"+(1:4),"pwm_"+(1:4), ...
            "reward","trackingTerm","actionPenalty","deltaActionPenalty"];
        stepTables{episode,controller}=[metadata array2table(values,VariableNames=names)];
        for motor=1:4
            for level=[-255 -224 -192 -160 -128 -96 -64 0 64 96 128 160 192 224 255]
                count=nnz(trace.pwm(:,motor)==level);
                pwmRows{end+1}=merge(m,struct("motor",motor,"pwm",level,"count",count,"fraction",count/n)); %#ok<AGROW>
            end
        end
    end
end
writetable(vertcat(stepTables{:}),fullfile(out,"step_traces.csv"));
writetable(struct2table([pwmRows{:}]),fullfile(out,"pwm_distribution.csv"));
end
function writeJson(file,value)
fid=fopen(file,"w","n","UTF-8");assert(fid>=0);cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
function hash=sha256(file)
fid=fopen(file,"rb");assert(fid>=0);cleanup=onCleanup(@() fclose(fid));
digest=java.security.MessageDigest.getInstance("SHA-256");digest.update(fread(fid,inf,"*uint8"));
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),"uint8"),2)',1,[])));
end
function restoreContext(override,hadOverride,rngState,oldPath)
if hadOverride,setConfigurablesOverride(override);else,clearConfigurablesOverride();end
rng(rngState);path(oldPath);
end
