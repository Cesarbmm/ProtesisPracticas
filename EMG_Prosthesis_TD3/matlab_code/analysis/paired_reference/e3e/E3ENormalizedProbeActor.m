classdef E3ENormalizedProbeActor < handle
    % E3ENormalizedProbeActor: Actor feed-forward para evaluación closed-loop causal.
    % Aplica la normalización robusta congelada exclusivamente sobre las 40 variables EMG
    % de la observación actual, preservando las 12 mecánicas sin alteración.
    properties (SetAccess=private)
        Network
        Median
        MAD
        Eps
        Probabilities = zeros(15, 4, 0)
        Entropies = zeros(4, 0)
        Categories = zeros(4, 0)
    end
    methods
        function obj = E3ENormalizedProbeActor(net, med, mad, epsVal)
            obj.Network = resetState(net);
            obj.Median = double(med(:));
            obj.MAD = double(mad(:));
            obj.Eps = double(epsVal);
        end
        function reset(obj)
            obj.Probabilities = zeros(15, 4, 0);
            obj.Entropies = zeros(4, 0);
            obj.Categories = zeros(4, 0);
        end
        function [action, state] = getAction(obj, observation)
            if iscell(observation), observation = cell2mat(observation); end
            assert(isequal(size(observation), [52, 1]) && all(isfinite(observation)));

            % Normalización causal robusta sobre EMG actual
            emg_norm = (double(observation(1:40)) - obj.Median) ./ (obj.MAD + obj.Eps);

            % Predicción con red feed-forward BASELINE
            [p, h] = e3dPredict(obj.Network, "BASELINE", emg_norm, double(observation(41:52)));
            [~, cats] = max(p, [], 1);
            cats = reshape(cats, 4, 1);

            obj.Probabilities(:, :, end+1) = p;
            obj.Entropies(:, end+1) = h;
            obj.Categories(:, end+1) = cats;
            action = {e3bCategoryPWM(cats) / 255};
            state = [];
        end
        function values = getLearnableParameters(obj)
            values = obj.Network.Learnables.Value;
        end
    end
end
