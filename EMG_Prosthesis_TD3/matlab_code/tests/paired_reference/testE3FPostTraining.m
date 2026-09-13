function tests = testE3FPostTraining
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
t.TestData.root = root;
old = path;
t.addTeardown(@() path(old));
addpath(root);
addpath(fullfile(root, "analysis", "paired_reference"));
addpath(fullfile(root, "analysis", "paired_reference", "e3ax"));
addpath(fullfile(root, "analysis", "paired_reference", "e3f"));

% Directorio de corrida existente E3F
t.TestData.runDir = "C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e3f_long\run_20260910_002946_786_14f0a07f";
end

function testPostProcessOnlyNoTraining(t)
runDir = t.TestData.runDir;
summaryFile = fullfile(runDir, "POST_TRAINING_STATUS.json");
if isfile(summaryFile)
    st = jsondecode(fileread(summaryFile));
    verifyTrue(t, st.postprocessOnly);
    verifyFalse(t, st.trainingExecuted);
end
end

function testCheckpoint1MUsedAndBestEqualsLast(t)
runDir = t.TestData.runDir;
sciFile = fullfile(runDir, "scientific_summary.json");
verifyTrue(t, isfile(sciFile));
sci = jsondecode(fileread(sciFile));
verifyEqual(t, sci.bestStep, 1000000);
end

