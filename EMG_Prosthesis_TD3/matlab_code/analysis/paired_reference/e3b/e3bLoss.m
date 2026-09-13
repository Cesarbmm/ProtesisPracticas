function [lossA,lossV,gradA,gradV,stats]=e3bLoss(actor,critic,states,categories,oldLogP,advantage,returns,cfg)
logits=e3bLogits(actor,states);[lp,entropy]=e3bCategoricalTerms(logits,categories);
ratio=exp(lp-oldLogP);clipped=min(1+cfg.clip,max(1-cfg.clip,ratio));
lossA=-mean(min(ratio.*advantage,clipped.*advantage),"all")-cfg.entropyWeight*mean(sum(entropy,1),"all");
v=reshape(stripdims(forward(critic,states)),1,[]);
lossV=.5*mean((v-returns).^2,"all");
[gradA,gradV]=dlgradient(lossA+lossV,actor.Learnables,critic.Learnables);
stats=struct("headEntropy",mean(entropy,2),"approxKL",mean(oldLogP-lp,"all"), ...
    "clipFraction",mean(abs(ratio-1)>cfg.clip,"all"),"maxRatio",max(ratio,[],"all"));
end
