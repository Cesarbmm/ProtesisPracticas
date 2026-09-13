function e2gMakeFigures
here=string(fileparts(mfilename("fullpath")));out=fullfile(here,"e2g_results");
T=readtable(fullfile(out,"support_steps.csv"),TextType="string");M=T(T.motor==2,:);
f=figure(Visible="off",Color="w",Position=[100 100 1250 850]);c=onCleanup(@() close(f)); %#ok<NASGU>
tiledlayout(2,2,TileSpacing="compact");
nexttile;hold on;
scatter(M.teacher(M.side==1),M.bestGraphH(M.side==1),8,[.1 .4 .7],"filled",MarkerFaceAlpha=.25);
scatter(M.teacher(M.side==2),M.bestGraphH(M.side==2),8,[.8 .3 .1],"filled",MarkerFaceAlpha=.25);
plot([0 1],[0 1],"k--");yline(M.hMin(1),":");yline(M.hMax(1),":");
xlabel("Teacher original M2");ylabel("h más próximo en todo el grafo");title("M2: soporte escalar, sin restricción de tiempo");legend("Cierre","Apertura","Identidad",Location="northwest");grid on;
nexttile;scatter(M.teacher,M.signedBestError,9,M.side,"filled",MarkerFaceAlpha=.25);yline(0,"k--");
xlabel("Teacher original M2");ylabel("h próximo − teacher");title("M2: diferencia firmada; predomina techo insuficiente");grid on;
nexttile;hold on;
names=["teacher","p2H","originalOracleH","projected","projectedOracleH"];
for j=1:numel(names),v=sort(M.(names(j)));plot(v,(1:numel(v))/numel(v),LineWidth=1.4);end
xline(M.hMin(1),"k:");xline(M.hMax(1),"k:");xlabel("Coordenada histórica");ylabel("Fracción acumulada por pasos");
legend("Teacher","P2: h visitado","H5 original: h visitado","Teacher proyectado","H5 proyectado: h visitado",Location="southeast");title("M2: distribuciones y acumulación en los extremos");grid on;
nexttile;opts=detectImportOptions(fullfile(out,"variation_summary.csv"),TextType="string");
opts=setvartype(opts,["subject","motor","side"],"string");R=readtable(fullfile(out,"variation_summary.csv"),opts);
R=R(R.subject=="ALL" & R.motor~="ALL" & R.side~="ALL",:);vals=zeros(4,2);
for k=1:height(R),vals(str2double(R.motor(k)),str2double(R.side(k)))=R.medianRangeRatio(k);end
bar(100*vals);yline(50,"r--","Mínimo preregistrado");xticks(1:4);xticklabels(["M1","M2","M3","M4"]);
ylabel("Mediana de rango temporal conservado (%)");legend("Cierre","Apertura",Location="northwest");title("Proyección: pérdida de variación temporal");grid on;
sgtitle("E2G · Diagnóstico de coordenadas, sin calibración física ni RL");
exportgraphics(f,fullfile(out,"e2g_support.png"),Resolution=160);print(f,fullfile(out,"e2g_support.svg"),"-dsvg");
end
