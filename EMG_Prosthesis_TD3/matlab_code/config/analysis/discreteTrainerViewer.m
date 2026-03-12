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
%}


close all
clc
tic 
% warning off backtrace

%% Configuración
% 1st
% trainingFolder = '.\data\episodes\agent0\2022-02-02 11 48\';

%
% new limits
% trainingFolder = '.\data\episodes\agent0\2022-02-02 19 39\';
% trainingFolder = '.\data\episodes\agent0\2022-02-02 20 32\'; % continuation anterior

% trainingFolder = '.\data\episodes\slowLearning\2022-02-03 10 13\';%388

% trainingFolder = '.\data\episodes\brainer\2022-02-03 11 31\';%

%_____ dqn0
%trainingFolder = '.\data\episodes\dqn0\2022-02-07 11 14\';%149
% trainingFolder = '.\data\episodes\dqn0\2022-02-07 12 27\';%213
% trainingFolder = '.\data\episodes\dqn0\2022-02-08 13 55\';% 839!!

%a,b,c,d,e
% trainingFolder = '.\data\episodes\dqn0\2022-02-08 18 08\';% !! after dqn0

% -- avg
% trainingFolder = '.\data\episodes\cAvenger_pg2\2022-02-14 18 19\';
% trainingFolder = '.\data\episodes\aAvenger\2022-02-14 18 16\';

%RT
% trainingFolder = '.\data\episodes\2022-02-16 12 04\';
% trainingFolder = '.\data\episodes\aAvenger_RT\2022-02-16 12 32\';
% trainingFolder = '.\data\episodes\aAvenger_RT\2022-02-16 13 11\';
% trainingFolder = '.\data\episodes\aAvenger_RT\2022-02-17 10 59\';
% trainingFolder = '.\data\episodes\aAvenger_RT\2022-02-17 11 14\';%very wrong
% trainingFolder = '.\data\episodes\aAvenger\2022-02-17 11 31\';

% trainingFolder = '.\data\episodes\aAvenger_empty\2022-02-16 18 49\'; %
% trainingFolder = '.\data\episodes\aAvenger_empty\2022-02-16 20 29\'; %


%---- DISCRETE DIRECTIONAL REWARDING
% trainingFolder = '.\data\episodes\aAvenger\2022-02-21 19 02\'; %1034
% trainingFolder = '.\data\episodes\bAvenger_pG\2022-02-21 20 42\';
% trainingFolder = '.\data\episodes\dAvenger_traditional\2022-02-21 20 44\';

%---- Distance rewarding
% trainingFolder = '.\data\episodes\aAvenger\2022-02-22 10 22\';

% trainingFolder = '.\data\episodes\aDQN_faster\2022-02-22 12 37\';
% trainingFolder = '.\data\episodes\bDQN_buffer\2022-02-22 12 37\';
% trainingFolder = '.\data\episodes\cDQN_slower\2022-02-22 12 38\';
% trainingFolder = '.\data\episodes\dDQN_lstm_small\2022-02-22 12 40\';

%--- Pure distance
% trainingFolder = '.\data\episodes\aDQN_faster\2022-02-22 17 46\';
% trainingFolder = '.\data\episodes\bDQN_buffer\2022-02-22 17 47\';
% trainingFolder = '.\data\episodes\cDQN_slower\2022-02-22 17 49\';%!
% trainingFolder = '.\data\episodes\dDQN_lstm_small\2022-02-22 17 50\';

%--RT
% trainingFolder = '.\data\episodes\cDQN_slower_RT_distanceRewarding\2022-02-22 21 24\';
% trainingFolder = '.\data\episodes\cDQN_slower_RT_distanceRewarding\2022-02-22 21 55\';

%%---New dataset
%Tunes
% trainingFolder = '.\data\episodes\09aTune\2022-03-04 17 44\';
% trainingFolder = '.\data\episodes\bDQN_buffer\2022-03-04 17 45\';
% trainingFolder = '.\data\episodes\cDQN_slower\2022-03-04 17 46\';
% trainingFolder = '.\data\episodes\dDQN_lstm_small\2022-03-04 17 47\';
% trainingFolder = '.\data\episodes\eDQN_lstm_big\2022-03-04 17 48\';

