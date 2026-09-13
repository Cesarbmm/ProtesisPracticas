classdef MockMyoDataSource < handle
 % Fuente determinista para infraestructura; ninguna evidencia cientifica.
 properties (SetAccess=private)
  Connected=false
  Clock=0
  LastEMG=0
  LastIMU=0
  IncludeIMU=true
 end
 methods
  function obj=MockMyoDataSource(includeIMU)
   if nargin>0,obj.IncludeIMU=logical(includeIMU);end
  end
  function connect(obj),obj.Connected=true;end
  function disconnect(obj),obj.Connected=false;end
  function t=now(obj),t=obj.Clock;end
  function advance(obj,dt)
   assert(isscalar(dt)&&isfinite(dt)&&dt>=0,"MyoMock:Time","Datos o estado incompatibles con MyoMock:Time.");obj.Clock=obj.Clock+dt;
  end
  function p=read(obj)
   assert(obj.Connected,"MyoSource:Disconnected","Datos o estado incompatibles con MyoSource:Disconnected.");p=emptyMyoPacket();
   n=floor(obj.Clock*200+1e-8);k=(obj.LastEMG+1:n)';obj.LastEMG=n;
   p.time_emg=k/200;p.arrival_emg=repmat(obj.Clock,numel(k),1);
   % Codigos/128 como MyoData; ni offset ni filtro del RAW guardado.
   p.emg_raw=round(22*sin(2*pi*p.time_emg*(7:14))+8*cos(2*pi*p.time_emg*(17:24)))/128;
   if obj.IncludeIMU
    n=floor(obj.Clock*50+1e-8);k=(obj.LastIMU+1:n)';obj.LastIMU=n;
    p.time_imu=k/50;p.arrival_imu=repmat(obj.Clock,numel(k),1);
    p.quat=[cos(p.time_imu/10),sin(p.time_imu/10),zeros(numel(k),2)];
    p.gyro=[ones(numel(k),1),zeros(numel(k),2)];p.accel=[zeros(numel(k),2),ones(numel(k),1)];p.pose=zeros(numel(k),1);
   end
  end
  function s=info(~)
   s=struct("source","MOCK","scientific_data",false,"emg_channels",8,"expected_emg_hz",200,"expected_imu_hz",50, ...
    "emg_units","SDK_COUNTS_DIV_128","timestamp_provenance","SYNTHETIC_NOMINAL","dropout_certified",false);
  end
 end
end
