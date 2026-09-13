function [P,Y,dir,phase]=e3dImitate(net,kind,D,shuffled)
N=height(D.samples);P=zeros(15,4,N);Y=zeros(4,N);dir=zeros(2,N);phase=zeros(6,N);
for len=1:8
    ids=find(D.samples.length==len);
    for start=1:128:numel(ids)
        ix=ids(start:min(start+127,end));[X,M,y]=e3dBatch(D,ix,kind,shuffled);[z,d,f]=e3dForward(net,X,M);[~,~,p]=e3bCategoricalTerms(z,[]);
        P(:,:,ix)=double(extractdata(p));Y(:,ix)=y;dir(:,ix)=soft(d);phase(:,ix)=soft(f);
    end
end
assert(all(isfinite(P),"all") && all(isfinite(dir),"all") && all(isfinite(phase),"all"));
end
function p=soft(z),z=double(extractdata(z));z=z-max(z,[],1);p=exp(z)./sum(exp(z),1);end
