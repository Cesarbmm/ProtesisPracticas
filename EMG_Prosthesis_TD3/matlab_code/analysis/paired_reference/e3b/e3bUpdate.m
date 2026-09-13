function [actor,critic,opt,info]=e3bUpdate(actor,critic,opt,b,cfg)
[A,returns]=e3bGAE(b.reward,b.value,b.nextValue,b.done,cfg.gamma,cfg.gaeLambda);
adv=(A-mean(A))/max(std(A,1),1e-8);n=numel(A);rows={};headMax=zeros(1,4);
for epoch=1:cfg.epochs
    order=randperm(n);
    for start=1:cfg.minibatch:n
        ix=order(start:min(start+cfg.minibatch-1,n));
        [la,lv,ga,gv,st]=dlfeval(@e3bLoss,actor,critic,dlarray(single(b.state(:,ix)),"CB"),b.category(:,ix), ...
            dlarray(single(b.logp(ix))),dlarray(single(adv(ix))),dlarray(single(returns(ix))),cfg);
        [ga,na]=limit(ga,cfg.gradientLimit);[gv,nv]=limit(gv,cfg.gradientLimit);
        head=zeros(1,4);
        % Norma antes de clip (ga ya limitado; recuperar factor).
        for m=1:4
            values=ga.Value(ga.Layer=="head"+m);head(m)=sqrt(sum(cellfun(@(v) sum(double(extractdata(v)).^2,"all"),values)))*max(1,na/cfg.gradientLimit);
        end
        headMax=max(headMax,head);opt.iteration=opt.iteration+1;
        [actor,opt.actorAverage,opt.actorSquared]=adamupdate(actor,ga,opt.actorAverage,opt.actorSquared,opt.iteration,cfg.actorLR,cfg.adamBeta1,cfg.adamBeta2,cfg.adamEpsilon);
        [critic,opt.criticAverage,opt.criticSquared]=adamupdate(critic,gv,opt.criticAverage,opt.criticSquared,opt.iteration,cfg.criticLR,cfg.adamBeta1,cfg.adamBeta2,cfg.adamEpsilon);
        values=[double(extractdata(la)),double(extractdata(lv)),na,nv,double(extractdata(st.approxKL)),double(extractdata(st.clipFraction)),double(extractdata(st.maxRatio)),head];
        assert(all(isfinite(values)),"E3B:NonfiniteUpdate","No se permite NaN/Inf.");
        rows{end+1}=values; %#ok<AGROW>
    end
end
means=mean(vertcat(rows{:}),1);info=struct("actorLoss",means(1),"criticLoss",means(2),"actorGradient",means(3),"criticGradient",means(4), ...
    "approxKL",means(5),"clipFraction",means(6),"maxRatio",max(cellfun(@(r) r(7),rows)),"headGradientMax",headMax, ...
    "samples",n,"minibatches",numel(rows),"advantageMean",mean(adv),"advantageStd",std(adv,1),"allFinite",true);
end
function [g,n]=limit(g,bound)
n=sqrt(sum(cellfun(@(x) sum(double(extractdata(x)).^2,"all"),g.Value)));
assert(isfinite(n),"E3B:NonfiniteGradient","Gradientes no finitos.");
if n>bound,g=dlupdate(@(x) x*(bound/n),g);end
end
