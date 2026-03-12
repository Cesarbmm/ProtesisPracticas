function [observation, reward, isDone, loggedSignals] = step(this, action)
    this.c = this.c + 1;

    %--- action verification depending matlab vers.
    % if ~isequal(matlabRelease.Release, "R2021b")
    %     %adjusting changes in toolbox apart from R2021b
    %     action = action{1};
    % end

    if this.unifyActions
        action = action * [1 1 1 1];
    end

    % Ensure action is of type double and has the correct size
    if iscell(action)
        action = cell2mat(action);
    end
    
    if ~isnumeric(action)
        error('action must be of numeric type');
    end
    
    % Ensure action has the correct dimensions
    expectedActionSize = size(this.actionLog, 2);
    disp(expectedActionSize); 
    disp(class(expectedActionSize));
    
    disp(size(action)); 
    disp(class(action));
    disp(size(action, 1));
    if size(action, 1) ~= expectedActionSize
        error('The action size does not match the actionLog size');
    end

    this.actionLog(this.c, :) = action;
    fprintf('  actions=[%2d %2d %2d %2d]\n', action);

    if this.rf_modify_actions
        % action is clipped
        [reward, rewardVector, action] = this.reward_function(this, action, []);
        fprintf('actionSat=[%2d %2d %2d %2d]\n', action);
    else
         calculate reward without modifying actions
        [reward, rewardVector] = this.reward_function(this, action);
    end

    this.actionSatLog(this.c, :) = action;
    action = action .* this.speeds;

    %% applying action
    drawnow
    completed = this.prosthesis.sendAllSpeed(...
        action(1), action(2), action(3),+ action(4));
    disp(action(1));
    disp(action(2));
    disp(action(3));
    disp(action(4));

    assert(completed, 'ERROR during sending speed to controller')

    %% waiting data, applying action.
    while this.periodTic.toc() < this.period
        drawnow
    end

    if this.wait_in_step
        % waiting when half-hardware execution
        while toc(this.period_realTic) < this.period
            drawnow
        end
    end

    %% reading hardware
    if this.usePrerecorded
        % only waits a period
        t_elapsed = this.periodTic.elapsed_time;
        % supposedly it is a period
        assert(t_elapsed > 0.9*this.period && t_elapsed < 1.1*this.period, ...
            "time elapsed %.2f is incorrect, must be %.2f", ...
            t_elapsed, this.period)
        emg = this.myo.readEmg(t_elapsed);
        flexData = this.glove.read(t_elapsed);
    else
        emg = this.myo.readEmg(); % E-by-8
        flexData = this.glove.read(); % n-by-9 double
    end

    motorData = this.prosthesis.read(); % m-by-4 double

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

    % --- end step
    this.periodTic.tic();
    if this.wait_in_step
        this.period_realTic = tic;
    end

    this.log(sprintf(...
        '%d. T=%.3f[s]. EmgSize %d. encodersSize %d. glovesize %d',...
        this.c, this.episodeTic.toc(this.c),...
        size(emg, 1), size(motorData, 1), size(flexData, 1)))

    %% Update prosthesis states
    this.State = this.calculateState(emg, motorData);
    observation = this.State;

    %% Reward
    this.flexConverted = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
    this.adjustEnc = this.flexJoined_scaler(encoder2Flex(this.motorData));

    if this.rf_modify_actions
        % action is not clipped
        reward = this.reward_function(this, action, []);
    end
    
        % DEBUG: Verificar rewardVector antes de guardar
    fprintf('[Step] rewardVector size: [%d %d], class: %s\n', size(rewardVector,1), size(rewardVector,2), class(rewardVector));
    fprintf('[Step] rewardIndividualLog class: %s\n', class(this.rewardIndividualLog));
    fprintf('[Step] Trying to store at index: %d\n', this.c);
    

    %% logs
    this.emgLog{this.c} = emg;
    this.encoderAdjustedLog{this.c} = this.adjustEnc;
    this.rewardLog(this.c) = reward;
    disp(rewardVector)
    this.rewardIndividualLog{this.c,1} = rewardVector; % save individual rewards % CAMBIO agregado ,1 revisar 
    
    this.flexConvertedLog{this.c} = this.flexConverted;

    %% Check terminal condition
    isDone = this.checkEndEpisode(); % || finishEpisode

    if isDone && this.flagSaveTraining
        this.saveEpisode();
    end
    % (optional) use notifyEnvUpdated to signal that the
    % environment has been updated (e.g. to update visualization)
    notifyEnvUpdated(this);

    loggedSignals = []; % not used
    drawnow
end
