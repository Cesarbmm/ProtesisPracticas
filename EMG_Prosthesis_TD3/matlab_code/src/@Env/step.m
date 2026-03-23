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

this.actionLog(this.c, :) = action.';
[effectiveAction, appliedPwm] = this.remapActionForActuator(action);
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
    flexData = this.glove.read(t_elapsed);
else
    emg = this.myo.readEmg();
    flexData = this.glove.read();
end

motorData = this.prosthesis.read();
this.encoderLog{this.c} = motorData;

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

if isempty(flexData)
    flexData = this.flexData;
    warning("--------------------flexdata is empty")
else
    this.flexData = flexData;
end

%% end step timing
this.periodTic.tic();
if this.wait_in_step
    this.period_realTic = tic;
end

this.log(sprintf(...
    '%d. T=%.3f[s]. EmgSize %d. encodersSize %d. glovesize %d',...
    this.c, this.episodeTic.elapsed_time,...
    size(emg, 1), size(motorData, 1), size(flexData, 1)))

%% Update prosthesis states
this.prevEffectiveActionForState = effectiveAction(:);
[~] = this.updateEmgFeatureHistory(emg, false);
[this.State, currentEncoderNorm] = this.calculateState(emg, motorData);
observation = this.State;

%% Reward and normalized tracking data
this.flexConverted = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
this.adjustEnc = this.flexJoined_scaler(encoder2Flex(this.motorData));
[reward, rewardVector, rewardInfo] = this.reward_function(this, effectiveAction, []);

%% logs
this.emgLog{this.c} = emg;
this.encoderAdjustedLog{this.c} = this.adjustEnc;
this.rewardLog(this.c) = reward;
this.rewardVectorLog(this.c, :) = rewardVector(:).';
this.trackingMseLog(this.c) = rewardInfo.trackingMse;
this.trackingMaeLog(this.c) = rewardInfo.trackingMae;
this.actionL2Log(this.c) = rewardInfo.actionL2;
this.progressTermLog(this.c) = rewardInfo.progressTerm;
this.smoothnessPenaltyLog(this.c) = rewardInfo.smoothnessPenalty;
this.deltaActionL2Log(this.c) = rewardInfo.deltaActionL2;
this.saturationFractionLog(this.c) = rewardInfo.saturationFraction;
this.rewardIndividualLog{this.c} = rewardVector(:).';
this.flexConvertedLog{this.c} = this.flexConverted;
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
