function figFiles = sealedPlotGlobalFigures(outDir, policyTable, subjectTable, motorTable, dirTable, catTable)
% sealedPlotGlobalFigures genera las 5 figuras globales de publicacion exigidas por el protocolo:
% 1. FINAL_TEST_POLICY_COMPARISON
% 2. FINAL_TEST_BY_SUBJECT
% 3. FINAL_TEST_BY_MOTOR
% 4. FINAL_TEST_OPENING_CLOSING
% 5. FINAL_TEST_PWM_USAGE

arguments
    outDir (1, 1) string
    policyTable table
    subjectTable table
    motorTable table
    dirTable table
    catTable table
end

figDir = fullfile(outDir, "figures");
if ~isfolder(figDir), mkdir(figDir); end

figFiles = struct();

%% 1. FINAL_TEST_POLICY_COMPARISON
f1 = figure(Visible="off", Color="w", Position=[100 100 900 550]);
cleanup1 = onCleanup(@() closeOwnFigure(f1)); %#ok<NASGU>

order = ["ZERO", "AGENT7250", "P_2", "ORACLE_H5", "FINAL_E4"];
labels = ["ZERO (Control Basal)", "Agent7250 (TD3 Baseline)", "P2 (Docente Privilegiado)*", "Oracle H5 (Oraculo Cinem.)*", "FINAL E4 (PPO Categorico)"];
mses = zeros(numel(order), 1);
for i = 1:numel(order)
    idx = find(policyTable.controller == order(i), 1);
    if ~isempty(idx)
        mses(i) = policyTable.trackingMSE(idx);
    end
end

b = bar(mses, 0.55, 'FaceColor', 'flat');
b.CData(1, :) = [0.6 0.6 0.6];       % ZERO
b.CData(2, :) = [0.85 0.33 0.1];      % Agent7250
b.CData(3, :) = [0.49 0.18 0.56];     % P2
b.CData(4, :) = [0.15 0.55 0.55];     % Oracle
b.CData(5, :) = [0.18 0.65 0.35];     % FINAL_E4

grid on;
set(gca, 'XTick', 1:numel(order), 'XTickLabel', labels, 'FontSize', 10);
ylabel('Macro Tracking MSE', 'FontSize', 11, 'FontWeight', 'bold');
title('FINAL TEST: Comparativa Global de Politicas (MATEO & SANDRA)', 'FontSize', 12, 'FontWeight', 'bold');

for i = 1:numel(mses)
    text(i, mses(i) + 0.002, sprintf('%.4f', mses(i)), 'HorizontalAlignment', 'center', ...
        'FontSize', 10, 'FontWeight', 'bold');
end
ylim([0 max(mses) * 1.15]);
legend('* Políticas privilegiadas no desplegables', 'Location', 'northwest', 'Box', 'off');

figFiles.policyPng = fullfile(figDir, "FINAL_TEST_POLICY_COMPARISON.png");
figFiles.policyFig = fullfile(figDir, "FINAL_TEST_POLICY_COMPARISON.fig");
exportgraphics(f1, figFiles.policyPng, Resolution=150);
savefig(f1, figFiles.policyFig);

%% 2. FINAL_TEST_BY_SUBJECT
f2 = figure(Visible="off", Color="w", Position=[100 100 800 500]);
cleanup2 = onCleanup(@() closeOwnFigure(f2)); %#ok<NASGU>

subjs = ["MATEO", "SANDRA"];
agentMse = zeros(2, 1);
e4Mse = zeros(2, 1);
for s = 1:2
    idxA = find(subjectTable.controller == "AGENT7250" & subjectTable.subject == subjs(s), 1);
    idxE = find(subjectTable.controller == "FINAL_E4" & subjectTable.subject == subjs(s), 1);
    if ~isempty(idxA), agentMse(s) = subjectTable.trackingMSE(idxA); end
    if ~isempty(idxE), e4Mse(s) = subjectTable.trackingMSE(idxE); end
end

b2 = bar([agentMse e4Mse], 0.65);
b2(1).FaceColor = [0.85 0.33 0.1];
b2(2).FaceColor = [0.18 0.65 0.35];
grid on;
set(gca, 'XTick', 1:2, 'XTickLabel', subjs, 'FontSize', 11);
ylabel('Tracking MSE', 'FontSize', 11, 'FontWeight', 'bold');
legend(["Agent7250 (TD3 Baseline)", "FINAL E4 (PPO Categorico)"], 'Location', 'northwest');
title('FINAL TEST: Desempeño por Sujeto Sellado (MATEO vs SANDRA)', 'FontSize', 12, 'FontWeight', 'bold');

for s = 1:2
    pct = 100 * (e4Mse(s) - agentMse(s)) / agentMse(s);
    text(s + 0.14, e4Mse(s) + 0.003, sprintf('%+.1f%%', pct), 'HorizontalAlignment', 'center', ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.1 0.4 0.1]);
end
ylim([0 max([agentMse; e4Mse]) * 1.18]);

figFiles.subjectPng = fullfile(figDir, "FINAL_TEST_BY_SUBJECT.png");
figFiles.subjectFig = fullfile(figDir, "FINAL_TEST_BY_SUBJECT.fig");
exportgraphics(f2, figFiles.subjectPng, Resolution=150);
savefig(f2, figFiles.subjectFig);

%% 3. FINAL_TEST_BY_MOTOR
f3 = figure(Visible="off", Color="w", Position=[100 100 850 500]);
cleanup3 = onCleanup(@() closeOwnFigure(f3)); %#ok<NASGU>

