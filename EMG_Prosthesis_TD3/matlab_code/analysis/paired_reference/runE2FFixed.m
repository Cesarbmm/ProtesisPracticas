function summary=runE2FFixed
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2f_results");
e2fVerifyHistory();[remap,cleanup]=e2cHistoricalRemapper(root); %#ok<ASGLU>
d=load(fullfile(here,"e2c_results","cycle_artifacts.mat"),"F");gd=load(fullfile(out,"graphs.mat"));graphs=gd.graphs;
rows={};tables={};fixedTrajectories=cell(20,5);index=0;
for c=1:2
    motor=c+2;
    for ri=1:5
        for si=1:2
            index=index+1;f=d.F(d.F.caseId==c & d.F.referenceIndex==ri & d.F.initialStateIndex==si,:);
            q=zeros(1,4);q(motor)=f.qBefore(1);ref=encoder2Flex(q)./[4092 2046 1023 2046];ref(motor)=f.reference(1);
            md=struct("subject","FIXED_CASE_"+c,"repetition",ri,"side",si,"controller","P_2","kp",2,"steps",100);
            seed=struct("q",repmat(q,101,1),"pwm",zeros(100,4),"reference",repmat(ref,100,1), ...
                "referenceBefore",repmat(ref,100,1),"metadata",md);
            base=e2eRollout(seed,false,remap);fixedTrajectories{index,1}=base;
            assert(isequal(base.q(1:100,motor),f.qBefore) && isequal(base.q(2:end,motor),f.qAfter));
            baseMse=mean((base.prediction(end-19:end,motor)-ref(motor)).^2);
            for H=[0 1 2 3 5]
                if H==0,t=base;col=1;else,t=e2fRollout(base,H,graphs,remap);col=find([0 1 2 3 5]==H);end
                fixedTrajectories{index,col}=t;period=e2fPeriodicTrace(t.q,t.pwm,motor,true);cycles=e2dCycleScan(t.q,t.pwm);
                lastMse=mean((t.prediction(end-19:end,motor)-ref(motor)).^2);
                hold=max(abs(diff(t.q(end-20:end,motor))))<=1e-9;
                rows{end+1}=struct("horizon",H,"caseId",c,"referenceIndex",ri,"initialStateIndex",si, ...
                    "motor",motor,"reference",ref(motor),"period",period,"terminalCycle",cycles(end,motor), ...
                    "last20Hold",hold,"last20MSE",lastMse,"p2Last20MSE",baseMse, ...
                    "stableStrategy",hold && period==0 && lastMse<=baseMse+1e-12, ...
                    "last20Active",nnz(t.pwm(end-19:end,motor)),"lastQ",t.q(end,motor), ...
                    "m3Reversals",nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0)); %#ok<AGROW>
                T=e2fTraceTable(t);T=T(T.motor==motor,:);T.horizon=repmat(H,100,1);T.caseId=repmat(c,100,1);
                T.referenceIndex=repmat(ri,100,1);T.initialStateIndex=repmat(si,100,1);tables{end+1}=T; %#ok<AGROW>
            end
        end
    end
    fprintf("E2F fijos caso%d: todos los horizontes completados.\n",c);
end
F=struct2table([rows{:}]);FT=vertcat(tables{:});writetable(F,fullfile(out,"fixed_reference_summary.csv"));
writetable(FT,fullfile(out,"fixed_reference_traces.csv"));save(fullfile(out,"fixed_trajectories.mat"),"fixedTrajectories","-v7.3");
summary=struct("primaryHorizon",5,"primaryStable",nnz(F.horizon==5 & F.stableStrategy), ...
    "primaryPeriods",nnz(F.horizon==5 & F.period>0),"primaryHistoricalCycles",nnz(F.horizon==5 & F.terminalCycle));
e2cWriteJSON(fullfile(out,"fixed_summary.json"),summary);disp(summary);
end
