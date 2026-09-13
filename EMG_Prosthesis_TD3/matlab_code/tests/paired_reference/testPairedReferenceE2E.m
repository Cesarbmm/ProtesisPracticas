function tests=testPairedReferenceE2E
% Contrato causal y reproduccion E2E; un gate cientifico fallido no se oculta.
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.TestData.root=root;t.TestData.oldPath=path;
assert(~contains(lower(string(path)),"sandbox"),"E2E:ForbiddenPath");
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
t.TestData.hadOverride=isappdata(0,"configurables_override");t.TestData.oldOverride=struct();
if t.TestData.hadOverride,t.TestData.oldOverride=getappdata(0,"configurables_override");end
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false, ...
    "plotEpisodeOnTest",false,"simPlantSource","patternCurveCanonical", ...
    "actionInterfaceVariant","baselineQuantized"));
[t.TestData.remap,t.TestData.remapCleanup]=e2cHistoricalRemapper(root);
out=fullfile(root,"analysis","paired_reference","e2e_results");
if isappdata(0,"E2ETestOutputDirectory"),out=getappdata(0,"E2ETestOutputDirectory");end
t.TestData.out=out;t.TestData.data=struct();
if isfile(fullfile(out,"trajectories.mat"))
    t.TestData.data=load(fullfile(out,"trajectories.mat"),"trajectories","baselines");
end
end

function teardownOnce(t)
if t.TestData.hadOverride,setConfigurablesOverride(t.TestData.oldOverride);else,clearConfigurablesOverride();end
t.TestData.remapCleanup=[];path(t.TestData.oldPath);
end

function testGuardOffCopiesDesiredWithoutNeutralizing(t)
[a,p,e]=e2eReversalGuard([-224 64 0 96],[96 -64 255 0],[0 0 0 -1],false);
verifyEqual(t,a,[-224 64 0 96]);verifyEqual(t,p,zeros(1,4));
verifyEqual(t,e.request,[true true false false]);
verifyFalse(t,any(e.neutralized|e.confirmed|e.cancelled));
end

function testRequestRequiresTwoNonzeroOppositeSigns(t)
[a,p,e]=e2eReversalGuard([64 -64 0 96],[-255 -96 255 0],zeros(1,4),true);
verifyEqual(t,e.request,[true false false false]);
verifyEqual(t,e.neutralized,e.request);verifyEqual(t,a,[0 -64 0 96]);
verifyEqual(t,p,[1 0 0 0]);
end

function testFirstReversalInsertsExactlyOneNeutralStep(t)
[a,p,e]=e2eReversalGuard(-64,224,0,true);
verifyEqual(t,a,0);verifyEqual(t,p,-1);verifyTrue(t,e.neutralized);
[a,p,e]=e2eReversalGuard(-96,a,p,true);
verifyEqual(t,a,-96);verifyEqual(t,p,0);verifyTrue(t,e.confirmed);
verifyFalse(t,e.neutralized);verifyFalse(t,e.request);
end

function testConfirmationUsesRecalculatedMagnitude(t)
[a,p]=e2eReversalGuard(64,-224,0,true);
[a,p,e]=e2eReversalGuard(255,a,p,true);
verifyEqual(t,a,255);verifyEqual(t,p,0);verifyTrue(t,e.confirmed);
end

function testOppositeRequestIsCancelledWithoutForcedReversal(t)
[a,p]=e2eReversalGuard(-64,224,0,true);
[a,p,e]=e2eReversalGuard(96,a,p,true);
verifyEqual(t,a,96);verifyEqual(t,p,0);verifyTrue(t,e.cancelled);
verifyFalse(t,e.confirmed|e.neutralized);
end

