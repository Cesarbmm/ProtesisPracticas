classdef MyoMexDataSource < handle
 % Adaptador de API existente. Construirlo NO conecta; connect es manual.
 properties (SetAccess=private)
  Device=[]
  Connected=false
  LastEMG=0
  LastIMU=0
 end

 methods
  function connect(obj)

    assert(~obj.Connected, ...
        "MyoSource:AlreadyConnected", ...
        "MyoMex ya esta conectado.");

    % =========================================================
    % Runtime Myo SDK + MinGW
    % =========================================================
    sdkRoot   = string(getenv('MYO_SDK_ROOT'));
    mingwRoot = string(getenv('MW_MINGW64_LOC'));

    assert(strlength(sdkRoot) > 0 && isfolder(sdkRoot), ...
        "MyoSource:MissingSDK", ...
        "MYO_SDK_ROOT no esta configurado o no existe.");

    assert(strlength(mingwRoot) > 0 && isfolder(mingwRoot), ...
        "MyoSource:MissingMinGW", ...
        "MW_MINGW64_LOC no esta configurado o no existe.");

    sdkBin   = fullfile(sdkRoot,'bin');
    mingwBin = fullfile(mingwRoot,'bin');

    assert(isfile(fullfile(sdkBin,'myo64.dll')), ...
        "MyoSource:MissingDLL", ...
        "No se encontro myo64.dll en %s.", sdkBin);

    currentPath = string(getenv('PATH'));

    if ~contains(lower(currentPath),lower(string(sdkBin)))
        currentPath = string(sdkBin) + pathsep + currentPath;
    end

    if ~contains(lower(currentPath),lower(string(mingwBin)))
        currentPath = string(mingwBin) + pathsep + currentPath;
    end

    setenv('PATH',char(currentPath));

    % =========================================================
    % Verificar wrapper y MEX
    % =========================================================
    classPath = which('MyoMex');
    mexPath   = which(['myo_mex.' mexext]);

    assert(~isempty(classPath), ...
        "MyoSource:MissingMyoMex", ...
        "No se encontro la clase MyoMex en el MATLAB path.");

    assert(~isempty(mexPath) && exist('myo_mex','file') == 3, ...
        "MyoSource:MissingMEX", ...
        "No se encontro myo_mex.%s compilado.",mexext);

    % =========================================================
    % Conexion
    % =========================================================
    obj.Device = MyoMex(1);

    obj.LastEMG = 0;
    obj.LastIMU = 0;
    obj.Connected = true;
end

  function t = now(obj)
   obj.assertConnected();
   t = obj.Device.currTime;
  end

  function p = read(obj)
   obj.assertConnected();
   d = obj.Device.myoData(1);
   p = emptyMyoPacket();
   arrival = obj.Device.currTime;

   ne = size(d.emg_log,1);
   ni = size(d.timeIMU_log,1);

   assert(ne >= obj.LastEMG && ni >= obj.LastIMU, ...
    "MyoSource:LogsReset", ...
    "Los logs se reiniciaron fuera del adaptador.");

   ie = (obj.LastEMG + 1):ne;
   ii = (obj.LastIMU + 1):ni;

   if ~isempty(ie)
    p.time_emg = d.timeEMG_log(ie,:);
    p.emg_raw = d.emg_log(ie,:);
    p.arrival_emg = repmat(arrival,numel(ie),1);
   end

   if ~isempty(ii)
    p.time_imu = d.timeIMU_log(ii,:);
    p.quat = d.quat_log(ii,:);
    p.gyro = d.gyro_log(ii,:);
    p.accel = d.accel_log(ii,:);
    p.pose = d.pose_log(ii,:);
    p.arrival_imu = repmat(arrival,numel(ii),1);
   end

   obj.LastEMG = ne;
   obj.LastIMU = ni;

   % No clearLogs: MyoData documenta que no debe llamarse durante streaming.
  end

  function disconnect(obj)
   if ~isempty(obj.Device) && isvalid(obj.Device)
    delete(obj.Device);
   end
   obj.Device = [];
   obj.Connected = false;
  end

  function delete(obj)
   obj.disconnect();
  end

  function s = info(~)
   s = struct( ...
    "source","MYOMEX", ...
    "scientific_data",true, ...
    "emg_channels",8, ...
    "expected_emg_hz",200, ...
    "expected_imu_hz",50, ...
    "emg_units","SDK_COUNTS_DIV_128", ...
    "timestamp_provenance","MYODATA_RECONSTRUCTED_NOMINAL", ...
    "dropout_certified",false, ...
    "initial_samples_removed_by_vendor",4, ...
    "vendor_emg_scale",128, ...
    "raw_definition","MYODATA_EMG_LOG_UNMODIFIED", ...
    "vendor_may_fill_missing_samples",true, ...
    "hardware_timestamps_available",false, ...
    "gyro_units","deg/s", ...
    "accel_units","g", ...
    "quat_order","wxyz");

   myoMexFile = which('MyoMex');
   myoDataFile = which('MyoData');
   binary = which(['myo_mex.' mexext]);

   s.myoMex_source_sha256 = "";
   s.myoData_source_sha256 = "";
   s.mex_available = ~isempty(binary);
   s.mex_sha256 = "";

   if ~isempty(myoMexFile)
    s.myoMex_source_sha256 = myoFileSHA256(myoMexFile);
   end

   if ~isempty(myoDataFile)
    s.myoData_source_sha256 = myoFileSHA256(myoDataFile);
   end

   if ~isempty(binary)
    s.mex_sha256 = myoFileSHA256(binary);
   end
  end
 end

 methods (Access=private)
  function assertConnected(obj)
   assert( ...
    obj.Connected && ~isempty(obj.Device) && isvalid(obj.Device), ...
    "MyoSource:Disconnected", ...
    "MyoMex no esta conectado o se cerro por error/desconexion.", ...
    "Datos o estado incompatibles con MyoMex no esta conectado o se cerro por error/desconexion.");
  end
 end
end