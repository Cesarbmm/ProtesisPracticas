function audit=e3axAuditRun(out)
% Repite inferencia determinista completa. No crea ni entrena agentes.
out=string(out);here=string(fileparts(mfilename("fullpath")));root=fileparts(fileparts(fileparts(here)));
oldPath=path;oldRng=rng;old=struct();if isappdata(0,"configurables_override"),old=getappdata(0,"configurables_override");end
c=onCleanup(@() restore(oldPath,oldRng,old)); %#ok<NASGU>
addpath(fileparts(here));addpath(genpath(fullfile(root,"src")));addpath(fullfile(root,"config"));addpath(genpath(fullfile(root,"lib")));
saved=load(fullfile(out,"config.mat"),"cfg","o");o=saved.o;o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);e3axVerifyHistory();
dest=fullfile(root,"analysis","paired_reference","e3ax_run_audit");if ~isfolder(dest),mkdir(dest);end
data=e3axLoadData(saved.cfg,dest);records={};
for kind=["best_checkpoint","last_checkpoint"]
    folder=fullfile(out,"evaluation",kind);s=jsondecode(fileread(fullfile(folder,"summary.json")));
    a=load(s.checkpoint,"saved_actor");original=load(fullfile(folder,"metrics","trajectories.mat"));
    E=readtable(fullfile(folder,"metrics","episode_metrics.csv"),TextType="string",Delimiter=",");
    M=readtable(fullfile(folder,"metrics","episode_motor_metrics.csv"),TextType="string",Delimiter=",");
    assert(numel(original.traces)==numel(data.evaluation),"E3AX:AuditEpisodeCount","Lista de episodios distinta.");
    before=getLearnableParameters(a.saved_actor);
    for e=1:numel(data.evaluation)
        [t,r]=e3axRollout(a.saved_actor,data.evaluation{e});prev=original.traces{e};pr=original.runtimeTraces{e};
        assert(isequal(t.metadata.subject,prev.metadata.subject) && t.metadata.repetition==prev.metadata.repetition && t.metadata.side==prev.metadata.side);
        assert(isequal(t.reference,prev.reference) && isequal(t.referenceBefore,prev.referenceBefore),"E3AX:AuditReference","Teacher original distinto.");
        [mot,met]=e2bControlMetrics(t);idx=E.subject==string(t.metadata.subject) & E.repetition==t.metadata.repetition & E.side==t.metadata.side;assert(nnz(idx)==1);
        metricDiff=0;
        for field=string(fieldnames(met))'
            actual=met.(field);expected=E.(field)(idx);assert(isequal(isnan(actual),isnan(expected)));
            if ~isnan(actual),metricDiff=max(metricDiff,abs(actual-expected));end
        end
        for motor=1:4
            mi=M.subject==string(t.metadata.subject) & M.repetition==t.metadata.repetition & M.side==t.metadata.side & M.motor==motor;assert(nnz(mi)==1);
            for field=string(fieldnames(mot(motor)))'
                actual=mot(motor).(field);expected=M.(field)(mi);assert(isequal(isnan(actual),isnan(expected)));
                if ~isnan(actual),metricDiff=max(metricDiff,abs(actual-expected));end
            end
        end
        row=struct("checkpoint",kind,"subject",string(t.metadata.subject),"row",t.metadata.repetition,"side",t.metadata.side, ...
            "stateDiff",difference(r.state,pr.state),"rawDiff",difference(r.rawAction,pr.rawAction), ...
            "effectiveDiff",difference(r.effectiveAction,pr.effectiveAction),"pwmDiff",difference(r.pwm,pr.pwm), ...
            "qDiff",difference(r.q,pr.q),"rewardDiff",difference(t.reward,prev.reward),"metricsCsvDiff",metricDiff, ...
            "teacherSteps",size(t.pwm,1),"emgOnlySteps",size(r.pwm,1),"m3Reversals",nnz(t.pwm(:,3)>0 & diff(t.q(:,3))<0));
        assert(max([row.stateDiff row.rawDiff row.effectiveDiff row.pwmDiff row.qDiff])==0 && row.rewardDiff<=1e-12 && metricDiff<=1e-9,"E3AX:AuditMismatch","La repetición no coincide con las trazas guardadas.");
        records{end+1}=row; %#ok<AGROW>
        if mod(e,25)==0 || e==numel(data.evaluation),fprintf("AUDITORÍA %s: %d/%d episodios repetidos, coincidencia exacta estado/acción/PWM/q.\n",kind,e,numel(data.evaluation));end
    end
    assert(isequaln(before,getLearnableParameters(a.saved_actor)),"E3AX:AuditLearning","La auditoría no permite cambiar pesos.");
end
R=struct2table([records{:}]);writetable(R,fullfile(dest,"deterministic_replay.csv"));
audit=struct("result","PASS","episodesReplayed",height(R),"maxStateDiff",max(R.stateDiff),"maxRawDiff",max(R.rawDiff), ...
    "maxEffectiveDiff",max(R.effectiveDiff),"maxPwmDiff",max(R.pwmDiff),"maxQDiff",max(R.qDiff),"maxRewardDiff",max(R.rewardDiff), ...
    "maxMetricsCsvDiff",max(R.metricsCsvDiff),"metricsCsvTolerance",1e-9,"trainingExecuted",false,"finalTestExecuted",false,"MATEO_SANDRA_SEALED",true);
e3axVerifyHistory();e2cWriteJSON(fullfile(dest,"replay_summary.json"),audit);disp(audit);
end
function d=difference(a,b)
assert(isequal(size(a),size(b)),"E3AX:AuditShape","Longitud distinta en replay.");d=max(abs(a-b),[],'all');
end
function restore(p,r,o)
setConfigurablesOverride(o);rng(r);path(p);
end
