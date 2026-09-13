function Z=e2eEventSummary(T)
rows={};
for enabled=[0 1]
    A=T(T.enabled==enabled,:);
    for kind=["total","motor","direction","motor_direction"]
        motors=0;sides=0;
        if contains(kind,"motor"),motors=1:4;end
        if contains(kind,"direction"),sides=1:2;end
        for m=motors
            for s=sides
                mask=true(height(A),1);if m,mask=mask & A.motor==m;end;if s,mask=mask & A.side==s;end
                B=A(mask,:);active=nnz(B.baselinePwm~=0);neutrals=nnz(B.neutralized);
                endings=false(height(B),1);
                % Cada motor/episodio conserva orden creciente de paso en exportación.
                endings(1:end-1)=B.step(2:end)<=B.step(1:end-1);endings(end)=true;
                rows{end+1}=struct("enabled",enabled,"kind",kind,"motor",m,"side",s, ...
                    "commands",height(B),"baselineActive",active,"requests",nnz(B.request), ...
                    "neutralized",neutrals,"confirmed",nnz(B.confirmed),"cancelled",nnz(B.cancelled), ...
                    "pendingEnd",nnz(B.pendingAfter(endings)),"neutralStepFraction",neutrals/height(B), ...
                    "neutralStepFractionOfActiveBaseline",neutrals/active, ...
                    "neutralizedBaselineActive",nnz(B.neutralized & B.baselinePwm~=0), ...
                    "pairedZeroed",nnz(B.baselinePwm~=0 & B.pwm==0), ...
                    "pairedZeroedActiveFraction",nnz(B.baselinePwm~=0 & B.pwm==0)/active, ...
                    "maxConsecutiveNeutralSteps",max(B.neutralRunLength), ...
                    "maxConsecutiveZeroCommands",max(B.zeroRunLength),"zeroCommands",nnz(B.pwm==0)); %#ok<AGROW>
            end
        end
    end
end
Z=struct2table([rows{:}]);
end
