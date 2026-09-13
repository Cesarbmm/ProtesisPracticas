function summary = runMyoAcquisitionSmoke(outputRoot)
% Prueba determinista GUI/backend. No instancia MyoMex ni conecta hardware.
if nargin<1
 root=string(fileparts(fileparts(mfilename("fullpath"))));
 outputRoot=fullfile(root,"results","myo_acquisition_smoke","run_"+string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'))+"_"+extractBefore(string(java.util.UUID.randomUUID()),9));
end
if ~isfolder(outputRoot),mkdir(outputRoot);end
protocol=buildMyoContinuousProtocol(repetitions=1,holdLevels=[.25 .5 .75 1],speeds="normal",prepareSeconds=.1,holdSeconds=.2,restSeconds=.2,normalSeconds=.2);
source=MockMyoDataSource();app=MyoContinuousAcquisitionApp(Source=source,Protocol=protocol,OutputRoot=outputRoot,Visible="off",AutoTimer=false);
cleanup=onCleanup(@() delete(app)); %#ok<NASGU>
app.connect();app.testSignal();source.advance(30);app.pulse();assert(app.QualityComplete);
app.startSession();targetChanged=false;firstTarget=app.TargetLabel.Text;
for k=1:1000
 source.advance(.05);app.pulse();drawnow;
 targetChanged=targetChanged||~strcmp(app.TargetLabel.Text,firstTarget);
 if app.Session.Index==4 && contains(app.PhaseLabel.Text,"HOLD") && ~isfile(fullfile(outputRoot,"gui_mock.png"))
  exportapp(app.Figure,fullfile(outputRoot,"gui_mock.png"));
 end
 if app.Session.Status=="FINISHED",break;end
end
assert(app.Session.Status=="FINISHED"&&targetChanged,"MyoSmoke:ProtocolDidNotFinish","Datos o estado incompatibles con MyoSmoke:ProtocolDidNotFinish.");
sessionDir=app.Session.Directory;T=readtable(fullfile(sessionDir,"session_manifest.csv"),TextType="string");
assert(height(T)==height(protocol)&&all(T.sample_count>0));
for k=1:height(T)
 file=fullfile(sessionDir,T.file(k));d=load(file,"trial");validateMyoTrial(d.trial);
 assert(~d.trial.source_info.scientific_data && ~d.trial.measured_aperture_available);
 assert(myoFileSHA256(file)==T.sha256(k));
end
app.finishSession();
summary=struct("result","PASS","mock_only",true,"gui_created",true,"target_changed",targetChanged, ...
 "trials",height(T),"sample_count",sum(T.sample_count),"session_directory",sessionDir, ...
 "gui_screenshot",fullfile(outputRoot,"gui_mock.png"),"real_myo_data_collected",false,"training_started",false);
myoWriteJSONAtomic(fullfile(outputRoot,"smoke_summary.json"),summary);disp(summary);
end
