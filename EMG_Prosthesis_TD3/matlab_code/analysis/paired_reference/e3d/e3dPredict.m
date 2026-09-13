function [p,h,dir,phase]=e3dPredict(net,kind,emg,mechanical)
assert(size(emg,1)==40 && size(mechanical,1)==12);
if kind=="BASELINE",X=dlarray(single(emg(:,end)),"CB");else,X=dlarray(single(emg),"CTB");end
[z,d,f]=e3dForward(net,X,dlarray(single(mechanical),"CB"));[~,en,prob]=e3bCategoricalTerms(z,[]);
p=double(extractdata(prob));h=reshape(double(extractdata(en)),4,[]);dir=soft(d);phase=soft(f);
end
function p=soft(z),z=double(extractdata(z));z=z-max(z,[],1);p=exp(z)./sum(exp(z),1);end