agentMotor = zeros(4, 1);
e4Motor = zeros(4, 1);
for m = 1:4
    idxA = find(motorTable.controller == "AGENT7250" & motorTable.motor == m, 1);
    idxE = find(motorTable.controller == "FINAL_E4" & motorTable.motor == m, 1);
    if ~isempty(idxA), agentMotor(m) = motorTable.trackingMSE(idxA); end
    if ~isempty(idxE), e4Motor(m) = motorTable.trackingMSE(idxE); end
end

b3 = bar([agentMotor e4Motor], 0.65);
b3(1).FaceColor = [0.85 0.33 0.1];
b3(2).FaceColor = [0.18 0.65 0.35];
grid on;
set(gca, 'XTick', 1:4, 'XTickLabel', ["Motor 1", "Motor 2", "Motor 3", "Motor 4"], 'FontSize', 11);
ylabel('Tracking MSE', 'FontSize', 11, 'FontWeight', 'bold');
legend(["Agent7250", "FINAL E4"], 'Location', 'northwest');
title('FINAL TEST: Tracking MSE por Motor (Agent7250 vs FINAL E4)', 'FontSize', 12, 'FontWeight', 'bold');
ylim([0 max([agentMotor; e4Motor]) * 1.15]);

figFiles.motorPng = fullfile(figDir, "FINAL_TEST_BY_MOTOR.png");
figFiles.motorFig = fullfile(figDir, "FINAL_TEST_BY_MOTOR.fig");
exportgraphics(f3, figFiles.motorPng, Resolution=150);
savefig(f3, figFiles.motorFig);

%% 4. FINAL_TEST_OPENING_CLOSING
f4 = figure(Visible="off", Color="w", Position=[100 100 850 500]);
cleanup4 = onCleanup(@() closeOwnFigure(f4)); %#ok<NASGU>

dirs = [1 2]; % 1=closing, 2=opening
agentDir = zeros(2, 1);
e4Dir = zeros(2, 1);
for d = 1:2
    idxA = find(dirTable.controller == "AGENT7250" & dirTable.side == dirs(d), 1);
    idxE = find(dirTable.controller == "FINAL_E4" & dirTable.side == dirs(d), 1);
    if ~isempty(idxA), agentDir(d) = dirTable.trackingMSE(idxA); end
    if ~isempty(idxE), e4Dir(d) = dirTable.trackingMSE(idxE); end
end

b4 = bar([agentDir e4Dir], 0.6);
b4(1).FaceColor = [0.85 0.33 0.1];
b4(2).FaceColor = [0.18 0.65 0.35];
grid on;
set(gca, 'XTick', 1:2, 'XTickLabel', ["CIERRE (Closing)", "APERTURA (Opening)"], 'FontSize', 11);
ylabel('Tracking MSE', 'FontSize', 11, 'FontWeight', 'bold');
legend(["Agent7250", "FINAL E4"], 'Location', 'northwest');
title('FINAL TEST: Comparativa CIERRE vs APERTURA', 'FontSize', 12, 'FontWeight', 'bold');
ylim([0 max([agentDir; e4Dir]) * 1.18]);

figFiles.dirPng = fullfile(figDir, "FINAL_TEST_OPENING_CLOSING.png");
figFiles.dirFig = fullfile(figDir, "FINAL_TEST_OPENING_CLOSING.fig");
exportgraphics(f4, figFiles.dirPng, Resolution=150);
savefig(f4, figFiles.dirFig);

%% 5. FINAL_TEST_PWM_USAGE
f5 = figure(Visible="off", Color="w", Position=[100 100 1000 550]);
cleanup5 = onCleanup(@() closeOwnFigure(f5)); %#ok<NASGU>

levels = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255];
labels15 = ["0", "-64", "+64", "-96", "+96", "-128", "+128", "-160", "+160", "-192", "+192", "-224", "+224", "-255", "+255"];
M = zeros(4, 15);

subCat = catTable(catTable.controller == "FINAL_E4", :);
for m = 1:4
    motT = subCat(subCat.motor == m, :);
    for k = 1:15
        colName = sprintf("pwm_%d", levels(k));
        colName = strrep(colName, "-", "m");
        if ismember(colName, motT.Properties.VariableNames)
            M(m, k) = sum(motT.(colName));
        end
    end
    tot = sum(M(m, :));
    if tot > 0, M(m, :) = M(m, :) / tot; end
end

imagesc(M);
colormap(hot);
cb = colorbar;
ylabel(cb, 'Fraccion de uso', 'FontSize', 10);
set(gca, 'XTick', 1:15, 'XTickLabel', labels15, 'YTick', 1:4, ...
    'YTickLabel', ["Motor 1", "Motor 2", "Motor 3", "Motor 4"], 'FontSize', 10);
xtickangle(45);
title('FINAL TEST: Distribucion de Uso de Acciones PWM (FINAL E4 sobre MATEO y SANDRA)', ...
    'FontSize', 12, 'FontWeight', 'bold');
xlabel('Comando PWM Discreto', 'FontSize', 11, 'FontWeight', 'bold');

figFiles.pwmPng = fullfile(figDir, "FINAL_TEST_PWM_USAGE.png");
figFiles.pwmFig = fullfile(figDir, "FINAL_TEST_PWM_USAGE.fig");
exportgraphics(f5, figFiles.pwmPng, Resolution=150);
savefig(f5, figFiles.pwmFig);

end

function closeOwnFigure(f)
if isgraphics(f), close(f); end
end
