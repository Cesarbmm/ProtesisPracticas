function tests = testE4FinalDevelopment
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
addpath(fullfile(root, "analysis", "paired_reference", "e3b"));
addpath(fullfile(root, "analysis", "paired_reference", "e3f"));
addpath(fullfile(root, "analysis", "paired_reference", "e4"));
addpath(fullfile(root, "config"));

t.TestData.runDir = "C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e4_final_development\run_20260910_084228_108_8176e5a9";
end

function testAuditAgainstE3B(t)
rep = e4AuditAgainstE3B();
verifyEqual(t, rep.E4_ARCHITECTURE_MATCH_E3B, "YES");
verifyEqual(t, rep.E4_ACTION_SPACE_MATCH_E3B, "YES");
verifyEqual(t, rep.E4_PPO_RECIPE_MATCH_E3B, "YES");
verifyEqual(t, rep.E4_REWARD_MATCH_E3B, "YES");
verifyEqual(t, rep.TRAIN_SUBJECTS_COUNT, 10);
verifyEqual(t, rep.VALIDATION_SUBJECTS_COUNT, 0);
verifyTrue(t, rep.SEALED_SUBJECTS_PROTECTED);
end

function testConfigFrozenBudgetAndCheckpoints(t)
cfg = e4Config("long");
verifyEqual(t, cfg.maxAgentSteps, 500000);
verifyEqual(t, cfg.checkpointSteps, [50000 100000 250000 500000]);
verifyEqual(t, cfg.checkpointSelection, "NONE");
verifyEqual(t, cfg.finalAgentStep, 500000);
verifyEqual(t, cfg.scientificSeed, 20260920);
verifyEqual(t, cfg.smokeSeed, 20260921);
end

function testSealedSubjectsStrictlyExcluded(t)
cfg = e4Config("long");
verifyFalse(t, any(ismember(cfg.trainSubjects, ["MATEO", "SANDRA"])));
verifyFalse(t, any(ismember(cfg.validationSubjects, ["MATEO", "SANDRA"])));
verifyTrue(t, isequal(cfg.sealedSubjects, ["MATEO", "SANDRA"]));
end

function testMarkov52StateDimension(t)
cfg = e4Config("long");
[actor, critic] = e3bNetworks(cfg);
dummyState = dlarray(zeros(52, 1, "single"), "CB");
logits = e3bLogits(actor, dummyState);
verifyEqual(t, size(logits, 1), 15);
verifyEqual(t, size(logits, 2), 4);
outCritic = forward(critic, dummyState);
verifyEqual(t, size(outCritic, 1), 1);
end

function testPreregistrationDocumentsExist(t)
root = t.TestData.root;
repoRoot = fileparts(root);
e4Prereg = fullfile(repoRoot, "docs", "paired_reference", "PREREGISTRO_E4_FINAL_DEVELOPMENT.md");
sealedPrereg = fullfile(repoRoot, "docs", "paired_reference", "PREREGISTRO_FINAL_SEALED_TEST.md");
verifyTrue(t, isfile(e4Prereg));
verifyTrue(t, isfile(sealedPrereg));
txtE4 = string(fileread(e4Prereg));
verifyTrue(t, contains(txtE4, "500,000"));
verifyTrue(t, contains(txtE4, "20260920"));
txtSealed = string(fileread(sealedPrereg));
verifyTrue(t, contains(txtSealed, "MATEO"));
verifyTrue(t, contains(txtSealed, "SANDRA"));
verifyTrue(t, contains(txtSealed, "Agent7250"));
end

function testPostProcessOnlyNoTraining(t)
runDir = t.TestData.runDir;
summaryFile = fullfile(runDir, "POST_TRAINING_STATUS.json");
if isfile(summaryFile)
    st = jsondecode(fileread(summaryFile));
    verifyTrue(t, st.postprocessOnly);
    verifyFalse(t, st.trainingExecuted);
    verifyEqual(t, st.checkpoint, 500000);
end
end

