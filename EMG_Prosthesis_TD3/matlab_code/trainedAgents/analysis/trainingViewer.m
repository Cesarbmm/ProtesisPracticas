%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: zt_jona
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

22 December 2021
Matlab R2021b.

Mod after Jan 17 2024.
%}


close all
clc

%% Configuración
% trainingFolder = '.\data\episodes\2021-12-22 17 45\';
% trainingFolder = '.\data\episodes\2021-12-29 14 08\';

% after deleting stuborn agent. Shows the initial randomness
% trainingFolder = '.\data\episodes\2022-01-01 17 28\'; % short

% trainingFolder = '.\data\episodes\2022-01-01 19 13\'; % 1 hour

% with hard reset
% trainingFolder = '.\data\episodes\2022-01-01 20 18\'; % 56 random only at the beggining
% trainingFolder = '.\data\episodes\2022-01-01 20 41\'; % 40

% fast episodes
% trainingFolder = '.\data\episodes\2022-01-01 21 07\'; % 341


% motor fixation: trapezoidal reward
% trainingFolder = '.\data\episodes\2022-01-05 11 19\'; % 54

% missing files?
% trainingFolder = '.\data\episodes\2022-01-05 11 59\';  % 58

% without resetEncoder
% trainingFolder = '.\data\episodes\2022-01-05 13 09\';  % 145

% trainingFolder = '.\data\episodes\darkAge\2022-01-05 14 12\';  %  539
trainingFolder = 'C:\trainedAgents\00_oldy\lr_2_\24-01-17 12 19';  %  539

%% ---------------- new fingers and motors
%-- first contact
% trainingFolder = '.\data\episodes\2022-01-14 17 10\';  %  6
% trainingFolder = '.\data\episodes\2022-01-14 17 13\';  %  35
% trainingFolder = '.\data\episodes\2022-01-19 20 50\';  %  31
% trainingFolder = '.\data\episodes\2022-01-20 19 42\';  %  3

% new limits
% trainingFolder = '.\data\episodes\2022-01-22 19 42\';  %  17
% trainingFolder = '.\data\episodes\2022-01-22 19 58\';  %  50
% trainingFolder = '.\data\episodes\2022-01-24 11 28\';  %  44

%% ------------ solving dir issue
% adjusting motor 2 imbalance
% trainingFolder = '.\data\episodes\2022-01-25 12 16\';  %  ---
% trainingFolder = '.\data\episodes\2022-01-25 12 38\';  %

%% new rewards and gaps lims
% trainingFolder = '.\data\episodes\2022-01-25 19 03\';  %
% trainingFolder = '.\data\episodes\2022-01-25 19 10\';  %
% default values
% trainingFolder = '.\data\episodes\2022-01-25 19 26\';  %  329, 1hora
% trainingFolder = '.\data\episodes\2022-01-26 11 54\';
% trainingFolder = '.\data\episodes\2022-01-26 12 16\';
% trainingFolder = '.\data\episodes\2022-01-26 12 23\';  % 519,moved reward?
% lower learning rate
% trainingFolder = '.\data\episodes\2022-01-26 16 56\';  % 249, 0.001

% trainingFolder = '.\data\episodes\2022-01-27 10 43\';  % 249, 0.001

% trainingFolder = '.\data\episodes\2022-01-27 15 36\';  % brainer, 0.005,109
% trainingFolder = '.\data\episodes\2022-01-28 11 17\';  % largebrainer, 0.005,

%% get data
rewards = [];
actions = [];
encoder = [];
flexEq = [];
encoderAdjusted = [];
episodeTimestamp = [];

idxRepetition = []; % index of sample from the dataset used for training episode

ns = [];
%%
episodeLims = 1;
encoderLims = 1;

