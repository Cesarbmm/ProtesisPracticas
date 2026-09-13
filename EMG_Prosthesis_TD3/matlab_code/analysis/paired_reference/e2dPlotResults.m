function e2dPlotResults(out)
g=readtable(fullfile(out,"candidate_gates.csv"));s=readtable(fullfile(out,"epsilon_summary.csv"));
fig=figure("Visible","off","Color","w","Position",[80 80 1240 760]);c=onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(2,2,"TileSpacing","compact");labels=compose("%.2f",g.epsilon);
nexttile;bar([g.mseChangePct,g.rewardChangePct]);yline(5,"--","Límite de deterioro","HandleVisibility","off");
ylim([-12 6]);
xticks(1:height(g));xticklabels(labels);xlabel("Epsilon");ylabel("Deterioro relativo (%)");
legend("MSE","Reward","Location","southwest");title("Valores negativos significan mejora");grid on;
nexttile;bar(g.cycles);xticks(1:height(g));xticklabels(labels);xlabel("Epsilon");ylabel("Ciclos finales");
ylim([0 2.5]);yticks(0:2);
title("Detector histórico en 200 episodios");grid on;
nexttile;bar([100*(s.flat_response-s.flat_response(1)),100*g.maxFlatIncrease]);yline(2,"--","Límite del aumento","HandleVisibility","off");
xticks(1:height(g));xticklabels(labels);xlabel("Epsilon");ylabel("Aumento de respuesta plana (pp)");ylim([0 22]);
legend("Aumento global (pp)","Mayor aumento por grupo (pp)","Location","northwest");
title("La respuesta plana supera el gate");grid on;
nexttile;bar(100*g.pairedZeroedActiveFraction);yline(20,"--","Límite preregistrado","HandleVisibility","off");
xticks(1:height(g));xticklabels(labels);xlabel("Epsilon");ylabel("Comandos activos P2 que pasan a cero (%)");
title("Comparación alineada con la trayectoria P2");grid on;
exportgraphics(fig,fullfile(out,"e2d_results.png"),"Resolution",180);
print(fig,fullfile(out,"e2d_results.svg"),"-dsvg");
end
