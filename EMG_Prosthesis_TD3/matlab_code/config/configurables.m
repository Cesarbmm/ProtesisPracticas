function paramsV = configurables(field)
%configurables() returns a struct with the configurable variables of
%training and environment. In every experiment these fields possibly
%change, and thus must be stored in disk. Note that parameters of the agent
%are defined in the corresponding agent file.
%configurables(field) returns a specific variable from the struct.
% IMPORTANT:
%* Some configurations are defined only under some scenarios.
%* Fields are unpacked in the required locations.
%* This file is intended for configuration and hyperparameters calibration.
%* In general, if required, check every @Class to a fully understand of the
%parameters. Recommended to change only COM ports, be careful changing the
%rest of parameters.
%

%{
Laboratorio de Inteligencia y Visión Artificial
ESCUELA POLITÉCNICA NACIONAL
Quito - Ecuador

autor: ztjona!
jonathan.a.zea@ieee.org

"I find that I don't understand things unless I try to program them."
-Donald E. Knuth

12 August 2021


%}

%% avoiding duplicated initialization
persistent params

if ~isempty(params)
    if nargin == 1
        if isfield(params, field)
            paramsV = params.(field);
        else
            warning('field %s not found', field)
            paramsV = params;
        end
    elseif nargin == 0
        paramsV = params;
    end
    return;
end


%% Episode

% --- NOTE: removed
% when true, calls goHomePostion(...) at the end of every episode
 params.returnHomeAtEndEpisode = true; % important with sims
% params.returnHomeAtEndEpisode = false; %train RT

params.maxNumberStepsInEpisodes = 50;% max buffer in episode

% When using prerecorded, waits till data is exhausted, ignores episode
% duration.
params.episodeDuration = 5; % Denis dataset has up to 5 seconds of data

params.period = 0.2; % reading time

params.verbose = true;  % print every statement verbose


%% Simulate or train
% when ``run_training`` is true, the environment trains the agent.
% when false, only uses the agent (simulation aka evaluation). Some configs
% are defined depending on the value of ``run_training``.
params.run_training = true;
% params.run_training = false;


% --- sim options
if ~params.run_training

    params.simOpts = rlSimulationOptions('MaxSteps', 500,... %500 default
        'NumSimulations', 50, ... %default 1
        'StopOnError', 'on', ...%default on
        'UseParallel', false ...%default false
        );
else
    params.RLtrainingOptions = rlTrainingOptions(...
        'MaxEpisodes',50,... % when too many episodes it makes slower creating episode =20000000
        'MaxStepsPerEpisode', params.maxNumberStepsInEpisodes,...
        'StopTrainingCriteria',"AverageReward",...
        'StopTrainingValue', 600,... % new rewards
        'SaveAgentCriteria','EpisodeFrequency', ...
        'SaveAgentValue', 10 ...
        ..., Plots="none" ... % debugging
        );
end


%% RESUME TRAINING
if params.run_training

    % true to start a new training, false to continue training from a
    % previous agent.
    params.newTraining = true;
    % params.newTraining = false;
else
     params.newTraining = false;
end

% --- resuming training or evaluation
if ~params.newTraining

    params.agentFile = ...
        "C:\Users\pc\Desktop\PROTESIS_PRACTICAS\EMG_Prosthesis_TD3\matlab_code\trainedAgents\td3\_\Agent341200.mat";
    params.agent_id = 'best'; % or name
    % params.agentFile = ...
    %     ".\trainedAgents\Agent3.mat";
    % params.agent_id = 'random'; % or name
end


%% Hardware and devices
if params.run_training
    % --- only applicable in training

    % when ``usePrerecorded`` true, loads a dataset (EMG and glove).
    % Otherwise uses real devices (EMG y/o glove).
     params.usePrerecorded = true;
    % params.usePrerecorded = false;

    % use simulator of the prosthesis
    % params.simMotors = true; % run with simulated objects
     params.simMotors = true; % run in hardware/RT

    % when not using prerecordings connects and reads the real glove
     params.connect_glove = false;% for evaluation with glove ref
    % params.connect_glove = true; %execute RT, uses shallow fake glove
