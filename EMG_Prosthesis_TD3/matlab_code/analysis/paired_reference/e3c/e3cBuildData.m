function D=e3cBuildData(cfg)
% Reconstruccion de estados Oracle anteriores a sus acciones; labels aparte.
data=e3axLoadData(cfg,cfg.output);O=load(fullfile(cfg.root,"analysis","paired_reference","e2f_results","trajectories.mat"),"trajectories");
episodes=data.evaluation;S={};seqs=cell(200,1);categories=cfg.categories;
for e=1:200
    oracle=O.trajectories{e,7};base=episodes{e}.base;assert(isequal(oracle.metadata.subject,base.metadata.subject) && oracle.metadata.repetition==base.metadata.repetition && oracle.metadata.side==base.metadata.side);
    rt=GloveFreePolicyRuntime(episodes{e}.emg,oracle.q(1,:),purpose="inference");N=size(oracle.pwm,1);states=zeros(52,N);labels=zeros(4,N);
    for k=1:N
        states(:,k)=rt.state;[ok,c]=ismember(oracle.pwm(k,:),categories);assert(all(ok));labels(:,k)=c';
        [next,~,record]=rt.advance(oracle.pwm(k,:)'/255);
        assert(isequal(record.q,oracle.q(k+1,:)) && isequal(next(49:52),oracle.pwm(k,:)'/255),"E3C:OracleReconstruction");
        phase=min(3,1+floor(3*(k-1)/N));md=base.metadata;
        S{end+1}=struct("episode",e,"step",k,"length",min(k,cfg.L),"subject",string(md.subject),"row",md.repetition,"side",md.side, ...
            "split",episodes{e}.split,"phase",phase,"phaseDirection",phase+3*(md.side-1)); %#ok<AGROW>
    end
    seqs{e}=struct("state",states,"label",labels);
end
samples=struct2table([S{:}]);writetable(samples,fullfile(cfg.output,"sample_inventory.csv"));
D=struct("episodes",{episodes},"sequences",{seqs},"samples",samples);save(fullfile(cfg.output,"supervised_data.mat"),"D","-v7.3");
fprintf("E3C datos: %d estados causales; %d TRAIN, %d VALIDATION.\n",height(samples),nnz(samples.split=="TRAIN"),nnz(samples.split=="VALIDATION"));
end
