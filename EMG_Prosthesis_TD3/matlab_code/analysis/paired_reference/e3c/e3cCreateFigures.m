function e3cCreateFigures(file,D,cfg)
folder=fileparts(fileparts(file));a=load(file,"kind","seed");d=load(fullfile(folder,"closed_loop.mat"));label=a.kind+" PROBE | seed"+a.seed;
for e=1:200
    t=d.traces{e};target=fullfile(folder,"figures",D.episodes{e}.split);stem=stemOf(t);
    if ~isfile(fullfile(target,stem+".png")) || ~isfile(fullfile(target,stem+".fig")),e3axPlotEpisode(t,target,label);end
    if mod(e,25)==0,fprintf("COMPACTAS %s: %d/200.\n",label,e);end
end
if a.kind~="GRU" || a.seed~=cfg.seeds(1),return;end
FF=load(fullfile(cfg.output,"FF_"+cfg.seeds(1),"closed_loop.mat"));
old=load(fullfile(cfg.e3bRun,"evaluation","best_checkpoint","metrics","trajectories.mat"));
checkpoint=fullfile(cfg.e3bRun,"checkpoints","CategoricalStep000500000.mat");b=load(checkpoint,"saved_actor");
selection=readtable(fullfile(cfg.output,"diagnostic_selection.csv"),TextType="string",Delimiter=",");dirs=["closing","opening"];
for i=1:height(selection)
    s=selection(i,:);e=find(cellfun(@(t) string(t.metadata.subject)==s.subject && t.metadata.repetition==s.row && t.metadata.side==s.side,d.traces));assert(isscalar(e));
    t=old.traces{e};n=size(t.pwm,1);[p,h]=b.saved_actor.distribution(old.runtimeTraces{e}.state(1:n,:)');[~,cats]=max(p,[],1);t.categories=reshape(cats,4,[]);t.probabilities=p;t.headEntropy=h;
    e3cPlotAnnotatedEpisode(FF.traces{e},d.traces{e},fullfile(cfg.output,"annotated","FF_vs_GRU"),["FF PROBE seed20260912","GRU PROBE seed20260912"]);
    e3cPlotAnnotatedEpisode(t,d.traces{e},fullfile(cfg.output,"annotated","E3B_vs_GRU"),["E3B CATEGORICAL BEST500k","GRU PROBE seed20260912"]);
    files=[checkpoint,fullfile(cfg.output,"FF_"+cfg.seeds(1),"checkpoints","ProbeEpoch040.mat"),file];policies=["E3B_CATEGORICAL_BEST","FF_PROBE","GRU_PROBE"];
    expected={old.runtimeTraces{e},FF.runtimeTraces{e},d.runtimeTraces{e}};
    for j=1:3
        viewer=fullfile(cfg.output,"viewer",policies(j),stemOf(t),"viewer_trace.mat");
        if ~isfile(viewer),v=exportE3AXViewerTrace(files(j),s.subject,s.row,dirs(s.side),viewer);else,v=load(viewer);end
        assert(isequal(v.q,expected{j}.q) && isequal(v.PWM,expected{j}.pwm) && ~v.teacherLoaded && ~v.trainingExecuted,"E3C:ViewerMismatch");
    end
end
end
function stem=stemOf(t)
directions=["closing","opening"];md=t.metadata;stem=string(md.subject)+compose("_row%04d_",md.repetition)+directions(md.side);
end