function testZeroCancelsPendingWithoutRememberingOldTarget(t)
[a,p]=e2eReversalGuard(-64,224,0,true);
[a,p,e]=e2eReversalGuard(0,a,p,true);
verifyEqual(t,a,0);verifyEqual(t,p,0);verifyTrue(t,e.cancelled);
[a,p,e]=e2eReversalGuard(-96,a,p,true);
verifyEqual(t,a,-96);verifyEqual(t,p,0);verifyFalse(t,e.neutralized|e.confirmed);
end

function testIndependentMotorStates(t)
[a,p,e]=e2eReversalGuard([-64 224 0 96],[224 0 0 -64],[0 1 -1 0],true);
verifyEqual(t,a,[0 224 0 0]);verifyEqual(t,p,[-1 0 0 1]);
verifyEqual(t,e.neutralized,[true false false true]);
verifyEqual(t,e.confirmed,[false true false false]);
verifyEqual(t,e.cancelled,[false false true false]);
end

function testPendingCannotCoexistWithNonzeroPreviousApplied(t)
verifyError(t,@() e2eReversalGuard(64,96,1,true),"E2E:InvalidPendingState");
verifyError(t,@() e2eReversalGuard(64,0,2,true),"E2E:InvalidPendingSign");
end

function testGuardNeverInventsSignOrMagnitude(t)
for enabled=[false true]
    for desired=[-255 -96 -64 0 64 96 255]
        for previous=[-224 0 224]
            [a,~,~]=e2eReversalGuard(desired,previous,0,enabled);
            verifyTrue(t,a==desired || a==0);
        end
    end
end
end

function testPureGuardHasNoPrivilegedDataInterfaceOrAccess(t)
verifyEqual(t,nargin("e2eReversalGuard"),4);
source=fileread(which("e2eReversalGuard"));
verifyEmpty(t,regexpi(source,'\b(glove|teacher|reference|reward|encoder|configurables|getappdata|evalin|global|load|fopen)\b','once'));
[a,p,e]=e2eReversalGuard([-64 96 0 224],[224 -64 0 0],zeros(1,4),true);
setappdata(0,"E2ETeacherSentinel",[-100 100 NaN Inf]);
cleanup=onCleanup(@() rmappdata(0,"E2ETeacherSentinel")); %#ok<NASGU>
[b,q,f]=e2eReversalGuard([-64 96 0 224],[224 -64 0 0],zeros(1,4),true);
verifyEqual(t,a,b);verifyEqual(t,p,q);verifyEqual(t,e,f);
end

function testGuardDeterminismAndUnresolvedPendingConservation(t)
desired=[224 -64 -96 224 -64 0 96 -64];
[a,p,e]=guardSequence(desired);[b,q,f]=guardSequence(desired);
verifyEqual(t,a,b);verifyEqual(t,p,q);verifyEqual(t,e,f);
verifyEqual(t,nnz(e.neutralized),nnz(e.confirmed)+nnz(e.cancelled)+nnz(p(end)~=0));
verifyEqual(t,maxConsecutive(e.neutralized),1);
end

function testHistoricalCycleDetectorStillFindsOriginalPair(t)
[q,pwm]=twoCycle();mask=e2dCycleScan(q,pwm);
verifyTrue(t,mask(end,3));verifyEqual(t,nnz(mask),1);
pwm(2,3)=0;verifyFalse(t,any(e2dCycleScan(q,pwm),"all"));
end

function testFixedOrbitDetectsOriginalPeriodTwo(t)
[q,previous,pending,pwm]=syntheticOrbit(false);
[period,persistentReversals]=e2eFixedOrbit(q,previous,pending,pwm,3);
verifyEqual(t,period,2);verifyTrue(t,persistentReversals);
end

function testFixedOrbitFindsPeriodFourWithNeutralPauses(t)
[q,previous,pending,pwm]=syntheticOrbit(true);
[period,persistentReversals]=e2eFixedOrbit(q,previous,pending,pwm,3);
verifyEqual(t,period,4);verifyTrue(t,persistentReversals);
verifyFalse(t,any(e2dCycleScan(q,pwm),"all"));
end

