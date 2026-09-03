function tests = testNoGloveStage7uMotionPermissionAblation
%testNoGloveStage7uMotionPermissionAblation deterministic ETAPA 7U tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
testDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(fileparts(testDir));
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
end

function testGatingZeroesRestPwmWhenGateAlwaysInactive(testCase)
data = restOnlyFixture(false(2, 20), true(2, 20));
analysis = analyzeNoGloveStage7uMotionPermission(data);
testCase.verifyTrue(analysis.restGateActiveAllFalse);
testCase.verifyEqual(analysis.restSummary.gated.restPWMNonZeroFraction, 0);
testCase.verifyEqual( ...
    analysis.restSummary.gated.firstStepUnsolicitedPWMFraction, 0);
testCase.verifyEqual(analysis.restSummary.gated.safetyInterventionCount, 0);
% u_actor_raw must be reported unchanged - the actor is never "fixed".
testCase.verifyGreaterThan(analysis.restSummary.baseline.actionL2Raw, 0);
testCase.verifyEqual(analysis.restSummary.baseline.actionL2Raw, ...
    mean(analysis.restTable.rawAction.^2));
end

function testRestCohortFailsClosedWhenGateActiveTrue(testCase)
gateActive = false(2, 20);
gateActive(1, 5) = true; % violates the ETAPA 7S design assumption
data = restOnlyFixture(gateActive, true(2, 20));
analysis = analyzeNoGloveStage7uMotionPermission(data);
testCase.verifyFalse(analysis.restGateActiveAllFalse);
testCase.verifyTrue(all(isnan(analysis.restTable.safetyGated)));
testCase.verifyNotEqual(analysis.improvementValidated, "YES");
end

function testAcceptanceCohortZeroFalseInhibitionWhenGateObeyed(testCase)
data = acceptanceOnlyFixture(true);
analysis = analyzeNoGloveStage7uMotionPermission(data);
testCase.verifyTrue(analysis.acceptanceSummary.falseInhibitionExactlyZero);
testCase.verifyEqual(analysis.acceptanceSummary.falseInhibitionStepCount, 0);
testCase.verifyEqual(height(analysis.falseInhibitionViolations), 0);
end

function testAcceptanceCohortDetectsFalseInhibitionViolation(testCase)
data = acceptanceOnlyFixture(false);
analysis = analyzeNoGloveStage7uMotionPermission(data);
testCase.verifyFalse(analysis.acceptanceSummary.falseInhibitionExactlyZero);
testCase.verifyGreaterThan(analysis.acceptanceSummary.falseInhibitionStepCount, 0);
testCase.verifyGreaterThan(height(analysis.falseInhibitionViolations), 0);
end

function testActiveWindowPwmIsUnchangedByConstruction(testCase)
data = acceptanceOnlyFixture(true);
analysis = analyzeNoGloveStage7uMotionPermission(data);
active = analysis.acceptanceStepTable.gateActive;
testCase.verifyEqual( ...
    analysis.acceptanceStepTable.meanAbsPwmGated(active), ...
    analysis.acceptanceStepTable.meanAbsPwmBaseline(active), "AbsTol", 1e-12);
end

function testInvalidEvidenceRejected(testCase)
data = restOnlyFixture(false(2, 20), true(2, 20));
data.actorLoaded = true;
testCase.verifyError(@() analyzeNoGloveStage7uMotionPermission(data), ...
    "analyzeNoGloveStage7uMotionPermission:InvalidEvidence");
end

function data = restOnlyFixture(gateActive, nonzeroPwmMask)
% gateActive, nonzeroPwmMask: episodeCount-by-20 logical.
[episodeCount, stepCount] = size(gateActive);
rng(11);
rows = episodeCount * stepCount;
states = zeros(rows, 60);
episode = zeros(rows, 1);
step = zeros(rows, 1);
rawAction = zeros(rows, 4);
effectiveAction = zeros(rows, 4);
pwm = zeros(rows, 4);
safetyIntervention = zeros(rows, 4);
restGateActive = cell(episodeCount, 1);

