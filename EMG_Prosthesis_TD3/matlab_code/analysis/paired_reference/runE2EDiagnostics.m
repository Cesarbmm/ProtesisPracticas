function summary=runE2EDiagnostics
% Primero casos conocidos; luego contrafactuales fijos, sin ajustar intervención.
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2e_results");
e2eVerifyHistory();[remap,cleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
source=load(fullfile(here,"e2b_results","trajectories.mat"),"trajectories");
knownTables={};knownTrajectories=cell(2,2);
for c=1:2
    subject="BLANCA";rep=1;side=1;if c==2,subject="IVANNA";rep=104;side=2;end
    matches=cellfun(@(x) x.metadata.controller=="P_2" && x.metadata.subject==subject && ...
        x.metadata.repetition==rep && x.metadata.side==side,source.trajectories);
    base=source.trajectories{find(matches)};
    for enabled=[0 1]
        t=e2eRollout(base,enabled,remap);knownTrajectories{c,enabled+1}=t;
        if ~enabled,assert(isequal(t.q,base.q) && isequal(t.pwm,base.pwm));end
        knownTables{end+1}=e2eStepTable(t,base,enabled); %#ok<AGROW>
    end
end
K=vertcat(knownTables{:});writetable(K,fullfile(out,"known_cases_all_motors.csv"));
writetable(K((K.subject=="BLANCA" & K.motor==3) | (K.subject=="IVANNA" & K.motor==4),:), ...
    fullfile(out,"known_cycle_case_traces.csv"));
fprintf("E2E: ambos casos E2C reproducidos OFF/ON.\n");
d=load(fullfile(here,"e2c_results","cycle_artifacts.mat"),"F");
fixedRows={};fixedTables={};fixedTrajectories=cell(20,2);index=0;
for c=1:2
    motor=c+2;
    for ri=1:5
        for si=1:2
            index=index+1;f=d.F(d.F.caseId==c & d.F.referenceIndex==ri & d.F.initialStateIndex==si,:);
            q=zeros(1,4);q(motor)=f.qBefore(1);ref=encoder2Flex(q)./[4092 2046 1023 2046];ref(motor)=f.reference(1);
            md=struct("subject","E2C_CASE_"+c,"repetition",ri,"side",si,"controller","P_2","kp",2,"steps",100);
            seed=struct("q",repmat(q,101,1),"pwm",zeros(100,4),"reference",repmat(ref,100,1), ...
                "referenceBefore",repmat(ref,100,1),"metadata",md);
            base=e2eRollout(seed,false,remap);
            assert(isequal(base.q(1:100,motor),f.qBefore) && isequal(base.q(2:101,motor),f.qAfter));
            for enabled=[0 1]
                if enabled,t=e2eRollout(base,true,remap);else,t=base;end
                fixedTrajectories{index,enabled+1}=t;
                [period,persistentReversals]=e2eFixedOrbit(t.q,t.previousAppliedPwm,t.pendingBefore,t.pwm,motor);
                fixedRows{end+1}=struct("enabled",enabled,"caseId",c,"referenceIndex",ri,"initialStateIndex",si, ...
                    "reference",ref(motor),"terminalCycle",t.cycleMask(end,motor),"period",period, ...
                    "persistentReversals",persistentReversals,"neutralSteps",nnz(t.neutralized(:,motor)), ...
                    "requests",nnz(t.request(:,motor)),"confirmed",nnz(t.confirmed(:,motor)), ...
                    "cancelled",nnz(t.cancelled(:,motor)),"pendingEnd",t.pendingAfter(end,motor)~=0, ...
                    "confirmedLast20",nnz(t.confirmed(end-19:end,motor)), ...
                    "lastQ",t.q(end,motor),"lastError",t.errorBefore(end,motor)); %#ok<AGROW>
                T=e2eStepTable(t,base,enabled);T=T(T.motor==motor,:);
                T.caseId=repmat(c,100,1);T.referenceIndex=repmat(ri,100,1);T.initialStateIndex=repmat(si,100,1);
                fixedTables{end+1}=T; %#ok<AGROW>
            end
        end
    end
end
F=struct2table([fixedRows{:}]);FT=vertcat(fixedTables{:});
writetable(F,fullfile(out,"fixed_reference_summary.csv"));writetable(FT,fullfile(out,"fixed_reference_traces.csv"));
save(fullfile(out,"diagnostic_artifacts.mat"),"fixedTrajectories","knownTrajectories","F","-v7.3");
summary=struct("fixedReplaysPerMode",20,"fixedStepsPerMode",2000,"offExactE2C",true, ...
    "onHistoricalCycles",nnz(F.enabled==1 & F.terminalCycle), ...
    "onAugmentedStateCycles",nnz(F.enabled==1 & F.period>0), ...
    "onPersistentReversals",nnz(F.enabled==1 & F.persistentReversals));
e2cWriteJSON(fullfile(out,"diagnostic_summary.json"),summary);disp(summary);
end
