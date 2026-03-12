function data = decodingSerialData(msg, parsingStr)
% msg is the string that is received via COM port.
% data is a structure with all the fields already parsed.

dataSerial = strsplit(msg, parsingStr);
dataSerial = str2double(dataSerial);

%% data parsing
% dataSerial(1) ignore. Colateral from parsing... Not part of dataSerial.
data.thumb = dataSerial(2);

data.indexUp = dataSerial(3);
data.indexDown = dataSerial(4);

data.middleUp = dataSerial(5);
data.middleDown = dataSerial(6);

data.ringUp = dataSerial(7);
data.ringDown = dataSerial(8);

data.pinkyUp = dataSerial(9);
data.pinkyDown = dataSerial(10);

data.switchIndexMiddle = dataSerial(11);

data.dipSwitch = dataSerial(12);

data.yaw = dataSerial(13);
data.pitch = dataSerial(14);
data.roll = dataSerial(15);

end