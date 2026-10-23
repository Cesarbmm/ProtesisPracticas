function tests=testMyoMultiParticipant
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
old=path;t.addTeardown(@()path(old));addpath(fullfile(t.TestData.root,'acquisition'));
end
function [a,src,root]=app(t)
root=string(tempname);src=MockMyoDataSource();
a=MyoContinuousAcquisitionApp(Campaign=myoCampaignConfig(),Source=src,OutputRoot=root,Visible='off',AutoTimer=false);
t.addTeardown(@()delete(a));
end
function confirm(a)
a.reviewSetup();a.SetupDialog.Visible='off';a.ConfirmParticipant.Value=true;a.ConfirmPlacement.Value=true;a.ConfirmPosture.Value=true;a.confirmSetup();
end
function start(a,src)
a.createParticipant();a.newSession();a.connect();confirm(a);a.testSignal();src.advance(30);a.pulse();a.startSession();
end
function testNextIDIncludesHistoricalFolders(t)
root=string(tempname);mkdir(fullfile(root,'P007','S04'));r=MyoParticipantRegistry(root);
verifyEqual(t,r.nextID(),"P008");id=r.create(r.nextID(),"alias opcional");verifyEqual(t,id,"P008");
verifyTrue(t,isfile(fullfile(root,id,'participant.json')));verifyEqual(t,r.describe(id).optional_alias,"alias opcional");
end
function testInitializeImportsHistoryWithoutRenaming(t)
root=string(tempname);folder=fullfile(root,'P001','S04');mkdir(folder);
myoWriteJSONAtomic(fullfile(folder,'metadata.json'),struct('participant_id','P001','session_id','S04'));
before=myoFileSHA256(fullfile(folder,'metadata.json'));r=MyoParticipantRegistry(root);r.initialize();
verifyTrue(t,isfolder(folder));verifyTrue(t,isfile(fullfile(root,'participants_registry.csv')));
verifyEqual(t,myoFileSHA256(fullfile(folder,'metadata.json')),before);verifyEqual(t,r.nextID(),"P002");
m=jsondecode(fileread(fullfile(root,'P001','participant.json')));verifyEqual(t,string(m.participant_id),"P001");verifyEqual(t,string(m.optional_alias),"");
end
function testInactiveIDsNeverReused(t)
r=MyoParticipantRegistry(tempname);id=r.create(r.nextID());r.setStatus(id,"inactive");
verifyEqual(t,r.nextID(),"P002");verifyEqual(t,r.create(r.nextID()),"P002");verifyEqual(t,height(r.list()),2);
end
function testReservedIDsNeverReused(t)
r=MyoParticipantRegistry(tempname);id=r.create(r.nextID());file=fullfile(r.Root,'participants_registry.csv');
rows=readtable(file,TextType='string');rows.status(:)="reserved";myoWriteTableAtomic(file,rows);
verifyEqual(t,r.nextID(),"P002");verifyError(t,@()r.reserveSession(id,"CAMPAIGN"),'MyoRegistry:Participant');
end
function testStaleIDPreviewRejected(t)
root=string(tempname);a=MyoParticipantRegistry(root);b=MyoParticipantRegistry(root);preview=a.nextID();b.create(preview);
verifyError(t,@()a.create(preview),'MyoRegistry:PreviewChanged');verifyEqual(t,a.nextID(),"P002");
end
function testLockExcludesOtherWriter(t)
root=string(tempname);r=MyoParticipantRegistry(root);lock=myoAcquireDataLock(root);
verifyError(t,@()r.create("P001"),'MyoRegistry:Locked');clear lock
verifyEqual(t,r.create("P001"),"P001");
end
function testSequentialSessionsIncludeHistoricalIDs(t)
root=string(tempname);mkdir(fullfile(root,'P001','S01'));mkdir(fullfile(root,'P001','S04'));r=MyoParticipantRegistry(root);
a=r.reserveSession("P001","C");b=r.reserveSession("P001","C");
verifyEqual(t,a.session_id,"S005");verifyEqual(t,b.session_id,"S006");verifyNotEqual(t,a.session_uuid,b.session_uuid);
verifyFalse(t,isfolder(fullfile(root,'P001','S005')));verifyEqual(t,r.describe("P001").session_count,2);
end
function testNewParticipantsHaveIndependentSessions(t)
r=MyoParticipantRegistry(tempname);a=r.create(r.nextID());b=r.create(r.nextID());
verifyEqual(t,r.reserveSession(a,"C").session_id,"S001");verifyEqual(t,r.reserveSession(b,"C").session_id,"S001");
verifyEqual(t,r.reserveSession(a,"C").session_id,"S002");
end
function testReadOnlyPracticeDoesNotCreateRegistryOrSession(t)
[a,src,root]=app(t);a.startPractice();p=a.PracticeProtocol;
verifyFalse(t,src.Connected);verifyEmpty(t,a.Session);verifyFalse(t,isfolder(root));
active=p.condition=="MOVEMENT";verifyEqual(t,nnz(active),8);verifyEqual(t,unique(p.move_s(active)),[1;2;3;4]);
a.advancePractice(sum(p.duration_s));verifyFalse(t,isfolder(root));
end
function testParticipantDropdownAndSessionAreNotFreeText(t)
[a,~,~]=app(t);id=a.createParticipant("opcional");
verifyClass(t,a.Participant,'matlab.ui.control.DropDown');verifyEqual(t,string(a.Participant.Editable),"off");
verifyEqual(t,string(a.SessionID.Editable),"off");verifyEqual(t,string(a.Participant.Value),id);
verifyTrue(t,contains(string(a.Participant.Items{1}),"opcional"));verifyTrue(t,contains(string(a.Participant.Items{1}),"0 sesiones"));
end
function testControlsRemainReadableAt768PixelHeight(t)
[a,~,root]=app(t);a.Figure.WindowState='normal';a.Figure.Position=[0 0 1366 768];a.startPractice();drawnow;
verifyGreaterThanOrEqual(t,a.Buttons.Start.Position(4),28);verifyGreaterThanOrEqual(t,a.Buttons.Finish.Position(4),28);
verifyFalse(t,isfolder(root));verifyTrue(t,contains(a.PracticeBanner.Text,'NO SE GUARDAN DATOS'));
end
function testPrepareIsRedAndMoveRestoresNormalColor(t)
[a,~,~]=app(t);a.startPractice();p=a.PracticeProtocol;
for direction=["opening","closing"]
 idx=find(p.direction==direction,1);at=sum(p.duration_s(1:idx-1));
 % Reiniciar sólo el reloj visual; no hay sesión ni escritura.
 a.stopPractice();a.startPractice();a.advancePractice(at);
 verifyEqual(t,a.InstructionLabel.FontColor,[.80 .06 .06]);verifyEqual(t,a.PhaseLabel.FontColor,[.80 .06 .06]);
 a.advancePractice(p.prepare_s(idx));verifyEqual(t,a.InstructionLabel.FontColor,[.10 .10 .10]);
