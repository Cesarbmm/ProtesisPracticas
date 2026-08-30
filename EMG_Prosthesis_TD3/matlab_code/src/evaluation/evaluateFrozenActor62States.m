function actions = evaluateFrozenActor62States(actor, states)
%evaluateFrozenActor62States serially evaluates a frozen 62-input actor.

arguments
    actor
    states double
end

if isempty(states) || size(states, 2) ~= 62 || ...
        ~isreal(states) || any(~isfinite(states), "all")
    error("evaluateFrozenActor62States:InvalidStates", ...
        "states must be a nonempty finite real N-by-62 matrix.");
end
actions = nan(size(states, 1), 4);
for rowIdx = 1:size(states, 1)
    output = getAction(actor, {states(rowIdx, :)'});
    if iscell(output)
        output = output{1};
    end
    output = double(output(:));
    if numel(output) ~= 4 || ~isreal(output) || ...
            any(~isfinite(output))
        error("evaluateFrozenActor62States:InvalidAction", ...
            "The actor must return one finite four-vector per state.");
    end
    actions(rowIdx, :) = output';
end
end
