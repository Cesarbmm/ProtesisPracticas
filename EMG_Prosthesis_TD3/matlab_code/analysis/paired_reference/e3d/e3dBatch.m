function [X,M,Y,labels]=e3dBatch(D,ids,kind,shuffled)
arguments,D;ids;kind;shuffled logical=false;end
x={};mechanical=zeros(12,numel(ids),'single');Y=zeros(4,numel(ids));labels=zeros(2,numel(ids));len=D.samples.length(ids(1));
for j=1:numel(ids)
    s=D.samples(ids(j),:);seq=D.sequences{s.episode};assert(s.length==len);
    [emg,m]=e3dContext(seq.state,s.step,shuffled,s.episode);if kind=="BASELINE",emg=emg(:,end);end
    x{j}=single(emg);mechanical(:,j)=single(m);Y(:,j)=seq.label(:,s.step);labels(:,j)=[s.side;s.phaseDirection]; %#ok<AGROW>
end
if kind=="BASELINE",X=dlarray(cat(2,x{:}),"CB");else,X=dlarray(cat(3,x{:}),"CTB");end
M=dlarray(mechanical,"CB");
end
