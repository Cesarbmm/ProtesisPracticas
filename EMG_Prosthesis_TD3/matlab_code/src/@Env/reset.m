function InitialObservation = reset(this)
%this.reset() method that resets environment to initial state and output
%initial observation. It uses the prosthesis built in method to go to home
%position.
%
%if false
    % if this.episodeCounter > 1
    %f = figure(2);
    %ax = gca;
    %drawnow
    % plot(ax, cat(1, this.emgLog{:}))
    %plot(ax, cat(1, this.flexConvertedLog{:}))
    %plot(ax, cat(1, this.encoderAdjustedLog{:}))
    %uiwait(f)
%end
%plot_episode(this)%for testing and save
%plot_episode2(this)%for training with MYO and glove
this.episodeTimestamp(1) = this.episodeTic.toc(this.c);
this.episodeCounter = this.episodeCounter + 1;
this.encoderLog = cell(this.maxNumberStepsInEpisodes, 1);
this.encoderAdjustedLog = cell(this.maxNumberStepsInEpisodes, 1);
this.actionLog = nan(this.maxNumberStepsInEpisodes, 4);
this.actionSatLog = nan(this.maxNumberStepsInEpisodes, 4);
this.rewardLog = nan(this.maxNumberStepsInEpisodes, 1);
this.rewardIndividualLog = cell(this.maxNumberStepsInEpisodes, 4);
this.emgLog = cell(this.maxNumberStepsInEpisodes, 1);
this.flexConvertedLog = cell(this.maxNumberStepsInEpisodes, 1);

if this.returnHomeAtEndEpisode
    drawnow
    if this.episodeType == EpisodeType.Closing % check!
        %% # --------- Hardware
        % moves the prosthesis to the relax position
        this.log("Reseting: going home");

        drawnow
        completed = this.prosthesis.goHomePosition();
        drawnow
        assert(completed , ...
            'ERROR in reseting env. Prostheshis could not go home position')
        this.log("Reseted: at home");
    end
end

%% loading prerecorded
if this.usePrerecorded

    if this.episodeType == EpisodeType.Closing
        % closed->training gesture open
        this.episodeType = EpisodeType.Opening;
        side = 2;

        %--- calling closing function
        this.prosthesis.closeHand();
    else
        % hand open->training to gesture close
        this.episodeType = EpisodeType.Closing;

        % -- restarting resshufle
        if mod(this.episodeCounter, 2*this.sizeDataset) == 1
            this.episodes_shuffled = randperm(this.sizeDataset);
        end

        side = 1;
    end
    % --- finding idx
    i = mod(this.episodeCounter, 2*this.sizeDataset);
    if i == 0
        j = this.sizeDataset;
    else
        j = floor((i + 1)/2);
    end

    this.repetitionId = this.episodes_shuffled(j);

    % --- doing the loading
    emg = this.emgSet{this.repetitionId, side};
    g = this.gloveSet{this.repetitionId, side};
    this.myo = RecordedMyo(emg);
    this.glove = RecordedGlove(g);
    this.emgLength = size(emg,1);
    this.log(sprintf("\n------------New Episode: %04d-------", ...
        this.episodeCounter));
    this.log(sprintf("using rep: %d, hand %s, emg sz: %d, g. sz: %d", ...
        this.repetitionId, this.episodeType, size(emg, 1), size(g, 1)));
end

drawnow
%% reseting buffer and waiting initial data
if this.wait_in_step
    this.period_realTic = tic;
    this.episode_realTic = tic;
end

while true
    this.glove.resetBuffer();
    this.myo.resetBuffer();
    this.prosthesis.resetBuffer();
    drawnow
    this.periodTic.tic();

    %% close hand
    if this.episodeType == EpisodeType.Opening
        this.prosthesis.closeHand();
        this.episodeTic.toc(10000);
        this.prosthesis.read();
        this.prosthesis.stop();
    else
        this.prosthesis.resetBuffer();
    end
    drawnow
    this.log("Reseting: waiting for buffer data");

    if this.wait_in_step
        this.period_realTic = tic;
        % waiting when half-hardware execution
        while toc(this.period_realTic) < this.period
            drawnow
        end
    end

    if this.usePrerecorded
        % only in this case, it waits a period
        emg = this.myo.readEmg(this.period);
        flexData = this.glove.read(this.period);
    else
        while this.periodTic.toc() < this.period
            drawnow
        end

        emg = this.myo.readEmg(); % E-by-8
        flexData = this.glove.read(); % n-by-9 double
    end

    this.log("Reseting: reading hardware");
    motorData = this.prosthesis.read(); % m-by-4 double

    if ~isempty(flexData) && ~isempty(emg)
        break
    else
        warning('No flex or EMG data, waiting again')
        pause(0.5); % Espera un poco antes de intentar nuevamente
    end
end

this.emg = emg;
this.motorData = motorData;
this.flexData = flexData;

this.log(sprintf('encoder\t[%d %d %d %d]',motorData(end,1),...
    motorData(end,2),motorData(end,3),motorData(end,4)))
this.log(sprintf('EmgSize %d. motorSize %d. glove size %d', ...
    size(emg, 1), size(motorData, 1), size(motorData, 1)))
drawnow

%% # --------- Update state
this.log(sprintf(...
    "Reseted: Calculated initial state\nStarts episode________"));

assert(~isempty(emg), "EMG empty in reset")

this.State = this.calculateState(emg, motorData);
InitialObservation = this.State;

% (optional) use notifyEnvUpdated to signal that the
% environment has been updated (e.g. to update visualization)
% notifyEnvUpdated(this);

%% ---- start new episode
drawnow
this.episodeTimestamp(2) = this.episodeTic.toc();
this.periodTic.tic();
this.episodeTic.tic();

% this.prosthesis.resetBuffer();
if this.wait_in_step % CHECK why tic twice??
    this.period_realTic = tic;
    this.episode_realTic = tic;
end
this.c = 0;
this.isDone = false;
end