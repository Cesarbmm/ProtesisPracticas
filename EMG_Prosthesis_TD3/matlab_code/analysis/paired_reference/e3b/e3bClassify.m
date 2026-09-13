function s=e3bClassify(R,cfg)
% Clasificacion cientifica solo al completar el presupuesto largo.
R=sortrows(R,["mse","reward","steps"],["ascend","descend","ascend"]);best=R(1,:);
complete=cfg.mode=="long" && any(R.steps==cfg.maxAgentSteps);
s=struct("classification","SMOKE_INFRASTRUCTURE_ONLY","continueTo5M",false,"massiveTrainingJustified",false,"bestSteps",best.steps);
if ~complete,s.classification="BUDGET_NOT_COMPLETED";if cfg.mode=="smoke",s.classification="SMOKE_INFRASTRUCTURE_ONLY";end;return;end
good=@(r) all(r.m3Reversals==0 & r.cycles==0 & r.periodic==0 & r.maxCategoryFraction<=cfg.maxCategoryFraction);
if best.mse<cfg.strongMSE && good(best),s.classification="CAT_STRONG_SIGNAL";
elseif best.mse<cfg.learningMSE && good(best),s.classification="CAT_LEARNING_SIGNAL";
elseif best.mse<cfg.learningMSE,s.classification="SIGNAL_WITH_PATHOLOGY";
else,s.classification="NO_LEARNING";end
trend=sortrows(R(ismember(R.steps,[500000 750000 1000000]),:),"steps");
if height(trend)==3
    s.continueTo5M=trend.mse(end)<cfg.strongMSE && good(trend) && all(diff(trend.mse)<=0) && any(diff(trend.mse)<0);
end
end
