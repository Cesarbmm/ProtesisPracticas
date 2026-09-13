function [coverageSummary, initialWindowSummary] = e3eAuditCoverageAndInitialWindow()
% e3eAuditCoverageAndInitialWindow: Audita cobertura de datos y estabilidad de la ventana inicial.
cfg = e3eConfig();
if ~isfolder(cfg.output), mkdir(cfg.output); end

% Cargar datos supervisados
a = load(cfg.dataPath, "D");
D = a.D;
S = D.samples;
episodes = D.episodes;

% Asegurar que MATEO y SANDRA están sellados
subjectsInSamples = unique(S.subject);
assert(~any(ismember(subjectsInSamples, cfg.sealedSubjects)), "ALERTA: Sujetos sellados presentes en datos");

%% ==========================================
% SECCIÓN 17: COBERTURA DE DATOS
% ==========================================
allSubjects = [cfg.trainSubjects, cfg.validationSubjects];
coverageRows = {};

% Estadísticas por sujeto
for i = 1:numel(allSubjects)
    sub = allSubjects(i);
    splitName = "TRAIN";
    if ismember(sub, cfg.validationSubjects), splitName = "VALIDATION"; end

    subIx = (S.subject == sub);
    subSamples = S(subIx, :);

    epIds = unique(subSamples.episode);
    epSides = zeros(numel(epIds), 1);
    epLengths = zeros(numel(epIds), 1);
    for k = 1:numel(epIds)
        e = epIds(k);
        epIx = (subSamples.episode == e);
        epSides(k) = subSamples.side(find(epIx, 1));
        epLengths(k) = sum(epIx);
    end

    nEpClosing = sum(epSides == 1);
    nEpOpening = sum(epSides == 2);

    nSampClosing = sum(subSamples.side == 1);
    nSampOpening = sum(subSamples.side == 2);

    lenMean = mean(epLengths);
    lenMed = median(epLengths);
    lenP05 = e3eStats.prctile(epLengths, 5);
    lenP95 = e3eStats.prctile(epLengths, 95);

    % Fases: 1=early, 2=middle, 3=late
    nEarly = sum(subSamples.phase == 1);
    nMid = sum(subSamples.phase == 2);
    nLate = sum(subSamples.phase == 3);

    imbalance = nSampOpening / max(1, nSampClosing);

    coverageRows{end+1} = struct(...
        "subject", sub, ...
        "split", splitName, ...
        "nEpisodesClosing", nEpClosing, ...
        "nEpisodesOpening", nEpOpening, ...
        "nSamplesClosing", nSampClosing, ...
        "nSamplesOpening", nSampOpening, ...
        "lengthMean", lenMean, ...
        "lengthMedian", lenMed, ...
        "lengthP05", lenP05, ...
        "lengthP95", lenP95, ...
        "nSamplesEarly", nEarly, ...
        "nSamplesMiddle", nMid, ...
        "nSamplesLate", nLate, ...
        "imbalanceRatio", imbalance);
end

coverageTable = struct2table([coverageRows{:}]);
writetable(coverageTable, fullfile(cfg.output, "coverage_by_subject.csv"));

% Resumen global TRAIN vs VALIDATION
trainIx = (S.split == "TRAIN");
valIx = (S.split == "VALIDATION");

nTrainClosing = sum(S.side(trainIx) == 1);
nTrainOpening = sum(S.side(trainIx) == 2);
nValClosing = sum(S.side(valIx) == 1);
nValOpening = sum(S.side(valIx) == 2);

trainImbalance = nTrainOpening / nTrainClosing;
valImbalance = nValOpening / nValClosing;
globalImbalance = sum(S.side == 2) / sum(S.side == 1);

% ¿Hay problema de cobertura de datos?
% Criterio: balance opening vs closing y presencia suficiente en todos los sujetos
hasCoverageProblem = (abs(globalImbalance - 1.0) > 0.25) || (min(coverageTable.nSamplesOpening) < 50);

coverageSummary = struct(...
    "OPENING_DATA_COVERAGE", sum(S.side == 2), ...
    "CLOSING_DATA_COVERAGE", sum(S.side == 1), ...
    "OPEN_CLOSE_IMBALANCE", globalImbalance, ...
    "TRAIN_OPENING_SAMPLES", nTrainOpening, ...
    "TRAIN_CLOSING_SAMPLES", nTrainClosing, ...
    "TRAIN_IMBALANCE", trainImbalance, ...
    "VAL_OPENING_SAMPLES", nValOpening, ...
    "VAL_CLOSING_SAMPLES", nValClosing, ...
    "VAL_IMBALANCE", valImbalance, ...
    "DATA_COVERAGE_PROBLEM", hasCoverageProblem);

fid = fopen(fullfile(cfg.output, "coverage_summary.json"), "w");
fprintf(fid, "%s", jsonencode(coverageSummary, PrettyPrint=true));
fclose(fid);

