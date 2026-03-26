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
persistent overrideKey

override = localGetOverride();
currentOverrideKey = localGetOverrideKey(override);

if ~isempty(params) && ~strcmp(currentOverrideKey, overrideKey)
    params = [];
end

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

params.trainingMaxEpisodes = 12000;
params.trainingSaveAgentEvery = 100;
params.trainingPlots = "training-progress";
params.plotEpisodeOnTest = false;

% --- NOTE: removed
% when true, calls goHomePostion(...) at the end of every episode
 params.returnHomeAtEndEpisode = true; % important with sims
% params.returnHomeAtEndEpisode = false; %train RT

params.maxNumberStepsInEpisodes = 50;% max buffer in episode

% When using prerecorded, waits till data is exhausted, ignores episode
% duration.
params.episodeDuration = 5; % Denis dataset has up to 5 seconds of data

params.period = 0.2; % reading time

params.verbose = false;  % quieter long-run training


%% Simulate or train
% when ``run_training`` is true, the environment trains the agent.
% when false, only uses the agent (simulation aka evaluation). Some configs
% are defined depending on the value of ``run_training``.
params.run_training = true;

% -------------------------------------------------------------------------
% Operator quick guide for the current repo state
%
% Current default below is intentionally left in "train a new base from
% scratch" mode:
%   params.run_training = true
%   params.newTraining = true
%   Launch with:
%       trainInterface('td3','','')
%
% To continue an old plain TD3 agent:
%   params.newTraining = false
%   params.agent_id = "td3"
%   params.agentFile = "C:/ruta/a/AgentXXXX.mat"
%
% To continue an old residual agent directly:
%   params.newTraining = false
%   params.agent_id = "td3_residual_lift"
%   params.agentFile = "C:/ruta/a/ResidualAgentXXXX.mat"
%
% To open a NEW residual line over any base checkpoint, do not edit this
% file every time. Prefer the launcher:
%   run_residual_lift_pilot(struct('baseCheckpointPath',"C:/ruta/a/AgentXXXX.mat"))
%
% Historical published wrapper over Agent7250:
%   run_agent7250_residual_policy_pilot()
% -------------------------------------------------------------------------


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

    params.agentFile = "";
    params.agent_id = 'td3'; % or name
    % Example:
    % params.agentFile = ".\..\..\Agentes\trainedAgentsProtesisTest\td3\_\yy-mm-dd HH M S\Agent2000.mat";
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
params.rewardType = 'trackingMseActionRateReward';% valid baseline after simulator fix
% params.rewardType = 'trackingMseProgressSmoothReward';% stage 2 pilot
% params.rewardType = 'trackingMseActionReward';% stage 1 baseline
% params.rewardType = 'legacy_distanceRewarding';% baseline reference
% rewardType = 'discreteDirectionalRewarding'; % not good
% rewardType = 'pureDistanceRewarding'; % not good
params.rewardActionWeight = 0.01;
params.rewardProgressWeight = 0.30;
params.rewardSmoothnessWeight = 0.05;
params.rewardDeltaActionWeight = 0.05;
params.rewardSaturationThreshold = 0.90;
params.rewardSaturationWeight = 0.02;

params.reward_function = @(env, action, observation) ...
    rewardFunctionSelector(env, params.rewardType, action, observation);


%% Actions
% when true only 1 action for all motors,
% when false, each motor has an action
params.unifyActions = false;

% params.speeds = [170, 170, 255, 170]; % little, idx, thumb, mid
params.speeds = 255* [1, 1, 1, 1]; % little, idx, thumb, mid
params.quantizeCommandsForSimulation = true;
params.actionCommandActivationThreshold = 0.05;
params.actionCommandLevels = [0 64 96 128 160 192 224 255];
params.actionInterfaceVariant = "baselineQuantized";
params.actionWarpDeadzone = 0.05;
params.actionWarpOutputLevels = [64 96 128 160 192 224 255] / 255;

% clipping
% when true, the reward function can limit, modify or clip the action.
% to achieve this, the reward function is calculated BEFORE applying the action.
% when false, the reward function is calculated AFTER applying the action.
params.rf_modify_actions = false;

%% Saving

% saves information about the training and episode info.
params.flagSaveTraining = true;
% params.flagSaveTraining = false;

% saving agent progress locally as backup, not in onedrive for overhead.
params.agents_directory = @(agent_id, variant)(fullfile('..', '..', 'Agentes', ...
    "trainedAgentsProtesisTest", agent_id, variant, ...
    string(datetime("now","Format", "yy-MM-dd HH m s"))));

params.episode_save_freq = 1; % 1 saves every episode.
params.enableDetailedActionDiagnostics = false;
params.savePerMotorMetrics = true;


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



