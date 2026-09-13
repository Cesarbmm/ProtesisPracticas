function inventory=e3axCheckEvaluationFiles(out)
% Gate de cierre: todos los episodios esperados tienen métricas y PNG/FIG.
selection=readtable(fullfile(out,"evaluation_selection.csv"),TextType="string",Delimiter=",");
assert(~any(ismember(selection.subject,["MATEO","SANDRA"])),"E3AX:SealedSubject","El test final sigue sellado.");
rows={};directions=["closing","opening"];
for kind=["best_checkpoint","last_checkpoint"]
    fprintf("TEST %s: verificando cobertura y archivos PNG/FIG.\n",kind);
    folder=fullfile(out,"evaluation",kind);
    E=readtable(fullfile(folder,"metrics","episode_metrics.csv"),TextType="string",Delimiter=",");
    assert(height(E)==height(selection),"E3AX:EvaluationIncomplete","Faltan métricas de episodios en %s.",kind);
    assert(numel(dir(fullfile(folder,"figures","**","*.png")))==height(selection) && ...
        numel(dir(fullfile(folder,"figures","**","*.fig")))==height(selection),"E3AX:FigureCount","Número de figuras incorrecto en %s.",kind);
    for i=1:height(selection)
        s=selection(i,:);idx=E.subject==s.subject & E.repetition==s.row & E.side==s.side;
        assert(nnz(idx)==1,"E3AX:EpisodeMismatch","Episodio ausente o duplicado: %s fila%d.",s.subject,s.row);
        stem=s.subject+compose("_row%04d_",s.row)+directions(s.side);
        png=fullfile("evaluation",kind,"figures",s.split,stem+".png");fig=fullfile("evaluation",kind,"figures",s.split,stem+".fig");
        assert(isfile(fullfile(out,png)) && isfile(fullfile(out,fig)),"E3AX:EpisodeFigureMissing","Falta PNG o FIG de %s.",stem);
        imageInfo=imfinfo(fullfile(out,png));figVars=whos('-file',fullfile(out,fig));
        assert(imageInfo.Width>0 && imageInfo.Height>0 && ~isempty(figVars),"E3AX:InvalidEpisodeFigure","Figura inválida: %s.",stem);
        rows{end+1}=struct("checkpoint",kind,"split",s.split,"subject",s.subject,"row",s.row,"direction",directions(s.side), ...
            "trackingMSE",E.trackingMSE(idx),"reward",E.rewardMean(idx),"png",replace(png,"\","/"),"fig",replace(fig,"\","/"),"verified",true); %#ok<AGROW>
    end
end
inventory=struct2table([rows{:}]);
end
