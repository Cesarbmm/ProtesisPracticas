function [envelope, sampleRanges] = computeEmgEnvelope( ...
        rawEmg, windowLength, hopLength)
%computeEmgEnvelope computes a causal mean-absolute envelope per channel.
%
% Each output row uses one complete raw-EMG window. Partial trailing windows
% are discarded so every estimate has the same physical interpretation.

arguments
    rawEmg {mustBeNumeric}
    windowLength (1, 1) double {mustBeInteger, mustBePositive}
    hopLength (1, 1) double {mustBeInteger, mustBePositive} = windowLength
end

if isempty(rawEmg) || ~ismatrix(rawEmg) || size(rawEmg, 2) < 1
    error("computeEmgEnvelope:InvalidEmg", ...
        "rawEmg must be a nonempty samples-by-channels matrix.");
end
if ~isreal(rawEmg) || any(~isfinite(rawEmg), "all")
    error("computeEmgEnvelope:NonfiniteEmg", ...
        "rawEmg must contain finite real samples.");
end
if size(rawEmg, 1) < windowLength
    error("computeEmgEnvelope:InsufficientSamples", ...
        "rawEmg has %d samples but a complete %d-sample window is required.", ...
        size(rawEmg, 1), windowLength);
end

rawEmg = double(rawEmg);
windowStarts = (1:hopLength:(size(rawEmg, 1) - windowLength + 1))';
numWindows = numel(windowStarts);
numChannels = size(rawEmg, 2);
envelope = zeros(numWindows, numChannels);
sampleRanges = zeros(numWindows, 2);

for windowIdx = 1:numWindows
    firstSample = windowStarts(windowIdx);
    lastSample = firstSample + windowLength - 1;
    envelope(windowIdx, :) = mean( ...
        abs(rawEmg(firstSample:lastSample, :)), 1);
    sampleRanges(windowIdx, :) = [firstSample, lastSample];
end
end
