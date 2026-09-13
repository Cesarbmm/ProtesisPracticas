function report=runE3AXPostTraining(runDirectory)
% Evalúa/publica una corrida existente. NUNCA llama train ni crea otro agente.
arguments,runDirectory (1,1) string;end
root=string(fileparts(mfilename("fullpath")));out=string(java.io.File(char(runDirectory)).getCanonicalPath());
assert(isfolder(out) && isfile(fullfile(out,"config.mat")),"E3AX:RunMissing","Seleccionar carpeta de corrida con config.mat.");
oldPath=path;oldRng=rng;oldDir=pwd;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(oldPath,oldRng,oldDir,old)); %#ok<NASGU>
cd(root);addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(genpath(fullfile(root,"lib")));addpath(fullfile(root,"analysis","paired_reference"));addpath(fullfile(root,"analysis","paired_reference","e3ax"));
assert(~contains(lower(out),"sandbox"),"E3AX:ForbiddenPath","Ruta fuera de la línea principal.");
saved=load(fullfile(out,"config.mat"),"cfg","o");cfg=saved.cfg;setConfigurablesOverride(saved.o);e3axVerifyHistory();
e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","RUNNING","stage","RECOVERY_OR_PUBLICATION","trainingExecuted",false));
try
    complete=isfile(fullfile(out,"evaluation","final_summary.json"));
    for kind=["best_checkpoint","last_checkpoint"]
        complete=complete && isfile(fullfile(out,"evaluation",kind,"summary.json"));
        for file=["episode_metrics.csv","trajectories.mat"]
            complete=complete && isfile(fullfile(out,"evaluation",kind,"metrics",file));
        end
    end
    for split=["ALL","TRAIN","VALIDATION"]
        complete=complete && isfile(fullfile(out,"evaluation","comparison",split,"metrics.csv"));
    end
    if ~complete
        % Resultados de entrenamiento quedan intactos; los metadatos de recuperación
        % se guardan en una carpeta nueva. El evaluador usa sólo actores guardados.
        scratch=fullfile(out,"recovery_"+string(datetime('now',Format='yyyyMMdd_HHmmss_SSS')));mkdir(scratch);
        data=e3axLoadData(cfg,scratch);session=E3AXSession(cfg,out,data);
        R=readtable(fullfile(out,"checkpoint_validation.csv"),TextType="string",Delimiter=",");
        session.records=table2struct(R);e3axFinalEvaluation(session);
    end
    repaired=e3axRepairEpisodeFigures(out);report=e3axPublishBehavioralTest(out);report.repairedEpisodes=repaired;
    e3axVerifyHistory();e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),report);
catch ex
    e2cWriteJSON(fullfile(out,"POST_TRAINING_STATUS.json"),struct("status","FAILED","message",ex.message,"trainingExecuted",false));rethrow(ex);
end
end
function restore(p,r,d,o)
setConfigurablesOverride(o);rng(r);cd(d);path(p);
end
