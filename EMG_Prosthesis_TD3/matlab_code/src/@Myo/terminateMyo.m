function terminateMyo(obj)
% Function to stop myo for streaming data, is required to delete object
% twice just to be sure.
obj.isConnected = false;


try
    % Stopping obj.myoObject
    obj.myoObject.myoData.stopStreaming();
    pause(0.1)
    obj.myoObject.delete;

    obj.isConnected = false;
catch me
    disp(me)
    try
        obj.myoObject.myoData.stopStreaming();
        obj.myoObject.delete;
    catch me
        disp(me)
    end
end

