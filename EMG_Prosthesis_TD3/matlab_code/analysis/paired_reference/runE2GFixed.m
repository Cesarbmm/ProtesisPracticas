function summary=runE2GFixed
here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(here));out=fullfile(here,"e2g_results");
e2gVerifyHistory();[remap,c]=e2cHistoricalRemapper(root); %#ok<ASGLU>
d=load(fullfile(here,"e2f_results","fixed_trajectories.mat"));gd=load(fullfile(here,"e2f_results","graphs.mat"));graphs=gd.graphs;
fixedTrajectories=cell(20,2);rows={};tables={};
for e=1:20
    original=d.fixedTrajectories{e,5};base=d.fixedTrajectories{e,1};m=3+(e>10);
    projected=base;projected.reference=e2gProjectReference(base.reference,graphs);projected.referenceBefore=e2gProjectReference(base.referenceBefore,graphs);
    candidate=e2fRollout(projected,5,graphs,remap);
    for col=1:2
        if col==1,t=original;t.metadata.controller="ORIGINAL";else,t=candidate;t.metadata.controller="PROJECTED";end
        fixedTrajectories{e,col}=t;period=e2fPeriodicTrace(t.q,t.pwm,m,true);cycles=e2dCycleScan(t.q,t.pwm);
        rows{end+1}=struct("controller",t.metadata.controller,"caseId",m-2,"referenceIndex",base.metadata.repetition,"initialStateIndex",base.metadata.side, ...
            "motor",m,"reference",t.reference(1,m),"period",period,"terminalCycle",cycles(end,m), ...
            "last20Hold",max(abs(diff(t.q(end-20:end,m))))<=1e-9,"last20MSE",mean((t.prediction(end-19:end,m)-t.reference(end-19:end,m)).^2), ...
            "m3Reversals",nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0)); %#ok<AGROW>
        T=e2fTraceTable(t);tables{end+1}=T(T.motor==m,:); %#ok<AGROW>
    end
end
F=struct2table([rows{:}]);writetable(F,fullfile(out,"fixed_summary.csv"));writetable(vertcat(tables{:}),fullfile(out,"fixed_steps.csv"));
save(fullfile(out,"fixed_trajectories.mat"),"fixedTrajectories","-v7.3");
S=F(F.controller=="PROJECTED",:);summary=struct("fixedCycles",nnz(S.terminalCycle),"fixedPeriods",nnz(S.period),"fixedStable",nnz(S.last20Hold),"m3Reversals",sum(S.m3Reversals));
e2cWriteJSON(fullfile(out,"fixed_summary.json"),summary);disp(summary);e2gVerifyHistory();
end
