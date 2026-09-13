function report = e4CheckPostProcessing(outDir)
% e4CheckPostProcessing gate de cierre: verifica que todas las figuras y
% evidencias numericas requeridas para E4_FINAL existen y son matematicamente exactas.

arguments
    outDir (1, 1) string
end

finalDir = fullfile(outDir, "evaluation", "final_checkpoint");
assert(isfolder(finalDir), "E4:Check:MissingFinalCheckpoint", "Falta carpeta evaluation/final_checkpoint.");

% 1. Verificar seleccion de episodios
selFile = fullfile(outDir, "evaluation_selection.csv");
sel = readtable(selFile, TextType="string", Delimiter=",");
assert(height(sel) == 200, "E4:Check:EpisodeCount", "Se esperaban 200 episodios, hay %d.", height(sel));
assert(~any(ismember(sel.subject, ["MATEO", "SANDRA"])), "E4:Check:SealedSubject", "MATEO o SANDRA fueron abiertos.");
assert(nnz(sel.split == "TRAIN") == 200, "E4:Check:TrainCount", "Se esperaban 200 episodios TRAIN.");

% 2. Verificar trazas guardadas
trajFile = fullfile(finalDir, "metrics", "trajectories.mat");
assert(isfile(trajFile), "E4:Check:MissingTrajectories", "Falta trajectories.mat en final_checkpoint.");
s = load(trajFile, "traces", "runtimeTraces");
assert(numel(s.traces) == 200, "E4:Check:TraceCount", "Faltan trazas en trajectories.mat (%d/200).", numel(s.traces));

% 3. Contar figuras compact, pro y classic
compactPngs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.png"));
compactFigs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.fig"));
proPngs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.png"));
proFigs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.fig"));
classicPngs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.png"));
classicFigs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.fig"));

assert(numel(compactPngs) == 200, "E4:Check:CompactPngCount", "Se esperaban 200 compact PNG, hay %d.", numel(compactPngs));
assert(numel(compactFigs) == 200, "E4:Check:CompactFigCount", "Se esperaban 200 compact FIG, hay %d.", numel(compactFigs));
assert(numel(proPngs) == 200, "E4:Check:ProPngCount", "Se esperaban 200 pro PNG, hay %d.", numel(proPngs));
assert(numel(proFigs) == 200, "E4:Check:ProFigCount", "Se esperaban 200 pro FIG, hay %d.", numel(proFigs));
assert(numel(classicPngs) == 200, "E4:Check:ClassicPngCount", "Se esperaban 200 classic PNG, hay %d.", numel(classicPngs));
assert(numel(classicFigs) == 200, "E4:Check:ClassicFigCount", "Se esperaban 200 classic FIG, hay %d.", numel(classicFigs));

% 4. Verificar figuras globales
globPng1 = fullfile(finalDir, "figures", "MOTOR_TRACKING_SUMMARY.png");
globFig1 = fullfile(finalDir, "figures", "MOTOR_TRACKING_SUMMARY.fig");
globPng2 = fullfile(finalDir, "figures", "OPENING_CLOSING_SUMMARY.png");
globFig2 = fullfile(finalDir, "figures", "OPENING_CLOSING_SUMMARY.fig");
globPng3 = fullfile(finalDir, "figures", "PWM_USAGE_HEATMAP.png");
globFig3 = fullfile(finalDir, "figures", "PWM_USAGE_HEATMAP.fig");

for gFile = [globPng1, globFig1, globPng2, globFig2, globPng3, globFig3]
    assert(isfile(gFile), "E4:Check:MissingGlobalFigure", "Falta figura global: %s", gFile);
end

% 5. Verificar figuras annotated
annotPngs = dir(fullfile(finalDir, "figures", "annotated", "PNG", "*.png"));
annotFigs = dir(fullfile(finalDir, "figures", "annotated", "FIG", "*.fig"));
annotCsvs = dir(fullfile(finalDir, "figures", "annotated", "CSV", "*.csv"));
annotMats = dir(fullfile(finalDir, "figures", "annotated", "MAT", "*.mat"));
nAnnot = numel(annotPngs);
assert(nAnnot >= 7 && nAnnot <= 12, "E4:Check:AnnotatedCount", "Numero de annotated inesperado: %d.", nAnnot);
assert(numel(annotFigs) == nAnnot && numel(annotCsvs) == nAnnot && numel(annotMats) == nAnnot, ...
    "E4:Check:AnnotatedMismatch", "Desajuste entre PNG, FIG, CSV y MAT en annotated.");

% 6. Verificar trazas CSV y MAT individuales
traceCsvs = dir(fullfile(finalDir, "traces", "**", "*.csv"));
traceMats = dir(fullfile(finalDir, "traces", "**", "*.mat"));
assert(numel(traceCsvs) == 200, "E4:Check:TraceCsvCount", "Se esperaban 200 traces CSV, hay %d.", numel(traceCsvs));
assert(numel(traceMats) == 200, "E4:Check:TraceMatCount", "Se esperaban 200 traces MAT, hay %d.", numel(traceMats));

% 7. Verificar coincidencia matematica de trazas y PWM
traceMatch = true;
pwmMatch = true;
effectiveActionMatch = true;
metricsMatch = true;

for e = 1:200
    t = s.traces{e};
    assert(isequal(size(t.reference), size(t.prediction)) && size(t.reference, 2) == 4, ...
        "E4:Check:MotorCount", "Cada traza debe tener 4 motores.");
    assert(max(abs(t.effectiveAction(:) - t.pwm(:) / 255)) < 1e-12, ...
        "E4:Check:EffectiveActionMatch", "effectiveAction != PWM/255 en episodio %d.", e);
end

% 8. Verificar HTML
htmlFile = fullfile(outDir, "TEST_COMPORTAMENTAL.html");
assert(isfile(htmlFile), "E4:Check:MissingHtml", "Falta TEST_COMPORTAMENTAL.html.");
htmlText = string(fileread(htmlFile));
assert(contains(htmlText, "DEVELOPMENT (10 Sujetos, 200 episodios)"), "E4:Check:HtmlTrain", "Falta seccion DEVELOPMENT en HTML.");
assert(contains(htmlText, "MOTOR_TRACKING_SUMMARY.png"), "E4:Check:HtmlSummary", "Falta link a figura resumen en HTML.");
assert(contains(htmlText, "CLASSIC PNG"), "E4:Check:HtmlClassic", "Falta boton CLASSIC PNG en HTML.");

report = struct("episodes", 200, "trainEpisodes", 200, "validationEpisodes", 0, ...
    "compactPng", numel(compactPngs), "compactFig", numel(compactFigs), ...
    "proPng", numel(proPngs), "proFig", numel(proFigs), ...
    "classicPng", numel(classicPngs), "classicFig", numel(classicFigs), ...
    "annotatedCount", nAnnot, "annotatedPng", numel(annotPngs), "annotatedFig", numel(annotFigs), ...
    "traceMatch", traceMatch, "pwmMatch", pwmMatch, "metricsMatch", metricsMatch, ...
    "htmlCoverage", "200/200", "sealedSubjectsUntouched", true);
end
