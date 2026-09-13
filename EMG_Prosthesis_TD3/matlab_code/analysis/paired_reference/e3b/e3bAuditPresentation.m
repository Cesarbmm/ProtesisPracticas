function audit=e3bAuditPresentation(out)
% Contrasta los datos de los 400 FIG sin abrir 400 ventanas.
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
dest=fullfile(root,"analysis","paired_reference","e3b_run_audit");out=string(out);
V=readtable(fullfile(dest,"verified_figures.csv"),TextType="string",Delimiter=",");
rows={};maxFigureDiff=0;directions=["closing","opening"];
for kind=["best_checkpoint","last_checkpoint"]
    d=load(fullfile(out,"evaluation",kind,"metrics","trajectories.mat"),"traces");
    T=V(V.checkpoint==kind,:);
    for i=1:height(T)
        ix=find(cellfun(@(t) string(t.metadata.subject)==T.subject(i) && t.metadata.repetition==T.row(i) && ...
            directions(t.metadata.side)==T.direction(i),d.traces));
        assert(isscalar(ix));t=d.traces{ix};fig=openfig(fullfile(out,T.fig(i)),"invisible");
        figCleanup=onCleanup(@() close(fig));
        ax=findall(fig,Type="axes");assert(numel(ax)==4);
        pred=cell(1,4);ref=cell(1,4);
        for ai=1:4
            pl=findall(ax(ai),Tag="prediction");rl=findall(ax(ai),Tag="reference");assert(numel(pl)==1 && numel(rl)==1);
            pred{ai}=pl.YData;ref{ai}=rl.YData;
        end
        expectedPred=num2cell(t.prediction,1);expectedRef=num2cell(t.reference,1);
        remaining=true(1,4);diffMax=0;
        for j=1:4
            candidates=inf(1,4);
            for m=find(remaining)
                if numel(pred{j})==numel(expectedPred{m}) && numel(ref{j})==numel(expectedRef{m})
                    candidates(m)=max(abs([pred{j}(:)-expectedPred{m}(:);ref{j}(:)-expectedRef{m}(:)]));
                end
            end
            [err,m]=min(candidates);assert(err==0,"E3B:FigureDataMismatch","Curvas FIG distintas a las trazas: %s",T.fig(i));
            remaining(m)=false;diffMax=max(diffMax,err);
        end
        maxFigureDiff=max(maxFigureDiff,diffMax);row=table2struct(T(i,:));row.curves=8;row.dataDiff=diffMax;rows{end+1}=row; %#ok<AGROW>
        clear figCleanup;
        if mod(i,25)==0,fprintf("FIG %s: %d/%d datos verificados.\n",kind,i,height(T));end
    end
    fprintf("FIG %s: %d archivos; ocho curvas por archivo identicas a MAT.\n",kind,height(T));
end
writetable(struct2table([rows{:}]),fullfile(dest,"figure_data_audit.csv"));
R=readtable(fullfile(out,"checkpoint_validation.csv"),TextType="string",Delimiter=",");
f=figure(Visible="off",Color="w",Position=[80 80 1200 840]);c=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(f,2,2,TileSpacing="compact",Padding="compact");
nexttile;plot(R.steps,R.mse,'-o',LineWidth=1.5);hold on;
yline(.0599808451870524,'--',"TD3 BEST");yline(.0515979622859728,':',"Agent7250");
title("VALIDATION: MSE; menor es mejor");xlabel("Agent steps");ylabel("MSE");grid on;
nexttile;plot(R.steps,R.reward,'-o',LineWidth=1.5);hold on;
yline(-.0756162096635791,'--',"TD3 BEST");yline(-.0641986312096749,':',"Agent7250");
title("VALIDATION: reward; mayor es mejor");xlabel("Agent steps");ylabel("Reward medio");grid on;
nexttile;plot(R.steps,R.m3Reversals,'-o',R.steps,R.cycles,'-s',LineWidth=1.5);
legend("Retrocesos M3","Ciclos finales",Location="best");title("Conteos en 60 episodios VALIDATION");xlabel("Agent steps");ylabel("Eventos");grid on;
nexttile;plot(R.steps,R.maxCategoryFraction,'-o',LineWidth=1.5);hold on;yline(.9,'--',"Limite preregistrado");
ylim([0 1]);title("Maxima fraccion de una categoria por motor");xlabel("Agent steps");ylabel("Fraccion");grid on;
sgtitle("E3B: mejor checkpoint 500k; validacion empeora despues");
exportgraphics(f,fullfile(dest,"checkpoint_audit.png"),Resolution=160);
exportgraphics(f,fullfile(dest,"checkpoint_audit.pdf"),ContentType="vector");savefig(f,fullfile(dest,"checkpoint_audit.fig"));
audit=struct("result","PASS","figuresAudited",height(V),"curvesAudited",height(V)*8,"maxCurveDataDiff",maxFigureDiff);
e2cWriteJSON(fullfile(dest,"presentation_summary.json"),audit);
end
