function [action, info] = referenceQuantizedController(target, pred, prevAction, options)
%referenceQuantizedController proportional quantized controller for demos.
%
% The controller is intentionally simple: it uses the current normalized
% tracking error, a deadband, coarse magnitude bins and a rate limiter.
% This creates a smoother prior than the aggressive benchmark while
% remaining consistent with the quantized actuator levels used by the env.

if nargin < 4 || isempty(options)
    options = struct();
end

if ~isfield(options, "deadband"), options.deadband = 0.03; end
if ~isfield(options, "errorBins"), options.errorBins = [0.06 0.12 0.20]; end
if ~isfield(options, "actionMagnitudes"), options.actionMagnitudes = [0.376 0.627 0.878 1.0]; end
if ~isfield(options, "maxDelta"), options.maxDelta = 0.251; end

target = double(target(:));
pred = double(pred(:));
prevAction = double(prevAction(:));

if numel(options.actionMagnitudes) ~= numel(options.errorBins) + 1
    error("actionMagnitudes must have exactly one more element than errorBins.");
end

err = target - pred;
absErr = abs(err);

desiredMagnitude = zeros(size(err));
for i = 1:numel(err)
    if absErr(i) < options.deadband
        desiredMagnitude(i) = 0;
    elseif absErr(i) < options.errorBins(1)
        desiredMagnitude(i) = options.actionMagnitudes(1);
    elseif absErr(i) < options.errorBins(2)
        desiredMagnitude(i) = options.actionMagnitudes(2);
    elseif absErr(i) < options.errorBins(3)
        desiredMagnitude(i) = options.actionMagnitudes(3);
    else
        desiredMagnitude(i) = options.actionMagnitudes(4);
    end
end

desiredAction = sign(err) .* desiredMagnitude;
delta = desiredAction - prevAction;
delta = max(-options.maxDelta, min(options.maxDelta, delta));
action = prevAction + delta;
action = max(-1, min(1, action));

info = struct( ...
    "error", err, ...
    "desiredAction", desiredAction, ...
    "clippedDelta", delta);
end
