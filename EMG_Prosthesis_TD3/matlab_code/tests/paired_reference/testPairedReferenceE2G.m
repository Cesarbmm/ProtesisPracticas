function tests=testPairedReferenceE2G
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(fullfile(root,"analysis","paired_reference"));
here=fullfile(root,"analysis","paired_reference");out=fullfile(here,"e2g_results");t.TestData.root=root;t.TestData.out=out;
g=load(fullfile(here,"e2f_results","graphs.mat"));t.TestData.g=g.graphs;
d=load(fullfile(out,"trajectories.mat"));t.TestData.traces=d.trajectories;t.TestData.floor=d.floorTraces;
d=load(fullfile(here,"e2f_results","trajectories.mat"));t.TestData.original=d.trajectories;
end
function testProjectionInsideUnchanged(t)
[~,lo,hi]=e2gProjectReference(zeros(1,4),t.TestData.g);r=[lo;(lo+hi)/2;hi];verifyEqual(t,e2gProjectReference(r,t.TestData.g),r);
end
function testProjectionOutsideUsesMotorBounds(t)
[p,lo,hi]=e2gProjectReference([-ones(1,4);2*ones(1,4)],t.TestData.g);verifyEqual(t,p,[lo;hi]);
end
function testProjectionIdempotentAndMonotone(t)
r=repmat(linspace(-.2,1.2,31)',1,4);p=e2gProjectReference(r,t.TestData.g);verifyEqual(t,e2gProjectReference(p,t.TestData.g),p);verifyTrue(t,all(diff(p)>=0,"all"));
end
function testProjectionMinimumScalarDistance(t)
r=repmat(linspace(-.2,1.2,31)',1,4);[p,lo,hi]=e2gProjectReference(r,t.TestData.g);
for alpha=linspace(0,1,21),candidate=lo+alpha*(hi-lo);verifyTrue(t,all(abs(p-r)<=abs(candidate-r)+1e-14,"all"));end
end
function testGloveSensorAggregation(t)
v=struct("thumb",11,"indexUp",2,"indexDown",3,"middleUp",5,"middleDown",7,"ringUp",13,"ringDown",17,"pinkyUp",19,"pinkyDown",23);
samples=repmat(v,2,1);r=reduceFlexDimension(samples);verifyEqual(t,r,repmat([72 5 11 12],2,1));
end
function testScalerHasNoOffset(t)
p=configurables();verifyEqual(t,p.flexJoined_scale([4092 2046 1023 2046]),ones(1,4));verifyEqual(t,p.flexJoined_scale(zeros(1,4)),zeros(1,4));
end
function testEncoderAnchorsAndSaturation(t)
gap=[7500 3650 4000 3550];br=[26500 11500 8500 9000];lo=[1800 900 300 900];hi=[4092 2046 1023 2046];
verifyEqual(t,encoder2Flex([zeros(1,4);gap;br;br+1]),[lo;lo;hi;hi],AbsTol=1e-10);
end
function testEncoderGapHidesEncoderMotion(t)
verifyEqual(t,encoder2Flex([0 0 0 0]),encoder2Flex([100 3500 100 100]));
end
function testEncoderAbsAndPerMotorMap(t)
q=[9000 6000 5500 5000];verifyEqual(t,encoder2Flex(q),encoder2Flex(-q));h=encoder2Flex(q);
for m=1:4,x=q;x(setdiff(1:4,m))=99999;y=encoder2Flex(x);verifyEqual(t,y(m),h(m));end
end
function testOriginalOracleReusedExactly(t)
for e=1:200
    a=t.TestData.traces{e,1};b=t.TestData.original{e,7};a.metadata.controller=b.metadata.controller;verifyEqual(t,a,b);
end
end
function testProjectionBothTeacherTimesOnly(t)
for e=1:200
    b=t.TestData.original{e,2};x=t.TestData.floor{e,2};
    verifyEqual(t,x.reference,e2gProjectReference(b.reference,t.TestData.g));verifyEqual(t,x.referenceBefore,e2gProjectReference(b.referenceBefore,t.TestData.g));
    x.reference=b.reference;x.referenceBefore=b.referenceBefore;x.metadata.controller=b.metadata.controller;verifyEqual(t,x,b);
end
end
function testSameEpisodesInitialStateDuration(t)
for e=1:200
    a=t.TestData.traces{e,1};b=t.TestData.traces{e,2};verifyEqual(t,a.q(1,:),b.q(1,:));verifyEqual(t,size(a.reference),size(b.reference));
    verifyEqual(t,a.metadata.subject,b.metadata.subject);verifyEqual(t,a.metadata.repetition,b.metadata.repetition);verifyEqual(t,a.metadata.side,b.metadata.side);
end
end
function testActionsLegalAndRemapperIdentical(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
for e=1:200,x=t.TestData.traces{e,2};verifyTrue(t,all(ismember(x.pwm,t.TestData.g{1}.actions),"all"));
    verifyEqual(t,x.effectiveAction,x.pwm/255);
    for k=1:size(x.pwm,1),[u,p]=remap(x.rawAction(k,:));verifyEqual(t,p',x.pwm(k,:));verifyEqual(t,u',x.effectiveAction(k,:));end
end
end
function testAllGraphTransitions(t)
for e=1:200,x=t.TestData.traces{e,2};
    for m=1:4,g=t.TestData.g{m};[ok,i]=ismember(x.q(1:end-1,m),g.q);[legal,a]=ismember(x.pwm(:,m),g.actions);verifyTrue(t,all(ok & legal));
        verifyEqual(t,x.q(2:end,m),g.q(g.next(sub2ind(size(g.next),i,a))));end
end
end
function testRewardUsesHistoricalFunction(t)
for e=1:200,x=t.TestData.traces{e,2};previous=zeros(1,4);
    for k=1:size(x.pwm,1)
        ctx=struct("flexConverted",x.reference(k,:),"adjustEnc",x.prediction(k,:),"prevAction",previous);
        verifyEqual(t,trackingMseActionRateReward(ctx,x.effectiveAction(k,:),[]),x.reward(k),AbsTol=1e-12);previous=x.effectiveAction(k,:);
    end
end
end
function testProjectedOracleDeterministic(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
actual=e2fRollout(t.TestData.floor{1,2},5,t.TestData.g,remap);actual.metadata.controller="PROJECTED";verifyEqual(t,actual,t.TestData.traces{1,2});
end
function testReachabilityFixedP2ReallyFixed(t)
for e=1:200,a=t.TestData.floor{e,1};b=t.TestData.floor{e,2};verifyEqual(t,a.q,b.q);verifyEqual(t,a.pwm,b.pwm);end
end
function testReachabilityMinimumIndependent(t)
R=readtable(fullfile(t.TestData.out,"reachability_P2_FIXED_PROJECTED.csv"),TextType="string");
for m=1:4
    A=R(R.motor==m & R.pwm==0,:);g=t.TestData.g{m};dest=g.next(A.qIndex,:);err=abs(g.h(dest)-A.referenceAfter);
    verifyEqual(t,A.bestOneStepError,min(err,[],2),AbsTol=1e-12);verifyTrue(t,all(A.bestOneStepError<=A.currentError+1e-12));
end
end
function testCounterfactualCrossReward(t)
X=readtable(fullfile(t.TestData.out,"cross_reference_episode_motor.csv"),TextType="string");
for e=[1 101 200]
    x=t.TestData.traces{e,2};r=t.TestData.traces{e,1}.reference;u=x.effectiveAction;du=[u(1,:);diff(u)];
    rows=X(X.controller=="PROJECTED" & X.evaluationReference=="ORIGINAL" & X.subject==x.metadata.subject & X.repetition==x.metadata.repetition & X.side==x.metadata.side,:);
    verifyEqual(t,rows.trackingMSE',mean((x.prediction-r).^2,1),AbsTol=1e-12);
    verifyEqual(t,rows.rewardMean',mean(-(x.prediction-r).^2-.01*u.^2-.05*du.^2,1),AbsTol=1e-12);
end
end
function testCyclesRecordedWithOriginalDetector(t)
M=readtable(fullfile(t.TestData.out,"episode_metrics.csv"),TextType="string");count=0;
for e=1:200,x=t.TestData.traces{e,2};mask=e2dCycleScan(x.q,x.pwm);count=count+nnz(mask(end,:));end
verifyEqual(t,count,sum(M.persistentTwoCycle(M.controller=="PROJECTED")));
end
function testFixedReplaysRecomputable(t)
d=load(fullfile(t.TestData.out,"fixed_trajectories.mat"));F=readtable(fullfile(t.TestData.out,"fixed_summary.csv"),TextType="string");
verifyEqual(t,size(d.fixedTrajectories),[20 2]);
for e=1:20,x=d.fixedTrajectories{e,2};m=3+(e>10);verifyEqual(t,e2fPeriodicTrace(x.q,x.pwm,m,true),F.period(2*e));verifyEqual(t,max(abs(diff(x.q(end-20:end,m))))<=1e-9,logical(F.last20Hold(2*e)));end
end
function testNoNewM3ReversalsOrPWMZeroMotion(t)
for e=1:200,x=t.TestData.traces{e,2};dq=diff(x.q);verifyEqual(t,nnz(x.pwm(:,3)>0 & dq(:,3)<0),0);verifyTrue(t,all(abs(dq(x.pwm==0))<=1e-9));end
end
function testCalibrationCannotBeInferredFromClipping(t)
E=jsondecode(fileread(fullfile(t.TestData.out,"coordinate_evidence.json")));S=jsondecode(fileread(fullfile(t.TestData.out,"scientific_summary.json")));
verifyEqual(t,S.gatesBeforeTests.A,all([E.motors.pairedPhysicalCalibrationDemonstrated]));
if ~all([E.motors.pairedPhysicalCalibrationDemonstrated]),verifyFalse(t,S.RL_PILOT_AUTHORIZED);end
verifyFalse(t,E.affineCalibrationIndependentAnchorsAvailable);
end
function testVariationGateUsesAllMotorDirections(t)
V=readtable(fullfile(t.TestData.out,"reference_variation.csv"),TextType="string");gate=true;
for m=1:4,for side=1:2
    A=V(V.motor==m & V.side==side,:);ratios=sort(A.rangeRatio(isfinite(A.rangeRatio)));mid=median(ratios);
    eligible=logical(A.trendEligible);trend=1;if any(eligible),trend=mean(A.trendRetained(eligible));end
    gate=gate && mid>=.5 && 100*mean(A.projectedFlat-A.originalFlat)<=5+1e-12 && trend>=.95;
end;end
S=jsondecode(fileread(fullfile(t.TestData.out,"scientific_summary.json")));verifyEqual(t,gate,S.gatesBeforeTests.D);
end
function testDevelopmentOnly(t)
allowed=["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA","JOE","JONATHAN","KHAROL"];
names=cellfun(@(x) string(x.metadata.subject),t.TestData.traces(:,2));verifyTrue(t,all(ismember(names,allowed)));verifyEqual(t,numel(unique(names)),10);
end
function testMappingCeilingVersusRecordedSupport(t)
A=readtable(fullfile(t.TestData.out,"plant_support_audit.csv"),TextType="string");M=A(A.motor==2,:);
verifyTrue(t,all(M.data_limits_match==1));verifyLessThan(t,max(M.data_q_max),11500);verifyEqual(t,max(M.avg_q_max)-max(t.TestData.g{2}.q),.5,AbsTol=1e-9);
end
function testHistoricalHashesIntact(t)
I=e2gVerifyHistory();verifyGreaterThanOrEqual(t,height(I),740);verifyTrue(t,all(I.unchanged));
end
