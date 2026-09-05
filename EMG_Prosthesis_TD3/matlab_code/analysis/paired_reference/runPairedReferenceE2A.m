function summary = runPairedReferenceE2A(options)
% Auditoria causal: teacher real, ausencia de teacher y teacher contrafactual.
% No ejecuta aprendizaje ni compara calidad de control con otros resultados.
arguments
    options.outputDir (1,1) string = ""
end
here = string(fileparts(mfilename("fullpath")));
matlabRoot = fileparts(fileparts(here));
if options.outputDir == "", options.outputDir = fullfile(here, "e2a_results"); end
if ~isfolder(options.outputDir), mkdir(options.outputDir); end
oldOverride = struct();
if isappdata(0, "configurables_override"), oldOverride = getappdata(0, "configurables_override"); end
oldRng = rng;
cleanup = onCleanup(@() restoreContext(oldOverride, oldRng));
override = struct("run_training", false, "flagSaveTraining", false, ...
    "plotEpisodeOnTest", false, "verbose", false, "usePrerecorded", true, ...
    "simMotors", true, "observationVariant", "markov52", ...
    "simPlantSource", "patternCurveCanonical", "actionInterfaceVariant", "baselineQuantized");
setConfigurablesOverride(override);
% Env tiene constantes; si ya se cargo con otra configuracion, abortar.
assert(~Env.flagSaveTraining && ~Env.plotEpisodeOnTest && Env.simMotors, ...
    "E2A:StaleEnvClass", "Ejecutar E2A en MATLAB nuevo, sin Env previo con otras constantes.");
[actor, policyManifest] = loadE2AFrozenActor();
beforeParameters = getLearnableParameters(actor);
writeJson(fullfile(options.outputDir, "policy_manifest.json"), policyManifest);
pairedReferencePlantManifest(plantSource="patternCurveCanonical", ...
    outputPath=fullfile(options.outputDir, "plant_manifest.json"));
subjects = ["BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", ...
    "GABRIEL", "IVANNA", "JOE", "JONATHAN", "KHAROL"];
