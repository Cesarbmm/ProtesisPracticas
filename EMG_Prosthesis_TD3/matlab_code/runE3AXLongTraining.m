function summary=runE3AXLongTraining(options)
% Único comando manual en MATLAB Desktop. La IA sólo ejecuta mode="smoke".
arguments,options.mode (1,1) string {mustBeMember(options.mode,["long","smoke"])}="long";end
root=string(fileparts(mfilename("fullpath")));here=fullfile(root,"analysis","paired_reference");
assert(usejava('desktop') && usejava('awt'),"E3AX:DesktopRequired","Abrir MATLAB Desktop; no usar -batch/-nodesktop/-noFigureWindows.");
assert(~contains(lower(string(path)),"sandbox"),"E3AX:ForbiddenPath");
oldPath=path;oldDir=pwd;oldRng=rng;oldOverride=struct();if isappdata(0,"configurables_override"),oldOverride=getappdata(0,"configurables_override");end
context=onCleanup(@() restore(oldPath,oldDir,oldRng,oldOverride)); %#ok<NASGU>
cd(root);addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(genpath(fullfile(root,"lib")));addpath(fullfile(root,"agents"));addpath(here);addpath(fullfile(here,"e3ax"));
cfg=e3axConfig(options.mode);clearConfigurablesOverride();o=e3axOverride(cfg);setConfigurablesOverride(o);p=configurables();
assert(~Env.flagSaveTraining && ~Env.plotEpisodeOnTest && Env.simMotors,"E3AX:StaleEnv","Usar MATLAB recién abierto: constantes Env incompatibles cargadas previamente.");
e3axAssertEnvContract(p);
assert(p.stateLength==52 && p.numEMGFeatures==40 && p.period==.2 && string(p.simPlantSource)=="patternCurveCanonical");
assert(p.td3.miniBatchSize==64 && p.td3.numHiddenUnits==64 && ~p.td3.useRecurrent && p.td3.sampleTime==.2 && ~p.td3Residual.enabled);
stamp=string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'));id=string(java.util.UUID.randomUUID());
out=fullfile(cfg.outputParent,"run_"+stamp+"_"+extractBefore(id,9));assert(~isfolder(out));mkdir(out);mkdir(fullfile(out,"checkpoints"));
diary(fullfile(out,"diary.log"));diaryCleanup=onCleanup(@() diary('off')); %#ok<NASGU>
fprintf("E3A-X %s · %d episodios. Referencia NO validada.\nSalida: %s\n",cfg.mode,cfg.maxEpisodes,out);
e2cWriteJSON(fullfile(out,"config.json"),cfg);configs=p;seed=cfg.seed;save(fullfile(out,"config.mat"),"cfg","configs","o","seed"); %#ok<NASGU>
split=struct("TRAIN",cfg.trainSubjects,"VALIDATION",cfg.validationSubjects,"SEALED",["MATEO","SANDRA"],"rule",cfg.splitRule);e2cWriteJSON(fullfile(out,"split.json"),split);
writematrix(seed,fullfile(out,"seed.txt"));writeText(fullfile(out,"STARTED.txt"),"Modo "+cfg.mode+"; "+stamp+"; entrenamiento exploratorio autorizado; sin hardware.");
manifest=pairedReferencePlantManifest(plantSource="patternCurveCanonical",outputPath=fullfile(out,"plant_manifest.json"));
manifest.protocolSHA256=e2cSHA256(fullfile(fileparts(root),"docs","paired_reference","PROTOCOLO_E3AX.md"));
manifest.splitSHA256=e2cSHA256(fullfile(out,"split.json"));manifest.referenceContractValidated=false;manifest.fullTrainingResumeAvailable=false;
e2cWriteJSON(fullfile(out,"manifest.json"),manifest);
try
    e3axVerifyHistory();
    data=e3axLoadData(cfg,out);rng(seed,'twister');
    [agent,~]=agentTd3(Env.defineObservationInfo(),Env.defineActionInfo());
    agent.AgentOptions.InfoToSave=struct("ExperienceBuffer",true,"Optimizer",true,"PolicyState",true,"Target",true);
    agent.AgentOptions.ResetExperienceBufferBeforeTraining=false;
    initialActor=getLearnableParameters(getActor(agent));critics=getCritic(agent);initialCritics=cell(1,2);
    for j=1:2,initialCritics{j}=getLearnableParameters(critics(j));end
    save(fullfile(out,"initial_parameters.mat"),"initialActor","initialCritics");
    agentOptions=agent.AgentOptions;save(fullfile(out,"agent_options.mat"),"agentOptions");
    env=Env("",true,data.emgs,data.gloves);session=E3AXSession(cfg,out,data);
    opts=rlTrainingOptions(MaxEpisodes=cfg.maxEpisodes,MaxStepsPerEpisode=cfg.maxSteps,StopTrainingCriteria="EpisodeCount",StopTrainingValue=cfg.maxEpisodes, ...
        Plots="training-progress",Verbose=true,UseParallel=false,SaveAgentCriteria="Custom",SaveAgentValue=@(info) session.logEpisode(info),SaveAgentDirectory=fullfile(out,"checkpoints"));
    evaluator=rlCustomEvaluator(@(a,e,i) session.evaluate(a,e,i),EvaluationFrequency=cfg.evaluationFrequency);
    save(fullfile(out,"training_options_snapshot.mat"),"cfg"); % evita serializar closures con todo el dataset.
    trainingStats=train(agent,env,opts,Evaluator=evaluator);
    save(fullfile(out,"trainingStats.mat"),"trainingStats","-v7.3");
    writeText(fullfile(out,"TRAINING_COMPLETED.txt"),"Training terminó; evaluación comportamental y figuras todavía pendientes.");
    e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","RUNNING","stage","STATS_AND_POLICY_EVALUATION","finalTestExecuted",false));
    fprintf("TRAINING TERMINADO. Comienza guardado de curvas y TEST COMPORTAMENTAL con figuras por episodio.\n");
    finalActor=getLearnableParameters(getActor(agent));critics=getCritic(agent);criticChanged=false(1,2);
    for j=1:2,criticChanged(j)=~isequaln(initialCritics{j},getLearnableParameters(critics(j)));end
    learning=struct("actorChanged",~isequaln(initialActor,finalActor),"criticsChanged",criticChanged);e2cWriteJSON(fullfile(out,"learning_check.json"),learning);
    if cfg.mode=="smoke",assert(learning.actorChanged && all(criticChanged),"E3AX:NoLearning","El smoke no demostró actualización real de pesos.");end
    clear agent env critics initialActor initialCritics finalActor opts evaluator;
    graphs=e3axExportTrainingStats(trainingStats,out);evaluation=e3axFinalEvaluation(session);
    summary=struct("mode",cfg.mode,"outputDirectory",out,"requestedEpisodes",cfg.maxEpisodes,"completedEpisodes",numel(trainingStats.EpisodeIndex), ...
        "plots","training-progress","desktop",usejava('desktop'),"trainingStatsSaved",true,"learning",learning,"graphs",graphs,"evaluation",evaluation, ...
        "agentCheckpointAvailable",true,"fullTrainingResumeAvailable",false,"trainingMonitorScreenshot","NOT_RELIABLY_SUPPORTED", ...
        "referenceContractValidated",false,"exploratoryTrainingAuthorized",true,"hardwareAuthorized",false,"MATEO_SANDRA_SEALED",true,"PUSH",false);
    e3axVerifyHistory();e2cWriteJSON(fullfile(out,"summary.json"),summary);save(fullfile(out,"summary.mat"),"summary");
    e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","COMPLETE","stage","POLICY_EVALUATION_AND_FIGURES_VERIFIED","report",evaluation.behavioralTest.html,"finalTestExecuted",false));
    writeText(fullfile(out,"COMPLETED.txt"),"Episodios completados: "+summary.completedEpisodes+" de "+cfg.maxEpisodes+newline+ ...
        "TEST COMPORTAMENTAL = COMPLETE"+newline+"PNG = "+evaluation.behavioralTest.pngCount+"; FIG = "+evaluation.behavioralTest.figCount+newline+ ...
        "Informe: "+evaluation.behavioralTest.html+newline+"TEST FINAL MATEO/SANDRA = NO. Training Progress permanece abierto.");
    disp(summary);fprintf("Training Progress permanece abierto. Artefactos: %s\n",out);
catch ex
    if isfile(fullfile(out,"TRAINING_COMPLETED.txt"))
        e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","FAILED","message",ex.message,"trainingCompleted",true, ...
            "recoveryCommand","runE3AXPostTraining('"+out+"')","finalTestExecuted",false));
        fprintf("El entrenamiento está guardado; el cierre NO está completo. Recuperar sin entrenar: runE3AXPostTraining('%s')\n",out);
    end
    writeText(fullfile(out,"FAILED.txt"),string(getReport(ex,'extended','hyperlinks','off')));rethrow(ex);
end
end
function writeText(p,s)
f=fopen(p,'w','n','UTF-8');assert(f>=0);c=onCleanup(@() fclose(f));fprintf(f,'%s',s); %#ok<NASGU>
end
function restore(p,d,r,o)
setConfigurablesOverride(o);rng(r);cd(d);path(p);
end