else
    % --- only applicable in evaluation|sim
    params.usePrerecorded = true;
    params.simMotors = true;
    params.connect_glove = false; % not need to be defined in evaluation
end

if params.usePrerecorded
    % --- loading dataset

    % params.dataset = "jona_2022"; % it can be a single name
    % everybody together
     params.dataset = {"BLANCA", "CECILIA", "DENIS", "EMILIA", "GABI", "GABRIEL", "IVANNA", "JOE", "JONATHAN", "KHAROL", "MATEO", "SANDRA"}; % or a cell of names.
    % params.dataset = "DENIS";
    % params.dataset = "GABRIEL";
    % params.dataset = "MATEO";
    % params.dataset = "EMILIA";
    % params.dataset = "IVANNA";
    % params.dataset = "CECILIA";
    % params.dataset = "GABI";
    % params.dataset = "JONATHAN";
    params.dataset_folder = '.\data\datasets\Denis Dataset\';
else

    % --- Connection devices Prosthesis
    params.comUNO = "COM4"; % prosthesis device
    params.comGlove = "COM3"; % glove
end


%% rewarding
% parameters of the corresponding reward functions are defined inside it.
params.rewardType = 'legacy_distanceRewarding';% the choosen one
% rewardType = 'discreteDirectionalRewarding'; % not good
% rewardType = 'pureDistanceRewarding'; % not good

params.reward_function = @(env, action, observation) ...
    rewardFunctionSelector(env, params.rewardType, action, observation);


%% Actions
% when true only 1 action for all motors,
% when false, each motor has an action
params.unifyActions = false;

% params.speeds = [170, 170, 255, 170]; % little, idx, thumb, mid
params.speeds = 255* [1, 1, 1, 1]; % little, idx, thumb, mid

% clipping
% when true, the reward function can limit, modify or clip the action.
% to achieve this, the reward function is calculated BEFORE applying the action.
% when false, the reward function is calculated AFTER applying the action.
params.rf_modify_actions = true;

%% Saving

% saves information about the training and episode info.
params.flagSaveTraining = true;
% params.flagSaveTraining = false;

% saving agent progress locally as backup, not in onedrive for overhead.
params.agents_directory = @(agent_id, variant)(fullfile('C:\Users\pc\Desktop\PROTESIS_PRACTICAS\Agentes', ...
    "trainedAgentsProtesisTest", agent_id, variant, ...
    string(datetime("now","Format", "yy-MM-dd HH m s"))));

params.episode_save_freq = 1; % 1 saves every episode.


%% feature extraction
% normalization of EMG features
fileCS = ".\config\normValues.mat";
bars = load (fileCS,"C","S");
params.norm.C = bars.C;
params.norm.S = bars.S;
params.fGetFeatures = @(x)getWmoosFeatures(x,params.norm.C, params.norm.S);

%
%% Normalization

% encoder in state
params.encoder2state_scale = @(x) x./[26500 11500 8500 9000]'; % used to norm state
% scale factor must be column vector

% Normalization of 
%   * flexion after encoder converted
%   * flexion of the reduced glove
% scale factor must be row vector
params.flexJoined_scale = @(x) x./[4092 2046 1023 2046];



%% Action Space Limits
% Límites para acciones continuas (para TD3)
params.minAction = -1 * ones(4,1); % Vector columna de -1s para cada motor
params.maxAction = ones(4,1);      % Vector columna de 1s para cada motor



%% Environment
% Parameters that affect getObservationInfo()
params.numEMGFeatures = 40;
params.stateLength = 44; % num state features: EMG features + motors

% -- Cinematic info: Encoder
% max unreachable limits, uses the limit of the ring|little
% probably not used by the RL matlab toolbox
params.encodersLimits = [-2000 30000];

% -- EMG info
params.EMGFeaturesLimits = [-inf inf];


%% Getting specific field
if nargin == 1
    %     if nargin == 1 && isfield(params, field)
    if isfield(params, field)
        paramsV = params.(field);
    else
        error('in property %s', field)
    end
elseif nargin == 0
    paramsV = params;
end


