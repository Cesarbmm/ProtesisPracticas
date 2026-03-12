function connect_serial(obj)
%obj.connect_serial() connects via USB serial to the prosthesis. Port and baud
%rate are properties defined inside the class.
%

%%
obj.isConnected = false; % prealloc

try
    obj.device = serialport(obj.port, obj.baudRate);
    obj.device.configureTerminator(obj.terminatorRead, obj.terminatorWrite);
    drawnow
    obj.send("ACK"); % To start transmitting
    obj.isConnected = true;

catch ME
    %% showing the available devices
    warning('Could not be connected.')
    disp('Check the correct COM port.')
    devices = EnumSerialComs;

    devs = [convertCharsToStrings(devices(:, 1))'; string([devices{:, 2}])];
    fprintf('Device name\t\t\t\t\tCOMport\n')
    fprintf('%s\t\t%s\n', devs)

    error(ME.message)
end

