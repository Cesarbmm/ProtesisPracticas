function summary=runMyoMultiParticipantSmoke(outputRoot)
% Campaña completa sintética: nunca instancia una fuente física.
if nargin<1
 root=string(fileparts(fileparts(mfilename('fullpath'))));
 outputRoot=fullfile(root,'results','myo_campaign_v2_smoke',"run_"+string(datetime('now',Format='yyyyMMdd_HHmmss_SSS')));
end
assert(~isfolder(outputRoot),'MyoCampaignSmoke:Exists','Usar carpeta nueva.');
src=MockMyoDataSource();a=runMyoMultiParticipantApp('Source',src,'OutputRoot',outputRoot,'Visible','off','AutoTimer',false);
cleanup=onCleanup(@()delete(a)); %#ok<NASGU>
a.Figure.WindowState='normal';a.Figure.Position=[0 0 1366 768];
a.startPractice();a.advancePractice(8);assert(~isfolder(outputRoot)&&isempty(a.Session)&&~src.Connected);a.stopPractice();
id=a.createParticipant("MOCK, sin persona");a.newSession();a.connect();
assert(string(a.Buttons.Test.Enable)=="off");a.reviewSetup();a.SetupDialog.Visible='off';
drawnow;exportapp(a.SetupDialog,fullfile(outputRoot,'posture_confirmation_mock.png'));
for field=string(fieldnames(a.SetupChecks))',a.SetupChecks.(field).Value=true;end
a.confirmSetup();
a.testSignal();src.advance(30);a.pulse();a.startSession();elapsed=0;shown=strings(0,1);
while a.Session.Status=="RUNNING"
 src.advance(.25);elapsed=elapsed+.25;a.pulse();
 row=table2struct(a.Protocol(min(a.Session.Index,height(a.Protocol)),:));
 v=a.CueEngine.cue(row,max(0,a.Session.LastClock-a.Session.StartTime));key=string(row.direction)+"_"+v.phase;
 if ~any(shown==key)&&ismember(v.phase,["PREPARE","MOVE","HOLD","RELEASE","BLOCK_BREAK"])
  shown(end+1,1)=key;drawnow;exportapp(a.Figure,fullfile(outputRoot,key+".png")); %#ok<AGROW>
 end
end
session=a.Session;files=dir(fullfile(session.Directory,'trials','trial_*.mat'));assert(numel(files)==97);
for f=files'
 d=load(fullfile(f.folder,f.name),'trial');validateMyoTrial(d.trial);assert(~d.trial.source_info.scientific_data);
 assert(string(d.trial.arm_posture_id)==a.Campaign.arm_posture_id);
end
manifest=readtable(fullfile(session.Directory,'session_manifest.csv'),TextType='string');
for k=1:height(manifest),assert(myoFileSHA256(fullfile(session.Directory,manifest.file(k)))==manifest.sha256(k));end
assert(isempty(dir(fullfile(outputRoot,'**','*.tmp*'))));
assert(session.Metadata.random_seed==myoSessionSeed(session.Metadata.session_uuid));
assert(session.Metadata.posture_reference_sha256==myoFileSHA256(myoPostureAssetPath(a.Campaign.posture_reference_asset)));
first=session.Metadata.session_uuid;a.finishSession();a.newSession();assert(a.Reservation.session_id=="S002"&&a.Reservation.session_uuid~=first);
summary=struct('result','PASS','mock_only',true,'simulated_seconds',elapsed,'movements',48,'scientific_records',97, ...
 'session_uuid',first,'second_session_reserved',a.Reservation.session_id,'posture_confirmed',true, ...
 'precheck_was_gated',true,'session_seed',session.Metadata.random_seed,'session_seed_reproducible',true, ...
 'arm_posture_id',a.Campaign.arm_posture_id,'practice_wrote_files',false,'human_acquisition_started',false,'training_started',false,'session_directory',session.Directory);
myoWriteJSONAtomic(fullfile(outputRoot,'smoke_summary.json'),summary);disp(summary);
end
