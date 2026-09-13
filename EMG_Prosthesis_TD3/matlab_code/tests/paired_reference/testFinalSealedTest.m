function tests = testFinalSealedTest
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
addpath(fullfile(root, "analysis", "paired_reference", "cap192"));
addpath(fullfile(root, "analysis", "paired_reference", "sealed"));
addpath(fullfile(root, "config"));
end

function testFinalAgentHashIntact(t)
root = t.TestData.root;
e4Run = fullfile(root, "results", "e4_final_development", "run_20260910_084228_108_8176e5a9");
agentFile = fullfile(e4Run, "FINAL_AGENT.mat");
verifyTrue(t, isfile(agentFile));
sha = cap192SHA256(agentFile);
verifyEqual(t, sha, "2aa39fdf166c62fb6da057f1ddecb6455fbaa142f476718dd4e2725dfde08c90");
end

function testPreregistrationIntact(t)
root = t.TestData.root;
repoRoot = fileparts(root);
prereg = fullfile(repoRoot, "docs", "paired_reference", "PREREGISTRO_FINAL_SEALED_TEST.md");
verifyTrue(t, isfile(prereg));
txt = string(fileread(prereg));
verifyTrue(t, contains(txt, "MATEO"));
verifyTrue(t, contains(txt, "SANDRA"));
verifyTrue(t, contains(txt, "Agent7250"));
verifyTrue(t, contains(txt, "FINAL E4"));
end

function testSealedDataStructure(t)
root = t.TestData.root;
mPath = fullfile(root, "data", "datasets", "Denis Dataset", "MATEO.mat");
sPath = fullfile(root, "data", "datasets", "Denis Dataset", "SANDRA.mat");
verifyTrue(t, isfile(mPath));
verifyTrue(t, isfile(sPath));
end
