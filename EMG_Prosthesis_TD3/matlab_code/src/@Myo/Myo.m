classdef Myo < handle
    %Myo class to communicate with myo

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona!
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    12 August 2021
    Matlab 9.9.0.1592791 (R2020b) Update 5.
    %}

    %%
    properties (GetAccess = public, SetAccess=private)
        isConnected = false;
        myoObject
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = Myo()
            %Myo(...) creates a new myo object
            %

            % # ----
            connectMyo(obj);
        end

        connectMyo(obj)
        terminateMyo(obj)

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            obj.myoObject.myoData.clearLogs();
        end
        %%
        % -----------------------------------------------------------------
        function emg = readEmg(obj)
            %obj.readEmg() returns EMG signal
            %# Outputs
            %* emg		-M-by-8
            %

            % # ----
            emg = obj.myoObject.myoData.emg_log;
            obj.myoObject.myoData.clearLogs();
        end
        %% 
        % -----------------------------------------------------------------
        function delete(obj)
            obj.terminateMyo();
        end
    end
end
% More properties at: AbortSet, Abstract, Access, Dependent, GetAccess, ...
% GetObservable, NonCopyable, PartialMatchPriority, SetAccess, ...
% SetObservable, Transient, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/property-attributes.html

% Methods: Abstract, Access, Hidden, Sealed, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html