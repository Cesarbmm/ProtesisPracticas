function [advantage,returns]=e3bGAE(reward,value,nextValue,done,gamma,lambda)
% done es terminal teacher real. Corte de rollout NO es terminal.
reward=double(reward(:)');value=double(value(:)');nextValue=double(nextValue(:)');done=logical(done(:)');
assert(isequal(size(reward),size(value),size(nextValue),size(done)));
advantage=zeros(size(reward));carry=0;
for k=numel(reward):-1:1
    delta=reward(k)+gamma*(~done(k))*nextValue(k)-value(k);
    carry=delta+gamma*lambda*(~done(k))*carry;advantage(k)=carry;
end
returns=advantage+value;
end
