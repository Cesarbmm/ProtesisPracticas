function actions = evaluateFrozenActorStates(actor, states)
%evaluateFrozenActorStates replays a frozen deterministic actor offline.

arguments
    actor
    states double
end

if isempty(states) || size(states, 2) ~= 60 || ...
        ~isreal(states) || any(~isfinite(states), "all")
    error("evaluateFrozenActorStates:InvalidStates", ...
        "states must be a nonempty finite real N-by-60 matrix.");
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
        error("evaluateFrozenActorStates:InvalidAction", ...
            "The actor must return one finite real four-vector per state.");
    end
    actions(rowIdx, :) = output';
end
end
