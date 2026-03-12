classdef Glove < handle
    %Glove is a class that handles the reading of the measurements of the
    %glove. The glove has 9 flex sensors, an IMU. More info at:
    %https://bibdigital.epn.edu.ec/handle/15000/16712

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona!
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    11 August 2021
    Matlab 9.9.0.1592791 (R2020b) Update 5.
    %}

    %%
    properties (SetAccess=immutable)
        port;
        baudRate;
        
        samplingRate = 10; % Hz aka 100ms
        rateIncreaseFactor = 1.3; % just to be sure to no overflow buffer
    end
    properties (SetAccess=protected)
        ticRead = tic(); % time of last reading
    end
    properties (Hidden=true, Constant)
        % waitSerial = 0.2; % time to wait for data, unkwnonw
        parsingStr = {'A','B','C','D','E','F','G','H',...
            'I','s','J','Y','P','R'};

        terminator = 'CR/LF';
    end
    properties (GetAccess = public, SetAccess=private)
        msg = 'A0B0C0D0E0F0G0H0I0s0J0Y0P0R0';
        isConnected;
        serial(1, 1){isa(serial, 'serialport')};

    end

    %%
    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = Glove(COMport, baudRate)
            %Glove(...) constructor
            %
            %# Outputs
            %* out        -salida descripción
            %

            % # ---- Data Validation
            arguments
                COMport (1, :) char = 'COM19';
                baudRate (1, 1) double = 115200;
            end

            % # ----
            obj.port = COMport;
            obj.baudRate = baudRate;
            obj.connect();
        end

        data = read(obj)

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            %obj.resetBuffer deletes all the content in the buffer
            %

            obj.serial.flush();
        end

        %% externally defined methods
        connect(obj)
    end

    methods (Static)
        data = decodingSerialData(msg, parsingStr)
        glove_tb = change_format(gloveData);
    end
end
% More properties at: AbortSet, Abstract, Access, Dependent, GetAccess, ...
% GetObservable, NonCopyable, PartialMatchPriority, SetAccess, ...
% SetObservable, Transient, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/property-attributes.html

% Methods: Abstract, Access, Hidden, Sealed, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html