end
end
function testEMGAxesFillsResizedGridWithoutChangingSignals(t)
[a,src,~]=app(t);a.Figure.WindowState='normal';a.Figure.Position=[0 0 1100 768];
a.connect();src.advance(2);a.pulse();waitForEMGLayout(a);x=a.EMGLines(1).XData;y=a.EMGLines(1).YData;before=a.EMGAxes.OuterPosition(3);
a.Figure.Position=[0 0 1366 768];waitForEMGLayout(a);a.pulse();drawnow;
verifyGreaterThan(t,a.EMGAxes.OuterPosition(3),before+200);
verifyGreaterThan(t,a.EMGAxes.OuterPosition(3),.90*a.EMGAxes.Parent.InnerPosition(3));
verifyEqual(t,a.EMGLines(1).XData,x);verifyEqual(t,a.EMGLines(1).YData,y);verifyEqual(t,numel(a.EMGLines),8);
end
function waitForEMGLayout(a)
% uifigure resuelve el layout web de forma asíncrona, incluso con Visible=off.
for attempt=1:50
 drawnow;g=a.EMGAxes.Parent.Parent;expected=a.Figure.Position(3)-sum(g.Padding([1 3]));
 if abs(a.EMGAxes.Parent.Position(3)-expected)<2&&abs(a.EMGAxes.OuterPosition(3)-expected)<2,return;end
 pause(.02);
