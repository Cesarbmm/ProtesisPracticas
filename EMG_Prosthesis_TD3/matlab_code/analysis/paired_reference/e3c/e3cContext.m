function [x,indices]=e3cContext(states,k,L,shuffled,episode)
arguments,states double;k (1,1) double;L (1,1) double=8;shuffled logical=false;episode double=1;end
assert(size(states,1)==52 && k>=1 && k<=size(states,2) && L>=1);
indices=max(1,k-L+1):k;
if shuffled && numel(indices)>2
    old=rng;c=onCleanup(@() rng(old)); %#ok<NASGU>
    rng(20260921+100*episode+k,'twister');n=numel(indices)-1;order=randperm(n);
    if isequal(order,1:n),order=[2:n,1];end
    indices=[indices(order),k];
end
x=states(:,indices);assert(all(indices<=k));
end
