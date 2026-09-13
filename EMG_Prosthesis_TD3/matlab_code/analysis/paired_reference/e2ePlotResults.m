function e2ePlotResults(out)
C=readtable(fullfile(out,"e2d_descriptive_comparison.csv"),TextType="string");
T=readtable(fullfile(out,"fixed_reference_traces.csv"));
fig=figure("Visible","off","Color","w","Position",[80 80 1300 740]);cleanup=onCleanup(@() close(fig)); %#ok<NASGU>
tiledlayout(2,2,"TileSpacing","compact");
for c=1:2
    nexttile;hold on;
    for enabled=[0 1]
        A=T(T.caseId==c & T.referenceIndex==1 & T.initialStateIndex==1 & T.enabled==enabled,:);
        keep=A.step<=20;
        stairs([0;A.step(keep)],[A.qBefore(1);A.qAfter(keep)],"LineWidth",1.4);
    end
    xlabel("Decisión, Ts=0.2 s");ylabel("Encoder");title("Referencia fija: motor "+(c+2));
    legend("P2 OFF","Guard ON","Location","best");grid on;
end
nexttile;bar(100*[C.directNeutralFraction,C.pairedZeroedActiveFraction]);
xticks(1:3);xticklabels(C.condition);ylabel("Comandos (%)");
legend("Inhibición directa / todos","Ceros pareados / activos P2","Location","northwest");
title("Denominadores distintos, explícitos");grid on;
nexttile;bar(100*C.flat_response);xticks(1:3);xticklabels(C.condition);ylabel("Respuesta plana (%)");
title("Comparación descriptiva, sin reabrir E2D");grid on;
exportgraphics(fig,fullfile(out,"e2e_results.png"),"Resolution",180);print(fig,fullfile(out,"e2e_results.svg"),"-dsvg");
end
