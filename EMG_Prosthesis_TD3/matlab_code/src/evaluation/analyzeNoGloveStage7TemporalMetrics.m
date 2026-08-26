function analysis = analyzeNoGloveStage7TemporalMetrics( ...
        componentTable, splitName, options)
%analyzeNoGloveStage7TemporalMetrics offline lag and shared-DTW metrics.
%
% Positive lag means the response is delayed: Q(t+lag) is compared with
% Qref(t). DTW is called once per multivariable four-motor episode, never
% independently per motor. Endpoint error is always retained.

arguments
    componentTable table
    splitName (1, 1) string
    options.maxDiscreteLagSteps (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 3
    options.dtwMaxLagSteps (1, 1) double ...
        {mustBeInteger, mustBeNonnegative} = 1
    options.activeVelocityThreshold (1, 1) double ...
        {mustBeNonnegative} = 0.005
    options.minimumRegimeSamples (1, 1) double ...
        {mustBeInteger, mustBePositive} = 10
    options.minimumBenefitFraction (1, 1) double ...
        {mustBeInRange(options.minimumBenefitFraction, 0, 1)} = 0.05
    options.fixedLagDominanceFraction (1, 1) double ...
        {mustBeInRange(options.fixedLagDominanceFraction, 0, 1)} = 0.80
    options.periodSec (1, 1) double {mustBePositive} = 0.2
end

validateComponentTable(componentTable, splitName, options);
commandSources = unique(string(componentTable.commandSource), "stable");
episodeIds = unique(double(componentTable.episode), "stable");

episodeSeries = cell(numel(commandSources), numel(episodeIds));
episodeDtwRows = repmat(emptyDtwRow(), ...
    numel(commandSources) * numel(episodeIds), 1);
rowIdx = 0;
for sourceIdx = 1:numel(commandSources)
    for episodeIdx = 1:numel(episodeIds)
        source = commandSources(sourceIdx);
        episode = episodeIds(episodeIdx);
        series = extractEpisodeSeries( ...
            componentTable, source, episode);
        episodeSeries{sourceIdx, episodeIdx} = series;
        rowIdx = rowIdx + 1;
        episodeDtwRows(rowIdx) = calculateEpisodeDtw( ...
            source, episode, series, options.dtwMaxLagSteps);
    end
end
episodeDtwTable = struct2table(episodeDtwRows);

discreteLagTable = buildDiscreteLagTable( ...
    commandSources, episodeSeries, options.maxDiscreteLagSteps, ...
    options.periodSec);
discreteLagSummary = summarizeDiscreteLag( ...
    discreteLagTable, options.periodSec);
[regimeLagTable, regimeLagSummary] = buildRegimeLagAnalysis( ...
    commandSources, episodeSeries, options);
dtwSummary = summarizeDtw(episodeDtwTable, ...
    options.dtwMaxLagSteps, options.periodSec);
evidenceDecision = classifyTemporalEvidence( ...
    commandSources, discreteLagSummary, dtwSummary, options);

analysis = struct( ...
    "schemaVersion", 1, ...
    "split", splitName, ...
    "commandSources", commandSources, ...
    "episodeCountPerSource", numel(episodeIds), ...
    "periodSec", options.periodSec, ...
    "maxDiscreteLagSteps", options.maxDiscreteLagSteps, ...
    "dtwMaxLagSteps", options.dtwMaxLagSteps, ...
    "dtwMetric", "squared", ...
    "dtwPathContract", "one shared four-motor path per episode", ...
    "endpointErrorRetained", true, ...
    "discreteLagTable", discreteLagTable, ...
    "discreteLagSummary", discreteLagSummary, ...
    "regimeLagTable", regimeLagTable, ...
    "regimeLagSummary", regimeLagSummary, ...
    "episodeDtwTable", episodeDtwTable, ...
    "dtwSummary", dtwSummary, ...
    "evidenceDecision", evidenceDecision, ...
    "agentLoaded", false, ...
    "reinforcementLearningInvoked", false, ...
    "simulatorInvoked", false, ...
    "rewardInvoked", false, ...
    "hardwareUsed", false);
end

function validateComponentTable(values, splitName, options)
required = ["split", "commandSource", "episode", "step", "motor", ...
    "qAfter", "qReference", "referenceVelocity"];
if ~all(ismember(required, string(values.Properties.VariableNames)))
    missing = setdiff(required, string(values.Properties.VariableNames));
    error("analyzeNoGloveStage7TemporalMetrics:MissingVariable", ...
        "componentTable is missing: %s.", strjoin(missing, ", "));
end
if isempty(values) || any(string(values.split) ~= splitName)
    error("analyzeNoGloveStage7TemporalMetrics:InvalidSplit", ...
        "componentTable must contain only split %s.", splitName);
end
numericFields = ["episode", "step", "motor", "qAfter", ...
    "qReference", "referenceVelocity"];
for fieldIdx = 1:numel(numericFields)
    fieldName = numericFields(fieldIdx);
    fieldValue = values.(fieldName);
    if ~isnumeric(fieldValue) || ~isreal(fieldValue) || ...
            any(~isfinite(fieldValue), "all")
        error("analyzeNoGloveStage7TemporalMetrics:NonfiniteData", ...
            "%s must be finite real numeric data.", fieldName);
    end
end
if any(~ismember(values.motor, 1:4)) || ...
        any(fix(values.motor) ~= values.motor) || ...
        any(values.step < 1 | fix(values.step) ~= values.step)
    error("analyzeNoGloveStage7TemporalMetrics:InvalidIndex", ...
        "Motor and step indices are invalid.");
end
if options.dtwMaxLagSteps > options.maxDiscreteLagSteps
    error("analyzeNoGloveStage7TemporalMetrics:InvalidLagBounds", ...
        "dtwMaxLagSteps must not exceed maxDiscreteLagSteps.");
end
end

function series = extractEpisodeSeries(values, commandSource, episode)
selected = values(string(values.commandSource) == commandSource & ...
    double(values.episode) == episode, :);
steps = unique(double(selected.step));
if isempty(steps) || ~isequal(steps(:), (1:max(steps))')
    error("analyzeNoGloveStage7TemporalMetrics:NoncontiguousSteps", ...
        "Source %s episode %d has noncontiguous steps.", ...
        commandSource, episode);
end
stepCount = numel(steps);
q = nan(4, stepCount);
qRef = nan(4, stepCount);
vRef = nan(4, stepCount);
for motorIdx = 1:4
    motorRows = sortrows(selected(selected.motor == motorIdx, :), "step");
    if height(motorRows) ~= stepCount || ...
            ~isequal(double(motorRows.step(:)), steps(:))
        error("analyzeNoGloveStage7TemporalMetrics:IncompleteEpisode", ...
            "Source %s episode %d does not have one row per motor-step.", ...
            commandSource, episode);
    end
    q(motorIdx, :) = double(motorRows.qAfter(:))';
    qRef(motorIdx, :) = double(motorRows.qReference(:))';
    vRef(motorIdx, :) = double(motorRows.referenceVelocity(:))';
end
series = struct("q", q, "qReference", qRef, ...
    "referenceVelocity", vRef, "stepCount", stepCount);
end

function row = calculateEpisodeDtw(source, episode, series, maxLagSteps)
q = series.q;
qRef = series.qReference;
endpointSquared = (q-qRef).^2;
[rawDistance, ix, iy] = dtw(q, qRef, maxLagSteps, "squared");
errorPath = q(:, ix)-qRef(:, iy);
pathSquaredSum = sum(errorPath.^2, "all");
consistencyTolerance = 256 * eps(max(1, abs(rawDistance)));
consistencyError = abs(double(rawDistance)-pathSquaredSum);
if consistencyError > consistencyTolerance
    error("analyzeNoGloveStage7TemporalMetrics:DtwDistanceMismatch", ...
        "Squared DTW distance is inconsistent with its shared path.");
end
pathLag = double(ix(:)-iy(:));
if any(abs(pathLag) > maxLagSteps)
    error("analyzeNoGloveStage7TemporalMetrics:DtwConstraintViolation", ...
        "DTW path exceeded maxLagSteps.");
end

row = emptyDtwRow();
row.commandSource = source;
row.episode = episode;
row.stepCount = series.stepCount;
row.endpointSquaredSum = sum(endpointSquared, "all");
row.endpointComponentCount = numel(endpointSquared);
row.endpointMse = mean(endpointSquared, "all");
row.dtwRawSquaredDistance = double(rawDistance);
row.dtwPathLength = numel(ix);
row.dtwComponentPathCount = numel(errorPath);
row.dtwMse = mean(errorPath.^2, "all");
row.dtwReductionFraction = safeReduction(row.endpointMse, row.dtwMse);
row.meanAbsLagSteps = mean(abs(pathLag));
row.meanSignedLagSteps = mean(pathLag);
row.maxAbsLagSteps = max(abs(pathLag));
row.normalizedLagPenalty = row.meanAbsLagSteps / max(1, maxLagSteps);
row.distanceConsistencyAbs = consistencyError;
end

function lagTable = buildDiscreteLagTable( ...
        sources, episodeSeries, maxLag, periodSec)
lags = (-maxLag:maxLag)';
rows = repmat(emptyLagRow(), numel(sources) * numel(lags), 1);
rowIdx = 0;
for sourceIdx = 1:numel(sources)
    for lagIdx = 1:numel(lags)
        lag = lags(lagIdx);
        responseCells = cell(size(episodeSeries, 2), 1);
        referenceCells = cell(size(episodeSeries, 2), 1);
        zeroResponseCells = cell(size(episodeSeries, 2), 1);
        for episodeIdx = 1:size(episodeSeries, 2)
            series = episodeSeries{sourceIdx, episodeIdx};
            [qIndices, refIndices] = alignedIndices(series.stepCount, lag);
            alignedResponse = series.q(:, qIndices);
            alignedReference = series.qReference(:, refIndices);
            zeroResponse = series.q(:, refIndices);
            responseCells{episodeIdx} = alignedResponse(:);
            referenceCells{episodeIdx} = alignedReference(:);
            zeroResponseCells{episodeIdx} = zeroResponse(:);
        end
        rowIdx = rowIdx + 1;
        rows(rowIdx) = calculateLagRow( ...
            sources(sourceIdx), lag, periodSec, ...
            vertcat(responseCells{:}), vertcat(referenceCells{:}), ...
            vertcat(zeroResponseCells{:}));
    end
end
lagTable = struct2table(rows);
end

function summary = summarizeDiscreteLag(lagTable, periodSec)
sources = unique(lagTable.commandSource, "stable");
rows = repmat(emptyLagSummaryRow(), numel(sources), 1);
for sourceIdx = 1:numel(sources)
    values = lagTable(lagTable.commandSource == sources(sourceIdx), :);
    zero = values(values.lagSteps == 0, :);
    bestMse = chooseBestLag(values);
    validCorrelation = values(isfinite(values.correlation), :);
    if isempty(validCorrelation)
        bestCorrelationLag = NaN;
        bestCorrelation = NaN;
    else
        bestCorrelation = max(validCorrelation.correlation);
        candidates = validCorrelation( ...
            validCorrelation.correlation == bestCorrelation, :);
        candidates = sortrows(candidates, ["absoluteLagSteps", "lagSteps"]);
        bestCorrelationLag = candidates.lagSteps(1);
    end
    row = emptyLagSummaryRow();
    row.commandSource = sources(sourceIdx);
    row.zeroLagMse = zero.mse;
    row.bestMseLagSteps = bestMse.lagSteps;
    row.bestMseLagSec = bestMse.lagSteps * periodSec;
    row.bestLagMse = bestMse.mse;
    row.zeroLagOverlapMseAtBestLag = bestMse.zeroLagOverlapMse;
    row.bestLagImprovementFraction = bestMse.improvementFraction;
    row.bestCorrelationLagSteps = bestCorrelationLag;
    row.bestCorrelationLagSec = bestCorrelationLag * periodSec;
    row.bestCorrelation = bestCorrelation;
    rows(sourceIdx) = row;
end
summary = struct2table(rows);
end

function [lagTable, summary] = buildRegimeLagAnalysis( ...
        sources, episodeSeries, options)
regimes = ["opening", "hold", "closing"];
lags = (-options.maxDiscreteLagSteps:options.maxDiscreteLagSteps)';
rowCount = numel(sources) * 4 * numel(regimes) * numel(lags);
rows = repmat(emptyRegimeLagRow(), rowCount, 1);
rowIdx = 0;
for sourceIdx = 1:numel(sources)
    for motorIdx = 1:4
        for regimeIdx = 1:numel(regimes)
            for lagIdx = 1:numel(lags)
                lag = lags(lagIdx);
                responseCells = cell(size(episodeSeries, 2), 1);
                referenceCells = cell(size(episodeSeries, 2), 1);
                zeroResponseCells = cell(size(episodeSeries, 2), 1);
                for episodeIdx = 1:size(episodeSeries, 2)
                    series = episodeSeries{sourceIdx, episodeIdx};
                    [qIndices, refIndices] = alignedIndices( ...
                        series.stepCount, lag);
                    referenceVelocity = series.referenceVelocity( ...
                        motorIdx, refIndices);
                    regimeMask = classifyRegime(referenceVelocity, ...
                        options.activeVelocityThreshold) == regimes(regimeIdx);
                    responseCells{episodeIdx} = series.q( ...
                        motorIdx, qIndices(regimeMask))';
                    referenceCells{episodeIdx} = series.qReference( ...
                        motorIdx, refIndices(regimeMask))';
                    zeroResponseCells{episodeIdx} = series.q( ...
                        motorIdx, refIndices(regimeMask))';
                end
                rowIdx = rowIdx + 1;
                base = calculateLagRow(sources(sourceIdx), lag, ...
                    options.periodSec, vertcat(responseCells{:}), ...
                    vertcat(referenceCells{:}), ...
                    vertcat(zeroResponseCells{:}));
                row = emptyRegimeLagRow();
                row.commandSource = sources(sourceIdx);
                row.motor = motorIdx;
                row.regime = regimes(regimeIdx);
                row.lagSteps = lag;
                row.lagSec = lag * options.periodSec;
                row.absoluteLagSteps = abs(lag);
                row.sampleCount = base.sampleCount;
                row.mse = base.mse;
                row.zeroLagOverlapMse = base.zeroLagOverlapMse;
                row.improvementFraction = base.improvementFraction;
                row.correlation = base.correlation;
                row.hasMinimumSamples = ...
                    base.sampleCount >= options.minimumRegimeSamples;
                rows(rowIdx) = row;
            end
        end
    end
end
lagTable = struct2table(rows);
summary = summarizeRegimeLag(lagTable, options.periodSec);
end

function summary = summarizeRegimeLag(lagTable, periodSec)
keys = unique(lagTable(:, ["commandSource", "motor", "regime"]), ...
    "rows", "stable");
rows = repmat(emptyRegimeSummaryRow(), height(keys), 1);
for keyIdx = 1:height(keys)
    values = lagTable( ...
        lagTable.commandSource == keys.commandSource(keyIdx) & ...
        lagTable.motor == keys.motor(keyIdx) & ...
        lagTable.regime == keys.regime(keyIdx) & ...
        lagTable.hasMinimumSamples, :);
    row = emptyRegimeSummaryRow();
    row.commandSource = keys.commandSource(keyIdx);
    row.motor = keys.motor(keyIdx);
    row.regime = keys.regime(keyIdx);
    if isempty(values)
        rows(keyIdx) = row;
        continue;
    end
    zero = values(values.lagSteps == 0, :);
    bestMse = chooseBestLag(values);
    correlations = values(isfinite(values.correlation), :);
    row.sampleCountAtZero = zero.sampleCount;
    row.zeroLagMse = zero.mse;
    row.bestMseLagSteps = bestMse.lagSteps;
    row.bestMseLagSec = bestMse.lagSteps * periodSec;
    row.bestLagMse = bestMse.mse;
    row.bestLagImprovementFraction = bestMse.improvementFraction;
    if ~isempty(correlations)
        maxCorrelation = max(correlations.correlation);
        candidates = correlations( ...
            correlations.correlation == maxCorrelation, :);
        candidates = sortrows(candidates, ["absoluteLagSteps", "lagSteps"]);
        row.bestCorrelationLagSteps = candidates.lagSteps(1);
        row.bestCorrelationLagSec = candidates.lagSteps(1) * periodSec;
        row.bestCorrelation = maxCorrelation;
    end
    rows(keyIdx) = row;
end
summary = struct2table(rows);
end

function summary = summarizeDtw(episodeTable, maxLagSteps, periodSec)
sources = unique(episodeTable.commandSource, "stable");
rows = repmat(emptyDtwSummaryRow(), numel(sources), 1);
for sourceIdx = 1:numel(sources)
    values = episodeTable( ...
        episodeTable.commandSource == sources(sourceIdx), :);
    row = emptyDtwSummaryRow();
    row.commandSource = sources(sourceIdx);
    row.episodeCount = height(values);
    row.endpointMse = sum(values.endpointSquaredSum) / ...
        sum(values.endpointComponentCount);
    row.dtwMse = sum(values.dtwRawSquaredDistance) / ...
        sum(values.dtwComponentPathCount);
    row.dtwReductionFraction = safeReduction(row.endpointMse, row.dtwMse);
    row.meanAbsLagSteps = sum( ...
        values.meanAbsLagSteps .* values.dtwPathLength) / ...
        sum(values.dtwPathLength);
    row.meanSignedLagSteps = sum( ...
        values.meanSignedLagSteps .* values.dtwPathLength) / ...
        sum(values.dtwPathLength);
    row.normalizedLagPenalty = row.meanAbsLagSteps / max(1, maxLagSteps);
    row.meanAbsLagSec = row.meanAbsLagSteps * periodSec;
    row.meanSignedLagSec = row.meanSignedLagSteps * periodSec;
    row.maxAbsLagSteps = max(values.maxAbsLagSteps);
    row.meanPathLength = mean(values.dtwPathLength);
    row.maxDistanceConsistencyAbs = max(values.distanceConsistencyAbs);
    rows(sourceIdx) = row;
end
summary = struct2table(rows);
end

function decision = classifyTemporalEvidence( ...
        sources, discreteSummary, dtwSummary, options)
rows = repmat(emptyDecisionRow(), numel(sources), 1);
for sourceIdx = 1:numel(sources)
    discrete = discreteSummary( ...
        discreteSummary.commandSource == sources(sourceIdx), :);
    dtwValue = dtwSummary( ...
        dtwSummary.commandSource == sources(sourceIdx), :);
    fixedBenefit = max(0, discrete.bestLagImprovementFraction);
    dtwBenefit = max(0, dtwValue.dtwReductionFraction);
    fixedLagDetected = discrete.bestMseLagSteps ~= 0 && ...
        fixedBenefit >= options.minimumBenefitFraction;
    dtwBenefitDetected = ...
        dtwBenefit >= options.minimumBenefitFraction;
    fixedDominates = fixedLagDetected && ...
        (~dtwBenefitDetected || fixedBenefit >= ...
        options.fixedLagDominanceFraction * dtwBenefit);
    if fixedDominates
        classification = "fixedLagPreferred";
        recommendation = ...
            "Test causal lag compensation or filtered reference before DTW reward.";
    elseif dtwBenefitDetected
        classification = "dtwMetricCandidate";
        recommendation = ...
            "Keep DTW offline until endpoint, lag and compute gates are reviewed.";
    else
        classification = "noMaterialTemporalBenefit";
        recommendation = ...
            "Cancel DTW reward stages for this source under the tested bound.";
    end
    row = emptyDecisionRow();
    row.commandSource = sources(sourceIdx);
    row.classification = classification;
    row.bestFixedLagSteps = discrete.bestMseLagSteps;
    row.bestFixedLagSec = discrete.bestMseLagSteps * options.periodSec;
    row.fixedLagImprovementFraction = fixedBenefit;
    row.dtwImprovementFraction = dtwBenefit;
    row.dtwMeanAbsLagSteps = dtwValue.meanAbsLagSteps;
    row.recommendation = recommendation;
    rows(sourceIdx) = row;
end
decision = struct2table(rows);
end

function row = calculateLagRow( ...
        source, lag, periodSec, response, reference, zeroResponse)
row = emptyLagRow();
row.commandSource = source;
row.lagSteps = lag;
row.lagSec = lag * periodSec;
row.absoluteLagSteps = abs(lag);
row.sampleCount = numel(response);
if isempty(response)
    return;
end
response = double(response(:));
reference = double(reference(:));
row.mse = mean((response-reference).^2);
row.zeroLagOverlapMse = mean((zeroResponse-reference).^2);
row.correlation = safeCorrelation(response, reference);
row.improvementFraction = safeReduction( ...
    row.zeroLagOverlapMse, row.mse);
end

function [qIndices, refIndices] = alignedIndices(stepCount, lag)
if abs(lag) >= stepCount
    error("analyzeNoGloveStage7TemporalMetrics:LagTooLarge", ...
        "Lag magnitude must be smaller than every episode.");
end
if lag >= 0
    qIndices = (1+lag):stepCount;
    refIndices = 1:(stepCount-lag);
else
    qIndices = 1:(stepCount+lag);
    refIndices = (1-lag):stepCount;
end
end

function regime = classifyRegime(velocity, threshold)
regime = repmat("hold", size(velocity));
regime(velocity >= threshold) = "closing";
regime(velocity <= -threshold) = "opening";
end

function value = safeCorrelation(a, b)
if numel(a) < 2 || std(a) == 0 || std(b) == 0
    value = NaN;
    return;
end
matrix = corrcoef(a, b);
value = matrix(1, 2);
end

function best = chooseBestLag(values)
metric = values.improvementFraction;
maximum = max(metric);
candidates = values(metric == maximum, :);
candidates = sortrows(candidates, ["absoluteLagSteps", "lagSteps"]);
best = candidates(1, :);
end

function value = safeReduction(baseline, candidate)
if baseline == 0
    if candidate == 0
        value = 0;
    else
        value = -Inf;
    end
else
    value = (baseline-candidate)/baseline;
end
end

function row = emptyLagRow()
row = struct("commandSource", "", "lagSteps", 0, ...
    "lagSec", 0, "absoluteLagSteps", 0, ...
    "sampleCount", 0, "mse", NaN, ...
    "zeroLagOverlapMse", NaN, "improvementFraction", NaN, ...
    "correlation", NaN);
end

function row = emptyLagSummaryRow()
row = struct("commandSource", "", "zeroLagMse", NaN, ...
    "bestMseLagSteps", NaN, "bestMseLagSec", NaN, ...
    "bestLagMse", NaN, ...
    "zeroLagOverlapMseAtBestLag", NaN, ...
    "bestLagImprovementFraction", NaN, ...
    "bestCorrelationLagSteps", NaN, "bestCorrelationLagSec", NaN, ...
    "bestCorrelation", NaN);
end

function row = emptyRegimeLagRow()
row = struct("commandSource", "", "motor", 0, "regime", "", ...
    "lagSteps", 0, "absoluteLagSteps", 0, "sampleCount", 0, ...
    "lagSec", 0, ...
    "mse", NaN, "zeroLagOverlapMse", NaN, ...
    "improvementFraction", NaN, "correlation", NaN, ...
    "hasMinimumSamples", false);
end

function row = emptyRegimeSummaryRow()
row = struct("commandSource", "", "motor", 0, "regime", "", ...
    "sampleCountAtZero", 0, "zeroLagMse", NaN, ...
    "bestMseLagSteps", NaN, "bestMseLagSec", NaN, ...
    "bestLagMse", NaN, ...
    "bestLagImprovementFraction", NaN, ...
    "bestCorrelationLagSteps", NaN, "bestCorrelationLagSec", NaN, ...
    "bestCorrelation", NaN);
end

function row = emptyDtwRow()
row = struct("commandSource", "", "episode", 0, "stepCount", 0, ...
    "endpointSquaredSum", 0, "endpointComponentCount", 0, ...
    "endpointMse", NaN, "dtwRawSquaredDistance", NaN, ...
    "dtwPathLength", 0, "dtwComponentPathCount", 0, ...
    "dtwMse", NaN, "dtwReductionFraction", NaN, ...
    "meanAbsLagSteps", NaN, "meanSignedLagSteps", NaN, ...
    "maxAbsLagSteps", NaN, "normalizedLagPenalty", NaN, ...
    "distanceConsistencyAbs", NaN);
end

function row = emptyDtwSummaryRow()
row = struct("commandSource", "", "episodeCount", 0, ...
    "endpointMse", NaN, "dtwMse", NaN, ...
    "dtwReductionFraction", NaN, "meanAbsLagSteps", NaN, ...
    "meanAbsLagSec", NaN, "meanSignedLagSteps", NaN, ...
    "meanSignedLagSec", NaN, "normalizedLagPenalty", NaN, ...
    "maxAbsLagSteps", NaN, "meanPathLength", NaN, ...
    "maxDistanceConsistencyAbs", NaN);
end

function row = emptyDecisionRow()
row = struct("commandSource", "", "classification", "", ...
    "bestFixedLagSteps", NaN, "bestFixedLagSec", NaN, ...
    "fixedLagImprovementFraction", NaN, ...
    "dtwImprovementFraction", NaN, "dtwMeanAbsLagSteps", NaN, ...
    "recommendation", "");
end
