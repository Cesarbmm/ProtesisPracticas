function tests = testPairedReferenceE2D
% Regresiones de la intervencion E2D y de su evaluacion preregistrada.
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
t.TestData.root = root;
t.TestData.oldPath = path;
assert(~contains(lower(string(path)),"sandbox"),"E2D:ForbiddenPath");
addpath(genpath(fullfile(root,"src")));
addpath(fullfile(root,"config"));
addpath(fullfile(root,"analysis","paired_reference"));
t.TestData.hadOverride = isappdata(0,"configurables_override");
t.TestData.oldOverride = struct();
if t.TestData.hadOverride
    t.TestData.oldOverride = getappdata(0,"configurables_override");
end
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false, ...
    "plotEpisodeOnTest",false,"simPlantSource","patternCurveCanonical", ...
    "actionInterfaceVariant","baselineQuantized"));
[t.TestData.remap,t.TestData.remapCleanup] = e2cHistoricalRemapper(root);
out = fullfile(root,"analysis","paired_reference","e2d_results");
if isappdata(0,"E2DTestOutputDirectory")
    out = getappdata(0,"E2DTestOutputDirectory");
end
t.TestData.out = out;
t.TestData.data = load(fullfile(out,"trajectories.mat"), ...
    "trajectories","baselines","grid");
end

function teardownOnce(t)
if t.TestData.hadOverride
    setConfigurablesOverride(t.TestData.oldOverride);
else
    clearConfigurablesOverride();
end
t.TestData.remapCleanup = [];
path(t.TestData.oldPath);
end

function testFixedPreregisteredGridAndSample(t)
d = t.TestData.data;
verifyEqual(t,d.grid,[0 .03 .05 .08 .12]);
verifySize(t,d.trajectories,[200 5]);
verifyEqual(t,numel(d.baselines),200);
prereg = fullfile(fileparts(t.TestData.root),"docs","paired_reference","PREREGISTRO_E2D.md");
verifyEqual(t,sha256(prereg),"9a9527571f9fac8524aa8b3ef90ee0110ed1bfce075146596868b7e5cd1ee8c9");
end

function testEpsilonZeroReproducesAllTwoHundredEpisodes(t)
d = t.TestData.data;
for k = 1:200
    actual = d.trajectories{k,1}; original = d.baselines{k};
    for field = ["q","rawAction","effectiveAction","pwm", ...
            "referenceBefore","reference","prediction"]
        verifyEqual(t,actual.(field),original.(field), ...
            sprintf("Episodio %d, campo %s",k,field));
    end
    verifyEqual(t,actual.reward,original.reward,"AbsTol",1e-12);
end
end

function testInclusiveDeadbandOnBothSigns(t)
for epsilon = [.03 .05 .08 .12]
    e = [-epsilon-1e-10 -epsilon -epsilon+1e-10 0 epsilon-1e-10 epsilon epsilon+1e-10];
    [raw,historical,inside] = e2dDeadbandAction(e,epsilon);
    verifyEqual(t,inside,abs(e)<=epsilon);
    verifyEqual(t,raw(inside),zeros(size(raw(inside))));
    verifyEqual(t,historical,max(-1,min(1,2*e)));
    verifyEqual(t,raw(~inside),historical(~inside));
end
end

function testOutsideBandExactlyPreservesHistoricalCommand(t)
e = [-2 -.5 -.121 -.0800001 -.0500001 -.0300001 .0300001 .0500001 .0800001 .121 .5 2];
for epsilon = [0 .03 .05 .08 .12]
    [raw,historical,inside] = e2dDeadbandAction(e,epsilon);
    verifyEqual(t,raw(~inside),historical(~inside));
    verifyEqual(t,historical,max(-1,min(1,2*e)));
end
end

