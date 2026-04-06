function summaryText = buildCheckpointAuditSummary(results)
%buildCheckpointAuditSummary generates a human-readable text report.

arguments
    results struct
end

lines = strings(0, 1);
lines(end+1) = "Checkpoint Audit Summary";
lines(end+1) = "========================";
lines(end+1) = "";
lines(end+1) = sprintf("Mode: %s", string(results.selectionInfo.mode));
lines(end+1) = sprintf("Experiment dir: %s", string(results.selectionInfo.experimentDir));
lines(end+1) = sprintf("Checkpoint count: %d", results.selectionInfo.checkpointCount);
lines(end+1) = sprintf("Best checkpoint: %s", string(results.bestCheckpointPath));
lines(end+1) = sprintf("Best episode inferred: %d", results.bestCheckpointEpisode);
lines(end+1) = "";
lines(end+1) = "Benchmark reference";
lines(end+1) = "-------------------";
lines(end+1) = sprintf("Label: %s", string(results.benchmark.label));
lines(end+1) = sprintf("trackingMSE = %.6f", results.benchmark.trackingMse);
lines(end+1) = sprintf("saturationFraction = %.6f", results.benchmark.saturationFraction);
lines(end+1) = sprintf("actionL2 = %.6f", results.benchmark.actionL2);
lines(end+1) = sprintf("deltaActionL2 = %.6f", results.benchmark.deltaActionL2);
lines(end+1) = "";
lines(end+1) = "Top results Phase A";
lines(end+1) = "-------------------";
lines(end+1) = formatTablePreview(results.phaseATable);
lines(end+1) = "";
lines(end+1) = "Top results Phase B";
lines(end+1) = "-------------------";
lines(end+1) = formatTablePreview(results.phaseBTable);

summaryText = strjoin(lines, newline);
end

function textValue = formatTablePreview(tbl)
if isempty(tbl)
    textValue = "(empty table)";
    return;
end

previewCols = intersect( ...
    ["checkpointEpisode", "checkpointLabel", "trackingMseMean", ...
     "saturationFractionMean", "deltaActionL2Mean", "actionL2Mean", ...
     "thresholdNullFractionMean", "signFlipFractionMean", "benchmarkStatus"], ...
    string(tbl.Properties.VariableNames), ...
    "stable");

textValue = strtrim(string(evalc("disp(tbl(:, cellstr(previewCols)))")));
end
