function context = classifyNoGloveStage7oContexts( ...
        states, steps, lowActivityCountdown, gateActive, options)
%classifyNoGloveStage7oContexts assigns exclusive causal 7O contexts.

arguments
    states double
    steps (:, 1) double {mustBeInteger, mustBePositive}
    lowActivityCountdown (:, 1) logical
    gateActive (:, 1) logical
    options.holdPositionMseTolerance (1, 1) double ...
        {mustBeNonnegative} = 1e-4
    options.velocityTolerance (1, 1) double {mustBeNonnegative} = 1e-12
end

layout = buildObservationLayout( ...
    "intentDeclaredRestHoldMarkov62", 40, 3, 4);
count = size(states, 1);
if size(states, 2) ~= layout.totalLength || ...
        numel(steps) ~= count || ...
        numel(lowActivityCountdown) ~= count || ...
        numel(gateActive) ~= count || ...
        any(~isfinite(states), "all")
    error("classifyNoGloveStage7oContexts:InvalidInput", ...
        "Inputs must describe aligned finite N-by-62 states.");
end
declared = logical(states(:, layout.declaredRest));
latch = logical(states(:, layout.holdLatch));
positionMse = mean((states(:, layout.encoder) - ...
    states(:, layout.referencePosition)).^2, 2);
near = positionMse <= options.holdPositionMseTolerance;
moving = max(abs(states(:, layout.referenceVelocity)), [], 2) > ...
    options.velocityTolerance | gateActive;

context = repmat("uncategorized", count, 1);
unassigned = true(count, 1);
assign("initialRest", steps == 1);
assign("driftAfterLatch", declared & latch & ~near);
assign("latchActive", declared & latch & near);
assign("declaredRestFar", declared & ~latch & ~near);
assign("nearBeforeLatch", declared & ~latch & near);
assign("lowActivityCountdown", lowActivityCountdown);
assign("intentionalMovement", ~declared & ~latch & moving);

    function assign(label, mask)
        selected = unassigned & mask;
        context(selected) = label;
        unassigned(selected) = false;
    end
end
