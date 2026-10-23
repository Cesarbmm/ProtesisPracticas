classdef MyoContinuousAcquisitionApp < handle
 % Una sola GUI de adquisicion RAW y practica sin escritura.
 properties (SetAccess=private)
  Figure
  Source
  Session=[]
  Timer=[]
  OutputRoot
  Protocol=[]
  QualityComplete=false
  QualityReport=struct()
  QualityIdentity=struct()
  QualityPacket
  Testing=false
  TestStart=0
  LivePacket
  Participant
  SessionID
  Placement
  Arm
  Note
  Repetitions
  HoldSeconds
  RestSeconds
  StatusLabel
  TargetLabel
  InstructionLabel
  DetailLabel
  PhaseLabel
  PracticeBanner
  GuideImage
  GuideFallback
  AssetRoot
  CurrentAsset=""
  QualityLabel
  TrialLabel
  EMGAxes
  EMGLines
  TargetPatch
  TargetAxes
  Buttons=struct()
  UIState="DESCONECTADO"
  PracticeActive=false
  PracticeProtocol=[]
  PracticeIndex=1
  PracticeElapsed=0
  PracticeClock=[]
  AutoTimer=true
  LastError=""
  Campaign=[]
  Registry=[]
  Reservation=[]
  ParticipantSummary
  SetupDialog=[]
  ConfirmParticipant
  ConfirmPlacement
  ConfirmPosture
  SetupConfirmation=[]
  CueEngine=[]
  SetupChecks=struct()
  QualityAssessment=[]
  QualityReviewAccepted=false
  QualityDialog=[]
 end
 methods
  function obj=MyoContinuousAcquisitionApp(o)
   arguments
    o.Source=[]
    o.OutputRoot (1,1) string = ""
    o.Protocol=[]
    o.Visible (1,1) string = "on"
    o.AutoTimer (1,1) logical = true
    o.AssetRoot (1,1) string = fullfile(fileparts(mfilename('fullpath')),'references')
    o.ParticipantID (1,1) string = "P001"
    o.SessionID (1,1) string = "S01"
    o.PlacementID (1,1) string = "P1"
    o.Campaign=[]
   end
   if isempty(o.Source),obj.Source=MyoMexDataSource();else,obj.Source=o.Source;end
   root=string(fileparts(fileparts(mfilename('fullpath'))));
   if o.OutputRoot=="",obj.OutputRoot=fullfile(root,'data_acquisition');else,obj.OutputRoot=o.OutputRoot;end
   obj.Campaign=o.Campaign;
   if ~isempty(obj.Campaign)
    obj.Registry=MyoParticipantRegistry(obj.OutputRoot);
    if isempty(o.Protocol),o.Protocol=obj.Campaign.protocol_builder(obj.Campaign.seed);end
    obj.CueEngine=MyoVisualCueEngine(obj.Campaign.asset_root);
   end
   obj.Protocol=o.Protocol;obj.AutoTimer=o.AutoTimer;obj.AssetRoot=o.AssetRoot;
   obj.LivePacket=emptyMyoPacket();obj.QualityPacket=emptyMyoPacket();obj.buildUI(o.Visible);
   if isempty(obj.Campaign)
    obj.Participant.Value=char(o.ParticipantID);obj.SessionID.Value=char(o.SessionID);
   else,obj.refreshParticipants(o.ParticipantID);end
   obj.Placement.Value=char(o.PlacementID);
   if obj.isOfficial()
    assert(string(o.PlacementID)=="P1",'MyoGUI:OfficialPlacement','La campaña oficial utiliza P1.');
    obj.Placement.Editable='off';obj.Placement.Tooltip=obj.Campaign.placement_description;
    obj.restorePendingSession();
   end
   if isa(obj.Source,'MockMyoDataSource'),obj.Figure.Name="SIMULACIÓN MYO · NO DATOS CIENTÍFICOS";end
   obj.setState("DESCONECTADO","Conectar Myo o ensayar con Práctica / Demo");
  end
  function connect(obj)
   assert(isempty(obj.Session)&&~obj.PracticeActive,'MyoGUI:SessionExists','Finalizar práctica o usar otra GUI para otra sesión.');
   obj.Source.connect();obj.QualityComplete=false;obj.Testing=false;
   obj.resetQualityReview();
   obj.setState("CONECTADO","Completar Test signal 30s");obj.showPlacementReminder();obj.ensureTimer();
  end
  function testSignal(obj)
   assert(isempty(obj.Session)&&~obj.PracticeActive,'MyoGUI:SessionExists','No iniciar diagnóstico durante sesión o práctica.');
   if ~isempty(obj.Campaign),obj.requireSetup();end
   obj.resetQualityReview();
   obj.showPlacementReminder();
   obj.Source.read();obj.TestStart=obj.Source.now();obj.QualityPacket=emptyMyoPacket();obj.QualityComplete=false;obj.Testing=true;
   obj.QualityIdentity=obj.identity();obj.setState("PRECHECK","Diagnóstico de 30 s: relajar y mover suavemente");obj.ensureTimer();
   if obj.isOfficial(),obj.renderPrecheck(0);end
  end
  function startSession(obj)
   assert(~obj.PracticeActive,'MyoGUI:PracticeActive','Detener práctica antes de adquirir.');
   if ~isempty(obj.Session)
    assert(obj.Session.Status=="PAUSED",'MyoGUI:SessionExists','La sesión no está en pausa.');
    obj.Session.start();obj.setState("CAPTURANDO","Trial reiniciado desde su comienzo");obj.ensureTimer();obj.updateTarget();return
   end
   assert(obj.QualityComplete,'MyoGUI:QualityRequired','Completar Test signal (30 s) antes de iniciar.');
   assert(~obj.isOfficial()||isempty(obj.QualityAssessment)||~obj.QualityAssessment.requires_review||obj.QualityReviewAccepted, ...
    'MyoGUI:QualityReviewRequired','Revisar los avisos del precheck antes de iniciar.');
   assert(isequaln(obj.QualityIdentity,obj.identity()),'MyoGUI:QualityContextChanged','Cambió participante/sesión/brazo/colocación/nota: repetir Test signal.');
   protocol=obj.activeProtocol();
   metadata=struct('participant_id',string(obj.Participant.Value),'session_id',string(obj.SessionID.Value), ...
    'placement_id',string(obj.Placement.Value),'arm',string(obj.Arm.Value),'placement_note',string(obj.Note.Value), ...
    'quality_precheck',obj.QualityReport,'quality_precheck_duration',30,'measured_aperture_provider','NONE');
   if ~isempty(obj.Campaign)
    obj.requireSetup();
    metadata.session_uuid=obj.Reservation.session_uuid;metadata.campaign_id=obj.Campaign.campaign_id;
    metadata.protocol_version=obj.Campaign.protocol_version;metadata.random_seed=obj.Protocol.randomization_seed(1);
    metadata.arm_posture_id=obj.Campaign.arm_posture_id;metadata.arm_posture_description=obj.Campaign.posture_description;
    metadata.posture_confirmed=true;metadata.participant_confirmed=true;metadata.placement_confirmed=true;
    metadata.posture_reference_asset=obj.Campaign.posture_reference_asset;
    metadata.posture_reference_sha256=obj.SetupConfirmation.posture_reference_sha256;
    metadata.posture_confirmation_utc=obj.SetupConfirmation.confirmed_utc;
    metadata.visual_cues_manifest_sha256=obj.CueEngine.ManifestHash;
    if obj.isOfficial()
     metadata.session_seed_source=obj.Reservation.seed_derivation;
     for field=["arm_confirmed","myo_fit_confirmed","myo_orientation_confirmed","stabilization_confirmed"]
      metadata.(field)=obj.SetupConfirmation.(field);
     end
     metadata.placement_definition=obj.Campaign.placement_description;
     metadata.quality_warnings_reviewed=obj.QualityReviewAccepted;
    end
   end
   obj.Session=MyoAcquisitionSession(obj.Source,obj.OutputRoot,metadata,protocol);
   if ~isempty(obj.CueEngine)
    temp=fullfile(obj.Session.Directory,'visual_cues_manifest.tmp.json');
    copyfile(fullfile(obj.CueEngine.Root,'cues_manifest.json'),temp);
    myoAtomicPromote(temp,fullfile(obj.Session.Directory,'visual_cues_manifest.json'),false);
   end
   qualityPacket=obj.QualityPacket;qualityReport=obj.QualityReport; %#ok<NASGU>
   save(fullfile(obj.Session.Directory,'quality_precheck.mat'),'qualityPacket','qualityReport','-v7');
   obj.lockMetadata();obj.Session.start();obj.setState("CAPTURANDO",metadata.participant_id+" / "+metadata.session_id+" / "+metadata.placement_id);
   obj.PracticeBanner.Text="CAPTURA ACTIVA — TARGET INSTRUIDO, NO APERTURA MEDIDA";
   obj.StatusLabel.Tooltip=obj.Session.Directory;obj.ensureTimer();obj.updateTarget();
  end
  function id=createParticipant(obj,alias,expected)
   arguments
    obj
    alias (1,1) string = ""
    expected (1,1) string = ""
   end
   obj.requireManagedIdle();
   if expected=="",expected=obj.Registry.nextID();end
   id=obj.Registry.create(expected,alias);obj.Reservation=[];obj.SessionID.Value='';obj.refreshParticipants(id);obj.contextChanged();
  end
  function selectParticipant(obj,id)
   obj.requireManagedIdle();
   assert(any(string(obj.Participant.ItemsData)==id),'MyoGUI:Participant','Seleccionar participante registrado.');
   obj.Participant.Value=char(id);obj.Reservation=[];obj.SessionID.Value='';obj.restorePendingSession();obj.refreshParticipantSummary();obj.contextChanged();
  end
  function newSession(obj)
   assert(~isempty(obj.Campaign)&&~obj.PracticeActive&&~obj.Testing,'MyoGUI:ManagedIdle','Detener práctica/precheck antes de reservar.');
   if ~isempty(obj.Session)
    assert(ismember(obj.Session.Status,["FINISHED","ABORTED","ERROR"]),'MyoGUI:SessionExists','Finalizar la sesión anterior.');
    obj.Session=[];obj.unlockMetadata();
   end
   id=string(obj.Participant.Value);obj.Reservation=obj.Registry.reserveSession(id,obj.Campaign.campaign_id);
   obj.adoptReservation();
   obj.refreshParticipantSummary();obj.setState("PREPARAR","Revisar identidad y postura antes del precheck");
  end
  function reviewSetup(obj)
   obj.requireManagedIdle();assert(~isempty(obj.Reservation),'MyoGUI:SessionRequired','Pulsar Nueva sesión primero.');
   if ~isempty(obj.SetupDialog)&&isvalid(obj.SetupDialog),delete(obj.SetupDialog);end
   if obj.isOfficial(),obj.buildOfficialSetup();return;end
   obj.SetupDialog=uifigure(Name='Confirmar identidad y postura',Position=[200 80 850 780],WindowStyle='modal');
   g=uigridlayout(obj.SetupDialog,[7 1]);g.RowHeight={110,'1x',45,28,28,28,40};
   text=sprintf('POSTURA REQUERIDA · %s\nPARTICIPANTE: %s · SESIÓN: %s\nCAMPAÑA: %s · BRAZO: %s · PLACEMENT: %s', ...
    obj.Campaign.arm_posture_id,obj.Participant.Value,obj.SessionID.Value,obj.Campaign.campaign_id,obj.Arm.Value,obj.Placement.Value);
   uilabel(g,Text=text,FontSize=17,FontWeight='bold',WordWrap='on');
   asset=obj.postureAsset();
   if isfile(asset),uiimage(g,ImageSource=asset,ScaleMethod='fit');
   else,uilabel(g,Text='FALTA LA REFERENCIA APROBADA. No se puede confirmar postura.',WordWrap='on');end
   uilabel(g,Text='Brazo y palma según imagen · muñeca neutra · Myo en placement indicado',WordWrap='on');
   obj.ConfirmParticipant=uicheckbox(g,Text='Participante correcto');
   obj.ConfirmPlacement=uicheckbox(g,Text='Myo colocado según referencia');
   obj.ConfirmPosture=uicheckbox(g,Text='Postura correcta');
   obj.SetupChecks=struct('participant',obj.ConfirmParticipant,'placement',obj.ConfirmPlacement,'posture',obj.ConfirmPosture);
   uibutton(g,Text='Confirmar preparación',ButtonPushedFcn=@(~,~)obj.guard(@()obj.confirmSetup()));
  end
  function confirmSetup(obj)
   obj.requireManagedIdle();
   assert(~isempty(obj.SetupDialog)&&isvalid(obj.SetupDialog),'MyoGUI:Confirmations','Abrir confirmación previa.');
   for field=string(fieldnames(obj.SetupChecks))'
    assert(obj.SetupChecks.(field).Value,'MyoGUI:Confirmations','Completar todas las verificaciones de identidad, colocación y postura.');
   end
   asset=obj.postureAsset();assert(isfile(asset),'MyoGUI:PostureAsset','Falta referencia aprobada de postura.');
   obj.Registry.verifyReservation(obj.Reservation);
   obj.CueEngine.verifyIntegrity();
   obj.SetupConfirmation=struct('identity',obj.identity(),'posture_reference_sha256',myoFileSHA256(asset), ...
    'confirmed_utc',string(datetime('now',TimeZone='UTC',Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")));
   if obj.isOfficial()
    assert(string(obj.Placement.Value)=="P1",'MyoGUI:OfficialPlacement','La campaña oficial utiliza P1.');
    obj.SetupConfirmation.arm_confirmed=true;obj.SetupConfirmation.myo_fit_confirmed=true;
    obj.SetupConfirmation.myo_orientation_confirmed=true;obj.SetupConfirmation.stabilization_confirmed=true;
   end
   delete(obj.SetupDialog);obj.SetupDialog=[];obj.setState("PREPARADO","Identidad y postura confirmadas; completar precheck");
  end
  function startPractice(obj)
   if obj.PracticeActive,obj.stopPractice();return;end
   assert(isempty(obj.Session)&&~obj.Testing,'MyoGUI:PracticeUnavailable','Práctica sólo sin sesión ni precheck activo.');
   if isempty(obj.Protocol)
    obj.PracticeProtocol=buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3,restSeconds=6);
   elseif obj.isPilot2()
    % Enseñar las ocho condiciones una vez; no repetir tres bloques de captura.
    active=obj.Protocol(obj.Protocol.condition=="MOVEMENT",:);seen=strings(0,1);chosen=[];
    for k=1:height(active)
     if ~any(seen==active.condition_id(k)),chosen(end+1)=k;seen(end+1)=active.condition_id(k);end %#ok<AGROW>
    end
    % Práctica pedagógica; no modifica el orden científico aleatorizado.
    active=active(chosen,:);active=sortrows(active,{'direction','movement_level'},{'descend','ascend'});
    rest=obj.Protocol(find(obj.Protocol.rest_intent,1),:);obj.PracticeProtocol=rest;
    for k=1:height(active),obj.PracticeProtocol=[obj.PracticeProtocol;active(k,:);rest];end
   else,obj.PracticeProtocol=obj.Protocol;end
   obj.PracticeIndex=1;obj.PracticeElapsed=0;obj.PracticeActive=true;obj.PracticeClock=tic;
   obj.PracticeBanner.Text="MODO PRÁCTICA — NO SE GUARDAN DATOS CIENTÍFICOS";
   obj.setState("PRÁCTICA","Aprende las instrucciones antes de iniciar");obj.updatePracticeTarget();obj.ensureTimer();
  end
  function advancePractice(obj,seconds)
   % Reloj visual propio; no usa MyoAcquisitionSession ni escribe archivos.
   assert(obj.PracticeActive,'MyoGUI:NoPractice','No hay práctica activa.');
   validateattributes(seconds,{'numeric'},{'scalar','finite','nonnegative'});
   obj.PracticeElapsed=obj.PracticeElapsed+seconds;
   while obj.PracticeElapsed>=obj.PracticeProtocol.duration_s(obj.PracticeIndex)
    obj.PracticeElapsed=obj.PracticeElapsed-obj.PracticeProtocol.duration_s(obj.PracticeIndex);
    obj.PracticeIndex=obj.PracticeIndex+1;
    if obj.PracticeIndex>height(obj.PracticeProtocol),obj.stopPractice();return;end
   end
   obj.updatePracticeTarget();
  end
  function stopPractice(obj)
   obj.PracticeActive=false;obj.PracticeClock=[];
   obj.PracticeBanner.Text="Práctica finalizada — no se guardaron datos científicos";
   obj.InstructionLabel.Text="PRÁCTICA FINALIZADA";
   if obj.Source.Connected
    if obj.QualityComplete,obj.setState("LISTO","Práctica terminada; iniciar cuando estés preparado");
    else,obj.setState("CONECTADO","Realizar Test signal 30s antes de iniciar");end
   else,obj.stopTimer();obj.setState("DESCONECTADO","Práctica terminada; conectar Myo para adquirir");end
  end
  function pauseSession(obj)
   assert(~isempty(obj.Session),'MyoGUI:NoSession','No hay sesión.');obj.Session.pause();
   if obj.Session.preview().phase=="BLOCK_BREAK",detail="Descanso pausado; no se guardó como trial científico";
   else,detail="Prefijo guardado; Iniciar / Seguir repite este trial desde el comienzo";end
   obj.setState("PAUSA",detail);
   obj.InstructionLabel.Text="PAUSA — RELAJA LA MANO";obj.PhaseLabel.Text="Tiempo detenido; no se completa el trial";
  end
  function repeatTrial(obj)
   assert(~isempty(obj.Session),'MyoGUI:NoSession','No hay sesión.');obj.Session.repeat();
   obj.setState("CAPTURANDO","Repetición en un archivo nuevo");obj.ensureTimer();obj.updateTarget();
  end
  function abortSession(obj)
   if obj.PracticeActive,obj.stopPractice();return;end
   if ~isempty(obj.Session),obj.Session.abort();detail="Sesión abortada; trials y prefijos conservados";
   else,detail="Diagnóstico abortado, sin sesión";end
   obj.Testing=false;obj.stopTimer();obj.Source.disconnect();obj.QualityComplete=false;
   obj.setState("FINALIZADO",detail);obj.InstructionLabel.Text="ADQUISICIÓN DETENIDA";
  end
  function finishSession(obj)
   if obj.PracticeActive,obj.stopPractice();end
   if isempty(obj.Session),detail="Diagnóstico finalizado, sin sesión";
   else
    obj.Session.finish();
    if obj.Session.Index>height(obj.Session.Protocol),detail="Sesión finalizada, datos guardados; protocolo completo";
    else,detail="Sesión finalizada, datos guardados; protocolo INCOMPLETO (conservar como piloto)";end
   end
   obj.Testing=false;obj.stopTimer();obj.Source.disconnect();obj.QualityComplete=false;
   obj.setState("FINALIZADO",detail);obj.InstructionLabel.Text="FINALIZADO — RELAJA LA MANO";
  end
  function pulse(obj)
   % Para tests deterministas; no avanza reloj del mock.
   if obj.PracticeActive,return;end
   if ~isempty(obj.Session) && obj.Session.Status=="RUNNING"
    obj.Session.tick();p=obj.Session.LatestPacket;obj.updateTarget();
   else,p=obj.Source.read();end
   obj.updateLive(p);
   if obj.Testing
    obj.QualityPacket=appendMyoPacket(obj.QualityPacket,p);elapsed=obj.Source.now()-obj.TestStart;
    obj.setState("PRECHECK",sprintf('Diagnóstico previo: %.1f / 30 s',min(elapsed,30)));
    if obj.isOfficial(),obj.renderPrecheck(elapsed);end
    if elapsed>=30
     obj.QualityReport=computeMyoQualityMetrics(obj.QualityPacket.time_emg,obj.QualityPacket.emg_raw,elapsed);
     obj.QualityReport.timestamp_provenance=obj.Source.info().timestamp_provenance;
     obj.QualityComplete=true;obj.Testing=false;
     obj.setState("LISTO","Precheck completo · avisos: "+obj.QualityReport.warning_count+" · revisar antes de iniciar");
     if obj.isOfficial()
      obj.QualityAssessment=myoPrecheckReview(obj.QualityReport);
      obj.QualityReviewAccepted=~obj.QualityAssessment.requires_review;
      if obj.QualityAssessment.has_errors,obj.QualityComplete=false;end
      if obj.QualityAssessment.requires_review
       obj.setState("REVISAR_SEÑAL","Avisos significativos: revisar antes de iniciar");
       obj.QualityLabel.Text="REVISAR SEÑAL · "+join(string(obj.QualityReport.warnings),", ");obj.QualityLabel.FontColor=[.8 .06 .06];
       obj.reviewQuality();
      else
       obj.InstructionLabel.Text="DIAGNÓSTICO COMPLETO";obj.DetailLabel.Text="Señal sin avisos significativos; revisar antes de iniciar";
      end
     end
    end
   end
   obj.updateButtons();
  end
  function reviewQuality(obj)
   assert(~isempty(obj.QualityAssessment),'MyoGUI:NoPrecheck','Completar precheck primero.');
   if ~isempty(obj.QualityDialog)&&isvalid(obj.QualityDialog),delete(obj.QualityDialog);end
   obj.QualityDialog=uifigure(Name='Revisión del diagnóstico de señal',Position=[200 130 700 450],WindowStyle='modal',Visible=obj.Figure.Visible);
   g=uigridlayout(obj.QualityDialog,[3 1]);g.RowHeight={40,'1x',40};
   uilabel(g,Text='AVISOS DEL PRECHECK · REVISAR ANTES DE CAPTURAR',FontWeight='bold',FontColor=[.8 .06 .06]);
   uitextarea(g,Value=splitlines(obj.QualityAssessment.message),Editable='off');
   b=uibutton(g,Text='He revisado canales, clipping y estabilidad; continuar',ButtonPushedFcn=@(~,~)obj.guard(@()obj.acceptQualityReview()));
   if obj.QualityAssessment.has_errors,b.Enable='off';b.Text='Errores de señal: repetir Test signal 30s';end
  end
  function acceptQualityReview(obj)
   assert(~isempty(obj.QualityAssessment)&&~obj.QualityAssessment.has_errors,'MyoGUI:QualityErrors','Corregir errores y repetir el precheck.');
   obj.QualityReviewAccepted=true;
   if ~isempty(obj.QualityDialog)&&isvalid(obj.QualityDialog),delete(obj.QualityDialog);end
   obj.QualityDialog=[];obj.setState("LISTO","Avisos revisados por el operador; puede iniciar o repetir precheck");
  end
  function delete(obj)
   obj.stopTimer();
   if ~isempty(obj.Session) && isvalid(obj.Session) && obj.Session.Status=="RUNNING"
    try,obj.Session.abort();catch ex,warning('MyoGUI:CloseSave','%s',ex.message);end
   end
   try,obj.Source.disconnect();catch,end
   if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end
   if ~isempty(obj.SetupDialog)&&isvalid(obj.SetupDialog),delete(obj.SetupDialog);end
   if ~isempty(obj.QualityDialog)&&isvalid(obj.QualityDialog),delete(obj.QualityDialog);end
  end
 end
 methods (Access=private)
  function buildUI(obj,visible)
   obj.Figure=uifigure(Name="Myo continuo · intención instruida / RAW",Position=[40 40 1250 930],Visible=visible, ...
    Resize='on',WindowStyle='normal',CloseRequestFcn=@(~,~)delete(obj));
   obj.Figure.WindowState='maximized';
   g=uigridlayout(obj.Figure,[8 1]);g.RowHeight={75,28,'2.2x','1x',44,30,44,25};g.Padding=[14 10 14 10];g.RowSpacing=5;
   if isempty(obj.Campaign)
   form=uigridlayout(g,[2 6]);form.Layout.Row=1;form.ColumnWidth={100,'1x',95,'1x',115,'1x'};
   uilabel(form,Text="Participante");obj.Participant=uieditfield(form,'text',Value='P001');
   uilabel(form,Text="Sesión");obj.SessionID=uieditfield(form,'text',Value='S01');
   uilabel(form,Text="Colocación");obj.Placement=uieditfield(form,'text',Value='P1');
   uilabel(form,Text="Brazo");obj.Arm=uidropdown(form,Items={'right','left'});
   uilabel(form,Text="Nota opcional");obj.Note=uieditfield(form,'text');obj.Note.Layout.Column=[4 6];
   else
    g.RowHeight={110,24,'3x','1x',34,24,36,28};
    form=uigridlayout(g,[3 6]);form.Layout.Row=1;form.ColumnWidth={95,'2x','1.2x','1x','1.4x','1.5x'};form.RowHeight={28,28,38};form.Padding=[0 0 0 0];form.RowSpacing=4;
    uilabel(form,Text='Participante');obj.Participant=uidropdown(form,Items={'Sin participantes'},ItemsData={''},Editable='off');
    obj.Buttons.NewParticipant=uibutton(form,Text='Nuevo participante',ButtonPushedFcn=@(~,~)obj.guard(@()obj.newParticipantDialog()));
    obj.SessionID=uieditfield(form,'text',Editable='off',Placeholder='Sin sesión');
    obj.Buttons.NewSession=uibutton(form,Text='Nueva sesión',ButtonPushedFcn=@(~,~)obj.guard(@()obj.newSession()));
    obj.Buttons.Review=uibutton(form,Text='Identidad / postura',ButtonPushedFcn=@(~,~)obj.guard(@()obj.reviewSetup()));
    uilabel(form,Text='Brazo');obj.Arm=uidropdown(form,Items={'right','left'});
    uilabel(form,Text='Placement');obj.Placement=uieditfield(form,'text',Value='P1');
    uilabel(form,Text='Nota opcional');obj.Note=uieditfield(form,'text');
    obj.ParticipantSummary=uilabel(form,Text='Seleccionar participante y reservar nueva sesión',WordWrap='on');obj.ParticipantSummary.Layout.Row=3;obj.ParticipantSummary.Layout.Column=[1 6];
   end
   obj.StatusLabel=uilabel(g,Text="DESCONECTADO",FontWeight='bold');obj.StatusLabel.Layout.Row=2;
   target=uigridlayout(g,[3 1]);target.Layout.Row=3;target.RowHeight={'1x',33,55};target.Padding=[0 0 0 0];
   main=uigridlayout(target,[1 2]);main.Layout.Row=1;main.ColumnWidth={'2x','1x'};main.Padding=[0 0 0 0];
   words=uigridlayout(main,[5 1]);words.RowHeight={24,'1x',58,25,20};words.Padding=[0 0 0 0];words.RowSpacing=4;
   obj.PracticeBanner=uilabel(words,Text="GUÍA VISUAL — NO ES APERTURA MEDIDA",HorizontalAlignment='center',FontWeight='bold',FontColor=[.65 .23 .02]);
   obj.InstructionLabel=uilabel(words,Text="PREPARA LA SESIÓN",FontSize=28,FontWeight='bold',HorizontalAlignment='center',WordWrap='on');
   obj.TargetLabel=uilabel(words,Text="—",FontSize=48,FontWeight='bold',HorizontalAlignment='center');
   obj.DetailLabel=uilabel(words,Text="El target indica qué hacer; no mide tu mano",HorizontalAlignment='center',FontSize=17,WordWrap='on');
   uilabel(words,Text="0 % cerrada · 100 % abierta · REST es relajación",HorizontalAlignment='center');
   if ~isempty(obj.Campaign)
    main.ColumnWidth={'1.2x','1x'};words.RowHeight={24,'1x',42,25,0};
    obj.InstructionLabel.FontSize=30;obj.TargetLabel.FontSize=34;
   end
   guide=uigridlayout(main,[2 1]);guide.RowHeight={'1x',28};guide.Padding=[0 0 0 0];
   obj.GuideImage=uiimage(guide,ScaleMethod='fit',Visible='off');obj.GuideImage.Layout.Row=1;
   obj.GuideFallback=uilabel(guide,Text="Sigue la instrucción y el porcentaje",WordWrap='on',FontSize=20,HorizontalAlignment='center');obj.GuideFallback.Layout.Row=1;
   uilabel(guide,Text="Imagen orientativa; REST no exige una postura",HorizontalAlignment='center',FontSize=11);
   obj.PhaseLabel=uilabel(target,Text="Sin trial activo",HorizontalAlignment='center',FontSize=21,FontWeight='bold');obj.PhaseLabel.Layout.Row=2;
   targetPlot=uipanel(target,BorderType='none');targetPlot.Layout.Row=3;
   obj.TargetAxes=uiaxes(targetPlot,Units='normalized',Position=[0 0 1 1]);obj.TargetAxes.XLim=[0 1];obj.TargetAxes.YLim=[0 1];obj.TargetAxes.YTick=[];
   obj.TargetAxes.XTick=0:.25:1;obj.TargetAxes.XTickLabel={'0%','25%','50%','75%','100%'};
   obj.TargetPatch=rectangle(obj.TargetAxes,Position=[0 .15 .0001 .7],FaceColor=[.10 .48 .73],EdgeColor='none');
   emgPanel=uigridlayout(g,[1 1]);emgPanel.Layout.Row=4;emgPanel.Padding=[0 0 0 0];
   obj.EMGAxes=uiaxes(emgPanel);obj.EMGAxes.Layout.Row=1;obj.EMGAxes.Layout.Column=1;
   hold(obj.EMGAxes,'on');obj.EMGLines=gobjects(1,8);
   for ch=1:8,obj.EMGLines(ch)=plot(obj.EMGAxes,NaN,NaN,DisplayName="CH"+ch,LineWidth=1);end
   obj.EMGAxes.YTick=(0:7)*2.6;obj.EMGAxes.YTickLabel=cellstr("CH"+(1:8));obj.EMGAxes.YLim=[-1.2 19.5];
   xlabel(obj.EMGAxes,'Tiempo fuente [s]');title(obj.EMGAxes,'8 canales EMG RAW · offsets sólo en pantalla');grid(obj.EMGAxes,'on');
   obj.QualityLabel=uilabel(g,Text="Diagnóstico pendiente",WordWrap='on');obj.QualityLabel.Layout.Row=5;
   settings=uigridlayout(g,[1 6]);settings.Layout.Row=6;settings.ColumnWidth={100,70,110,70,110,70};settings.Padding=[0 0 0 0];
   uilabel(settings,Text="Repeticiones");obj.Repetitions=uieditfield(settings,'numeric',Value=5,Limits=[1 20],RoundFractionalValues='on');
   uilabel(settings,Text="Hold [s]");obj.HoldSeconds=uieditfield(settings,'numeric',Value=4,Limits=[3 5]);
   uilabel(settings,Text="REST [s]");obj.RestSeconds=uieditfield(settings,'numeric',Value=6,Limits=[5 10]);
   if obj.isOfficial()
    settings.ColumnWidth={100,70,110,70,110,70,'1x'};
    obj.Buttons.QualityReview=uibutton(settings,Text='Revisar señal',ButtonPushedFcn=@(~,~)obj.guard(@()obj.reviewQuality()));
   end
   buttons=uigridlayout(g,[1 8]);buttons.Layout.Row=7;buttons.ColumnWidth=repmat({'1x'},1,8);
   if ~isempty(obj.Campaign),buttons.Padding=[0 0 0 0];buttons.ColumnSpacing=6;end
   names=["Conectar Myo","Test signal 30s","Práctica / Demo","Iniciar / Seguir","Pausa","Repetir trial","Abortar seguro","Finalizar"];
   keys=["Connect","Test","Practice","Start","Pause","Repeat","Abort","Finish"];
   calls={@()obj.connect(),@()obj.testSignal(),@()obj.startPractice(),@()obj.startSession(),@()obj.pauseSession(),@()obj.repeatTrial(),@()obj.abortSession(),@()obj.finishSession()};
   for k=1:8,fn=calls{k};obj.Buttons.(keys(k))=uibutton(buttons,Text=names(k),ButtonPushedFcn=@(~,~)obj.guard(fn));end
   obj.TrialLabel=uilabel(g,Text="Sin sesión · RAW separado por trial · no entrenamiento",HorizontalAlignment='center');obj.TrialLabel.Layout.Row=8;
   if ~isempty(obj.Protocol)
    controls={obj.Repetitions,obj.HoldSeconds,obj.RestSeconds};
    active=~obj.Protocol.rest_intent;if ismember('block_break',obj.Protocol.Properties.VariableNames),active=active&~obj.Protocol.block_break;end
    values={max(1,max(obj.Protocol.repetition)),unique(obj.Protocol.hold_s(active)),unique(obj.Protocol.hold_s(obj.Protocol.rest_intent))};
    for k=1:3
     control=controls{k};v=values{k};control.Enable='off';
     if ~isempty(v)
      control.Limits=[min(control.Limits(1),min(v)),max(control.Limits(2),max(v))];control.Value=v(1);
      if numel(v)>1,control.Tooltip="Protocolo con tiempos variables: consultar protocol.csv";end
     end
    end
   end
   controls={obj.Participant,obj.SessionID,obj.Placement,obj.Arm,obj.Note};
   for k=1:numel(controls),controls{k}.ValueChangedFcn=@(~,~)obj.contextChanged();end
   if ~isempty(obj.Campaign),obj.Participant.ValueChangedFcn=@(~,~)obj.guard(@()obj.selectParticipant(string(obj.Participant.Value)));end
  end
  function contextChanged(obj)
   if ~isempty(obj.Campaign)&&~isempty(obj.SetupConfirmation)&&~isequaln(obj.SetupConfirmation.identity,obj.identity())
    obj.SetupConfirmation=[];
   end
   if isempty(obj.Session)&&obj.QualityComplete&&~isequaln(obj.QualityIdentity,obj.identity())
    obj.QualityComplete=false;obj.setState("CONECTADO","Cambió la identidad/colocación: repetir precheck");
   end
   obj.updateButtons();
  end
  function setState(obj,state,detail)
   obj.UIState=state;obj.StatusLabel.Text=state+" · "+string(detail);obj.updateButtons();
  end
  function updateButtons(obj)
   free=isempty(obj.Session);connected=obj.Source.Connected;practice=obj.PracticeActive;
   ready=free&&connected&&obj.QualityComplete&&~obj.Testing&&isequaln(obj.QualityIdentity,obj.identity());
   setup=true;if ~isempty(obj.Campaign),setup=obj.setupReady();ready=ready&&setup;end
   if obj.isOfficial()&&~isempty(obj.QualityAssessment)
    ready=ready&&~obj.QualityAssessment.has_errors&&(~obj.QualityAssessment.requires_review||obj.QualityReviewAccepted);
    obj.Buttons.QualityReview.Enable=matlab.lang.OnOffSwitchState(free&&~practice&&~obj.Testing);
   elseif isfield(obj.Buttons,'QualityReview'),obj.Buttons.QualityReview.Enable='off';end
   paused=~free&&obj.Session.Status=="PAUSED";running=~free&&obj.Session.Status=="RUNNING";
   repeatAllowed=connected&&~free&&ismember(obj.Session.Status,["RUNNING","PAUSED","FINISHED"]);
   if ~free&&obj.isPilot2(),repeatAllowed=repeatAllowed&&obj.Session.preview().phase~="BLOCK_BREAK";end
   enabled=[free&&~connected&&~practice,free&&connected&&~obj.Testing&&~practice&&setup,free&&~obj.Testing, ...
    ~practice&&(ready||paused),running,repeatAllowed,connected||practice||~free,true];
   keys=["Connect","Test","Practice","Start","Pause","Repeat","Abort","Finish"];
   for k=1:numel(keys),if enabled(k),obj.Buttons.(keys(k)).Enable='on';else,obj.Buttons.(keys(k)).Enable='off';end,end
   if practice,obj.Buttons.Practice.Text="Terminar práctica";else,obj.Buttons.Practice.Text="Práctica / Demo";end
   if ~isempty(obj.Campaign)
    finished=~free&&ismember(obj.Session.Status,["FINISHED","ABORTED","ERROR"]);idle=(free||finished)&&~practice&&~obj.Testing;
    obj.Buttons.NewParticipant.Enable=matlab.lang.OnOffSwitchState(idle);obj.Participant.Enable=matlab.lang.OnOffSwitchState(idle);
    obj.Buttons.NewSession.Enable=matlab.lang.OnOffSwitchState(idle&&strlength(string(obj.Participant.Value))>0);
    obj.Buttons.Review.Enable=matlab.lang.OnOffSwitchState(free&&~practice&&~obj.Testing&&~isempty(obj.Reservation));
   end
  end
  function protocol=activeProtocol(obj)
   protocol=obj.Protocol;
   if isempty(protocol),protocol=buildMyoContinuousProtocol(repetitions=obj.Repetitions.Value,holdSeconds=obj.HoldSeconds.Value,restSeconds=obj.RestSeconds.Value);end
  end
  function yes=isPilot2(obj)
   yes=~isempty(obj.Protocol)&&ismember('campaign',obj.Protocol.Properties.VariableNames)&&all(obj.Protocol.campaign=="MYO_PILOT2_OPEN_CLOSE");
  end
  function yes=isOfficial(obj)
   yes=~isempty(obj.Campaign)&&isfield(obj.Campaign,'official_placement_checklist')&&obj.Campaign.official_placement_checklist;
  end
  function adoptReservation(obj)
   obj.SessionID.Value=char(obj.Reservation.session_id);
   if isfield(obj.Campaign,'session_randomization')&&obj.Campaign.session_randomization
    obj.Protocol=obj.Campaign.protocol_builder(obj.Reservation.random_seed);
   end
   obj.SetupConfirmation=[];obj.QualityComplete=false;obj.resetQualityReview();
  end
  function restorePendingSession(obj)
   if ~obj.isOfficial()||strlength(string(obj.Participant.Value))==0,return;end
   pending=obj.Registry.pendingSession(string(obj.Participant.Value),obj.Campaign.campaign_id);
   if ~isempty(pending),obj.Reservation=pending;obj.adoptReservation();end
  end
  function resetQualityReview(obj)
   obj.QualityAssessment=[];obj.QualityReviewAccepted=false;
   if ~isempty(obj.QualityDialog)&&isvalid(obj.QualityDialog),delete(obj.QualityDialog);end
   obj.QualityDialog=[];obj.QualityLabel.FontColor=[.15 .15 .15];
  end
  function renderPrecheck(obj,elapsed)
   obj.InstructionLabel.Text="DIAGNÓSTICO DE SEÑAL";obj.InstructionLabel.FontColor=[.10 .10 .10];
   obj.DetailLabel.Text=myoPrecheckInstruction(elapsed);obj.TargetLabel.Text="30 s";
   obj.PhaseLabel.Text=compose('PRECHECK · %.1f s restantes',max(0,30-elapsed));
   obj.PhaseLabel.FontColor=[.10 .10 .10];obj.TargetPatch.Position=[0 .15 .0001 .7];
   obj.GuideImage.Visible='off';obj.GuideFallback.Visible='on';obj.GuideFallback.Text="Reposo → apertura cómoda → cierre cómodo → reposo";
   obj.PracticeBanner.Text="PRECHECK — NO ES UN TRIAL CIENTÍFICO";
  end
  function buildOfficialSetup(obj)
   obj.SetupDialog=uifigure(Name='Identidad / postura oficial y colocación Myo', ...
    Position=[120 35 1000 700],WindowStyle='modal',Visible=obj.Figure.Visible);
   g=uigridlayout(obj.SetupDialog,[5 1]);g.RowHeight={82,205,24,'1x',36};g.Padding=[12 10 12 10];g.RowSpacing=6;
   text=sprintf('POSTURA OFICIAL · %s\nPARTICIPANTE: %s · SESIÓN: %s · BRAZO: %s · PLACEMENT: %s\nCAMPAÑA: %s', ...
    obj.Campaign.arm_posture_id,obj.Participant.Value,obj.SessionID.Value,obj.Arm.Value,obj.Placement.Value,obj.Campaign.campaign_id);
   uilabel(g,Text=text,FontSize=17,FontWeight='bold',WordWrap='on');
   visual=uigridlayout(g,[1 2]);visual.Padding=[0 0 0 0];visual.ColumnWidth={'1x','1.6x'};
   asset=obj.postureAsset();
   if isfile(asset),uiimage(visual,ImageSource=asset,ScaleMethod='fit');
   else,uilabel(visual,Text='FALTA LA REFERENCIA APROBADA. No se puede confirmar postura.',WordWrap='on');end
   instructions=["COLOCACIÓN DEL MYO", ...
    "1. Aproximadamente DOS DEDOS por debajo del codo.", ...
    "2. Directamente sobre la piel limpia y seca.", ...
    "3. Usar clips/pinzas adecuados al diámetro del antebrazo.", ...
    "4. Ocho sensores en contacto firme y estable con la piel.", ...
    "5. Ajustado, sin comprimir excesivamente el brazo.", ...
    "6. Mantener siempre la misma orientación.", ...
    "7. Tapa/puerto de carga hacia el EXTERIOR del brazo.", ...
    "8. NO rotar ni reajustar durante la sesión."];
   uitextarea(visual,Value=instructions',Editable='off',FontSize=13);
   uilabel(g,Text='Sentado, espalda apoyada, antebrazo natural; mano libre. Confirmación física del operador.',FontWeight='bold');
   checks=uigridlayout(g,[10 1]);checks.RowHeight=repmat({22},1,10);checks.RowSpacing=1;checks.Padding=[0 0 0 0];checks.Scrollable='on';
   keys=["participant","arm","location","orientation","fit","contact","stabilization","elbow","wrist","posture"];
   labels=["Participante correcto","Brazo correcto","Myo aproximadamente dos dedos debajo del codo", ...
    "Tapa/puerto de carga orientado hacia el exterior del brazo","Clips de ajuste colocados correctamente", ...
    "Los 8 sensores mantienen contacto firme con la piel","Myo colocado, ajustado y estabilizado antes del precheck", ...
    "Codo apoyado en el reposabrazos","Muñeca en posición neutra","Postura coincide con la imagen de referencia"];
   obj.SetupChecks=struct();
   for k=1:numel(keys),obj.SetupChecks.(keys(k))=uicheckbox(checks,Text=labels(k));end
   obj.ConfirmParticipant=obj.SetupChecks.participant;obj.ConfirmPlacement=obj.SetupChecks.location;obj.ConfirmPosture=obj.SetupChecks.posture;
   uibutton(g,Text='Confirmar identidad, colocación y postura',ButtonPushedFcn=@(~,~)obj.guard(@()obj.confirmSetup()));
  end
  function showPlacementReminder(obj)
   if ~isempty(obj.Campaign)
    obj.InstructionLabel.Text="PREPARA LA SESIÓN";obj.DetailLabel.Text="Revisa identidad y postura antes del precheck";
    obj.PhaseLabel.Text=obj.Campaign.arm_posture_id;return
   end
   if obj.isPilot2()
    obj.InstructionLabel.Text="COLOCACIÓN A CARGO DEL OPERADOR";
    obj.DetailLabel.Text="Nota opcional; no cambies la colocación durante S04";
    obj.PhaseLabel.Text="P0_NEUTRAL_90 · codo 90° · muñeca neutra";
   end
  end
  function lockMetadata(obj)
   controls={obj.Participant,obj.SessionID,obj.Placement,obj.Arm,obj.Note,obj.Repetitions,obj.HoldSeconds,obj.RestSeconds};
   for k=1:numel(controls),controls{k}.Enable='off';end
  end
  function unlockMetadata(obj)
   controls={obj.Participant,obj.Placement,obj.Arm,obj.Note};
   for k=1:numel(controls),controls{k}.Enable='on';end
  end
  function requireManagedIdle(obj)
   assert(~isempty(obj.Campaign)&&~obj.PracticeActive&&~obj.Testing,'MyoGUI:ManagedIdle','No disponible durante práctica/precheck.');
   if ~isempty(obj.Session)
    assert(ismember(obj.Session.Status,["FINISHED","ABORTED","ERROR"]),'MyoGUI:SessionExists','Finalizar la captura anterior.');
    obj.Session=[];obj.unlockMetadata();
   end
  end
  function refreshParticipants(obj,preferred)
   rows=obj.Registry.list();active=ismember(rows.status,["active","legacy"]);rows=rows(active,:);
   labels=strings(height(rows),1);
   for k=1:height(rows)
    info=obj.Registry.describe(rows.participant_id(k));alias="";
    if info.optional_alias~="",alias=" · "+info.optional_alias;end
    labels(k)=info.participant_id+alias+compose(' · %d sesiones',info.session_count);
   end
   if isempty(labels),obj.Participant.Items={'Sin participantes'};obj.Participant.ItemsData={''};obj.Participant.Value='';
   else
    obj.Participant.Items=cellstr(labels);obj.Participant.ItemsData=cellstr(rows.participant_id);
    if any(rows.participant_id==preferred),obj.Participant.Value=char(preferred);else,obj.Participant.Value=char(rows.participant_id(1));end
   end
   obj.refreshParticipantSummary();
  end
  function refreshParticipantSummary(obj)
   id=string(obj.Participant.Value);
   if id=="",obj.ParticipantSummary.Text="Sin participante · práctica disponible sin crear identidad";return;end
   info=obj.Registry.describe(id);
   obj.ParticipantSummary.Text=sprintf('%s · %s · %d sesiones · última: %s · placement previo: %s (referencia)\nCampaña %s · postura %s', ...
    id,info.optional_alias,info.session_count,info.last_session_utc,info.previous_placement,obj.Campaign.campaign_id,obj.Campaign.arm_posture_id);
  end
  function newParticipantDialog(obj)
   obj.requireManagedIdle();id=obj.Registry.nextID();
   d=uifigure(Name='Nueva persona · ID automático',Position=[300 250 500 240],WindowStyle='modal');
   g=uigridlayout(d,[4 1]);g.RowHeight={45,30,35,35};
   uilabel(g,Text="ID reservado al confirmar: "+id,FontSize=20,FontWeight='bold');
   uilabel(g,Text='Alias opcional. No se solicita nombre real.');alias=uieditfield(g,'text');
   uibutton(g,Text="Crear "+id,ButtonPushedFcn=@(~,~)obj.guard(@()create()));
   function create()
    obj.createParticipant(string(alias.Value),id);delete(d);
   end
  end
  function asset=postureAsset(obj)
   asset=myoPostureAssetPath(obj.Campaign.posture_reference_asset,obj.Campaign.asset_root);
  end
  function yes=setupReady(obj)
   yes=~isempty(obj.Reservation)&&~isempty(obj.SetupConfirmation)&&isequaln(obj.SetupConfirmation.identity,obj.identity());
  end
  function requireSetup(obj)
   assert(obj.setupReady(),'MyoGUI:SetupRequired','Confirmar participante, Myo y postura antes del precheck/inicio.');
   assert(isfile(obj.postureAsset())&&myoFileSHA256(obj.postureAsset())==obj.SetupConfirmation.posture_reference_sha256, ...
    'MyoGUI:PostureAsset','Referencia de postura ausente o modificada; volver a confirmar.');
   obj.CueEngine.verifyIntegrity();
  end
  function m=identity(obj)
   m=struct('participant',string(obj.Participant.Value),'session',string(obj.SessionID.Value),'placement',string(obj.Placement.Value),'arm',string(obj.Arm.Value),'note',string(obj.Note.Value));
   if ~isempty(obj.Campaign)
    m.campaign_id=obj.Campaign.campaign_id;m.arm_posture_id=obj.Campaign.arm_posture_id;m.session_uuid="";
    if ~isempty(obj.Reservation),m.session_uuid=obj.Reservation.session_uuid;end
    if obj.isOfficial(),m.random_seed=obj.Protocol.randomization_seed(1);end
   end
  end
  function ensureTimer(obj)
   if obj.AutoTimer && (isempty(obj.Timer)||~isvalid(obj.Timer))
    obj.Timer=timer(ExecutionMode='fixedSpacing',Period=.05,BusyMode='drop',TimerFcn=@(~,~)obj.onTimer(),ErrorFcn=@(~,~)obj.timerFailure());start(obj.Timer);
   end
  end
  function onTimer(obj)
   if obj.PracticeActive
    elapsed=toc(obj.PracticeClock);obj.PracticeClock=tic;obj.guard(@()obj.advancePractice(elapsed));return
   end
   if isa(obj.Source,'MockMyoDataSource')&&obj.Source.Connected,obj.Source.advance(.05);end
   obj.guard(@()obj.pulse());
  end
  function guard(obj,fn)
   try,fn();catch ex
    obj.LastError=string(getReport(ex,'extended','hyperlinks','off'));
    if ~isempty(obj.Session)&&obj.Session.Status=="RUNNING"
     try,obj.Session.abort();catch saveError,obj.LastError=obj.LastError+newline+string(saveError.message);end
    end
    obj.stopTimer();obj.Testing=false;obj.setState("ERROR",string(ex.message));warning('MyoGUI:Operation','%s',ex.message);
   end
  end
  function timerFailure(obj)
   obj.stopTimer();
   if ~isempty(obj.Session)&&obj.Session.Status=="RUNNING"
    try,obj.Session.abort();catch ex,obj.LastError=string(getReport(ex,'extended','hyperlinks','off'));end
   end
   obj.setState("ERROR","Timer detenido; conservar archivos y revisar diagnóstico");
  end
  function stopTimer(obj)
   if ~isempty(obj.Timer)&&isvalid(obj.Timer),stop(obj.Timer);delete(obj.Timer);end
   obj.Timer=[];
  end
  function updateTarget(obj)
   v=obj.Session.preview();row=table2struct(obj.Session.Protocol(v.index,:));obj.renderTarget(row,v.elapsed);
   obj.TrialLabel.Text=sprintf('Trial %d / %d · %s · target instruido, no medido',v.index,v.count,v.status);
   if obj.isPilot2()
    p=obj.Session.Protocol;active=p.condition=="MOVEMENT";scientific=p.is_scientific_trial;
    movement=sum(active(1:v.index));trial=sum(scientific(1:v.index));
    obj.TrialLabel.Text=sprintf('BLOQUE %d/%d · TRIAL %d/%d · registro %d/%d · %s',row.block_id,max(p.block_id),movement,sum(active),trial,sum(scientific),v.status);
    if v.status=="RUNNING"
     if row.block_break
      obj.setState("DESCANSO_BLOQUE","Sin RAW científico ni MAT de trial");obj.PracticeBanner.Text="DESCANSO DE BLOQUE — NO SE GUARDAN DATOS CIENTÍFICOS";
     else
      posture="P0_NEUTRAL_90";if ~isempty(obj.Campaign),posture=obj.Campaign.arm_posture_id;end
      obj.setState("CAPTURANDO",posture+" · mantener colocación durante la sesión");obj.PracticeBanner.Text="CAPTURA ACTIVA — TARGET INSTRUIDO, NO APERTURA MEDIDA";
     end
    end
   end
   if v.status=="FINISHED"
    obj.setState("FINALIZADO","Protocolo completo; trials guardados");obj.InstructionLabel.Text="PROTOCOLO COMPLETO — RELAJA LA MANO";
   end
  end
  function updatePracticeTarget(obj)
   row=table2struct(obj.PracticeProtocol(obj.PracticeIndex,:));obj.renderTarget(row,obj.PracticeElapsed);
   obj.TrialLabel.Text=sprintf('PRÁCTICA · trial %d / %d · sin escritura',obj.PracticeIndex,height(obj.PracticeProtocol));
   if obj.isPilot2()
    count=sum(obj.PracticeProtocol.condition(1:obj.PracticeIndex)=="MOVEMENT");
    obj.TrialLabel.Text=sprintf('PRÁCTICA · movimiento %d / %d · sin escritura',count,sum(obj.PracticeProtocol.condition=="MOVEMENT"));
   end
  end
  function renderTarget(obj,row,elapsed)
   if isempty(obj.CueEngine),v=myoParticipantInstruction(row,elapsed);else,v=obj.CueEngine.cue(row,elapsed);end
   obj.InstructionLabel.Text=v.instruction;obj.DetailLabel.Text=v.detail;
   if v.phase=="PREPARE",cueColor=[.80 .06 .06];else,cueColor=[.10 .10 .10];end
   obj.InstructionLabel.FontColor=cueColor;obj.PhaseLabel.FontColor=cueColor;
   if isnan(v.target),obj.TargetLabel.Text=v.phase;width=.0001;color=[.65 .65 .65];
   else,obj.TargetLabel.Text=sprintf('%.0f %%',100*v.target);width=max(.0001,v.target);color=[.10 .48 .73];end
   if v.phase=="BLOCK_BREAK",obj.TargetLabel.Text=sprintf('%.0f s',ceil(v.remaining));end
   if v.phase=="RELEASE",obj.TargetLabel.Text="—";end
   if isfield(v,'participant_level')&&isfinite(v.participant_level)
    if v.phase~="RELEASE",obj.TargetLabel.Text=sprintf('%s %.0f %%',v.participant_direction,v.participant_level);end
   end
   obj.TargetPatch.Position=[0 .15 width .7];obj.TargetPatch.FaceColor=color;
   obj.PhaseLabel.Text=sprintf('%s · quedan %.1f s',v.phase,v.remaining);
   if isfield(v,'participant_level')&&isfinite(v.participant_level)
    obj.PhaseLabel.Text=sprintf('%s %.0f %% · %s · quedan %.1f s',v.participant_direction,v.participant_level,v.phase,v.remaining);
   end
   if isempty(obj.CueEngine),asset=fullfile(obj.AssetRoot,v.asset);else,asset=v.asset;end
   % La imagen de transición aportada indica apertura; no usar su flecha en cierre.
   if v.phase=="RAMP"&&string(row.direction)=="closing",asset="";end
   if v.asset~=""&&isfile(asset)
    if obj.CurrentAsset~=asset
     try,obj.GuideImage.ImageSource=asset;obj.CurrentAsset=asset;
     catch,obj.CurrentAsset="";end
    end
    if obj.CurrentAsset==asset,obj.GuideImage.Visible='on';obj.GuideFallback.Visible='off';return;end
   end
   obj.GuideImage.Visible='off';obj.GuideFallback.Visible='on';obj.GuideFallback.Text=v.instruction+newline+v.detail;
  end
  function updateLive(obj,p)
   obj.LivePacket=appendMyoPacket(obj.LivePacket,p);
   if isempty(obj.LivePacket.time_emg),return;end
   finish=obj.LivePacket.time_emg(end);e=obj.LivePacket.time_emg>=finish-2;
   for f=["time_emg","emg_raw","arrival_emg"],obj.LivePacket.(f)=obj.LivePacket.(f)(e,:);end
   i=obj.LivePacket.time_imu>=finish-2;for f=["time_imu","quat","gyro","accel","pose","arrival_imu"],obj.LivePacket.(f)=obj.LivePacket.(f)(i,:);end
   for ch=1:8,set(obj.EMGLines(ch),XData=obj.LivePacket.time_emg,YData=obj.LivePacket.emg_raw(:,ch)+(ch-1)*2.6);end
   obj.EMGAxes.XLim=[max(0,finish-2) max(.1,finish)];
   q=computeMyoQualityMetrics(obj.LivePacket.time_emg,obj.LivePacket.emg_raw);
   flat="ninguno";if ~isempty(q.flat_channels),flat=join("CH"+q.flat_channels,", ");end
   obj.QualityLabel.Text=sprintf('Fs por timestamps: %.1f Hz (Myo: reconstruidos) | planos: %s | clip max: %.2f%% | RMS: %.3f | MAV: %.3f\nGaps nominales estimados: %.0f; dropout NO certificado; filas repetidas: %.2f%%. RAW sin offset.', ...
    q.actual_emg_fs,flat,100*max(q.clipping_fraction),mean(q.rms),mean(q.mav),q.estimated_dropped_samples_timestamp,100*q.identical_consecutive_row_fraction);
  end
 end
end
