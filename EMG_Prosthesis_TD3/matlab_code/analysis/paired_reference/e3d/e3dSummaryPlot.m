function e3dSummaryPlot
out=fullfile(fileparts(string(fileparts(mfilename("fullpath")))),"e3d_results");
I=readtable(fullfile(out,"intent_all.csv"),TextType="string",Delimiter=",");C=readtable(fullfile(out,"closed_loop_all.csv"),TextType="string",Delimiter=",");
s=jsondecode(fileread(fullfile(out,"scientific_summary.json")));F=figure(Visible="off",Color="w",Position=[40 40 1450 900]);cl=onCleanup(@() close(F)); %#ok<NASGU>
tiledlayout(F,2,3,TileSpacing="compact",Padding="compact");
for task=["direction","phase_direction"]
 nexttile;mu=zeros(1,3);sd=mu;
 for k=1:3,kind="BASELINE";control="ordered";if k>=2,kind="TEMPORAL_EMG";end;if k==3,control="shuffled";end
  v=I.macroF1(I.kind==kind & I.control==control & I.split=="VALIDATION" & I.subject=="ALL" & I.task==task);assert(numel(v)==3);mu(k)=mean(v);sd(k)=std(v);
 end
 bar(mu);hold on;errorbar(1:3,mu,sd,'.k');xticks(1:3);xticklabels(["Actual","EMG L8","Permutado"]);ylabel("Macro-F1; media y SD de 3 seeds");title(task,Interpreter="none");ylim([0 1]);grid on;
end
nexttile;pair(C,"trackingMSE","2",.0565534616657263);title("Apertura VALIDATION: MSE");
nexttile;pair(C,"flat_response","2",.458333333333333);title("Apertura: fraccion de respuesta plana");
nexttile;pair(C,"trackingMSE","1",.0583243505891969);title("Cierre VALIDATION: MSE");
nexttile;T=readtable(fullfile(out,"by_seed.csv"),TextType="string",Delimiter=",");kinds=["BASELINE","TEMPORAL_EMG"];m=zeros(2,2);
for j=1:2,m(j,:)=[mean(T.oracleF1(T.kind==kinds(j))),mean(T.oracleNLL(T.kind==kinds(j)))];end
bar(m');xticks(1:2);xticklabels(["Oracle macro-F1","Oracle NLL"]);legend("Actual","Temporal EMG");title("Imitacion auxiliar, sin gate");grid on;
sgtitle("E3D: "+string(s.E3D_RESULT),Interpreter="none");
exportgraphics(F,fullfile(out,"e3d_summary.png"),Resolution=150);exportgraphics(F,fullfile(out,"e3d_summary.pdf"),ContentType="vector");savefig(F,fullfile(out,"e3d_summary.fig"));
end
function pair(C,field,side,previous)
m=zeros(1,3);s=m;kinds=["BASELINE","TEMPORAL_EMG"];
for k=1:2,v=C.(field)(C.kind==kinds(k) & C.split=="VALIDATION" & C.dimension=="direction" & string(C.value)==side);assert(numel(v)==3);m(k)=mean(v);s(k)=std(v);end
m(3)=previous;bar(m);hold on;errorbar(1:2,m(1:2),s(1:2),'.k');xticks(1:3);xticklabels(["Actual","Temporal EMG","E3B BEST"]);grid on;
end