% trainingFolder = '.\data\episodes\09aTune\2022-03-04 19 36\';
% trainingFolder = '.\data\episodes\09bTune_slower\2022-03-04 19 36\';
% trainingFolder = '.\data\episodes\09cTune_faster\2022-03-04 19 37\';
% trainingFolder = '.\data\episodes\09dTune_MC\2022-03-04 19 39\';
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-04 19 40\';

%----------------------bug recorded glove fixed
% trainingFolder = '.\data\episodes\09aTune\2022-03-05 12 57\';
% trainingFolder = '.\data\episodes\09bTune_slower\2022-03-05 12 59\';
% trainingFolder = '.\data\episodes\09cTune_faster\2022-03-05 13 02\';
% trainingFolder = '.\data\episodes\09dTune_MC\2022-03-05 13 04\';
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-05 13 06\';

% triple action
% trainingFolder = '.\data\episodes\09aTune\2022-03-05 15 11\';
% trainingFolder = '.\data\episodes\09bTune_slower\2022-03-05 15 11\';
% trainingFolder = '.\data\episodes\09cTune_faster\2022-03-05 15 12\';
% trainingFolder = '.\data\episodes\09dTune_MC\2022-03-05 15 13\';
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-05 15 14\';


% comparing datasets
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-06 14 03\'; % full
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-06 14 04\'; % short
% trainingFolder = '.\data\episodes\09eTune_greedy\2022-03-06 14 05\'; % new

%alfas
% trainingFolder = '.\data\episodes\10Alphas_ss\\2022-03-06 16 10\';
% trainingFolder = '.\data\episodes\10Alphas_s\\2022-03-06 16 12\';
% trainingFolder = '.\data\episodes\10Alphas_L\2022-03-06 16 13\';
% trainingFolder = '.\data\episodes\10Alphas_LL\2022-03-06 16 15\';

% gammas
% trainingFolder = '.\data\episodes\11Agamma_w\\2022-03-06 17 36\';
% trainingFolder = '.\data\episodes\11Bgamma_x\\2022-03-06 17 36\';
% trainingFolder = '.\data\episodes\11Cgamma_y\2022-03-06 17 40\';
% trainingFolder = '.\data\episodes\11Dgamma_z\2022-03-06 17 40\';


% TDLambda
% trainingFolder = '.\data\episodes\12TDL_1\2022-03-06 19 25\';
% trainingFolder = '.\data\episodes\12TDL_4\2022-03-06 19 24\';
% trainingFolder = '.\data\episodes\12TDL_6\2022-03-06 19 24\';
% trainingFolder = '.\data\episodes\12TDL_8\2022-03-06 19 24\';

% gammas 2 h
% trainingFolder = '.\data\episodes\13GammH1_0\2022-03-07 13 00\';
% trainingFolder = '.\data\episodes\13GammH1_0.3\2022-03-07 13 00\';
% trainingFolder = '.\data\episodes\13GammH1_0.6\2022-03-07 13 00\';
% trainingFolder = '.\data\episodes\13GammH1_1\2022-03-07 13 01\';

% batch
% trainingFolder = '.\data\episodes\14batch-256\2022-03-07 15 47\';
% trainingFolder = '.\data\episodes\14batch-1024\2022-03-07 15 47\';
% trainingFolder = '.\data\episodes\14batch-2048\2022-03-07 15 47\';
% trainingFolder = '.\data\episodes\14batch-4096\2022-03-07 15 48\';


% %% neurons
% trainingFolder = '.\data\episodes\15neuron-4\2022-03-07 20 51\';
% trainingFolder = '.\data\episodes\15neuron-8\2022-03-07 20 52\';
% trainingFolder = '.\data\episodes\15neuron-32\2022-03-07 20 54\';
% trainingFolder = '.\data\episodes\15neuron-64\2022-03-07 20 54\';


% %% act fcn
% trainingFolder = '.\data\episodes\16ActFcn-elu\2022-03-08 12 10\';
% trainingFolder = '.\data\episodes\16ActFcn-leakyRelu\2022-03-08 12 11\';
% trainingFolder = '.\data\episodes\16ActFcn-swish\2022-03-08 12 11\';
% trainingFolder = '.\data\episodes\16ActFcn-tanh\2022-03-08 12 11\';

