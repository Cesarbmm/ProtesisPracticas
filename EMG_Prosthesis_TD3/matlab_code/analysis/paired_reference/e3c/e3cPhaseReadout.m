function [net,T]=e3cPhaseReadout(H,S,cfg,seed)
% Diagnostico lineal de representacion congelada: ningun gradiente al actor.
rng(seed+500,'twister');net=dlnetwork([featureInputLayer(64,Normalization="none",Name="latent");fullyConnectedLayer(6,Name="phase")]);
train=find(S.split=="TRAIN");avg=[];avg2=[];it=0;
for epoch=1:cfg.phaseEpochs
    ids=train(randperm(numel(train)));
    for start=1:cfg.supervisedBatch:numel(ids)
        ix=ids(start:min(start+cfg.supervisedBatch-1,end));X=dlarray(single(H(:,ix)),"CB");y=S.phaseDirection(ix)';
        [~,g]=dlfeval(@lossGradient,net,X,y);it=it+1;[net,avg,avg2]=adamupdate(net,g,avg,avg2,it,cfg.supervisedLR,.9,.999,1e-8);
    end
end
z=double(extractdata(forward(net,dlarray(single(H),"CB"))));z=z-max(z,[],1);p=exp(z)./sum(exp(z),1);rows={};
for split=["TRAIN","VALIDATION"]
    ix=find(S.split==split);
    for task=["phase_direction","phase","direction"]
        prob=p(:,ix);y=S.phaseDirection(ix)';classes=6;
        if task=="phase",prob=prob(1:3,:)+prob(4:6,:);y=S.phase(ix)';classes=3;
        elseif task=="direction",prob=[sum(prob(1:3,:),1);sum(prob(4:6,:),1)];y=S.side(ix)';classes=2;end
        [~,pred]=max(prob,[],1);cm=accumarray([y',pred'],1,[classes,classes]);f1=zeros(classes,1);
        for k=1:classes,den=sum(cm(k,:))+sum(cm(:,k));if den>0,f1(k)=2*cm(k,k)/den;end;end
        selected=prob(sub2ind(size(prob),y,1:numel(y)));
        rows{end+1}=struct("split",split,"task",task,"samples",numel(ix),"accuracy",mean(pred==y),"macroF1",mean(f1),"NLL",mean(-log(max(selected,realmin)))); %#ok<AGROW>
    end
end
T=struct2table([rows{:}]);
end
function [loss,g]=lossGradient(net,X,Y)
z=stripdims(forward(net,X));shift=z-max(z,[],1);lp=shift-log(sum(exp(shift),1));mask=zeros(size(z),'single');mask(sub2ind(size(mask),Y,1:numel(Y)))=1;
loss=-mean(sum(lp.*mask,1));g=dlgradient(loss,net.Learnables);
end
