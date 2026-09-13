function [advantage,returns]=e3fGAE(reward,value,nextValue,done,gamma,lambda)
T=numel(reward);advantage=zeros(1,T);lastGae=0;
for t=T:-1:1
    if done(t)
        delta=reward(t)-value(t);lastGae=delta;
    else
        delta=reward(t)+gamma*nextValue(t)-value(t);lastGae=delta+gamma*lambda*lastGae;
    end
    advantage(t)=lastGae;
end
returns=advantage+value;
end