% %% archi
% trainingFolder = '.\data\episodes\17Archi-1L-12\2022-03-08 14 44\';
% trainingFolder = '.\data\episodes\17Archi-3L-10\2022-03-08 14 44\';
% trainingFolder = '.\data\episodes\17Archi-4L-9\2022-03-08 14 44\';
% trainingFolder = '.\data\episodes\17Archi-5L-9\2022-03-08 14 45\';

% %% 18-eps
% trainingFolder = '.\data\episodes\18Eps-1e-2\2022-03-09 12 49\';
% trainingFolder = '.\data\episodes\18Eps-1e-3\2022-03-09 12 50\';
% trainingFolder = '.\data\episodes\18Eps-3e-3\2022-03-09 12 49\';
% trainingFolder = '.\data\episodes\18Eps-5e-4\2022-03-09 12 50\';


% %% 19-summary
% trainingFolder = '.\data\episodes\19Summ-chosen\2022-03-09 18 45\';
% trainingFolder = '.\data\episodes\19Summ-noDouble\2022-03-09 18 45\';

% %% 20-L2
% trainingFolder = '.\data\episodes\20L2-1e-2\2022-03-12 09 50\';
% trainingFolder = '.\data\episodes\20L2-1e-3\2022-03-12 09 50\';
% trainingFolder = '.\data\episodes\20L2-1e-5\2022-03-12 09 50\';
% trainingFolder = '.\data\episodes\20L2-1e-6\2022-03-12 09 51\';


% %% 21-momentum
% trainingFolder = '.\data\episodes\21Momen-0.5\2022-03-12 21 51\';
% trainingFolder = '.\data\episodes\21Momen-0.7\2022-03-12 21 51\';
% trainingFolder = '.\data\episodes\21Momen-0.95\2022-03-12 21 52\';
% trainingFolder = '.\data\episodes\21Momen-0.99\2022-03-12 21 52\';

% %% 22-alfa2
% trainingFolder = '.\data\episodes\22_alpha2-1\2022-03-15 12 42\';
% trainingFolder = '.\data\episodes\22_alpha2-1e-1\2022-03-15 12 41\';
% trainingFolder = '.\data\episodes\22_alpha2-5e-4\2022-03-15 12 41\';
% trainingFolder = '.\data\episodes\22_alpha2-1e-4\2022-03-15 12 41\';

% %% 23-n2
% trainingFolder = '.\data\episodes\23_neuron2-1\2022-03-15 19 22\';
% trainingFolder = '.\data\episodes\23_neuron2-2\2022-03-15 19 22\';
% trainingFolder = '.\data\episodes\23_neuron2-12\2022-03-15 19 23\';
% trainingFolder = '.\data\episodes\23_neuron2-24\2022-03-15 19 23\';

% %% 24-momen2
% trainingFolder = '.\data\episodes\24_momen2-0.77\2022-03-16 09 41\';
% trainingFolder = '.\data\episodes\24_momen2-0.84\2022-03-16 09 41\';
% trainingFolder = '.\data\episodes\24_momen2-0.9\2022-03-16 09 42\';
% trainingFolder = '.\data\episodes\24_momen2-0.92\2022-03-16 09 42\';

%% 24-momen2
% trainingFolder = '.\data\episodes\25_smoothF-1e-1\2022-03-16 12 58\';
% trainingFolder = '.\data\episodes\25_smoothF-1e-2\2022-03-16 12 58\';
% trainingFolder = '.\data\episodes\25_smoothF-1e-4\2022-03-16 12 58\';
% trainingFolder = '.\data\episodes\25_smoothF-1e-5\2022-03-16 12 59\';


%% --- pretrained continuation
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-17 09 58\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-17 10 34\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-26 13 36\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT_ep0.1\2022-03-26 21 29\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT_ep0.7\2022-03-26 21 46\';

%---sim
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-26 12 55\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-26 12 59\';
% trainingFolder = '.\data\episodes\momen2-0.9_RT\2022-03-26 13 57\';

%% from zero
% trainingFolder = '.\data\episodes\24_momen2-0.9\2022-03-17 10 52\';


