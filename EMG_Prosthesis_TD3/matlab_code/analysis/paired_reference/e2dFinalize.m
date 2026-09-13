function summary=e2dFinalize
% Cierre medido: nunca selecciona un candidato que incumpla un gate.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2d_results");
m=jsondecode(fileread(fullfile(out,"measurement_summary.json")));
t=jsondecode(fileread(fullfile(out,"test_summary.json")));
d=jsondecode(fileread(fullfile(out,"diagnostic_summary.json")));
g=readtable(fullfile(out,"candidate_gates.csv"));f=readtable(fullfile(out,"fixed_reference_summary.csv"));
assert(t.previousTests==81 && t.previousPassed==81 && t.passed==t.totalTests && ...
    t.historicalFilesUnchanged,"E2D:TestGateFailed","No cerrar sin regresiones completas.");
selected=e2dSelectEpsilon(g.epsilon',g.passed');
result="DEADBAND_NOT_SUFFICIENT";if isfinite(selected),result="MINIMAL_ANTI_CHATTERING_SUPPORTED";end
summary=struct("worktree",fileparts(fileparts(root)),"branch","experiment/no-glove-paired-reference-td3", ...
    "startSHA","165be049eb41fc41254435181c9857fe0f22ed1c","E2C_RESULT","CHARACTERIZED", ...
    "E2B_RESULT","FAIL","P2_BASELINE_MSE",m.baselineMSE,"P2_BASELINE_REWARD",m.baselineReward, ...
    "P2_BASELINE_CYCLES",m.baselineCycles,"EPSILON_GRID",m.grid,"SELECTED_EPSILON",selected, ...
    "E2D_RESULT",result,"RL_AUTHORIZED",false,"E3_PREPARED",false,"E3_EXECUTED",false, ...
    "MATEO_SANDRA_SEALED",true,"HISTORICAL_HASHES_INTACT",t.historicalFilesUnchanged, ...
    "GIT_REPAIR_ATTEMPTED",false,"PUSH",false,"tests",t,"diagnostics",d, ...
    "candidateGates",table2struct(g),"fixedCyclesByEpsilon",zeros(numel(g.epsilon),1), ...
    "preregistrationSHA256",m.preregistrationSHA256);
for k=1:height(g),summary.fixedCyclesByEpsilon(k)=nnz(f.epsilon==g.epsilon(k) & f.terminalCycle);end
if isfinite(selected)
    summary.selected=table2struct(g(g.epsilon==selected,:));
else
    summary.selected=[];
end
e2cWriteJSON(fullfile(out,"e2d_summary.json"),summary);
e2dPlotResults(out);
files=dir(fullfile(out,"**","*"));rows={};
for file=files'
    if file.isdir || string(file.name)=="artifact_manifest.json",continue,end
    full=fullfile(file.folder,file.name);relative=extractAfter(string(full),strlength(out)+1);
    rows{end+1}=struct("file",relative,"bytes",file.bytes,"sha256",e2cSHA256(full)); %#ok<AGROW>
end
e2cWriteJSON(fullfile(out,"artifact_manifest.json"),struct("artifacts",[rows{:}]));
disp(summary);
end
