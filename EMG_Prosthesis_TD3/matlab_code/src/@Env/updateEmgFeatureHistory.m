function currentFeatures = updateEmgFeatureHistory(this, emg, resetHistory)
%updateEmgFeatureHistory stores a short feature history for the observation.

arguments
    this
    emg
    resetHistory (1, 1) logical = false
end

currentFeatures = this.featureCalculator(emg);
historyLength = configurables("emgHistoryLength");

if historyLength <= 1
    this.emgFeatureHistory = currentFeatures(:);
    return;
end

if resetHistory || isempty(this.emgFeatureHistory) || ...
        size(this.emgFeatureHistory, 1) ~= numel(currentFeatures) || ...
        size(this.emgFeatureHistory, 2) ~= historyLength
    this.emgFeatureHistory = repmat(currentFeatures(:), 1, historyLength);
else
    this.emgFeatureHistory = [ ...
        currentFeatures(:), ...
        this.emgFeatureHistory(:, 1:historyLength-1)];
end
end
