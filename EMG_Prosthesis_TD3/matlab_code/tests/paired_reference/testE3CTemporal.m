function tests=testE3CTemporal,tests=functiontests(localfunctions);end
function setupOnce(t)
here=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));pr=fullfile(here,"analysis","paired_reference");t.TestData.cfg=e3cConfig;
addpath(fullfile(pr,"e3c"));rng(414);t.TestData.ff=e3cNetwork("FF");t.TestData.gru=e3cNetwork("GRU");
end
function testCausalIndices(t)
s=reshape(1:52*20,52,20);[x,ix]=e3cContext(s,10,8);verifyEqual(t,ix,3:10);verifyEqual(t,x,s(:,3:10));
end
function testNoFutureLeakage(t)
s=randn(52,20);x=e3cContext(s,7,8);s(:,8:end)=999;verifyEqual(t,e3cContext(s,7,8),x);
end
function testPrefixLength(t)
s=randn(52,20);for k=1:12,verifySize(t,e3cContext(s,k,8),[52,min(8,k)]);end
end
function testShuffledMultisetAndCurrent(t)
s=reshape(1:52*20,52,20);[x,ix]=e3cContext(s,12,8,true,2);verifyEqual(t,sort(ix),5:12);verifyEqual(t,x(:,end),s(:,12));verifyNotEqual(t,ix,5:12);
end
function testShuffleDeterministicAndRng(t)
s=randn(52,20);r=rng;x=e3cContext(s,12,8,true,2);verifyEqual(t,rng,r);verifyEqual(t,e3cContext(s,12,8,true,2),x);
end
function testShortShuffle(t)
s=randn(52,3);for k=1:2,verifyEqual(t,e3cContext(s,k,8,true),e3cContext(s,k,8));end
end
function testFourHeads(t)
for net={t.TestData.ff,t.TestData.gru},verifyEqual(t,sort(string(net{1}.OutputNames(:))),["head1";"head2";"head3";"head4"]);end
end
function testRealGRULayer(t)
net=t.TestData.gru;ix=find(string({net.Layers.Name})=="memory");verifyClass(t,net.Layers(ix),'nnet.cnn.layer.GRULayer');verifyEqual(t,net.Layers(ix).NumHiddenUnits,64);verifyEqual(t,net.Layers(ix).OutputMode,'last');
end
function testGRUVariablePrefixesFinite(t)
for L=1:8,[p,h]=e3cPredict(t.TestData.gru,"GRU",randn(52,L,3));verifySize(t,p,[15,4,3]);verifyTrue(t,all(isfinite(h),"all"));verifyEqual(t,sum(p,1),ones(1,4,3),AbsTol=1e-6);end
end
function testFFUsesCurrentOnly(t)
x=randn(52,8);[p,~]=e3cPredict(t.TestData.ff,"FF",x);x(:,1:7)=500;verifyEqual(t,e3cPredict(t.TestData.ff,"FF",x),p);
end
function testActorReset(t)
a=E3CProbeActor(t.TestData.gru,"GRU",8);x=randn(52,1);p=getAction(a,{x});getAction(a,{randn(52,1)});reset(a);verifyEmpty(t,a.History);verifyEqual(t,getAction(a,{x}),p);
end
function testActorMemoryBounded(t)
a=E3CProbeActor(t.TestData.gru,"GRU",8);for k=1:11,getAction(a,{randn(52,1)});end;verifySize(t,a.History,[52,8]);
end
function testEpisodeIsolation(t)
a=E3CProbeActor(t.TestData.gru,"GRU",8);b=E3CProbeActor(t.TestData.gru,"GRU",8);getAction(a,{99*ones(52,1)});reset(a);x=randn(52,1);verifyEqual(t,getAction(a,{x}),getAction(b,{x}));
end
function testLegalCategoricalActions(t)
for kind=["FF","GRU"],a=E3CProbeActor(e3cNetwork(kind),kind,8);u=getAction(a,{zeros(52,1)});verifyTrue(t,all(ismember(u{1}*255,t.TestData.cfg.categories)));end
end
function testNoTeacherActorInterface(t)
file=which('E3CProbeActor');source=lower(fileread(file));verifyFalse(t,contains(source,'reference') || contains(source,'trackingerror') || contains(source,'glove'));
end
function testGradientsAllHeadsAndGRU(t)
X=dlarray(randn(52,8,4,'single'),'CTB');Y=repmat([1;3;5;7],1,4);[loss,g]=dlfeval(@gradientFixture,t.TestData.gru,X,Y);
verifyTrue(t,isfinite(extractdata(loss)));for name=["memory","head1","head2","head3","head4"],v=g.Value(g.Layer==name);verifyGreaterThan(t,sum(cellfun(@(x) sum(abs(double(extractdata(x))),"all"),v)),0);end
end
function [loss,g]=gradientFixture(net,X,Y)
z=e3cForward(net,X);lp=e3bCategoricalTerms(z,Y);loss=-mean(lp)/4;g=dlgradient(loss,net.Learnables);
end
function testFrozenRecipeAndSplit(t)
c=t.TestData.cfg;verifyEqual(t,c.seeds,[20260912,20260913,20260914]);verifyEqual(t,c.supervisedEpochs,40);verifyEqual(t,c.supervisedLR,.001);verifyEqual(t,c.supervisedBatch,64);verifyEqual(t,c.L,8);
verifyEqual(t,c.trainSubjects,["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"]);verifyEqual(t,c.validationSubjects,["JOE","JONATHAN","KHAROL"]);
end
function testOracleLabelsOnlyTarget(t)
D=data(t);ids=find(D.samples.length==8,3);[x,y]=e3cBatch(D,ids,"GRU");
for e=unique(D.samples.episode(ids))',D.sequences{e}.label=ones(size(D.sequences{e}.label))*15;D.episodes{e}.base.reference(:)=999;end
[xx,yy]=e3cBatch(D,ids,"GRU");verifyEqual(t,extractdata(x),extractdata(xx));verifyNotEqual(t,y,yy);
end
function testAllSampleEpisodeBoundaries(t)
D=data(t);for i=1:height(D.samples)
 s=D.samples(i,:);[x,ix]=e3cContext(D.sequences{s.episode}.state,s.step,8);
 verifyEqual(t,size(x,2),s.length);verifyTrue(t,all(ix>=1 & ix<=s.step));
