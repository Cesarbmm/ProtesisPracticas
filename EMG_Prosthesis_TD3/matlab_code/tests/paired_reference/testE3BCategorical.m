function tests=testE3BCategorical
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));pr=fullfile(root,"analysis","paired_reference");
oldPath=path;t.addTeardown(@() path(oldPath));addpath(root,pr,fullfile(pr,"e3b"),fullfile(pr,"e3ax"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
t.TestData.root=root;t.TestData.pr=pr;
t.TestData.smoke=strtrim(string(fileread(fullfile(pr,"e3b_preparation","smoke_path.txt"))));
t.TestData.summary=jsondecode(fileread(fullfile(t.TestData.smoke,"summary.json")));
t.TestData.cfg=e3bConfig("smoke");
t.TestData.saved=load(t.TestData.summary.lastCheckpoint);
[t.TestData.emg,t.TestData.teacher]=loadE2ADevelopmentEpisode("BLANCA",1,1,includeTeacher=true);
end
function setup(t)
old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
r=rng;t.addTeardown(@() rng(r));t.addTeardown(@() setConfigurablesOverride(old));
o=t.TestData.saved.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);rng(20260911);
end
function testFrozenScientificRecipe(t)
c=e3bConfig;verifyEqual(t,c.maxAgentSteps,1000000);verifyEqual(t,c.checkpointSteps,[50000 100000 250000 500000 750000 1000000]);
verifyEqual(t,c.seed,20260910);verifyEqual(t,c.gamma,.99);verifyEqual(t,c.gaeLambda,.95);verifyEqual(t,c.epochs,4);
verifyEqual(t,c.rolloutLength,1024);verifyEqual(t,c.minibatch,64);verifyEqual(t,c.clip,.2);verifyEqual(t,c.entropyWeight,.01);
verifyFalse(t,c.rewardNormalization);verifyEqual(t,c.selection,"MIN_VALIDATION_MSE_THEN_REWARD_THEN_STEPS");
end
function testFourIndependentHeads(t)
[a,v]=e3bNetworks(t.TestData.cfg);verifyEqual(t,sort(string(a.OutputNames(:))),["head1";"head2";"head3";"head4"]);
for m=1:4,i=find(string({a.Layers.Name})=="head"+m);verifyEqual(t,a.Layers(i).OutputSize,15);end
z=e3bLogits(a,dlarray(zeros(52,3,"single"),"CB"));verifySize(t,z,[15 4 3]);
verifySize(t,forward(v,dlarray(zeros(52,3,"single"),"CB")),[1 3]);
end
function testCategoryOrdering(t)
expected=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
verifyEqual(t,e3bCategoryPWM(repmat(1:15,4,1)),repmat(expected,4,1));
verifyEqual(t,e3bCategoryPWM([2;5;10;15]),[-64;96;-192;255]);
end
function testInvalidCategoryRejected(t)
verifyError(t,@() e3bCategoryPWM([0;1;1;1]),"E3B:Category");
verifyError(t,@() e3bCategoryPWM([16;1;1;1]),"E3B:Category");
verifyError(t,@() e3bCategoryPWM([2.2;1;1;1]),"E3B:Category");
end
function testUniformJointLogProbabilityAndEntropy(t)
[lp,h,p]=e3bCategoricalTerms(dlarray(zeros(15,4,7)),ones(4,7));
verifyEqual(t,extractdata(lp),-4*log(15)*ones(1,7),AbsTol=1e-12);
verifyEqual(t,extractdata(h),log(15)*ones(4,7),AbsTol=1e-12);
verifyEqual(t,sum(extractdata(p),1),ones(1,4,7),AbsTol=1e-12);
end
function testNonuniformFactorization(t)
z=reshape(sin(1:120),15,4,2);cats=[2 3;4 5;6 7;8 9];
[lp,h,p]=e3bCategoricalTerms(dlarray(z),cats);p=extractdata(p);
for b=1:2
    selected=zeros(1,4);for m=1:4,selected(m)=p(cats(m,b),m,b);end
    verifyEqual(t,extractdata(lp(b)),sum(log(selected)),AbsTol=1e-12);
    verifyEqual(t,sum(extractdata(h(:,b))),-sum(p(:,:,b).*log(p(:,:,b)),"all"),AbsTol=1e-12);
end
end
function testStableExtremeLogits(t)
z=1000*ones(15,4,3);z(1,:,:)= -1000;[lp,h,p]=e3bCategoricalTerms(dlarray(z),ones(4,3));
verifyTrue(t,all(isfinite(extractdata(lp)),"all"));verifyTrue(t,all(isfinite(extractdata(h)),"all"));verifyTrue(t,all(isfinite(extractdata(p)),"all"));
end
function testDeterministicTieUsesZero(t)
[a,~]=e3bNetworks(t.TestData.cfg);a=dlupdate(@(x) x*0,a);actor=E3BCategoricalActor(a);
action=getAction(actor,{zeros(52,1)});verifyEqual(t,action{1},zeros(4,1));
end
function testSamplingLegalAndReproducible(t)
a=t.TestData.saved.saved_actor.Network;s=zeros(52,1);
rng(15);[ca,lp,ent]=e3bSample(a,s);rng(15);[cb,lq,entb]=e3bSample(a,s);
verifyEqual(t,ca,cb);verifyEqual(t,lp,lq);verifyEqual(t,ent,entb);verifyTrue(t,all(ca>=1 & ca<=15));
end
function testGAEAnalyticEpisode(t)
[A,R]=e3bGAE([1 2],[.5 .6],[.6 .7],[false true],.9,1);
verifyEqual(t,A,[2.3 1.4],AbsTol=1e-12);verifyEqual(t,R,[2.8 2],AbsTol=1e-12);
end
function testTeacherDoneStopsBootstrapAndRecursion(t)
[A,R]=e3bGAE([1 999],[.5 10],[999 999],[true false],.9,.95);
verifyEqual(t,A(1),.5);verifyEqual(t,R(1),1);
end
function testRolloutCutKeepsBootstrap(t)
[A,R]=e3bGAE(1,.5,.7,false,.9,.95);verifyEqual(t,A,1.13,AbsTol=1e-12);verifyEqual(t,R,1.63,AbsTol=1e-12);
end
function testPositiveAdvantageClipsPpoRatio(t)
[la,lv]=analyticLoss(t,2,1);verifyEqual(t,la,-1.2,AbsTol=1e-5);verifyEqual(t,lv,2,AbsTol=1e-5);
end
function testNegativeAdvantageClipsOtherSide(t)
[la,~]=analyticLoss(t,.5,-1);verifyEqual(t,la,.8,AbsTol=1e-5);
end
function testSixtyCategoryTransitionAndRewardEquivalences(t)
emg=t.TestData.emg;teacher=t.TestData.teacher;catEnv=E3BTrainingEnv({emg,emg},{teacher,teacher});
legacy=Env("",true,{emg,emg},{teacher,teacher});cases={};levels=[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
for motor=1:4
    for c=1:15
        rng(55);s=reset(catEnv);rng(55);sl=reset(legacy);verifyEqual(t,s,sl);
        q0=catEnv.Historical.motorData(end,:);pwm=zeros(4,1);pwm(motor)=levels(c);category=ones(4,1);category(motor)=c;
        clock=Timing(false,.2);plant=SimController(clock);plant.resetBuffer(q0);
        plant.sendAllSpeed(pwm(1),pwm(2),pwm(3),pwm(4));clock.toc(1);direct=plant.read();
        [sc,rc,dc,rec]=step(catEnv,category);[sh,rh,dh]=step(legacy,pwm/255);
        verifyEqual(t,rec.pwm,pwm);verifyEqual(t,rec.effectiveAction,pwm/255);
        verifyEqual(t,rec.q,direct(end,:));verifyEqual(t,rec.q,legacy.motorData(end,:));
        verifyEqual(t,sc,sh);verifyEqual(t,rc,rh);verifyEqual(t,dc,dh);
        cases{end+1}=struct("motor",motor,"category",c,"pwm",pwm(motor),"qDiff",max(abs(rec.q-direct(end,:))),"rewardDiff",abs(rc-rh)); %#ok<AGROW>
    end
end
writetable(struct2table([cases{:}]),fullfile(t.TestData.pr,"e3b_preparation","transition_equivalence.csv"));
end
function testPreviousEffectiveAcrossMultipleSteps(t)
env=E3BTrainingEnv({t.TestData.emg,t.TestData.emg},{t.TestData.teacher,t.TestData.teacher});reset(env);previous=zeros(4,1);
for c=2:6
    category=c*ones(4,1);[s,~,~,r]=step(env,category);verifyEqual(t,r.previousEffective,previous);verifyEqual(t,s(49:52),r.pwm/255);previous=r.effectiveAction;
end
end
function testFrozenPlantRewardAndObservation(t)
p=configurables();verifyEqual(t,string(p.simPlantSource),"patternCurveCanonical");verifyEqual(t,p.period,.2);
verifyEqual(t,p.actionCommandLevels,[0 64 96 128 160 192 224 255]);verifyEqual(t,string(p.observationVariant),"markov52");
verifyEqual(t,p.rewardActionWeight,.01);verifyEqual(t,p.rewardDeltaActionWeight,.05);verifyEqual(t,p.numEMGFeatures,40);
end
function testSmokeReallyLearnedActorCriticAndAllHeads(t)
s=t.TestData.summary;verifyEqual(t,s.completedEpisodes,6);verifyEqual(t,s.agentSteps,132);
verifyTrue(t,s.learning.actorChanged && s.learning.criticChanged && s.learning.allHeadsReceivedGradient);
verifyGreaterThan(t,s.learning.headGradientMax,zeros(4,1));verifyEqual(t,s.learning.updates,16);
init=load(fullfile(t.TestData.smoke,"initial_networks.mat"));
verifyNotEqual(t,init.initialActor.Learnables.Value,t.TestData.saved.saved_actor.Network.Learnables.Value);
verifyNotEqual(t,init.initialCritic.Learnables.Value,t.TestData.saved.saved_critic.Learnables.Value);
end
function testSmokeRolloutsFiniteOnPolicyAndExactReward(t)
files=dir(fullfile(t.TestData.smoke,"smoke_rollout_*.mat"));total=0;versions=[];allsteps=[];
for f=files'
    d=load(fullfile(f.folder,f.name));b=d.lastRollout;n=numel(b.reward);total=total+n;
    for field=["state","nextState","logp","headEntropy","value","nextValue","reward"],verifyTrue(t,all(isfinite(b.(field)),"all"));end
    verifyEqual(t,numel(unique(b.policyVersion)),1);versions(end+1)=b.policyVersion(1); %#ok<AGROW>
    verifyEqual(t,b.pwm,e3bCategoryPWM(b.category));verifyEqual(t,b.nextState(49:52,:),b.pwm/255);
    expected=mean(-(b.prediction-b.reference).^2-.01*(b.pwm/255).^2-.05*(b.pwm/255-b.previousEffective).^2,1);
    verifyEqual(t,b.reward,expected,AbsTol=1e-12);allsteps=[allsteps b.step]; %#ok<AGROW>
end
verifyEqual(t,total,132);verifyEqual(t,allsteps,1:132);verifyEqual(t,versions,[0 8]);
end
function testCheckpointStoresOptimizersAndEpisode(t)
s=t.TestData.saved;verifyEqual(t,s.checkpointInfo.agentSteps,132);verifyEqual(t,s.checkpointInfo.episode,6);
verifyTrue(t,s.checkpointInfo.episodeComplete);verifyFalse(t,s.checkpointInfo.fullTrainingResumeAvailable);
verifyNotEmpty(t,s.optimizer.actorAverage);verifyNotEmpty(t,s.optimizer.criticSquared);
verifyEqual(t,s.optimizer.iteration,16);verifyEqual(t,numel(s.rollout.reward),66);
end
function testCheckpointCannotOverwrite(t)
s=t.TestData.saved;
verifyError(t,@() e3bCheckpoint(t.TestData.smoke,s.saved_actor.Network,s.saved_critic,s.optimizer,s.cfg,s.o,132,6,true,[],[]),"E3B:CheckpointExists");
end
function testExactLongCheckpointScheduleWithoutFakeTerminal(t)
cfg=e3bConfig;
for step=cfg.checkpointSteps
    a=e3bSchedule(cfg,step,12,false,48);verifyTrue(t,a.checkpoint && a.update);verifyFalse(t,a.terminal);verifyEqual(t,a.stop,step==1000000);
    a=e3bSchedule(cfg,step-1,12,false,47);verifyFalse(t,a.checkpoint || a.stop);
end
verifyError(t,@() e3bSchedule(cfg,1000001,12,false,1),"E3B:Budget");
end
function testSmokeStopsOnlyAtSixCompletedEpisodes(t)
cfg=e3bConfig("smoke");a=e3bSchedule(cfg,132,6,true,66);verifyTrue(t,a.stop && a.checkpoint && a.update);
a=e3bSchedule(cfg,131,5,false,65);verifyFalse(t,a.stop || a.checkpoint);
end
function testGreedyRuntimeDeterministicWithoutTeacher(t)
o=t.TestData.saved.o;o.run_training=false;setConfigurablesOverride(o);
actor=t.TestData.saved.saved_actor;
rt1=GloveFreePolicyRuntime(t.TestData.emg);rt2=GloveFreePolicyRuntime(t.TestData.emg);
while ~rt1.exhausted
    a=getAction(actor,{rt1.state});b=getAction(actor,{rt2.state});verifyEqual(t,a,b);
    [sa,da,ra]=rt1.advance(a);[sb,db,rb]=rt2.advance(b);
    verifyEqual(t,sa,sb);verifyEqual(t,da,db);verifyEqual(t,ra.q,rb.q);verifyEqual(t,ra.pwm,rb.pwm);verifyEqual(t,sa(49:52),ra.pwm/255);
end
verifyFalse(t,isprop(actor,"glove"));verifyFalse(t,isprop(rt1,"glove"));
end
function testEvaluationEntropyAndCollapseCounts(t)
folder=fullfile(t.TestData.smoke,"evaluation","best_checkpoint","metrics");
G=readtable(fullfile(folder,"categorical_grouped.csv"),TextType="string",Delimiter=",");
F=readtable(fullfile(folder,"category_distribution.csv"),TextType="string",Delimiter=",");
for motor=1:4
    g=G(G.split=="ALL" & G.dimension=="motor" & G.motor==motor,:);
    f=F(F.split=="ALL" & F.dimension=="motor" & F.motor==motor,:);
    verifyEqual(t,sum(f.fraction),1,AbsTol=1e-12);verifyEqual(t,g.maxCategoryFraction,max(f.fraction),AbsTol=1e-12);
    verifyGreaterThanOrEqual(t,g.headEntropy,0);verifyLessThanOrEqual(t,g.headEntropy,log(15)+1e-6);
end
end
function testBestLastCompleteEpisodeFigures(t)
I=e3axCheckEvaluationFiles(t.TestData.smoke);verifyEqual(t,height(I),8);
verifyEqual(t,nnz(I.split=="TRAIN"),4);verifyEqual(t,nnz(I.split=="VALIDATION"),4);
verifyTrue(t,isfile(fullfile(t.TestData.smoke,"TEST_COMPORTAMENTAL.html")));
end
function testViewerCategoricalSameFormatAndState(t)
v=load(fullfile(t.TestData.smoke,"evaluation","best_checkpoint","viewer_trace.mat"));
d=load(fullfile(t.TestData.smoke,"evaluation","best_checkpoint","metrics","trajectories.mat"));
r=d.runtimeTraces{1};verifyEqual(t,v.q,r.q);verifyEqual(t,v.PWM,r.pwm);verifyEqual(t,v.Ts,.2);
verifyEqual(t,v.state(2:end,49:52),v.PWM/255);verifyTrue(t,startsWith(v.policy,"CATEGORICAL_E3B"));
verifyFalse(t,v.teacherLoaded || v.trainingExecuted || v.cap192);
end
function testViewerRejectsCategoryCap(t)
folder=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
verifyError(t,@() exportE3AXViewerTrace(string(t.TestData.summary.lastCheckpoint),"BLANCA",1,"closing",fullfile(folder.Folder,"viewer.mat"),cap192=true),"E3B:NoCap");
end
function testSameSubjectSplitAndTeacherOriginal(t)
c=e3bConfig;verifyEqual(t,c.trainSubjects,["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"]);
verifyEqual(t,c.validationSubjects,["JOE","JONATHAN","KHAROL"]);verifyEqual(t,c.referenceTransform,"ORIGINAL");verifyFalse(t,c.referenceContractValidated);
end
function testClassificationRequiresFullBudget(t)
c=e3bConfig;R=records;R.steps=[50000;100000;250000];s=e3bClassify(R,c);verifyEqual(t,s.classification,"BUDGET_NOT_COMPLETED");verifyFalse(t,s.continueTo5M);
end
function testStrongSignalAndFavorableTrend(t)
c=e3bConfig;s=e3bClassify(records,c);verifyEqual(t,s.classification,"CAT_STRONG_SIGNAL");verifyTrue(t,s.continueTo5M);verifyFalse(t,s.massiveTrainingJustified);
end
function testPathologiesBlockEscalation(t)
c=e3bConfig;
for f=["m3Reversals","cycles","periodic","maxCategoryFraction"]
    R=records;R.(f)(:)=1;s=e3bClassify(R,c);verifyEqual(t,s.classification,"SIGNAL_WITH_PATHOLOGY");verifyFalse(t,s.continueTo5M);
end
end
function testDegradingLateTrendBlocksEscalation(t)
c=e3bConfig;R=records;R.mse=[.048;.049;.050];s=e3bClassify(R,c);verifyFalse(t,s.continueTo5M);
end
function testNoScientificClaimFromSmoke(t)
R=records;c=e3bConfig("smoke");s=e3bClassify(R,c);verifyEqual(t,s.classification,"SMOKE_INFRASTRUCTURE_ONLY");
verifyFalse(t,s.continueTo5M || s.massiveTrainingJustified);
end
function testCustomMonitorApiWorksInR2023b(t)
m=trainingProgressMonitor(Metrics=["EpisodeReward","AverageReward","ActorLoss","CriticLoss","ValidationMSE"],Info=["Episode","AgentSteps"],XLabel="Agent steps",Visible="off");
clean=onCleanup(@() delete(m)); %#ok<NASGU>
recordMetrics(m,66,EpisodeReward=-1,AverageReward=-2,ActorLoss=.1,CriticLoss=.2);
recordMetrics(m,66,ValidationMSE=.1);updateInfo(m,Episode=3,AgentSteps=66);m.Progress=50;
verifyEqual(t,m.MetricData.ValidationMSE(end,:),[66 .1]);verifyEqual(t,m.Progress,50);
end
function testHistoricalFilesIntact(t)
H=readtable(fullfile(t.TestData.pr,"e3b_preparation","historical_hashes_before.csv"),TextType="string",Delimiter=",");
for k=1:height(H),verifyEqual(t,cap192SHA256(fullfile(t.TestData.root,H.path(k))),H.sha256(k));end
end
function [la,lv]=analyticLoss(t,ratio,adv)
cfg=t.TestData.cfg;cfg.entropyWeight=0;[a,v]=e3bNetworks(cfg);a=dlupdate(@(x) x*0,a);v=dlupdate(@(x) x*0,v);
states=dlarray(zeros(52,4,"single"),"CB");cats=ones(4,4);old=single(-4*log(15)-log(ratio))*ones(1,4,"single");
[la,lv]=dlfeval(@e3bLoss,a,v,states,cats,dlarray(old),dlarray(single(adv)*ones(1,4,"single")),dlarray(2*ones(1,4,"single")),cfg);
la=double(extractdata(la));lv=double(extractdata(lv));
end
function R=records
R=table([500000;750000;1000000],[.050;.049;.048],[-.06;-.059;-.058],zeros(3,1),zeros(3,1),zeros(3,1),.5*ones(3,1), ...
    VariableNames=["steps","mse","reward","m3Reversals","cycles","periodic","maxCategoryFraction"]);
end
