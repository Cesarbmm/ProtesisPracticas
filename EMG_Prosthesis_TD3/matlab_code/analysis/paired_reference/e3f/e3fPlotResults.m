function e3fPlotResults(out,audit,trainingStats)
arguments
    out (1,1) string
    audit struct
    trainingStats table
end
% Figura 1: Subject Invariance Comparison (WMoos40 vs E3F Latent)
fig1=figure(Visible="off",Color="w",Position=[100 100 800 500]);
categories=["Subject-ID Acc","Subject-ID F1","Direction F1","Phase-Dir F1"];
wmoosVals=[audit.baselineSubjectIDAccuracy, audit.baselineSubjectIDMacroF1, audit.baselineDirectionF1, audit.baselinePhaseDirectionF1];
latentVals=[audit.latentSubjectIDAccuracy, audit.latentSubjectIDMacroF1, audit.directionMacroF1, audit.phaseDirectionMacroF1];

b=bar([wmoosVals; latentVals]');
b(1).FaceColor=[0.2 0.4 0.8]; % WMoos40 (Original)
b(2).FaceColor=[0.85 0.35 0.1]; % E3F Latent (Adversarial)
set(gca,"XTickLabel",categories,"FontSize",11);
legend(["WMoos40 Original","E3F Latent64"],"Location","northeast");
ylabel("Score / Exactitud / F1");
title("Subject Invariance & Intent Retention (WMoos40 vs E3F Latent)");
grid on;ylim([0 1]);

% Líneas de referencia para gates
yline(0.80*audit.baselineSubjectIDAccuracy,"--r","Gate Invarianza (<= 0.6331)",LineWidth=1.2);
exportgraphics(fig1,fullfile(out,"subject_invariance.png"),Resolution=150);
close(fig1);

% Figura 2: Training Progress
if ~isempty(trainingStats) && ismember("TotalAgentSteps",trainingStats.Properties.VariableNames)
    fig2=figure(Visible="off",Color="w",Position=[100 100 900 450]);
    subplot(2,1,1);
    plot(trainingStats.TotalAgentSteps,trainingStats.EpisodeReward,"b.-");hold on;
    plot(trainingStats.TotalAgentSteps,trainingStats.AverageReward,"r-",LineWidth=1.5);
    ylabel("Reward");title("E3F Training Progress");legend(["Episode","Average 100"],"Location","southeast");grid on;
    subplot(2,1,2);
    plot(trainingStats.TotalAgentSteps,trainingStats.EpisodeSteps,"k.-");
    ylabel("Pasos");xlabel("Agent Steps");grid on;
    exportgraphics(fig2,fullfile(out,"training_progress.png"),Resolution=150);
    close(fig2);
end
end