function testFixedOrbitRequiresRepeatedAugmentedState(t)
[q,previous,pending,pwm]=syntheticOrbit(true);
pending(end-1,3)=0;
[period,~]=e2eFixedOrbit(q,previous,pending,pwm,3);
verifyEqual(t,period,0);
end

function testFixedOrbitRejectsHoldAndSmallMotion(t)
[q,previous,pending,pwm]=syntheticOrbit(true);q(:,3)=1541;
[period,~]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyEqual(t,period,0);
q(2:2:end,3)=1542;
[period,~]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyEqual(t,period,0);
end

function testFixedOrbitRequiresFullThirtyTwoDecisionTail(t)
[q,previous,pending,pwm]=syntheticOrbit(true);
[period,~]=e2eFixedOrbit(q(1:32,:),previous(1:31,:),pending(1:31,:),pwm(1:31,:),3);
verifyEqual(t,period,0);
end

function testFixedOrbitPositionToleranceAndExactActionMemory(t)
[q,previous,pending,pwm]=syntheticOrbit(true);q(end-1,3)=q(end-1,3)+2e-9;
[period,~]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyEqual(t,period,0);
[q,previous,pending,pwm]=syntheticOrbit(true);previous(end,3)=previous(end,3)+1e-10;
[period,~]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyEqual(t,period,0);
end

function testFixedOrbitPersistentRequiresFourSignChanges(t)
q=zeros(21,4);previous=zeros(20,4);pending=zeros(20,4);pwm=zeros(20,4);
pwm(1:4,3)=[64;-64;64;-64];
[~,persistentReversals]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyFalse(t,persistentReversals);
pwm(5,3)=64;
[~,persistentReversals]=e2eFixedOrbit(q,previous,pending,pwm,3);verifyTrue(t,persistentReversals);
end

function testRecordedOffMatchesExactTwoHundredEpisodeBaseline(t)
d=measured(t);verifySize(t,d.trajectories,[200 2]);verifyEqual(t,numel(d.baselines),200);
for k=1:200
    a=d.trajectories{k,1};b=d.baselines{k};
    for field=["q","rawAction","effectiveAction","pwm","referenceBefore","reference","prediction"]
        verifyEqual(t,a.(field),b.(field));
    end
    verifyEqual(t,a.reward,b.reward,"AbsTol",1e-12);
end
end

function testRecordedOffPreservesScientificBaseline(t)
d=measured(t);mse=zeros(200,1);reward=zeros(200,1);cycles=0;
for k=1:200
    [~,a]=e2bControlMetrics(d.trajectories{k,1});mse(k)=a.trackingMSE;reward(k)=a.rewardMean;
    cycles=cycles+a.persistentTwoCycle;
end
verifyEqual(t,mean(mse),.025400336373607925,"AbsTol",1e-12);
verifyEqual(t,mean(reward),-.03272837710980499,"AbsTol",1e-12);verifyEqual(t,cycles,2);
end

function testRecordedDesiredActionsUseHistoricalPAndRemapper(t)
d=measured(t);
for index=1:numel(d.trajectories)
    tr=d.trajectories{index};h=encoder2Flex(tr.q(1:end-1,:))./[4092 2046 1023 2046];
    raw=min(max(2*(tr.referenceBefore-h),-1),1);verifyEqual(t,tr.rawAction,raw);
    [effective,pwm]=t.TestData.remap(raw(:));
    verifyEqual(t,tr.desiredPwm,reshape(pwm,size(raw)));
    verifyEqual(t,tr.desiredEffectiveAction,reshape(effective,size(raw)));
end
end

