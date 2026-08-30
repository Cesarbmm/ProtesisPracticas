function actions = evaluateFrozenActorModel62(model, states)
%evaluateFrozenActorModel62 evaluates a frozen 62-input actor in a batch.

arguments
    model (1, 1) dlnetwork
    states double
end

if isempty(states) || size(states, 2) ~= 62 || ...
        ~isreal(states) || any(~isfinite(states), "all")
    error("evaluateFrozenActorModel62:InvalidStates", ...
        "states must be a nonempty finite real N-by-62 matrix.");
end
input = dlarray(single(states'), "CB");
output = predict(model, input);
actions = double(extractdata(output))';
if ~isequal(size(actions), [size(states, 1), 4]) || ...
        ~isreal(actions) || any(~isfinite(actions), "all") || ...
        any(abs(actions) > 1+1e-6, "all")
    error("evaluateFrozenActorModel62:InvalidAction", ...
        "The model must return finite N-by-4 actions in [-1,1].");
end
end