end
end
function testOpening25VisibleEndpointKeepsTargetAndDuration(t)
c=myoCampaignConfig();m=jsondecode(fileread(fullfile(c.asset_root,'cues_manifest.json')));
verifyEqual(t,m.sequences.opening_025.source_last_frame,63);verifyEqual(t,numel(m.sequences.opening_025.frames),28);
p=buildMyoCampaignProtocol();row=table2struct(p(find(p.direction=="opening"&p.movement_level==.25,1),:));
e=MyoVisualCueEngine(c.asset_root);v=e.cue(row,row.prepare_s+row.move_s);
verifyEqual(t,row.move_s,1);verifyEqual(t,v.target,.25);verifyTrue(t,endsWith(v.asset,'frame_0063.png'));
end
function testPrecheckRequiresThreeConfirmations(t)
[a,~,~]=app(t);a.createParticipant();a.newSession();a.connect();
verifyEqual(t,string(a.Buttons.Test.Enable),"off");verifyError(t,@()a.testSignal(),'MyoGUI:SetupRequired');
a.reviewSetup();a.SetupDialog.Visible='off';a.ConfirmParticipant.Value=true;a.ConfirmPlacement.Value=true;
verifyError(t,@()a.confirmSetup(),'MyoGUI:Confirmations');a.ConfirmPosture.Value=true;a.confirmSetup();
verifyEqual(t,string(a.Buttons.Test.Enable),"on");a.testSignal();verifyTrue(t,a.Testing);
end
function testChangedIdentityInvalidatesConfirmation(t)
[a,~,~]=app(t);a.createParticipant();a.newSession();a.connect();confirm(a);
a.Arm.Value='left';verifyError(t,@()a.testSignal(),'MyoGUI:SetupRequired');
end
function testMissingPostureAssetBlocksConfirmation(t)
c=myoCampaignConfig();c.asset_root=string(tempname);src=MockMyoDataSource();
a=MyoContinuousAcquisitionApp(Campaign=c,Source=src,OutputRoot=string(tempname),Visible='off',AutoTimer=false);t.addTeardown(@()delete(a));
a.createParticipant();a.newSession();a.reviewSetup();a.SetupDialog.Visible='off';
a.ConfirmParticipant.Value=true;a.ConfirmPlacement.Value=true;a.ConfirmPosture.Value=true;
verifyError(t,@()a.confirmSetup(),'MyoGUI:PostureAsset');
end
function testMetadataCampaignUUIDPostureAndAssetsPersist(t)
[a,src,~]=app(t);start(a,src);m=jsondecode(fileread(fullfile(a.Session.Directory,'metadata.json')));
verifyEqual(t,string(m.campaign_id),"PILOT2_OPEN_CLOSE_V1");verifyEqual(t,string(m.arm_posture_id),"P0_FORWARD_EXTENDED");
verifyTrue(t,m.posture_confirmed&&m.participant_confirmed&&m.placement_confirmed);
verifyEqual(t,string(m.session_uuid),a.Reservation.session_uuid);verifyEqual(t,m.random_seed,20261008);
verifyEqual(t,string(m.posture_reference_sha256),myoFileSHA256(fullfile(a.Campaign.asset_root,'postures','P0_FORWARD_EXTENDED.png')));
verifyEqual(t,myoFileSHA256(fullfile(a.Session.Directory,'visual_cues_manifest.json')),a.CueEngine.ManifestHash);
verifyTrue(t,all(isfield(m,{'capture_utc','protocol_sha256','protocol_version','acquisition_code_hashes'})));a.finishSession();
end
function testBackendRejectsMissingConfirmationsBeforeWriting(t)
root=string(tempname);src=MockMyoDataSource();m=struct('participant_id','P001','session_id','S001','placement_id','P1','arm','right','campaign_id','PILOT2_OPEN_CLOSE_V1');
verifyError(t,@()MyoAcquisitionSession(src,root,m,buildMyoCampaignProtocol()),'MyoSession:Confirmations');verifyFalse(t,isfolder(root));
end
function testExistingSessionNeverOverwritten(t)
[a,src,~]=app(t);start(a,src);file=fullfile(a.Session.Directory,'metadata.json');before=myoFileSHA256(file);
verifyError(t,@()MyoAcquisitionSession(src,a.OutputRoot,a.Session.Metadata,a.Protocol),'MyoSession:Exists');
verifyEqual(t,myoFileSHA256(file),before);a.finishSession();
end
function testBackendRejectsIncorrectPostureHash(t)
[a,src,~]=app(t);start(a,src);m=a.Session.Metadata;m.posture_reference_sha256="incorrecto";
verifyError(t,@()MyoAcquisitionSession(src,a.OutputRoot,m,a.Protocol),'MyoSession:PostureAsset');a.finishSession();
end
function testSameAppCanStartNextSessionSameParticipant(t)
[a,src,~]=app(t);start(a,src);first=a.Reservation;a.finishSession();a.newSession();
verifyEqual(t,a.Reservation.participant_id,first.participant_id);verifyEqual(t,a.Reservation.session_id,"S002");
verifyNotEqual(t,a.Reservation.session_uuid,first.session_uuid);verifyFalse(t,a.QualityComplete);verifyEmpty(t,a.SetupConfirmation);
a.connect();confirm(a);a.testSignal();src.advance(30);a.pulse();a.startSession();a.finishSession();
end
function testCurrentProtocolExactlyPreservesScientificSchedule(t)
old=buildMyoPilot2Protocol();p=buildMyoCampaignProtocol();names=setdiff(old.Properties.VariableNames,{'arm_posture_id'},'stable');
verifyEqual(t,p(:,names),old(:,names));verifyEqual(t,nnz(p.condition=="MOVEMENT"),48);verifyEqual(t,sum(p.duration_s),833);
verifyTrue(t,all(p.arm_posture_id=="P0_FORWARD_EXTENDED"));
end
function testEveryBlockAndCycleContainsAllConditions(t)
p=buildMyoCampaignProtocol();
for b=1:3
 a=p(p.condition=="MOVEMENT"&p.block_id==b,:);
 verifyEqual(t,numel(unique(a.condition_id)),8);
 for id=unique(a.condition_id)',verifyEqual(t,nnz(a.condition_id==id),2);end
