function summary=e3axRunPostTrainingTests(options)
% Regresiones históricas + E3AX y pruebas del cierre. Sin entrenamiento.
arguments,options.reuseHistorical (1,1) logical = false;end
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(fileparts(here)));out=fullfile(fileparts(here),"e3ax_run_audit");
oldPath=path;c=onCleanup(@() path(oldPath));addpath(fileparts(here)); %#ok<NASGU>
old=e3axRunTests(reusePrevious=options.reuseHistorical);assert(old.passed==225);
r=runtests(fullfile(root,"tests","paired_reference","testE3AXPostTraining.m"));
T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]',VariableNames=["Name","Passed","Failed","Incomplete","Duration"]);
writetable(T,fullfile(out,"post_training_test_results.csv"));
prior=readtable(fullfile(fileparts(here),"e3ax_preparation","regression","test_results.csv"),TextType="string",Delimiter=",");
combined=[prior;T];writetable(combined,fullfile(out,"all_test_results.csv"));
summary=struct("previousPassed",old.passed,"newTests",height(T),"newPassed",nnz(T.Passed),"totalTests",height(combined), ...
    "passed",nnz(combined.Passed),"failed",nnz(combined.Failed),"incomplete",nnz(combined.Incomplete),"trainingExecuted",false);
e2cWriteJSON(fullfile(out,"test_summary.json"),summary);disp(summary);
assert(all(T.Passed),"E3AX:PostTrainingTestsFailed","Revisar resultados de pruebas del cierre.");
end
