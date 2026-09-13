function [category,logp,entropy]=e3bSample(actor,state)
p=E3BCategoricalActor(actor);[prob,entropy]=p.distribution(state);category=zeros(4,1);
for m=1:4
    c=cumsum(prob(:,m));c(end)=1;category(m)=find(rand<=c,1);
end
z=e3bLogits(actor,dlarray(single(state),"CB"));lp=e3bCategoricalTerms(z,category);logp=double(extractdata(lp));
assert(isfinite(logp),"E3B:LogProbability","Log probabilidad no finita.");
end
