function [lossA,lossV,lossD,gradA,gradV,gradD,stats]=e3fLoss(actor,critic,disc,states,subjects,categories,oldLogP,advantage,returns,cfg)
% Forward actor
[logits,latent]=e3fLogits(actor,states);
[lp,entropy]=e3fCategoricalTerms(logits,categories);
ratio=exp(lp-oldLogP);clipped=min(1+cfg.clip,max(1-cfg.clip,ratio));
lossA=-mean(min(ratio.*advantage,clipped.*advantage),"all")-cfg.entropyWeight*mean(sum(entropy,1),"all");

% Forward critic
v=reshape(stripdims(forward(critic,states)),1,[]);
lossV=0.5*mean((v-returns).^2,"all");

% Forward discriminator (GRL is inside discriminator)
disc_logits=forward(disc,latent);
shift=disc_logits-max(disc_logits,[],1);
logProbSub=shift-log(sum(exp(shift),1));
B=numel(subjects);
idxSub=sub2ind(size(disc_logits),reshape(subjects,1,[]),1:B);
lossD=-mean(logProbSub(idxSub),"all");

[~,predSub]=max(disc_logits,[],1);
subAcc=mean(extractdata(predSub)==reshape(subjects,1,[]));

% Gradient total
[gradA,gradV,gradD]=dlgradient(lossA+lossV+lossD,actor.Learnables,critic.Learnables,disc.Learnables);

% Gradientes descompuestos para diagnostico de encoders
gradPPO=dlgradient(lossA,actor.Learnables);
gradAdv=dlgradient(lossD,actor.Learnables);
encMask=ismember(actor.Learnables.Layer,["emg_fc1","emg_fc2"]);
normPpo=sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2,"all"),gradPPO.Value(encMask))));
normAdv=sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2,"all"),gradAdv.Value(encMask))));

stats=struct("headEntropy",mean(entropy,2),"approxKL",mean(oldLogP-lp,"all"), ...
    "clipFraction",mean(abs(ratio-1)>cfg.clip,"all"),"maxRatio",max(ratio,[],"all"), ...
    "subjectLoss",double(extractdata(lossD)),"subjectAccuracy",subAcc, ...
    "normPpoEncoder",normPpo,"normAdvEncoder",normAdv);
end
