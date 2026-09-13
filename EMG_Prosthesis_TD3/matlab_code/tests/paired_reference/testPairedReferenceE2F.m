function tests=testPairedReferenceE2F
tests=functiontests(localfunctions);
end
function setupOnce(t)
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(fullfile(root,"analysis","paired_reference"));
out=fullfile(root,"analysis","paired_reference","e2f_results");t.TestData.out=out;t.TestData.root=root;
d=load(fullfile(out,"graphs.mat"));t.TestData.graphs=d.graphs;
d=load(fullfile(out,"trajectories.mat"));t.TestData.traces=d.trajectories;
t.TestData.steps=readtable(fullfile(out,"step_traces.csv"),TextType="string");
end
function testGraphClosed(t)
for m=1:4,g=t.TestData.graphs{m};verifyTrue(t,g.closed);verifyLessThanOrEqual(t,numel(g.q),10000);verifyTrue(t,all(g.next>=1 & g.next<=numel(g.q),"all"));end
end
function testGraphKeysBitExact(t)
for m=1:4,g=t.TestData.graphs{m};verifyEqual(t,string(cellstr(num2hex(g.q))),g.qHex);verifyEqual(t,numel(unique(g.qHex)),numel(g.q));end
end
function testAPISeparable(t)
old=rng;c=onCleanup(@() rng(old));rng(204); %#ok<NASGU>
for k=1:80
    q=zeros(1,4);pwm=zeros(1,4);expected=zeros(1,4);
    for m=1:4,g=t.TestData.graphs{m};i=randi(numel(g.q));a=randi(15);q(m)=g.q(i);pwm(m)=g.actions(a);expected(m)=g.q(g.next(i,a));end
    actual=SimController.prosthesis_simulator(q,pwm,.2,.14,plantSource="patternCurveCanonical");verifyEqual(t,actual,expected);
end
end
function testHSeparable(t)
q=[1234 4321 -3456 6543];h=encoder2Flex(q);
for m=1:4,other=q;other(setdiff(1:4,m))=99999;altered=encoder2Flex(other);verifyEqual(t,h(m),altered(m));end
end
function testRewardSeparable(t)
u=[0 64 -96 224]/255;prev=[-64 0 96 128]/255;ref=[.2 .4 .6 .8];pred=[.3 .1 .65 .9];
ctx=struct("flexConverted",ref,"adjustEnc",pred,"prevAction",prev);[r,v]=trackingMseActionRateReward(ctx,u,[]);
expected=-((pred-ref).^2+.01*u.^2+.05*(u-prev).^2);verifyEqual(t,v,expected);verifyEqual(t,r,mean(expected));
end
function testBellmanExhaustive(t)
A=readtable(fullfile(t.TestData.out,"bellman_validation.csv"));verifyEqual(t,height(A),12);verifyEqual(t,A.error,zeros(12,1));verifyEqual(t,A.actionIndex,A.exhaustiveActionIndex);
end
function testBellmanValuePlan(t)
for m=1:4,g=t.TestData.graphs{m};[a,v,p]=e2fOracleAction(g,1,3,[.5;.52;.54;.56;.58]);verifyEqual(t,a,p.actionIndices(1));verifyEqual(t,sum(p.stageCosts),v,AbsTol=1e-12);end
end
function testBellmanDeterministic(t)
g=t.TestData.graphs{1};[a,v,p]=e2fOracleAction(g,17,4,[.6;.5;.4]);[b,w,q]=e2fOracleAction(g,17,4,[.6;.5;.4]);verifyEqual(t,a,b);verifyEqual(t,v,w);verifyEqual(t,p,q);
end
function testOneStepJointSeparableOptimum(t)
cost=zeros(4,15);opt=0;
for m=1:4
    g=t.TestData.graphs{m};ref=.15*m;[~,v]=e2fOracleAction(g,1,1,ref);opt=opt+v;
    for a=1:15,cost(m,a)=(g.h(g.next(1,a))-ref)^2+.06*(g.actions(a)/255)^2;end
