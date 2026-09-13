function audit=e3fLatentAudit(actor,out,dataPath)
arguments
    actor
    out (1,1) string
    dataPath (1,1) string = ""
end
if dataPath == ""
    cfg=e3fConfig();
    dataPath=fullfile(cfg.root,"analysis","paired_reference","e3c_results","supervised_data.mat");
end
d=load(dataPath,"D");D=d.D;S=D.samples;
N_total=height(S);
Z=zeros(64,N_total,"single");
for e=1:200
    epIx=find(S.episode==e);
    states=D.sequences{e}.state;
    emg=states(1:40,:);
    mech=states(41:52,:);
    [z,~]=forward(actor,dlarray(single(emg),"CB"),dlarray(single(mech),"CB"),Outputs=["emg_latent","head1"]);
    Z(:,epIx)=single(extractdata(z));
end

% 1. Subject-ID Probe sobre TRAIN (5-fold CV)
trainMask=(S.split=="TRAIN");
S_train=S(trainMask,:);
Z_train=Z(:,trainMask);
trainSubjects=["BLANCA","CECILIA","DENIS","EMILIA","GABI","GABRIEL","IVANNA"];
K=numel(trainSubjects);
y_sub=zeros(1,height(S_train),"int32");
for k=1:K,y_sub(S_train.subject==trainSubjects(k))=k;end

uniqueEps=unique(S_train.episode);
epSub=strings(numel(uniqueEps),1);
for i=1:numel(uniqueEps),epSub(i)=S_train.subject(find(S_train.episode==uniqueEps(i),1));end

rng(20260923);
folds=zeros(numel(uniqueEps),1);
for k=1:K
    subEps=find(epSub==trainSubjects(k));
    p=randperm(numel(subEps));
    for fold=1:5
        idxInSub=p((fold-1)*4+1:fold*4);
        folds(subEps(idxInSub))=fold;
    end
end
sampleFold=zeros(height(S_train),1);
for i=1:numel(uniqueEps),sampleFold(S_train.episode==uniqueEps(i))=folds(i);end

oof_preds=zeros(1,height(S_train));
for fold=1:5
    trIdx=find(sampleFold~=fold);vaIdx=find(sampleFold==fold);
    X_tr=dlarray(Z_train(:,trIdx));y_tr=y_sub(trIdx);
    X_va=dlarray(Z_train(:,vaIdx));
    rng(20260923+fold);
    W=dlarray(randn(K,64,"single")*0.01);b=dlarray(zeros(K,1,"single"));
    lr=0.01;bs=64;nB=ceil(numel(trIdx)/bs);
    avgW=[];avgWsq=[];avgb=[];avgbsq=[];
    for epoch=1:40
        p=randperm(numel(trIdx));
        for b_idx=1:nB
            sel=p((b_idx-1)*bs+1:min(b_idx*bs,numel(trIdx)));
            [~,gW,gb]=dlfeval(@subLoss,W,b,X_tr(:,sel),y_tr(sel));
            [W,avgW,avgWsq]=adamupdate(W,gW,avgW,avgWsq,(epoch-1)*nB+b_idx,lr);
            [b,avgb,avgbsq]=adamupdate(b,gb,avgb,avgbsq,(epoch-1)*nB+b_idx,lr);
        end
    end
    [~,pred_va]=max(extractdata(W*X_va+b),[],1);
    oof_preds(vaIdx)=pred_va;
end
cm_sub=accumarray([double(y_sub)',oof_preds'],1,[K K]);
f1_sub=zeros(K,1);
for k=1:K
    den=sum(cm_sub(k,:))+sum(cm_sub(:,k));
    if den>0,f1_sub(k)=2*cm_sub(k,k)/den;end
end
latentSubjectAccuracy=mean(oof_preds==double(y_sub));
latentSubjectMacroF1=mean(f1_sub);

% 2. Intent Probe: Direction (TRAIN -> VAL)
valMask=(S.split=="VALIDATION");
S_val=S(valMask,:);
Z_val=Z(:,valMask);
y_dir_tr=int32(S_train.side);
y_dir_va=int32(S_val.side);

