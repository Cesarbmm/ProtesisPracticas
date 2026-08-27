function analysis = analyzeNoGloveStage7cRestCommands( ...
        episodes, protocolTable, matchedPTable, actorEvaluator, ...
        controller, actuator, options)
%analyzeNoGloveStage7cRestCommands attributes frozen-actor rest commands.
%
% Only observations already recorded in ETAPA 7B are used. Single-block
% interventions borrow an observed block from another pre-rest state in the
% same episode and select the donor with the closest complementary state.
% These local sensitivities do not constitute a root-cause claim.

arguments
    episodes struct
    protocolTable table
    matchedPTable table
    actorEvaluator function_handle
    controller struct
    actuator struct
    options.preRestWindows (1, 1) double ...
        {mustBeInteger, mustBePositive} = 8
    options.periodSec (1, 1) double {mustBePositive} = 0.2
    options.replayTolerance (1, 1) double {mustBeNonnegative} = 1e-12
    options.stateTolerance (1, 1) double {mustBeNonnegative} = 1e-12
    options.minimumDonorBlockDistance (1, 1) double ...
        {mustBeNonnegative} = 1e-12
    options.maximumComplementDistance (1, 1) double ...
        {mustBePositive} = 2.0
    options.materialRawActionDelta (1, 1) double ...
        {mustBePositive} = 0.05
    options.minimumMaterialFraction (1, 1) double ...
        {mustBeInRange(options.minimumMaterialFraction, 0, 1)} = 0.25
    options.minimumLocalCoverage (1, 1) double ...
        {mustBeInRange(options.minimumLocalCoverage, 0, 1)} = 0.75
    options.minimumIdentifiableFraction (1, 1) double ...
        {mustBeInRange(options.minimumIdentifiableFraction, 0, 1)} = 0.75
    options.falseActivationLimit (1, 1) double ...
        {mustBeInRange(options.falseActivationLimit, 0, 1)} = 0.01
    options.saturationThreshold (1, 1) double ...
        {mustBeInRange(options.saturationThreshold, 0, 1)} = 0.95
end

layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
validateTopLevelInputs(episodes, protocolTable, matchedPTable, ...
    controller, actuator, options, layout);
[rest, episodeAudit] = collectRestStates( ...
    episodes, protocolTable, options, layout);

replayedAction = evaluateHandle(actorEvaluator, rest.state);
replayError = abs(replayedAction-rest.rawAction);
if any(replayError > options.replayTolerance, "all")
    error("analyzeNoGloveStage7cRestCommands:ReplayMismatch", ...
        "Frozen actor replay differs from saved actionLog by %.17g.", ...
        max(replayError, [], "all"));
end
[replayedEffective, replayedPwm] = quantizeRows(replayedAction, actuator);
if any(abs(replayedEffective-rest.effectiveAction) > ...
        options.replayTolerance, "all") || ...
        any(abs(replayedPwm-rest.appliedPwm) > ...
        options.replayTolerance, "all")
    error("analyzeNoGloveStage7cRestCommands:QuantizationMismatch", ...
        "Pure baseline quantization does not reproduce saved commands.");
end

observedRestTable = buildObservedTable( ...
    rest, layout, options.saturationThreshold);
anchorTable = buildAnchorTable(rest, layout, options);
anchorSummary = summarizeAnchors(anchorTable);

[interventionTable, blockScaleTable] = buildInterventions( ...
    rest, actorEvaluator, actuator, layout, options);
blockSummary = summarizeInterventions(interventionTable, options);
blockDecision = summarizeBlocks(blockSummary);

[pOnAgentRaw, pOnAgentEffective, pOnAgentPwm] = ...
    evaluatePOnObservedStates(rest.state, controller, actuator, ...
    layout, options.periodSec);
controlSummary = buildControlSummary(rest, matchedPTable, ...
    pOnAgentRaw, pOnAgentEffective, pOnAgentPwm, ...
    options.preRestWindows, options.saturationThreshold);
sourceDecision = buildSourceDecision( ...
    observedRestTable, anchorTable, blockDecision, options);

analysis = struct( ...
    "schemaVersion", 1, "stage", "7C", ...
    "observationVariant", "intentMarkov60", ...
    "preRestWindows", options.preRestWindows, ...
    "periodSec", options.periodSec, ...
    "blockSwapContract", ...
        "sameEpisodeNearestComplementObservedBlock", ...
    "standardizedEmgUsedAsPhysicalAmplitude", false, ...
    "replayMaximumAbsoluteError", max(replayError, [], "all"), ...
    "replayMeanAbsoluteError", mean(replayError, "all"), ...
    "episodeAudit", episodeAudit, ...
    "observedRestTable", observedRestTable, ...
    "anchorTable", anchorTable, ...
    "anchorSummary", anchorSummary, ...
    "blockScaleTable", blockScaleTable, ...
    "interventionTable", interventionTable, ...
    "blockSummary", blockSummary, ...
    "blockDecision", blockDecision, ...
    "controlSummary", controlSummary, ...
    "sourceDecision", sourceDecision, ...
    "rootCauseIdentified", sourceDecision.rootCauseIdentified, ...
    "behavioralInterventionExecuted", false, ...
    "compensationInterventionExecuted", false, ...
    "filteredReferenceInterventionExecuted", false, ...
    "dtwCalculated", false, "dtwRewardUsed", false, ...
    "runTraining", false, "agent7250Loaded", false, ...
    "envCreated", false, "simulatorInvoked", false, ...
    "rewardInvoked", false, "hardwareUsed", false);
