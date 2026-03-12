classdef RecordedGlove < handle
    %RecordedGlove is a mock class that substitutes Glove.

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
        j = 1;% first available index
        n;%numero points
        exhausted = false; % true when data finished
        gloveData;
    end


    methods
        %% Constructor
        % -----------------------------------------------------------------
        % Contructor method creates an instance of the environment
        function obj = RecordedGlove(gloveDataI)
            %RecordedGlove Construct an instance of this class
            obj.gloveData = gloveDataI;
            obj.n = size(gloveDataI, 1);
            obj.isConnected = true;
        end

        % -----------------------------------------------------------------
        function data = read(obj, time_elapsed)
            % ``time_elapsed`` seconds since last call.
            samples = floor(time_elapsed * obj.samplingRate);

            jf = sat(samples+ obj.j -1,obj.j,obj.n);
            data = obj.gloveData(obj.j:jf);
            obj.j = jf + 1;

            if obj.j >= obj.n
                obj.exhausted = true;
            end
        end

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            %obj.resetBuffer deletes all the content in the buffer
            %
            obj.j = 1;
            obj.exhausted = false;
        end

    end
end

