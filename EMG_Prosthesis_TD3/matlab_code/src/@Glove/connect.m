function connect(obj)
%obj.connect() connects via USB to the glove. Port and baud rate are
%defined inside the class.
%

%%
obj.isConnected = false; % prealloc

try
    if isempty(instrfind('Port', obj.port))
        obj.serial = serialport(obj.port, obj.baudRate);
        obj.serial.configureTerminator(obj.terminator);
        drawnow
    else
        error('Could not connect.')
    end
    
    obj.isConnected = true;
    
catch ME
    if ~isempty(instrfindall)
        fclose(instrfindall);
        delete(instrfindall);
    end
    
    
    %% showing the available devices
    warning('Could not be connected.')
    disp('Check the correct COM port.')
    devices = EnumSerialComs;
    
    devs = [convertCharsToStrings(devices(:, 1))'; string([devices{:, 2}])];
    fprintf('Device name\t\t\t\t\tCOMport\n')
    fprintf('%s\t\t%s\n', devs)
    
    error(ME.message)
end
end
