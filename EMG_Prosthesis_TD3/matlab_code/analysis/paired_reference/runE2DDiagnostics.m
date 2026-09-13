function summary=runE2DDiagnostics
% Replays y mapas contrafactuales fijados en el preregistro; no selecciona epsilon.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2d_results");
prereg=fullfile(fileparts(root),"docs","paired_reference","PREREGISTRO_E2D.md");
assert(e2cSHA256(prereg)=="9a9527571f9fac8524aa8b3ef90ee0110ed1bfce075146596868b7e5cd1ee8c9");
had=isappdata(0,"configurables_override");old=struct();if had,old=getappdata(0,"configurables_override");end
cleanup=onCleanup(@() restoreOverride(old,had)); %#ok<NASGU>
setConfigurablesOverride(struct("run_training",false,"flagSaveTraining",false,"plotEpisodeOnTest",false));
[remap,remapCleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
source=load(fullfile(here,"e2c_results","cycle_artifacts.mat"),"L","F");
d=load(fullfile(out,"trajectories.mat"),"grid","baselines");grid=d.grid;
fixedRows={};fixedTables={};maps={};boundRows={};
for c=1:2
    motor=c+2;
    for ri=1:5
        for si=1:2
            f=source.F(source.F.caseId==c & source.F.referenceIndex==ri & source.F.initialStateIndex==si,:);
            q=zeros(1,4);q(motor)=f.qBefore(1);ref=encoder2Flex(q)./[4092 2046 1023 2046];ref(motor)=f.reference(1);
            metadata=struct("subject","E2C_CASE_"+c,"repetition",ri,"side",si,"controller","P_2","kp",2,"steps",100);
            seed=struct("q",repmat(q,101,1),"pwm",zeros(100,4),"reference",repmat(ref,100,1), ...
                "referenceBefore",repmat(ref,100,1),"metadata",metadata);
            base=e2dRollout(seed,0,remap);
            assert(isequal(base.q(1:100,motor),f.qBefore) && isequal(base.q(2:101,motor),f.qAfter));
            for g=1:numel(grid)
                if g==1,t=base;else,t=e2dRollout(base,grid(g),remap);end
                pair=sort(t.q(end-1:end,motor));basePair=sort(base.q(end-1:end,motor));
                terminal=t.cycleMask(end,motor);
                fixedRows{end+1}=struct("epsilon",grid(g),"caseId",c,"referenceIndex",ri,"initialStateIndex",si, ...
                    "reference",ref(motor),"terminalCycle",terminal,"originalPairPersists",terminal && max(abs(pair-basePair))<=1e-9, ...
                    "newPair",terminal && max(abs(pair-basePair))>1e-9,"slidingCycleWindows",nnz(t.cycleMask(:,motor)), ...
                    "zeroCommands",nnz(t.pwm(:,motor)==0),"last20AllZero",all(t.pwm(end-19:end,motor)==0), ...
                    "lastQ",t.q(end,motor),"lastError",t.errorBefore(end,motor)); %#ok<AGROW>
                keys=table(repmat(grid(g),100,1),repmat(c,100,1),repmat(ri,100,1),repmat(si,100,1),(1:100)', ...
                    VariableNames=["epsilon","caseId","referenceIndex","initialStateIndex","step"]);
                values=[t.referenceBefore(:,motor),t.errorBefore(:,motor),t.rawHistorical(:,motor),t.rawAction(:,motor), ...
                    t.effectiveAction(:,motor),t.pwm(:,motor),t.q(1:100,motor),t.q(2:end,motor),t.zeroedDirect(:,motor)];
                fixedTables{end+1}=[keys,array2table(values,VariableNames=["teacher","error","rawHistorical", ...
                    "rawDeadband","effective","pwm","qBefore","qAfter","zeroedDirect"])]; %#ok<AGROW>
            end
        end
    end
end
for g=1:numel(grid)
    L=source.L;epsilon=grid(g);L.epsilon=repmat(epsilon,height(L),1);
    L.rawDeadband=e2dDeadbandAction(L.error,epsilon);[L.effectiveDeadband,L.pwmDeadband]=remap(L.rawDeadband);
    L.qNextDeadband=zeros(height(L),1);L.zeroedDirect=L.pwm~=0 & L.pwmDeadband==0;
    for k=1:height(L)
        motor=L.caseId(k)+2;q=zeros(1,4);q(motor)=L.q(k);u=zeros(1,4);u(motor)=L.pwmDeadband(k);
        next=SimController.prosthesis_simulator(q,u,.2,.14,plantSource="patternCurveCanonical");L.qNextDeadband(k)=next(motor);
    end
    if g==1,assert(isequal(L.qNext,L.qNextDeadband) && isequal(L.pwm,L.pwmDeadband));end
    maps{end+1}=L; %#ok<AGROW>
    for c=1:2
        states=unique(source.F.qBefore(source.F.caseId==c & source.F.referenceIndex==1));motor=c+2;
        for state=states'
            q=zeros(1,4);q(motor)=state;h=encoder2Flex(q)./[4092 2046 1023 2046];
            centers=unique([-.025 .025 -epsilon epsilon]);
            for center=centers
                for offset=[-1e-10 0 1e-10]
                    error=center+offset;[raw,historical]=e2dDeadbandAction(error,epsilon);
                    [eff,pwm]=remap(raw);[~,pwmHist]=remap(historical);
                    cmd=zeros(1,4);cmd(motor)=pwm;next=SimController.prosthesis_simulator(q,cmd,.2,.14,plantSource="patternCurveCanonical");
                    boundRows{end+1}=struct("epsilon",epsilon,"caseId",c,"qBefore",state,"hBefore",h(motor), ...
                        "teacher",h(motor)+error,"boundaryError",center,"offset",offset,"error",error, ...
                        "rawHistorical",historical,"rawDeadband",raw,"historicalPwm",pwmHist,"effective",eff, ...
                        "pwm",pwm,"qAfter",next(motor)); %#ok<AGROW>
                end
            end
        end
    end
    fprintf("E2D mapa local epsilon %.2f completado.\n",epsilon);
end
F=struct2table([fixedRows{:}]);FT=vertcat(fixedTables{:});L=vertcat(maps{:});B=struct2table([boundRows{:}]);
writetable(F,fullfile(out,"fixed_reference_summary.csv"));writetable(FT,fullfile(out,"fixed_reference_traces.csv"));
writetable(L,fullfile(out,"local_counterfactual_map.csv"));writetable(B,fullfile(out,"deadband_boundaries.csv"));
save(fullfile(out,"diagnostic_artifacts.mat"),"F","FT","L","B","-v7.3");
summary=struct("localMapRows",height(L),"fixedReplays",height(F),"fixedSteps",height(FT), ...
    "boundaryRows",height(B),"grid",grid,"epsilon0LocalMapExact",true,"epsilon0FixedReferenceExact",true);
e2cWriteJSON(fullfile(out,"diagnostic_summary.json"),summary);disp(summary);
end
function restoreOverride(old,had)
if had,setConfigurablesOverride(old);else,clearConfigurablesOverride();end
end
