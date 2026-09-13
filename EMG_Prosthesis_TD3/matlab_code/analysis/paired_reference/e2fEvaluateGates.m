function gate=e2fEvaluateGates
here=string(fileparts(mfilename("fullpath")));out=fullfile(here,"e2f_results");
read=@(n) readtable(fullfile(out,n+".csv"),TextType="string");
M=read("controller_summary");P=M(M.controller=="P_2",:);O=M(M.controller=="ORACLE_H5",:);
E=read("episode_metrics");C=read("cycle_windows");Q=read("periodic_trajectories");F=read("fixed_reference_summary");
R=read("reachability_summary");RP=R(R.controller=="P_2",:);T=read("step_traces");S=T(T.controller=="ORACLE_H5",:);
tables={read("subject_summary"),read("motor_summary"),read("direction_summary")};
kind=["subject","motor","direction"];id=["subject","motor","side"];rows={};counts=zeros(1,3);
for H=[1 2 3 5]
    controller="ORACLE_H"+H;
    for type=1:3
        A=tables{type};a=A(A.controller==controller,:);b=A(A.controller=="P_2",:);
        assert(isequal(a.(id(type)),b.(id(type))));
        for j=1:height(a)
            dm=change(a.trackingMSE(j),b.trackingMSE(j),false);dr=change(a.rewardMean(j),b.rewardMean(j),true);
            degraded=dm>5+1e-12 || dr>5+1e-12;if H==5,counts(type)=counts(type)+degraded;end
            rows{end+1}=struct("horizon",H,"kind",kind(type),"group",string(a.(id(type))(j)), ...
                "mseChangePct",dm,"rewardChangePct",dr,"degraded",degraded); %#ok<AGROW>
        end
    end
end
D=struct2table([rows{:}]);writetable(D,fullfile(out,"subgroup_degradations.csv"));
gate=struct("primaryHorizon",5,"trackingMSE",O.trackingMSE,"rewardMean",O.rewardMean, ...
    "mseImprovementPct",100*(P.trackingMSE-O.trackingMSE)/P.trackingMSE, ...
    "rewardDeteriorationPct",change(O.rewardMean,P.rewardMean,true), ...
    "subjectDegradations",counts(1),"motorDegradations",counts(2),"directionDegradations",counts(3), ...
    "fixedStable",nnz(F.horizon==5 & F.stableStrategy),"fixedOrbits",nnz(F.horizon==5 & F.period>0), ...
    "finalCycles",sum(E.persistentTwoCycle(E.controller=="ORACLE_H5")), ...
    "newFinalCycles",nnz(C.controller=="ORACLE_H5" & C.terminal & C.newVersusP2), ...
    "periodicTrajectories",nnz(Q.controller=="ORACLE_H5" & Q.period>0), ...
    "newPeriodicTrajectories",nnz(Q.controller=="ORACLE_H5" & Q.newVersusP2), ...
    "p2OneStepFloorMSE",RP.minimumReachableMSE,"p2OneStepFloorRatio",RP.minimumReachableMSE/P.trackingMSE, ...
    "m3Reversals",nnz(S.motor==3 & S.pwm>0 & S.qAfter<S.qBefore), ...
    "zeroMotionFailures",nnz(S.pwm==0 & abs(S.qAfter-S.qBefore)>1e-9));
gate.pass1=gate.fixedStable==20 && gate.fixedOrbits==0 && gate.finalCycles==0;
gate.pass2=gate.mseImprovementPct>=10-1e-12 && O.rewardMean>=P.rewardMean-1e-12 && ...
    counts(1)<=2 && counts(2)<=1 && counts(3)==0;
gate.pass3=gate.p2OneStepFloorRatio<=.5+1e-12;
gate.pass4=gate.newPeriodicTrajectories==0 && gate.m3Reversals==0 && gate.zeroMotionFailures==0;
gate.measuredGatesPass=gate.pass1 && gate.pass2 && gate.pass3 && gate.pass4;
writetable(struct2table(gate),fullfile(out,"primary_gates.csv"));e2cWriteJSON(fullfile(out,"primary_gates.json"),gate);disp(gate);
end
function v=change(a,b,reward)
d=a-b;if reward,d=-d;end
if abs(b)<=1e-12,if d<=1e-12,v=0;else,v=Inf;end;else,v=100*d/abs(b);end
end
