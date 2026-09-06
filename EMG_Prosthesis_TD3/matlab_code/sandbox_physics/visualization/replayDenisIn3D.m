function result = replayDenisIn3D(options)
%replayDenisIn3D FASE S2: anima en 3D un episodio ya reproducido en S1.
%
%   El visor NO participa en el lazo: primero se ejecuta el replay canonico
%   (S1) y despues se dibuja q(t). Si la animacion se ve rara, S1 dice si el
%   problema estaba ya en la trayectoria o es del visor.
%
%   Uso:
%       result = replayDenisIn3D();                        % DENIS, cierre
%       result = replayDenisIn3D(side=2, saveGif=true);
%       result = replayDenisIn3D(trace=miTraza);           % reutiliza S1
%
%   Sub-pasos (opcional, por defecto activados solo para la animacion):
%   entre dos pasos de control de 0.2 s la planta canonica devuelve UN solo
%   punto. Para animar de forma continua se vuelve a muestrear LA MISMA curva
%   empirica con un periodo mas fino. No es interpolacion inventada y el punto
%   final coincide exactamente con el paso historico (verificado en test).
%   Los sub-pasos son VISUALIZATION_ONLY: no entran en ninguna metrica ni gate.

arguments
    options.subject (1, 1) string = "DENIS"
    options.repetition (1, 1) double {mustBeInteger, mustBePositive} = 1
    options.side (1, 1) double {mustBeMember(options.side, [1 2])} = 1
    options.trace = []
    options.substepSamplingPeriod (1, 1) double = 0.02
    options.useSubsteps (1, 1) logical = true
    options.rangeMode (1, 1) string = "plantReachable"
    options.visible (1, 1) logical = true
    options.saveGif (1, 1) logical = true
    options.saveFrames (1, 1) logical = true
    options.frameDelay (1, 1) double = 0.08
    options.outputDir (1, 1) string = ""
end

here = string(fileparts(mfilename("fullpath")));
sandboxRoot = fileparts(here);
if options.outputDir == ""
    options.outputDir = fullfile(sandboxRoot, "results", "s2_viewer");
end
if ~isfolder(options.outputDir)
    mkdir(options.outputDir);
end

% --- 1. trayectoria: la del replay S1, no una recalculada por el visor ----
if isempty(options.trace)
    summary = runSandboxS1CanonicalReplay(subject = options.subject, ...
        repetition = options.repetition, side = options.side);
    replayFile = fullfile(sandboxRoot, "results", "s1_canonical_replay", ...
        "s1_replay_trajectories.mat");
    stored = load(replayFile, "episodes");
    trace = stored.episodes(1).trace;
    replaySummary = summary;
else
    trace = options.trace;
    replaySummary = struct("stage", "S1_TRACE_PROVIDED_BY_CALLER");
end

steps = size(trace.rawAction, 1);
assert(steps > 0, "Sandbox:EmptyTrace", "La traza no contiene pasos.");

% --- 2. secuencia de poses ------------------------------------------------
qSequence = trace.q(1, :);          % estado inicial (reset)
stepIndex = 0;
substepNote = "sin sub-pasos";
if options.useSubsteps && options.substepSamplingPeriod > 0
    substepNote = sprintf("sub-pasos VISUALIZATION_ONLY a %.3g s", options.substepSamplingPeriod);
    for k = 1:steps
        fine = CanonicalPlantAdapter.substepTrajectory(trace.q(k, :), trace.pwm(k, :), ...
            0.2, options.substepSamplingPeriod);
        qSequence = [qSequence; fine]; %#ok<AGROW>
        stepIndex = [stepIndex; repmat(k, size(fine, 1), 1)]; %#ok<AGROW>
    end
    endpointError = max(abs(qSequence(end, :) - trace.q(end, :)));
else
    qSequence = trace.q;
    stepIndex = (0:steps)';
    endpointError = 0;
end

% --- 3. visor -------------------------------------------------------------
viewer = HandKinematicViewer(units = "encoder", rangeMode = options.rangeMode, ...
    visible = options.visible, ...
    figureTitle = sprintf("S2 - %s lado %d (%s)", options.subject, options.side, substepNote));

gifPath = fullfile(options.outputDir, sprintf("replay_%s_side%d.gif", ...
    options.subject, options.side));
framesDir = fullfile(options.outputDir, sprintf("frames_%s_side%d", ...
    options.subject, options.side));
if options.saveFrames && ~isfolder(framesDir)
    mkdir(framesDir);
end
flexionLog = zeros(size(qSequence, 1), 4);
gifWritten = false;

for k = 1:size(qSequence, 1)
    [~, flexion] = viewer.update(qSequence(k, :));
    flexionLog(k, :) = flexion;

    if options.saveGif
        % rgb2ind pertenece a Image Processing Toolbox: si no esta, se avisa
        % y se continua con PNG. La animacion es un extra, no un gate.
        try
            image = frame2im(viewer.capture());
            [indexed, map] = rgb2ind(image, 256);
            if ~gifWritten
                imwrite(indexed, map, gifPath, "gif", LoopCount = inf, ...
                    DelayTime = options.frameDelay);
                gifWritten = true;
            else
                imwrite(indexed, map, gifPath, "gif", WriteMode = "append", ...
                    DelayTime = options.frameDelay);
            end
        catch gifError
            warning("Sandbox:GifUnavailable", ...
                "No se pudo escribir el GIF (%s). Se continua sin animacion.", ...
                gifError.message);
            options.saveGif = false;
        end
    end

    if options.saveFrames
        exportgraphics(viewer.figureHandle, ...
            fullfile(framesDir, sprintf("frame_%04d.png", k)), Resolution = 130);
    end
end

trajectoryCsv = fullfile(options.outputDir, sprintf("pose_sequence_%s_side%d.csv", ...
    options.subject, options.side));
writetable(array2table([stepIndex, qSequence, flexionLog], VariableNames = ...
    ["controlStep", "q_1", "q_2", "q_3", "q_4", ...
     "flexion_1", "flexion_2", "flexion_3", "flexion_4"]), trajectoryCsv);

result = struct( ...
    "stage", "S2_KINEMATIC_VIEWER", ...
    "subject", options.subject, ...
    "side", options.side, ...
    "controlSteps", steps, ...
    "renderedFrames", size(qSequence, 1), ...
    "substeps", substepNote, ...
    "substepEndpointError", endpointError, ...
    "rangeMode", options.rangeMode, ...
    "VIEWER_INPUT_UNITS", "encoder", ...
    "GLOVE_USED_AS_PLANT_STATE", false, ...
    "gifPath", gifPath, ...
    "gifWritten", gifWritten, ...
    "framesDir", framesDir, ...
    "poseSequencePath", trajectoryCsv, ...
    "replaySummary", replaySummary);

if ~options.visible
    viewer.closeViewer();
end
end
