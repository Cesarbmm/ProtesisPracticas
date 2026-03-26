function verdict = classifyBenchmarkAcceptance(metrics, benchmark)
%classifyBenchmarkAcceptance evaluates a candidate against Agent7250.

arguments
    metrics struct
    benchmark struct = getAgent7250Benchmark()
end

requiredFields = ["trackingMseMean", "saturationFractionMean", "actionL2Mean", "deltaActionL2Mean"];
for i = 1:numel(requiredFields)
    if ~isfield(metrics, requiredFields(i))
        error("Metrics struct is missing required field '%s'.", requiredFields(i));
    end
end

trackingMse = double(metrics.trackingMseMean);
saturationFraction = double(metrics.saturationFractionMean);
actionL2 = double(metrics.actionL2Mean);
deltaActionL2 = double(metrics.deltaActionL2Mean);

if any(isnan([trackingMse, saturationFraction, actionL2, deltaActionL2]))
    meetsConditionA = false;
    meetsConditionB = false;
else
    meetsConditionA = ...
        trackingMse < benchmark.trackingMse && ...
        saturationFraction <= benchmark.saturationFraction && ...
        actionL2 <= benchmark.actionL2;

    meetsConditionB = ...
        trackingMse <= benchmark.trackingMse * 1.03 && ...
        saturationFraction <= benchmark.saturationFraction * 0.90 && ...
        actionL2 <= benchmark.actionL2 * 0.92;
end

if meetsConditionA
    status = "ConditionA";
elseif meetsConditionB
    status = "ConditionB";
else
    status = "Rejected";
end

verdict = struct( ...
    "meetsConditionA", meetsConditionA, ...
    "meetsConditionB", meetsConditionB, ...
    "status", status, ...
    "trackingMsePctVsBenchmark", percentDelta(trackingMse, benchmark.trackingMse), ...
    "saturationFractionPctVsBenchmark", percentDelta(saturationFraction, benchmark.saturationFraction), ...
    "actionL2PctVsBenchmark", percentDelta(actionL2, benchmark.actionL2), ...
    "deltaActionL2PctVsBenchmark", percentDelta(deltaActionL2, benchmark.deltaActionL2));
end

function deltaPct = percentDelta(value, reference)
if isnan(value) || isnan(reference) || reference == 0
    deltaPct = NaN;
else
    deltaPct = 100 * (value / reference - 1);
end
end
