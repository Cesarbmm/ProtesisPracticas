function tests = testE3EDomainAudit()
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.cfg = e3eConfig();
pr = t.TestData.cfg.pr;
root = t.TestData.cfg.root;
addpath(pr, t.TestData.cfg.here, fullfile(pr, "e3d"), fullfile(pr, "e3c"), fullfile(pr, "e3b"), fullfile(pr, "e3ax"), fullfile(root, "config"));
addpath(genpath(fullfile(root, "src")));
addpath(genpath(fullfile(root, "lib")));
t.TestData.sum = jsondecode(fileread(fullfile(t.TestData.cfg.output, "scientific_summary.json")));
t.TestData.cov = jsondecode(fileread(fullfile(t.TestData.cfg.output, "coverage_summary.json")));
t.TestData.init = jsondecode(fileread(fullfile(t.TestData.cfg.output, "initial_window_summary.json")));
t.TestData.vDec = jsondecode(fileread(fullfile(t.TestData.cfg.output, "variance_summary.json")));
t.TestData.norm = load(fullfile(t.TestData.cfg.output, "train_robust_normalization_params.mat"), "normParams");
end

function testE3EDataCoverageBalanced(t)
c = t.TestData.cov;
verifyFalse(t, c.DATA_COVERAGE_PROBLEM);
verifyEqual(t, c.OPENING_DATA_COVERAGE, 1468);
verifyEqual(t, c.CLOSING_DATA_COVERAGE, 1470);
verifyEqual(t, c.VAL_OPENING_SAMPLES, 431);
verifyEqual(t, c.VAL_CLOSING_SAMPLES, 431);
verifyEqual(t, c.VAL_IMBALANCE, 1.0, AbsTol=1e-6);
end

function testE3EInitialWindowUnstable(t)
w = t.TestData.init;
verifyFalse(t, w.INITIAL_WINDOW_STABLE);
verifyEqual(t, w.N1_fracSigOpenClose, 1.0, AbsTol=1e-6);
verifyGreaterThan(t, w.N1_meanDiffOpenClose, 0.50);
end

function testE3ESubjectVarianceDominance(t)
v = t.TestData.vDec;
verifyEqual(t, v.NUM_FEATURES_SUBJECT_DOMINANT, 40);
verifyGreaterThan(t, v.SUBJECT_TO_INTENT_VARIANCE_RATIO_MEAN, 50.0);
verifyGreaterThan(t, v.SUBJECT_TO_INTENT_VARIANCE_RATIO_MEDIAN, 15.0);
verifyGreaterThan(t, v.ETA2_SUBJECT_MEAN, 0.25);
verifyLessThan(t, v.ETA2_INTENT_MEAN, 0.01);
end

function testE3ESubjectIDProbeHighAccuracy(t)
s = t.TestData.sum;
verifyGreaterThan(t, s.subjectID_original.SUBJECT_ID_ACCURACY, 0.70);
verifyGreaterThan(t, s.subjectID_original.SUBJECT_ID_MACRO_F1, 0.70);
verifyEqual(t, s.subjectID_original.CHANCE_LEVEL, 1/7, AbsTol=1e-6);
% Gate A falló porque normalized aumentó predictibilidad
verifyGreaterThan(t, s.subjectID_normalized.SUBJECT_ID_ACCURACY, s.subjectID_original.SUBJECT_ID_ACCURACY);
end

function testE3ENormalizationTrainOnly(t)
p = t.TestData.norm.normParams;
verifyTrue(t, p.causal_deployable);
verifyEqual(t, p.train_samples_used, 2076);
verifyEqual(t, p.val_samples_used, 0);
verifyEqual(t, numel(p.median_train), 40);
verifyEqual(t, numel(p.mad_train), 40);
verifyTrue(t, all(isfinite(p.median_train)));
verifyTrue(t, all(isfinite(p.mad_train)));
verifyTrue(t, all(p.mad_train >= p.epsilon));
end

function testE3ECausalActorContract(t)
p = t.TestData.norm.normParams;
net = e3dNetwork("BASELINE");
actor = E3ENormalizedProbeActor(net, p.median_train, p.mad_train, p.epsilon);
u = getAction(actor, {zeros(52, 1)});
verifyTrue(t, all(ismember(u{1}*255, t.TestData.cfg.categories)));
reset(actor);
verifyEmpty(t, actor.Probabilities);
verifyEmpty(t, actor.Categories);
end

function testE3EGatesMatchPreregistration(t)
s = t.TestData.sum;
g = s.gates;
verifyFalse(t, s.NORMALIZATION_SUPPORTED);
verifyFalse(t, g.A_subject_id_reduction);
verifyTrue(t, g.B_direction_F1_no_worse);
verifyFalse(t, g.C_phase_direction_F1_no_worse);
verifyFalse(t, g.D_train_val_gap_decreases);
verifyFalse(t, g.E_opening_MSE_improves_10pct);
verifyTrue(t, g.F_closing_MSE_no_worse_5pct);
verifyTrue(t, g.G_global_MSE_improves);
verifyTrue(t, g.H_zero_cycles_periodicities);
verifyTrue(t, g.I_m3_reversals_no_material_increase);
verifyTrue(t, g.J_max_category_fraction);
verifyTrue(t, g.K_causal_for_new_subject);
end

function testE3EHistoricalIntegrity(t)
integ = jsondecode(fileread(fullfile(t.TestData.cfg.output, "integrity_after.json")));
verifyTrue(t, integ.pass);
verifyEqual(t, numel(integ.failures), 0);
verifyEqual(t, integ.files, 7529);
end

function testE3ESealedSubjectsNeverOpened(t)
cfg = t.TestData.cfg;
for sub = cfg.sealedSubjects
    verifyFalse(t, isfolder(fullfile(cfg.root, "data", sub)));
    verifyFalse(t, isfile(fullfile(cfg.output, sprintf("%s.csv", sub))));
end
S = load(cfg.dataPath, "D").D.samples;
verifyFalse(t, any(ismember(unique(S.subject), cfg.sealedSubjects)));
end
