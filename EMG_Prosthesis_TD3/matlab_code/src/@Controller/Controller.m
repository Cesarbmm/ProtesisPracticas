classdef Controller < handle
    %Controller is a class that handles communication with Wemos D1 ESPR32
    %via Bluetooth or serial.

    %{
    Laboratorio de Inteligencia y Visión Artificial
    ESCUELA POLITÉCNICA NACIONAL
    Quito - Ecuador
    
    autor: ztjona!
    jonathan.a.zea@ieee.org
    
    "I find that I don't understand things unless I try to program them."
    -Donald E. Knuth
    %}

    %%
    properties (Access=public)
        device (1,1) {isa(device, 'bluetooth')}% bluetooth object
    end

    properties (Hidden=true)
        isConnected = false;
        port;
        baudRate;
    end

    properties (Hidden=true, Constant)
        timeout = 2; % in seconds to wait bluetooth message
        terminatorRead = 'CR/LF'; % carriage return, line feed
        terminatorWrite = 'LF'; % line feed
        motorsPosDir = {'A', 'B', 'C', 'D'};
        motorsNegDir = {'a', 'b', 'c', 'd'};
    end

    methods
        %% Constructor
        % -----------------------------------------------------------------
        function obj = Controller(bluetoothFlag,blName,COMport,baudRate)
            %Controller(...) constructor, connects with Bluetooth device by
            %name
            %
            %# Inputs
            %*ble       -bool, flag to determine type of connection.
            %* blName   -char with the name of the bluetooth device, by
            %           default is 'prosthesisEPN'.
            %
            %# Outputs
            %

            % # ---- Data Validation
            arguments
                bluetoothFlag (1,1) logical = false;
                blName   (1, :) char = 'Prosthesis_EPN_v2';
                COMport (1, :) char = 'COM4';
                baudRate (1, 1) double = 250000;
            end

            % #
            if bluetoothFlag
                % bluetooth connection
                obj.device = bluetooth(blName);
                obj.device.Timeout = obj.timeout;
                obj.device.configureTerminator(...
                    obj.terminatorRead, obj.terminatorWrite);

            else
                % serial connection
                obj.port = COMport;
                obj.baudRate = baudRate;
                obj.connect_serial();
            end

            pause(10)
        end
        %%
        % -----------------------------------------------------------------
        function completed = closeHand(obj)
            %obj.closeHand() sends the close hand command.
            %
            %# Inputs
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %
            completed = obj.send("C:");
        end

        %%
        % -----------------------------------------------------------------
        function completed = openHand(obj)
            %obj.openHand() sends the open hand command.
            %
            %# Inputs
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %
            completed = obj.send("C:");
        end


        %%
        % -----------------------------------------------------------------
        function completed = sendAllSpeed(obj, pwm1, pwm2, pwm3, pwm4)
            %obj.sendAllSpeed() sends via Bluetooth the 4 pwm commands
            %
            %# Inputs
            %* pwm1,2,3,4     -double with PWM speed to motors, negative
            %                   means reverse direction
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %

            % # ---- Data Validation
            arguments
                obj
                pwm1 (1,1) double {mustBeInRange(pwm1, -255, 255)}
                pwm2 (1,1) double {mustBeInRange(pwm2, -255, 255)}
                pwm3 (1,1) double {mustBeInRange(pwm3, -255, 255)}
                pwm4 (1,1) double {mustBeInRange(pwm4, -255, 255)}
            end
                % # ---- DEBUG: Imprimir valores sin redondear
            fprintf('[Controller] PWM RAW VALUES:\n');
            fprintf('  pwm1: %f (isfinite: %d)\n', pwm1, isfinite(pwm1));
            fprintf('  pwm2: %f (isfinite: %d)\n', pwm2, isfinite(pwm2));
            fprintf('  pwm3: %f (isfinite: %d)\n', pwm3, isfinite(pwm3));
            fprintf('  pwm4: %f (isfinite: %d)\n', pwm4, isfinite(pwm4));
            % # ----

             % # ---- Redondear valores
            pwm1 = round(pwm1);
            pwm2 = round(pwm2);
            pwm3 = round(pwm3);
            pwm4 = round(pwm4);

            % # ---- DEBUG: Imprimir valores DESPUÉS de redondear
            fprintf('[Controller] ROUNDED PWM VALUES:\n');
            fprintf('  pwm1: %.0f\n', pwm1);
            fprintf('  pwm2: %.0f\n', pwm2);
            fprintf('  pwm3: %.0f\n', pwm3);
            fprintf('  pwm4: %.0f\n', pwm4);

            
            mt1 = getMotorCode(obj, 1, pwm1);
            mt2 = getMotorCode(obj, 2, pwm2);
            mt3 = getMotorCode(obj, 3, pwm3);
            mt4 = getMotorCode(obj, 4, pwm4);
            msj = sprintf('%c%s%c%s%c%s%c%s', ...
                mt1, dec2hex(abs(pwm1), 2), ...
                mt2, dec2hex(abs(pwm2), 2), ...
                mt3, dec2hex(abs(pwm3), 2),...
                mt4, dec2hex(abs(pwm4), 2));

            completed = obj.send(msj);
        end

        %%
        % -----------------------------------------------------------------
        function completed = sendSpeed(obj, motor, pwm)
            %obj.sendSpeed() sends via Bluetooth a pwm command of a motor
            %
            %# Inputs
            %* motor          - double between 1 and 4
            %* pwm            -double with PWM speed to motors, negative
            %                   means reverse direction
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %

            % # ---- Data Validation
            arguments
                obj
                motor (1,1) double {mustBeInRange(motor, 1, 4)}
                pwm (1,1) double {mustBeInRange(pwm, -255, 255)}
            end

            % # ----
            mtCode = getMotorCode(obj, motor, pwm);
            msj = sprintf('%c%s', mtCode, dec2hex(abs(pwm), 2));
            completed = obj.send(msj);
        end

        %%
        % -----------------------------------------------------------------
        function completed = changePeriod(obj, msPeriod)
            %obj.changePeriod() sends the new period for
            %sending the encoders position
            %
            %# Inputs
            %* msPeriod     -double. the ESP32 will send the encoders
            %               position each period in ms
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %

            % # ---- Data Validation
            arguments
                obj
                msPeriod (1,1) double {mustBePositive, mustBeInteger}
            end

            msj = sprintf('P%d', msPeriod);
            completed = obj.send(msj);
        end

        %%
        % -----------------------------------------------------------------
        function completed = resetEncoder(obj, v1, v2, v3, v4)
            %obj.resetEncoder() resets the encoder values
            %
            %# Inputs
            %* v1,2,3,4  -int the new value for each encoder
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.
            %

            % # ---- Data Validation
            arguments
                obj
                v1(1,1) double {mustBeInteger} = 0;
                v2(1,1) double {mustBeInteger} = 0;
                v3(1,1) double {mustBeInteger} = 0;
                v4(1,1) double {mustBeInteger} = 0;
            end
            if v1 == 0 && v2 == 0&& v3 == 0 && v4 == 0
                msj = 'R:';
            else
                msj = sprintf('R%dr%dr%dr%d',v1,v2,v3,v4); % not yet
            end
            completed = obj.send(msj);
        end
        %%
        % -----------------------------------------------------------------
        function completed = stop(obj)
            %obj.stop() stops all the motors
            %
            %# Inputs
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.

            % # ----
            msj = 'S:';
            completed = obj.send(msj);
        end

        %%
        % -----------------------------------------------------------------
        function completed = stopMotor(obj, idxs)
            %obj.stop() stops the given motor indexes.
            %
            %# Inputs
            %
            %# Outputs
            %* completed    -bool when true was correct, otherwise false.

            % # ----
            completed = true;
            for i = idxs
                msj = sprintf('S%d:', i);
                completed = completed  && obj.send(msj);
            end
        end

        %%
        % -----------------------------------------------------------------
        function resetBuffer(obj)
            %obj.resetBuffer deletes all the content in the buffer

            obj.device.flush();
        end

        %%
        % -----------------------------------------------------------------
        function data = read(obj)
            %obj.read() returns the buffer of enconder vals
            %
            %# Inputs
            %
            %# Outputs
            %* data        -double m-by-4 with m measurements
            %

            % # ----
            data = []; %% assumes data was not received
            % loop to read all the messages
            while obj.device.NumBytesAvailable > 0


                % count = obj.device.NumBytesAvailable;
                % str = obj.device.read(count, 'uint8');
                % disp (str)
                % str = '';
                str = obj.device.readline();

                if isempty(str)
                    continue;
                end

                % data
                expr = '^x(-?\d+)y(-?\d+)z(-?\d+)w(-?\d+)';
                [m, isValid] = regexp(str, expr, 'tokens');
                if isValid
                    m1 = cellfun(@(x)str2double(x), m{1});
                    data = [data; m1];
                else
                    fprintf('[ProsthesisEPNv2] %s\n',str);
                end
            end
        end

        %%
        % -----------------------------------------------------------------
        connect_serial(obj)
    end

    methods (Hidden = true, Access = private)
        %%
        % -----------------------------------------------------------------
        function mtCode = getMotorCode(obj, motor, pwm)
            %obj.getCode returns the code for the motor and the direction.
            %
            %# Inputs
            %* motor        -int between 1 and 4
            %* pwm          -double with PWM speed to motors, -255 to 255
            %

            % # ---- Data Validation
            arguments
                obj
                motor (1,1) double {mustBeInRange(motor, 1, 4)}
                pwm (1,1) double {mustBeInRange(pwm, -255, 255)}
            end

            % # ----
            if pwm >= 0 % deciding between A or a (i.e. forward, backward)
                % uppercase is forward
                mtCode = obj.motorsPosDir{motor};
            else
                % lowercase is backward
                mtCode = obj.motorsNegDir{motor};
            end
        end
        %%
        % -----------------------------------------------------------------
        function completed = send(obj, msj)
            %obj.send() the given msj via bluetooth, returns true when
            %correct
            %

            % # ---- Data Validation
            arguments
                obj
                msj (1, :) char
            end

            % # ----
            try
                obj.device.writeline(msj); % with \n LF
                completed = true;
            catch
                completed = false;
            end
        end
    end
end
% More properties at: AbortSet, Abstract, Access, Dependent, GetAccess, ...
% GetObservable, NonCopyable, PartialMatchPriority, SetAccess, ...
% SetObservable, Transient, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/property-attributes.html

% Methods: Abstract, Access, Hidden, Sealed, Framework attributes
% https://www.mathworks.com/help/matlab/matlab_oop/method-attributes.html