function [logJoint,headEntropy,prob,logProb]=e3bCategoricalTerms(logits,categories)
% Softmax independiente por cabeza; logsumexp estable, sin producto numerico.
shift=logits-max(logits,[],1);logProb=shift-log(sum(exp(shift),1));prob=exp(logProb);
headEntropy=reshape(-sum(prob.*logProb,1),4,[]);
logJoint=[];
if ~isempty(categories)
    B=size(categories,2);mask=zeros(15,4,B,"like",extractdata(logits));
    for m=1:4,idx=sub2ind([15 4 B],categories(m,:),m*ones(1,B),1:B);mask(idx)=1;end
    logJoint=reshape(sum(sum(logProb.*mask,1),2),1,[]);
end
end
