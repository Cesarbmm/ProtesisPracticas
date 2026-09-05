classdef (InferiorClasses = {?rl.agent.rlTD3Agent}) GloveFreePolicyRuntime < handle
    % Ejecucion de markov52 sin teacher. No es un entorno RL y no da reward.
    % La composicion de estado y el remapeo reproducen las formulas de Env;
    % E2A las contrasta contra Env sin modificar la ruta de entrenamiento.
    properties (SetAccess=private)
        state
        q
        c = 0
        exhausted = false
        plantManifest
    end
    properties (Access=private)
        myo
        prosthesis
        timing
        configs
        lastEmg
        previousEncoder
        previousEffective = zeros(4,1)
    end
    methods
        function obj = GloveFreePolicyRuntime(emgData, initialPosition, options)
            arguments
                emgData (:,8) double {mustBeFinite}
                initialPosition (1,4) double {mustBeFinite} = zeros(1,4)
                options.purpose (1,1) string = "inference"
                options.outputManifestPath (1,1) string = ""
            end
            if ~ismember(options.purpose, ["inference", "causalEvaluation"])
                error("E2A:TrainingForbidden", ...
                    "Esta clase permite solo ejecucion causal; entrenamiento RL prohibido.");
            end
            p = configurables();
            if p.run_training
                error("E2A:TrainingForbidden", ...
                    "Fijar run_training=false para ejecutar; esta clase no admite entrenamiento RL.");
            end
            assert(p.stateLength == 52 && p.numEMGFeatures == 40 && ...
                string(p.observationVariant) == "markov52", "E2A:Contract", "Se exige markov52.");
            assert(resolveSimPlantSource() == "patternCurveCanonical" && p.simMotors, ...
                "E2A:Contract", "Se exige planta canonica simulada.");
            assert(string(p.actionInterfaceVariant) == "baselineQuantized" && ...
                p.quantizeCommandsForSimulation && ~p.unifyActions && ...
                isequal(p.actionCommandLevels, [0 64 96 128 160 192 224 255]) && ...
                p.actionCommandActivationThreshold == 0.05 && ...
                isequal(p.speeds, 255*ones(1,4)) && p.period == 0.2, ...
                "E2A:Contract", "Interfaz/periodo fuera del contrato E2A congelado.");
            assert(size(emgData,1) >= 40, "E2A:EmptyEmg", "Falta el bloque EMG inicial.");
            obj.configs = p;
            obj.myo = RecordedMyo(emgData);
            obj.timing = Timing(false, p.period);
            obj.prosthesis = SimController(obj.timing);
            obj.prosthesis.resetBuffer(initialPosition);
            obj.q = initialPosition;
            obj.lastEmg = obj.myo.readEmg(p.period);
            obj.previousEncoder = p.encoder2state_scale(initialPosition');
            obj.state = obj.observe(obj.lastEmg);
            obj.exhausted = obj.myo.exhausted;
            obj.plantManifest = pairedReferencePlantManifest( ...
                plantSource="patternCurveCanonical", outputPath=options.outputManifestPath);
        end

        function [state, isDone, record] = advance(obj, rawAction)
            if obj.exhausted
                error("E2A:EmgExhausted", "El episodio ya termino por agotamiento EMG.");
            end
            if configurables("run_training")
                error("E2A:TrainingForbidden", "No se permite aprendizaje con este runtime.");
            end
            assert(resolveSimPlantSource() == "patternCurveCanonical", ...
                "E2A:Contract", "La fuente de planta cambio durante el episodio.");
            if iscell(rawAction), rawAction = cell2mat(rawAction); end
            rawAction = double(rawAction(:));
            assert(numel(rawAction)==4 && all(isfinite(rawAction)), ...
                "E2A:InvalidAction", "Se requieren cuatro acciones finitas.");
            before = obj.state;
            [effective, pwm] = obj.remap(rawAction);
            obj.prosthesis.sendAllSpeed(pwm(1), pwm(2), pwm(3), pwm(4));
            obj.c = obj.c + 1;
            obj.timing.toc(obj.c);
            emg = obj.myo.readEmg(obj.configs.period);
            if isempty(emg), emg = obj.lastEmg; else, obj.lastEmg = emg; end
            motorData = obj.prosthesis.read();
            obj.q = motorData(end,:);
            obj.previousEffective = effective;
            obj.state = obj.observe(emg);
            obj.previousEncoder = obj.configs.encoder2state_scale(obj.q');
            obj.exhausted = obj.myo.exhausted;
            state = obj.state;
            isDone = obj.exhausted;
            record = struct("stateBefore", before, "stateAfter", state, ...
                "rawAction", rawAction, "effectiveAction", effective, "pwm", pwm, "q", obj.q);
        end

        function varargout = train(varargin) %#ok<STOUT,INUSD>
            % Precedencia sobre rlTD3Agent: tambien intercepta train(agent,runtime).
            error("E2A:TrainingForbidden", ...
                "GloveFreePolicyRuntime no es un entorno RL: entrenamiento prohibido, sin reward.");
        end
    end
    methods (Access=private)
        function state = observe(obj, emg)
            features = obj.configs.fGetFeatures(emg);
            enc = obj.configs.encoder2state_scale(obj.q');
            delta = max(-1, min(1, enc - obj.previousEncoder(:)));
            previous = max(-1, min(1, obj.previousEffective(:)));
            state = [features; enc; delta; previous];
            assert(isequal(size(state), [52 1]) && all(isfinite(state)), ...
                "E2A:InvalidState", "markov52 debe contener 52 valores finitos.");
        end

        function [effective, pwm] = remap(obj, action)
            action = max(-1, min(1, double(action(:))));
            maxPwm = max(abs(obj.configs.speeds));
            levels = sort(unique(abs(double(obj.configs.actionCommandLevels(:)'))));
            levels = levels(levels > 0);
            effective = zeros(size(action)); pwm = zeros(size(action));
            for i = 1:numel(action)
                if abs(action(i)) < obj.configs.actionCommandActivationThreshold, continue; end
                [~, index] = min(abs(levels - abs(action(i))*maxPwm));
                pwm(i) = sign(action(i))*levels(index);
                effective(i) = pwm(i)/maxPwm;
            end
        end
    end
end
