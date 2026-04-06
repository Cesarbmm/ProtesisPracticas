function result = analyzeExperimentRun(runDir, figurePath)
%analyzeExperimentRun summarizes a training or evaluation directory.

arguments
    runDir (1, 1) string
    figurePath (1, 1) string = ""
end

paths = resolveMatlabCodePaths(string(mfilename("fullpath")));
matlabRoot = char(paths.matlabRoot);
addpath(genpath(fullfile(matlabRoot, "src")));
addpath(genpath(fullfile(matlabRoot, "config")));
addpath(genpath(fullfile(matlabRoot, "lib")));
addpath(genpath(fullfile(matlabRoot, "agents")));

result = struct( ...
    "runDir", runDir, ...
    "episodeSummary", summarizeEpisodeDirectory(runDir), ...
    "trainingSummary", struct());

trainingInfoPath = fullfile(runDir, "training_info.mat");
if isfile(trainingInfoPath)
    data = load(trainingInfoPath, "trainingInfo");
    if isfield(data, "trainingInfo")
        if canSummarizeTrainingInfo(data.trainingInfo)
            result.trainingSummary = summarizeTrainingInfo(data.trainingInfo);
        end
        if strlength(figurePath) > 0 && canSummarizeTrainingInfo(data.trainingInfo)
            createTrainingProgressFigure(data.trainingInfo, figurePath);
        end
    end
end
end

function tf = canSummarizeTrainingInfo(trainingInfo)
requiredProperties = ["EpisodeIndex", "EpisodeReward", "AverageReward", "EpisodeQ0"];
availableProperties = string(properties(trainingInfo));
tf = all(ismember(requiredProperties, availableProperties));
end

function summary = summarizeTrainingInfo(trainingInfo)
episodeReward = double(trainingInfo.EpisodeReward(:));
averageReward = double(trainingInfo.AverageReward(:));
episodeQ0 = double(trainingInfo.EpisodeQ0(:));
episodeSteps = double(trainingInfo.EpisodeSteps(:));
episodeIndex = double(trainingInfo.EpisodeIndex(:));
totalAgentSteps = double(trainingInfo.TotalAgentSteps(:));
averageSteps = double(trainingInfo.AverageSteps(:));

firstWindow = min(500, numel(episodeReward));
lastWindow = min(500, numel(episodeReward));

[bestReward, bestRewardIdx] = max(episodeReward);
[bestAverageReward, bestAverageIdx] = max(averageReward);

summary = struct( ...
    "numEpisodes", numel(episodeReward), ...
    "episodeRewardMean", mean(episodeReward, "omitnan"), ...
    "episodeRewardStd", std(episodeReward, 0, "omitnan"), ...
    "episodeRewardFinal", episodeReward(end), ...
    "bestEpisodeReward", bestReward, ...
    "bestEpisodeRewardEpisode", episodeIndex(bestRewardIdx), ...
    "averageRewardFinal", averageReward(end), ...
    "bestAverageReward", bestAverageReward, ...
    "bestAverageRewardEpisode", episodeIndex(bestAverageIdx), ...
    "episodeQ0Final", episodeQ0(end), ...
    "episodeQ0Mean", mean(episodeQ0, "omitnan"), ...
    "stepsMean", mean(episodeSteps, "omitnan"), ...
    "stepsStd", std(episodeSteps, 0, "omitnan"), ...
    "totalAgentStepsFinal", totalAgentSteps(end), ...
    "averageStepsFinal", averageSteps(end), ...
    "firstWindowRewardMean", mean(episodeReward(1:firstWindow), "omitnan"), ...
    "lastWindowRewardMean", mean(episodeReward(end-lastWindow+1:end), "omitnan"), ...
    "firstWindowAverageRewardMean", mean(averageReward(1:firstWindow), "omitnan"), ...
    "lastWindowAverageRewardMean", mean(averageReward(end-lastWindow+1:end), "omitnan"));
end

function createTrainingProgressFigure(trainingInfo, figurePath)
f = figure('Visible', 'off');
set(f, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

plot(trainingInfo.EpisodeIndex, trainingInfo.EpisodeReward, ...
    'Color', [0.45 0.80 1.00], 'LineWidth', 0.8);
hold on
plot(trainingInfo.EpisodeIndex, trainingInfo.AverageReward, ...
    'Color', [0.00 0.45 0.74], 'LineWidth', 2.0);
plot(trainingInfo.EpisodeIndex, trainingInfo.EpisodeQ0, ...
    'Color', [0.93 0.69 0.13], 'LineWidth', 0.9);
hold off

title('Episode reward for Env with rlTD3Agent')
xlabel('Episode Number')
ylabel('Episode Reward')
grid on

[figureDir, ~, ~] = fileparts(figurePath);
if strlength(figureDir) > 0 && ~exist(figureDir, 'dir')
    mkdir(figureDir);
end

saveas(f, figurePath);
close(f);
end
