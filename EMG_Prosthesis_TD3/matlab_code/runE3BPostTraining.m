function summary=runE3BPostTraining(out)
% Recupera evaluacion/figuras desde checkpoints, nunca ejecuta training.
root=string(fileparts(mfilename("fullpath")));pr=fullfile(root,"analysis","paired_reference");
oldPath=path;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(oldPath,old)); %#ok<NASGU>
addpath(root,pr,fullfile(pr,"e3ax"),fullfile(pr,"e3b"),fullfile(pr,"cap192"),fullfile(root,"config"));
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
s=load(fullfile(out,"config.mat"),"cfg","o");o=s.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
data=e3axLoadData(s.cfg,out);R=readtable(fullfile(out,"checkpoint_validation.csv"),TextType="string",Delimiter=",");
stats=load(fullfile(out,"trainingStats.mat"),"trainingStats");e3axExportTrainingStats(stats.trainingStats,out);
summary=e3bFinalEvaluation(out,s.cfg,data,table2struct(R));e2cWriteJSON(fullfile(out,"post_training_recovery.json"),summary);
f=fopen(fullfile(out,"COMPLETED.txt"),'w','n','UTF-8');assert(f>=0);
fprintf(f,'Evaluacion recuperada sin entrenamiento. Informe: %s',summary.report);fclose(f);
end
function restore(p,o),setConfigurablesOverride(o);path(p);end