end
end
function testPrepareCuesFollowDirection(t)
engine=MyoVisualCueEngine(myoCampaignConfig().asset_root);p=buildMyoCampaignProtocol();
for direction=["opening","closing"]
 row=table2struct(p(find(p.direction==direction,1),:));v=engine.cue(row,0);
 if direction=="opening",verifyTrue(t,endsWith(v.asset,'prepare_closed.png'));else,verifyTrue(t,endsWith(v.asset,'prepare_open.png'));end
end
end
function testFramesUseElapsedMoveAndHoldFreezesEndpoint(t)
engine=MyoVisualCueEngine(myoCampaignConfig().asset_root);p=buildMyoCampaignProtocol();
for direction=["opening","closing"]
 for level=[.25 .5 .75 1]
  row=table2struct(p(find(p.direction==direction&p.movement_level==level,1),:));
  first=engine.cue(row,2);mid=engine.cue(row,2+row.move_s/2);last=engine.cue(row,2+row.move_s);hold=engine.cue(row,2+row.move_s+1);
  verifyEqual(t,first.frame_index,1);verifyEqual(t,mid.progress,.5);verifyGreaterThan(t,mid.frame_index,first.frame_index);
  verifyEqual(t,last.asset,hold.asset);verifyEqual(t,last.progress,1);verifyTrue(t,isfile(last.asset));
  verifyEqual(t,last.target,row.target_end);verifyEqual(t,first.target,row.target_start);
 end
end
end
function testCuesAreDeterministicWithoutIndependentClock(t)
e=MyoVisualCueEngine(myoCampaignConfig().asset_root);p=buildMyoCampaignProtocol();r=table2struct(p(2,:));
a=e.cue(r,2.5);e.cue(r,4);verifyEqual(t,e.cue(r,2.5),a);
end
function testCuratedFrameSourcesAndNominalPrefixes(t)
c=myoCampaignConfig();m=jsondecode(fileread(fullfile(c.asset_root,'cues_manifest.json')));
verifyEqual(t,string(m.sequences.opening_100.source),"Cierre-Apertura.mp4");
verifyEqual(t,string(m.sequences.closing_100.source),"Apertura-Cierre.mp4");
for direction=["opening","closing"]
 full=string(m.sequences.(direction+"_100").frames);verifyEqual(t,numel(full),71);
 verifyTrue(t,endsWith(full(1),'frame_0036.png'));verifyTrue(t,endsWith(full(end),'frame_0106.png'));
 for level=[25 50 75 100]
  frames=string(m.sequences.(direction+compose('_%03d',level)).frames);
  count=1+round(70*level/100);if direction=="opening"&&level==25,count=28;end
  verifyEqual(t,frames,full(1:count));
 end
