classdef e3fGradientReversalLayer < nnet.layer.Layer
    properties
        Lambda = 0.10
    end
    methods
        function layer = e3fGradientReversalLayer(name, lambda)
            arguments
                name (1,1) string = "grl";
                lambda (1,1) double = 0.10;
            end
            layer.Name = name;
            layer.Description = "Gradient Reversal Layer with lambda = " + num2str(lambda);
            layer.Lambda = lambda;
        end
        function Z = predict(layer, X)
            Z = X;
        end
        function dLdX = backward(layer, X, Z, dLdZ, ~)
            dLdX = -single(layer.Lambda) * dLdZ;
        end
    end
end
