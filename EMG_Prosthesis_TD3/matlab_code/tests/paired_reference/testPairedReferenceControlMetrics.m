function tests=testPairedReferenceControlMetrics
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.TestData.oldPath=path;
addpath(genpath(fullfile(root,"src"))); addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testInitialActionCostAndMotorDenominator(t)
q=zeros(3,4); u=repmat([64/255 0 0 0],2,1);
trace=fixture(q,u); [m,a]=e2bControlMetrics(trace);
verifyEqual(t,a.actionL2,(64/255)^2/4,"AbsTol",1e-14);
verifyEqual(t,a.deltaActionL2,(64/255)^2/8,"AbsTol",1e-14);
verifyEqual(t,m(1).deltaActionL2,(64/255)^2/2,"AbsTol",1e-14);
verifyEqual(t,a.rewardMean,a.trackingTerm-a.actionPenalty-a.deltaActionPenalty,"AbsTol",1e-14);
end
function testConstantCorrelationAndNoCommandsStayUndefined(t)
[m,a]=e2bControlMetrics(fixture(zeros(3,4),zeros(2,4)));
verifyTrue(t,all(isnan([m.correlation])));
verifyEqual(t,a.correlationValid,0);
verifyTrue(t,isnan(a.action_no_motion));
verifyEqual(t,a.flat_response,1);
end
function testGapMovementIsDifferentFromNoMotion(t)
q=[zeros(1,4);ones(1,4)*100;ones(1,4)*200];
[~,a]=e2bControlMetrics(fixture(q,ones(2,4)*64/255));
verifyEqual(t,a.flat_response,1);
verifyEqual(t,a.action_no_motion,0);
verifyEqual(t,a.encoderRange,200);
end
function testCycleNeedsFinalFiveStatesAndAlternatingCommands(t)
q=repmat([8000;12000;8000;12000;8000],1,4);
u=repmat([1;-1;1;-1]*64/255,1,4);
[~,a]=e2bControlMetrics(fixture(q,u));
verifyEqual(t,a.persistentTwoCycle,4);
[~,short]=e2bControlMetrics(fixture(q(1:4,:),u(1:3,:)));
verifyEqual(t,short.persistentTwoCycle,0);
[~,hold]=e2bControlMetrics(fixture(repmat(q(1,:),5,1),u));
verifyEqual(t,hold.persistentTwoCycle,0);
end
function testDirectionAndZeroCommandFailuresAreVisible(t)
q=[zeros(1,4);ones(1,4)*100];
[~,a]=e2bControlMetrics(fixture(q,[-64/255 0 64/255 0]));
verifyEqual(t,a.directionFailures,1);
verifyEqual(t,a.zeroMotionFailures,2);
end
function testRewardMismatchCannotPass(t)
trace=fixture(zeros(3,4),zeros(2,4)); trace.reward(1)=trace.reward(1)+.1;
verifyError(t,@() e2bControlMetrics(trace),"E2B:RewardDecomposition");
end
function trace=fixture(q,u)
p=configurables(); prediction=p.flexJoined_scale(encoder2Flex(q(2:end,:)));
reference=prediction+.1; delta=[u(1,:);diff(u,1,1)];
trace=struct("q",q,"prediction",prediction,"reference",reference, ...
    "rawAction",u,"effectiveAction",u,"pwm",round(u*255), ...
    "reward",-mean((prediction-reference).^2+p.rewardActionWeight*u.^2+ ...
    p.rewardDeltaActionWeight*delta.^2,2));
end
