function report=e3axVerifyCheckpointEvaluation(checkpoint)
% Recuperación de infraestructura SIN entrenamiento; usa checkpoint existente.
here=string(fileparts(mfilename("fullpath")));addpath(fileparts(here));cfg=e3axConfig("smoke");
addpath(genpath(fullfile(cfg.root,"src")));addpath(fullfile(cfg.root,"config"));addpath(genpath(fullfile(cfg.root,"lib")));
old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end;c=onCleanup(@() setConfigurablesOverride(old)); %#ok<NASGU>
clearConfigurablesOverride();setConfigurablesOverride(e3axOverride(cfg));
out=fullfile(cfg.root,"results","e3ax_preparation","evaluation_recovery_"+string(datetime('now',Format='yyyyMMdd_HHmmss_SSS')));mkdir(out);
data=e3axLoadData(cfg,out);validation=data.evaluation(cellfun(@(x) x.split=="VALIDATION",data.evaluation));
result=e3axEvaluate(checkpoint,validation,fullfile(out,"checkpoint"),"TD3_RECOVERY",false);
s=E3AXSession(cfg,out,data);s.recordEvaluation(result,2);assert(numel(s.records)==1);
final=e3axFinalEvaluation(s);report=struct("evaluation","PASS","recordFirstResult","PASS","finalPlots","PASS","trainingExecuted",false,"output",out,"final",final);
e2cWriteJSON(fullfile(out,"recovery_summary.json"),report);disp(report);
end