end

function validateTopLevelInputs(episodes, protocol, matchedP, ...
        controller, actuator, options, layout)
requiredEpisode = ["episode", "repetitionId", "side", "profileId", ...
    "stateLog", "rawAction", "effectiveAction", "appliedPwm", ...
    "referenceHistory", "positionSafetyInterventionLog", ...
    "referenceSource", "observationVariant", "stateLength"];
requiredProtocol = ["profileId", "repetitionId", "side", ...
    "synergyAxis", "directionName", "preRestWindows"];
requiredMatched = ["commandSource", "episode", "step", "motor", ...
    "rawAction", "effectiveAction", "appliedPwm", ...
    "positionViolation"];
if isempty(episodes) || ~all(isfield(episodes, cellstr(requiredEpisode)))
    error("analyzeNoGloveStage7cRestCommands:IncompleteEpisode", ...
        "episodes do not satisfy the ETAPA 7C contract.");
end
if ~all(ismember(requiredProtocol, ...
        string(protocol.Properties.VariableNames))) || ...
        ~all(ismember(requiredMatched, ...
        string(matchedP.Properties.VariableNames)))
    error("analyzeNoGloveStage7cRestCommands:MissingVariable", ...
        "Protocol or matched-P table is incomplete.");
end
if numel(episodes) ~= height(protocol) || ...
        height(unique(protocol(:, ["repetitionId", "side"]), ...
        "rows")) ~= height(protocol) || ...
        any(protocol.preRestWindows ~= options.preRestWindows)
    error("analyzeNoGloveStage7cRestCommands:ProtocolMismatch", ...
        "Every episode must have one protocol row and eight pre-rest windows.");
end
requiredController = ["type", "kp", "kd", "maxAction", ...
    "positionTolerance", "velocityTolerance"];
requiredActuator = ["maxPwm", "activationThreshold", "commandLevels"];
if layout.totalLength ~= 60 || ...
        ~all(isfield(controller, cellstr(requiredController))) || ...
        ~all(isfield(actuator, cellstr(requiredActuator)))
    error("analyzeNoGloveStage7cRestCommands:InvalidConfiguration", ...
        "State, controller or actuator configuration is invalid.");
end
if any(matchedP.positionViolation) || ...
        any(string(matchedP.commandSource) ~= "conventionalP")
    error("analyzeNoGloveStage7cRestCommands:UnsafeMatchedControl", ...
        "Matched control must be safe conventionalP data only.");
end
end

function [rest, audit] = collectRestStates( ...
        episodes, protocol, options, layout)
rowCount = numel(episodes) * options.preRestWindows;
state = nan(rowCount, layout.totalLength);
rawAction = nan(rowCount, 4);
effectiveAction = nan(rowCount, 4);
appliedPwm = nan(rowCount, 4);
safety = nan(rowCount, 4);
episodeId = zeros(rowCount, 1);
repetitionId = zeros(rowCount, 1);
side = zeros(rowCount, 1);
step = zeros(rowCount, 1);
profileId = strings(rowCount, 1);
synergyAxis = strings(rowCount, 1);
directionName = strings(rowCount, 1);
auditRows = repmat(emptyEpisodeAuditRow(), numel(episodes), 1);
cursor = 0;
for episodeIdx = 1:numel(episodes)
    value = episodes(episodeIdx);
    match = protocol.repetitionId == value.repetitionId & ...
        protocol.side == value.side & ...
        string(protocol.profileId) == string(value.profileId);
    if sum(match) ~= 1
        error("analyzeNoGloveStage7cRestCommands:ProtocolMismatch", ...
            "Episode %d does not map to one protocol row.", value.episode);
    end
    validateEpisode(value, options, layout);
    rows = cursor + (1:options.preRestWindows);
    localSteps = (1:options.preRestWindows)';
    state(rows, :) = double(value.stateLog(localSteps, :));
    rawAction(rows, :) = double(value.rawAction(localSteps, :));
    effectiveAction(rows, :) = ...
        double(value.effectiveAction(localSteps, :));
    appliedPwm(rows, :) = double(value.appliedPwm(localSteps, :));
    safety(rows, :) = ...
        double(value.positionSafetyInterventionLog(localSteps, :));
    episodeId(rows) = value.episode;
    repetitionId(rows) = value.repetitionId;
    side(rows) = value.side;
    step(rows) = localSteps;
    profileId(rows) = string(value.profileId);
    synergyAxis(rows) = string(protocol.synergyAxis(match));
    directionName(rows) = string(protocol.directionName(match));

    initialState = double(value.stateLog(1, :));
    q = initialState(layout.encoder);
    qRef = initialState(layout.referencePosition);
    dynamicIndices = [layout.deltaEncoder, ...
        layout.previousEffectiveAction, layout.referenceVelocity];
    row = emptyEpisodeAuditRow();
    row.episode = value.episode;
    row.repetitionId = value.repetitionId;
    row.side = value.side;
    row.profileId = string(value.profileId);
    row.initialPositionErrorMaxAbs = max(abs(qRef-q));
    row.initialDynamicStateMaxAbs = ...
        max(abs(initialState(dynamicIndices)));
    row.initialNonEmgStateMaxAbs = ...
        max(abs(initialState(41:60)));
    row.initialHomeAnchor = row.initialNonEmgStateMaxAbs <= ...
        options.stateTolerance;
    row.referenceVelocityPreRestMaxAbs = max(abs( ...
        value.stateLog(localSteps, layout.referenceVelocity)), [], "all");
    row.referenceDriftPreRestMaxAbs = max(abs( ...
        value.stateLog(localSteps, layout.referencePosition) - ...
        value.stateLog(1, layout.referencePosition)), [], "all");
    row.safetyInterventionCount = sum( ...
        value.positionSafetyInterventionLog(localSteps, :), "all");
    auditRows(episodeIdx) = row;
    cursor = cursor + options.preRestWindows;