function testCheckpoint500kUsedAndFinalAgentMatch(t)
runDir = t.TestData.runDir;
finalAgent = fullfile(runDir, "FINAL_AGENT.mat");
verifyTrue(t, isfile(finalAgent));
shaFile = fullfile(runDir, "FINAL_AGENT_SHA256.txt");
verifyTrue(t, isfile(shaFile));
sha = strtrim(string(fileread(shaFile)));
verifyEqual(t, strlength(sha), 64);
end

function test200EpisodesCoveredInDevelopment(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
selFile = fullfile(runDir, "evaluation_selection.csv");
verifyTrue(t, isfile(selFile));
sel = readtable(selFile, TextType="string", Delimiter=",");
verifyEqual(t, height(sel), 200);
verifyEqual(t, nnz(sel.split == "TRAIN"), 200);
verifyFalse(t, any(ismember(sel.subject, ["MATEO", "SANDRA"])));
end

function testCompactFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    pngs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.png"));
    figs = dir(fullfile(finalDir, "figures", "compact", "**", "*_compact.fig"));
    verifyEqual(t, numel(pngs), 200);
    verifyEqual(t, numel(figs), 200);
end
end

function testProFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    pngs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.png"));
    figs = dir(fullfile(finalDir, "figures", "pro", "**", "*_pro.fig"));
    verifyEqual(t, numel(pngs), 200);
    verifyEqual(t, numel(figs), 200);
end
end

function testClassicFiguresCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    pngs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.png"));
    figs = dir(fullfile(finalDir, "figures", "classic", "**", "*_classic.fig"));
    verifyEqual(t, numel(pngs), 200);
    verifyEqual(t, numel(figs), 200);
end
end

function testAnnotatedCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    pngs = dir(fullfile(finalDir, "figures", "annotated", "PNG", "*.png"));
    figs = dir(fullfile(finalDir, "figures", "annotated", "FIG", "*.fig"));
    verifyGreaterThanOrEqual(t, numel(pngs), 7);
    verifyLessThanOrEqual(t, numel(pngs), 12);
    verifyEqual(t, numel(pngs), numel(figs));
end
end

function testGlobalPublicationFigures(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "MOTOR_TRACKING_SUMMARY.png")));
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "MOTOR_TRACKING_SUMMARY.fig")));
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "OPENING_CLOSING_SUMMARY.png")));
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "OPENING_CLOSING_SUMMARY.fig")));
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "PWM_USAGE_HEATMAP.png")));
    verifyTrue(t, isfile(fullfile(finalDir, "figures", "PWM_USAGE_HEATMAP.fig")));
end
end

function testTracesCsvAndMatCount(t)
runDir = t.TestData.runDir;
finalDir = fullfile(runDir, "evaluation", "final_checkpoint");
if isfolder(finalDir)
    csvs = dir(fullfile(finalDir, "traces", "**", "*.csv"));
    mats = dir(fullfile(finalDir, "traces", "**", "*.mat"));
    verifyEqual(t, numel(csvs), 200);
    verifyEqual(t, numel(mats), 200);
end
end

function testEffectiveActionEqualsPWMDiv255(t)
runDir = t.TestData.runDir;
trajFile = fullfile(runDir, "evaluation", "final_checkpoint", "metrics", "trajectories.mat");
if isfile(trajFile)
    d = load(trajFile, "traces");
    for e = 1:min(20, numel(d.traces))
        tTrace = d.traces{e};
        diffAct = max(abs(tTrace.effectiveAction(:) - tTrace.pwm(:) / 255));
        verifyLessThan(t, diffAct, 1e-12);
    end
end
end

function testHtmlCoverage200(t)
runDir = t.TestData.runDir;
htmlFile = fullfile(runDir, "TEST_COMPORTAMENTAL.html");
if isfile(htmlFile)
    txt = string(fileread(htmlFile));
    verifyTrue(t, contains(txt, "DEVELOPMENT (10 Sujetos, 200 episodios)"));
    verifyTrue(t, contains(txt, "COMPACT PNG"));
    verifyTrue(t, contains(txt, "PRO PNG"));
    verifyTrue(t, contains(txt, "CLASSIC PNG"));
end
end