function testRecordedGuardEventsAndMemoryMatchCausalHelper(t)
d=measured(t);
for j=1:2
    for k=1:200
        tr=d.trajectories{k,j};previous=zeros(1,4);pending=zeros(1,4);
        for step=1:size(tr.pwm,1)
            verifyEqual(t,tr.previousAppliedPwm(step,:),previous);verifyEqual(t,tr.pendingBefore(step,:),pending);
            [applied,next,event]=e2eReversalGuard(tr.desiredPwm(step,:),previous,pending,j==2);
            verifyEqual(t,tr.pwm(step,:),applied);verifyEqual(t,tr.pendingAfter(step,:),next);
            for field=["request","neutralized","confirmed","cancelled"]
                verifyEqual(t,tr.(field)(step,:),event.(field));
            end
            previous=applied;pending=next;
        end
        if j==2
            verifyEqual(t,nnz(tr.neutralized),nnz(tr.confirmed)+nnz(tr.cancelled)+nnz(pending~=0));
        end
    end
end
end

function testRecordedNeutralizationLastsOnlyOneDecision(t)
d=measured(t);
for k=1:200
    tr=d.trajectories{k,2};verifyFalse(t,any(tr.neutralized(1:end-1,:) & tr.neutralized(2:end,:),"all"));
    verifyEqual(t,tr.pwm(tr.neutralized),zeros(nnz(tr.neutralized),1));
    verifyEqual(t,tr.pwm(~tr.neutralized),tr.desiredPwm(~tr.neutralized));
end
end

function testRecordedPlantUsesUnchangedCanonicalApi(t)
d=measured(t);
for episode=unique(round(linspace(1,200,10)))
    for j=1:2
        tr=d.trajectories{episode,j};
        for k=1:size(tr.pwm,1)
            next=SimController.prosthesis_simulator(tr.q(k,:),tr.pwm(k,:),.2,.14,plantSource="patternCurveCanonical");
            verifyEqual(t,next(end,:),tr.q(k+1,:));
        end
    end
end
end

function testRecordedPwmZeroNeverMovesThePlant(t)
d=measured(t);
for index=1:numel(d.trajectories)
    tr=d.trajectories{index};delta=diff(tr.q);
    % Un episodio sin PWM0 no aporta violaciones; el máximo vacío no es un dato.
    verifyEqual(t,nnz(tr.pwm==0 & abs(delta)>1e-9),0);
end
end

function testRecordedRewardUsesAppliedActionIncludingNeutralStep(t)
d=measured(t);
for index=1:numel(d.trajectories)
    tr=d.trajectories{index};previous=zeros(1,4);verifyEqual(t,tr.effectiveAction,tr.pwm/255);
    for k=1:size(tr.pwm,1)
        context=struct("flexConverted",tr.reference(k,:),"adjustEnc",tr.prediction(k,:),"prevAction",previous);
        reward=trackingMseActionRateReward(context,tr.effectiveAction(k,:),[]);
        verifyEqual(t,tr.reward(k),reward,"AbsTol",1e-12);
        previous=tr.effectiveAction(k,:);
    end
end
end

function testRecordedCyclesKeepHistoricalDefinition(t)
d=measured(t);
for index=1:numel(d.trajectories)
    tr=d.trajectories{index};mask=e2dCycleScan(tr.q,tr.pwm);[mot,~]=e2bControlMetrics(tr);
    verifyEqual(t,tr.cycleMask,mask);verifyEqual(t,mask(end,:),logical([mot.persistentTwoCycle]));
end
end

function testKnownBlancaAndIvannaOffCyclesAreReproduced(t)
d=measured(t);found=false(1,2);
for k=1:200
    tr=d.trajectories{k,1};md=tr.metadata;
    if md.subject=="BLANCA" && md.repetition==1 && md.side==1
        verifyEqual(t,tr.pwm(end-3:end,3),[224;-64;224;-64]);verifyTrue(t,tr.cycleMask(end,3));found(1)=true;
    end
    if md.subject=="IVANNA" && md.repetition==104 && md.side==2
        verifyEqual(t,tr.pwm(end-3:end,4),[-64;96;-64;96]);verifyTrue(t,tr.cycleMask(end,4));found(2)=true;
    end
end
verifyTrue(t,all(found));
end