end
if height(unique(table(episodeId, step), "rows")) ~= rowCount
    error("analyzeNoGloveStage7cRestCommands:DuplicateStep", ...
        "Episode-step rows must be unique.");
end
rest = struct("state", state, "rawAction", rawAction, ...
    "effectiveAction", effectiveAction, "appliedPwm", appliedPwm, ...
    "safety", safety, "episode", episodeId, ...
    "repetitionId", repetitionId, "side", side, "step", step, ...
    "profileId", profileId, "synergyAxis", synergyAxis, ...
    "directionName", directionName);
audit = struct2table(auditRows);
end

function validateEpisode(value, options, layout)
matrices = {value.stateLog, value.rawAction, value.effectiveAction, ...
    value.appliedPwm, value.referenceHistory, ...
    value.positionSafetyInterventionLog};
for matrixIdx = 1:numel(matrices)
    matrix = matrices{matrixIdx};
    if ~isnumeric(matrix) || ~isreal(matrix) || ...
            any(~isfinite(matrix), "all")
        error("analyzeNoGloveStage7cRestCommands:NonfiniteEpisode", ...
            "Episode %d contains invalid numeric data.", value.episode);
    end
end
stepCount = size(value.stateLog, 1);
if stepCount < options.preRestWindows || ...
        size(value.stateLog, 2) ~= layout.totalLength || ...
        size(value.rawAction, 1) ~= stepCount || ...
        size(value.rawAction, 2) ~= 4 || ...
        ~isequal(size(value.effectiveAction), [stepCount, 4]) || ...
        ~isequal(size(value.appliedPwm), [stepCount, 4]) || ...
        ~isequal(size(value.positionSafetyInterventionLog), [stepCount, 4]) || ...
        size(value.referenceHistory, 1) ~= stepCount || ...
        size(value.referenceHistory, 2) ~= 4
    error("analyzeNoGloveStage7cRestCommands:DimensionMismatch", ...
        "Episode %d has inconsistent dimensions.", value.episode);
end
if string(value.referenceSource) ~= "emgIntent" || ...
        string(value.observationVariant) ~= "intentMarkov60" || ...
        double(value.stateLength) ~= layout.totalLength
    error("analyzeNoGloveStage7cRestCommands:IncompatibleEpisode", ...
        "Episode %d is not an intentMarkov60 EMG-only trace.", ...
        value.episode);
end
pre = 1:options.preRestWindows;
if any(abs(value.stateLog(pre, layout.referenceVelocity)) > ...
        options.stateTolerance, "all") || ...
        any(abs(value.stateLog(pre, layout.referencePosition) - ...
        value.referenceHistory(pre, :)) > options.stateTolerance, "all") || ...
        any(abs(value.stateLog(pre, layout.referencePosition) - ...
        value.stateLog(1, layout.referencePosition)) > ...
        options.stateTolerance, "all")
    error("analyzeNoGloveStage7cRestCommands:NonrestReference", ...
        "Episode %d reference is not a causal hold during pre-rest.", ...
        value.episode);
end
if options.preRestWindows > 1
    expectedPreviousAction = value.effectiveAction( ...
        1:options.preRestWindows-1, :);
    observedPreviousAction = value.stateLog( ...
        2:options.preRestWindows, layout.previousEffectiveAction);
    expectedDeltaEncoder = max(-1, min(1, ...
        diff(value.stateLog(1:options.preRestWindows, ...
        layout.encoder), 1, 1)));
    observedDeltaEncoder = value.stateLog( ...
        2:options.preRestWindows, layout.deltaEncoder);
    if any(abs(observedPreviousAction-expectedPreviousAction) > ...
            options.stateTolerance, "all") || ...
            any(abs(observedDeltaEncoder-expectedDeltaEncoder) > ...
            options.stateTolerance, "all")
        error("analyzeNoGloveStage7cRestCommands:TemporalMismatch", ...
            "Episode %d violates action or encoder state alignment.", ...
            value.episode);
    end
end
initial = value.stateLog(1, :);
if any(abs(initial(layout.encoder)- ...
        initial(layout.referencePosition)) > options.stateTolerance) || ...
        any(abs(initial([layout.deltaEncoder, ...
        layout.previousEffectiveAction, layout.referenceVelocity])) > ...
        options.stateTolerance)
    error("analyzeNoGloveStage7cRestCommands:InvalidInitialAnchor", ...
        "Episode %d initial state is not a zero-error dynamic anchor.", ...
        value.episode);
end
end

function actions = evaluateHandle(actorEvaluator, states)
actions = actorEvaluator(double(states));
if ~isnumeric(actions) || ~isreal(actions) || ...
        ~isequal(size(actions), [size(states, 1), 4]) || ...
        any(~isfinite(actions), "all") || any(abs(actions) > 1+1e-12, "all")
    error("analyzeNoGloveStage7cRestCommands:InvalidActorOutput", ...
        "actorEvaluator must return finite N-by-4 actions in [-1,1].");