end
end
function testPreparedAssetsRegenerateDeterministically(t)
root=string(tempname);m=prepareMyoCampaignAssets(root);before=myoFileSHA256(fullfile(root,'cues_manifest.json'));
prepareMyoCampaignAssets(root);e=MyoVisualCueEngine(root);verifyEqual(t,e.ManifestHash,before);
verifyEqual(t,numel(m.sequences.opening_100.frames),71);
end
function testCampaignDescriptorDoesNotRequireGUIChange(t)
c=myoCampaignConfig();c.campaign_id="FUTURE_FIXTURE_ONLY";c.protocol_builder=@futureProtocol;
src=MockMyoDataSource();a=MyoContinuousAcquisitionApp(Campaign=c,Source=src,OutputRoot=string(tempname),Visible='off',AutoTimer=false);t.addTeardown(@()delete(a));
start(a,src);verifyEqual(t,string(a.Session.Metadata.campaign_id),"FUTURE_FIXTURE_ONLY");a.finishSession();
end
function p=futureProtocol(seed)
p=buildMyoCampaignProtocol(seed);p.campaign_id(:)="FUTURE_FIXTURE_ONLY";
end
function testReleaseRestAndMissingOptionalAssetText(t)
e=MyoVisualCueEngine(myoCampaignConfig().asset_root);p=buildMyoCampaignProtocol();r=table2struct(p(2,:));
v=e.cue(r,r.duration_s-1);verifyEqual(t,v.phase,"RELEASE");verifyTrue(t,isnan(v.target));
v=e.cue(table2struct(p(1,:)),1);verifyEqual(t,v.instruction,"REPOSO");verifyTrue(t,isnan(v.target));
end
function testAnnotationDoesNotModifyOriginalFiles(t)
root=string(tempname);folder=fullfile(root,'P001','S04');mkdir(folder);
myoWriteJSONAtomic(fullfile(folder,'metadata.json'),struct('participant_id','P001','arm_posture_id','P0_NEUTRAL_90'));
writetable(table("original",VariableNames={'trial'}),fullfile(folder,'session_manifest.csv'));
before=[myoFileSHA256(fullfile(folder,'metadata.json')),myoFileSHA256(fullfile(folder,'session_manifest.csv'))];
r=annotateMyoSession(root,folder,"arm_posture_id","P0_FORWARD_EXTENDED","Declaración posterior del operador");
verifyEqual(t,r.original_value,"P0_NEUTRAL_90");verifyEqual(t,[r.source_metadata_sha256,r.source_manifest_sha256],before);
verifyEqual(t,myoFileSHA256(fullfile(folder,'metadata.json')),before(1));
verifyEqual(t,myoFileSHA256(fullfile(folder,'session_manifest.csv')),before(2));
verifyError(t,@()annotateMyoSession(root,folder,"participant_id","P009","sin registrar"),'MyoAnnotation:Participant');
registry=MyoParticipantRegistry(root);id=registry.create(registry.nextID());annotateMyoSession(root,folder,"participant_id",id,"Asignación explícita del operador");
verifyEqual(t,height(readtable(fullfile(root,'session_annotations.csv'),ReadVariableNames=true,Delimiter=',',Format=repmat('%q',1,9))),2);
end
function testHistoricalSessionsS01ThroughS04StayReadable(t)
root=fullfile(t.TestData.root,'data_acquisition','P001');count=0;
for sid=["S01","S02","S03","S04"]
 files=dir(fullfile(root,sid,'trials','trial_*.mat'));
 for f=files'
  path=fullfile(f.folder,f.name);before=myoFileSHA256(path);d=load(path,'trial');verifyTrue(t,validateMyoTrial(d.trial).schema_valid);
  verifyEqual(t,myoFileSHA256(path),before);count=count+1;
 end
end
fprintf('Historical trials S01-S04 read-only: %d\n',count);
end