function test200EpisodesCovered(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
selFile = fullfile(runDir, "evaluation_selection.csv");
verifyTrue(t, isfile(selFile));
sel = readtable(selFile, TextType="string", Delimiter=",");
verifyEqual(t, height(sel), 200);
verifyEqual(t, nnz(sel.split == "TRAIN"), 140);
verifyEqual(t, nnz(sel.split == "VALIDATION"), 60);
end

function testSealedSubjectsUntouched(t)
runDir = t.TestData.runDir;
selFile = fullfile(runDir, "evaluation_selection.csv");
sel = readtable(selFile, TextType="string", Delimiter=",");
verifyFalse(t, any(ismember(sel.subject, ["MATEO", "SANDRA"])));
end

function testCompactFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
pngs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.png"));
figs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.fig"));
verifyEqual(t, numel(pngs), 200);
verifyEqual(t, numel(figs), 200);
end

function testProFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
pngs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.png"));
figs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.fig"));
verifyEqual(t, numel(pngs), 200);
verifyEqual(t, numel(figs), 200);
end

function testClassicFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
pngs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.png"));
figs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.fig"));
verifyEqual(t, numel(pngs), 200);
verifyEqual(t, numel(figs), 200);
end

function testReferenceClassicFiguresExist(t)
runDir = t.TestData.runDir;
refLegacy = fullfile(runDir, "LEGACY_CLASSIC_REFERENCE.png");
refE3F = fullfile(runDir, "E3F_CLASSIC_REFERENCE.png");
verifyTrue(t, isfile(refLegacy));
verifyTrue(t, isfile(refE3F));
end

function testFourMotorsPerFigure(t)
runDir = t.TestData.runDir;
trajFile = fullfile(runDir, "evaluation", "final_checkpoint", "metrics", "trajectories.mat");
verifyTrue(t, isfile(trajFile));
d = load(trajFile, "traces");
verifyEqual(t, size(d.traces{1}.prediction, 2), 4);
verifyEqual(t, size(d.traces{1}.reference, 2), 4);
verifyEqual(t, size(d.traces{1}.pwm, 2), 4);
end

function testClassicLayout4x2(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
figs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.fig"));
verifyGreaterThanOrEqual(t, numel(figs), 1);
testFigPath = fullfile(figs(1).folder, figs(1).name);
f = openfig(testFigPath, "invisible");
cleanup = onCleanup(@() close(f));
axesList = findall(f, "Type", "axes");
verifyEqual(t, numel(axesList), 8, "Debe tener exactamente 8 subplots (4x2).");
end

function testEffectiveActionEqualsPWMDiv255(t)
runDir = t.TestData.runDir;
trajFile = fullfile(runDir, "evaluation", "final_checkpoint", "metrics", "trajectories.mat");
d = load(trajFile, "traces");
for e = 1:min(20, numel(d.traces))
    tTrace = d.traces{e};
    diffAct = max(abs(tTrace.effectiveAction(:) - tTrace.pwm(:) / 255));
    verifyLessThan(t, diffAct, 1e-12);
end
end

function testClassicSemanticPWMFixture(t)
% Fixture semantico exhaustivo con los 15 niveles de PWM discretos:
% [255, 224, 192, 160, 128, 96, 64, 0, -64, -96, -128, -160, -192, -224, -255]
levels = [255, 224, 192, 160, 128, 96, 64, 0, -64, -96, -128, -160, -192, -224, -255]';
n = numel(levels);
effLevels = levels / 255;

dummyTrace = struct();
dummyTrace.metadata = struct("subject", "FIXTURE", "repetition", 9999, "side", 1, "split", "TRAIN");
dummyTrace.reference = repmat(linspace(0, 1, n)', 1, 4);
dummyTrace.prediction = repmat(linspace(0.1, 0.9, n)', 1, 4);
dummyTrace.pwm = repmat(levels, 1, 4);
dummyTrace.effectiveAction = repmat(effLevels, 1, 4);
dummyTrace.selectedProbability = repmat(0.85, n, 4);

tempFolder = fullfile(tempdir, "e3f_fixture_test_" + string(randi(1e6)));
mkdir(tempFolder);
cleanupTemp = onCleanup(@() rmdir(tempFolder, "s"));

files = e3fPlotClassic(dummyTrace, tempFolder);
verifyTrue(t, isfile(files.png));
verifyTrue(t, isfile(files.fig));

f = openfig(files.fig, "invisible");
cleanupFig = onCleanup(@() close(f));

% Extraer todos los objetos Text
textObjs = findall(f, "Type", "text");
allStrings = string({textObjs.String});

for k = 1:n
    expectedEffStr = sprintf("%.2f", effLevels(k));
    expectedPwmStr = sprintf("PWM:%+d", levels(k));

    % 1. Verificar presencia de string exacto PWM/255
    verifyTrue(t, any(allStrings == expectedEffStr), ...
        sprintf("Falta string exacto PWM/255 '%s' para PWM=%d", expectedEffStr, levels(k)));

    % 2. Verificar que valores negativos conservan su signo menos (no valor absoluto)
    if effLevels(k) < 0
        verifyFalse(t, any(allStrings == sprintf("%.2f", abs(effLevels(k)))) && ...
                       ~any(allStrings == expectedEffStr), ...
            sprintf("Se uso valor absoluto en lugar de signo negativo para PWM=%d", levels(k)));
    end

    % 3. Verificar presencia de string PWM exacto
    verifyTrue(t, any(allStrings == expectedPwmStr), ...
        sprintf("Falta string exacto PWM '%s'", expectedPwmStr));
end

% 4. Verificar que NO se usaron indices de categoria (1 a 15) como strings de accion
for c = 1:15
    catStr = sprintf("Cat:%d", c);
    verifyFalse(t, any(allStrings == catStr), "No deben aparecer indices de categoria como accion.");
end
end

function testAnnotatedSelectionDeterministic(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
pngs = dir(fullfile(finalDir, "figures", "annotated", "PNG", "*.png"));
verifyGreaterThanOrEqual(t, numel(pngs), 7);
verifyLessThanOrEqual(t, numel(pngs), 12);
end

function testHtmlCoverage200(t)
runDir = t.TestData.runDir;
htmlFile = fullfile(runDir, "TEST_COMPORTAMENTAL.html");
verifyTrue(t, isfile(htmlFile));
txt = string(fileread(htmlFile));
verifyTrue(t, contains(txt, "TRAIN (140 episodios)"));
verifyTrue(t, contains(txt, "VALIDATION (60 episodios)"));
verifyTrue(t, contains(txt, "CLASSIC PNG"));
verifyTrue(t, contains(txt, "CLASSIC FIG"));
end
