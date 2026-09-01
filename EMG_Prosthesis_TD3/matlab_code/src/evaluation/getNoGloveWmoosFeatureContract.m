function contract = getNoGloveWmoosFeatureContract()
%getNoGloveWmoosFeatureContract returns the published 40-feature order.

family = ["standardDeviation"; "absoluteEnvelopeIntegral"; ...
    "meanAbsoluteValue"; "energy"; "rootMeanSquare"];
functionName = ["WMoos_F1"; "WMoos_F2"; "WMoos_F4"; ...
    "WMoos_F5"; "WMoos_F13"];
firstIndex = [1; 9; 17; 25; 33];
lastIndex = firstIndex+7;
dimension = 8.*ones(5, 1);
families = table(family, functionName, firstIndex, lastIndex, dimension);

channel = (1:8)';
standardDeviationIndex = channel;
absoluteEnvelopeIntegralIndex = channel+8;
meanAbsoluteValueIndex = channel+16;
energyIndex = channel+24;
rootMeanSquareIndex = channel+32;
channels = table(channel, standardDeviationIndex, ...
    absoluteEnvelopeIntegralIndex, meanAbsoluteValueIndex, ...
    energyIndex, rootMeanSquareIndex);

contract = struct("schemaVersion", 1, "featureCount", 40, ...
    "channelCount", 8, "familyCount", 5, ...
    "families", families, "channels", channels, ...
    "standardizedFeatures", true, ...
    "interpretedAsPhysicalAmplitude", false);
end
