classdef Timing < handle
    %Timing class for handling time between simulation and real time.
    % In real time uses tic, and in simulation uses a mock.

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: Laboratorio IA
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    26 March 2024
    %}

    %%
    properties (SetAccess=protected)
        t0;
        elapsed_time = 0; % only used in simulation
        c = 0;
    end

    properties (SetAccess=immutable)
        flag_harware;
        period;
    end
    properties (Constant)

    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function this = Timing(harware, period)
            %Timing(...) creates the timing object.
            %
            % # USAGE
            %   obj = Timing(harware);
            %
            % # INPUTS
            %  harware        bool flag, when true it runs in real time
            %                   (ie. tics) otherwise, mocks.
            %  period          int, only when ``hardware`` is false, time
            %                  period for each call in the simulation.
            %
            %

            % # ---- Data Validation
            arguments
                harware   (1, 1) logical
                period    (1, 1) double = -1;
            end

            % # ----
            this.flag_harware = harware;

            if harware
                this.t0 = tic;
            else
                this.period = period;
            end
        end

        %% Methods
        % -----------------------------------------------------------------
        function t = toc(this, counter)
            % returns the time elapsed since the last tic.
            %
            % # INPUTS
            %  counter        when the simulation is running, it is the
            %                 number of periods passed.

            % # ---- Data Validation
            arguments
                this
                counter (1, 1) double {mustBeNonnegative} = 1;
            end

            % --
            this.c = this.c + 1;

            if this.flag_harware
                t = toc(this.t0);
            else
                this.elapsed_time = counter*this.period;

                t = this.elapsed_time;
            end
        end

        % -----------------------------------------------------------------
        function tic(this)
            % restarts the timer.
            this.c = 0;
            if this.flag_harware
                this.t0 = tic;
            end
        end
    end
end