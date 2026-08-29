function [observation, reward, isDone, loggedSignals] = step(this, action)
this.c = this.c + 1;

if iscell(action)
    action = cell2mat(action);
end

if this.unifyActions
    action = action * [1 1 1 1];
end

if ~isnumeric(action)
    error('action must be of numeric type');
end

action = double(action(:));
expectedActionSize = size(this.actionLog, 2);
if numel(action) ~= expectedActionSize
    error('The action size does not match the actionLog size');
end

if ~isempty(this.State)
    this.stateLog(this.c, :) = reshape(double(this.State), 1, []);
end

rawAction = action;
actionInterfaceVariant = string(configurables("actionInterfaceVariant"));
switch actionInterfaceVariant
    case "baselineQuantized"
        warpedAction = rawAction;
    case "alignedContinuousWarp"
        warpedAction = warpActionToAlignedContinuousMagnitude( ...
            rawAction, ...
            configurables("actionWarpDeadzone"), ...
            configurables("actionWarpOutputLevels"));
    otherwise
        error("Unsupported actionInterfaceVariant '%s'.", actionInterfaceVariant);
end

this.actionLog(this.c, :) = rawAction.';
this.actionWarpLog(this.c, :) = warpedAction.';
[effectiveAction, appliedPwm] = this.remapActionForActuator(warpedAction);
this.actionSatLog(this.c, :) = effectiveAction.';
this.actionPwmLog(this.c, :) = appliedPwm.';

%% applying action
drawnow
completed = this.prosthesis.sendAllSpeed(...
    appliedPwm(1), appliedPwm(2), appliedPwm(3), appliedPwm(4));

assert(completed, 'ERROR during sending speed to controller')

%% waiting data, applying action.
while this.periodTic.toc() < this.period
    drawnow
end

if this.wait_in_step
    while toc(this.period_realTic) < this.period
        drawnow
    end
end

%% reading hardware
% Advance episode time before reading the prosthesis so the commanded
% action affects the current transition instead of the next one.
this.episodeTic.toc(this.c);

if this.usePrerecorded
    t_elapsed = this.periodTic.elapsed_time;
    assert(t_elapsed > 0.9*this.period && t_elapsed < 1.1*this.period, ...
        "time elapsed %.2f is incorrect, must be %.2f", ...
        t_elapsed, this.period)
    emg = this.myo.readEmg(t_elapsed);
    if this.referenceSource == "glove"
        flexData = this.glove.read(t_elapsed);
    end
else
    emg = this.myo.readEmg();
    if this.referenceSource == "glove"
        flexData = this.glove.read();
    end
end

motorData = this.prosthesis.read();
this.encoderLog{this.c} = motorData;
if this.simMotors
    safetyDiagnostics = this.prosthesis.getPositionSafetyDiagnostics();
    cumulativeSafetyCount = ...
        safetyDiagnostics.interventionCountByMotor;
    stepSafetyCount = cumulativeSafetyCount - ...
        this.positionSafetyInterventionCountByMotor;
    if any(stepSafetyCount < 0)
        error("Env:InvalidPositionSafetyDiagnostics", ...
            "Simulation position-safety counts must be monotonic.");
    end
    this.positionSafetyInterventionLog(this.c, :) = stepSafetyCount;
    this.positionSafetyInterventionCountByMotor = cumulativeSafetyCount;
end

if isempty(emg)
    emg = this.emg;
    warning("--------------------emg is empty")
else
    this.emg = emg;
end

if isempty(motorData)
    motorData = this.motorData;
    warning("--------------------motorData is empty")
else
    this.motorData = motorData;
end

if this.referenceSource == "glove"
    if isempty(flexData)
        flexData = this.flexData;
        warning("--------------------flexdata is empty")
    else
        this.flexData = flexData;
    end
end

%% end step timing
this.periodTic.tic();
if this.wait_in_step
    this.period_realTic = tic;
end

if this.referenceSource == "glove"
    this.log(sprintf(...
        '%d. T=%.3f[s]. EmgSize %d. encodersSize %d. glovesize %d',...
        this.c, this.episodeTic.elapsed_time,...
        size(emg, 1), size(motorData, 1), size(flexData, 1)))
else
    this.log(sprintf(...
        '%d. T=%.3f[s]. EmgSize %d. encodersSize %d. reference %s',...
        this.c, this.episodeTic.elapsed_time,...
        size(emg, 1), size(motorData, 1), this.referenceSource))
end

%% Reward and normalized tracking data
if this.referenceSource == "glove"
    % Historical glove path: preserve conversion, sampling and reward inputs.
    this.prevEffectiveActionForState = effectiveAction(:);
    [~] = this.updateEmgFeatureHistory(emg, false);
    [this.State, currentEncoderNorm] = this.calculateState(emg, motorData);
    observation = this.State;
    this.flexConverted = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
    this.adjustEnc = this.flexJoined_scaler(encoder2Flex(this.motorData));
    this.referenceTarget = this.flexConverted(end, :)';
    this.trackingPrediction = this.adjustEnc(end, :)';
    rewardContext = [];
