function tests=testE3AXEvaluationArtifacts
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));oldPath=path;t.addTeardown(@() path(oldPath));
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(fullfile(root,"analysis","paired_reference"));addpath(fullfile(root,"analysis","paired_reference","e3ax"));
old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
t.addTeardown(@() setConfigurablesOverride(old));oldRng=rng;t.addTeardown(@() rng(oldRng));
clearConfigurablesOverride();o=e3axOverride(e3axConfig("smoke"));o.run_training=false;setConfigurablesOverride(o);
pointer=fullfile(root,"analysis","paired_reference","e3ax_preparation","smoke_path.txt");
out=erase(strtrim(string(fileread(pointer))),char(65279));
t.TestData.out=out;t.TestData.root=root;
end
function testSavedStatesReproduceActionsDeterministically(t)
for which=["best_checkpoint","last_checkpoint"]
    folder=fullfile(t.TestData.out,"evaluation",which);s=jsondecode(fileread(fullfile(folder,"summary.json")));
    a=load(s.checkpoint,"saved_actor");d=load(fullfile(folder,"metrics","trajectories.mat"),"runtimeTraces");
    before=getLearnableParameters(a.saved_actor);
    for e=1:numel(d.runtimeTraces)
        r=d.runtimeTraces{e};verifyEqual(t,size(r.state,2),52);verifyEqual(t,size(r.state,1),size(r.pwm,1)+1);
        for k=1:size(r.pwm,1)
            x=getAction(a.saved_actor,{r.state(k,:)'});y=getAction(a.saved_actor,{r.state(k,:)'});
            verifyEqual(t,x,y);if iscell(x),x=cell2mat(x);end
            verifyEqual(t,double(x(:)'),r.rawAction(k,:));
        end
    end
    verifyEqual(t,getLearnableParameters(a.saved_actor),before);
end
end
function testRewardReferenceAndRuntimeHorizonRemainHistorical(t)
source=load(fullfile(t.TestData.root,"analysis","paired_reference","e2f_results","trajectories.mat"),"trajectories");
for which=["best_checkpoint","last_checkpoint"]
    d=load(fullfile(t.TestData.out,"evaluation",which,"metrics","trajectories.mat"));
    for e=1:numel(d.traces)
        x=d.traces{e};r=d.runtimeTraces{e};n=size(x.reference,1);
        found=cellfun(@(b) string(b.metadata.subject)==string(x.metadata.subject) && b.metadata.repetition==x.metadata.repetition && b.metadata.side==x.metadata.side,source.trajectories(:,2));
        assertEqual(t,nnz(found),1);b=source.trajectories{found,2};
        verifyEqual(t,x.reference,b.reference);verifyEqual(t,x.referenceBefore,b.referenceBefore);verifyEqual(t,x.q(1,:),b.q(1,:));
        verifyEqual(t,x.q,r.q(1:n+1,:));verifyEqual(t,x.rawAction,r.rawAction(1:n,:));
        verifyGreaterThanOrEqual(t,size(r.pwm,1),n);verifyEqual(t,r.termination,"EMG_ONLY");
        p=encoder2Flex(x.q(2:end,:))./[4092 2046 1023 2046];u=x.effectiveAction;du=[u(1,:);diff(u)];
        verifyEqual(t,x.prediction,p);verifyEqual(t,x.trackingTerm,-(p-x.reference).^2);
        verifyEqual(t,x.reward,mean(-(p-x.reference).^2-.01*u.^2-.05*du.^2,2),AbsTol=1e-14);
    end
end
end
function testAppliedPwmReconstructsCanonicalPlantAndPreviousActionState(t)
d=load(fullfile(t.TestData.out,"evaluation","last_checkpoint","metrics","trajectories.mat"),"runtimeTraces");
for e=1:numel(d.runtimeTraces)
    r=d.runtimeTraces{e};verifyTrue(t,all(ismember(abs(r.pwm),[0 64 96 128 160 192 224 255]),"all"));
    verifyEqual(t,r.effectiveAction,r.pwm/255);verifyEqual(t,r.state(2:end,49:52),r.effectiveAction);
    for k=1:size(r.pwm,1)
        q=SimController.prosthesis_simulator(r.q(k,:),r.pwm(k,:),.2,.14,plantSource="patternCurveCanonical");
        verifyEqual(t,q(end,:),r.q(k+1,:));
    end
end
end
function testHistoricalClosureHashesRemainIntact(t)
I=e3axVerifyHistory();verifyEqual(t,height(I),816);verifyTrue(t,all(I.unchanged));
end
