function connectMyo(obj)
% Función para conectarse al Myo. Utiliza librería Myo Mex. No se realiza
% ninguna acción en el caso de que el dispositivo ya esté
% conectado. La estructura que contiene los datos del Myo se llama
% myoObject.


obj.isConnected = 1; % Bandera que indica estado de conexión

try
    % Revisando si existe conexión existente
    obj.isConnected = obj.myoObject.myoData.isStreaming;
    
    if isnan(obj.myoObject.myoData.rateEMG)
        terminateMyo
        obj.isConnected = 0;
    end
catch
    % En el caso de que no haya conexión detectada.
    
    try
        % Nueva conexión
        obj.myoObject = MyoMex();
        %         beep
        obj.myoObject.myoData.startStreaming();
        
        % fprintf('Conexión con MYO exitosa!!!\n');
    catch
        % No conexión posible
        obj.isConnected = 0;
    end
end
end