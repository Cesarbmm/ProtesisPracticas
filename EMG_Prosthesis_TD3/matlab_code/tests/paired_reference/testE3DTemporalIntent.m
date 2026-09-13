function tests=testE3DTemporalIntent,tests=functiontests(localfunctions);end
function setupOnce(t)
rng(414);t.TestData.cfg=e3dConfig;t.TestData.a=e3dNetwork("BASELINE");t.TestData.b=e3dNetwork("TEMPORAL_EMG");
end
function testEMGInput40Mechanical12(t)
for n={t.TestData.a,t.TestData.b}
 layers=n{1}.Layers;verifyEqual(t,layers(string({layers.Name})=="emg").InputSize,40);
 verifyEqual(t,layers(string({layers.Name})=="mechanical_current").InputSize,12);
 C=n{1}.Connections;verifyTrue(t,any(string(C.Source)=="mechanical_current" & string(C.Destination)=="concat/in2"));
end
end
function testGRUOnlyEMG(t)
C=t.TestData.b.Connections;verifyEqual(t,string(C.Source(string(C.Destination)=="emg_context")),"emg");
layer=t.TestData.b.Layers(string({t.TestData.b.Layers.Name})=="emg_context");verifyClass(t,layer,'nnet.cnn.layer.GRULayer');verifyEqual(t,layer.NumHiddenUnits,64);
end
function testCausalEMGWindow(t)
s=reshape(1:52*20,52,20);[x,m,ix]=e3dContext(s,12);verifyEqual(t,ix,5:12);verifyEqual(t,x,s(1:40,5:12));verifyEqual(t,m,s(41:52,12));
end
function testNoMechanicalHistory(t)
s=randn(52,12);[x,m]=e3dContext(s,9);s(41:52,1:8)=999;[xx,mm]=e3dContext(s,9);verifyEqual(t,x,xx);verifyEqual(t,m,mm);
end
function testNoFutureLeakage(t)
s=randn(52,15);[x,m]=e3dContext(s,9);s(:,10:end)=999;[xx,mm]=e3dContext(s,9);verifyEqual(t,x,xx);verifyEqual(t,m,mm);
end
function testCurrentMechanicalSensitive(t)
s=randn(52,12);[x,m]=e3dContext(s,9);s(41:52,9)=s(41:52,9)+1;[xx,mm]=e3dContext(s,9);verifyEqual(t,x,xx);verifyEqual(t,mm,m+1,AbsTol=1e-12);
end
function testVariablePrefixes(t)
for L=1:8,[p,h]=e3dPredict(t.TestData.b,"TEMPORAL_EMG",randn(40,L),randn(12,1));verifySize(t,p,[15 4]);verifyTrue(t,all(isfinite(h),"all"));verifyEqual(t,sum(p,1),ones(1,4),AbsTol=1e-6);end
end
function testShufflePastOnly(t)
s=reshape(1:52*12,52,12);[x,m,ix]=e3dContext(s,9,true,2);verifyEqual(t,sort(ix),2:9);verifyNotEqual(t,ix,2:9);verifyEqual(t,x(:,end),s(1:40,9));verifyEqual(t,m,s(41:52,9));verifyEqual(t,sort(x(:,1:end-1),2),sort(s(1:40,2:8),2));
end
function testShuffleDeterministicNoRngEffect(t)
s=randn(52,15);r=rng;[x,m]=e3dContext(s,9,true,2);verifyEqual(t,rng,r);[xx,mm]=e3dContext(s,9,true,2);verifyEqual(t,x,xx);verifyEqual(t,m,mm);
end
function testShortShuffleUnchanged(t)
s=randn(52,3);for k=1:2,[x,m]=e3dContext(s,k);[xx,mm]=e3dContext(s,k,true);verifyEqual(t,x,xx);verifyEqual(t,m,mm);end
end
function testBaselineCurrentEMGOnly(t)
x=randn(40,8);m=randn(12,1);p=e3dPredict(t.TestData.a,"BASELINE",x,m);x(:,1:7)=999;verifyEqual(t,e3dPredict(t.TestData.a,"BASELINE",x,m),p);
end
function testFourActionHeadsAndSeparateIntentOutputs(t)
names=["direction";"head1";"head2";"head3";"head4";"phase_direction"];
for n={t.TestData.a,t.TestData.b},verifyEqual(t,sort(string(n{1}.OutputNames(:))),names);C=n{1}.Connections;verifyFalse(t,any(ismember(string(C.Source),["direction","phase_direction"])));end
end
function testAllSixHeadsAndEMGReceiveGradients(t)
X=dlarray(randn(40,8,4,'single'),'CTB');M=dlarray(randn(12,4,'single'),'CB');Y=repmat([1;3;5;7],1,4);labels=[1 2 1 2;1 6 2 4];
[loss,g,parts]=dlfeval(@e3dLoss,t.TestData.b,X,M,Y,labels);verifyEqual(t,double(extractdata(loss)),sum(double(extractdata(parts))),AbsTol=1e-6);
for name=["emg_context","head1","head2","head3","head4","direction","phase_direction"],v=g.Value(g.Layer==name);verifyGreaterThan(t,sum(cellfun(@(x) sum(abs(double(extractdata(x))),"all"),v)),0);end
end
function testActorResetEpisodeIsolation(t)
a=E3DProbeActor(t.TestData.b,"TEMPORAL_EMG");b=E3DProbeActor(t.TestData.b,"TEMPORAL_EMG");x=randn(52,1);getAction(a,{999*ones(52,1)});reset(a);verifyEmpty(t,a.EMGHistory);verifyEqual(t,getAction(a,{x}),getAction(b,{x}));
end
function testActorOnlyStoresBoundedEMG(t)
a=E3DProbeActor(t.TestData.b,"TEMPORAL_EMG");s=randn(52,12);for k=1:12,getAction(a,{s(:,k)});end
verifyEqual(t,a.EMGHistory,s(1:40,5:12));verifyFalse(t,isprop(a,'MechanicalHistory') || isprop(a,'History'));
end
function testMechanicalPastChangesCannotChangeCurrentDecision(t)
a=E3DProbeActor(t.TestData.b,"TEMPORAL_EMG");b=E3DProbeActor(t.TestData.b,"TEMPORAL_EMG");s=randn(52,9);
for k=1:8,x=s(:,k);y=x;y(41:52)=100;getAction(a,{x});getAction(b,{y});end
getAction(a,{s(:,9)});getAction(b,{s(:,9)});verifyEqual(t,a.Probabilities(:,:,end),b.Probabilities(:,:,end));
end
function testLegalActions(t)
for kind=t.TestData.cfg.models,a=E3DProbeActor(e3dNetwork(kind),kind);u=getAction(a,{zeros(52,1)});verifyTrue(t,all(ismember(u{1}*255,t.TestData.cfg.categories)));end
end
function testNoPrivilegedActorInputs(t)
source=lower(fileread(which('E3DProbeActor')));verifyFalse(t,contains(source,'reference') || contains(source,'glove') || contains(source,'reward') || contains(source,'subject') || contains(source,'phasedirection'));
end
function testLabelsOfflineOnly(t)
D=data(t);ids=find(D.samples.length==8,3);[x,m,y,l]=e3dBatch(D,ids,"TEMPORAL_EMG");
for e=unique(D.samples.episode(ids))',D.sequences{e}.label(:)=15;D.episodes{e}.base.reference(:)=999;end
D.samples.side(ids)=3-D.samples.side(ids);D.samples.phaseDirection(ids)=7-D.samples.phaseDirection(ids);
[xx,mm,yy,ll]=e3dBatch(D,ids,"TEMPORAL_EMG");verifyEqual(t,extractdata(x),extractdata(xx));verifyEqual(t,extractdata(m),extractdata(mm));verifyNotEqual(t,y,yy);verifyNotEqual(t,l,ll);
end
function testSamePhaseDefinitionE3C(t)
D=data(t);for e=1:200,ix=D.samples.episode==e;S=D.samples(ix,:);N=height(S);verifyEqual(t,S.phase,min(3,1+floor(3*(S.step-1)/N)));verifyEqual(t,S.phaseDirection,S.phase+3*(S.side-1));end
end
function testBoundariesAllSamples(t)
D=data(t);for i=1:height(D.samples),s=D.samples(i,:);[x,m,ix]=e3dContext(D.sequences{s.episode}.state,s.step);verifySize(t,x,[40,s.length]);verifySize(t,m,[12,1]);verifyTrue(t,all(ix>=1 & ix<=s.step));end
end
function testFrozenRecipeThreeSeeds(t)
c=t.TestData.cfg;verifyEqual(t,c.seeds,[20260923 20260924 20260925]);verifyEqual(t,c.L,8);verifyEqual(t,c.supervisedEpochs,40);verifyEqual(t,c.supervisedLR,.001);verifyEqual(t,c.supervisedBatch,64);verifyEqual(t,c.supervisedGradientLimit,1);verifyEqual(t,c.lossWeights,[1 1 1]);
verifyEqual(t,c.trainSubjects,["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"]);verifyEqual(t,c.validationSubjects,["JOE","JONATHAN","KHAROL"]);
end
function testPlansTrainOnlyIdenticalAndNetworksChanged(t)
D=data(t);for seed=t.TestData.cfg.seeds
 a=load(model(t,"BASELINE",seed),"plans","net","initial");b=load(model(t,"TEMPORAL_EMG",seed),"plans","net","initial");
 verifyEqual(t,a.plans,b.plans);verifyEqual(t,numel(a.plans),40);verifyNotEqual(t,a.net.Learnables.Value,a.initial.Learnables.Value);verifyNotEqual(t,b.net.Learnables.Value,b.initial.Learnables.Value);
 for epoch=1:40,verifyEqual(t,sort(vertcat(a.plans{epoch}{:})),find(D.samples.split=="TRAIN"));end
