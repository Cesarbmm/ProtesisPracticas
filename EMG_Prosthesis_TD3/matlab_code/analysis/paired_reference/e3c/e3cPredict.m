function [p,h,latent]=e3cPredict(net,kind,x)
if kind=="FF",X=dlarray(reshape(single(x(:,end,:)),52,[]),"CB");else,X=dlarray(single(x),"CTB");end
[z,latent]=e3cForward(net,X);[~,hd,pd]=e3bCategoricalTerms(z,[]);
p=double(extractdata(pd));h=double(extractdata(hd));latent=double(extractdata(latent));
assert(all(isfinite(p),"all") && all(isfinite(h),"all"));
end