end
actions = double(actions);
end

function [effective, pwm] = quantizeRows(raw, actuator)
effective = nan(size(raw));
pwm = nan(size(raw));
for rowIdx = 1:size(raw, 1)
    [effectiveRow, pwmRow] = quantizeBaselineAction( ...
        raw(rowIdx, :), actuator.maxPwm, ...
        actuator.activationThreshold, actuator.commandLevels);
    effective(rowIdx, :) = effectiveRow';
    pwm(rowIdx, :) = pwmRow';
end
end

function tableValue = buildObservedTable(rest, layout, saturationThreshold)
rowCount = size(rest.state, 1) * 4;
rows = repmat(emptyObservedRow(), rowCount, 1);
cursor = 0;
for stateIdx = 1:size(rest.state, 1)
    state = rest.state(stateIdx, :);
    for motor = 1:4
        cursor = cursor + 1;
        row = emptyObservedRow();
        row.episode = rest.episode(stateIdx);
        row.repetitionId = rest.repetitionId(stateIdx);
        row.side = rest.side(stateIdx);
        row.profileId = rest.profileId(stateIdx);
        row.synergyAxis = rest.synergyAxis(stateIdx);
        row.directionName = rest.directionName(stateIdx);
        row.step = rest.step(stateIdx);
        row.motor = motor;
        row.encoder = state(layout.encoder(motor));
        row.deltaEncoder = state(layout.deltaEncoder(motor));
        row.previousEffectiveAction = ...
            state(layout.previousEffectiveAction(motor));
        row.referencePosition = ...
            state(layout.referencePosition(motor));
        row.referenceVelocity = ...
            state(layout.referenceVelocity(motor));
        row.positionError = row.referencePosition-row.encoder;
        row.rawAction = rest.rawAction(stateIdx, motor);
        row.effectiveAction = rest.effectiveAction(stateIdx, motor);
        row.appliedPwm = rest.appliedPwm(stateIdx, motor);
        row.commandActive = abs(row.appliedPwm) > 0;
        row.saturated = abs(row.effectiveAction) >= saturationThreshold;
        row.safetyInterventionCount = rest.safety(stateIdx, motor);
        rows(cursor) = row;
    end
end
tableValue = struct2table(rows);
end

function anchors = buildAnchorTable(rest, layout, options)
initialRows = find(rest.step == 1);
rows = repmat(emptyAnchorRow(), numel(initialRows)*4, 1);
cursor = 0;
for initialIdx = 1:numel(initialRows)
    stateIdx = initialRows(initialIdx);
    state = rest.state(stateIdx, :);
    home = max(abs(state(41:60))) <= options.stateTolerance;
    zeroErrorDynamic = max(abs([ ...
        state(layout.referencePosition)-state(layout.encoder), ...
        state(layout.deltaEncoder), ...
        state(layout.previousEffectiveAction), ...
        state(layout.referenceVelocity)])) <= options.stateTolerance;
    for motor = 1:4
        cursor = cursor + 1;
        row = emptyAnchorRow();
        row.episode = rest.episode(stateIdx);
        row.repetitionId = rest.repetitionId(stateIdx);
        row.side = rest.side(stateIdx);
        row.profileId = rest.profileId(stateIdx);
        row.synergyAxis = rest.synergyAxis(stateIdx);
        row.directionName = rest.directionName(stateIdx);
        row.motor = motor;
        row.homeNonEmgZero = home;
        row.zeroErrorDynamicAnchor = zeroErrorDynamic;
        row.emgFeatureRms = sqrt(mean(state(layout.emg).^2));
        row.rawAction = rest.rawAction(stateIdx, motor);
        row.effectiveAction = rest.effectiveAction(stateIdx, motor);
        row.appliedPwm = rest.appliedPwm(stateIdx, motor);
        row.commandActive = abs(row.appliedPwm) > 0;
        rows(cursor) = row;
    end
end
anchors = struct2table(rows);
end

function summary = summarizeAnchors(anchors)
rows = repmat(emptyAnchorSummaryRow(), 5, 1);
motors = [0, 1:4];
for rowIdx = 1:numel(motors)
    motor = motors(rowIdx);
    values = anchors;
    if motor > 0
        values = values(values.motor == motor, :);
    end
    home = values(values.homeNonEmgZero, :);
    row = emptyAnchorSummaryRow();
    row.motor = motor;
    row.anchorComponentCount = height(values);
    row.homeAnchorComponentCount = height(home);
    row.zeroErrorDynamicFraction = mean(values.zeroErrorDynamicAnchor);
    row.commandActiveFraction = mean(values.commandActive);
    row.homeCommandActiveFraction = safeMean(home.commandActive);
    row.meanAbsRawAction = mean(abs(values.rawAction));
    row.homeMeanAbsRawAction = safeMean(abs(home.rawAction));
    row.meanAbsPwm = mean(abs(values.appliedPwm));
    row.homeMeanAbsPwm = safeMean(abs(home.appliedPwm));
    rows(rowIdx) = row;
end
summary = struct2table(rows);
end

function [tableValue, scaleTable] = buildInterventions( ...
        rest, actorEvaluator, actuator, layout, options)
blockNames = ["emgFeatures", "encoder", "deltaEncoder", ...
    "previousEffectiveAction", "referencePosition", ...
    "referenceVelocity"];
