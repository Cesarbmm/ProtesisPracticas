function gradients = evaluateFrozenActorBitGradients(model, states, bitIndices)
%evaluateFrozenActorBitGradients returns d action_m / d selected state bits.

arguments
    model (1, 1) dlnetwork
    states double
    bitIndices (1, :) double {mustBeInteger, mustBePositive} = [61, 62]
end

if isempty(states) || size(states, 2) ~= 62 || ...
        ~isreal(states) || any(~isfinite(states), "all") || ...
        any(bitIndices > 62) || numel(unique(bitIndices)) ~= numel(bitIndices)
    error("evaluateFrozenActorBitGradients:InvalidInput", ...
        "Expected finite N-by-62 states and unique valid bit indices.");
end
input = dlarray(single(states'), "CB");
gradients = nan(size(states, 1), 4, numel(bitIndices));
for motor = 1:4
    gradient = dlfeval(@gradientForMotor, model, input, motor);
    values = double(extractdata(gradient(bitIndices, :)))';
    gradients(:, motor, :) = reshape(values, ...
        size(states, 1), 1, numel(bitIndices));
end
if any(~isfinite(gradients), "all")
    error("evaluateFrozenActorBitGradients:NonfiniteGradient", ...
        "Actor bit gradients must be finite.");
end
end

function gradient = gradientForMotor(model, input, motor)
output = forward(model, input);
objective = sum(output(motor, :), "all");
gradient = dlgradient(objective, input);
end
