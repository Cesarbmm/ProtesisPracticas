function flexData = reduceFlexDimension(gloveData)
%params.reduceFlexDimension() adds all the channels related to a finger in
%the glove data (9 flex sensors) so it can be compared with the motor data
%(4 encoder sensors). This means converting from n-by-9 to n-by-4.

persistent fingers flexMapping
if isempty(fingers)
    fingers = definitions("fingers");
end

if isempty(flexMapping)
    flexMapping = definitions("flexMapping");
end

flexData = zeros(length(gloveData), 4);
% flex
for i = 1:numel(fingers)
    fingerName = fingers{i};

    y = zeros(length(gloveData), 1);
    for flexS = flexMapping.(fingerName)
        y = y + cat( 1, gloveData.( flexS{1}) );
    end

    flexData(:, i) = y;
    % flexData(:, i) = 2*y; % simplified version of polyval
end