end
end
function testIdenticalTrainPlansNoValidation(t)
D=data(t);for seed=t.TestData.cfg.seeds
 a=load(model(t,"FF",seed),"plans","net","initial");b=load(model(t,"GRU",seed),"plans","net","initial");verifyEqual(t,a.plans,b.plans);verifyEqual(t,numel(a.plans),40);
 verifyNotEqual(t,a.net.Learnables.Value,a.initial.Learnables.Value);verifyNotEqual(t,b.net.Learnables.Value,b.initial.Learnables.Value);
 for epoch=1:40,ids=vertcat(a.plans{epoch}{:});verifyEqual(t,sort(ids),find(D.samples.split=="TRAIN"));end
end
end
function testCausalGRUWindowReproducesClosedLoop(t)
for seed=t.TestData.cfg.seeds
 a=load(model(t,"GRU",seed),"net");d=load(fullfile(fileparts(fileparts(model(t,"GRU",seed))),"closed_loop.mat"));
 for e=[1,140,200]
  r=d.runtimeTraces{e};for k=1:size(r.pwm,1)
   x=e3cContext(r.state',k,8);p=e3cPredict(a.net,"GRU",x);verifyEqual(t,p,r.probabilities(:,:,k));
  end
 end
end
end
function testClosedLoopDeterministicAllSixModels(t)
D=data(t);for seed=t.TestData.cfg.seeds
 for kind=["FF","GRU"]
  file=model(t,kind,seed);a=load(file,"saved_actor");d=load(fullfile(fileparts(fileparts(file)),"closed_loop.mat"));
  for e=[1,200]
   reset(a.saved_actor);[trace,r]=e3axRollout(a.saved_actor,D.episodes{e});original=d.runtimeTraces{e};
   for field=["q","state","rawAction","effectiveAction","pwm"],verifyEqual(t,r.(field),original.(field));end
   verifyEqual(t,trace.reward,d.traces{e}.reward);verifyEqual(t,r.state(2:end,49:52),r.effectiveAction);
  end
 end
end
end
function testTeacherCounterfactualDoesNotChangeAction(t)
D=data(t);a=load(model(t,"GRU",t.TestData.cfg.seeds(1)),"saved_actor");ep=D.episodes{200};reset(a.saved_actor);[trace,r]=e3axRollout(a.saved_actor,ep);
ep.base.reference=1-ep.base.reference;ep.base.referenceBefore=1-ep.base.referenceBefore;reset(a.saved_actor);[other,ro]=e3axRollout(a.saved_actor,ep);
verifyEqual(t,r.q,ro.q);verifyEqual(t,r.state,ro.state);verifyEqual(t,r.pwm,ro.pwm);verifyNotEqual(t,trace.reward,other.reward);
end
function testImitationMetricsReconstructed(t)
D=data(t);for kind=["FF","GRU"]
 folder=fileparts(fileparts(model(t,kind,t.TestData.cfg.seeds(1))));a=load(fullfile(folder,"imitation.mat"),"P","Y");
 [M,~]=e3cImitationMetrics(a.P,a.Y,D.samples);stored=readtable(fullfile(folder,"imitation_metrics.csv"),TextType="string",Delimiter=",");
 for field=["macroF1","NLL","accuracy","jointExact","jointNLL","top2"],verifyEqual(t,M.(field),stored.(field),AbsTol=1e-12);end
end
end
function testSecondaryPhaseClassifierSeparate(t)
folder=fileparts(fileparts(model(t,"GRU",t.TestData.cfg.seeds(1))));a=load(fullfile(folder,"imitation.mat"),"phaseNet","H");
verifyEqual(t,size(a.H,1),64);verifyEqual(t,numel(a.phaseNet.Layers),2);verifyEqual(t,a.phaseNet.Layers(end).OutputSize,6);
end
function testCompactFiguresComplete(t)
for seed=t.TestData.cfg.seeds
 for kind=["FF","GRU"]
  folder=fileparts(fileparts(model(t,kind,seed)));verifyEqual(t,numel(dir(fullfile(folder,"figures","TRAIN","*.png"))),140);verifyEqual(t,numel(dir(fullfile(folder,"figures","VALIDATION","*.png"))),60);
  verifyEqual(t,numel(dir(fullfile(folder,"figures","**","*.fig"))),200);
 end
end
end
function testCompactFourMotorsNoActionLabels(t)
folder=fileparts(fileparts(model(t,"GRU",t.TestData.cfg.seeds(1))));files=dir(fullfile(folder,"figures","VALIDATION","*.fig"));f=openfig(fullfile(files(1).folder,files(1).name),"invisible");c=onCleanup(@() close(f)); %#ok<NASGU>
verifyEqual(t,numel(findall(f,Type="axes")),4);verifyEqual(t,numel(findall(f,Tag="reference")),4);verifyEqual(t,numel(findall(f,Tag="prediction")),4);verifyEmpty(t,findall(f,Tag="effectiveActionLabel"));
end
function testAnnotatedTwoPoliciesAndEffectiveLabels(t)
files=dir(fullfile(t.TestData.cfg.output,"annotated","**","*.fig"));verifyEqual(t,numel(files),12);
f=openfig(fullfile(files(1).folder,files(1).name),"invisible");c=onCleanup(@() close(f)); %#ok<NASGU>
verifyEqual(t,numel(findall(f,Type="axes")),8);verifyEqual(t,numel(findall(f,Tag="reference")),8);verifyEqual(t,numel(findall(f,Tag="prediction")),8);
stem=erase(string(files(1).name),".fig");d=load(fullfile(files(1).folder,stem+".mat"),"T");verifyEqual(t,numel(findall(f,Tag="effectiveActionLabel")),height(d.T));
end
function testAnnotatedCsvMatConsistency(t)
files=dir(fullfile(t.TestData.cfg.output,"annotated","**","*.mat"));verifyEqual(t,numel(files),12);
for file=files'
 d=load(fullfile(file.folder,file.name),"T");R=readtable(fullfile(file.folder,replace(file.name,'.mat','.csv')),TextType="string",Delimiter=",");
 verifyEqual(t,d.T.policy,R.policy);for field=["step","motor","teacher","h_q","category","PWM","effectiveAction","selectedProbability","headEntropy","q","delta_q"],verifyEqual(t,d.T.(field),R.(field),AbsTol=1e-9);end
 verifyEqual(t,R.effectiveAction,R.PWM/255,AbsTol=1e-12);verifyTrue(t,all(R.selectedProbability>=0 & R.selectedProbability<=1));
end
end
function testViewerTracesAllThreePolicies(t)
files=dir(fullfile(t.TestData.cfg.output,"viewer","**","viewer_trace.mat"));verifyEqual(t,numel(files),18);
for file=files'
 v=load(fullfile(file.folder,file.name));verifyEqual(t,v.time,v.step*.2);verifyEqual(t,size(v.q,1),size(v.PWM,1)+1);verifyEqual(t,v.state(2:end,49:52),v.PWM/255);
 verifyEqual(t,v.checkpointSHA256,cap192SHA256(v.checkpoint));verifyFalse(t,v.teacherLoaded || v.trainingExecuted);verifyEqual(t,string(v.plantManifest.simPlantSource),"patternCurveCanonical");
end
end
function testDiagnosticSelectionFrozen(t)
T=readtable(fullfile(t.TestData.cfg.output,"diagnostic_selection.csv"),TextType="string",Delimiter=",");verifyEqual(t,height(T),6);verifyEqual(t,sort(unique(T.subject)),["JOE";"JONATHAN";"KHAROL"]);
verifyEqual(t,T.row',[1 111 220 220 234 178]);verifyEqual(t,T.side',[2 2 1 2 2 2]);
end
function testHistoricalIntegrity(t)
H=readtable(fullfile(t.TestData.cfg.output,"historical_hashes_before.csv"),TextType="string",Delimiter=",");
for k=1:height(H)
 if string(H.path(k))==fullfile(t.TestData.cfg.root,"exportE3AXViewerTrace.m"),continue;end
 verifyEqual(t,cap192SHA256(H.path(k)),H.sha256(k));
end
end
function D=data(t),a=load(fullfile(t.TestData.cfg.output,"supervised_data.mat"),"D");D=a.D;end
function file=model(t,kind,seed),file=fullfile(t.TestData.cfg.output,kind+"_"+seed,"checkpoints","ProbeEpoch040.mat");end