seed = 20260905;
rows = cell(20,1); trajectories = cell(20,1); provenance = cell(20,1);
levelRows = cell(60,1); allBProfile = strings(0,1);
index = 0;
for subject = subjects
    emgs = cell(1,2); teachers = cell(1,2); sources = cell(1,2);
    for side = 1:2
        [emgs{side}, teachers{side}, sources{side}] = ...
            loadE2ADevelopmentEpisode(subject, 1, side, includeTeacher=true);
    end
    counterfactual = cellfun(@(g) g(end:-1:1), teachers, UniformOutput=false);
    for side = 1:2
        index = index+1;
        a = teacherEpisode(actor, emgs, teachers, side, seed);
        c = teacherEpisode(actor, emgs, counterfactual, side, seed);
        % Instrumentar TODA la ruta B, incluida su carga EMG selectiva.
        profile clear; profile on;
        profileCleanup = onCleanup(@() profile("off"));
        [bEmg, unusedTeacher, bSource] = loadE2ADevelopmentEpisode(subject, 1, side);
        assert(isempty(unusedTeacher) && isequal(bEmg, emgs{side}));
        b = absentEpisode(actor, bEmg, a.q(1,:), seed);
        profile off;
        info = profile("info");
        allBProfile = [allBProfile; string({info.FunctionTable.FunctionName})']; %#ok<AGROW>
        clear profileCleanup;
        ab = compareEpisodes(a,b); ac = compareEpisodes(a,c);
        rewardDifference = max(abs(a.reward - c.reward));
        rows{index} = struct("subject", subject, "repetition", 1, "side", side, ...
            "teacherSteps", size(a.rawAction,1), "gloveFreeSteps", size(b.rawAction,1), ...
            "commonHorizon", ab.commonHorizon, "counterfactualSteps", size(c.rawAction,1), ...
            "maxStateDiff", ab.state, "maxRawActionDiff", ab.rawAction, ...
            "maxEffectiveActionDiff", ab.effectiveAction, "maxPwmDiff", ab.pwm, "maxQDiff", ab.q, ...
            "abExact", ab.exact, "counterfactualExact", ac.exact, ...
            "counterfactualMaxStateDiff", ac.state, "counterfactualMaxActionDiff", ac.rawAction, ...
            "counterfactualMaxQDiff", ac.q, "counterfactualRewardMaxDifference", rewardDifference, ...
            "teacherEmgExhausted", a.emgExhausted, "teacherGloveExhausted", a.gloveExhausted, ...
            "absentEmgExhausted", b.emgExhausted);
        trajectories{index} = struct("subject", subject, "side", side, "A", a, "B", b, "C", c);
        provenance{index} = struct("teacher", sources{side}, "absent", bSource);
        routes = {a,b,c}; names = ["A", "B", "C"];
        for route = 1:3
            levelRows{3*(index-1)+route} = actionLevels(routes{route}, subject, side, names(route));
        end
        fprintf("  %s lado %d: A=%d B=%d comun=%d; igualdad=%d; reward contrafactual cambia=%d\n", ...
            subject, side, rows{index}.teacherSteps, rows{index}.gloveFreeSteps, ab.commonHorizon, ...
            ab.exact && ac.exact, rewardDifference>0);
    end
end
comparison = struct2table(vertcat(rows{:}));
levels = vertcat(levelRows{:});
writetable(comparison, fullfile(options.outputDir, "causal_comparisons.csv"));
writetable(levels, fullfile(options.outputDir, "pwm_distribution.csv"));
save(fullfile(options.outputDir, "causal_trajectories.mat"), "trajectories", "provenance", "seed");
writeJson(fullfile(options.outputDir, "episode_provenance.json"), provenance);
writeJson(fullfile(options.outputDir, "absent_call_profile.json"), unique(allBProfile));
exportTrajectoryCsv(trajectories, options.outputDir);

% Fixture corta: mismo EMG, teacher real truncado en memoria, sin tocar archivos.
[shortEmg, shortTeacher] = loadE2ADevelopmentEpisode("BLANCA",1,1,includeTeacher=true);
shortTeacher = shortTeacher(1:min(6,numel(shortTeacher)));
shortA = teacherEpisode(actor, {shortEmg,shortEmg}, {shortTeacher,shortTeacher}, 1, seed);
shortB = absentEpisode(actor, shortEmg, shortA.q(1,:), seed);
shortComparison = compareEpisodes(shortA,shortB);
shortFixture = struct("teacherSteps", size(shortA.rawAction,1), ...
    "gloveFreeSteps", size(shortB.rawAction,1), "commonHorizon", shortComparison.commonHorizon, ...
    "exact", shortComparison.exact, "teacherEmgExhausted", shortA.emgExhausted, ...
    "teacherGloveExhausted", shortA.gloveExhausted, "absentEmgExhausted", shortB.emgExhausted);
writeJson(fullfile(options.outputDir,"short_teacher_fixture.json"), shortFixture);
assert(isequaln(getLearnableParameters(actor),beforeParameters), ...
    "E2A:PolicyModified", "El actor cambio durante la auditoria.");

testsDir = fullfile(matlabRoot,"tests","paired_reference");
testNames = ["testPairedReferenceGloveFreeExecution.m", "testPairedReferencePlantCanonicalSource.m", ...
    "testPairedReferencePlantHoldOutsideCurve.m", "testPairedReferenceStage0PlantSanity.m"];
testResults = runtests(fullfile(testsDir,testNames));
testTable = table(testResults);
writetable(testTable(:,["Name","Passed","Failed","Incomplete","Duration"]), ...
    fullfile(options.outputDir,"test_results.csv"));
forbiddenCalls = contains(allBProfile,"RecordedGlove") | contains(allBProfile,"FakeGlove") | ...
    startsWith(allBProfile,"Glove.") | startsWith(allBProfile,"Glove>") | ...
    contains(allBProfile,"getDataset");
summary = struct("START_SHA","c08b784bf4759c70a9bc2d10f0b44f638a61526a", ...
    "episodes",height(comparison), "seed",seed, "simPlantSource","patternCurveCanonical", ...
    "GLOVE_IN_OBSERVATION",false, "GLOVE_IN_ACTOR_INPUT",false, ...
    "GLOVE_IN_PLANT_TRANSITION",false, "GLOVE_IN_REWARD",true, ...
    "GLOVE_IN_HISTORICAL_TERMINATION",true, ...
    "GLOVE_FREE_RUNTIME_CONSTRUCTS_GLOVE",any(forbiddenCalls), "GLOVE_FREE_TERMINATION","EMG_ONLY", ...
    "MAX_STATE_DIFF_COMMON_HORIZON",max(comparison.maxStateDiff), ...
    "MAX_RAW_ACTION_DIFF_COMMON_HORIZON",max(comparison.maxRawActionDiff), ...
    "MAX_EFFECTIVE_ACTION_DIFF_COMMON_HORIZON",max(comparison.maxEffectiveActionDiff), ...
    "MAX_PWM_DIFF_COMMON_HORIZON",max(comparison.maxPwmDiff), ...
    "MAX_Q_DIFF_COMMON_HORIZON",max(comparison.maxQDiff), ...
    "COUNTERFACTUAL_GLOVE_REWARD_CHANGED",any(comparison.counterfactualRewardMaxDifference>0), ...
    "COUNTERFACTUAL_GLOVE_ACTION_CHANGED",any(~comparison.counterfactualExact), ...
    "counterfactualRewardChangedEpisodes",nnz(comparison.counterfactualRewardMaxDifference>0), ...
    "teacherStepsTotal",sum(comparison.teacherSteps),"gloveFreeStepsTotal",sum(comparison.gloveFreeSteps), ...
    "commonHorizonTotal",sum(comparison.commonHorizon), ...
    "absentPwmHighFraction",mean(abs(allPwm(trajectories,"B"))>=128), ...
    "actorParametersUnchanged",true,"shortTeacherFixture",shortFixture, ...
    "tests",numel(testResults),"testsPassed",nnz([testResults.Passed]), ...
    "E2A_RESULT","FAIL","E2B_AUTHORIZED",false,"RL_AUTHORIZED",false);
e0pTests = ~contains(string({testResults.Name}),"GloveFreeExecution");
summary.E0P_REGRESSION_TESTS_STILL_PASS = all([testResults(e0pTests).Passed]);
passed = all(comparison.abExact) && all(comparison.counterfactualExact) && ...
    summary.COUNTERFACTUAL_GLOVE_REWARD_CHANGED && ~any(forbiddenCalls) && ...
    all(comparison.absentEmgExhausted) && shortFixture.exact && ...
    shortFixture.teacherSteps < shortFixture.gloveFreeSteps && ...
    ~shortFixture.teacherEmgExhausted && shortFixture.teacherGloveExhausted && ...
    all([testResults.Passed]);
if passed, summary.E2A_RESULT="PASS"; end
writeJson(fullfile(options.outputDir,"e2a_summary.json"),summary);
disp(summary);
assert(passed,"E2A:GateFailed","E2A_RESULT=FAIL; revisar artefactos.");
end

function trace = teacherEpisode(actor, emgs, teachers, side, seed)
rng(seed,"twister");
env = Env("",true,emgs,teachers);
for i=1:side, state=reset(env); end
trace = emptyTrace(state,env.motorData(end,:));
trace.reward = zeros(0,1);
done = false;
while ~done
    raw = action(actor,state);
    [state,reward,done] = step(env,raw);
    trace = append(trace,state,raw,env.actionSatLog(env.c,:)', ...
        env.actionPwmLog(env.c,:)',env.motorData(end,:));
    trace.reward(end+1,1)=reward;
    assert(env.c<100,"E2A:Horizon","Horizonte inesperado; detener auditoria.");
end
trace.emgExhausted=env.myo.exhausted;
trace.gloveExhausted=env.glove.exhausted;
end

function trace = absentEpisode(actor, emg, initial, seed)
rng(seed,"twister");
runtime = GloveFreePolicyRuntime(emg,initial,purpose="causalEvaluation");
state = runtime.state;
trace = emptyTrace(state,runtime.q);
while ~runtime.exhausted
    raw = action(actor,state);
    [state,~,record] = runtime.advance(raw);
    trace = append(trace,state,raw,record.effectiveAction,record.pwm,record.q);
    assert(runtime.c<100,"E2A:Horizon","Horizonte inesperado; detener auditoria.");
end
trace.emgExhausted = runtime.exhausted;
end

function value = action(actor,state)
value = getAction(actor,{state});
if iscell(value), value=cell2mat(value); end
value=double(value(:));
end

function trace = emptyTrace(state,q)
trace=struct("state",state',"q",q,"rawAction",zeros(0,4), ...
    "effectiveAction",zeros(0,4),"pwm",zeros(0,4));
end

function trace = append(trace,state,raw,effective,pwm,q)
trace.state(end+1,:)=state'; trace.q(end+1,:)=q;
trace.rawAction(end+1,:)=raw'; trace.effectiveAction(end+1,:)=effective'; trace.pwm(end+1,:)=pwm';
end

function comparison = compareEpisodes(a,b)
n=min(size(a.rawAction,1),size(b.rawAction,1));
comparison=struct("commonHorizon",n,"exact",true);
for field=["state","q","rawAction","effectiveAction","pwm"]
    count=n+double(ismember(field,["state","q"]));
    x=a.(field)(1:count,:); y=b.(field)(1:count,:);
    comparison.(field)=max(abs(x-y),[],"all");
    comparison.exact=comparison.exact && isequal(x,y);
end
end

function tableRows = actionLevels(trace,subject,side,route)
pwm=trace.pwm(:); levels=[0 64 96 128 160 192 224 255]';
counts=arrayfun(@(level) nnz(abs(pwm)==level),levels);
tableRows=table(repmat(subject,8,1),repmat(side,8,1),repmat(route,8,1),levels,counts, ...
    counts/numel(pwm),repmat(mean(abs(pwm)>=128),8,1), ...
    VariableNames=["subject","side","route","pwm_magnitude","count","fraction","highPwmFraction"]);
end

function values = allPwm(traces,route)
values=cellfun(@(t) reshape(t.(route).pwm,[],1),traces,UniformOutput=false);
values=vertcat(values{:});
end

function exportTrajectoryCsv(traces,outputDir)
rows=cell(60,1); index=0;
for episode=1:numel(traces)
    for route=["A","B","C"]
        index=index+1; t=traces{episode}.(route); n=size(t.rawAction,1);
        metadata=table(repmat(traces{episode}.subject,n,1),repmat(traces{episode}.side,n,1), ...
            repmat(route,n,1),(1:n)',VariableNames=["subject","side","route","step"]);
        values=[t.state(1:n,:) t.state(2:n+1,:) t.rawAction t.effectiveAction t.pwm t.q(2:n+1,:)];
        names=["state_"+(1:52),"nextState_"+(1:52),"raw_"+(1:4), ...
            "effective_"+(1:4),"pwm_"+(1:4),"q_"+(1:4)];
        rows{index}=[metadata,array2table(values,VariableNames=names)];
    end
end
writetable(vertcat(rows{:}),fullfile(outputDir,"execution_traces.csv"));
end

function writeJson(path,value)
fid=fopen(path,"w","n","UTF-8"); assert(fid>=0,"No se pudo escribir el resultado E2A.");
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end

function restoreContext(override,rngState)
setConfigurablesOverride(override); rng(rngState);
end
