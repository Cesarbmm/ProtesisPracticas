function e2fPlotResults(out)
M=readtable(fullfile(out,"controller_summary.csv"),TextType="string");F=readtable(fullfile(out,"fixed_reference_traces.csv"));
S=readtable(fullfile(out,"step_traces.csv"));D=load(fullfile(out,"graphs.mat"));
fig=figure("Visible","off","Color","w","Position",[60 60 1400 800]);cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(2,2,"TileSpacing","compact");labels=["Cero","P2","Agent7250","H1","H2","H3","H5"];
nexttile;bar(M.trackingMSE);xticks(1:7);xticklabels(labels);ylabel("MSE");title("Mismos 200 episodios; H5 primario");grid on;
nexttile;bar([M.trackingMSE M.actionPenalty M.deltaActionPenalty],"stacked");xticks(1:7);xticklabels(labels);
ylabel("Coste = -reward");legend("Tracking","Acción","Cambio de acción","Location","northeast");title("Coste histórico descompuesto");grid on;
nexttile;hold on;
for H=[0 5]
    A=F(F.caseId==1 & F.referenceIndex==1 & F.initialStateIndex==1 & F.horizon==H & F.step<=20,:);
    stairs([0;A.step],[A.qBefore(1);A.qAfter],"LineWidth",1.5);
end
xlabel("Decisión (Ts=.2 s)");ylabel("Encoder M3");legend("P2","Oracle H5","Location","best");title("Referencia fija: mismo mapa de planta");grid on;
nexttile;hold on;hmin=zeros(1,4);hmax=hmin;rmin=hmin;rmax=hmin;
for m=1:4,hmin(m)=min(D.graphs{m}.h);hmax(m)=max(D.graphs{m}.h);rmin(m)=min(S.referenceAfter(S.motor==m));rmax(m)=max(S.referenceAfter(S.motor==m));end
errorbar((1:4)-.08,(hmin+hmax)/2,(hmax-hmin)/2,"o","LineWidth",2);
errorbar((1:4)+.08,(rmin+rmax)/2,(rmax-rmin)/2,"o","LineWidth",2);
xticks(1:4);xticklabels(["M1","M2","M3","M4"]);ylabel("Escala h(q)/teacher");ylim([0 1]);
legend("Envolvente del grafo","Teacher observado","Location","best");title("Soporte de la planta y target");grid on;
exportgraphics(fig,fullfile(out,"e2f_results.png"),"Resolution",180);print(fig,fullfile(out,"e2f_results.svg"),"-dsvg");
end
