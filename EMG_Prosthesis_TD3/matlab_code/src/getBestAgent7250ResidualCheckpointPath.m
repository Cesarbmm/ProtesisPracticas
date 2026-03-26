function checkpointPath = getBestAgent7250ResidualCheckpointPath()
%getBestAgent7250ResidualCheckpointPath resolves the best residual pilot checkpoint.

srcDir = fileparts(mfilename("fullpath"));
matlabRoot = fileparts(srcDir);
repoRoot = fileparts(fileparts(matlabRoot));
resultsRoot = fullfile(repoRoot, "Agentes", "agent7250_residual_policy_pilot");

fallbackPath = getResidualFinalCheckpointPath();

if ~isfolder(resultsRoot)
    checkpointPath = string(fallbackPath);
    return;
end

summaryFiles = [ ...
    dir(fullfile(resultsRoot, "*", "agent7250_residual_policy_pilot_summary.csv")); ...
    dir(fullfile(resultsRoot, "*", "residual_lift_pilot_summary.csv"))];
if isempty(summaryFiles)
    checkpointPath = string(fallbackPath);
    return;
end

bestMeta = struct();
bestFound = false;

for i = 1:numel(summaryFiles)
    summaryPath = fullfile(summaryFiles(i).folder, summaryFiles(i).name);
    try
        summaryTable = readtable(summaryPath, TextType="string");
    catch
        continue;
    end
    if isempty(summaryTable) || ~ismember("bestCheckpointPath", summaryTable.Properties.VariableNames)
        continue;
    end

    checkpointCandidate = string(summaryTable.bestCheckpointPath(1));
    if strlength(checkpointCandidate) == 0 || ~isfile(checkpointCandidate)
        continue;
    end

    status = getSummaryStatus(summaryTable);
    trackingMse = getSummaryMetric(summaryTable, "visualTrackingMseMean", "trackingMseMean");
    saturationFraction = getSummaryMetric(summaryTable, "visualSaturationFractionMean", "saturationFractionMean");
    actionL2 = getSummaryMetric(summaryTable, "visualActionL2Mean", "actionL2Mean");
    episode = getSummaryMetric(summaryTable, "", "bestCheckpointEpisode");

    currentMeta = struct( ...
        "checkpointPath", checkpointCandidate, ...
        "statusRank", mapStatusToRank(status), ...
        "trackingMse", trackingMse, ...
        "saturationFraction", saturationFraction, ...
        "actionL2", actionL2, ...
        "episode", episode, ...
        "modified", summaryFiles(i).datenum);

    if ~bestFound || isBetterResidualCandidate(currentMeta, bestMeta)
        bestMeta = currentMeta;
        bestFound = true;
    end
end

if bestFound
    checkpointPath = string(bestMeta.checkpointPath);
else
    checkpointPath = string(fallbackPath);
end
end

function status = getSummaryStatus(summaryTable)
status = "";
if ismember("visualBenchmarkStatus", summaryTable.Properties.VariableNames)
    status = string(summaryTable.visualBenchmarkStatus(1));
end
if strlength(strtrim(status)) == 0 && ismember("benchmarkStatus", summaryTable.Properties.VariableNames)
    status = string(summaryTable.benchmarkStatus(1));
end
end

function value = getSummaryMetric(summaryTable, preferredField, fallbackField)
value = NaN;
if strlength(string(preferredField)) > 0 && ismember(preferredField, summaryTable.Properties.VariableNames)
    preferredValue = double(summaryTable.(preferredField)(1));
    if ~isnan(preferredValue)
        value = preferredValue;
        return;
    end
end
if strlength(string(fallbackField)) > 0 && ismember(fallbackField, summaryTable.Properties.VariableNames)
    value = double(summaryTable.(fallbackField)(1));
end
end

function rank = mapStatusToRank(status)
switch string(status)
    case "ConditionA"
        rank = 2;
    case "ConditionB"
        rank = 1;
    otherwise
        rank = 0;
end
end

function tf = isBetterResidualCandidate(currentMeta, bestMeta)
if currentMeta.statusRank ~= bestMeta.statusRank
    tf = currentMeta.statusRank > bestMeta.statusRank;
    return;
end
if currentMeta.trackingMse ~= bestMeta.trackingMse
    tf = currentMeta.trackingMse < bestMeta.trackingMse;
    return;
end
if currentMeta.saturationFraction ~= bestMeta.saturationFraction
    tf = currentMeta.saturationFraction < bestMeta.saturationFraction;
    return;
end
if currentMeta.actionL2 ~= bestMeta.actionL2
    tf = currentMeta.actionL2 < bestMeta.actionL2;
    return;
end
if currentMeta.episode ~= bestMeta.episode
    tf = currentMeta.episode > bestMeta.episode;
    return;
end
tf = currentMeta.modified > bestMeta.modified;
end