%% final fine tuning
% trainingFolder = '.\data\episodes\final_eps0.3\2022-03-27 17 12\';
% trainingFolder = '.\data\episodes\final_eps0.3_alf1e-4\2022-03-27 18 04\';
% trainingFolder = '.\data\episodes\final_eps0.3_alf5e-5\2022-03-27 18 34\'; %best?

%% EVALUATION RANDOM AGENT
% trainingFolder = '.\data\evaluation\24_momen2-0.9\2022-04-05 16 33\';


%% Eval trained agent
%reward -40
% trainingFolder = '.\data\evaluation\final_eps0.3_alf1e-5\2022-04-07 11 24\';

%reward -60: 400 420! valid
% trainingFolder = '.\data\evaluation\final_eps0.3_alf1e-5\2022-04-07 11 31\';

%reward -40: 400 ! important used evaluation trained agent
% trainingFolder = '.\data\evaluation\final_eps0.3_alf1e-5\2022-04-07 11 39\';

% trainingFolder = 'C:\trainedAgents\00_oldy\lr_2_\24-01-17 12 19';  %  539

% trainingFolder = 'C:\trainedAgents\00_oldy\baseline_Denis_RAW\24-01-18 18 46';  %  10k
trainingFolder = 'C:\trainedAgents\00_oldy\beaseline\24-01-17 19 20';  %  10k

%%
addpath(genpath("src"))
%% get data
rewards = [];
rewardsTotalEpisode = [];
actions = [];
actionsSat = [];
encoder = [];
flexEq = [];
episodeTimestamp = [];
encoderAdjusted = [];

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
    name = f.name;
     vars = load(fullfile(f.folder, f.name));

    n = numel(vars.rewardLog);
    ns = [ns; n];
    episodeLims = [episodeLims episodeLims(end) + n + 1];

    rewards = [rewards; vars.rewardLog; nan];
    rewardsTotalEpisode = [rewardsTotalEpisode; sum(vars.rewardLog)];
    actions = [actions; vars.actionLog; nan(1, 4)];
    actionsSat = [actionsSat; vars.actionSatLog; nan(1, 4)];
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

tiempo = toc;
fprintf('Reading all in %.2f [s] or %.2f [min]\n', tiempo, tiempo/60);
%% rewards resumen--Figure 1
axR = figurePRO();
plot(axR, rewardsTotalEpisode, 'o')

hold(axR, 'on')
window = 30;
M = movmean(rewardsTotalEpisode, window);
plot(M)
title(axR, 'Cumulative reward by episode')
xlabel(axR, 'Episode')
legend(axR, 'Total reward in episode', ...
    sprintf('Average reward in %d episodes', window), ...
    'Location','best', 'Orientation','horizontal')
axR.YGrid = 'on';


%% rewards all detailed--Figure 2
f = figure;
f.WindowState = 'maximized';

s0 = stackedplot(f, rewards, 'o--', 'MarkerSize',3);

axRs = findobj(s0.NodeChildren, 'Type','Axes');
set(axRs, 'XTick', episodeLims(1:end - 1), 'XTickLabel', 1:numEpisodes ...
    , 'XGrid', 'on', 'YGrid', 'on', 'YTick', [0])
xlabel(s0, 'episodes')
% ax.XTick = episodeLims;
% ax.XTickLabel = '';
% ax.XGrid = 'on';
title(s0, 'Rewards')

% f.KeyPressFcn = @fcnFigMov;
%
% set(axRs, 'XLim', [episodeLims(end - 24) episodeLims(end)])

%% table actions--Figure 3

maxVal = max(actions, [],'all');
tActions = array2table([actions actionsSat], 'VariableNames', ...
    {'A1','A2','A3','A4','Asat1','Asat2','Asat3','Asat4'} );

f1 = figure();
colororder(f1, [0.8500 0.3250 0.0980; 0 0.4470 0.7410]);
f1.WindowState = 'maximized';
% s1 = stackedplot(f1, 1:size(actions,1),actions, '.--');

s1 = stackedplot(f1, tActions, {["A1","Asat1"], ["A2","Asat2"], ...
    ["A3","Asat3"], ["A4","Asat4"]}, '.--');

