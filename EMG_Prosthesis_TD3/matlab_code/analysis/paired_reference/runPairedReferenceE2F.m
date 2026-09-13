function summary=runPairedReferenceE2F
% Reproduce sólo E2F; ninguna ruta de entrenamiento o Git.
here=string(fileparts(mfilename("fullpath")));out=fullfile(here,"e2f_results");
had=isappdata(0,"configurables_override");old=struct();if had,old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(old,had)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"));e2fVerifyHistory();
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
d=load(fullfile(here,"e2b_results","trajectories.mat"),"trajectories");
keep=cellfun(@(x) any(x.metadata.controller==["ZERO","P_2","AGENT7250"]),d.trajectories);
f=load(fullfile(here,"e2c_results","cycle_artifacts.mat"),"F");f.F.motor=f.F.caseId+2;
e2fBuildGraphs(d.trajectories(keep),f.F,out);e2fValidateBellman();runE2FMeasurements();runE2FFixed();
e2fEvaluateGates();e2fRunTests();
script=fullfile(here,"e2fSupportAudit.py");[status,output]=system("python """+script+"""");
assert(status==0,"E2F:SupportAuditFailed",output);fprintf("%s",output);
summary=e2fFinalize();
end
function restore(old,had)
if had,setConfigurablesOverride(old);else,clearConfigurablesOverride();end
end
