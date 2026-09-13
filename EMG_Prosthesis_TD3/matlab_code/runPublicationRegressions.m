function summary=runPublicationRegressions
% Regresiones desde codigo publicado. No invocar runFinalSealedTest.
root=string(fileparts(mfilename("fullpath")));pr=fullfile(root,"analysis","paired_reference");
oldP=path;prior=struct();if isappdata(0,"configurables_override"),prior=getappdata(0,"configurables_override");end
clean=onCleanup(@() restore(oldP,prior)); %#ok<NASGU>
addpath(root,pr,fullfile(root,"config"));
for part=["e3ax","e3b","cap192","e3c","e3d","e3e","e3f","e4","sealed"],addpath(fullfile(pr,part));end
addpath(genpath(fullfile(root,"src")));addpath(genpath(fullfile(root,"lib")));
assert(~contains(lower(string(path)),"sandbox"));
out=fullfile(pr,"publication_results");if ~isfolder(out),mkdir(out);end
files=dir(fullfile(root,"tests","paired_reference","test*.m"));rows={};T=table;
for file=files'
 suite=testsuite(fullfile(file.folder,file.name));
 for k=1:numel(suite),rows{end+1}=struct("file",string(file.name),"test",string(suite(k).Name));end %#ok<AGROW>
end
writetable(struct2table([rows{:}]),fullfile(out,"suite_inventory.csv"));
for file=files'
 % Tests historicos conservados. E3C requiere el mismo contexto de inferencia de su runner.
 c=e3axConfig("long");o=e3axOverride(c);o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
 fprintf("PUBLICATION: %s\n",file.name);r=runtests(fullfile(file.folder,file.name));
 N=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
 T=[T;N]; %#ok<AGROW>
 writetable(T,fullfile(out,"test_results.csv"));
end
summary=struct("total",height(T),"passed",nnz(T.Passed),"failed",nnz(T.Failed),"incomplete",nnz(T.Incomplete), ...
 "sealedTestReexecuted",false,"sealedRawRead",false,"codeWorktree",root,"fixtures","local copies ignored by Git");
e2cWriteJSON(fullfile(out,"summary.json"),summary);disp(summary);assert(all(T.Passed) && ~any(T.Incomplete));
end
function restore(p,o),setConfigurablesOverride(o);path(p);end