row = 0;
for e = 1:episodeCount
    prevEffective = zeros(1, 4);
    restGateActive{e} = gateActive(e, :)';
    for s = 1:stepCount
        row = row + 1;
        episode(row) = e;
        step(row) = s;
        states(row, 49:52) = prevEffective;
        raw = (rand(1, 4) - 0.3) * 0.9;
        rawAction(row, :) = raw;
        if nonzeroPwmMask(e, s)
            eff = sign(raw) .* max(abs(raw), 0.3);
            pwmValue = round(eff * 255 / 64) * 64;
        else
            eff = zeros(1, 4);
            pwmValue = zeros(1, 4);
        end
        effectiveAction(row, :) = eff;
        pwm(row, :) = pwmValue;
        safetyIntervention(row, :) = double(any(abs(eff) >= 0.95, "all")) * ones(1, 4);
        prevEffective = eff;
    end
end

metadata = table(repmat("steadyRest", rows, 1), episode, step, ...
    'VariableNames', ["source", "episode", "step"]);
corpus = struct("states", states, "metadata", metadata, ...
    "rawAction", rawAction, "effectiveAction", effectiveAction, ...
    "pwm", pwm, "safetyIntervention", safetyIntervention);
restEpisodeInventory = table((1:episodeCount)', ...
    'VariableNames', "episode");

data = struct( ...
    "restEvidence", struct("corpus", corpus, ...
        "restEpisodeInventory", restEpisodeInventory), ...
    "restGateActive", {restGateActive}, ...
    "acceptanceEpisodes", emptyAcceptanceEpisodes(), ...
    "actorLoaded", false, "actorRetrained", false, ...
    "environmentUsed", false, "simulationUsed", false, ...
    "trainingUsed", false, "hardwareUsed", false);
end

function data = acceptanceOnlyFixture(referenceObeysGate)
rng(11);
stepCount = 10;
gateActive = false(stepCount, 1);
gateActive(4:7) = true; % one active window in the middle
referenceHistory = zeros(stepCount, 4);
for t = 2:stepCount
    if gateActive(t) || ~referenceObeysGate && t == 3
        referenceHistory(t, :) = referenceHistory(t-1, :) + 0.05;
    else
        referenceHistory(t, :) = referenceHistory(t-1, :);
    end
end
rawAction = (rand(stepCount, 4) - 0.3) * 0.9;
effectiveAction = zeros(stepCount, 4);
effectiveAction(gateActive, :) = rawAction(gateActive, :);
% Also give rest-phase steps some baseline nonzero PWM (the phenomenon
% under test), independent of referenceObeysGate.
restRows = find(~gateActive);
effectiveAction(restRows, :) = 0.4 * sign(rawAction(restRows, :));
pwm = round(effectiveAction * 255 / 64) * 64;
trackingMse = rand(stepCount, 1) * 0.01;
trackingMae = sqrt(trackingMse);

episodeStruct = struct( ...
    "episode", 1, "filePath", "fixture", "stepCount", stepCount, ...
    "rawAction", rawAction, "effectiveAction", effectiveAction, ...
    "pwm", pwm, "gateActive", gateActive, ...
    "trackingMse", trackingMse, "trackingMae", trackingMae, ...
    "referenceHistory", referenceHistory, ...
    "trackingPredictionHistory", referenceHistory, ...
    "safetyIntervention", zeros(stepCount, 4));

data = struct( ...
    "restEvidence", struct( ...
        "corpus", struct("states", zeros(0, 60), ...
        "metadata", table(strings(0, 1), zeros(0, 1), zeros(0, 1), ...
        'VariableNames', ["source", "episode", "step"]), ...
        "rawAction", zeros(0, 4), "effectiveAction", zeros(0, 4), ...
        "pwm", zeros(0, 4), "safetyIntervention", zeros(0, 4)), ...
        "restEpisodeInventory", table(zeros(0, 1), 'VariableNames', "episode")), ...
    "restGateActive", {{}}, ...
    "acceptanceEpisodes", episodeStruct, ...
    "actorLoaded", false, "actorRetrained", false, ...
    "environmentUsed", false, "simulationUsed", false, ...
    "trainingUsed", false, "hardwareUsed", false);
end

function value = emptyAcceptanceEpisodes()
value = repmat(struct( ...
    "episode", 0, "filePath", "", "stepCount", 0, ...
    "rawAction", zeros(0, 4), "effectiveAction", zeros(0, 4), ...
    "pwm", zeros(0, 4), "gateActive", false(0, 1), ...
    "trackingMse", zeros(0, 1), "trackingMae", zeros(0, 1), ...
    "referenceHistory", zeros(0, 4), ...
    "trackingPredictionHistory", zeros(0, 4), ...
    "safetyIntervention", zeros(0, 4)), 0, 1);
end
