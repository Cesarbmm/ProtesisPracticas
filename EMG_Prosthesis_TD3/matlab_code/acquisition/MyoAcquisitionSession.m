classdef MyoAcquisitionSession < handle
 % Backend de trials. Sin GUI, modelos, caracteristicas ni actuadores.
 properties (SetAccess=private)
  Source
  Protocol
  Metadata
  Directory
  Status="CREATED"
  Index=1
  TrialID=1
  StartTime=0
  LastClock=0
  LastRecovery=0
  Buffer
  LatestPacket
  TargetEvents=table()
  LastError=""
  BlockEvents=table()
  SkipBacklog=false
 end
 methods
  function obj=MyoAcquisitionSession(source,outputRoot,metadata,protocol)
   for f=["participant_id","session_id","placement_id"]
    assert(isfield(metadata,f)&&~isempty(regexp(char(metadata.(f)),'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$','once')),"MyoSession:Identifier","Datos o estado incompatibles con MyoSession:Identifier.");
   end
   assert(ismember(string(metadata.arm),["right","left"]),"MyoSession:Arm","Datos o estado incompatibles con MyoSession:Arm.");
   assert(istable(protocol)&&height(protocol)>0&&any(protocol.rest_intent),"MyoSession:Protocol","Datos o estado incompatibles con MyoSession:Protocol.");
   if isfield(metadata,'campaign_id')
    required=["session_uuid","protocol_version","random_seed","arm_posture_id","posture_confirmed","participant_confirmed","placement_confirmed","posture_reference_asset","posture_reference_sha256"];
    assert(all(isfield(metadata,required))&&isequal(metadata.posture_confirmed,true)&&isequal(metadata.participant_confirmed,true)&&isequal(metadata.placement_confirmed,true), ...
     'MyoSession:Confirmations','Confirmar identidad, colocación y postura antes de crear sesión.');
    assert(all(protocol.arm_posture_id==string(metadata.arm_posture_id))&&all(protocol.campaign_id==string(metadata.campaign_id))&& ...
     all(protocol.protocol_version==string(metadata.protocol_version))&&all(protocol.randomization_seed==metadata.random_seed), ...
     'MyoSession:Campaign','Descriptor y protocolo no coinciden.');
    registry=MyoParticipantRegistry(outputRoot);registry.verifyReservation(metadata);
    asset=fullfile(fileparts(mfilename('fullpath')),string(metadata.posture_reference_asset));
    assert(startsWith(string(metadata.posture_reference_asset),"assets/")&&isfile(asset)&& ...
     myoFileSHA256(asset)==string(metadata.posture_reference_sha256),'MyoSession:PostureAsset','Referencia de postura no verificable.');
   end
   if ismember('campaign',protocol.Properties.VariableNames)&&any(protocol.campaign=="MYO_PILOT2_OPEN_CLOSE")
    validateMyoPilot2Protocol(protocol);
    if ~isfield(metadata,'campaign_id')
     metadata.arm_posture_id="P0_NEUTRAL_90";
     metadata.arm_posture_description="Tronco erguido; codo aproximadamente 90°; antebrazo frente al torso; muñeca neutra; evitar mover hombro/antebrazo.";
    end
    metadata.randomization_seed=protocol.randomization_seed(1);
    metadata.randomized_order=table2struct(protocol(protocol.condition=="MOVEMENT",{'block_id','randomized_order','condition_id','direction','movement_level','repetition'}));
    metadata.campaign="MYO_PILOT2_OPEN_CLOSE";metadata.placement_change_allowed=false;
    metadata.vision_camera_excluded=true;metadata.measured_aperture_provider="NONE";
   end
   obj.Source=source;obj.Protocol=protocol;obj.Metadata=metadata;obj.Metadata.source_info=source.info();
   obj.Metadata.created_utc=string(datetime('now',TimeZone='UTC',Format='yyyy-MM-dd HH:mm:ss.SSS Z'));
   obj.Metadata.capture_utc=obj.Metadata.created_utc;
   if ~isfield(obj.Metadata,'session_uuid'),obj.Metadata.session_uuid=string(java.util.UUID.randomUUID());end
   parent=fullfile(outputRoot,string(metadata.participant_id));if ~isfolder(parent),mkdir(parent);end
   obj.Directory=string(fullfile(parent,string(metadata.session_id)));
   assert(~isfolder(obj.Directory),"MyoSession:Exists","Usar otro session_id; no mezclar ni sobrescribir una sesion existente.");
   % Creacion exclusiva del directorio: un unico escritor por sesion.
   java.nio.file.Files.createDirectory(java.io.File(char(obj.Directory)).toPath(),javaArray('java.nio.file.attribute.FileAttribute',0));
   mkdir(fullfile(obj.Directory,"trials"));mkdir(fullfile(obj.Directory,"recovery"));
   writetable(protocol,fullfile(obj.Directory,"protocol.csv"));
   obj.Metadata.protocol_sha256=myoFileSHA256(fullfile(obj.Directory,"protocol.csv"));
   code=dir(fullfile(fileparts(mfilename("fullpath")),"*.m"));hashes=struct("file",{},"sha256",{});
   for k=1:numel(code),hashes(k)=struct("file",string(code(k).name),"sha256",myoFileSHA256(fullfile(code(k).folder,code(k).name)));end
   obj.Metadata.acquisition_code_hashes=hashes;
   myoWriteJSONAtomic(fullfile(obj.Directory,"metadata.json"),obj.Metadata);
   obj.Buffer=emptyMyoPacket();obj.LatestPacket=emptyMyoPacket();obj.writeStatus();
  end
  function start(obj)
   assert(ismember(obj.Status,["CREATED","PAUSED"]),"MyoSession:StartState","Datos o estado incompatibles con MyoSession:StartState.");
   obj.beginTrial();
  end
  function tick(obj)
   if obj.Status~="RUNNING",return;end
   try
    obj.capture();
    if obj.LastClock-obj.StartTime>=obj.Protocol.duration_s(obj.Index)-1e-9
     obj.saveCurrent("COMPLETED");obj.Index=obj.Index+1;
     if obj.Index>height(obj.Protocol),obj.Status="FINISHED";obj.writeStatus();else,obj.beginTrial();end
    elseif obj.LastClock-obj.LastRecovery>=1
     obj.snapshot();
    end
   catch ex
    % Preservar el ultimo prefijo disponible aunque el dispositivo ya sea invalido.
    obj.LastError=string(getReport(ex,'extended','hyperlinks','off'));
    try,obj.saveCurrent("ERROR_PARTIAL");catch saveError,ex=addCause(ex,saveError);end
    obj.Status="ERROR";
    try,obj.writeStatus();catch statusError,ex=addCause(ex,statusError);end
    rethrow(ex);
   end
  end
  function pause(obj)
   assert(obj.Status=="RUNNING","MyoSession:PauseState","Datos o estado incompatibles con MyoSession:PauseState.");obj.capture();obj.saveCurrent("PAUSED_PARTIAL");obj.Status="PAUSED";obj.writeStatus();
  end
  function repeat(obj)
   assert(ismember(obj.Status,["RUNNING","PAUSED","FINISHED"]),"MyoSession:RepeatState","Datos o estado incompatibles con MyoSession:RepeatState.");
   if obj.Status=="RUNNING",obj.capture();obj.saveCurrent("REPEATED_PARTIAL");end
   obj.Index=min(obj.Index,height(obj.Protocol));obj.beginTrial();
  end
  function abort(obj)
   if obj.Status=="RUNNING"
    try,obj.capture();catch,end
    obj.saveCurrent("ABORTED_PARTIAL");
   end
   obj.Status="ABORTED";obj.writeStatus();
  end
  function finish(obj)
   if obj.Status=="RUNNING",obj.capture();obj.saveCurrent("FINISHED_PARTIAL");end
   if ~ismember(obj.Status,["ERROR","ABORTED"]),obj.Status="FINISHED";end
   obj.writeStatus();
  end
  function v=preview(obj)
   row=table2struct(obj.Protocol(min(obj.Index,height(obj.Protocol)),:));
   elapsed=max(0,obj.LastClock-obj.StartTime);[target,phase]=myoProtocolTarget(row,elapsed);
   v=struct("index",min(obj.Index,height(obj.Protocol)),"count",height(obj.Protocol),"target",target, ...
    "phase",phase,"direction",row.direction,"elapsed",elapsed,"duration",row.duration_s,"status",obj.Status);
  end
 end
 methods (Access=private)
  function beginTrial(obj)
   % Solo al iniciar/reanudar se descarta el backlog externo al protocolo.
   % Entre trials no descartar paquetes acumulados durante el guardado.
   if obj.Status~="RUNNING"||obj.SkipBacklog,obj.Source.read();end
   obj.SkipBacklog=false;
   obj.StartTime=obj.Source.now();obj.LastClock=obj.StartTime;obj.LastRecovery=obj.StartTime;
   obj.Buffer=emptyMyoPacket();obj.TargetEvents=table();obj.Status="RUNNING";
   if obj.isBlockBreak()
    obj.SkipBacklog=true;
    row=table(obj.Index,obj.Protocol.block_id(obj.Index),obj.StartTime,NaN,60,NaN,"RUNNING", ...
     VariableNames={'protocol_index','block_id','start_source_time','end_source_time','planned_duration','observed_duration','status'});
    obj.BlockEvents=[obj.BlockEvents;row];obj.writeBlockEvents();
   else,obj.recordTarget();obj.snapshot();end
   obj.writeStatus();
  end
  function capture(obj)
   obj.LastClock=obj.Source.now();p=obj.Source.read();obj.LatestPacket=p;
   if obj.isBlockBreak(),return;end % Sólo live view; este intervalo no se guarda como RAW científico.
   % Preservar TODOS los samples del paquete. Los bordes de reloj ambiguos
   % se etiquetan OUTSIDE_STIMULUS_CLOCK; no recortar RAW por jitter de GUI.
   obj.Buffer=appendMyoPacket(obj.Buffer,p);obj.recordTarget();
  end
  function recordTarget(obj)
   v=obj.preview();r=table(obj.LastClock,obj.LastClock-obj.StartTime,v.target,v.phase, ...
    VariableNames=["source_time","trial_time","target","phase"]);
   obj.TargetEvents=[obj.TargetEvents;r];
  end
  function trial=current(obj,status)
   row=table2struct(obj.Protocol(obj.Index,:));
   duration=max(0,obj.LastClock-obj.StartTime);
   trial=makeMyoTrial(obj.Metadata,row,obj.Buffer,obj.TrialID,obj.StartTime,status,obj.TargetEvents,duration);
  end
  function snapshot(obj)
   if obj.isBlockBreak(),obj.LastRecovery=obj.LastClock;obj.writeStatus();return;end
   trial=obj.current("RECOVERY_PREFIX");validateMyoTrial(trial);
   folder=fullfile(obj.Directory,"recovery");temp=fullfile(folder,"active_"+string(java.util.UUID.randomUUID())+".tmp.mat");
   save(temp,"trial","-v7");d=load(temp,"trial");validateMyoTrial(d.trial);
   assert(isequaln(trial,d.trial),'MyoSave:RoundTrip','Recovery no supera validacion round-trip.');
   myoAtomicPromote(temp,fullfile(folder,"active_trial.mat"),true);obj.LastRecovery=obj.LastClock;
  end
  function saveCurrent(obj,status)
   if obj.isBlockBreak()
    if ~isempty(obj.BlockEvents)
     obj.BlockEvents.end_source_time(end)=obj.LastClock;
     obj.BlockEvents.observed_duration(end)=max(0,obj.LastClock-obj.StartTime);
     obj.BlockEvents.status(end)=string(status);obj.writeBlockEvents();
    end
    return
   end
   trial=obj.current(status);saveMyoTrialAtomic(obj.Directory,trial);obj.TrialID=obj.TrialID+1;
  end
  function yes=isBlockBreak(obj)
   yes=ismember('block_break',obj.Protocol.Properties.VariableNames)&&obj.Index<=height(obj.Protocol)&&obj.Protocol.block_break(obj.Index);
  end
  function writeBlockEvents(obj)
   temp=fullfile(obj.Directory,"block_events_"+string(java.util.UUID.randomUUID())+".tmp.csv");
   writetable(obj.BlockEvents,temp);persisted=readtable(temp,TextType='string');
   assert(height(obj.BlockEvents)==height(persisted),'MyoSave:RoundTrip','Conteo de eventos de bloque incorrecto.');
   for field=string(obj.BlockEvents.Properties.VariableNames)
    a=obj.BlockEvents.(field);b=persisted.(field);
    if isnumeric(a)
     assert(all((isnan(a)&isnan(b))|abs(a-b)<=1e-9),'MyoSave:RoundTrip','CSV de eventos de bloque inválido.');
    else,assert(isequal(a,b),'MyoSave:RoundTrip','Estado del evento de bloque inválido.');end
   end
   myoAtomicPromote(temp,fullfile(obj.Directory,'block_break_events.csv'),true);
  end
  function writeStatus(obj)
   myoWriteJSONAtomic(fullfile(obj.Directory,"session_status.json"),struct("status",obj.Status,"protocol_index",obj.Index,"next_trial_id",obj.TrialID, ...
    "protocol_complete",obj.Index>height(obj.Protocol),"last_error",obj.LastError));
  end
 end
end
