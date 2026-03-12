function data = read(obj)
%obj.read() returns the buffer of measured data
%

% # ----
% prealloc struct
sec = toc(obj.ticRead); % time
x = ceil(sec*obj.samplingRate*obj.rateIncreaseFactor);

data = struct('thumb', cell(x, 1), 'indexUp', cell(x, 1), ...
    'indexDown', cell(x, 1), 'middleUp', cell(x, 1), ...
    'middleDown', cell(x, 1), 'ringUp', cell(x, 1), ...
    'ringDown', cell(x, 1), 'pinkyUp', cell(x, 1), ...
    'pinkyDown', cell(x, 1), 'switchIndexMiddle',...
    cell(x, 1), 'dipSwitch', cell(x, 1), 'yaw', ...
    cell(x, 1), 'pitch', cell(x, 1), 'roll', cell(x, 1));

% loop to read all the messages
n = 0;
while obj.serial.NumBytesAvailable > 0
    str = obj.serial.readline();

    if isempty(str)
        continue;
    end

    % data
    n = n + 1;
    try
        data(n) = Glove.decodingSerialData(str, obj.parsingStr);
    catch
        n = n - 1;
    end
end
obj.ticRead = tic;
data = data(1:n);
end