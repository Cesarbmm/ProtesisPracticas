function checkpointPath = getResidualSeed22CheckpointPath()
%getResidualSeed22CheckpointPath resolves the best tracked checkpoint for seed 22.

srcDir = fileparts(mfilename("fullpath"));
srcRoot = fileparts(srcDir);
matlabRoot = fileparts(srcRoot);
repoRoot = fileparts(fileparts(matlabRoot));
resultsRoot = fullfile(repoRoot, "Agentes", "residual_lift_multiseed");

fallbackPath = getResidualFinalCheckpointPath();

if ~isfolder(resultsRoot)
    checkpointPath = string(fallbackPath);
    return;
end

summaryFiles = dir(fullfile(resultsRoot, "*", "residual_lift_multiseed_summary.csv"));
if isempty(summaryFiles)
    checkpointPath = string(fallbackPath);
    return;
end

bestCandidate = struct();
bestFound = false;

for i = 1:numel(summaryFiles)
    summaryPath = fullfile(summaryFiles(i).folder, summaryFiles(i).name);
    try
        summaryTable = readtable(summaryPath, TextType="string");
    catch
        continue;
    end

    if isempty(summaryTable) || ...
            ~ismember("seed", summaryTable.Properties.VariableNames) || ...
            ~ismember("bestCheckpointPath", summaryTable.Properties.VariableNames)
        continue;
    end

    seedMask = double(summaryTable.seed) == 22;
    if ~any(seedMask)
        continue;
    end

    row = summaryTable(find(seedMask, 1, "first"), :);
    checkpointCandidate = string(row.bestCheckpointPath(1));
    if strlength(checkpointCandidate) == 0 || ~isfile(checkpointCandidate)
        continue;
    end

    status = string(row.finalStatus(1));
    candidate = struct( ...
        "checkpointPath", checkpointCandidate, ...
        "statusRank", mapStatusToRank(status), ...
        "trackingMse", double(row.finalTrackingMse(1)), ...
        "saturationFraction", double(row.finalSaturationFraction(1)), ...
        "actionL2", double(row.finalActionL2(1)), ...
        "deltaActionL2", double(row.finalDeltaActionL2(1)), ...
        "modified", summaryFiles(i).datenum);

    if ~bestFound || isBetterCandidate(candidate, bestCandidate)
        bestCandidate = candidate;
        bestFound = true;
    end
end

if bestFound
    checkpointPath = string(bestCandidate.checkpointPath);
else
    checkpointPath = string(fallbackPath);
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

function tf = isBetterCandidate(currentMeta, bestMeta)
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
if currentMeta.deltaActionL2 ~= bestMeta.deltaActionL2
    tf = currentMeta.deltaActionL2 < bestMeta.deltaActionL2;
    return;
end
if currentMeta.actionL2 ~= bestMeta.actionL2
    tf = currentMeta.actionL2 < bestMeta.actionL2;
    return;
end
tf = currentMeta.modified > bestMeta.modified;
end