else
    % action_t is evaluated against the reference already visible in
    % state_t. The newly read EMG is reserved for state_(t+1).
    currentEncoderNorm = this.encoderNormCalculator(motorData(end, :)');
    this.referenceTarget = this.intentTarget(:);
    this.trackingPrediction = currentEncoderNorm(:);
    rewardContext = struct( ...
        "trackingTarget", this.referenceTarget(:)', ...
        "trackingPrediction", this.trackingPrediction(:)', ...
        "trackingVelocityTarget", this.intentVelocity(:)', ...
        "trackingVelocityPrediction", ...
            ((currentEncoderNorm(:) - this.prevEncoderNorm(:)) ./ this.period)', ...
        "decisionPositionPrediction", this.prevEncoderNorm(:)', ...
        "previousEffectiveAction", this.prevAction(:)', ...
        "referenceSource", this.referenceSource);
end

[reward, rewardVector, rewardInfo] = this.reward_function( ...
    this, effectiveAction, rewardContext);
[reward, rewardVector] = normalizeRewardOutputs( ...
    reward, rewardVector, expectedActionSize);
if this.referenceSource == "emgIntent"
    velocityError = rewardContext.trackingVelocityPrediction - ...
        rewardContext.trackingVelocityTarget;
else
    % The historical glove reward has no velocity target. Keep an explicit
    % neutral value so old episode readers receive the additive metric.
    velocityError = zeros(1, 4);
end
rewardContextForContract = struct( ...
    "effectiveAction", effectiveAction(:)', ...
    "previousEffectiveAction", this.prevAction(:)', ...
    "trackingError", (this.trackingPrediction - this.referenceTarget)', ...
    "velocityError", velocityError, ...
    "softSaturationThreshold", ...
        configurables("intentRewardSoftActionLimit"), ...
    "referenceSource", this.referenceSource);
rewardInfo = normalizeRewardInfo(rewardInfo, rewardContextForContract);

referenceUsedForReward = this.referenceTarget(:);
predictionUsedForReward = this.trackingPrediction(:);

if this.referenceSource == "emgIntent"
    % Only after reward_t is fully validated may EMG_(t+1) update the
    % dynamic reference and returned observation.
    this.intentProvenanceLog{this.c} = ...
        this.advanceIntentReference(emg, currentEncoderNorm);
    this.prevEffectiveActionForState = effectiveAction(:);
    [~] = this.updateEmgFeatureHistory(emg, false);
    [this.State, observedEncoderNorm] = this.calculateState(emg, motorData);
    encoderTolerance = 64 * eps(max(1, max(abs(currentEncoderNorm))));
    if any(abs(observedEncoderNorm(:) - currentEncoderNorm(:)) > ...
            encoderTolerance)
        error("Env:EncoderAlignmentMismatch", ...
            "Reward and next observation used different encoder samples.");
    end
    observation = this.State;
end

% Commit the generic tracking history only after the complete reward
% boundary has been validated. A failing reward cannot advance the history.
this.referenceHistoryCount = this.referenceHistoryCount + 1;
this.referenceHistory(this.referenceHistoryCount, :) = ...
    referenceUsedForReward(:)';
this.trackingPredictionHistory(this.referenceHistoryCount, :) = ...
    predictionUsedForReward(:)';

%% logs
this.emgLog{this.c} = emg;
if this.referenceSource == "glove"
    this.encoderAdjustedLog{this.c} = this.adjustEnc;
end
this.rewardLog(this.c) = reward;
this.rewardVectorLog(this.c, :) = rewardVector;
this.trackingMseLog(this.c) = rewardInfo.trackingMse;
this.trackingMaeLog(this.c) = rewardInfo.trackingMae;
this.velocityMseLog(this.c) = rewardInfo.velocityMse;
this.actionL2Log(this.c) = rewardInfo.actionL2;
this.progressTermLog(this.c) = rewardInfo.progressTerm;
this.smoothnessPenaltyLog(this.c) = rewardInfo.smoothnessPenalty;
this.deltaActionL2Log(this.c) = rewardInfo.deltaActionL2;
this.saturationFractionLog(this.c) = rewardInfo.saturationFraction;
this.softSaturationPenaltyLog(this.c) = ...
    rewardInfo.softSaturationPenalty;
this.saturationPenaltyLog(this.c) = rewardInfo.saturationPenalty;
this.rewardIndividualLog{this.c} = rewardVector;
this.rewardInfoLog{this.c} = rewardInfo;
if this.referenceSource == "glove"
    this.flexConvertedLog{this.c} = this.flexConverted;
end
this.prevAction = effectiveAction(:);
this.prevTrackingMse = rewardInfo.trackingMse;
this.hasPrevRewardState = true;
this.prevEncoderNorm = currentEncoderNorm(:);

%% Check terminal condition
isDone = this.checkEndEpisode();

if isDone && this.plotEpisodeOnTest
    plot_episode(this);
end

if isDone && this.flagSaveTraining
    this.saveEpisode();
end

notifyEnvUpdated(this);

loggedSignals = [];
drawnow
end