blockIndices = {layout.emg, layout.encoder, layout.deltaEncoder, ...
    layout.previousEffectiveAction, layout.referencePosition, ...
    layout.referenceVelocity};
featureScale = std(rest.state, 0, 1);
featureScale(featureScale <= options.minimumDonorBlockDistance) = NaN;
scaleRows = repmat(struct("block", "", "variableFeatureCount", 0, ...
    "featureCount", 0, "minimumScale", NaN, "maximumScale", NaN), ...
    numel(blockNames), 1);
for blockIdx = 1:numel(blockNames)
    scales = featureScale(blockIndices{blockIdx});
    finiteScales = scales(isfinite(scales));
    scaleRows(blockIdx).block = blockNames(blockIdx);
    scaleRows(blockIdx).variableFeatureCount = numel(finiteScales);
    scaleRows(blockIdx).featureCount = numel(scales);
    if ~isempty(finiteScales)
        scaleRows(blockIdx).minimumScale = min(finiteScales);
        scaleRows(blockIdx).maximumScale = max(finiteScales);
    end
end
scaleTable = struct2table(scaleRows);

swapCount = size(rest.state, 1) * numel(blockNames);
swapRows = repmat(emptySwapRow(), swapCount, 1);
hybrids = nan(swapCount, size(rest.state, 2));
cursor = 0;
allIndices = 1:size(rest.state, 2);
for recipientIdx = 1:size(rest.state, 1)
    episodeRows = find(rest.episode == rest.episode(recipientIdx));
    for blockIdx = 1:numel(blockNames)
        cursor = cursor + 1;
        indices = blockIndices{blockIdx};
        complement = setdiff(allIndices, indices, "stable");
        candidateRows = episodeRows(episodeRows ~= recipientIdx);
        blockDistance = sqrt(mean(( ...
            rest.state(candidateRows, indices) - ...
            rest.state(recipientIdx, indices)).^2, 2));
        candidateRows = candidateRows( ...
            blockDistance > options.minimumDonorBlockDistance);
        row = emptySwapRow();
        row.recipientIndex = recipientIdx;
        row.episode = rest.episode(recipientIdx);
        row.repetitionId = rest.repetitionId(recipientIdx);
        row.side = rest.side(recipientIdx);
        row.profileId = rest.profileId(recipientIdx);
        row.synergyAxis = rest.synergyAxis(recipientIdx);
        row.directionName = rest.directionName(recipientIdx);
        row.recipientStep = rest.step(recipientIdx);
        row.block = blockNames(blockIdx);
        if isempty(candidateRows)
            hybrids(cursor, :) = rest.state(recipientIdx, :);
            swapRows(cursor) = row;
            continue;
        end
        distances = nan(numel(candidateRows), 1);
        validComplement = complement(isfinite(featureScale(complement)));
        for candidateIdx = 1:numel(candidateRows)
            if isempty(validComplement)
                distances(candidateIdx) = 0;
            else
                delta = (rest.state(candidateRows(candidateIdx), ...
                    validComplement) - rest.state(recipientIdx, ...
                    validComplement)) ./ featureScale(validComplement);
                distances(candidateIdx) = sqrt(mean(delta.^2));
            end
        end
        [minimumDistance, selectedIdx] = min(distances);
        donorIdx = candidateRows(selectedIdx);
        hybrid = rest.state(recipientIdx, :);
        hybrid(indices) = rest.state(donorIdx, indices);
        row.donorIndex = donorIdx;
        row.donorEpisode = rest.episode(donorIdx);
        row.donorStep = rest.step(donorIdx);
        row.blockRmsDistance = sqrt(mean(( ...
            rest.state(donorIdx, indices) - ...
            rest.state(recipientIdx, indices)).^2));
        row.complementStandardizedRmsDistance = minimumDistance;
        row.identifiable = true;
        row.locallyMatched = minimumDistance <= ...
            options.maximumComplementDistance;
        row.hybridWithinObservedFeatureBounds = all( ...
            hybrid >= min(rest.state, [], 1)-options.stateTolerance & ...
            hybrid <= max(rest.state, [], 1)+options.stateTolerance);
        hybrids(cursor, :) = hybrid;
        swapRows(cursor) = row;
    end
end

counterfactualRaw = evaluateHandle(actorEvaluator, hybrids);
[counterfactualEffective, counterfactualPwm] = ...
    quantizeRows(counterfactualRaw, actuator);
expanded = repmat(emptyInterventionRow(), swapCount*4, 1);
cursor = 0;
for swapIdx = 1:swapCount
    swap = swapRows(swapIdx);
    recipientIdx = swap.recipientIndex;
    for motor = 1:4
        cursor = cursor + 1;
        row = emptyInterventionRow();
        fields = fieldnames(swap);
        for fieldIdx = 1:numel(fields)
            row.(fields{fieldIdx}) = swap.(fields{fieldIdx});
        end
        row.motor = motor;
        row.observedRawAction = rest.rawAction(recipientIdx, motor);
        row.counterfactualRawAction = counterfactualRaw(swapIdx, motor);
        row.deltaRawAction = row.counterfactualRawAction - ...
            row.observedRawAction;
        row.absoluteRawActionDelta = abs(row.deltaRawAction);
        row.observedEffectiveAction = ...
            rest.effectiveAction(recipientIdx, motor);
        row.counterfactualEffectiveAction = ...
            counterfactualEffective(swapIdx, motor);
        row.observedPwm = rest.appliedPwm(recipientIdx, motor);
        row.counterfactualPwm = counterfactualPwm(swapIdx, motor);
        row.absolutePwmDelta = abs(row.counterfactualPwm-row.observedPwm);
        row.quantizedCommandChanged = ...
            row.counterfactualPwm ~= row.observedPwm;
        row.commandSignChanged = sign(row.counterfactualPwm) ~= ...
            sign(row.observedPwm);
        row.materialRawEffect = row.absoluteRawActionDelta >= ...
            options.materialRawActionDelta;
        expanded(cursor) = row;
    end
