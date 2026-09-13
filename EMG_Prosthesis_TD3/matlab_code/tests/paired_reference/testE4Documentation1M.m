function tests = testE4Documentation1M
tests = functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
old=path; t.addTeardown(@() path(old)); oldRng=rng; t.addTeardown(@() rng(oldRng));
addpath(root,fullfile(root,"analysis","paired_reference"),fullfile(root,"config"));
for s=["e4","e3b","e3ax","cap192"],addpath(fullfile(root,"analysis","paired_reference",s));end
t.TestData.root=root; t.TestData.cfg=e4DocumentationConfig();
end
function testExactRecipe(t)
c=t.TestData.cfg; h=e4Config("long");
exclude=["seed","scientificSeed","smokeSeed","maxAgentSteps","checkpointSteps","finalAgentStep","outputParent"];
for f=string(fieldnames(h))'
 if ~ismember(f,exclude),verifyEqual(t,c.(f),h.(f),char(f));end
end
end
function testActualNetworksIdentical(t)
c=t.TestData.cfg; rng(10); [a,v]=e3bNetworks(c);rng(10);[b,w]=e3bNetworks(e4Config("long"));
verifyEqual(t,a.Learnables,b.Learnables);verifyEqual(t,v.Learnables,w.Learnables);
x=dlarray(single(reshape(1:104,52,2)/104),"CB");
verifyEqual(t,extractdata(e3bLogits(a,x)),extractdata(e3bLogits(b,x)));
verifyEqual(t,size(e3bLogits(a,x)),[15 4 2]);
end
function testDevelopmentExact(t)
c=t.TestData.cfg;
verifyEqual(t,c.trainSubjects,["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA","JOE","JONATHAN","KHAROL"]);
verifyEmpty(t,c.validationSubjects);verifyFalse(t,any(ismember(c.trainSubjects,["MATEO","SANDRA"])));
end
function testBudgetSeedCheckpoints(t)
c=t.TestData.cfg;verifyEqual(t,c.seed,20261001);verifyEqual(t,c.maxAgentSteps,1000000);
verifyEqual(t,c.checkpointSteps,[250000 500000 750000 1000000]);verifyEqual(t,c.checkpointSelection,"NONE");
verifyFalse(t,isfield(c,"finalAgentStep"));
end
function testPreflightRejectsAnyDrift(t)
c=t.TestData.cfg;verifyTrue(t,e4DocumentationPreflight(c).configurationValidated);
for field=["seed","maxAgentSteps","actorLR"]
 bad=c;bad.(field)=bad.(field)+1;verifyError(t,@() e4DocumentationPreflight(bad),"E4Doc:ConfigChanged");
end
bad=c;bad.trainSubjects(1)="MATEO";verifyError(t,@() e4DocumentationPreflight(bad),"E4Doc:ConfigChanged");
bad=c;bad.outputParent=fullfile(c.root,"results","e4_final_development");verifyError(t,@() e4DocumentationPreflight(bad),"E4Doc:ConfigChanged");
end
function testLoaderRejectsSealedBeforeRead(t)
c=t.TestData.cfg;c.trainSubjects(1)="SANDRA";
verifyError(t,@() e4LoadData(c),"E4:LoadData:SealedViolation");
end
function testCheckpointDoesNotChangeUpdate(t)
c=t.TestData.cfg;
for step=[249999 250000 250001 500000 750000 999999 1000000]
 for count=[1 144 1024]
  h=e4Schedule(c,step,10,false,count);s=e4DocumentationSchedule(c,step,10,false,count);
  verifyEqual(t,s.update,h.update);verifyEqual(t,s.stop,h.stop);
  verifyEqual(t,s.checkpoint,ismember(step,c.checkpointSteps));
 end
end
s=e4DocumentationSchedule(c,250000,10,false,144);verifyFalse(t,s.update);verifyTrue(t,s.checkpoint);
s=e4DocumentationSchedule(c,1000000,10,false,576);verifyTrue(t,s.stop);verifyTrue(t,s.update);
end
function testLegalActionContract(t)
c=t.TestData.cfg;verifyEqual(t,c.categories,[0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255]);
[a,~]=e3bNetworks(c);[category,lp,entropy]=e3bSample(a,zeros(52,1));
verifySize(t,category,[4 1]);verifyTrue(t,all(ismember(category,1:15)));
verifyTrue(t,isfinite(lp));verifyTrue(t,all(isfinite(entropy)));
end
function testDocumentaryRole(t)
c=t.TestData.cfg;verifyTrue(t,c.documentationOnly);verifyFalse(t,c.scientificFinalModel);
verifyFalse(t,c.mateoSandraAllowed);verifyEqual(t,c.sealedTestReuse,"FORBIDDEN");
verifyFalse(t,c.fullTrainingResumeAvailable);verifyFalse(t,c.referenceContractValidated);
verifyTrue(t,endsWith(c.outputParent,fullfile("results","e4_documentation_1m")));
end
function testHistoricalRunnerAndMDPIntact(t)
root=t.TestData.root;
verifyEqual(t,cap192SHA256(fullfile(root,"runE4FinalDevelopmentTraining.m")),"644578f52403816e151170778e2361e70d5983e26f9ca844d87a102ae28c4833");
% Codigo nuevo llama a las mismas implementaciones; no contiene un reward paralelo.
s=string(fileread(fullfile(root,"runE4Documentation1M.m")));
verifyTrue(t,contains(s,"E3BTrainingEnv(data.emgs, data.gloves)"));
verifyTrue(t,contains(s,"e3bUpdate(actor, critic, opt, buffer, cfg)"));
verifyFalse(t,contains(s,"runFinalSealedTest("));verifyFalse(t,contains(s,"runE4FinalDevelopmentTraining("));
verifyFalse(t,contains(s,'"FINAL_AGENT.mat"'));verifyFalse(t,contains(s,"copyfile("));
verifyFalse(t,contains(s,"e4_final_development"));
end
function testFrozenModelHashFromPersistedSummary(t)
root=t.TestData.root;
f=fullfile(root,"results","final_sealed_test","run_20260911_212959_985_f79338ed","FINAL_SEALED_TEST_SUMMARY.json");
d=jsondecode(fileread(f));verifyEqual(t,string(d.finalAgentSHA256),t.TestData.cfg.scientificFinalAgentSHA256);
% No se carga el agente ni datos raw sellados.
end
function testPrerecordedDocumentation(t)
f=fullfile(fileparts(fileparts(t.TestData.root)),"docs","paired_reference","E4_DOCUMENTATION_1M.md");
s=string(fileread(f));
for k=["DOCUMENTATION_ONLY = YES","SCIENTIFIC_FINAL_MODEL = NO","SEALED_TEST_REUSE = FORBIDDEN","MATEO_SANDRA_ALLOWED = NO","20261001"]
 verifyTrue(t,contains(s,k));
end
end
