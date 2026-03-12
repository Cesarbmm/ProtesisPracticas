classdef FakeGlove < handle
    %FakeGlove is a mock class that substitutes Glove.

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    Fake Glove
    Anderson Cárdenas

    mod by Jonathan Zea
    %}

    % modified from Glove
    properties (Constant)
        port = 'COM19';
        baudRate = 115200;

        samplingRate = 10; % Hz aka 100ms
    end

    properties (Hidden=true, Constant)
        parsingStr = {'A','B','C','D','E','F','G','H',...
            'I','s','J','Y','P','R'};

        terminator = 'CR/LF';
    end
    properties (GetAccess = public, SetAccess=private)
        msg = 'A0B0C0D0E0F0G0H0I0s0J0Y0P0R0';
        isConnected;
        serial(1, 1){isa(serial, 'serialport')};
    end

    properties(Access=private, Hidden)
        % time of last reading, to approximate sampling rate
        ticGlove = tic;
        minOhm = 0;
        maxOhm = 1200;
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        % Contructor method creates an instance of the environment
        function obj = FakeGlove(~, ~)
            %FAKEGLOVE Construct an instance of this class
            obj.isConnected = true;
        end

        % -----------------------------------------------------------------
        function data = read(obj)
            x = ceil(toc(obj.ticGlove) * obj.samplingRate);
            data = struct('thumb', cell(x, 1), 'indexUp', cell(x, 1), ...
                'indexDown', cell(x, 1), 'middleUp', cell(x, 1), ...
                'middleDown', cell(x, 1), 'ringUp', cell(x, 1), ...
                'ringDown', cell(x, 1), 'pinkyUp', cell(x, 1), ...
                'pinkyDown', cell(x, 1), 'switchIndexMiddle',...
                cell(x, 1), 'dipSwitch', cell(x, 1), 'yaw', ...
                cell(x, 1), 'pitch', cell(x, 1), 'roll', cell(x, 1));

            for i = 1:x
                dataP.thumb = randi([obj.minOhm obj.maxOhm]);
                dataP.indexUp = randi([obj.minOhm obj.maxOhm]);
                dataP.indexDown = randi([obj.minOhm obj.maxOhm]);
                dataP.middleUp = randi([obj.minOhm obj.maxOhm]);
                dataP.middleDown = randi([obj.minOhm obj.maxOhm]);
                dataP.ringUp = randi([obj.minOhm obj.maxOhm]);
                dataP.ringDown = randi([obj.minOhm obj.maxOhm]);
                dataP.pinkyUp = randi([obj.minOhm obj.maxOhm]);
                dataP.pinkyDown = randi([obj.minOhm obj.maxOhm]);
                dataP.switchIndexMiddle = randi([obj.minOhm obj.maxOhm]);
                dataP.dipSwitch = randi([obj.minOhm obj.maxOhm]);

                % not used, does not matter range
                dataP.yaw = mod(randi([obj.minOhm obj.maxOhm]), 180);
                dataP.pitch = mod(randi([obj.minOhm obj.maxOhm]), 180);
                dataP.roll = mod(randi([obj.minOhm obj.maxOhm]), 180);

                data(i) = dataP;
            end
        end

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            %obj.resetBuffer deletes all the content in the buffer
            %
            obj.ticGlove = tic;
        end

    end
end