function testMeasuredM3ReversalCountsRemainVisible(t)
d=measured(t);gates=readtable(fullfile(t.TestData.out,"candidate_gates.csv"));
for j=1:2
    count=0;
    for k=1:200,tr=d.trajectories{k,j};count=count+nnz(tr.pwm(:,3)>0 & diff(tr.q(:,3))<0);end
    verifyEqual(t,gates.m3Reversals(gates.enabled==j-1),count);
    if j==1,verifyEqual(t,count,0);end
end
end

function testFixedReferenceDiagnosticsMatchTheirStoredTraces(t)
d=load(fullfile(t.TestData.out,"diagnostic_artifacts.mat"),"fixedTrajectories");
T=readtable(fullfile(t.TestData.out,"fixed_reference_summary.csv"));
verifySize(t,d.fixedTrajectories,[20 2]);verifyEqual(t,height(T),40);
for index=1:20
    caseId=ceil(index/10);motor=caseId+2;referenceIndex=floor(mod(index-1,10)/2)+1;initialStateIndex=mod(index-1,2)+1;
    for j=1:2
        tr=d.fixedTrajectories{index,j};[period,persistentReversals]=e2eFixedOrbit(tr.q,tr.previousAppliedPwm,tr.pendingBefore,tr.pwm,motor);
        row=T(T.enabled==j-1 & T.caseId==caseId & T.referenceIndex==referenceIndex & T.initialStateIndex==initialStateIndex,:);
        verifyEqual(t,height(row),1);verifyEqual(t,row.period,period);verifyEqual(t,logical(row.persistentReversals),persistentReversals);
        verifyEqual(t,row.neutralSteps,nnz(tr.neutralized(:,motor)));
    end
end
end

function testRolloutDeterminism(t)
d=measured(t);base=d.baselines{1};
a=e2eRollout(base,true,t.TestData.remap);b=e2eRollout(base,true,t.TestData.remap);
for field=["q","rawAction","pwm","effectiveAction","pendingBefore","pendingAfter","request","neutralized","confirmed","cancelled","reward"]
    verifyEqual(t,a.(field),b.(field));verifyEqual(t,a.(field),d.trajectories{1,2}.(field));
end
end

function testAllPreregisteredGatesAreRequired(t)
f=passingFacts();g=e2eCandidateGate(f);verifyTrue(t,g.passed);
fields=["cycles","newCycles","mseChangePct","rewardChangePct","subjectDegradations", ...
    "maxFlatIncrease","maxNoMotionIncrease","neutralStepFractionOfActiveBaseline","m3Reversals","zeroMotionFailures"];
values=[1 1 5.0001 5.0001 3 .020001 .050001 .100001 1 1];
for k=1:numel(fields)
    changed=f;changed.(fields(k))=values(k);g=e2eCandidateGate(changed);
    verifyFalse(t,g.("pass"+char('A'+k-1)));verifyFalse(t,g.passed);
end
end

function testGateBoundariesAndUndefinedMotionAreExplicit(t)
f=passingFacts();f.mseChangePct=5;f.rewardChangePct=5;f.subjectDegradations=2;f.motorDegradations=1;
f.maxFlatIncrease=.02;f.maxNoMotionIncrease=.05;f.neutralStepFractionOfActiveBaseline=.10;
g=e2eCandidateGate(f);verifyTrue(t,g.passed);
f.noMotionDefined=false;g=e2eCandidateGate(f);verifyFalse(t,g.passG);
f.noMotionDefined=true;f.flatDefined=false;g=e2eCandidateGate(f);verifyFalse(t,g.passF);
f.flatDefined=true;f.directionDegradations=1;g=e2eCandidateGate(f);verifyFalse(t,g.passE);
end

function testStoredGateFlagsAreRecomputableWithoutRescuingFailures(t)
T=readtable(fullfile(t.TestData.out,"candidate_gates.csv"));
for row=1:height(T)
    f=table2struct(T(row,:));g=e2eCandidateGate(f);
    for name=string(fieldnames(g))',verifyEqual(t,logical(T.(name)(row)),g.(name));end