ax1 = findobj(s1.NodeChildren, 'Type','Axes');
set(ax1, 'XTick', episodeLims(1:end - 1), 'XTickLabel', 1:numEpisodes ...
    , 'XGrid', 'on', 'YTick', maxVal*[-1 0 1], 'YGrid', 'on', ...
    'YLim', 1*[-1 1])
title(s1, 'Actions during training')
% s1.DisplayLabels = {'Action M1','Action M2', 'Action M3', 'Action M4'};
xlabel(s1, 'episodes')

% set(ax1, 'XLim', [episodeLims(end - 24) episodeLims(end)])
% set(ax1, 'XLim', [episodeLims(1) episodeLims(100)])
for i = 1:4
    set(ax1(i), 'YLim', maxVal* [-1 1])
end

%% complete action flexion--Figure 4
breakLimit = definitions('breakLimit');
fingers = definitions('fingers');
flexsLimit = definitions('flexsLimit');
gap = definitions('gap');

f2 = figure();
f2.WindowState = 'maximized';
xl = [1 10];
for i = 1:4
    ax = subplot(4, 1, i);
    plot(ax, encoder(:, i), '.:')

    hold(ax, 'on')

    %------
    yyaxis(ax, 'right')
    plot(ax, flexEq(:, i))
    plot(ax, encoderAdjusted(:, i), 'b:')


    bl = breakLimit.(fingers{i});

    yline(ax, flexsLimit.(fingers{i}), '--r', 'flexlim')
    %-----------
    yyaxis(ax, 'left')
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
    ax.YTick = [0 gap.(fingers{i}) bl];
    ax.YLim = [-400 bl+400];
    ylabel(ax, sprintf('Position M %d',i ))
    ax.XTickLabel = 1:numEpisodes;

    %---------

end
legend(ax,{'Encoder', 'break limit', 'Flex (adjusted)', 'encoAdjusted'},...
    'Location', 'best')

% zoom(f2,'xon')

f2.KeyPressFcn = @fcnFigMov;

%% RMSE
i0 = 1;
mses = [];
metric = 'RMSE';
for i = find(isnan(flexEq(:, 1)))'

    %MAE
    %     mses  = [mses; mean( abs(flexEq(i0:i - 1, :) - ...
    %         encoderAdjusted(i0:i - 1, :)), 'all')];
    mses  = [mses; sqrt(mean( (flexEq(i0:i - 1, :) - ...
        encoderAdjusted(i0:i - 1, :)).^2, 'all'))];
    if i == size(flexEq, 1)
        break
    end
    i0 = i + 1;
end

axMSE = figurePRO();
plot(axMSE, mses, 'o:')

hold(axMSE, 'on')
window = 20;
M = movmean(mses, window);
plot(axMSE, M)
title(axMSE, 'RMSE between flex eq and encoder adjusted by episode')
xlabel(axMSE, 'Episode')
legend(axMSE, 'RMSE in episode', ...
    sprintf('Average RMSE in %d episodes', window), ...
    'Location','best', 'Orientation','horizontal')
axMSE.YGrid = 'on';

%---------
% folderRMSE = '.\data\rmses\';
% 
% w = strsplit(trainingFolder, '\');
% code = [w{end - 2} '...' w{end - 1}];
% saveRMSE= true;
% if saveRMSE
%     save([folderRMSE code '.mat'], "trainingFolder", "metric", "mses")
% end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--- changing limits
% ini = sat( 1390, 1, size(episodeLims, 2) - 8 );
% fin = sat( 1400, 1, size(episodeLims, 2) );
% 
% set(axRs, 'XLim', [episodeLims(ini) episodeLims(fin)])
% set(ax1, 'XLim', [episodeLims(ini) episodeLims(fin)])
% axR.XLim = [ini fin];


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% times episodes--Figure 6
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

%% fig 7
odds = idxRepetition(1:2:end);
evens = idxRepetition(2:2:end);
nA = min(numel(odds), numel(evens));
odds = odds(1:nA);
evens = evens(1:nA);
axDif = figurePRO;
plot(axDif, odds ~= evens)

%%
size(idxRepetition, 1)

%%
% f = figure;
% % subplot(f, 4, 1, 1)
% plot(movmean(actions(:, 1), 5));
%% dataset comp
% idxRepetition(786)

