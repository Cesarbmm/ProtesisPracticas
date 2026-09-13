function [X,Y]=e3cBatch(D,ids,kind,shuffled)
arguments,D;ids;kind;shuffled logical=false;end
x={};Y=zeros(4,numel(ids));len=D.samples.length(ids(1));
for j=1:numel(ids)
    s=D.samples(ids(j),:);seq=D.sequences{s.episode};assert(s.length==len);
    context=e3cContext(seq.state,s.step,8,shuffled,s.episode);if kind=="FF",context=context(:,end);end
    x{j}=single(context);Y(:,j)=seq.label(:,s.step); %#ok<AGROW>
end
if kind=="FF",X=dlarray(cat(2,x{:}),"CB");else,X=dlarray(cat(3,x{:}),"CTB");end
end