%% ==========================================
% SECCIÓN 18: PRIMEROS SAMPLES DEL EPISODIO
% ==========================================
% Evaluamos N = 1, 2, 3, 5
% Extraer los primeros N pasos de WMoos40 de cada uno de los 200 episodios
Ns = [1, 2, 3, 5];
initialWindowRows = {};

for idxN = 1:numel(Ns)
    N = Ns(idxN);

    % Recolectar datos de la ventana inicial para los 200 episodios
    % Para cada episodio: media de los primeros N pasos de features 1:40
    featInit = zeros(200, 40);
    epSide = zeros(200, 1);
    epSub = strings(200, 1);
    epSplit = strings(200, 1);

    for e = 1:200
        states = D.sequences{e}.state; % 52 x T
        actualN = min(N, size(states, 2));
        featInit(e, :) = mean(states(1:40, 1:actualN), 2)';
        epSide(e) = episodes{e}.base.metadata.side;
        epSub(e) = string(episodes{e}.base.metadata.subject);
        epSplit(e) = episodes{e}.split;
    end

    % Diferencia opening vs closing en la ventana inicial
    openIx = (epSide == 2);
    closeIx = (epSide == 1);

    diffOpenClose = abs(mean(featInit(openIx, :), 1) - mean(featInit(closeIx, :), 1));
    meanDiffOpenClose = mean(diffOpenClose);
    maxDiffOpenClose = max(diffOpenClose);

    % Variabilidad intra-sujeto (varianza media dentro del mismo sujeto)
    % vs inter-sujeto
    varIntraList = [];
    for i = 1:numel(allSubjects)
        subIx = (epSub == allSubjects(i));
        if sum(subIx) > 1
            varIntraList(end+1, :) = var(featInit(subIx, :), 0, 1); %#ok<AGROW>
        end
    end
    meanIntraVar = mean(mean(varIntraList, 1));

    varInter = var(featInit, 0, 1);
    meanInterVar = mean(varInter);

    % Estabilidad temporal: deriva entre step 1 y step N (cuando N > 1)
    if N > 1
        driftList = zeros(200, 1);
        for e = 1:200
            states = D.sequences{e}.state;
            actualN = min(N, size(states, 2));
            driftList(e) = mean(abs(states(1:40, actualN) - states(1:40, 1)));
        end
        meanDrift = mean(driftList);
    else
        meanDrift = 0;
    end

    % Test de diferencia significativa opening vs closing (Welch t-test)
    % Calculamos fracción de features con diferencia opening/closing significativa (p < 0.05)
    sigFeatures = 0;
    for f = 1:40
        [~, pVal] = e3eStats.ttest2(featInit(openIx, f), featInit(closeIx, f));
        if pVal < 0.05
            sigFeatures = sigFeatures + 1;
        end
    end
    fracSigOpenClose = sigFeatures / 40;

    initialWindowRows{end+1} = struct(...
        "N", N, ...
        "meanDiffOpenClose", meanDiffOpenClose, ...
        "maxDiffOpenClose", maxDiffOpenClose, ...
        "fracSignificantOpenClose", fracSigOpenClose, ...
        "meanIntraSubjectVariance", meanIntraVar, ...
        "meanTotalVariance", meanInterVar, ...
        "meanDriftStep1ToN", meanDrift);
end

initialWindowTable = struct2table([initialWindowRows{:}]);
writetable(initialWindowTable, fullfile(cfg.output, "initial_window_audit.csv"));

% Determinación de INITIAL_WINDOW_STABLE:
% Si opening y closing ya difieren fuertemente desde el inicio (fracSigOpenClose > 0.30)
% o si la deriva temporal es alta, NO se puede tratar como un baseline neutro de reposo.
isStable = (initialWindowTable.fracSignificantOpenClose(initialWindowTable.N == 1) < 0.25) && ...
           (initialWindowTable.meanDiffOpenClose(initialWindowTable.N == 1) < 0.20);

initialWindowSummary = struct(...
    "INITIAL_WINDOW_STABLE", isStable, ...
    "N1_meanDiffOpenClose", initialWindowTable.meanDiffOpenClose(initialWindowTable.N == 1), ...
    "N1_fracSigOpenClose", initialWindowTable.fracSignificantOpenClose(initialWindowTable.N == 1), ...
    "N3_meanDiffOpenClose", initialWindowTable.meanDiffOpenClose(initialWindowTable.N == 3), ...
    "N5_meanDiffOpenClose", initialWindowTable.meanDiffOpenClose(initialWindowTable.N == 5));

fid = fopen(fullfile(cfg.output, "initial_window_summary.json"), "w");
fprintf(fid, "%s", jsonencode(initialWindowSummary, PrettyPrint=true));
fclose(fid);

fprintf("Auditoría de cobertura y ventana inicial completada exitosamente.\n");
end