%% TD3 hyperparameters
params.td3.numHiddenUnits = 64;
params.td3.useRecurrent = false; % clean MLP baseline before revisiting recurrent TD3
params.td3.recurrentUnits = 16;
params.td3.sequenceLength = 16;
params.td3.numStepsToLookAhead = 1;
params.td3.actorLearnRate = 1e-4;
params.td3.criticLearnRate = 1e-3;
params.td3.actorL2Regularization = 1e-4;
params.td3.criticL2Regularization = 1e-4;
params.td3.gradientThreshold = 1;
params.td3.targetSmoothFactor = 5e-3;
params.td3.discountFactor = 0.95;
params.td3.miniBatchSize = 64;
params.td3.experienceBufferLength = 1e5;
params.td3.sampleTime = params.period;
params.td3.policyUpdateFrequency = 2;
params.td3.targetUpdateFrequency = 2;
params.td3.explorationStd = 0.2;
params.td3.explorationStdDecayRate = 1e-4;
params.td3.explorationStdMin = 0.02;
params.td3.resetExperienceBufferBeforeTraining = false;
params.td3.targetPolicyStd = 0.2;
params.td3.targetPolicyNoiseClip = 0.5;

%% Residual TD3 over a frozen base checkpoint
params.td3Residual = struct();
if exist("getAgent7250CheckpointPath", "file") == 2
    params.td3Residual.baseCheckpointPath = getAgent7250CheckpointPath();
else
    params.td3Residual.baseCheckpointPath = "";
end
% These fields are consumed by the residual launchers. The published
% default still points to Agent7250, but if you want to create a new
% residual line over another base checkpoint, prefer:
%   run_residual_lift_pilot(struct('baseCheckpointPath',"C:/ruta/a/AgentXXXX.mat"))
% instead of editing this file permanently.
params.td3Residual.baseLabel = "Agent7250";
params.td3Residual.residualScale = 0.20;
params.td3Residual.hiddenUnits = 32;
params.td3Residual.enabled = false;
params.td3Residual.logDiagnostics = true;

%% Environment
% Parameters that affect getObservationInfo()
params.numEMGFeatures = 40;
params.observationVariant = "markov52";
params.emgHistoryLength = 3; % explicit stacked EMG context frames
params.stateLength = params.numEMGFeatures + 3 * numel(params.minAction);

% -- Cinematic info: Encoder
% max unreachable limits, uses the limit of the ring|little
% probably not used by the RL matlab toolbox
params.encodersLimits = [-2000 30000];

% -- EMG info
params.EMGFeaturesLimits = [-inf inf];

params = localApplyOverride(params, override);
params = localFinalizeStateSettings(params, override);
params = localFinalizeModeSettings(params, override);
params = localFinalizeResumeSettings(params);
params = localFinalizeRuntimeSettings(params);
params.reward_function = @(env, action, observation) ...
    rewardFunctionSelector(env, params.rewardType, action, observation);
overrideKey = currentOverrideKey;


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

end

function override = localGetOverride()
if isappdata(0, 'configurables_override')
    override = getappdata(0, 'configurables_override');
else
    override = struct();
end
end

function key = localGetOverrideKey(override)
if isempty(override) || isempty(fieldnames(override))
    key = "__no_override__";
    if isappdata(0, 'configurables_override_key')
        rmappdata(0, 'configurables_override_key');
    end
    return;
end

if isappdata(0, 'configurables_override_key')
    key = string(getappdata(0, 'configurables_override_key'));
else
    key = makeConfigurablesOverrideKey(override);
    setappdata(0, 'configurables_override_key', key);
end
end

function params = localApplyOverride(params, override)
fields = fieldnames(override);
for i = 1:numel(fields)
    params.(fields{i}) = override.(fields{i});
end
end

function params = localFinalizeStateSettings(params, override)
if ~isfield(params, "emgHistoryLength") || isempty(params.emgHistoryLength)
    params.emgHistoryLength = 1;
end

if ~isfield(override, "stateLength")
    if ~isfield(params, "observationVariant") || isempty(params.observationVariant)
        params.observationVariant = "markov52";
    end

    switch string(params.observationVariant)
        case "legacy44"
            params.stateLength = params.numEMGFeatures + numel(params.minAction);
        case "markov52"
            params.stateLength = params.numEMGFeatures + 3 * numel(params.minAction);
        case "stackedEmg132"
            params.stateLength = params.numEMGFeatures * params.emgHistoryLength + ...
                3 * numel(params.minAction);
        otherwise
            error("Unsupported observationVariant '%s'", string(params.observationVariant));
    end
end
end

function params = localFinalizeModeSettings(params, override)
if ~isfield(override, "newTraining")
    params.newTraining = params.run_training;
end
end

function params = localFinalizeResumeSettings(params)
if ~isfield(params, "newTraining") || params.newTraining
    return;
end

if ~isfield(params, "agent_id") || isempty(params.agent_id)
    params.agent_id = "td3";
end

if ~isfield(params, "agentFile") || isempty(params.agentFile)
    params.agentFile = "";
end
end

function params = localFinalizeRuntimeSettings(params)
if params.run_training
    params.RLtrainingOptions = rlTrainingOptions(...
        'MaxEpisodes', params.trainingMaxEpisodes, ...
        'MaxStepsPerEpisode', params.maxNumberStepsInEpisodes, ...
        'StopTrainingCriteria', "EpisodeCount", ...
        'StopTrainingValue', params.trainingMaxEpisodes, ...
        'SaveAgentCriteria', 'EpisodeFrequency', ...
        'SaveAgentValue', params.trainingSaveAgentEvery, ...
        'Plots', params.trainingPlots);
else
    params.simOpts = rlSimulationOptions( ...
        'MaxSteps', 500, ...
        'NumSimulations', 50, ...
        'StopOnError', 'on', ...
        'UseParallel', false);
end
end