end
end
function testClosedLoopSixModelsDeterministic(t)
D=data(t);for seed=t.TestData.cfg.seeds
 for kind=t.TestData.cfg.models
  f=model(t,kind,seed);a=load(f,"saved_actor");d=load(fullfile(fileparts(fileparts(f)),"closed_loop.mat"));
  for e=[1,200],reset(a.saved_actor);[tr,r]=e3axRollout(a.saved_actor,D.episodes{e});orig=d.runtimeTraces{e};for field=["q","state","pwm","rawAction","effectiveAction"],verifyEqual(t,r.(field),orig.(field));end
   verifyEqual(t,tr.reward,d.traces{e}.reward);verifyEqual(t,r.state(2:end,49:52),r.effectiveAction);
  end
 end
end
end
function testClosedLoopWindowsMatchOffline(t)
for seed=t.TestData.cfg.seeds
 f=model(t,"TEMPORAL_EMG",seed);a=load(f,"net");d=load(fullfile(fileparts(fileparts(f)),"closed_loop.mat"));
 for e=[1,140,200],r=d.runtimeTraces{e};for k=1:size(r.pwm,1),[emg,m]=e3dContext(r.state',k);verifyEqual(t,e3dPredict(a.net,"TEMPORAL_EMG",emg,m),r.probabilities(:,:,k));end;end
end
end
function testTeacherCounterfactualActionIdentity(t)
D=data(t);a=load(model(t,"TEMPORAL_EMG",t.TestData.cfg.seeds(1)),"saved_actor");ep=D.episodes{200};reset(a.saved_actor);[tr,r]=e3axRollout(a.saved_actor,ep);
ep.base.reference=1-ep.base.reference;ep.base.referenceBefore=1-ep.base.referenceBefore;reset(a.saved_actor);[other,ro]=e3axRollout(a.saved_actor,ep);
verifyEqual(t,r.q,ro.q);verifyEqual(t,r.state,ro.state);verifyEqual(t,r.pwm,ro.pwm);verifyNotEqual(t,tr.reward,other.reward);
end
function testIntentMetricsReconstruction(t)
D=data(t);for kind=t.TestData.cfg.models
 folder=fileparts(fileparts(model(t,kind,t.TestData.cfg.seeds(1))));a=load(fullfile(folder,"imitation.mat"));I=e3dIntentMetrics(a.dir,a.phase,D.samples);
 R=readtable(fullfile(folder,"intent_metrics.csv"),TextType="string",Delimiter=",");for field=["macroF1","NLL","accuracy"],verifyEqual(t,I.(field),R.(field),AbsTol=1e-12);end
end
end
function testFrozenDiagnosticSelection(t)
a=fileread(fullfile(t.TestData.cfg.output,"diagnostic_selection.csv"));b=fileread(fullfile(fileparts(t.TestData.cfg.output),"e3c_results","diagnostic_selection.csv"));verifyEqual(t,a,b);
end
function testScientificGatesMatchPreregistration(t)
s=jsondecode(fileread(fullfile(t.TestData.cfg.output,"scientific_summary.json")));a=s.means.BASELINE;b=s.means.TEMPORAL_EMG;sh=s.shuffled;g=struct2array(s.gates);
expected=[b.directionF1>=a.directionF1+.03,b.phaseDirectionF1>=a.phaseDirectionF1+.05,b.phaseDirectionF1>=sh.phaseDirectionF1+.02,b.openingMSE<=.90*a.openingMSE,b.closingMSE<=1.05*a.closingMSE,b.MSE<a.MSE,b.cycles==0 && b.periodic==0,sum([s.bySeed.TEMPORAL_EMG.m3Reversals])<=sum([s.bySeed.BASELINE.m3Reversals])+1,b.maxCategoryFraction<=.90];
verifyEqual(t,logical(g),expected);verifyEqual(t,s.TEMPORAL_EMG_CONTEXT_SUPPORTED,all(expected));
end
function testHistoricalIntegrity(t)
H=readtable(fullfile(t.TestData.cfg.output,"historical_hashes_before.csv"),TextType="string",Delimiter=",");
for k=1:height(H),if H.path(k)==fullfile(t.TestData.cfg.root,"exportE3AXViewerTrace.m"),continue;end;verifyEqual(t,cap192SHA256(H.path(k)),H.sha256(k));end
end
function D=data(t),a=load(fullfile(fileparts(t.TestData.cfg.output),"e3c_results","supervised_data.mat"),"D");D=a.D;end
function file=model(t,kind,seed),file=fullfile(t.TestData.cfg.output,kind+"_"+seed,"checkpoints","ProbeEpoch040.mat");end
function testCompactComplete(t)
for seed=t.TestData.cfg.seeds,for kind=t.TestData.cfg.models
 folder=fileparts(fileparts(model(t,kind,seed)));verifyEqual(t,numel(dir(fullfile(folder,"figures","TRAIN","*.png"))),140);verifyEqual(t,numel(dir(fullfile(folder,"figures","VALIDATION","*.png"))),60);verifyEqual(t,numel(dir(fullfile(folder,"figures","**","*.fig"))),200);
end;end
end
function testCompactFourMotors(t)
folder=fileparts(fileparts(model(t,"TEMPORAL_EMG",t.TestData.cfg.seeds(1))));files=dir(fullfile(folder,"figures","VALIDATION","*.fig"));f=openfig(fullfile(files(1).folder,files(1).name),"invisible");c=onCleanup(@() close(f)); %#ok<NASGU>
verifyEqual(t,numel(findall(f,Type="axes")),4);verifyEqual(t,numel(findall(f,Tag="reference")),4);verifyEqual(t,numel(findall(f,Tag="prediction")),4);verifyEmpty(t,findall(f,Tag="effectiveActionLabel"));
end
function testAnnotatedTwoPolicies(t)
files=dir(fullfile(t.TestData.cfg.output,"annotated","**","*.fig"));verifyEqual(t,numel(files),12);f=openfig(fullfile(files(1).folder,files(1).name),"invisible");c=onCleanup(@() close(f)); %#ok<NASGU>
verifyEqual(t,numel(findall(f,Type="axes")),8);verifyEqual(t,numel(findall(f,Tag="reference")),8);verifyEqual(t,numel(findall(f,Tag="prediction")),8);
d=load(fullfile(files(1).folder,replace(files(1).name,'.fig','.mat')),"T");verifyEqual(t,numel(findall(f,Tag="effectiveActionLabel")),height(d.T));
end
function testAnnotatedCsvMatExactValues(t)
files=dir(fullfile(t.TestData.cfg.output,"annotated","**","*.mat"));verifyEqual(t,numel(files),12);
for file=files'
 d=load(fullfile(file.folder,file.name),"T");R=readtable(fullfile(file.folder,replace(file.name,'.mat','.csv')),TextType="string",Delimiter=",");verifyEqual(t,d.T.policy,R.policy);
 for field=["step","motor","teacher","h_q","category","PWM","effectiveAction","selectedProbability","headEntropy","q","delta_q"],verifyEqual(t,d.T.(field),R.(field),AbsTol=1e-9);end
 verifyEqual(t,R.effectiveAction,R.PWM/255,AbsTol=1e-12);verifyTrue(t,all(R.selectedProbability>=0 & R.selectedProbability<=1));
end
end
function testViewerFormatProvenanceAndAlignment(t)
files=dir(fullfile(t.TestData.cfg.output,"viewer","**","viewer_trace.mat"));verifyEqual(t,numel(files),18);
for file=files'
 v=load(fullfile(file.folder,file.name));verifyEqual(t,v.time,v.step*.2);verifyEqual(t,size(v.q,1),size(v.PWM,1)+1);verifyEqual(t,v.state(2:end,49:52),v.PWM/255);
 verifyEqual(t,v.checkpointSHA256,cap192SHA256(v.checkpoint));verifyFalse(t,v.teacherLoaded || v.trainingExecuted);verifyEqual(t,string(v.plantManifest.simPlantSource),"patternCurveCanonical");
end
end
