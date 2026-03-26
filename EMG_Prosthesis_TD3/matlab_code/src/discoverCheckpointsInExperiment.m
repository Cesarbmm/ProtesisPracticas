function [checkpointPaths, checkpointInfo] = discoverCheckpointsInExperiment(experimentDir, samplingPolicy)
%discoverCheckpointsInExperiment resolves Agent*.mat files in an experiment.

arguments
    experimentDir (1, 1) string
    samplingPolicy = struct()
end

if strlength(experimentDir) == 0 || ~isfolder(experimentDir)
    error("Experiment directory '%s' not found.", experimentDir);
end

fileInfo = dir(fullfile(experimentDir, "Agent*.mat"));
if isempty(fileInfo)
    error("No Agent*.mat checkpoints found in %s", experimentDir);
end

checkpointPaths = string(fullfile({fileInfo.folder}, {fileInfo.name}))';
episodes = arrayfun(@inferEpisodeFromCheckpointName, checkpointPaths);
checkpointInfo = table( ...
    checkpointPaths, ...
    string({fileInfo.name})', ...
    episodes(:), ...
    'VariableNames', {'checkpointPath', 'checkpointName', 'episode'});

if all(~isnan(episodes))
    checkpointInfo = sortrows(checkpointInfo, "episode", "ascend");
else
    checkpointInfo = sortrows(checkpointInfo, "checkpointName", "ascend");
end

checkpointPaths = checkpointInfo.checkpointPath;
checkpointInfo = applySamplingPolicy(checkpointInfo, samplingPolicy);
checkpointPaths = checkpointInfo.checkpointPath;
end

function checkpointInfo = applySamplingPolicy(checkpointInfo, samplingPolicy)
if nargin < 2 || isempty(samplingPolicy) || isempty(fieldnames(samplingPolicy))
    return;
end

mode = lower(string(getPolicyField(samplingPolicy, "mode", "all")));
n = double(getPolicyField(samplingPolicy, "n", 0));
k = double(getPolicyField(samplingPolicy, "k", 0));

switch mode
    case {"", "all"}
        return;

    case "tail_last_n"
        if n <= 0
            error("samplingPolicy.n must be positive for mode tail_last_n.");
        end
        checkpointInfo = checkpointInfo(max(1, height(checkpointInfo)-n+1):end, :);

    case "every_k"
        if k <= 0
            error("samplingPolicy.k must be positive for mode every_k.");
        end
        idx = buildEveryKMask(checkpointInfo.episode, k);
        checkpointInfo = checkpointInfo(idx, :);

    case "tail_every_k_last_n"
        if k <= 0 || n <= 0
            error("samplingPolicy.k and samplingPolicy.n must be positive for mode tail_every_k_last_n.");
        end
        idx = buildEveryKMask(checkpointInfo.episode, k);
        checkpointInfo = checkpointInfo(idx, :);
        checkpointInfo = checkpointInfo(max(1, height(checkpointInfo)-n+1):end, :);

    otherwise
        error("Unsupported sampling policy mode '%s'.", mode);
end

if isempty(checkpointInfo)
    error("Sampling policy removed all checkpoints.");
end
end

function idx = buildEveryKMask(episodes, k)
if any(isnan(episodes))
    idx = false(size(episodes));
    idx(1:k:end) = true;
    idx(end) = true;
    return;
end

idx = mod(episodes, k) == 0;
idx(end) = true;
end

function value = getPolicyField(policy, fieldName, defaultValue)
if isfield(policy, fieldName)
    value = policy.(fieldName);
else
    value = defaultValue;
end
end