end
joint=Inf;for a=1:15,for b=1:15,for c=1:15,for d=1:15,joint=min(joint,cost(1,a)+cost(2,b)+cost(3,c)+cost(4,d));end;end;end;end
verifyEqual(t,opt,joint,AbsTol=1e-12);
end
function testPreviousActionMatters(t)
g=t.TestData.graphs{1};[~,v]=e2fOracleAction(g,1,1,.5);[~,w]=e2fOracleAction(g,1,15,.5);verifyNotEqual(t,v,w);
end
function testLegalActions(t)
S=t.TestData.steps;verifyTrue(t,all(ismember(S.pwm,t.TestData.graphs{1}.actions)));verifyEqual(t,S.effective,S.pwm/255,AbsTol=1e-14);
end
function testRemapperUnchanged(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
actions=t.TestData.graphs{1}.actions;[eff,pwm]=remap(actions/255);verifyEqual(t,pwm,actions');verifyEqual(t,eff,actions'/255);
end
function testRewardReconstruction(t)
S=t.TestData.steps;expected=-(S.hAfter-S.referenceAfter).^2-.01*S.effective.^2-.05*(S.effective-S.previousPwm/255).^2;
verifyEqual(t,S.rewardMotor,expected,AbsTol=2e-12);
end
function testAllOracleGraphTransitions(t)
for e=1:200
    for col=4:7
        x=t.TestData.traces{e,col};
        for m=1:4,g=t.TestData.graphs{m};[ok,q]=ismember(x.q(1:end-1,m),g.q);[legal,a]=ismember(x.pwm(:,m),g.actions);verifyTrue(t,all(ok & legal));next=g.next(sub2ind(size(g.next),q,a));verifyEqual(t,x.q(2:end,m),g.q(next));end
    end
end
end
function testBaselineReproduced(t)
m=jsondecode(fileread(fullfile(t.TestData.out,"measurement_summary.json")));verifyTrue(t,m.baselinePlantExact);verifyLessThanOrEqual(t,m.baselineMaxRewardError,1e-12);
end
function testOracleRolloutDeterministic(t)
[remap,c]=e2cHistoricalRemapper(t.TestData.root); %#ok<ASGLU>
b=t.TestData.traces{1,2};a=e2fRollout(b,5,t.TestData.graphs,remap);expected=t.TestData.traces{1,7};verifyEqual(t,a,expected);
end
function testHistoricalCycleDetector(t)
M=readtable(fullfile(t.TestData.out,"episode_metrics.csv"),TextType="string");counts=zeros(1,7);
for c=1:7,for e=1:200,x=t.TestData.traces{e,c};mask=e2dCycleScan(x.q,x.pwm);counts(c)=counts(c)+nnz(mask(end,:));end;verifyEqual(t,counts(c),sum(M.persistentTwoCycle(M.controller==t.TestData.traces{1,c}.metadata.controller)));end
verifyEqual(t,counts(2),2);
end
function testPeriodicWithPauses(t)
q=zeros(33,4);positions=repmat([1541.66666666667;7532.5;7532.5;1541.66666666667],9,1);q(:,3)=positions(1:33);
pwm=zeros(32,4);pwm(:,3)=repmat([224;0;-64;0],8,1);
verifyEqual(t,e2fPeriodicTrace(q,pwm,3,true),4);mask=e2dCycleScan(q,pwm);verifyFalse(t,any(mask(:,3)));
end
function testKnownCasesPresent(t)
K=readtable(fullfile(t.TestData.out,"known_cycle_cases.csv"),TextType="string");verifyEqual(t,numel(unique(K.controller)),7);verifyTrue(t,any(K.subject=="BLANCA" & K.motor==3));verifyTrue(t,any(K.subject=="IVANNA" & K.motor==4));
end
function testReachabilityIncludesHold(t)
R=readtable(fullfile(t.TestData.out,"reachability_ORACLE_H5.csv"),TextType="string");verifyTrue(t,all(R.bestOneStepError<=R.currentError+1e-12));verifyEqual(t,R.qAfter(R.pwm==0),R.qBefore(R.pwm==0));
end
function testReachabilityEndpoints(t)
R=readtable(fullfile(t.TestData.out,"reachability_ORACLE_H5.csv"),TextType="string");
for m=1:4
    S=R(R.motor==m,:);g=t.TestData.graphs{m};q=S.qIndex;[~,a]=ismember(S.pwm,g.actions);next=g.next(sub2ind(size(g.next),q,a));verifyEqual(t,S.qAfter,g.q(next),AbsTol=1e-9);verifyEqual(t,S.absoluteError,abs(S.hAfter-S.referenceAfter),AbsTol=1e-12);
end
end
function testM3RecordedWithoutHidingFailures(t)
S=t.TestData.steps;S=S(S.controller=="ORACLE_H5",:);G=jsondecode(fileread(fullfile(t.TestData.out,"primary_gates.json")));verifyEqual(t,G.m3Reversals,nnz(S.motor==3 & S.pwm>0 & S.qAfter<S.qBefore));
end
function testZeroPWMHold(t)
S=t.TestData.steps;verifyEqual(t,S.qAfter(S.pwm==0),S.qBefore(S.pwm==0),AbsTol=1e-9);
end
function testFixedResultsRecomputable(t)
d=load(fullfile(t.TestData.out,"fixed_trajectories.mat"));F=readtable(fullfile(t.TestData.out,"fixed_reference_summary.csv"));
for e=1:20
    for c=1:5,x=d.fixedTrajectories{e,c};m=3+(e>10);p=e2fPeriodicTrace(x.q,x.pwm,m,true);row=(e-1)*5+c;verifyEqual(t,p,F.period(row));end
end
end
function testHistoricalIntegrity(t)
I=e2fVerifyHistory();verifyGreaterThanOrEqual(t,height(I),663);verifyTrue(t,all(I.unchanged));
end
