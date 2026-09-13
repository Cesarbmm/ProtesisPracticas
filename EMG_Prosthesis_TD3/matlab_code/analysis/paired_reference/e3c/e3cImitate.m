function [P,Y,H]=e3cImitate(net,kind,D,shuffled)
N=height(D.samples);P=zeros(15,4,N);Y=zeros(4,N);H=zeros(64,N);
for len=1:8
    ids=find(D.samples.length==len);
    for start=1:128:numel(ids)
        ix=ids(start:min(start+127,end));[X,y]=e3cBatch(D,ix,kind,shuffled);
        [z,h]=e3cForward(net,X);[~,~,p]=e3bCategoricalTerms(z,[]);
        P(:,:,ix)=double(extractdata(p));Y(:,ix)=y;H(:,ix)=double(extractdata(h));
    end
end
assert(all(isfinite(P),"all") && all(Y>=1 & Y<=15,"all"));
end
