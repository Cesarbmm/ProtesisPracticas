classdef Env < rl.env.MATLABEnvironment
    %ENV class that handles the environment for reinforcement learning
    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona!
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    12 August 2021
    
    Mod after 2024/jan/4
    %}

    %% Properties
    % --- Hardware
    properties (AbortSet=true, GetAccess=public, SetAccess=protected, ...
            Transient=true)
        % AbortSet to avoid recreating object
        % Transient as session dependant
        glove (1,1) {isa(glove, 'Glove')}
        prosthesis (1, 1) {isa(prosthesis, 'Controller')}
        myo (1, 1) {isa(myo, 'Myo')}
    end

    %% Constants
    properties (Constant)
        % env
        v = 2.5; % must be changed in env changes.
    end

    %% only in constructor
    properties (SetAccess=immutable)
        % --- using prerecorded
        usePrerecorded = true;
        % Per-instance so a safety override cannot be masked by class cache.
        simMotors (1, 1) logical = true;
        % Per-instance to avoid stale values after configurables overrides.
        referenceSource (1, 1) string = "glove";
        observationVariant (1, 1) string = "markov52";
        stateLength (1, 1) double = 52;
        numEMGFeatures (1, 1) double = 40;
        emgHistoryLength (1, 1) double = 3;
        intentDecoderEnabled (1, 1) logical = false;
        intentCalibration = struct();
        intentExpectedContext = struct();
        % Per-instance so a source switch cannot retain a glove-only reward.
        reward_function;
        % Configurables are per-instance so experiment overrides remain exact.
        unifyActions;
        episodeDuration;
        speeds;
        period;
        verbose;
        returnHomeAtEndEpisode = false; % preserve historical behavior
        flagSaveTraining;
        episode_save_freq;
        plotEpisodeOnTest;
        maxNumberStepsInEpisodes;
        featureCalculator;
        encoderNormCalculator;
        flexJoined_scaler;
        quantizeCommandsForSimulation;
        actionCommandActivationThreshold;
        actionCommandLevels;
        enableDetailedActionDiagnostics;
        savePerMotorMetrics;
        rf_modify_actions;
        emgSet = {}; % when using prerecordings
        gloveSet = {};
        sizeDataset = 0; % number of samples in dataset

        % -- saving
        episode_folder; % episode output folder
    end

    %% Properties that change during execution
    properties (SetAccess=protected)
        %---episode flags
        episodeType = ''; % EpisodeType.Opening or EpisodeType.Closing
        % Initialize system state
        State = [];

        % Initialize internal flags to indicate episode termination
        isDone = false; % true when episode finished

        c = 0; % steps in episode counter
        episodeCounter = 0;
        repetitionId = -1; % idx of the dataset repetition used in episode
        episodes_shuffled = []; % episodes in the dataset shuffled

        % now these use Timing class
        episodeTic; % timing of each episode
        periodTic;  % timing of each step inside episode

        % real tics-needed for half-hardware execution
        episode_realTic; % timing of each episode
        period_realTic;  % timing of each step inside episode

        % buffer main vars
        emg;
        motorData;
        flexData;
        emgLength;

        % buffers aux vars
        flexConverted;
        adjustEnc;
        referenceTarget = zeros(4, 1);
        trackingPrediction = zeros(4, 1);
        intentTarget = zeros(4, 1);
        intentVelocity = zeros(4, 1);
        intentGateState = struct( ...
            "isActive", false, "onCount", 0, "offCount", 0);
        referenceHistory = nan(0, 4);
        referenceHistoryCount = 0;
        trackingPredictionHistory = nan(0, 4);

        % --- logs: for saving episode recording data
        % timestamp of init of episode with and without home [reset]
        episodeTimestamp = [0, 0];
        encoderLog = {};
        emgLog = {};
        encoderAdjustedLog = {};
        stateLog = [];
        actionLog = [];%history of the actions per epidodes
        actionWarpLog = [];% aligned action before actuator remap
        actionSatLog = [];%history of the actions per epidodes
        actionPwmLog = [];% applied pwm commands per episode
        rewardLog = [];
        rewardVectorLog = [];
        trackingMseLog = [];
        trackingMaeLog = [];
        velocityMseLog = [];
        actionL2Log = [];
        progressTermLog = [];
        smoothnessPenaltyLog = [];
        deltaActionL2Log = [];
        saturationFractionLog = [];
        softSaturationPenaltyLog = [];
        saturationPenaltyLog = [];
        rewardIndividualLog = {};
        rewardInfoLog = {};
        flexConvertedLog = {};
        prevAction = zeros(4,1); % previous effective action for reward
        prevTrackingMse = NaN;
        hasPrevRewardState = false;
        prevEncoderNorm = zeros(4,1); % previous normalized encoder for state
        prevEffectiveActionForState = zeros(4,1); % visible in observation
        emgFeatureHistory = []; % columns ordered as [phi_t phi_t-1 ...]

        wait_in_step = false; % bool to wait period
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        % Contructor method creates an instance of the environment
        function this = Env(agent_dir, usePrerecorded, emgs, gloveDatas)
            % # ---- Data Validation
            arguments
                agent_dir (1, 1) string = "";
                usePrerecorded	(1, 1) logical = false;
                emgs (:, :) cell = {};
                gloveDatas (:, :) cell = {};
            end

            configs = configurables();
            referenceSource = string(configs.referenceSource);
            if referenceSource == "emgIntent" && ~usePrerecorded
                error("Env:EmgIntentRequiresPrerecorded", ...
                    "The no-glove line permits emgIntent only with prerecorded EMG. " + ...
                    "Live Myo access is not authorized.");
            end
            if referenceSource == "emgIntent" && ~configs.simMotors
                error("Env:EmgIntentRequiresSimulation", ...
                    "The no-glove line does not permit physical prosthesis control.");
            end
            allowedIntentRewards = [ ...
                "trackingMseActionRateReward", ...
                "trackingIntentActionRateReward"];
            if referenceSource == "emgIntent" && ...
                    ~any(string(configs.rewardType) == allowedIntentRewards)
                error("Env:UnsupportedEmgIntentReward", ...
                    "The current no-glove line supports emgIntent only with " + ...
                    "an explicitly approved causal reward.");
            end
            if configs.intentDecoderEnabled
                calibrationValidation = validateIntentCalibration( ...
                    configs.intentCalibration, configs.intentExpectedContext);
                if ~calibrationValidation.isValid
                    error("Env:InvalidIntentCalibration", ...
                        "Runtime intent calibration is invalid: %s", ...
                        strjoin(calibrationValidation.issues, "; "));
                end
                timingTolerance = 64 * eps(max(1, abs(configs.period)));
                if abs(configs.intentCalibration.limits.deltaT - ...
                        configs.period) > timingTolerance
                    error("Env:IntentPeriodMismatch", ...
                        "Environment period and intent calibration deltaT must match.");
                end
            end
            if usePrerecorded && (isempty(emgs) || size(emgs, 2) < 2)
                error("Env:InvalidPrerecordedEmg", ...
                    "Prerecorded EMG must be a nonempty N-by-2 cell array.");
            end
            if usePrerecorded && referenceSource == "glove" && isempty(gloveDatas)
                error("Env:MissingGloveData", ...
                    "The historical glove source requires prerecorded glove data.");
            end

            % ------------ Initialize Observation settings
            ObservationInfo = Env.defineObservationInfo();

            % Initialize Action settings
             ActionInfo = Env.defineActionInfo();
            %ActionInfo = Env.defineActionDiscreteInfo();

            % The following line implements built-in functions of RL env
            this = this@rl.env.MATLABEnvironment(...
                ObservationInfo, ActionInfo);

            % --- inmutable properties
            this.episode_folder = agent_dir;
            this.referenceSource = referenceSource;
            this.observationVariant = string(configs.observationVariant);
            this.stateLength = double(configs.stateLength);
            this.numEMGFeatures = double(configs.numEMGFeatures);
            this.emgHistoryLength = double(configs.emgHistoryLength);
            this.intentDecoderEnabled = logical(configs.intentDecoderEnabled);
            this.intentCalibration = configs.intentCalibration;
            this.intentExpectedContext = configs.intentExpectedContext;
            this.simMotors = logical(configs.simMotors);
            this.reward_function = configs.reward_function;
            this.unifyActions = configs.unifyActions;
            this.episodeDuration = configs.episodeDuration;
            this.speeds = configs.speeds;
            this.period = configs.period;
            this.verbose = configs.verbose;
            this.flagSaveTraining = configs.flagSaveTraining;
            this.episode_save_freq = configs.episode_save_freq;
            this.plotEpisodeOnTest = configs.plotEpisodeOnTest;
            this.maxNumberStepsInEpisodes = configs.maxNumberStepsInEpisodes;
            this.featureCalculator = configs.fGetFeatures;
            this.encoderNormCalculator = configs.encoder2state_scale;
            this.flexJoined_scaler = configs.flexJoined_scale;
            this.quantizeCommandsForSimulation = ...
                configs.quantizeCommandsForSimulation;
            this.actionCommandActivationThreshold = ...
                configs.actionCommandActivationThreshold;
            this.actionCommandLevels = configs.actionCommandLevels;
            this.enableDetailedActionDiagnostics = ...
                configs.enableDetailedActionDiagnostics;
            this.savePerMotorMetrics = configs.savePerMotorMetrics;
            this.rf_modify_actions = configs.rf_modify_actions;
            this.log("Defined observation and action space");

            % --- hardware
            this.usePrerecorded = usePrerecorded;

            if usePrerecorded
                this.log("Using prerecorded data");
                this.emgSet = emgs;
                this.sizeDataset = size(emgs, 1);

                % loading with a random episode (i.e. 1)
                this.myo = RecordedMyo(emgs{1});
                if this.referenceSource == "glove"
                    this.gloveSet = gloveDatas;
                    this.glove = RecordedGlove(gloveDatas{1});
                end
            else
                this.log("Connecting to devices");

                this.myo = Myo();

                if this.referenceSource == "glove"
                    if configurables('connect_glove')
                        % real glove
                        this.glove = Glove(configurables("comGlove"));
                    else
                        % overload glove
                        this.glove = FakeGlove();
                    end
                end

                this.log("Created devices");
            end

            % -- simulation
            if this.simMotors

                % when input false it is in simulation
                this.episodeTic = Timing(false, this.period);
                this.periodTic = Timing(false, this.period);

                this.prosthesis = SimController(this.episodeTic);
            else
                % hardware
                % when input true it is in real world hardware
                this.episodeTic = Timing(true);
                this.periodTic = Timing(true);

                com = configurables('comUNO');
                msg = "Connecting to serial port %s\n" + ...
                    "If required," + ...
                    "change the prosthesis port in config\\configurables.m";
                this.log(sprintf( msg, com));
                this.prosthesis = Controller(false, '', com);
            end

            this.wait_in_step = ~this.simMotors || ~this.usePrerecorded;

            if this.wait_in_step
                this.log("Waiting in step");
                this.period_realTic = tic;
                this.episode_realTic = tic;
            else
                this.period_realTic = [];
                this.episode_realTic = [];
            end

            %-----
            % Initialize property values and pre-compute necessary values
            % updateActionInfo(this); % actions always the same

            % validate env
            % this.log("Validating env");
            % this.validateEnvironment();
            % this.log("Validated!");
            this.log("Env. created.");
        end
    end

    %% methods
    % DOCS:
    % [1] https://www.mathworks.com/help/reinforcement-learning/ug/
    % create-custom-matlab-environment-from-template.html
    %
    % Helper methods to create the environment
    % -------- From the docs [1]:
    % The getObservationInfo, getActionInfo, sim, and
    % validateEnvironment functions are already defined in the base
    % abstract class.

    % getObservationInfo(this)
    % actionInfo = getActionInfo(this)
    % validateEnvironment = validateEnvironment(this)
    %sim = sim(this, agente);


    % To create your environment, you must define the constructor,
    % reset, and step functions.
    methods
        InitialObservation = reset(this)
        [Observation,Reward,IsDone,LoggedSignals] = step(this, action)
        [state, enc] = calculateState(this, emg, motorData)
        advanceIntentReference(this, emg)
        [effectiveAction, appliedPwm] = remapActionForActuator(this, action)

        isDone = checkEndEpisode(this)

        loop(this, agent) %

        saveEpisode(this)

        plot_episode(this)

        plot_episode2(this)

        % -----------------------------------------------------------------
        function log(this, msg)
            % prints messages depending on verbose flag.
            if this.verbose
                fprintf('%s|| %s\n', string(datetime("now", "Format", ...
                    'yy-MM-dd HH:m:ss.SSS')), msg);
            end
        end

    end

    %% Other methods
    % /////////////////////////////////////////////////////////////////////
    methods (Access = protected)
        % (optional) update visualization everytime the environment is
        % updated
        % (notifyEnvUpdated is called)
        function envUpdatedCallback(this)
        end
    end

    % /////////////////////////////////////////////////////////////////////
    methods (Static)

        obsInfo = defineObservationInfo()

        %actionInfo = defineActionDiscreteInfo()

        %--- continous version
         actionInfo = defineActionInfo()
    end
end
% More properties at: AbortSet, Abstract, Access, Dependent, GetAccess, ...
% GetObservable, NonCopyable, PartialMatchPriority, SetAccess, ...
% SetObservable, Transient, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/property-attributes.html

% Methods: Abstract, Access, Hidden, Sealed, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html

%https://www.mathworks.com/help/reinforcement-learning/ug/
% create-custom-matlab-environment-from-template.html