function testZeroEpsilonIncludesOnlyAlreadyZeroError(t)
e = [-1 -.025 -eps 0 eps .025 1];
[raw,historical,inside] = e2dDeadbandAction(e,0);
verifyEqual(t,raw,historical);
verifyEqual(t,inside,e==0);
end

function testHistoricalActivationThresholdAndRemapUnchanged(t)
e = [-.025-1e-10 -.025 -.025+1e-10 .025-1e-10 .025 .025+1e-10];
raw = e2dDeadbandAction(e,0);
[effective,pwm] = t.TestData.remap(raw);
verifyEqual(t,pwm,[-64;-64;0;0;64;64]);
verifyEqual(t,effective,pwm/255);
raw = e2dDeadbandAction(e,.03);
[~,pwm] = t.TestData.remap(raw);
verifyEqual(t,pwm,zeros(6,1));
end

function testSubactivationBandHasNoPwmEffect(t)
e = [-.03 -.025 -.024 -.02 -.01 0 .01 .02 .024 .025 .03];
for epsilon = [.01 .02]
    [raw,historical] = e2dDeadbandAction(e,epsilon);
    [~,intervened] = t.TestData.remap(raw);
    [~,original] = t.TestData.remap(historical);
    verifyEqual(t,intervened,original);
end
end

function testRecordedActionsUseHistoricalRemapper(t)
d = t.TestData.data;
for index = 1:numel(d.trajectories)
    tr = d.trajectories{index};
    [effective,pwm] = t.TestData.remap(tr.rawAction(:));
    verifyEqual(t,reshape(effective,size(tr.rawAction)),tr.effectiveAction);
    verifyEqual(t,reshape(pwm,size(tr.rawAction)),tr.pwm);
end
end

function testStoredTransitionsUseUnchangedCanonicalPlant(t)
d = t.TestData.data;
episodes = unique(round(linspace(1,200,10)));
for episode = episodes
    for j = 1:5
        tr = d.trajectories{episode,j};
        for k = 1:size(tr.pwm,1)
            next = SimController.prosthesis_simulator(tr.q(k,:),tr.pwm(k,:), ...
                .2,.14,plantSource="patternCurveCanonical");
            verifyEqual(t,next(end,:),tr.q(k+1,:));
        end
    end
end
end

function testRecordedRewardUsesOriginalFunctionAndInitialAction(t)
d = t.TestData.data;
for index = 1:numel(d.trajectories)
    tr = d.trajectories{index}; previous = zeros(1,4);
    for k = 1:numel(tr.reward)
        context = struct("flexConverted",tr.reference(k,:), ...
            "adjustEnc",tr.prediction(k,:),"prevAction",previous);
        actual = trackingMseActionRateReward(context,tr.effectiveAction(k,:),[]);
        verifyEqual(t,actual,tr.reward(k),"AbsTol",1e-12);
        previous = tr.effectiveAction(k,:);
    end
end
end

function testZeroEpsilonPreservesHistoricalMetricsAndTwoCycles(t)
d = t.TestData.data;
mse = zeros(200,1); rewards = zeros(200,1); cycles = 0;
for k = 1:200
    [~,a] = e2bControlMetrics(d.trajectories{k,1});
    [~,b] = e2bControlMetrics(d.baselines{k});
    verifyEqual(t,a.trackingMSE,b.trackingMSE,"AbsTol",1e-12);
    verifyEqual(t,a.rewardMean,b.rewardMean,"AbsTol",1e-12);
    mse(k) = a.trackingMSE; rewards(k) = a.rewardMean;
    cycles = cycles+a.persistentTwoCycle;
end
% Diez episodios por cada uno de los veinte grupos: la media es la macro E2B.
verifyEqual(t,mean(mse),.025400336373607925,"AbsTol",1e-12);
verifyEqual(t,mean(rewards),-.03272837710980499,"AbsTol",1e-12);
verifyEqual(t,cycles,2);
end

