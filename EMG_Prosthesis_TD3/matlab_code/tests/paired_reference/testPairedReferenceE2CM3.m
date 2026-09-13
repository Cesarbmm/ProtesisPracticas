function tests=testPairedReferenceE2CM3
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));t.TestData.root=root;
t.TestData.oldPath=path;addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
t.TestData.avgs=load(fullfile(root,"src","@SimController","pattern_curve.mat"),"avgs").avgs;
t.TestData.limits=readtable(fullfile(root,"src","@SimController","plant_limits_canonical.csv"),TextType="string");
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testExactPWM192Region(t)
verifyRegion(t,"sp_BF",[7647 7648.333333333333]);
end
function testExactPWM224Region(t)
verifyRegion(t,"sp_DF",[7513.666666666667 7567.5]);
end
function testExactPWM255Region(t)
verifyRegion(t,"sp_FF",[7577.833333333333 7604.5]);
end
function testLowPWMsHaveNoRegionOverEmpiricalDomain(t)
for f=["sp_3F","sp_5F","sp_7F","sp_9F"]
    [curve,lim]=getCurve(t,f);R=e2cM3ReversalIntervals(curve,lim,[-910 7912]);verifyEmpty(t,R);
end
end
function testFirstCrossingUsesPrefixRecordNotLaterRecrossing(t)
curve=[1;5;3;6;repmat(2,210,1)];
[next,index]=e2cM3CurveStep([3;5;5.1;7],curve,[0 10]);
verifyEqual(t,index,[2;2;4;0]);verifyEqual(t,next,[2;2;2;7]);
end
function testClampAndHoldRemainHistorical(t)
curve=[(0:300)';zeros(201,1)];
[next,index]=e2cM3CurveStep([-50;350;1000],curve,[0 400]);
verifyEqual(t,next,[200;350;1000]);verifyEqual(t,index,[1;0;0]);
end
function testIntervalsRespectOpenLowerAndClosedUpper(t)
R=table(10,20,false,true,VariableNames=["lower","upper","lowerIncluded","upperIncluded"]);
verifyEqual(t,e2cM3RegionMembership([10;10+1e-8;20;20+1e-8],R),[false;true;true;false]);
end
function testEmpiricalReversalNotOnlyAverage(t)
c=t.TestData.avgs.sp_BF.closing.m_3;
verifyEqual(t,c.data(422,:)-c.data(222,:),[0 -4 0]);
verifyEqual(t,nnz(c.data(422,:)-c.data(222,:)<0),1);
end
function testSingletonDomainBoundaryReversal(t)
curve=[(0:300)';zeros(201,1)];
R=e2cM3ReversalIntervals(curve,[0 400],[300 400]);
verifyEqual(t,[R.lower R.upper],[300 300]);
verifyTrue(t,R.lowerIncluded && R.upperIncluded);
verifyEqual(t,e2cM3RegionMembership([300;300+1e-8],R),[true;false]);
end
function testExactIntervalsAgreeWithLiteralSearch(t)
curve=[(0:300)';(299:-1:0)'];limits=[10 290];domain=[-20 350];
q=unique([linspace(-20,350,3001)';curve]);expected=q;
for k=1:numel(q)
    i=find(curve>=min(290,max(10,q(k))),1);
    if ~isempty(i),expected(k)=curve(min(i+200,numel(curve)));end
end
verifyEqual(t,e2cM3CurveStep(q,curve,limits),expected);
R=e2cM3ReversalIntervals(curve,limits,domain);
insideDomain=q>=domain(1)&q<=domain(2);
verifyEqual(t,e2cM3RegionMembership(q(insideDomain),R),expected(insideDomain)<q(insideDomain));
end
function testRepeatabilityClassification(t)
E=table([6;6],[2;3],[4;3],[1;0],VariableNames= ...
    ["sameIndexSupported","sameIndexNegative","sameQSupported","sameQNegative"]);
verifyEqual(t,e2cM3Classify(E,true),"LOW_REPEATABILITY");
E.sameIndexNegative(:)=6;E.sameQNegative=E.sameQSupported;
verifyEqual(t,e2cM3Classify(E,true),"REPEATABLE_EMPIRICAL_STRUCTURE");
E.sameIndexNegative(:)=0;E.sameQNegative(:)=0;
verifyEqual(t,e2cM3Classify(E,true),"AVERAGING_ARTIFACT");
verifyEqual(t,e2cM3Classify(E,false),"UNRESOLVED");
end
function testP2VisitsButNeverCommandsReversal(t)
out=fullfile(t.TestData.root,"analysis","paired_reference","e2c_results");
G=readtable(fullfile(out,"m3_controller_visitation.csv"),TextType="string");
p=G(G.controller=="P_2",:);verifyEqual(t,p.inAnyReversalRegion,300);verifyEqual(t,p.executedReversals,0);
verifyEqual(t,sum(G.executedReversals),520);
end
function verifyRegion(t,field,expected)
[curve,lim]=getCurve(t,field);R=e2cM3ReversalIntervals(curve,lim,[-910 7912]);
verifyEqual(t,[R.lower R.upper],expected,"AbsTol",1e-9);
verifyFalse(t,R.lowerIncluded);verifyTrue(t,R.upperIncluded);
pwm=t.TestData.limits.speed_value(t.TestData.limits.motor==3 & t.TestData.limits.direction=="closing" & ...
    t.TestData.limits.speed_field==field);pwm=min(pwm,255);
for q=[R.lower R.lower+1e-8 (R.lower+R.upper)/2 R.upper R.upper+1e-8]
    out=SimController.prosthesis_simulator([0 0 q 0],[0 0 pwm 0],.2,.14,plantSource="patternCurveCanonical");
    verifyEqual(t,out(3)<q,e2cM3RegionMembership(q,R));
end
end
function [curve,lim]=getCurve(t,field)
curve=t.TestData.avgs.(field).closing.m_3.avg(:);
l=t.TestData.limits;l=l(l.motor==3 & l.direction=="closing" & l.speed_field==field,:);
lim=[l.min_lim l.max_lim];
end