end
end

function testHistoricalHashesAndPreregistrationExistUnchanged(t)
manifest=readtable(fullfile(t.TestData.out,"historical_hashes_before.csv"),TextType="string");
verifyGreaterThanOrEqual(t,height(manifest),539);
verifyTrue(t,any(contains(manifest.path,"e2d_results")));
for k=1:height(manifest)
    verifyFalse(t,contains(lower(manifest.path(k)),"sandbox"));
    verifyEqual(t,e2cSHA256(fullfile(t.TestData.root,manifest.path(k))),manifest.sha256(k));
end
verifyTrue(t,isfile(fullfile(fileparts(t.TestData.root),"docs","paired_reference","PREREGISTRO_E2E.md")));
end

function testHistoricalParametersAndNoRlStayIntact(t)
p=configurables();verifyEqual(t,p.period,.2);verifyEqual(t,p.observationVariant,"markov52");
verifyEqual(t,p.actionInterfaceVariant,"baselineQuantized");verifyEqual(t,p.simPlantSource,"patternCurveCanonical");
verifyEqual(t,p.actionCommandLevels,[0 64 96 128 160 192 224 255]);verifyEqual(t,p.actionCommandActivationThreshold,.05);
verifyEqual(t,p.speeds,[255 255 255 255]);verifyEqual(t,p.rewardActionWeight,.01);verifyEqual(t,p.rewardDeltaActionWeight,.05);
verifyFalse(t,p.run_training);
end

function d=measured(t)
d=t.TestData.data;assert(isfield(d,"trajectories") && isfield(d,"baselines"),"E2E:MissingMeasurements");
end

function [applied,pending,events]=guardSequence(desired)
applied=zeros(size(desired));pending=zeros(size(desired));previous=0;state=0;
events=struct("neutralized",false(size(desired)),"confirmed",false(size(desired)),"cancelled",false(size(desired)));
for k=1:numel(desired)
    [applied(k),pending(k),event]=e2eReversalGuard(desired(k),previous,state,true);
    for field=string(fieldnames(events))',events.(field)(k)=event.(field);end
    previous=applied(k);state=pending(k);
end
end

function n=maxConsecutive(flags)
n=0;current=0;for flag=flags,if flag,current=current+1;n=max(n,current);else,current=0;end,end
end

function [q,pwm]=twoCycle()
q=zeros(5,4);q(:,3)=[1541.6666666666667;7532.5;1541.6666666666667;7532.5;1541.6666666666667];
pwm=zeros(4,4);pwm(:,3)=[224;-64;224;-64];
end

function [q,previous,pending,pwm]=syntheticOrbit(withPauses)
A=1541.6666666666667;B=7532.5;n=40;q=zeros(n+1,4);previous=zeros(n,4);pending=zeros(n,4);pwm=zeros(n,4);
if withPauses
    q(:,3)=[repmat([A;B;B;A],n/4,1);A];
    pwm(:,3)=repmat([224;0;-64;0],n/4,1);
    previous(:,3)=repmat([0;224;0;-64],n/4,1);
    pending(:,3)=repmat([1;0;-1;0],n/4,1);
else
    q(:,3)=[repmat([A;B],n/2,1);A];
    pwm(:,3)=repmat([224;-64],n/2,1);previous(:,3)=repmat([-64;224],n/2,1);
end
end

function f=passingFacts()
f=struct("cycles",0,"newCycles",0,"mseChangePct",0,"rewardChangePct",0, ...
    "subjectDegradations",0,"motorDegradations",0,"directionDegradations",0, ...
    "maxFlatIncrease",0,"maxNoMotionIncrease",0,"flatDefined",true,"noMotionDefined",true, ...
    "neutralStepFractionOfActiveBaseline",0,"m3Reversals",0,"zeroMotionFailures",0);
end
