function summary=runPairedReferenceE2E
% Reproducción exclusiva E2E: no entrenamiento ni operaciones Git.
had=isappdata(0,"configurables_override");old=struct();if had,old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restore(old,had)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"),"E2E:ForbiddenPath");
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
runE2EDiagnostics();runE2EMeasurements();e2eRunTests();summary=e2eFinalize();
end
function restore(old,had)
if had,setConfigurablesOverride(old);else,clearConfigurablesOverride();end
end
