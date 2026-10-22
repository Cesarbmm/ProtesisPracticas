function tests=testMyoPilot2
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
old=path;t.addTeardown(@()path(old));addpath(fullfile(t.TestData.root,'acquisition'));
end
function [s,src,folder]=session(t)
folder=string(tempname);src=MockMyoDataSource();src.connect();
m=struct('participant_id','MOCK','session_id','S04','placement_id','P1','arm','right','placement_note','LED dorsal fijo');
s=MyoAcquisitionSession(src,folder,m,buildMyoPilot2Protocol());t.addTeardown(@()src.disconnect());
end
function [a,src,folder]=app(t,varargin)
folder=string(tempname);src=MockMyoDataSource();
a=MyoContinuousAcquisitionApp('Source',src,'Protocol',buildMyoPilot2Protocol(),'OutputRoot',folder,'Visible','off','AutoTimer',false,'SessionID','S04',varargin{:});
t.addTeardown(@()delete(a));
end
function testOpeningCoordinates(t)
p=buildMyoPilot2Protocol();a=p(p.direction=="opening",:);
verifyEqual(t,a.target_start,zeros(24,1));verifyEqual(t,a.target_end,a.movement_level);verifyEqual(t,unique(a.movement_level),[.25;.5;.75;1]);
end
function testClosingCoordinates(t)
p=buildMyoPilot2Protocol();a=p(p.direction=="closing",:);
verifyEqual(t,a.target_start,ones(24,1));verifyEqual(t,a.target_end,1-a.movement_level);
for level=[.25 .5 .75 1],verifyEqual(t,unique(a.target_end(a.movement_level==level)),1-level);end
end
function testConstantNominalSpeedAndTimes(t)
p=buildMyoPilot2Protocol();a=p(p.condition=="MOVEMENT",:);
verifyEqual(t,a.move_s,4*a.movement_level);verifyEqual(t,abs(a.target_end-a.target_start)./a.move_s,repmat(.25,48,1));
verifyEqual(t,a.duration_s,6+a.move_s);verifyEqual(t,sum(p.duration_s),833);
end
function testReleaseSeparatedFromRest(t)
p=buildMyoPilot2Protocol();r=table2struct(p(find(p.condition=="MOVEMENT",1),:));
e=r.prepare_s+r.move_s+r.hold_s;[target,phase]=myoProtocolTarget(r,[0 r.prepare_s e-1e-6 e r.duration_s]);
verifyEqual(t,phase,["PREPARE";"MOVE";"HOLD";"RELEASE";"RELEASE"]);verifyTrue(t,all(isnan(target(4:5))));
[target,phase]=myoProtocolTarget(table2struct(p(1,:)),[0 4]);verifyTrue(t,all(isnan(target)));verifyEqual(t,phase,["REST";"REST"]);
end
function testClosingTrajectoryDirection(t)
p=buildMyoPilot2Protocol();r=table2struct(p(find(p.direction=="closing"&p.movement_level==1,1),:));
[q,phase]=myoProtocolTarget(r,(0:.1:6)');verifyTrue(t,all(diff(q(phase~="RELEASE"))<=1e-12));verifyEqual(t,q(1),1);
end
function testSeedReproducibilityWithoutGlobalRNG(t)
before=rng;a=buildMyoPilot2Protocol(Seed=20261008);b=buildMyoPilot2Protocol(Seed=20261008);c=buildMyoPilot2Protocol(Seed=12);
verifyEqual(t,a,b);verifyNotEqual(t,a.condition_id,c.condition_id);verifyEqual(t,rng,before);
end
function testEveryBlockBalanced(t)
p=buildMyoPilot2Protocol();
for block=1:3
 a=p(p.block_id==block&p.condition=="MOVEMENT",:);verifyEqual(t,height(a),16);
 for d=["opening","closing"],for level=[.25 .5 .75 1],verifyEqual(t,sum(a.direction==d&a.movement_level==level),2);end,end
end
verifyEqual(t,max(p.repetition),6);verifyEqual(t,p.randomized_order(p.condition=="MOVEMENT"),(1:48)');
end
function testDirectionRunsIncludingBlockBoundary(t)
for seed=[0 1 2 8 1234 20261008]
 p=buildMyoPilot2Protocol(Seed=seed);d=p.direction(p.condition=="MOVEMENT");
 verifyFalse(t,any(d(1:end-2)==d(2:end-1)&d(2:end-1)==d(3:end)));
end
end
function testProtocolRejectsDrift(t)
p=buildMyoPilot2Protocol();idx=find(p.direction=="closing",1);p.target_end(idx)=1;
verifyError(t,@()validateMyoPilot2Protocol(p),'MyoPilot2:Coordinates');
p=buildMyoPilot2Protocol();p.move_s(2)=99;verifyError(t,@()validateMyoPilot2Protocol(p),'MyoPilot2:Timing');
end
function testBlockBreakNotScientificTrial(t)
p=buildMyoPilot2Protocol();b=p(p.block_break,:);verifyEqual(t,height(b),3);verifyFalse(t,any(b.is_scientific_trial));verifyFalse(t,any(b.rest_intent));
verifyEqual(t,b.duration_s,[60;60;60]);verifyEqual(t,b.block_id,[1;2;3]);
end
function testEmptyPlacementNoteAllowsPrecheckAndStart(t)
[a,src,folder]=app(t);a.connect();verifyEmpty(t,a.Note.Value);
verifyError(t,@()a.startSession(),'MyoGUI:QualityRequired');
a.testSignal();verifyTrue(t,a.Testing);verifyFalse(t,isfolder(folder));
src.advance(30);a.pulse();verifyTrue(t,a.QualityComplete);verifyEqual(t,string(a.Buttons.Start.Enable),"on");
a.startSession();verifyEqual(t,a.Session.Status,"RUNNING");verifyEqual(t,string(a.Session.Metadata.placement_note),"");
m=jsondecode(fileread(fullfile(a.Session.Directory,'metadata.json')));verifyEqual(t,string(m.placement_note),"");
a.finishSession();
end
function testBackendAcceptsOptionalPlacementNote(t)
src=MockMyoDataSource();src.connect();t.addTeardown(@()src.disconnect());
for note=[""," "]
 folder=string(tempname);m=struct('participant_id','MOCK','session_id','S04','placement_id','P1','arm','right','placement_note',note);
 s=MyoAcquisitionSession(src,folder,m,buildMyoPilot2Protocol());verifyEqual(t,string(s.Metadata.placement_note),note);s.finish();
end
m=rmfield(m,'placement_note');s=MyoAcquisitionSession(src,string(tempname),m,buildMyoPilot2Protocol());
verifyFalse(t,isfield(s.Metadata,'placement_note'));s.finish();
end
function testMetadataSeedPostureAndOrder(t)
[s,~]=session(t);m=jsondecode(fileread(fullfile(s.Directory,'metadata.json')));
verifyEqual(t,string(m.arm_posture_id),"P0_NEUTRAL_90");verifyEqual(t,m.randomization_seed,20261008);
verifyEqual(t,numel(m.randomized_order),48);verifyFalse(t,m.placement_change_allowed);verifyTrue(t,m.vision_camera_excluded);
end
function testPracticeAllEightNoData(t)
[a,src,folder]=app(t);a.startPractice();verifyFalse(t,src.Connected);verifyEmpty(t,a.Session);
p=a.PracticeProtocol;active=p(p.condition=="MOVEMENT",:);verifyEqual(t,height(active),8);verifyEqual(t,numel(unique(active.condition_id)),8);
verifyEqual(t,unique(active.direction),["closing";"opening"]);verifyFalse(t,any(p.block_break));
a.advancePractice(sum(p.duration_s));verifyFalse(t,a.PracticeActive);verifyFalse(t,isfolder(folder));
end
function testClosingInstructionsAndAsset(t)
p=buildMyoPilot2Protocol();r=table2struct(p(find(p.direction=="closing"&p.movement_level==1,1),:));
v=myoParticipantInstruction(r,0);verifyEqual(t,v.instruction,"ABRE COMPLETAMENTE LA MANO");verifyEqual(t,v.asset,"PosicionInicial_ManoAbierta.png");verifyTrue(t,contains(v.detail,'Prepárate para cerrar'));
v=myoParticipantInstruction(r,3);verifyEqual(t,v.instruction,"CIERRA PROGRESIVAMENTE 100 %");verifyTrue(t,contains(v.detail,'NO APRIETES CON FUERZA'));
v=myoParticipantInstruction(r,6);verifyEqual(t,v.instruction,"MANTÉN EL CIERRE 100 %");verifyEqual(t,v.asset,"cierre_100.png");
v=myoParticipantInstruction(r,8);verifyEqual(t,v.instruction,"RELÁJATE");verifyEqual(t,v.detail,"VUELVE A TU POSICIÓN NATURAL");verifyEqual(t,v.participant_level,100);verifyEqual(t,v.participant_direction,"CIERRE");
end
function testFallbackAssetsAbsent(t)
[a,~,folder]=app(t,'AssetRoot',string(tempname));a.startPractice();a.advancePractice(8);
verifyEqual(t,string(a.GuideFallback.Visible),"on");verifyFalse(t,isfolder(folder));
end
function testBlockPauseResumeCreatesNoTrial(t)
[s,src]=session(t);s.start();
while ~s.Protocol.block_break(s.Index),src.advance(s.Protocol.duration_s(s.Index));s.tick();end
before=dir(fullfile(s.Directory,'trials','trial_*.mat'));id=s.TrialID;
src.advance(10.123456789);s.tick();s.pause();verifyEqual(t,s.Status,"PAUSED");verifyEqual(t,s.TrialID,id);
s.start();src.advance(60);s.tick();verifyEqual(t,numel(dir(fullfile(s.Directory,'trials','trial_*.mat'))),numel(before));
B=readtable(fullfile(s.Directory,'block_break_events.csv'),TextType='string');verifyEqual(t,B.status,["PAUSED_PARTIAL";"COMPLETED"]);s.abort();
end
function testTrialV2ReleaseAndLabels(t)
[s,src]=session(t);s.start();src.advance(5);s.tick();row=table2struct(s.Protocol(s.Index,:));src.advance(row.duration_s);s.tick();
d=load(fullfile(s.Directory,'trials','trial_0002.mat'));t2=d.trial;verifyEqual(t,t2.schema_version,"myo-continuous-v2");verifyTrue(t,validateMyoTrial(t2).schema_valid);
verifyEqual(t,t2.movement_level,row.movement_level);verifyEqual(t,t2.block_id,1);verifyEmpty(t,t2.measured_aperture);
bad=t2;bad.target_end=.123;verifyError(t,@()validateMyoTrial(bad),'MyoTrial:Pilot2Coordinates');s.abort();
end
function testV1SyntheticReadableUnchangedPhases(t)
src=MockMyoDataSource();src.connect();src.advance(1);packet=src.read();p=buildMyoContinuousProtocol(repetitions=1,includeRamps=false);
m=struct('participant_id','MOCK','session_id','V1','placement_id','P1','arm','right','source_info',src.info());
r=table2struct(p(2,:));trial=makeMyoTrial(m,r,packet,1,0,"COMPLETED",table(),1);
verifyEqual(t,trial.schema_version,"myo-continuous-v1");verifyTrue(t,validateMyoTrial(trial).schema_valid);verifyFalse(t,isfield(trial,'movement_level'));
[q,phase]=myoProtocolTarget(r,[0 2 3 4]);verifyEqual(t,phase,["PREPARE";"RAMP";"RAMP";"HOLD"]);verifyEqual(t,q,[0;0;.125;.25]);
end
function testExistingSessionsReadOnlyCompatibility(t)
root=fullfile(t.TestData.root,'data_acquisition','P001');count=0;
for sid=["S01","S02","S03"]
 files=dir(fullfile(root,sid,'trials','trial_*.mat'));
 for f=files'
  file=fullfile(f.folder,f.name);before=myoFileSHA256(file);d=load(file,'trial');verifyTrue(t,validateMyoTrial(d.trial).schema_valid);
  verifyEqual(t,myoFileSHA256(file),before);count=count+1;
 end
end
% En CI sin datos humanos la prueba sintética anterior cubre el contrato v1.
fprintf('Legacy session trials validated read-only: %d\n',count);
end
