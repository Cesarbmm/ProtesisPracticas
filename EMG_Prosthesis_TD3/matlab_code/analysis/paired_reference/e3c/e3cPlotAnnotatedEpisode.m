function files=e3cPlotAnnotatedEpisode(left,right,folder,labels)
arguments,left;right;folder string;labels string=["FF PROBE","GRU PROBE"];end
assert(isequal(left.reference,right.reference) && size(left.pwm,1)==size(right.pwm,1));
md=left.metadata;directions=["closing","opening"];assert(string(md.subject)==string(right.metadata.subject) && md.repetition==right.metadata.repetition && md.side==right.metadata.side);
if ~isfolder(folder),mkdir(folder);end
stem=string(md.subject)+compose("_row%04d_",md.repetition)+directions(md.side);
files=struct("png",fullfile(folder,stem+".png"),"fig",fullfile(folder,stem+".fig"),"csv",fullfile(folder,stem+".csv"),"mat",fullfile(folder,stem+".mat"));
T=[e3cDiagnosticTable(left,labels(1));e3cDiagnosticTable(right,labels(2))];writetable(T,files.csv);save(files.mat,"T","left","right","labels");
f=figure(Visible="off",Color="w",Position=[30 30 1700 1200]);cleanup=onCleanup(@() close(f)); %#ok<NASGU>
layout=tiledlayout(f,4,2,TileSpacing="compact",Padding="compact");traces={left,right};
for m=1:4
    for j=1:2
        t=traces{j};n=size(t.pwm,1);ax=nexttile(layout);plot(ax,1:n,t.reference(:,m),'--',Color=[.85 .33 .1],LineWidth=1.5,Tag="reference",DisplayName="Teacher posterior");hold(ax,'on');
        plot(ax,1:n,t.prediction(:,m),'-o',Color=[0 .45 .74],LineWidth=1.4,MarkerSize=3,Tag="prediction",DisplayName="Protesis h(q)");
        for k=1:n
            value=t.effectiveAction(k,m);label=sprintf('%+.2f',value);if value==0,label='0';end
            text(ax,k,t.prediction(k,m)+.025+.035*mod(k,2),label,FontSize=7,Color=[.2 .2 .2],HorizontalAlignment="center",Tag="effectiveActionLabel");
        end
        title(ax,"M"+m+" | "+labels(j),Interpreter="none");grid(ax,'on');ylabel(ax,"Escala h / teacher");
        if n>1,xlim(ax,[.5 n+.5]);end;ylim(ax,[min([t.reference(:,m);t.prediction(:,m)])-.035,max([t.reference(:,m);t.prediction(:,m)])+.12]);
        if m==1,legend(ax,Location="best",Box="off");end;if m==4,xlabel(ax,"Paso; texto = accion efectiva PWM / 255");end
    end
end
title(layout,"E3C | "+string(md.subject)+compose(" | fila%d | ",md.repetition)+directions(md.side)+" | etiqueta = accion, NO probabilidad",Interpreter="none");
exportgraphics(f,files.png,Resolution=150);savefig(f,files.fig);
end