files = dir(fullfile(trainingFolder, 'episode*.mat'));
% ignoring episode 1
c = 0;
tamsFlexs = [];
numEpisodes = numel(files);
for f = files'
    % name = sprintf('episode%d.mat', f);
    % try
    %     vars = load([trainingFolder name]);
    % 
    % catch
    %     warning('file %d not found', f)
    %     continue
    % end
    vars = load(fullfile(f.folder, f.name));

    n = numel(vars.rewardLog);
    ns = [ns; n];
    episodeLims = [episodeLims episodeLims(end) + n + 1];

    rewards = [rewards; vars.rewardLog; nan];
    actions = [actions; vars.actionLog; nan(1, 4)];
    idxRepetition = [idxRepetition; vars.repetitionId];

    if isfield(vars, 'episodeTimestamp')
        episodeTimestamp = [episodeTimestamp; vars.episodeTimestamp];
    end
    % acopling data
    sizesEnc = cellfun(@(x)size(x,1),vars.encoderLog);
    sizesFlex = cellfun(@(x)size(x,1),vars.flexConvertedLog);
    pos = min([sizesEnc sizesFlex], [], 2);
    n2 = sum(pos);

    % encoderLog = cat(1, vars.encoderLog{:});
    % flexConvertedLog = cat(1, vars.flexConvertedLog{:});
    for i = 1:numel(sizesEnc)
        encoder = [encoder; vars.encoderLog{i}(1:pos(i), :)];
        encoderAdjusted = [encoderAdjusted;
            vars.encoderAdjustedLog{i}(1:pos(i), :)];

        flexEq = [flexEq; vars.flexConvertedLog{i}(1:pos(i), :)];
    end
    tamsFlexs = [tamsFlexs n2];

    encoder = [encoder; nan(1, 4)];
    encoderAdjusted = [encoderAdjusted; nan(1, 4)];
    flexEq = [flexEq; nan(1, 4)];

    encoderLims = [encoderLims encoderLims(end) + n2 + 1];

    if ~isequal(sizesEnc, sizesFlex)
        c = c + 1;
        warning('Diferente tamaño en %s %d-%d', name, ...
            sum(sizesEnc), sum(sizesFlex))
    end
end


%%
f = figure;
s0 = stackedplot(f, rewards, 'o:', 'MarkerSize',3);

ax = findobj(s0.NodeChildren, 'Type','Axes');
set(ax, 'XTick', episodeLims(1:end - 1), 'XTickLabel', 1:numEpisodes ...
    , 'XGrid', 'on')
xlabel(s0, 'episodes')
% ax.XTick = episodeLims;
% ax.XTickLabel = '';
% ax.XGrid = 'on';
title(s0, 'Rewards')

f.KeyPressFcn = @fcnFigMov;
%
set(ax, 'XLim', [episodeLims(1) episodeLims(25)])
%%
f1 = figure();
s1 = stackedplot(f1, 1:size(actions,1),actions, '.:');

ax1 = findobj(s1.NodeChildren, 'Type','Axes');
set(ax1, 'XTick', episodeLims(1:end - 1), 'XTickLabel', 1:numEpisodes ...
    , 'XGrid', 'on', 'YTick', [-255 0 255], 'YGrid', 'on')
title(s1, 'Actions during training')
s1.DisplayLabels = {'Action M1','Action M2', 'Action M3', 'Action M4'};
xlabel(s1, 'episodes')
f1.KeyPressFcn = @fcnFigMov;
set(ax1, 'XLim', [episodeLims(1) episodeLims(25)])
%%
breakLimit = definitions('breakLimit');
fingers = definitions('fingers');

f2 = figure();
xl = [1 50];
for i = 1:4
    ax = subplot(4, 1, i);
    plot(ax, encoder(:, i), ':')
    hold(ax, 'on')
    plot(ax, flexEq(:, i))
    plot(ax, encoderAdjusted(:, i))

    bl = breakLimit.(fingers{i});
    % yline(ax, bl * [-1 1], ':')

    % outside of range
    xS = find(abs(encoder(:, i)) > bl);
    yS = encoder(xS, i);
    scatter(ax, xS, yS, 'red','filled')

    ax.XTick = encoderLims(1:end - 1);
    ax.XTickLabel = '';
    ax.XLim = [encoderLims(xl(1)) encoderLims(xl(2))];
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.YTick = [-bl 0 bl];
    ax.YLim = [-bl-400 bl+400];
    ylabel(ax, sprintf('Position M %d',i ))
    ax.XTickLabel = 1:numEpisodes;
end
legend(ax,{'Encoder', 'Flex (adjusted)', 'enc (adjusted)'}, ...
    'Location', 'best')

% zoom(f2,'xon')

f2.KeyPressFcn = @fcnFigMov;

%% times episodes
if ~isempty(episodeTimestamp)
    episodeTimestamp(:, 2) = episodeTimestamp(:, 2) - episodeTimestamp(:, 1);
    episodeTimestamp(:, 2) = [0; episodeTimestamp(1:end - 1, 2)];
    episodeTimestamp = [episodeTimestamp [0;ns(1:end - 1)]*0.2];


    ax3 = figurePRO();
    plot(ax3, 0:size(episodeTimestamp, 1) - 1, episodeTimestamp)
    legend(ax3, 'episode', 'positioning', 'expected time?', 'Location','best')
    ax3.XTick = 0:10:size(episodeTimestamp, 1);
    ax3.XGrid = 'on';
    xlabel(ax3, 'Episodes')
    ylabel(ax3, 'Seconds')
    title(ax3, 'Times during training')
end

%%

size(idxRepetition, 1)
%% dataset comp
% idxRepetition(11)
