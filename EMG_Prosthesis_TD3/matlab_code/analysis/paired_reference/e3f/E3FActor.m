classdef E3FActor < handle
    properties
        Network
        Categories = [0 -64 64 -96 96 -128 128 -160 160 -192 192 -224 224 -255 255]
    end
    methods
        function obj = E3FActor(network)
            obj.Network = network;
        end
        function [p, h] = distribution(obj, state)
            if iscell(state), state = cell2mat(state); end
            [logits, ~] = e3fLogits(obj.Network, state);
            [~, hd, pd] = e3fCategoricalTerms(logits, []);
            p = double(extractdata(pd));
            h = double(extractdata(hd));
            assert(all(isfinite(p), "all") && all(isfinite(h), "all"), "E3F:Distribution", "Probabilidades no finitas.");
        end
        function [action, state] = getAction(obj, observation)
            [p, ~] = obj.distribution(observation);
            [~, category] = max(p, [], 1);
            category = reshape(category, 4, []);
            pwm = e3fCategoryPWM(category);
            action = {pwm / 255};
            state = [];
        end
        function values = getLearnableParameters(obj)
            values = obj.Network.Learnables.Value;
        end
    end
end