end
tableValue = struct2table(expanded);
end

function summary = summarizeInterventions(values, options)
keys = unique(values(:, ["block", "motor"]), "rows", "stable");
rows = repmat(emptyBlockSummaryRow(), height(keys), 1);
for keyIdx = 1:height(keys)
    selected = values(values.block == keys.block(keyIdx) & ...
        values.motor == keys.motor(keyIdx), :);
    identifiable = selected(selected.identifiable, :);
    local = identifiable(identifiable.locallyMatched, :);
    row = emptyBlockSummaryRow();
    row.block = keys.block(keyIdx);
    row.motor = keys.motor(keyIdx);
    row.interventionCount = height(selected);
    row.identifiableCount = height(identifiable);
    row.identifiableFraction = mean(selected.identifiable);
    row.locallyMatchedCount = height(local);
    row.localCoverageFraction = safeRatio(height(local), height(identifiable));
    row.hybridFeatureBoundsFraction = safeMean( ...
        identifiable.hybridWithinObservedFeatureBounds);
    row.meanComplementDistance = safeMean( ...
        local.complementStandardizedRmsDistance);
    row.maximumComplementDistance = safeMax( ...
        local.complementStandardizedRmsDistance);
    row.meanAbsRawActionDelta = safeMean(local.absoluteRawActionDelta);
    row.medianAbsRawActionDelta = safeMedian(local.absoluteRawActionDelta);
    row.maximumAbsRawActionDelta = safeMax(local.absoluteRawActionDelta);
    row.materialRawEffectFraction = safeMean(local.materialRawEffect);
    row.quantizedCommandChangedFraction = ...
        safeMean(local.quantizedCommandChanged);
    row.commandSignChangedFraction = safeMean(local.commandSignChanged);
    row.meanAbsPwmDelta = safeMean(local.absolutePwmDelta);
    if isempty(identifiable)
        row.classification = "invariantDuringPreRest";
    elseif row.identifiableFraction < options.minimumIdentifiableFraction
        row.classification = "insufficientIdentifiability";
    elseif row.localCoverageFraction < options.minimumLocalCoverage
        row.classification = "insufficientLocalSupport";
    elseif row.medianAbsRawActionDelta >= ...
            options.materialRawActionDelta && ...
            row.quantizedCommandChangedFraction >= ...
            options.minimumMaterialFraction
        row.classification = "locallySensitive";
    else
        row.classification = "locallyStable";
    end
    rows(keyIdx) = row;
end
summary = struct2table(rows);
end

function decision = summarizeBlocks(summary)
blocks = unique(summary.block, "stable");
rows = repmat(struct("block", "", "motorCount", 0, ...
    "locallySensitiveMotorCount", 0, "locallyStableMotorCount", 0, ...
    "invariantMotorCount", 0, ...
    "insufficientIdentifiabilityMotorCount", 0, ...
    "insufficientSupportMotorCount", 0, ...
    "classification", ""), numel(blocks), 1);
for blockIdx = 1:numel(blocks)
    selected = summary(summary.block == blocks(blockIdx), :);
    sensitive = sum(selected.classification == "locallySensitive");
    stable = sum(selected.classification == "locallyStable");
    invariant = sum(selected.classification == "invariantDuringPreRest");
    unidentifiable = sum(selected.classification == ...
        "insufficientIdentifiability");
    insufficient = sum(selected.classification == ...
        "insufficientLocalSupport");
    if invariant == height(selected)
        classification = "invariantDuringPreRest";
    elseif unidentifiable > 0
        classification = "identifiabilityLimited";
    elseif insufficient > 0
        classification = "supportLimited";
    elseif sensitive > 0
        classification = "localSensitivityObserved";
    else
        classification = "locallyStable";
    end
    rows(blockIdx) = struct("block", blocks(blockIdx), ...
        "motorCount", height(selected), ...
        "locallySensitiveMotorCount", sensitive, ...
        "locallyStableMotorCount", stable, ...
        "invariantMotorCount", invariant, ...
        "insufficientIdentifiabilityMotorCount", unidentifiable, ...
        "insufficientSupportMotorCount", insufficient, ...
        "classification", classification);
end
decision = struct2table(rows);
end

function [raw, effective, pwm] = evaluatePOnObservedStates( ...
        states, controller, actuator, layout, periodSec)
raw = nan(size(states, 1), 4);
effective = nan(size(raw));
pwm = nan(size(raw));
for rowIdx = 1:size(states, 1)
    q = states(rowIdx, layout.encoder);
    v = states(rowIdx, layout.deltaEncoder) ./ periodSec;
    qRef = states(rowIdx, layout.referencePosition);
    vRef = states(rowIdx, layout.referenceVelocity);
    [rawRow, effectiveRow, pwmRow] = quantizedIntentPdController( ...
        qRef, q, vRef, v, controller, actuator);
    raw(rowIdx, :) = rawRow';
    effective(rowIdx, :) = effectiveRow';
    pwm(rowIdx, :) = pwmRow';
