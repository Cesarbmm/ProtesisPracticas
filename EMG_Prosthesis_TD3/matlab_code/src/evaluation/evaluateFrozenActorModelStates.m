function actions = evaluateFrozenActorModelStates(model, states)
%evaluateFrozenActorModelStates evaluates a frozen actor model in a batch.

arguments
    model (1, 1) dlnetwork
    states double
end

if isempty(states) || size(states, 2) ~= 60 || ...
        ~isreal(states) || any(~isfinite(states), "all")
    error("evaluateFrozenActorModelStates:InvalidStates", ...
        "states must be a nonempty finite real N-by-60 matrix.");
end

input = dlarray(single(states'), "CB");
output = predict(model, input);
actions = double(extractdata(output))';
if ~isequal(size(actions), [size(states, 1), 4]) || ...
        ~isreal(actions) || any(~isfinite(actions), "all")
    error("evaluateFrozenActorModelStates:InvalidAction", ...
        "The model must return a finite real four-vector per state.");
end
end