rng(20260924);
W_dir=dlarray(randn(2,64,"single")*0.01);b_dir=dlarray(zeros(2,1,"single"));
avgW=[];avgWsq=[];avgb=[];avgbsq=[];
bs=64;nB=ceil(height(S_train)/bs);
for epoch=1:30
    p=randperm(height(S_train));
    for b_idx=1:nB
        sel=p((b_idx-1)*bs+1:min(b_idx*bs,height(S_train)));
        [~,gW,gb]=dlfeval(@subLoss,W_dir,b_dir,dlarray(Z_train(:,sel)),y_dir_tr(sel));
        [W_dir,avgW,avgWsq]=adamupdate(W_dir,gW,avgW,avgWsq,(epoch-1)*nB+b_idx,0.01);
        [b_dir,avgb,avgbsq]=adamupdate(b_dir,gb,avgb,avgbsq,(epoch-1)*nB+b_idx,0.01);
    end
end
[~,pred_dir]=max(extractdata(W_dir*dlarray(Z_val)+b_dir),[],1);
cm_dir=accumarray([double(y_dir_va),pred_dir'],1,[2 2]);
f1_dir=zeros(2,1);
for k=1:2
    den=sum(cm_dir(k,:))+sum(cm_dir(:,k));if den>0,f1_dir(k)=2*cm_dir(k,k)/den;end
end
directionMacroF1=mean(f1_dir);

% 3. Intent Probe: Phase-Direction (6 classes, TRAIN -> VAL)
y_ph_tr=int32(S_train.phaseDirection);
y_ph_va=int32(S_val.phaseDirection);
rng(20260925);
W_ph=dlarray(randn(6,64,"single")*0.01);b_ph=dlarray(zeros(6,1,"single"));
avgW=[];avgWsq=[];avgb=[];avgbsq=[];
for epoch=1:30
    p=randperm(height(S_train));
    for b_idx=1:nB
        sel=p((b_idx-1)*bs+1:min(b_idx*bs,height(S_train)));
        [~,gW,gb]=dlfeval(@subLoss,W_ph,b_ph,dlarray(Z_train(:,sel)),y_ph_tr(sel));
        [W_ph,avgW,avgWsq]=adamupdate(W_ph,gW,avgW,avgWsq,(epoch-1)*nB+b_idx,0.01);
        [b_ph,avgb,avgbsq]=adamupdate(b_ph,gb,avgb,avgbsq,(epoch-1)*nB+b_idx,0.01);
    end
end
[~,pred_ph]=max(extractdata(W_ph*dlarray(Z_val)+b_ph),[],1);
cm_ph=accumarray([double(y_ph_va),pred_ph'],1,[6 6]);
f1_ph=zeros(6,1);
for k=1:6
    den=sum(cm_ph(k,:))+sum(cm_ph(:,k));if den>0,f1_ph(k)=2*cm_ph(k,k)/den;end
end
phaseDirectionMacroF1=mean(f1_ph);

audit=struct();
audit.baselineSubjectIDAccuracy=0.7914;
audit.baselineSubjectIDMacroF1=0.7845;
audit.baselineDirectionF1=0.810528;
audit.baselinePhaseDirectionF1=0.510308;

audit.latentSubjectIDAccuracy=latentSubjectAccuracy;
audit.latentSubjectIDMacroF1=latentSubjectMacroF1;
audit.directionMacroF1=directionMacroF1;
audit.phaseDirectionMacroF1=phaseDirectionMacroF1;

audit.subjectInvarianceSupported=(latentSubjectAccuracy<=0.80*audit.baselineSubjectIDAccuracy);
audit.directionRetentionSupported=(directionMacroF1>=audit.baselineDirectionF1-0.02);
audit.phaseDirectionRetentionSupported=(phaseDirectionMacroF1>=audit.baselinePhaseDirectionF1-0.03);

e2cWriteJSON(fullfile(out,"latent_audit.json"),audit);
save(fullfile(out,"latent_features.mat"),"Z","audit","-v7.3");
end

function [loss,gW,gb]=subLoss(W,b,X,y)
logits=W*X+b;
shift=logits-max(logits,[],1);
logProb=shift-log(sum(exp(shift),1));
idx=sub2ind(size(logits),reshape(y,1,[]),1:numel(y));
loss=-mean(logProb(idx),"all");
[gW,gb]=dlgradient(loss,W,b);
end
