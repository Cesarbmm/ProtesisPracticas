classdef MyoContinuousAcquisitionApp < handle
 % GUI de adquisicion RAW. El constructor no conecta al Myo.
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
  PhaseLabel
  QualityLabel
  TrialLabel
  EMGAxes
  EMGLines
  TargetPatch
  TargetAxes
  AutoTimer=true
  LastError=""
 end
 methods
  function obj=MyoContinuousAcquisitionApp(o)
   arguments
    o.Source=[]
    o.OutputRoot (1,1) string = ""
    o.Protocol=[]
    o.Visible (1,1) string = "on"
    o.AutoTimer (1,1) logical = true
   end
   if isempty(o.Source),obj.Source=MyoMexDataSource();else,obj.Source=o.Source;end
   root=string(fileparts(fileparts(mfilename("fullpath"))));
   if o.OutputRoot=="",obj.OutputRoot=fullfile(root,"data_acquisition");else,obj.OutputRoot=o.OutputRoot;end
   obj.Protocol=o.Protocol;obj.AutoTimer=o.AutoTimer;obj.LivePacket=emptyMyoPacket();obj.QualityPacket=emptyMyoPacket();
   obj.buildUI(o.Visible);
   if isa(obj.Source,'MockMyoDataSource'),obj.Figure.Name="SIMULACION MYO · NO DATOS CIENTIFICOS";end
  end
  function connect(obj)
   assert(isempty(obj.Session),"MyoGUI:SessionExists","Cerrar esta GUI para crear otra sesion.");
   obj.Source.connect();obj.QualityComplete=false;obj.StatusLabel.Text="Conectado · completar diagnostico de 30 s";
   if obj.AutoTimer
    obj.Timer=timer(ExecutionMode='fixedSpacing',Period=.05,BusyMode='drop',TimerFcn=@(~,~)obj.onTimer(),ErrorFcn=@(~,~)obj.timerFailure());
    start(obj.Timer);
   end
  end
  function testSignal(obj)
   assert(isempty(obj.Session),"MyoGUI:SessionExists","Datos o estado incompatibles con MyoGUI:SessionExists.");
   obj.Source.read();obj.TestStart=obj.Source.now();obj.QualityPacket=emptyMyoPacket();obj.QualityComplete=false;obj.Testing=true;
   obj.QualityIdentity=obj.identity();
   obj.StatusLabel.Text="Diagnostico de 30 s: relajar y mover suavemente; no se mide apertura";
  end
  function startSession(obj)
   if ~isempty(obj.Session)
    assert(obj.Session.Status=="PAUSED","MyoGUI:SessionExists","Datos o estado incompatibles con MyoGUI:SessionExists.");obj.Session.start();return;
   end
   assert(obj.QualityComplete,"MyoGUI:QualityRequired","Completar Test signal (30 s) antes de iniciar.");
   assert(isequaln(obj.QualityIdentity,obj.identity()),"MyoGUI:QualityContextChanged","Cambio participante/sesion/brazo/colocacion/nota: repetir Test signal.");
   protocol=obj.Protocol;
   if isempty(protocol)
    protocol=buildMyoContinuousProtocol(repetitions=obj.Repetitions.Value,holdSeconds=obj.HoldSeconds.Value,restSeconds=obj.RestSeconds.Value);
   end
   metadata=struct("participant_id",string(obj.Participant.Value),"session_id",string(obj.SessionID.Value), ...
    "placement_id",string(obj.Placement.Value),"arm",string(obj.Arm.Value),"placement_note",string(obj.Note.Value), ...
    "quality_precheck",obj.QualityReport,"quality_precheck_duration",30,"measured_aperture_provider","NONE");
   obj.Session=MyoAcquisitionSession(obj.Source,obj.OutputRoot,metadata,protocol);
   qualityPacket=obj.QualityPacket;qualityReport=obj.QualityReport; %#ok<NASGU>
   save(fullfile(obj.Session.Directory,"quality_precheck.mat"),"qualityPacket","qualityReport","-v7");
   obj.lockMetadata();obj.Session.start();obj.StatusLabel.Text="Capturando RAW · "+metadata.participant_id+" / "+metadata.session_id+" / "+metadata.placement_id+" · "+obj.Source.info().source;
   obj.StatusLabel.Tooltip=obj.Session.Directory;obj.updateTarget();
  end
  function pauseSession(obj)
   assert(~isempty(obj.Session),"MyoGUI:NoSession","Datos o estado incompatibles con MyoGUI:NoSession.");obj.Session.pause();obj.StatusLabel.Text="PAUSA: prefijo guardado. Iniciar repite este trial desde el comienzo.";
  end
  function repeatTrial(obj)
   assert(~isempty(obj.Session),"MyoGUI:NoSession","Datos o estado incompatibles con MyoGUI:NoSession.");obj.Session.repeat();obj.updateTarget();
  end
  function abortSession(obj)
   if ~isempty(obj.Session),obj.Session.abort();end
   obj.Testing=false;obj.StatusLabel.Text="ABORTADO: trials y prefijo preservados";obj.stopTimer();
  end
  function finishSession(obj)
   if ~isempty(obj.Session),obj.Session.finish();end
   obj.Testing=false;obj.StatusLabel.Text="FINALIZADO: datos guardados";obj.stopTimer();obj.Source.disconnect();
  end
  function pulse(obj)
   % Publico para pruebas deterministas con reloj mock; no avanza el reloj.
   if ~isempty(obj.Session) && obj.Session.Status=="RUNNING"
    obj.Session.tick();p=obj.Session.LatestPacket;obj.updateTarget();
   else
    p=obj.Source.read();
   end
   obj.updateLive(p);
   if obj.Testing
    obj.QualityPacket=appendMyoPacket(obj.QualityPacket,p);elapsed=obj.Source.now()-obj.TestStart;
    obj.StatusLabel.Text=sprintf('Diagnostico previo: %.1f / 30 s',min(elapsed,30));
    if elapsed>=30
     obj.QualityReport=computeMyoQualityMetrics(obj.QualityPacket.time_emg,obj.QualityPacket.emg_raw,elapsed);
     obj.QualityReport.timestamp_provenance=obj.Source.info().timestamp_provenance;
     obj.QualityComplete=true;obj.Testing=false;
     obj.StatusLabel.Text="Diagnostico completo · avisos: "+obj.QualityReport.warning_count+" · listo para iniciar";
    end
   end
  end
  function delete(obj)
   obj.stopTimer();
   if ~isempty(obj.Session) && isvalid(obj.Session) && obj.Session.Status=="RUNNING"
    try,obj.Session.abort();catch ex,warning('MyoGUI:CloseSave','%s',ex.message);end
   end
   try,obj.Source.disconnect();catch,end
   if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end
  end
 end
 methods (Access=private)
  function buildUI(obj,visible)
   obj.Figure=uifigure(Name="Myo continuo · intencion instruida / RAW",Position=[60 40 1250 930],Visible=visible,CloseRequestFcn=@(~,~)delete(obj));
   g=uigridlayout(obj.Figure,[8 1]);g.RowHeight={90,27,180,'1x',55,35,42,25};g.Padding=[14 12 14 12];
   form=uigridlayout(g,[2 6]);form.Layout.Row=1;form.ColumnWidth={120,'1x',120,'1x',130,'1x'};
   uilabel(form,Text="Participante");obj.Participant=uieditfield(form,'text',Value='P001');
   uilabel(form,Text="Sesion");obj.SessionID=uieditfield(form,'text',Value='S01');
   uilabel(form,Text="Colocacion");obj.Placement=uieditfield(form,'text',Value='P1');
   uilabel(form,Text="Brazo");obj.Arm=uidropdown(form,Items={'right','left'});
   uilabel(form,Text="Orientacion / nota");obj.Note=uieditfield(form,'text');obj.Note.Layout.Column=[4 6];
   obj.StatusLabel=uilabel(g,Text="Desconectado · no hay medicion de apertura",FontWeight='bold');
   obj.StatusLabel.Layout.Row=2;
   target=uigridlayout(g,[3 1]);target.Layout.Row=3;target.RowHeight={58,28,'1x'};
   obj.TargetLabel=uilabel(target,Text="INTENCION VISUAL",FontSize=34,FontWeight='bold',HorizontalAlignment='center');
   obj.TargetLabel.Layout.Row=1;
   obj.PhaseLabel=uilabel(target,Text="Target visual ≠ apertura medida",HorizontalAlignment='center',FontSize=15);
   obj.PhaseLabel.Layout.Row=2;
   targetPlot=uipanel(target,BorderType='none');targetPlot.Layout.Row=3;
   obj.TargetAxes=uiaxes(targetPlot,Units='normalized',Position=[0 0 1 1]);obj.TargetAxes.XLim=[0 1];obj.TargetAxes.YLim=[0 1];obj.TargetAxes.YTick=[];
   obj.TargetAxes.XTick=0:.25:1;obj.TargetAxes.XTickLabel={'0%','25%','50%','75%','100%'};
   obj.TargetPatch=rectangle(obj.TargetAxes,Position=[0 .15 .0001 .7],FaceColor=[.10 .48 .73],EdgeColor='none');
   emgPanel=uipanel(g,BorderType='none');emgPanel.Layout.Row=4;
   obj.EMGAxes=uiaxes(emgPanel,Units='normalized',Position=[0 0 1 1]);hold(obj.EMGAxes,'on');obj.EMGLines=gobjects(1,8);
   for ch=1:8,obj.EMGLines(ch)=plot(obj.EMGAxes,NaN,NaN,DisplayName="CH"+ch,LineWidth=1);end
   obj.EMGAxes.YTick=(0:7)*2.6;obj.EMGAxes.YTickLabel=cellstr("CH"+(1:8));obj.EMGAxes.YLim=[-1.2 19.5];
   xlabel(obj.EMGAxes,'Tiempo fuente [s]');title(obj.EMGAxes,'8 canales EMG RAW · offsets solo en pantalla');grid(obj.EMGAxes,'on');
   obj.QualityLabel=uilabel(g,Text="Fs nominal/estimada · llegada host · flat · clipping · RMS/MAV",WordWrap='on');
   obj.QualityLabel.Layout.Row=5;
   settings=uigridlayout(g,[1 6]);settings.Layout.Row=6;settings.ColumnWidth={100,70,110,70,110,70};
   uilabel(settings,Text="Repeticiones");obj.Repetitions=uieditfield(settings,'numeric',Value=5,Limits=[1 20],RoundFractionalValues='on');
   uilabel(settings,Text="Hold [s]");obj.HoldSeconds=uieditfield(settings,'numeric',Value=4,Limits=[3 5]);
   uilabel(settings,Text="REST [s]");obj.RestSeconds=uieditfield(settings,'numeric',Value=6,Limits=[5 10]);
   buttons=uigridlayout(g,[1 7]);buttons.Layout.Row=7;buttons.ColumnWidth=repmat({'1x'},1,7);
   names=["Conectar Myo","Test signal 30s","Iniciar / Seguir","Pausa","Repetir trial","Abortar seguro","Finalizar"];
   calls={@()obj.connect(),@()obj.testSignal(),@()obj.startSession(),@()obj.pauseSession(),@()obj.repeatTrial(),@()obj.abortSession(),@()obj.finishSession()};
   for k=1:7,fn=calls{k};uibutton(buttons,Text=names(k),ButtonPushedFcn=@(~,~)obj.guard(fn));end
   obj.TrialLabel=uilabel(g,Text="Sin sesion · RAW separado por trial · no entrenamiento",HorizontalAlignment='center');
   obj.TrialLabel.Layout.Row=8;
   if ~isempty(obj.Protocol),obj.Repetitions.Enable='off';obj.HoldSeconds.Enable='off';obj.RestSeconds.Enable='off';end
  end
  function lockMetadata(obj)
   controls={obj.Participant,obj.SessionID,obj.Placement,obj.Arm,obj.Note,obj.Repetitions,obj.HoldSeconds,obj.RestSeconds};
   for k=1:numel(controls),controls{k}.Enable='off';end
  end
  function m=identity(obj)
   m=struct("participant",string(obj.Participant.Value),"session",string(obj.SessionID.Value),"placement",string(obj.Placement.Value),"arm",string(obj.Arm.Value),"note",string(obj.Note.Value));
  end
  function onTimer(obj)
   if isa(obj.Source,'MockMyoDataSource'),obj.Source.advance(.05);end
   obj.guard(@()obj.pulse());
  end
  function guard(obj,fn)
   try,fn();catch ex
    obj.LastError=string(getReport(ex,'extended','hyperlinks','off'));obj.StatusLabel.Text="ERROR: "+string(ex.message);
    if ~isempty(obj.Session) && obj.Session.Status=="RUNNING"
     try,obj.Session.abort();catch,end
     obj.stopTimer();
    end
    if ~isempty(obj.Session) && obj.Session.Status=="ERROR",obj.stopTimer();end
    warning('MyoGUI:Operation','%s',ex.message);
   end
  end
  function timerFailure(obj)
   try,obj.abortSession();catch,end
   obj.stopTimer();
  end
  function stopTimer(obj)
   if ~isempty(obj.Timer)&&isvalid(obj.Timer),stop(obj.Timer);delete(obj.Timer);end
   obj.Timer=[];
  end
  function updateTarget(obj)
   v=obj.Session.preview();
   if isnan(v.target)
    obj.TargetLabel.Text="REPOSO · relajar";obj.TargetPatch.Position=[0 .15 .0001 .7];obj.TargetPatch.FaceColor=[.65 .65 .65];
   else
    obj.TargetLabel.Text=sprintf('APERTURA OBJETIVO %.0f %%',100*v.target);
    obj.TargetPatch.Position=[0 .15 max(.0001,v.target) .7];obj.TargetPatch.FaceColor=[.10 .48 .73];
   end
   direction=v.direction;if direction=="opening",direction="ABRIR";elseif direction=="closing",direction="CERRAR";else,direction="RELAX";end
   obj.PhaseLabel.Text=direction+" · "+v.phase+sprintf(' · %.1f / %.1f s',min(v.elapsed,v.duration),v.duration);
   obj.TrialLabel.Text=sprintf('Trial protocolo %d / %d · %s · target es instruccion, no medicion',v.index,v.count,v.status);
   if v.status=="FINISHED",obj.StatusLabel.Text="Protocolo finalizado · trials guardados";end
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