function testCycleScanFinalMatchesOriginalDetectorEveryEpisode(t)
d = t.TestData.data;
for index = 1:numel(d.trajectories)
    tr = d.trajectories{index}; masks = e2dCycleScan(tr.q,tr.pwm);
    [perMotor,~] = e2bControlMetrics(tr);
    verifySize(t,masks,size(tr.pwm));
    verifyEqual(t,logical(masks(end,:)),logical([perMotor.persistentTwoCycle]));
end
end

function testCycleScanReportsSlidingPrefixWithoutChangingDefinition(t)
[q,pwm] = syntheticCycle();
q = [q; q(end,:)]; pwm = [pwm;zeros(1,4)];
masks = e2dCycleScan(q,pwm);
verifyFalse(t,any(masks(1:3,:),"all"));
verifyTrue(t,masks(4,3));
verifyFalse(t,any(masks(5,:)));
end

function testCycleDetectorRejectsZeroCommandsAndSmallAmplitude(t)
[q,pwm] = syntheticCycle(); pwm(2,3) = 0;
verifyFalse(t,any(e2dCycleScan(q,pwm),"all"));
[q,pwm] = syntheticCycle(); q(:,3) = [1541;1542;1541;1542;1541];
verifyFalse(t,any(e2dCycleScan(q,pwm),"all"));
end

function testAllPreregisteredGatesMustPass(t)
g = e2dCandidateGate(passingFacts());
for name = ["passA","passB","passC","passD","passE","passF","passed"]
    verifyTrue(t,g.(name));
end
f = passingFacts(); f.cycles = 1; g = e2dCandidateGate(f);
verifyFalse(t,g.passA); verifyFalse(t,g.passed);
end

function testFivePercentMseAndRewardBoundaries(t)
f = passingFacts(); f.mseChangePct = 5; f.rewardChangePct = 5;
g = e2dCandidateGate(f); verifyTrue(t,g.passed);
f.mseChangePct = 5+1e-8; g = e2dCandidateGate(f);
verifyFalse(t,g.passB); verifyFalse(t,g.passed);
f = passingFacts(); f.rewardChangePct = 5+1e-8; g = e2dCandidateGate(f);
verifyFalse(t,g.passC); verifyFalse(t,g.passed);
end

function testSubgroupDegradationLimitsAreJoint(t)
f = passingFacts(); f.subjectDegradations = 2; f.motorDegradations = 1;
g = e2dCandidateGate(f); verifyTrue(t,g.passD);
for field = ["subjectDegradations","motorDegradations","directionDegradations"]
    invalid = f; invalid.(field) = invalid.(field)+1;
    g = e2dCandidateGate(invalid); verifyFalse(t,g.passD); verifyFalse(t,g.passed);
end
end

function testAnyNewM3ReversalRejectsCandidate(t)
f = passingFacts(); f.m3Reversals = 1;
g = e2dCandidateGate(f); verifyFalse(t,g.passE); verifyFalse(t,g.passed);
f.m3Reversals = 0; g = e2dCandidateGate(f); verifyTrue(t,g.passE);
d = t.TestData.data;
for k = 1:200
    tr = d.trajectories{k,1};
    verifyEqual(t,nnz(tr.pwm(:,3)>0 & diff(tr.q(:,3))<0),0);
end
end

function testMaterialityLimitsUseAbsoluteProportions(t)
f = passingFacts(); f.maxFlatIncrease = .02; f.maxNoMotionIncrease = .05;
g = e2dCandidateGate(f); verifyTrue(t,g.passF);
f.maxFlatIncrease = .02+1e-8; g = e2dCandidateGate(f); verifyFalse(t,g.passF);
f.maxFlatIncrease = .02; f.maxNoMotionIncrease = .05+1e-8;
g = e2dCandidateGate(f); verifyFalse(t,g.passF);
end

function testUndefinedMotionMetricCannotPass(t)
f = passingFacts(); f.motionMetricsDefined = false;
g = e2dCandidateGate(f); verifyFalse(t,g.passF); verifyFalse(t,g.passed);
end

