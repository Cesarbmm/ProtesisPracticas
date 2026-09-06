classdef CanonicalPlantAdapter < handle
%CanonicalPlantAdapter interfaz de planta del sandbox sobre la planta canonica.
%
%   FASE S3. Envuelve Timing + SimController SIN modificarlos y sin tocar
%   src/@Env. Expone la interfaz que el plan pide para el sandbox:
%
%       plant = CanonicalPlantAdapter();
%       q0 = plant.reset([0 0 0 0]);
%       [q1, diagnostics] = plant.step([255 255 255 255]);
%
%   Nota de honestidad sobre `dt`: el plan propone step(pwm, dt). En el codigo
%   oficial el avance NO es por tiempo continuo, sino por CONTADOR de periodos:
%   SimController.updatePos usa `timing.c - c0` y multiplica por timing.period
%   (src/@SimController/SimController.m:155-156). Por eso este adaptador acepta
%   dt pero exige dt == period; pedir otro dt seria inventar una semantica que
%   la planta historica no tiene.
%
%   Consecuencia auditada de esa semantica: en src/@Env/reset.m:129 se llama
%   `episodeTic.toc(10000)` despues de closeHand(). El argumento 10000 fija
%   elapsed_time pero SimController ignora elapsed_time y solo ve `c`, que
%   avanza 1. El "cierre previo" de los episodios de apertura dura por tanto UN
%   periodo de 0.2 s, no 10000. Se conserva tal cual; solo se documenta.
%
%   Nada de esta clase entrena, ni lee guante, ni cambia niveles PWM, periodo,
%   reward o politica.

    properties (SetAccess = immutable)
        period (1, 1) double
        samplingPeriod (1, 1) double
        plantSource (1, 1) string
    end

    properties (SetAccess = private)
        q (1, 4) double = zeros(1, 4)
        stepCount (1, 1) double = 0
        timing
        controller
    end

    methods
        function obj = CanonicalPlantAdapter(options)
            arguments
                options.period (1, 1) double {mustBePositive} = 0.2
                options.requireCanonicalSource (1, 1) logical = true
            end
            obj.plantSource = resolveSimPlantSource();
            if options.requireCanonicalSource && obj.plantSource ~= "patternCurveCanonical"
                error("Sandbox:PlantSource", ...
                    "El sandbox exige simPlantSource='patternCurveCanonical'; se leyo '%s'.", ...
                    obj.plantSource);
            end
            obj.period = options.period;
            obj.timing = Timing(false, obj.period);
            obj.controller = SimController(obj.timing);
            obj.samplingPeriod = 0.14;   % valor historico de SimController
            obj.reset(zeros(1, 4));
        end

        function q = reset(obj, q0)
            arguments
                obj
                q0 (1, 4) double {mustBeFinite} = zeros(1, 4)
            end
            obj.controller.resetBuffer(q0);
            obj.q = q0;
            obj.stepCount = 0;
            q = obj.q;
        end

        function [qNext, diagnostics] = step(obj, pwm, dt, options)
            arguments
                obj
                pwm (1, 4) double {mustBeFinite}
                dt (1, 1) double = obj.period
                options.substepSamplingPeriod (1, 1) double = 0
            end
            if abs(dt - obj.period) > 0
                error('Sandbox:FixedPeriod', 'El periodo de control debe ser exactamente 0.2 s.');
            end
            if resolveSimPlantSource() ~= obj.plantSource
                error("Sandbox:PlantSourceChanged", ...
                    "El periodo de control debe ser exactamente 0.2 s. Recibido: " + num2str(dt));
            end
            if any(abs(pwm) > 255)
                error("Sandbox:PwmRange", "PWM fuera de [-255, 255].");
            end

            qBefore = obj.q;
            obj.controller.sendAllSpeed(pwm(1), pwm(2), pwm(3), pwm(4));
            obj.stepCount = obj.stepCount + 1;
            obj.timing.toc(obj.stepCount);
            motorData = obj.controller.read();
            obj.q = motorData(end, :);
            qNext = obj.q;

            diagnostics = struct( ...
                "step", obj.stepCount, ...
                "pwm", pwm, ...
                "qBefore", qBefore, ...
                "qAfter", qNext, ...
                "delta", qNext - qBefore, ...
                "commandedButStill", abs(pwm) > 0 & abs(qNext - qBefore) == 0, ...
                "movedAgainstCommand", sign(qNext - qBefore) == -sign(pwm) & (qNext - qBefore) ~= 0, ...
                "plantSource", obj.plantSource, ...
                "substepTrajectory", []);

            if options.substepSamplingPeriod > 0
                diagnostics.substepTrajectory = CanonicalPlantAdapter.substepTrajectory( ...
                    qBefore, pwm, dt, options.substepSamplingPeriod);
                diagnostics.substepNote = ...
                    "VISUALIZATION_ONLY: mismo punto final que el paso historico, verificado en test.";
            end
        end
    end

    methods (Static)
        function trajectory = substepTrajectory(q0, pwm, dt, samplingPeriod)
            %substepTrajectory muestrea la MISMA curva empirica mas fino.
            % No es interpolacion inventada: son puntos de pattern_curve.mat.
            % El ultimo punto coincide exactamente con el paso historico
            % (testSandboxCanonicalAdapterRegression lo verifica).
            arguments
                q0 (1, 4) double {mustBeFinite}
                pwm (1, 4) double {mustBeFinite}
                dt (1, 1) double {mustBePositive}
                samplingPeriod (1, 1) double {mustBePositive}
            end
            trajectory = SimController.prosthesis_simulator(q0, pwm, dt, samplingPeriod);
        end

        function qNext = singleStep(q0, pwm, dt, samplingPeriod)
            %singleStep paso sin estado, usando directamente el simulador.
            arguments
                q0 (1, 4) double {mustBeFinite}
                pwm (1, 4) double {mustBeFinite}
                dt (1, 1) double {mustBePositive} = 0.2
                samplingPeriod (1, 1) double {mustBePositive} = 0.14
            end
            trajectory = SimController.prosthesis_simulator(q0, pwm, dt, samplingPeriod);
            qNext = trajectory(end, :);
        end
    end
end
