function summary=runPairedReferenceE2G
% Reproduce E2G exclusivamente. No recaptura historia ni entrena.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));
old=path;oldDir=pwd;c=onCleanup(@() restore(old,oldDir)); %#ok<NASGU>
assert(~contains(lower(string(path)),"sandbox"));cd(root);
addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(genpath(fullfile(root,"lib")));addpath(here);
e2gVerifyHistory();e2gAuditPlantSupport();pythonScript("e2gAuditPlantSupportRaw.py");
runE2GMeasurements();runE2GFixed();pythonScript("e2gSummarize.py");
e2gRunTests();e2gMakeFigures();pythonScript("e2gWriteReport.py");pythonScript("e2gFinalize.py");
pythonScript("verifyE2GArtifacts.py");summary=jsondecode(fileread(fullfile(here,"e2g_results","e2g_summary.json")));
end
function pythonScript(name)
script=fullfile(fileparts(mfilename("fullpath")),name);[code,output]=system("python """+script+"""");fprintf("%s",output);assert(code==0,"E2G:PythonFailure");
end
function restore(p,d)
path(p);cd(d);
end
