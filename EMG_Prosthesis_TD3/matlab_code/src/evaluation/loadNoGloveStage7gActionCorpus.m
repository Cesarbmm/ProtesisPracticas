function [components, episodeAudit] = loadNoGloveStage7gActionCorpus( ...
        variant, acceptanceDirectory, restDirectory, options)
%loadNoGloveStage7gActionCorpus loads recorded 7F actions without simulation.

arguments
    variant (1, 1) string
    acceptanceDirectory (1, 1) string
    restDirectory (1, 1) string
    options.activeVelocityThreshold (1, 1) double ...
        {mustBeNonnegative} = 0.005
end

if ~any(variant == ["control", "candidate"])
    error("loadNoGloveStage7gActionCorpus:InvalidVariant", ...
        "variant must be control or candidate.");
end
layout = buildObservationLayout("intentMarkov60", 40, 3, 4);
sources = ["acceptance", "steadyRest"];
directories = [acceptanceDirectory, restDirectory];
componentParts = cell(0, 1);
auditRows = cell(0, 1);
windowCursor = 0;
for sourceIdx = 1:numel(sources)
    source = sources(sourceIdx);
    files = dir(fullfile(directories(sourceIdx), "episode*.mat"));
    if isempty(files)
        error("loadNoGloveStage7gActionCorpus:NoEpisodes", ...
            "No episode files found in %s.", directories(sourceIdx));
    end
    [~, order] = sort({files.name});
    files = files(order);
    for fileIdx = 1:numel(files)
        path = string(fullfile(files(fileIdx).folder, files(fileIdx).name));
        token = regexp(files(fileIdx).name, '^episode(\d+)\.mat$', ...
            'tokens', 'once');
        if isempty(token)
            error("loadNoGloveStage7gActionCorpus:EpisodeName", ...
                "Unexpected episode filename %s.", files(fileIdx).name);
        end
        episode = str2double(token{1});
        data = load(path, "stateLog", "actionLog", ...
            "actionSatLog", "actionPwmLog", "referenceSource", ...
            "observationVariant", "stateLength");
        validateEpisode(data, path, layout.totalLength);
        state = double(data.stateLog);
        raw = double(data.actionLog);
        effective = double(data.actionSatLog);
        pwm = double(data.actionPwmLog);
        velocity = state(:, layout.referenceVelocity);
        reference = state(:, layout.referencePosition);
        stepCount = size(state, 1);
        if source == "steadyRest"
            if any(abs(velocity) > 1e-12, "all") || ...
                    any(abs(diff(reference, 1, 1)) > 1e-12, "all")
                error("loadNoGloveStage7gActionCorpus:NonRestEpisode", ...
                    "Steady-rest episode %s changes its reference.", path);
            end
            firstGlobalActiveStep = NaN;
            lastGlobalActiveStep = NaN;
        else
            globalActive = any(abs(velocity) >= ...
                options.activeVelocityThreshold, 2);
            if ~any(globalActive)
                error("loadNoGloveStage7gActionCorpus:NoMovement", ...
                    "Acceptance episode %s has no active reference.", path);
            end
            firstGlobalActiveStep = find(globalActive, 1, "first");
            lastGlobalActiveStep = find(globalActive, 1, "last");
        end

        rowCount = stepCount*4;
        rowVariant = repmat(variant, rowCount, 1);
        rowSource = repmat(source, rowCount, 1);
        rowEpisode = repelem(episode, rowCount, 1);
        rowStep = repelem((1:stepCount)', 4, 1);
        rowMotor = repmat((1:4)', stepCount, 1);
        rowWindow = repelem((windowCursor+(1:stepCount))', 4, 1);
        rowPhase = strings(rowCount, 1);
        for motor = 1:4
            rows = motor:4:rowCount;
            if source == "steadyRest"
                rowPhase(rows) = "steadyRest";
                continue;
            end
            motorActive = abs(velocity(:, motor)) >= ...
                options.activeVelocityThreshold;
            hasBeenActive = cummax(double(motorActive)) > 0;
            phase = repmat("inactiveOther", stepCount, 1);
            phase((1:stepCount)' < firstGlobalActiveStep) = "preActivation";
            phase(motorActive) = "movement";
            phase(~motorActive & hasBeenActive) = "postActivationHold";
            rowPhase(rows) = phase;
        end
        rawColumn = reshape(raw', [], 1);
        effectiveColumn = reshape(effective', [], 1);
        pwmColumn = reshape(pwm', [], 1);
        velocityColumn = reshape(velocity', [], 1);
        componentParts{end+1, 1} = table( ...
            rowVariant, rowSource, rowEpisode, rowStep, rowMotor, ...
            rowWindow, rowPhase, rawColumn, effectiveColumn, pwmColumn, ...
            velocityColumn, 'VariableNames', ["variant", "source", ...
            "episode", "step", "motor", "windowIndex", "phase", ...
            "rawAction", "effectiveAction", "pwm", ...
            "referenceVelocity"]); %#ok<AGROW>
        auditRows{end+1, 1} = table(variant, source, episode, ...
            stepCount, firstGlobalActiveStep, lastGlobalActiveStep, ...
            sum(abs(velocity) >= options.activeVelocityThreshold, "all"), ...
            path, 'VariableNames', ["variant", "source", "episode", ...
            "stepCount", "firstGlobalActiveStep", ...
            "lastGlobalActiveStep", "activeMotorStepCount", ...
            "episodePath"]); %#ok<AGROW>
        windowCursor = windowCursor+stepCount;
    end
end
components = vertcat(componentParts{:});
episodeAudit = vertcat(auditRows{:});
end

function validateEpisode(data, path, expectedStateLength)
required = ["stateLog", "actionLog", "actionSatLog", "actionPwmLog", ...
    "referenceSource", "observationVariant", "stateLength"];
if ~all(isfield(data, cellstr(required))) || ...
        string(data.referenceSource) ~= "emgIntent" || ...
        string(data.observationVariant) ~= "intentMarkov60" || ...
        double(data.stateLength) ~= expectedStateLength
    error("loadNoGloveStage7gActionCorpus:EpisodeContract", ...
        "Episode %s violates the no-glove observation contract.", path);
end
state = double(data.stateLog);
raw = double(data.actionLog);
effective = double(data.actionSatLog);
pwm = double(data.actionPwmLog);
if size(state, 2) ~= expectedStateLength || ...
        ~isequal(size(raw), size(effective), size(pwm)) || ...
        size(raw, 1) ~= size(state, 1) || size(raw, 2) ~= 4 || ...
        any(~isfinite([state(:); raw(:); effective(:); pwm(:)]))
    error("loadNoGloveStage7gActionCorpus:EpisodeArrays", ...
        "Episode %s contains invalid or misaligned arrays.", path);
end
end
