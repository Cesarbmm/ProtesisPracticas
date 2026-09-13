function file=e3dTrainProbe(D,cfg,kind,seed,o)
folder=fullfile(cfg.output,kind+"_"+seed);if ~isfolder(folder),mkdir(folder);mkdir(fullfile(folder,"checkpoints"));end
file=fullfile(folder,"checkpoints","ProbeEpoch040.mat");assert(~isfile(file),"E3D:ModelExists","No reentrenar/sobrescribir un probe existente.");
save(fullfile(folder,"config.mat"),"cfg","o");rng(seed,'twister');net=e3dNetwork(kind);initial=net;avg=[];avg2=[];iteration=0;logs={};
train=find(D.samples.split=="TRAIN");rng(seed+1000,'twister');plans=cell(cfg.supervisedEpochs,1);
for epoch=1:cfg.supervisedEpochs
    batches={};for len=1:cfg.L
        ids=train(D.samples.length(train)==len);ids=ids(randperm(numel(ids)));
        for k=1:cfg.supervisedBatch:numel(ids),batches{end+1}=ids(k:min(k+cfg.supervisedBatch-1,end));end %#ok<AGROW>
    end
    batches=batches(randperm(numel(batches)));plans{epoch}=batches;lossSum=0;partSum=zeros(3,1);seen=0;headMax=zeros(1,6);
    for batch=1:numel(batches)
        ids=batches{batch};assert(all(D.samples.split(ids)=="TRAIN"));[X,M,Y,labels]=e3dBatch(D,ids,kind);
        [loss,g,parts]=dlfeval(@e3dLoss,net,X,M,Y,labels);gn=sqrt(sum(cellfun(@(v) sum(double(extractdata(v)).^2,"all"),g.Value)));
        names=["head1","head2","head3","head4","direction","phase_direction"];
        for m=1:6,v=g.Value(g.Layer==names(m));headMax(m)=max(headMax(m),sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2,"all"),v))));end
        assert(isfinite(gn) && isfinite(extractdata(loss)));if gn>cfg.supervisedGradientLimit,g=dlupdate(@(v) v*(cfg.supervisedGradientLimit/gn),g);end
        iteration=iteration+1;[net,avg,avg2]=adamupdate(net,g,avg,avg2,iteration,cfg.supervisedLR,.9,.999,1e-8);
        lossSum=lossSum+double(extractdata(loss))*numel(ids);partSum=partSum+double(extractdata(parts))*numel(ids);seen=seen+numel(ids);
    end
    assert(seen==numel(train));logs{epoch}=struct("epoch",epoch,"trainLoss",lossSum/seen,"actionNLL",partSum(1)/seen,"directionNLL",partSum(2)/seen,"phaseDirectionNLL",partSum(3)/seen,"samples",seen,"updates",iteration,"headGradient",headMax);
    fprintf("E3D %s seed%d epoca%d/%d TRAIN loss %.6f.\n",kind,seed,epoch,cfg.supervisedEpochs,lossSum/seen);
    writetable(struct2table([logs{1:epoch}]),fullfile(folder,"training.csv"));
end
assert(~isequaln(initial.Learnables.Value,net.Learnables.Value));saved_actor=E3DProbeActor(net,kind);trainingLogs=struct2table([logs{:}]); %#ok<NASGU>
save(file,"saved_actor","net","initial","kind","seed","cfg","trainingLogs","plans","iteration","avg","avg2","-v7.3");
end
