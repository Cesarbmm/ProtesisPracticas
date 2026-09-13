function repaired=e3axRepairEpisodeFigures(out)
% Recupera únicamente PNG/FIG ausentes o ilegibles desde trazas guardadas.
repaired=0;
for kind=["best_checkpoint","last_checkpoint"]
    fprintf("TEST %s: comprobando figuras existentes y recuperando las que falten.\n",kind);
    folder=fullfile(out,"evaluation",kind);d=load(fullfile(folder,"metrics","trajectories.mat"),"traces");
    for i=1:numel(d.traces)
        t=d.traces{i};md=t.metadata;dirs=["closing","opening"];
        stem=string(md.subject)+compose("_row%04d_",md.repetition)+dirs(md.side);
        dest=fullfile(folder,"figures",md.split);png=fullfile(dest,stem+".png");fig=fullfile(dest,stem+".fig");
        valid=isfile(png) && isfile(fig);
        if valid
            try,imfinfo(png);v=whos('-file',fig);valid=~isempty(v);catch,valid=false;end
        end
        if ~valid,e3axPlotEpisode(t,dest,string(md.controller));repaired=repaired+1;end
        if mod(i,25)==0 || i==numel(d.traces),fprintf("TEST %s: figuras revisadas %d/%d.\n",kind,i,numel(d.traces));end
    end
end
end
