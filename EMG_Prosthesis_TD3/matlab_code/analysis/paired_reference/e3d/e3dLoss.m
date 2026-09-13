function [loss,g,parts]=e3dLoss(net,X,M,Y,labels)
[z,d,p]=e3dForward(net,X,M);lp=e3bCategoricalTerms(z,Y);a=-mean(lp)/4;b=ce(d,labels(1,:));c=ce(p,labels(2,:));
loss=a+b+c;parts=[a;b;c];g=dlgradient(loss,net.Learnables);
end
function v=ce(z,y)
z=z-max(z,[],1);logp=z-log(sum(exp(z),1));mask=zeros(size(z),'single');mask(sub2ind(size(mask),y,1:numel(y)))=1;
v=-mean(sum(logp.*mask,1));
end
