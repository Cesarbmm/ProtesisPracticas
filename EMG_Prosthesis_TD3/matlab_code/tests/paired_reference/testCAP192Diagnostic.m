function tests=testCAP192Diagnostic
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));pr=fullfile(root,"analysis","paired_reference");out=fullfile(pr,"cap192_results");
oldPath=path;t.addTeardown(@() path(oldPath));addpath(root,pr,fullfile(pr,"cap192"),fullfile(pr,"e3ax"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
t.TestData.root=root;t.TestData.out=out;t.TestData.pr=pr;
t.TestData.run=fullfile(root,"results","e3ax_long","run_20260908_141321_916_6ebf347b");
for label=["BEST_OFF","BEST_CAP192","LAST_OFF","LAST_CAP192"],t.TestData.(label)=load(fullfile(out,label,"trajectories.mat"));end
t.TestData.measured=load(fullfile(out,"measurements.mat"));
end
function setup(t)
oldRng=rng;t.addTeardown(@() rng(oldRng));
old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
t.addTeardown(@() setConfigurablesOverride(old));saved=load(fullfile(t.TestData.run,"config.mat"),"o");o=saved.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
rng(20260908);
end
function testCapExactBothSigns(t)
verifyEqual(t,cap192Command([-1 1 -192/255 192/255],true),[-192/255 192/255 -192/255 192/255]);
end
function testInteriorIsClippedNotScaled(t)
x=[-.7 -.05 -.049 0 .049 .05 .6 .7];verifyEqual(t,cap192Command(x,true),x);
end
function testOffIdentityIncludingShape(t)
x=reshape(linspace(-1,1,24),6,4);verifyEqual(t,cap192Command(x,false),x);
end
function testHistoricalActivationThreshold(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
[~,p]=remap(cap192Command([-.05 -.049 .049 .05]',true));verifyEqual(t,p,[-64;0;0;64]);
end
function testAppliedLevelsAndRange(t)
for label=["BEST_CAP192","LAST_CAP192"]
    d=t.TestData.(label);
    for e=1:200
        r=d.runtimeTraces{e};verifyTrue(t,all(ismember(r.pwm,[-192 -160 -128 -96 -64 0 64 96 128 160 192]),"all"));
        verifyEqual(t,r.effectiveAction,r.pwm/255);
        verifyEqual(t,r.rawAction,cap192Command(r.desiredRaw,true));
    end
end
end
function testPreviousActionImmediatelyAfterCap(t)
rt=GloveFreePolicyRuntime(randn(160,8),[0 0 0 0]);
[s,~,r]=rt.advance(cap192Command([1;-1;.5;0],true));
verifyEqual(t,s(49:52),r.pwm/255);verifyEqual(t,r.pwm(1:2),[192;-192]);
verifyNotEqual(t,s(49:50),[1;-1]);
end
function testEveryRuntimeStateUsesRealEffectiveAction(t)
for label=["BEST_CAP192","LAST_CAP192"]
    d=t.TestData.(label);
    for e=1:200,r=d.runtimeTraces{e};verifyEqual(t,r.state(2:end,49:52),r.effectiveAction);verifyEqual(t,r.state(1,49:52),zeros(1,4));end
end
end
function testBestOffExactlyMatchesStoredOriginal(t)
verifyOriginal(t,"BEST_OFF","best_checkpoint");
end
function testLastOffExactlyMatchesStoredOriginal(t)
verifyOriginal(t,"LAST_OFF","last_checkpoint");
end
function testHistoricalRewardReconstructed(t)
for label=["BEST_CAP192","LAST_CAP192"]
    d=t.TestData.(label);
    for e=1:200
        a=d.traces{e};u=a.effectiveAction;du=[u(1,:);diff(u)];
        expected=mean(-(a.prediction-a.reference).^2-.01*u.^2-.05*du.^2,2);
        verifyEqual(t,a.reward,expected,AbsTol=1e-12);e2bControlMetrics(a);
    end
end
end
function testHistoricalRemappingReconstructed(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
for label=["BEST_CAP192","LAST_CAP192"]
    d=t.TestData.(label);
    for e=1:200
        r=d.runtimeTraces{e};
        for k=1:size(r.pwm,1),[u,p]=remap(r.rawAction(k,:)');verifyEqual(t,r.pwm(k,:),p');verifyEqual(t,r.effectiveAction(k,:),u');end
    end
end
end
function testZeroPwmNeverMovesPlant(t)
C=t.TestData.measured.C;verifyEqual(t,sum(C.zeroMotionFailures),0);
end
function testDeterministicActorRuntime(t)
a=load(fullfile(t.TestData.run,"checkpoints","AgentEpisode010000.mat"),"saved_actor");
d=load(fullfile(t.TestData.root,"data","datasets","Denis Dataset","BLANCA.mat"),"emgs");
target=t.TestData.BEST_CAP192.runtimeTraces{1};
x=cap192Runtime(a.saved_actor,d.emgs{1,1},target.q(1,:),true);
y=cap192Runtime(a.saved_actor,d.emgs{1,1},target.q(1,:),true);
for f=["q","state","desiredRaw","rawAction","effectiveAction","pwm"]
    verifyEqual(t,x.(f),y.(f));verifyEqual(t,x.(f),target.(f));
end
end
function testBoundFractionIncludesZeroCommands(t)
p=[192 0 0 0;-192 192 0 0;0 0 0 0];q=zeros(4,4);c=cap192Counts(q,p,p/255,p/255);
verifyEqual(t,sum(c.boundHits)/sum(c.commands),3/12);
end
function testM3ReversalRequiresPositivePwmAndNegativeDelta(t)
q=zeros(5,4);q(:,3)=[3;2;1;1;0];p=zeros(4,4);p(:,3)=[192;-192;192;0];
c=cap192Counts(q,p,p/255,p/255);verifyEqual(t,c.positiveReversals(3),1);
end
function testOriginalReversalCountingMatchesAudit(t)
C=t.TestData.measured.C;
verifyEqual(t,sum(C.positiveReversals(C.controller=="BEST_OFF" & C.split=="VALIDATION" & C.horizon=="COMMON" & C.motor==3)),134);
verifyEqual(t,sum(C.positiveReversals(C.controller=="LAST_OFF" & C.split=="VALIDATION" & C.horizon=="COMMON" & C.motor==3)),81);
end
function testGateAcceptsFrozenBoundary(t)
[o,c,k]=gateFixture;c.mse=1.05;c.reward=-1.05;c.m3=10;c.boundHitFraction192=.5;
g=cap192Gate(o,c,k);verifyTrue(t,g.supported);
end
function testNegativeRewardWorseningSign(t)
[o,c,k]=gateFixture;c.reward=-.8;g=cap192Gate(o,c,k);verifyLessThan(t,g.rewardWorseningPct,0);verifyTrue(t,g.rewardPass);
c.reward=-1.06;g=cap192Gate(o,c,k);verifyFalse(t,g.rewardPass);
end
function testGateRejectsEachBlocker(t)
[o,c,k]=gateFixture;
for f=["mse","reward","m3","boundHitFraction192","newFinalCycles","newFinalPeriodic","newRuntimeFinalCycles","newRuntimeFinalPeriodic","zeroMotionFailures"]
    a=c;if f=="mse",a.(f)=1.06;elseif f=="reward",a.(f)=-1.06;elseif f=="m3",a.(f)=11;elseif f=="boundHitFraction192",a.(f)=.50001;else,a.(f)=1;end
    g=cap192Gate(o,a,k);verifyFalse(t,g.supported);
end
end
function testGuardAndRuntimeDoNotReadTeacher(t)
for file=["cap192Command.m","cap192Runtime.m"]
    s=lower(string(fileread(fullfile(t.TestData.pr,"cap192",file))));
    verifyFalse(t,contains(s,".reference") || contains(s,"load(") || contains(s,"reward(") || contains(s,".glove"));
end
r=t.TestData.BEST_CAP192.runtimeTraces{1};verifyEqual(t,r.termination,"EMG_ONLY");
end
function testViewerAlignmentAndExactRuntimeTrace(t)
for label=["BEST_OFF","BEST_CAP192","LAST_OFF","LAST_CAP192"]
    v=load(fullfile(t.TestData.out,"viewer",label,"viewer_trace.mat"));r=t.TestData.(label).runtimeTraces{1};n=size(r.pwm,1);
    verifyEqual(t,v.q,r.q);verifyEqual(t,v.PWM,r.pwm);verifyEqual(t,v.step,(0:n)');verifyEqual(t,v.commandStep,(1:n)');
    verifyEqual(t,v.Ts,.2);verifyEqual(t,v.time,(0:n)'*.2);verifyFalse(t,v.teacherLoaded || v.trainingExecuted);
    verifyTrue(t,contains(v.source,"GloveFreePolicyRuntime"));verifyEqual(t,size(v.q),[n+1 4]);
end
end
function testViewerRefusesSealedSubjectsBeforeLoading(t)
for subject=["MATEO","SANDRA"]
    verifyError(t,@() exportE3AXViewerTrace("unused",subject,1,"closing","unused.mat"),"CAP192:SealedSubject");
end
end
function testHistoricalHashesIncludingPlantAndCheckpoints(t)
H=readtable(fullfile(t.TestData.out,"historical_hashes_before.csv"),TextType="string",Delimiter=",");
verifyGreaterThanOrEqual(t,height(H),977);
for k=1:height(H),verifyEqual(t,cap192SHA256(fullfile(t.TestData.root,H.path(k))),H.sha256(k));end
end
function testHistoricalCycleAndPeriodicDetectorsUnchanged(t)
d=t.TestData.BEST_CAP192;
C=t.TestData.measured.C;C=C(C.controller=="BEST_CAP192" & C.horizon=="COMMON",:);
for e=1:200
    a=d.traces{e};m=e2dCycleScan(a.q,a.pwm);idx=(e-1)*4+(1:4);
    verifyEqual(t,C.finalCycles(idx)',double(m(end,:)));verifyEqual(t,C.cycleWindows(idx)',sum(m,1));
    for motor=1:4,verifyEqual(t,C.period(idx(motor)),e2fPeriodicTrace(a.q,a.pwm,motor,false));end
end
end
function testStepCsvPreservesMotorAndDesiredAlignment(t)
S=readtable(fullfile(t.TestData.out,"BEST_CAP192","step_traces.csv"),TextType="string",Delimiter=",");
a=t.TestData.BEST_CAP192.traces{1};
for m=1:4
    idx=S.subject=="BLANCA" & S.repetition==1 & S.side==1 & S.motor==m;
    verifyEqual(t,S.desiredRaw(idx),a.desiredRaw(:,m),AbsTol=1e-14);
    verifyEqual(t,S.commandRaw(idx),a.rawAction(:,m),AbsTol=1e-14);verifyEqual(t,S.pwm(idx),a.pwm(:,m));
end
end
function verifyOriginal(t,label,kind)
d=t.TestData.(label);original=load(fullfile(t.TestData.run,"evaluation",kind,"metrics","trajectories.mat"));
for e=1:200
    for f=["q","state","rawAction","effectiveAction","pwm"],verifyEqual(t,d.runtimeTraces{e}.(f),original.runtimeTraces{e}.(f));end
    verifyEqual(t,d.traces{e}.reward,original.traces{e}.reward,AbsTol=1e-12);
end
end
function [o,c,k]=gateFixture
o=struct("mse",1,"reward",-1,"m3",100);
c=struct("mse",1,"reward",-1,"m3",0,"boundHitFraction192",.3,"newFinalCycles",0,"newFinalPeriodic",0, ...
    "newRuntimeFinalCycles",0,"newRuntimeFinalPeriodic",0,"zeroMotionFailures",0);
k=struct("offReproduced",true,"testsPass",true,"hashesIntact",true);
end
