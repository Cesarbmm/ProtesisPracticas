function summary=runMyoPilot2Smoke(outputRoot)
% Piloto completo MOCK; ninguna conexión física ni lectura de sesiones humanas.
if nargin<1
 root=string(fileparts(fileparts(mfilename('fullpath'))));
 outputRoot=fullfile(root,'results','myo_pilot2_smoke',"run_"+string(datetime('now',Format='yyyyMMdd_HHmmss_SSS'))+"_"+extractBefore(string(java.util.UUID.randomUUID()),9));
end
assert(~isfolder(outputRoot),'MyoPilot2Smoke:Exists','Usar una carpeta nueva.');mkdir(outputRoot);
p=buildMyoPilot2Protocol();src=MockMyoDataSource();
app=MyoContinuousAcquisitionApp(Source=src,Protocol=p,OutputRoot=outputRoot,Visible='off',AutoTimer=false,SessionID='S04');
cleanup=onCleanup(@()delete(app)); %#ok<NASGU>
app.Note.Value='MOCK: LED alineado con cara dorsal del antebrazo; colocación fija';
app.startPractice();assert(isempty(app.Session)&&~isfolder(fullfile(outputRoot,'P001')));
practiceDirections=unique(app.PracticeProtocol.direction(app.PracticeProtocol.condition=="MOVEMENT"));
assert(isequal(practiceDirections,["closing";"opening"]));app.stopPractice();
app.connect();app.testSignal();src.advance(30);app.pulse();assert(app.QualityComplete);app.startSession();
elapsed=0;shown=strings(0,1);
while app.Session.Status=="RUNNING"
 src.advance(.5);elapsed=elapsed+.5;app.pulse();
 row=table2struct(p(min(app.Session.Index,height(p)),:));v=myoParticipantInstruction(row,max(0,app.Session.LastClock-app.Session.StartTime));
 key=v.phase;if row.direction=="closing"||row.direction=="opening",key=row.direction+"_"+v.phase;end
 if ~any(shown==key)&&ismember(key,["opening_PREPARE","opening_MOVE","opening_HOLD","opening_RELEASE", ...
   "closing_PREPARE","closing_MOVE","closing_HOLD","closing_RELEASE","REST","BLOCK_BREAK"])
  shown(end+1)=key;drawnow;exportapp(app.Figure,fullfile(outputRoot,key+".png")); %#ok<AGROW>
 end
end
s=app.Session;T=readtable(fullfile(s.Directory,'session_manifest.csv'),TextType='string');
assert(height(T)==97&&sum(T.condition=="MOVEMENT")==48&&sum(T.condition=="REST")==49);
assert(all(T.status=="COMPLETED")&&~any(T.condition=="BLOCK_BREAK"));
releaseSamples=0;
for k=1:height(T)
 f=fullfile(s.Directory,T.file(k));d=load(f,'trial');validateMyoTrial(d.trial);
 assert(myoFileSHA256(f)==T.sha256(k)&&~d.trial.source_info.scientific_data);
 if d.trial.condition=="MOVEMENT"
  r=d.trial.phase=="RELEASE";releaseSamples=releaseSamples+nnz(r);assert(any(r)&&all(isnan(d.trial.target_aperture(r))));
 end
end
B=readtable(fullfile(s.Directory,'block_break_events.csv'),TextType='string');
assert(height(B)==3&&all(B.status=="COMPLETED")&&all(B.observed_duration>=60));
metadata=jsondecode(fileread(fullfile(s.Directory,'metadata.json')));
assert(metadata.randomization_seed==20261008&&numel(metadata.randomized_order)==48&&metadata.vision_camera_excluded);
assert(isempty(dir(fullfile(outputRoot,'**','*.tmp*'))));app.finishSession();
summary=struct('result','PASS','mock_only',true,'seed',20261008,'active_movements',48,'rest_trials',49, ...
 'scientific_records',height(T),'block_breaks_without_trial',height(B),'protocol_seconds',elapsed,'emg_samples',sum(T.sample_count), ...
 'release_samples',releaseSamples,'phases_seen',shown,'practice_no_scientific_output',true,'all_trial_hashes_valid',true, ...
 'real_hardware_started',false,'training_started',false,'session_directory',s.Directory);
myoWriteJSONAtomic(fullfile(outputRoot,'summary.json'),summary);disp(summary);
end
