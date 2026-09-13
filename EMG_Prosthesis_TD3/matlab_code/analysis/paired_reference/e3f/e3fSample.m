function [category,logp,entropy]=e3fSample(actor,state)
p=E3FActor(actor);[prob,entropy]=p.distribution(state);category=zeros(4,1);
for m=1:4
    c=cumsum(prob(:,m));c(end)=1;category(m)=find(rand<=c,1);
end
[logits,~]=e3fLogits(actor,state);
[lp,~]=e3fCategoricalTerms(logits,category);
logp=double(extractdata(lp));
assert(isfinite(logp),"E3F:LogProbability","Log probabilidad no finita.");
end
