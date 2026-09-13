function file=e3cTrainProbe(D,cfg,kind,seed,o)
folder=fullfile(cfg.output,kind+"_"+seed);if ~isfolder(folder),mkdir(folder);mkdir(fullfile(folder,"checkpoints"));end
file=fullfile(folder,"checkpoints","ProbeEpoch040.mat");assert(~isfile(file),"E3C:ModelExists","No reentrenar/sobrescribir un probe existente.");
save(fullfile(folder,"config.mat"),"cfg","o");rng(seed,'twister');net=e3cNetwork(kind);initial=net;avg=[];avg2=[];iteration=0;logs={};
train=find(D.samples.split=="TRAIN");rng(seed+1000,'twister');plans=cell(cfg.supervisedEpochs,1);
for epoch=1:cfg.supervisedEpochs
    batches={};for len=1:cfg.L
        ids=train(D.samples.length(train)==len);ids=ids(randperm(numel(ids)));
        for k=1:cfg.supervisedBatch:numel(ids),batches{end+1}=ids(k:min(k+cfg.supervisedBatch-1,end));end %#ok<AGROW>
    end
    batches=batches(randperm(numel(batches)));plans{epoch}=batches;lossSum=0;seen=0;headMax=zeros(1,4);
    for batch=1:numel(batches)
        ids=batches{batch};assert(all(D.samples.split(ids)=="TRAIN"));[X,Y]=e3cBatch(D,ids,kind);
        [loss,g]=dlfeval(@lossGrad,net,X,Y);gn=sqrt(sum(cellfun(@(v) sum(double(extractdata(v)).^2,"all"),g.Value)));
        for m=1:4,v=g.Value(g.Layer=="head"+m);headMax(m)=max(headMax(m),sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2,"all"),v))));end
        assert(isfinite(gn) && isfinite(extractdata(loss)));if gn>cfg.supervisedGradientLimit,g=dlupdate(@(v) v*(cfg.supervisedGradientLimit/gn),g);end
        iteration=iteration+1;[net,avg,avg2]=adamupdate(net,g,avg,avg2,iteration,cfg.supervisedLR,.9,.999,1e-8);
        lossSum=lossSum+double(extractdata(loss))*numel(ids);seen=seen+numel(ids);
    end
    assert(seen==numel(train));logs{epoch}=struct("epoch",epoch,"trainNLL",lossSum/seen,"samples",seen,"updates",iteration,"headGradient",headMax);
    fprintf("E3C %s seed%d epoca%d/%d TRAIN NLL %.6f.\n",kind,seed,epoch,cfg.supervisedEpochs,lossSum/seen);
    writetable(struct2table([logs{1:epoch}]),fullfile(folder,"training.csv"));
end
assert(~isequaln(initial.Learnables.Value,net.Learnables.Value));saved_actor=E3CProbeActor(net,kind,cfg.L);trainingLogs=struct2table([logs{:}]); %#ok<NASGU>
save(file,"saved_actor","net","initial","kind","seed","cfg","trainingLogs","plans","iteration","avg","avg2","-v7.3");
end
function [loss,g]=lossGrad(net,X,Y)
z=e3cForward(net,X);lp=e3bCategoricalTerms(z,Y);loss=-mean(lp)/4;g=dlgradient(loss,net.Learnables);
end
