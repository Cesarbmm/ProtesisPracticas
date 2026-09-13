function tests=testMyoContinuousAcquisition
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));t.TestData.root=root;
old=path;t.addTeardown(@()path(old));addpath(fullfile(root,"acquisition"));
end
function [s,source]=session(t,rest)
if nargin<2,rest=.2;end
folder=string(tempname);mkdir(folder);t.TestData.lastFolder=folder;
source=MockMyoDataSource();source.connect();
p=buildMyoContinuousProtocol(repetitions=1,holdLevels=.25,includeRamps=false,prepareSeconds=.1,normalSeconds=.1,holdSeconds=.2,restSeconds=rest);
metadata=struct("participant_id","P001","session_id","S01","placement_id","P1","arm","right","placement_note","mock");
s=MyoAcquisitionSession(source,folder,metadata,p);
end
function testProtocolRequiredConditions(t)
p=buildMyoContinuousProtocol();verifyTrue(t,all(ismember([.25 .5 .75 1],p.target_end(p.condition=="HOLD"))));
verifyTrue(t,any(p.rest_intent));verifyEqual(t,unique(p.speed(p.condition=="RAMP")),["normal";"slow"]);
verifyTrue(t,all(ismember(["opening","closing"],p.direction)));verifyEqual(t,max(p.repetition),5);
verifyTrue(t,all(p.duration_s==p.prepare_s+p.ramp_s+p.hold_s));
verifyTrue(t,all(p.condition(1:2:end)=="REST"));
end
function testProtocolConfigurableAndFastPrepared(t)
p=buildMyoContinuousProtocol(repetitions=2,speeds="fast",holdSeconds=3,restSeconds=8);
verifyEqual(t,unique(p.ramp_s(p.condition=="RAMP")),1);verifyEqual(t,unique(p.hold_s(~p.rest_intent)),3);
verifyEqual(t,unique(p.duration_s(p.rest_intent)),8);
end
function testExactRampPairs(t)
p=buildMyoContinuousProtocol(repetitions=1,speeds="normal");r=p(p.condition=="RAMP",:);
verifyEqual(t,[r.target_start,r.target_end],[0 .25;.25 .5;.5 .75;.75 1;1 .75;.75 .5;.5 .25;.25 0]);
end
function testInvalidProtocolRejected(t)
verifyError(t,@()buildMyoContinuousProtocol(holdLevels=1.1),"MyoProtocol:Levels");
verifyError(t,@()buildMyoContinuousProtocol(speeds="invented"),"MyoProtocol:Speed");
end
function testTargetTiming(t)
p=buildMyoContinuousProtocol(repetitions=1);r=table2struct(p(2,:));[q,phase]=myoProtocolTarget(r,[0 2 3 4 7]);
verifyEqual(t,q,[0;0;.125;.25;.25],AbsTol=1e-14);verifyEqual(t,phase,["PREPARE";"RAMP";"RAMP";"HOLD";"HOLD"]);
end
function testClosingTargetMonotonic(t)
p=buildMyoContinuousProtocol(repetitions=1);r=table2struct(p(find(p.direction=="closing",1),:));
[q,~]=myoProtocolTarget(r,linspace(0,r.duration_s,300));verifyTrue(t,all(diff(q)<=0));
end
function testRestIsNotOpenOrClosed(t)
p=buildMyoContinuousProtocol();[q,phase]=myoProtocolTarget(table2struct(p(1,:)),[0 1 6]);
verifyTrue(t,all(isnan(q)));verifyEqual(t,phase,repmat("REST",3,1));
end
function testMock200Hz8Channels(t)
s=MockMyoDataSource();s.connect();s.advance(1);p=s.read();
verifySize(t,p.emg_raw,[200 8]);verifyEqual(t,diff(p.time_emg),repmat(.005,199,1),AbsTol=1e-14);
verifySize(t,p.quat,[50 4]);verifySize(t,p.gyro,[50 3]);verifyEqual(t,p.emg_raw*128,round(p.emg_raw*128));
end
function testMockIncrementalNoDuplicates(t)
s=MockMyoDataSource();s.connect();s.advance(.15);a=s.read();s.advance(.1);b=s.read();empty=s.read();
verifySize(t,a.emg_raw,[30 8]);verifySize(t,b.emg_raw,[20 8]);verifyEmpty(t,empty.time_emg);verifyGreaterThan(t,b.time_emg(1),a.time_emg(end));
end
function testMockOptionalIMU(t)
s=MockMyoDataSource(false);s.connect();s.advance(.2);p=s.read();verifyEmpty(t,p.time_imu);verifySize(t,p.quat,[0 4]);
end
function testMockDeterminismWithoutGlobalRNG(t)
old=rng;s=MockMyoDataSource();s.connect();s.advance(.3);p=s.read();r=MockMyoDataSource();r.connect();r.advance(.3);
verifyEqual(t,p,r.read());verifyEqual(t,rng,old);
end
function testRealAdapterDoesNotAutoconnect(t)
s=MyoMexDataSource();c=onCleanup(@()delete(s)); %#ok<NASGU>
verifyFalse(t,s.Connected);verifyEmpty(t,s.Device);verifyEqual(t,s.info().expected_emg_hz,200);
verifyEqual(t,s.info().timestamp_provenance,"MYODATA_RECONSTRUCTED_NOMINAL");
verifyEqual(t,strlength(s.info().myoData_source_sha256),64);
end
function testQualityWarningsPreserveData(t)
x=zeros(200,8);x(:,2)=1;x(8,3)=NaN;before=x;time=(1:200)'/200;time(10)=time(9);
q=computeMyoQualityMetrics(time,x,1);verifyFalse(t,q.finite_raw);verifyFalse(t,q.timestamps_monotonic);
verifyTrue(t,any(q.clipping_fraction>.01));verifyGreaterThan(t,q.warning_count,0);verifyEqual(t,x,before);verifyFalse(t,q.dropout_certified);
end
function testQualityFSUsesNMinusOne(t)
s=MockMyoDataSource();s.connect();s.advance(30);p=s.read();q=computeMyoQualityMetrics(p.time_emg,p.emg_raw,30);
verifyEqual(t,q.actual_emg_fs,200,AbsTol=1e-10);verifyEqual(t,q.wall_sample_rate,200);verifyEqual(t,q.sample_count,6000);
end
function testSessionMetadataAndPlacement(t)
[s,~]=session(t);m=jsondecode(fileread(fullfile(s.Directory,"metadata.json")));
verifyEqual(t,string(m.placement_id),"P1");verifyFalse(t,m.source_info.scientific_data);verifyTrue(t,isfile(fullfile(s.Directory,"protocol.csv")));
verifyEqual(t,string(m.protocol_sha256),myoFileSHA256(fullfile(s.Directory,"protocol.csv")));verifyGreaterThan(t,numel(m.acquisition_code_hashes),0);
end
function testSessionIdentifiersNoTraversal(t)
src=MockMyoDataSource();m=struct("participant_id","../escape","session_id","S01","placement_id","P1","arm","right");
verifyError(t,@()MyoAcquisitionSession(src,string(tempname),m,buildMyoContinuousProtocol()),"MyoSession:Identifier");
end
function testSessionCannotOverwriteOrMixPlacements(t)
[s,src]=session(t);m=s.Metadata;m.placement_id="P2";
verifyError(t,@()MyoAcquisitionSession(src,fileparts(fileparts(s.Directory)),m,s.Protocol),"MyoSession:Exists");
end
function testIncrementalRawAndSchema(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();d=load(fullfile(s.Directory,"trials","trial_0001.mat"));
verifyTrue(t,validateMyoTrial(d.trial).schema_valid);verifyEqual(t,d.trial.emg_raw,round(22*sin(2*pi*d.trial.source_time_emg*(7:14))+8*cos(2*pi*d.trial.source_time_emg*(17:24)))/128);
verifyEqual(t,d.trial.reference_source,"VISUAL_TARGET");verifyEmpty(t,d.trial.measured_aperture);verifyFalse(t,d.trial.measured_aperture_available);
verifyTrue(t,all(isnan(d.trial.target_aperture)));s.abort();
end
function testAtomicNoOverwrite(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();file=fullfile(s.Directory,"trials","trial_0001.mat");d=load(file);sha=myoFileSHA256(file);
verifyError(t,@()saveMyoTrialAtomic(s.Directory,d.trial),"MyoSave:NoOverwrite");verifyEqual(t,myoFileSHA256(file),sha);s.abort();
end
function testTargetCannotMasqueradeAsMeasured(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();d=load(fullfile(s.Directory,"trials","trial_0001.mat"));
bad=d.trial;bad.measured_aperture=bad.target_aperture;verifyError(t,@()validateMyoTrial(bad),"MyoTrial:MeasuredUnavailable");s.abort();
end
function testInvalidSchemaDoesNotDamagePriorTrial(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();f=fullfile(s.Directory,"trials","trial_0001.mat");sha=myoFileSHA256(f);d=load(f);bad=d.trial;bad.trial_id=99;bad.emg_raw=bad.emg_raw(:,1:7);
verifyError(t,@()saveMyoTrialAtomic(s.Directory,bad),"MyoTrial:EMGShape");verifyEqual(t,myoFileSHA256(f),sha);verifyFalse(t,isfile(fullfile(s.Directory,"trials","trial_0099.mat")));s.abort();
end
function testManifestHashAndRawConsistency(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();s.abort();T=readtable(fullfile(s.Directory,"session_manifest.csv"),TextType="string");
verifyEqual(t,height(T),2);
for k=1:height(T),f=fullfile(s.Directory,T.file(k));d=load(f);verifyEqual(t,myoFileSHA256(f),T.sha256(k));verifyEqual(t,d.trial.sample_count,T.sample_count(k));end
end
function testPauseRestartPreservesPrefixes(t)
[s,src]=session(t,2);s.start();src.advance(.2);s.tick();s.pause();verifyEqual(t,s.Status,"PAUSED");
src.advance(10);s.start();verifyEqual(t,s.Index,1);verifyEqual(t,s.TrialID,2);src.advance(.1);s.tick();s.abort();
a=load(fullfile(s.Directory,"trials","trial_0001.mat"));b=load(fullfile(s.Directory,"trials","trial_0002.mat"));
verifyEqual(t,a.trial.status,"PAUSED_PARTIAL");verifyEqual(t,b.trial.status,"ABORTED_PARTIAL");verifyGreaterThan(t,b.trial.source_time_emg(1),a.trial.source_time_emg(end)+9);
end
function testRepeatDoesNotOverwrite(t)
[s,src]=session(t,2);s.start();src.advance(.1);s.tick();s.repeat();verifyEqual(t,s.TrialID,2);verifyEqual(t,s.Index,1);
src.advance(.1);s.tick();s.abort();verifyEqual(t,numel(dir(fullfile(s.Directory,"trials","trial_*.mat"))),2);
end
function testAbortConservesCompleted(t)
[s,src]=session(t);s.start();src.advance(.2);s.tick();f=fullfile(s.Directory,"trials","trial_0001.mat");sha=myoFileSHA256(f);
src.advance(.1);s.tick();s.abort();verifyEqual(t,myoFileSHA256(f),sha);verifyEqual(t,s.Status,"ABORTED");
end
function testRecoveryIsIdempotent(t)
[s,src]=session(t,3);s.start();src.advance(1.1);s.tick();
r=recoverMyoSession(s.Directory);verifyTrue(t,r.active_prefix_recovered);file=fullfile(s.Directory,"trials","trial_0001.mat");sha=myoFileSHA256(file);
r2=recoverMyoSession(s.Directory);verifyFalse(t,r2.active_prefix_recovered);verifyEqual(t,myoFileSHA256(file),sha);
d=load(file);verifyEqual(t,d.trial.status,"RECOVERED_PARTIAL");verifyEqual(t,d.trial.sample_count,220);
end
function testDisconnectPreservesLastPrefix(t)
[s,src]=session(t,3);s.start();src.advance(.2);s.tick();src.disconnect();
verifyError(t,@()s.tick(),"MyoSource:Disconnected");verifyEqual(t,s.Status,"ERROR");
d=load(fullfile(s.Directory,"trials","trial_0001.mat"));verifyEqual(t,d.trial.sample_count,40);
end
function testGUIQualityRequiredAndMetadataLocked(t)
src=MockMyoDataSource();a=MyoContinuousAcquisitionApp(Source=src,OutputRoot=string(tempname),Visible="off",AutoTimer=false);
c=onCleanup(@()delete(a)); %#ok<NASGU>
a.connect();verifyError(t,@()a.startSession(),"MyoGUI:QualityRequired");a.testSignal();src.advance(30);a.pulse();
verifyTrue(t,a.QualityComplete);a.startSession();verifyEqual(t,string(a.Participant.Enable),"off");a.abortSession();
end
function testGUISmoke(t)
s=runMyoAcquisitionSmoke(string(tempname));verifyEqual(t,s.result,"PASS");verifyTrue(t,s.mock_only);verifyTrue(t,s.target_changed);verifyTrue(t,isfile(s.gui_screenshot));
end
function testNoTrainingDatasetOrFeatureDependencies(t)
files=dir(fullfile(t.TestData.root,"acquisition","*.m"));
for f=files'
 s=string(fileread(fullfile(f.folder,f.name)));
 verifyFalse(t,contains(s,"Denis Dataset"));verifyFalse(t,contains(s,"runFinalSealedTest("));
 verifyFalse(t,contains(s,"e3bUpdate("));verifyFalse(t,contains(s,"WMoos("));verifyFalse(t,contains(s,"prosthesis_simulator("));
end
end
function testLateTickDoesNotDiscardRaw(t)
[s,src]=session(t);s.start();src.advance(.25);s.tick();
d=load(fullfile(s.Directory,"trials","trial_0001.mat"));
verifyEqual(t,d.trial.sample_count,50);verifyEqual(t,d.trial.duration,.25,AbsTol=1e-12);s.abort();
end
function testAmbiguousTimestampPreservesRawWithoutInventingTarget(t)
[s,src]=session(t);src.advance(.05);p=src.read();m=s.Metadata;r=table2struct(s.Protocol(2,:));
trial=makeMyoTrial(m,r,p,1,.03,"PARTIAL",table(),.01);
verifyEqual(t,trial.emg_raw,p.emg_raw);outside=trial.time_emg < -1e-9 | trial.time_emg>.01+1e-9;
verifyTrue(t,all(isnan(trial.target_aperture(outside))));verifyTrue(t,all(trial.phase(outside)=="OUTSIDE_STIMULUS_CLOCK"));
verifyTrue(t,validateMyoTrial(trial).schema_valid);
end
function testGUILayoutUsesDistinctRows(t)
a=MyoContinuousAcquisitionApp(Source=MockMyoDataSource(),Visible="off",AutoTimer=false);c=onCleanup(@()delete(a)); %#ok<NASGU>
verifyEqual(t,a.StatusLabel.Layout.Row,2);verifyEqual(t,a.TargetAxes.Parent.Layout.Row,3);verifyEqual(t,a.PhaseLabel.Layout.Row,2);
verifyEqual(t,a.EMGAxes.Parent.Layout.Row,4);verifyEqual(t,a.QualityLabel.Layout.Row,5);verifyEqual(t,a.TrialLabel.Layout.Row,8);
verifyEqual(t,numel(a.EMGLines),8);verifyEqual(t,a.EMGAxes.YLim,[-1.2 19.5]);
end
function testPlacementChangeRequiresNewQualityCheck(t)
src=MockMyoDataSource();a=MyoContinuousAcquisitionApp(Source=src,OutputRoot=string(tempname),Visible="off",AutoTimer=false);c=onCleanup(@()delete(a)); %#ok<NASGU>
a.connect();a.testSignal();src.advance(30);a.pulse();a.Placement.Value='P2';
verifyError(t,@()a.startSession(),"MyoGUI:QualityContextChanged");verifyEmpty(t,a.Session);
end
