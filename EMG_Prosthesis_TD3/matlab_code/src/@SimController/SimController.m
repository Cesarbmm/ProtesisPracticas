classdef SimController < handle
    %SimController mock class for Controller.
    % Includes a simulator of the prosthesis dynamics.
    % Requires the Timing object of the episode.

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    
    %}

    %%
    properties (SetAccess=protected)
        vels = [0 0 0 0];%1-by-4

        buffer = [0 0 0 0];

        tocStop; % moment from which prosthesis stopped

        timing; % object that mocks time

        sampling_period = 0.14; % seconds

        c0 = 0; % counter of periods
    end

    properties (Hidden=true)
        isConnected = false;
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = SimController(timing)
            %SimController(...)
            %

            % # ----
            obj.isConnected = true;

            obj.timing = timing;
            obj.c0 = timing.c;
        end

        %%
        % -----------------------------------------------------------------
        function completed = closeHand(obj)

            obj.sendAllSpeed(255, 255, 255, 255);
            completed = true;
        end

        %%
        % -----------------------------------------------------------------
        function completed = sendAllSpeed(obj, pwm1, pwm2, pwm3, pwm4)

            obj.updatePos();

            obj.vels = [pwm1, pwm2, pwm3, pwm4];
            completed = true;
        end
        %%
        % -----------------------------------------------------------------
        function completed = sendSpeed(obj, motor, pwm)
            obj.updatePos();

            obj.vels(motor) = pwm;
            completed = true;
        end

        %%
        % -----------------------------------------------------------------
        function completed = resetEncoder(obj, v1, v2, v3, v4)
            % # ---- Data Validation
            arguments
                obj
                v1(1,1) double {mustBeInteger} = 0;
                v2(1,1) double {mustBeInteger} = 0;
                v3(1,1) double {mustBeInteger} = 0;
                v4(1,1) double {mustBeInteger} = 0;
            end

            obj.updatePos();
            obj.buffer(end + 1, :) = [v1 v2 v3 v4];
            completed = true;
        end

        %%
        % -----------------------------------------------------------------
        function completed = stop(obj)
            obj.updatePos();

            obj.vels = zeros(1, 4);
            completed = true;
        end

        %%
        % -----------------------------------------------------------------
        function completed = stopMotor(obj, idxs)
            obj.updatePos();

            obj.vels(idxs) = 0;
            completed = true;
        end
        %%
        % -----------------------------------------------------------------
        function completed = goHomePosition(obj, ~, ~, ~)
            obj.updatePos();

            obj.resetBuffer();

            obj.buffer = [0 0 0 0];
            completed = true;
        end

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj, last_pos)
            % # ---- Data Validation
            arguments
                obj
                last_pos   (1, 4) double = [0 0 0 0];
            end

            obj.buffer = last_pos;
            obj.c0 = obj.timing.c;
        end

        %%
        % -----------------------------------------------------------------
        function data = read(obj)
            obj.updatePos();

            data = obj.buffer;
            obj.resetBuffer(data(end, :));
        end
    end

    methods (Access=protected)

        %%
        % -----------------------------------------------------------------
        function updatePos(obj)
            % Calculates and updates trajectory until this moment on time
            % with the recorded speeds.

            % how many times did the prosthesis was moving suppossely.
            cs = obj.timing.c - obj.c0;
            duration = cs*obj.timing.period();
            obj.c0 = obj.timing.c;

            if duration  == 0

                return;
            elseif duration < 0
                warning("Duration lower than 0.")
                return;
            elseif isempty(duration)
                error("Duration can not be empty for simulator.")
            end

            % trayectory before changing speed during this time
            trajectory = SimController.prosthesis_simulator( ...
                obj.buffer(end, :), obj.vels, duration, ...
                obj.sampling_period);

            obj.buffer = [obj.buffer; trajectory];
        end
    end

    methods (Static)
        trajectory = prosthesis_simulator( ...
            initial_position, speeds, duration, sampling_period);
    end
end