classdef RecordedMyo < handle
    %RecordedMyo mock object for Myo.

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona
    jonathan.a.zea@ieee.org
    Cuando escribí este código, solo dios y yo sabíamos como funcionaba.
    Ahora solo lo sabe dios.
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    10 November 2021
    Matlab R2021B.
    %}

    %%
    properties (GetAccess = public, SetAccess=private)
        isConnected = false;
        j = 1;% first available index
        emg;
        n;%numero points
        exhausted = false; % true when data finished
    end

    properties(Access=private, Hidden)
        emgFreq = 200; % myo freq [Hz]
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = RecordedMyo(emgData)
            %obj = RecordedMyo() Constructor%emgData is a cel with m
            %examples
           
            obj.isConnected = true;
            obj.emg = emgData;
            obj.n= size(emgData,1);
        end
        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            obj.j = 1;
            obj.exhausted = false;
        end
        %%
        % -----------------------------------------------------------------

        function terminateMyo(obj)
            %obj.terminateMyo() disconnects the device

            % # ----
            obj.isConnected = false;
        end

        %%
        % -----------------------------------------------------------------
        function emgi = readEmg(obj, time_elapsed)
            %obj.readEmg() returns EMG signal
            %
            %# Inputs
            % ``time_elapsed`` seconds since last call.
            %
            %# Outputs
            %* emg		-M-by-8
            %

            % # ----
            samples = floor( obj.emgFreq * time_elapsed );
            jf = sat(samples + obj.j -1,obj.j,obj.n);
            % fprintf('%d %d\n', obj.j, jf);
            emgi = obj.emg(obj.j:jf, : );
            obj.j = jf + 1;

            if obj.j >= obj.n
                obj.exhausted = true;
            end
        end

        %%
        % -----------------------------------------------------------------
        function connectMyo(obj)
            %obj.connectMyo() connects the device

            % # ----
            obj.isConnected = true;
        end
    end
end