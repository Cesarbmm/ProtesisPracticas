function tests=testE3AXPostTraining
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));t.TestData.root=root;
old=path;t.addTeardown(@() path(old));addpath(root);addpath(fullfile(root,"analysis","paired_reference"));addpath(fullfile(root,"analysis","paired_reference","e3ax"));
pointer=fullfile(root,"analysis","paired_reference","e3ax_preparation","smoke_path.txt");
t.TestData.source=erase(strtrim(string(fileread(pointer))),char(65279));
end
function setup(t)
f=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);t.TestData.out=string(f.Folder);
copyfile(fullfile(t.TestData.source,"evaluation"),fullfile(t.TestData.out,"evaluation"));
for file=["config.mat","checkpoint_validation.csv","evaluation_selection.csv","training_progress.png"]
    copyfile(fullfile(t.TestData.source,file),fullfile(t.TestData.out,file));
end
end
function testCompleteReportLinksEveryEpisode(t)
r=e3axPublishBehavioralTest(t.TestData.out);verifyEqual(t,r.pngCount,8);verifyEqual(t,r.figCount,8);
verifyEqual(t,r.trainEpisodesPerCheckpoint,2);verifyEqual(t,r.validationEpisodesPerCheckpoint,2);
verifyFalse(t,r.finalTestExecuted || r.trainingExecuted || r.referenceContractValidated);
html=string(fileread(r.html));verifyEqual(t,count(html,"data-subject="),8);
verifyTrue(t,contains(html,"MATEO/SANDRA sellado"));verifyTrue(t,contains(html,"VALIDATION"));
I=readtable(fullfile(t.TestData.out,"evaluation","episode_figure_index.csv"),TextType="string",Delimiter=",");
for k=1:height(I),verifyTrue(t,contains(html,I.png(k)));verifyTrue(t,contains(html,I.fig(k)));end
end
function testMissingFigurePreventsCompleteReport(t)
p=firstPng(t);delete(p);
verifyError(t,@() e3axPublishBehavioralTest(t.TestData.out),"E3AX:FigureCount");
verifyFalse(t,isfile(fullfile(t.TestData.out,"TEST_COMPORTAMENTAL.json")));
end
function testCorruptFigurePreventsCompleteReport(t)
p=firstPng(t);f=fopen(p,'w');fprintf(f,'Esto no es PNG');fclose(f);
failed=false;try,e3axPublishBehavioralTest(t.TestData.out);catch,failed=true;end
verifyTrue(t,failed);verifyFalse(t,isfile(fullfile(t.TestData.out,"TEST_COMPORTAMENTAL.json")));
end
function testRecoveryRepairsOnlyMissingEpisode(t)
files=dir(fullfile(t.TestData.out,"evaluation","**","*.png"));other=string(fullfile(files(end).folder,files(end).name));h=e2cSHA256(other);
p=firstPng(t);delete(p);verifyEqual(t,e3axRepairEpisodeFigures(t.TestData.out),1);
verifyTrue(t,isfile(p));verifyEqual(t,e2cSHA256(other),h);verifyEqual(t,height(e3axCheckEvaluationFiles(t.TestData.out)),8);
end
function testMissingMetricsEpisodeFailsCoverage(t)
file=fullfile(t.TestData.out,"evaluation","best_checkpoint","metrics","episode_metrics.csv");
E=readtable(file,Delimiter=",");E(1,:)=[];writetable(E,file);
verifyError(t,@() e3axCheckEvaluationFiles(t.TestData.out),"E3AX:EvaluationIncomplete");
end
function testWrongBestSelectionFailsReport(t)
file=fullfile(t.TestData.out,"evaluation","final_summary.json");F=jsondecode(fileread(file));F.bestEpisode=999;e2cWriteJSON(file,F);
verifyError(t,@() e3axPublishBehavioralTest(t.TestData.out),"E3AX:CheckpointSelection");
end
function testPostTrainingReusesSavedEvaluationWithoutTraining(t)
file=fullfile(t.TestData.out,"checkpoint_validation.csv");before=e2cSHA256(file);
r=runE3AXPostTraining(t.TestData.out);verifyEqual(t,r.status,"COMPLETE");verifyFalse(t,r.trainingExecuted);
verifyEqual(t,r.repairedEpisodes,0);verifyEqual(t,e2cSHA256(file),before);
verifyFalse(t,isfolder(fullfile(t.TestData.out,"checkpoints")));
status=jsondecode(fileread(fullfile(t.TestData.out,"POST_TRAINING_STATUS.json")));verifyEqual(t,string(status.status),"COMPLETE");
end
function testRunnerDeclaresEvaluationBeforeCompletion(t)
code=string(fileread(fullfile(t.TestData.root,"runE3AXLongTraining.m")));
verifyTrue(t,contains(code,"POST_TRAINING_STATUS.json"));verifyTrue(t,contains(code,"runE3AXPostTraining"));
verifyLessThan(t,strfind(code,"evaluation=e3axFinalEvaluation(session)"),strfind(code,'fullfile(out,"COMPLETED.txt")'));
final=string(fileread(fullfile(t.TestData.root,"analysis","paired_reference","e3ax","e3axFinalEvaluation.m")));
verifyTrue(t,contains(final,"result.behavioralTest=e3axPublishBehavioralTest(out)"));
recovery=string(fileread(fullfile(t.TestData.root,"runE3AXPostTraining.m")));
verifyFalse(t,contains(recovery,"train("));verifyFalse(t,contains(recovery,"agentTd3("));
end
function p=firstPng(t)
d=dir(fullfile(t.TestData.out,"evaluation","best_checkpoint","figures","**","*.png"));p=string(fullfile(d(1).folder,d(1).name));
end
