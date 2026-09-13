function tests=testPairedReferenceE2CCycles
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));t.TestData.root=root;
t.TestData.oldPath=path;addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
t.TestData.had=isappdata(0,"configurables_override");t.TestData.old=struct();
if t.TestData.had,t.TestData.old=getappdata(0,"configurables_override");end
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
[t.TestData.remap,t.TestData.cleanup]=e2cHistoricalRemapper(root);
end
function teardownOnce(t)
if t.TestData.had,setConfigurablesOverride(t.TestData.old);else,clearConfigurablesOverride();end
path(t.TestData.oldPath);
end
function testClosedLoopM3FixedTeacher(t)
runPair(t,3,[1541.6666666666667 7532.5],.739980449657869,[224 -64]);
end
function testClosedLoopM4FixedTeacher(t)
runPair(t,4,[6049.75 2976.3333333333335],.6456500488758553,[-64 96]);
end
function testMovingTeacherChangesM3PairNotOscillation(t)
runPair(t,3,[1541.6666666666667 7584.5],.7702834799608993,[255 -64]);
end
function testActivationBoundaryHas64PWMJump(t)
[~,a]=t.TestData.remap([.05-1e-10 .05 .05+1e-10]);
verifyEqual(t,a,[0;64;64]);
end
function testAdjacentLevelTieChoosesLower(t)
[~,a]=t.TestData.remap([80/255-1e-10 80/255 80/255+1e-10]);
verifyEqual(t,a,[64;64;96]);
end
function testNoInfinitesimal224ToMinus64Boundary(t)
b=[.05 ([64 96 128 160 192 224]+[96 128 160 192 224 255])/510];
for edge=[-b b]
    [~,a]=t.TestData.remap([edge-1e-10 edge+1e-10]);verifyLessThanOrEqual(t,abs(diff(a)),64);
end
end
function testDeterministicCycleClassification(t)
verifyEqual(t,e2cCycleClassify(true,true,true,true),"QUANTIZATION_OVERSHOOT");
verifyEqual(t,e2cCycleClassify(true,true,true,false),"PLANT_STEP_SIZE");
verifyEqual(t,e2cCycleClassify(true,false,false,false),"MOVING_REFERENCE");
verifyEqual(t,e2cCycleClassify(false,true,true,true),"UNRESOLVED");
end
function testFullHistoricalReplayArtifacts(t)
out=fullfile(t.TestData.root,"analysis","paired_reference","e2c_results");
s=jsondecode(fileread(fullfile(out,"cycle_summary.json")));
verifyEqual(t,[s.maxHistoricalQError s.maxHistoricalRawError s.maxHistoricalRewardError],[0 0 0]);
f=readtable(fullfile(out,"cycle_fixed_reference_summary.csv"));
verifyTrue(t,all(f.anyTwoCycle));verifyEqual(t,nnz(f.originalPairPersists),18);
end
function runPair(t,motor,pair,reference,commands)
for start=1:2
    q=zeros(1,4);q(motor)=pair(start);
    for k=1:30
        index=mod(start+k-2,2)+1;prediction=encoder2Flex(q)./[4092 2046 1023 2046];
        raw=max(-1,min(1,2*(reference-prediction(motor))));[~,pwm]=t.TestData.remap(raw);
        verifyEqual(t,pwm,commands(index));u=zeros(1,4);u(motor)=pwm;
        q=SimController.prosthesis_simulator(q,u,.2,.14,plantSource="patternCurveCanonical");
        verifyEqual(t,q(motor),pair(3-index),"AbsTol",1e-9);
    end
end
end
