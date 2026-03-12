classdef FakeMyo < handle
    %FakeMyo mock object for Myo.

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
    end

    properties(Access=private, Hidden)
        % time of last reading, to approximate sampling rate
        ticMyo;
        minEmg = -1;
        maxEmg = 1;
        emgFreq = 200; % myo freq [Hz]
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = FakeMyo()
            %obj = FakeMyo() Constructor

            obj.isConnected = true;
            obj.ticMyo = tic;
        end
  %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
                obj.ticMyo = tic;
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
        function emg = readEmg(obj)
            %obj.readEmg() returns EMG signal
            %# Outputs
            %* emg		-M-by-8
            %

            % # ----
            t = round( obj.emgFreq  * toc(obj.ticMyo) );
            if t < 10
                t = 10; % creating a buffer
            end
            emg = rand(t, 8 );
            obj.ticMyo = tic;
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