end
end

function summary = buildControlSummary(rest, matchedP, ...
        pRaw, pEffective, pPwm, preRestWindows, saturationThreshold)
sourceNames = ["Agent200Observed", "zeroAction", ...
    "conventionalPOnAgentState", "conventionalPMatchedTrajectory"];
sourceRaw = {rest.rawAction, zeros(size(rest.rawAction)), pRaw, []};
sourceEffective = {rest.effectiveAction, zeros(size(rest.effectiveAction)), ...
    pEffective, []};
sourcePwm = {rest.appliedPwm, zeros(size(rest.appliedPwm)), pPwm, []};
matched = matchedP(matchedP.step <= preRestWindows, :);
expectedMatchedRows = numel(unique(rest.episode)) * preRestWindows * 4;
if height(matched) ~= expectedMatchedRows || ...
        height(unique(matched(:, ["episode", "step", "motor"]), ...
        "rows")) ~= expectedMatchedRows
    error("analyzeNoGloveStage7cRestCommands:MatchedControlCoverage", ...
        "Matched conventionalP must cover every pre-rest component once.");
end
rows = repmat(emptyControlSummaryRow(), numel(sourceNames)*5, 1);
cursor = 0;
for sourceIdx = 1:numel(sourceNames)
    for motorValue = [0, 1:4]
        cursor = cursor + 1;
        if sourceIdx < 4
            raw = sourceRaw{sourceIdx};
            effective = sourceEffective{sourceIdx};
            pwm = sourcePwm{sourceIdx};
            if motorValue > 0
                raw = raw(:, motorValue);
                effective = effective(:, motorValue);
                pwm = pwm(:, motorValue);
            else
                raw = raw(:);
                effective = effective(:);
                pwm = pwm(:);
            end
        else
            selected = matched;
            if motorValue > 0
                selected = selected(selected.motor == motorValue, :);
            end
            raw = double(selected.rawAction);
            effective = double(selected.effectiveAction);
            pwm = double(selected.appliedPwm);
        end
        row = emptyControlSummaryRow();
        row.commandSource = sourceNames(sourceIdx);
        row.motor = motorValue;
        row.componentCount = numel(pwm);
        row.commandActiveFraction = mean(abs(pwm) > 0);
        row.meanAbsRawAction = mean(abs(raw));
        row.meanAbsEffectiveAction = mean(abs(effective));
        row.meanAbsPwm = mean(abs(pwm));
        row.saturationFraction = mean( ...
            abs(effective) >= saturationThreshold);
        rows(cursor) = row;
    end
end
summary = struct2table(rows);
end

function decision = buildSourceDecision(observed, anchors, blocks, options)
restActiveFraction = mean(observed.commandActive);
windowKeys = unique(observed(:, ["episode", "step"]), "rows", "stable");
windowActive = false(height(windowKeys), 1);
for windowIdx = 1:height(windowKeys)
    selected = observed(observed.episode == windowKeys.episode(windowIdx) & ...
        observed.step == windowKeys.step(windowIdx), :);
    windowActive(windowIdx) = any(selected.commandActive);
end
restWindowActiveFraction = mean(windowActive);
initialActiveFraction = mean(anchors.commandActive);
anchorEpisodes = unique(anchors.episode, "stable");
anchorEpisodeActive = false(numel(anchorEpisodes), 1);
for anchorIdx = 1:numel(anchorEpisodes)
    anchorEpisodeActive(anchorIdx) = any(anchors.commandActive( ...
        anchors.episode == anchorEpisodes(anchorIdx)));
end
initialEpisodeActiveFraction = mean(anchorEpisodeActive);
home = anchors(anchors.homeNonEmgZero, :);
homeActiveFraction = safeMean(home.commandActive);
emg = blocks(blocks.block == "emgFeatures", :);
emgSensitive = ~isempty(emg) && ...
    emg.locallySensitiveMotorCount > 0;
commandConfirmed = restWindowActiveFraction > options.falseActivationLimit;
homeCommandConfirmed = ~isempty(home) && ...
    homeActiveFraction > options.falseActivationLimit;
if ~commandConfirmed
    classification = "restCommandNotReproduced";
    recommendation = "No behavioral change is supported by ETAPA 7C.";
elseif homeCommandConfirmed && emgSensitive
    classification = "restEmgPathSensitivityObservedBiasUnresolved";
    recommendation = ...
        "Separate actor intercept from real-rest feature response offline; " + ...
        "do not change policy or gate in the same ablation.";
elseif homeCommandConfirmed
    classification = "restCommandAtObservedEmgOnlyStateUnresolved";
    recommendation = ...
        "Command does not require mechanical/reference input; distinguish " + ...
        "stable rest-feature response from actor bias offline.";
else
    classification = "restCommandMechanismUnresolved";
    recommendation = ...
        "Retain the gate and continue one-factor offline diagnosis.";
