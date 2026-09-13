function e2cPlotDiagnostics(out)
% Figura cientifica exportable basada solamente en artefactos medidos.
arguments
    out (1,1) string = fullfile(fileparts(mfilename("fullpath")),"e2c_results")
end
S=load(fullfile(out,"cycle_artifacts.mat"),"F");M=load(fullfile(out,"m3_artifacts.mat"),"D","G");
fig=figure("Visible","off","Color","w","Position",[100 100 1250 780]);
cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(2,2,"TileSpacing","compact");
for c=1:2
    nexttile;f=S.F(S.F.caseId==c & S.F.referenceIndex==1 & S.F.initialStateIndex==1 & S.F.step<=12,:);
    plot(f.step-1,f.hBefore,"o-","LineWidth",1.4);hold on;
    yline(f.reference(1),"--","Teacher fijo","LineWidth",1.2);
    xlabel("Paso (Ts = 0.2 s)");ylabel("h(q)");grid on;
    title("Caso "+c+": alternancia con referencia fija");
end
nexttile;hold on;
for speed=[192 224 255]
    d=M.D(M.D.pwm==speed & M.D.qBefore>7490 & M.D.qBefore<7670,:);
    plot(d.qBefore,d.deltaQ,"DisplayName","PWM "+speed,"LineWidth",1.1);
end
yline(0,"k--","HandleVisibility","off");ylim([-70 5]);xlim([7490 7670]);grid on;
xlabel("q inicial M3 (encoder)");ylabel("q siguiente - q inicial");
title("Retrocesos M3: detalle de los intervalos");legend("Location","southwest");
nexttile;g=M.G;
bar([100*g.fractionInAnyReversalRegion,100*g.executedReversals./g.statesBefore]);
xticks(1:height(g));xticklabels(["Cero","P0.5","P1","P2","P4","P8","Agente"]);
ylabel("Porcentaje de pasos M3");grid on;
legend("Visita región de algún PWM","Ejecuta retroceso","Location","northwest");
title("Visitar una posición no determina el comando");
exportgraphics(fig,fullfile(out,"e2c_diagnostics.png"),"Resolution",180);
print(fig,fullfile(out,"e2c_diagnostics.svg"),"-dsvg");
end