function testTwentyPercentOriginalActiveCommandGuard(t)
f = passingFacts(); f.pairedZeroedActiveFraction = .2;
g = e2dCandidateGate(f); verifyTrue(t,g.passF);
f.pairedZeroedActiveFraction = .2+1e-8;
g = e2dCandidateGate(f); verifyFalse(t,g.passF); verifyFalse(t,g.passed);
end

function testSelectionUsesSmallestPassingPositiveEpsilon(t)
grid = [0 .03 .05 .08 .12];
verifyEqual(t,e2dSelectEpsilon(grid,[true false true true true]),.05);
verifyEqual(t,e2dSelectEpsilon(grid,true(size(grid))),.03);
end

function testSelectionRemainsMissingIfNoInterventionPasses(t)
grid = [0 .03 .05 .08 .12];
verifyTrue(t,isnan(e2dSelectEpsilon(grid,false(size(grid)))));
verifyTrue(t,isnan(e2dSelectEpsilon(grid,[true false false false false])));
end

function testRolloutDeterminismAcrossTwoCalls(t)
base = t.TestData.data.baselines{1};
a = e2dRollout(base,.08,t.TestData.remap);
b = e2dRollout(base,.08,t.TestData.remap);
for field = ["q","rawAction","effectiveAction","pwm","referenceBefore", ...
        "reference","prediction","reward"]
    verifyEqual(t,a.(field),b.(field));
    verifyEqual(t,a.(field),t.TestData.data.trajectories{1,4}.(field));
end
end

function testProtectedHistoricalFilesAndE2CRemainIntact(t)
manifest = readtable(fullfile(t.TestData.out,"historical_hashes_before.csv"),TextType="string");
verifyGreaterThanOrEqual(t,height(manifest),453);
verifyTrue(t,any(contains(manifest.path,"e2c_results")));
for k = 1:height(manifest)
    verifyFalse(t,contains(lower(manifest.path(k)),"sandbox"));
    file = fullfile(t.TestData.root,manifest.path(k));
    verifyTrue(t,isfile(file));
    verifyEqual(t,sha256(file),manifest.sha256(k),char(manifest.path(k)));
end
end

function testHistoricalParametersAndTrainingDisabled(t)
p = configurables();
verifyEqual(t,p.period,.2);
verifyEqual(t,p.actionInterfaceVariant,"baselineQuantized");
verifyEqual(t,p.simPlantSource,"patternCurveCanonical");
verifyEqual(t,p.actionCommandLevels,[0 64 96 128 160 192 224 255]);
verifyEqual(t,p.actionCommandActivationThreshold,.05);
verifyEqual(t,p.speeds,[255 255 255 255]);
verifyEqual(t,p.rewardActionWeight,.01);
verifyEqual(t,p.rewardDeltaActionWeight,.05);
verifyEqual(t,p.observationVariant,"markov52");
verifyFalse(t,p.run_training);
end

function [q,pwm] = syntheticCycle()
q = zeros(5,4); q(:,3) = [1541.6666666666667;7532.5;1541.6666666666667;7532.5;1541.6666666666667];
pwm = zeros(4,4); pwm(:,3) = [224;-64;224;-64];
end

function f = passingFacts()
f = struct("cycles",0,"mseChangePct",0,"rewardChangePct",0, ...
    "subjectDegradations",0,"motorDegradations",0,"directionDegradations",0, ...
    "m3Reversals",0,"maxFlatIncrease",0,"maxNoMotionIncrease",0, ...
    "motionMetricsDefined",true,"pairedZeroedActiveFraction",0);
end

function value = sha256(file)
fid = fopen(file,"rb"); assert(fid>=0); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(fread(fid,Inf,"*uint8"));
value = string(lower(reshape(dec2hex(typecast(digest.digest(),"uint8"),2).',1,[])));
end
