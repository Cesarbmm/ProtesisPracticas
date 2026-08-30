function gradients = evaluateFrozenActorStateGradients(model, states, options)
%evaluateFrozenActorStateGradients returns d action_m / d state_j.

arguments
    model (1, 1) dlnetwork
    states double
    options.batchSize (1, 1) double {mustBeInteger, mustBePositive} = 512
end

if isempty(states) || size(states, 2) ~= 60 || ~isreal(states) || ...
        any(~isfinite(states), "all")
    error("evaluateFrozenActorStateGradients:InvalidStates", ...
        "states must be a nonempty finite real N-by-60 matrix.");
end

gradients = nan(size(states, 1), 4, 60);
for first = 1:options.batchSize:size(states, 1)
    last = min(size(states, 1), first+options.batchSize-1);
    input = dlarray(single(states(first:last, :)'), "CB");
    for motor = 1:4
        gradient = dlfeval(@gradientForMotor, model, input, motor);
        values = double(extractdata(gradient))';
        gradients(first:last, motor, :) = reshape(values, ...
            last-first+1, 1, 60);
    end
end
if any(~isfinite(gradients), "all")
    error("evaluateFrozenActorStateGradients:NonfiniteGradient", ...
        "Actor state gradients must be finite.");
end
end

function gradient = gradientForMotor(model, input, motor)
output = forward(model, input);
objective = sum(output(motor, :), "all");
gradient = dlgradient(objective, input);
end
