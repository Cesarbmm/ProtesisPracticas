function e3cSummaryPlot
here=string(fileparts(mfilename("fullpath")));out=fullfile(fileparts(here),"e3c_results");
I=readtable(fullfile(out,"imitation_all.csv"),TextType="string",Delimiter=",");C=readtable(fullfile(out,"closed_loop_all.csv"),TextType="string",Delimiter=",");
F=figure(Visible="off",Color="w",Position=[40 40 1400 900]);cl=onCleanup(@() close(F)); %#ok<NASGU>
tiledlayout(F,2,3,TileSpacing="compact",Padding="compact");
for field=["macroF1","NLL"]
    nexttile;means=zeros(1,3);sd=means;
    for k=1:3
        kind="FF";control="ordered";if k>=2,kind="GRU";end;if k==3,control="shuffled";end
        v=I.(field)(I.split=="VALIDATION" & I.dimension=="all" & I.motor==0 & I.kind==kind & I.control==control);
        assert(numel(v)==3);means(k)=mean(v);sd(k)=std(v);
    end
    bar(means);hold on;errorbar(1:3,means,sd,'.k',LineWidth=1.4);xticks(1:3);xticklabels(["FF","GRU","GRU desordenado"]);title("Imitacion Oracle: "+field,Interpreter="none");ylabel("Media +/- SD de tres seeds");grid on;
end
nexttile;pairBars(C,"trackingMSE","2",.0565534616657263);title("Apertura VALIDATION: MSE");
nexttile;pairBars(C,"flat_response","2",.458333333333333);title("Apertura: fraccion de respuesta plana");
nexttile;pairBars(C,"trackingMSE","1",.0583243505891969);title("Cierre VALIDATION: MSE");
nexttile;P=readtable(fullfile(out,"phase_all.csv"),TextType="string",Delimiter=",");y=zeros(2,3);
tasks=["direction","phase","phase_direction"];
for k=1:2,kind=["FF","GRU"];for j=1:3,y(k,j)=mean(P.accuracy(P.kind==kind(k) & P.split=="VALIDATION" & P.task==tasks(j)));end;end
bar(y');xticks(1:3);xticklabels(["Direccion","Fase","Fase+direccion"]);legend("FF","GRU",Location="best");ylabel("Accuracy");title("Readout lineal secundario");ylim([0 1]);grid on;
sgtitle("E3C: mejora en lazo cerrado frente a FF; gate temporal no cumplido");
exportgraphics(F,fullfile(out,"e3c_summary.png"),Resolution=150);exportgraphics(F,fullfile(out,"e3c_summary.pdf"),ContentType="vector");savefig(F,fullfile(out,"e3c_summary.fig"));
end
function pairBars(C,field,side,previous)
m=zeros(1,3);s=zeros(1,3);for j=1:2
    kinds=["FF","GRU"];v=C.(field)(C.kind==kinds(j) & C.split=="VALIDATION" & C.dimension=="direction" & string(C.value)==side);
    assert(numel(v)==3);m(j)=mean(v);s(j)=std(v);
end
m(3)=previous;bar(m);hold on;errorbar(1:2,m(1:2),s(1:2),'.k',LineWidth=1.4);xticks(1:3);xticklabels(["FF probe","GRU probe","E3B BEST"]);grid on;
end