end
decision = table(restActiveFraction, restWindowActiveFraction, ...
    initialActiveFraction, initialEpisodeActiveFraction, ...
    height(home)/4, homeActiveFraction, commandConfirmed, ...
    homeCommandConfirmed, emgSensitive, false, ...
    sum(observed.safetyInterventionCount), ...
    mean(observed.safetyInterventionCount > 0), ...
    classification, recommendation, ...
    'VariableNames', ["restCommandActiveFraction", ...
    "restWindowAnyCommandFraction", ...
    "initialCommandActiveFraction", ...
    "initialEpisodeAnyCommandFraction", "homeAnchorEpisodeCount", ...
    "homeAnchorCommandActiveFraction", ...
    "commandDuringCalibratedRestConfirmed", ...
    "commandAtObservedEmgOnlyStateConfirmed", ...
    "restEmgLocalSensitivityObserved", "rootCauseIdentified", ...
    "restSafetyInterventionCount", ...
    "restSafetyInterventionComponentFraction", ...
    "classification", "recommendation"]);
end

function value = safeMean(values)
if isempty(values)
    value = NaN;
else
    value = mean(values, "omitnan");
end
end

function value = safeMedian(values)
if isempty(values)
    value = NaN;
else
    value = median(values, "omitnan");
end
end

function value = safeMax(values)
if isempty(values)
    value = NaN;
else
    value = max(values, [], "omitnan");
end
end

function value = safeRatio(numerator, denominator)
if denominator == 0
    value = NaN;
else
    value = numerator/denominator;
end
end

function row = emptyEpisodeAuditRow()
row = struct("episode", 0, "repetitionId", 0, "side", 0, ...
    "profileId", "", "initialPositionErrorMaxAbs", NaN, ...
    "initialDynamicStateMaxAbs", NaN, ...
    "initialNonEmgStateMaxAbs", NaN, "initialHomeAnchor", false, ...
    "referenceVelocityPreRestMaxAbs", NaN, ...
    "referenceDriftPreRestMaxAbs", NaN, ...
    "safetyInterventionCount", 0);
end

function row = emptyObservedRow()
row = struct("episode", 0, "repetitionId", 0, "side", 0, ...
    "profileId", "", "synergyAxis", "", "directionName", "", ...
    "step", 0, "motor", 0, "encoder", NaN, "deltaEncoder", NaN, ...
    "previousEffectiveAction", NaN, "referencePosition", NaN, ...
    "referenceVelocity", NaN, "positionError", NaN, ...
    "rawAction", NaN, "effectiveAction", NaN, "appliedPwm", NaN, ...
    "commandActive", false, "saturated", false, ...
    "safetyInterventionCount", 0);
end

function row = emptyAnchorRow()
row = struct("episode", 0, "repetitionId", 0, "side", 0, ...
    "profileId", "", "synergyAxis", "", "directionName", "", ...
    "motor", 0, "homeNonEmgZero", false, ...
    "zeroErrorDynamicAnchor", false, "emgFeatureRms", NaN, ...
    "rawAction", NaN, "effectiveAction", NaN, "appliedPwm", NaN, ...
    "commandActive", false);
end

function row = emptyAnchorSummaryRow()
row = struct("motor", 0, "anchorComponentCount", 0, ...
    "homeAnchorComponentCount", 0, "zeroErrorDynamicFraction", NaN, ...
    "commandActiveFraction", NaN, "homeCommandActiveFraction", NaN, ...
    "meanAbsRawAction", NaN, "homeMeanAbsRawAction", NaN, ...
    "meanAbsPwm", NaN, "homeMeanAbsPwm", NaN);
end

function row = emptySwapRow()
row = struct("recipientIndex", 0, "donorIndex", NaN, ...
    "donorEpisode", NaN, ...
    "episode", 0, "repetitionId", 0, "side", 0, ...
    "profileId", "", "synergyAxis", "", "directionName", "", ...
    "recipientStep", 0, "donorStep", NaN, "block", "", ...
    "blockRmsDistance", NaN, ...
    "complementStandardizedRmsDistance", NaN, ...
    "identifiable", false, "locallyMatched", false, ...
    "hybridWithinObservedFeatureBounds", false);
end

function row = emptyInterventionRow()
row = emptySwapRow();
row.motor = 0;
row.observedRawAction = NaN;
row.counterfactualRawAction = NaN;
row.deltaRawAction = NaN;
row.absoluteRawActionDelta = NaN;
row.observedEffectiveAction = NaN;
row.counterfactualEffectiveAction = NaN;
row.observedPwm = NaN;
row.counterfactualPwm = NaN;
row.absolutePwmDelta = NaN;
row.quantizedCommandChanged = false;
row.commandSignChanged = false;
row.materialRawEffect = false;
end

function row = emptyBlockSummaryRow()
row = struct("block", "", "motor", 0, "interventionCount", 0, ...
    "identifiableCount", 0, "identifiableFraction", NaN, ...
    "locallyMatchedCount", 0, "localCoverageFraction", NaN, ...
    "hybridFeatureBoundsFraction", NaN, ...
    "meanComplementDistance", NaN, "maximumComplementDistance", NaN, ...
    "meanAbsRawActionDelta", NaN, "medianAbsRawActionDelta", NaN, ...
    "maximumAbsRawActionDelta", NaN, ...
    "materialRawEffectFraction", NaN, ...
    "quantizedCommandChangedFraction", NaN, ...
    "commandSignChangedFraction", NaN, "meanAbsPwmDelta", NaN, ...
    "classification", "");
end

function row = emptyControlSummaryRow()
row = struct("commandSource", "", "motor", 0, ...
    "componentCount", 0, "commandActiveFraction", NaN, ...
    "meanAbsRawAction", NaN, "meanAbsEffectiveAction", NaN, ...
    "meanAbsPwm", NaN, "saturationFraction", NaN);
end
