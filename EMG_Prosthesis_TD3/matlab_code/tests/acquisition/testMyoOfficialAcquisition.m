function tests=testMyoOfficialAcquisition
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
old=path;t.addTeardown(@()path(old));addpath(fullfile(t.TestData.root,'acquisition'),fullfile(fileparts(mfilename('fullpath')),'fixtures'));
end
function [a,src,root]=app(t,src,root)
if nargin<2,src=MockMyoDataSource();end
if nargin<3,root=string(tempname);end
a=runMyoMultiParticipantApp(Source=src,OutputRoot=root,Visible='off',AutoTimer=false);
t.addTeardown(@()delete(a));
end
function confirm(a)
a.reviewSetup();
for field=string(fieldnames(a.SetupChecks))',a.SetupChecks.(field).Value=true;end
a.confirmSetup();
end
function ready(a,src)
a.createParticipant();a.newSession();a.connect();confirm(a);a.testSignal();src.advance(30);a.pulse();
end
function testOfficialDefaultAndPilotDescriptorRemainSeparate(t)
c=myoOfficialCampaignConfig();old=myoCampaignConfig();
verifyEqual(t,c.campaign_id,"MYO_OPEN_CLOSE_OFFICIAL_V1");verifyEqual(t,c.protocol_version,"OPEN_CLOSE_OFFICIAL_V1");
verifyEqual(t,c.arm_posture_id,"P0_SEATED_ARMREST");verifyEqual(t,old.arm_posture_id,"P0_FORWARD_EXTENDED");
[a,~,~]=app(t);verifyEqual(t,a.Campaign,c);verifyEqual(t,string(a.Figure.Resize),"on");
end
function testExistingPostureImageUsedDirectlyWithoutNewCopy(t)
c=myoOfficialCampaignConfig();path=myoPostureAssetPath(c.posture_reference_asset);
verifyEqual(t,c.posture_reference_asset,"references/Referencia.jpg");verifyTrue(t,isfile(path));
verifyEqual(t,myoFileSHA256(path),"8673addf727fdfe1a0f5deba2891f5d00011474f61781b0b640476eaf31a91c4");
[a,~,~]=app(t);a.createParticipant();a.newSession();a.reviewSetup();images=findall(a.SetupDialog,'Type','uiimage');
verifyEqual(t,numel(images),1);verifyEqual(t,string(images.ImageSource),path);
end
function testOfficialProtocolExactlyMatchesS04ScientificContent(t)
seed=187245;p=buildMyoOfficialProtocol(seed);old=buildMyoCampaignProtocol(seed);
names=setdiff(p.Properties.VariableNames,{'arm_posture_id','campaign_id','protocol_version'},'stable');
verifyEqual(t,p(:,names),old(:,names));verifyEqual(t,sum(p.duration_s),833);
active=p(p.condition=="MOVEMENT",:);verifyEqual(t,height(active),48);
verifyEqual(t,unique(active.movement_level),[.25;.5;.75;1]);verifyEqual(t,unique(active.direction),["closing";"opening"]);
for id=unique(active.condition_id)',verifyEqual(t,nnz(active.condition_id==id),6);end
for b=1:3
 block=active(active.block_id==b,:);verifyEqual(t,height(block),16);
 for id=unique(block.condition_id)',verifyEqual(t,nnz(block.condition_id==id),2);end
end
verifyEqual(t,active.move_s,4*active.movement_level);
verifyTrue(t,all(p.arm_posture_id=="P0_SEATED_ARMREST"));
end
function testReleaseAndRestStillSeparate(t)
p=buildMyoOfficialProtocol();row=table2struct(p(find(p.condition=="MOVEMENT",1),:));
[target,phase]=myoProtocolTarget(row,row.duration_s-1);verifyEqual(t,phase,"RELEASE");verifyTrue(t,isnan(target));
[target,phase]=myoProtocolTarget(table2struct(p(find(p.rest_intent,1),:)),1);
verifyEqual(t,phase,"REST");verifyTrue(t,isnan(target));
end
function testAllTenConfirmationsRequiredBeforePrecheck(t)
[a,~,~]=app(t);a.createParticipant();a.newSession();a.connect();a.reviewSetup();
verifyEqual(t,numel(fieldnames(a.SetupChecks)),10);verifyEqual(t,string(a.Buttons.Test.Enable),"off");
for field=string(fieldnames(a.SetupChecks))',a.SetupChecks.(field).Value=true;end
for field=string(fieldnames(a.SetupChecks))'
 a.SetupChecks.(field).Value=false;
 verifyError(t,@()a.confirmSetup(),'MyoGUI:Confirmations');
 verifyError(t,@()a.testSignal(),'MyoGUI:SetupRequired');
 a.SetupChecks.(field).Value=true;
end
a.confirmSetup();verifyEqual(t,string(a.Buttons.Test.Enable),"on");
end
function testP1LockedAndExplained(t)
[a,~,~]=app(t);verifyEqual(t,string(a.Placement.Value),"P1");verifyEqual(t,string(a.Placement.Editable),"off");
verifyTrue(t,contains(a.Placement.Tooltip,'dos dedos'));verifyTrue(t,contains(a.Placement.Tooltip,'exterior'));
end
function testArmChangeInvalidatesConfirmationAndPrecheck(t)
[a,src,~]=app(t);ready(a,src);a.Arm.Value='left';a.Arm.ValueChangedFcn([],[]);
verifyEmpty(t,a.SetupConfirmation);verifyFalse(t,a.QualityComplete);verifyEqual(t,string(a.Buttons.Test.Enable),"off");
verifyError(t,@()a.startSession(),'MyoGUI:QualityRequired');
end
function testOfficialMetadataStoresConfirmationsHashAndSeed(t)
[a,src,~]=app(t);ready(a,src);a.startSession();m=a.Session.Metadata;
for field=["participant_confirmed","placement_confirmed","posture_confirmed","arm_confirmed","myo_fit_confirmed","myo_orientation_confirmed","stabilization_confirmed"]
 verifyTrue(t,m.(field));
end
verifyEqual(t,m.arm_posture_id,"P0_SEATED_ARMREST");verifyEqual(t,m.placement_id,"P1");
verifyEqual(t,m.random_seed,myoSessionSeed(m.session_uuid));verifyEqual(t,m.session_seed_source,"UUID_FIRST_32_BITS_V1");
verifyEqual(t,m.posture_reference_sha256,myoFileSHA256(myoPostureAssetPath(m.posture_reference_asset)));
verifyEqual(t,m.random_seed,a.Protocol.randomization_seed(1));verifyNotEmpty(t,m.acquisition_code_hashes);
saved=jsondecode(fileread(fullfile(a.Session.Directory,'metadata.json')));
verifyEqual(t,saved.random_seed,m.random_seed);verifyEqual(t,string(saved.posture_reference_sha256),m.posture_reference_sha256);
a.finishSession();
end
function testBackendRejectsMissingOfficialChecksWithoutCreatingSession(t)
[a,src,root]=app(t);ready(a,src);a.startSession();m=a.Session.Metadata;p=a.Protocol;a.finishSession();a.newSession();
m.session_id=a.Reservation.session_id;m.session_uuid=a.Reservation.session_uuid;m.random_seed=a.Reservation.random_seed;
p=buildMyoOfficialProtocol(m.random_seed); %#ok<NASGU>
for field=["arm_confirmed","myo_fit_confirmed","myo_orientation_confirmed","stabilization_confirmed"]
 bad=m;bad.(field)=false;
 verifyError(t,@()MyoAcquisitionSession(src,root,bad,p),'MyoSession:OfficialPlacement');
 verifyFalse(t,isfolder(fullfile(root,m.participant_id,m.session_id)));
end
bad=m;bad.random_seed=mod(m.random_seed+1,2^32);pbad=buildMyoOfficialProtocol(bad.random_seed);
verifyError(t,@()MyoAcquisitionSession(src,root,bad,pbad),'MyoRegistry:Seed');
end
function testSessionSeedDeterministicFullUint32AndNoGlobalRNGMutation(t)
before=rng;
verifyEqual(t,myoSessionSeed("00000000-1234-4234-8234-123456789abc"),0);
verifyEqual(t,myoSessionSeed("FFFFFFFF-1234-4234-8234-123456789abc"),2^32-1);
verifyEqual(t,myoSessionSeed("12345678-1234-4234-8234-123456789abc"),hex2dec('12345678'));
verifyEqual(t,rng,before);verifyError(t,@()myoSessionSeed("not-a-uuid"),'MyoSession:UUID');
end
function testReservationSeedPersistsWithoutRegistryMigration(t)
root=string(tempname);r=MyoParticipantRegistry(root);id=r.create(r.nextID());s=r.reserveSession(id,"MYO_OPEN_CLOSE_OFFICIAL_V1");
file=fullfile(root,'session_reservations.csv');hash=myoFileSHA256(file);r2=MyoParticipantRegistry(root);
again=r2.getReservation(id,s.session_id,s.campaign_id);verifyEqual(t,again,s);
verifyEqual(t,r2.pendingSession(id,s.campaign_id),s);verifyEqual(t,myoFileSHA256(file),hash);
rows=readtable(file);verifyEqual(t,width(rows),5);
end
function testGUIRestartRecoversPendingSessionAndOrderWithoutWriting(t)
[a,~,root]=app(t);id=a.createParticipant();a.newSession();s=a.Reservation;p=a.Protocol;
file=fullfile(root,'session_reservations.csv');before=myoFileSHA256(file);delete(a);
[b,~,~]=app(t,MockMyoDataSource(),root);verifyEqual(t,b.Reservation,s);verifyEqual(t,b.Protocol,p);
verifyEqual(t,string(b.Participant.Value),id);verifyEqual(t,string(b.SessionID.Value),s.session_id);
verifyEmpty(t,b.SetupConfirmation);verifyFalse(t,b.QualityComplete);verifyEqual(t,myoFileSHA256(file),before);
end
function testUsedSessionsAreNeverRecoveredOrOverwritten(t)
[a,src,root]=app(t);ready(a,src);a.startSession();first=a.Reservation;a.finishSession();delete(a);
[b,~,~]=app(t,MockMyoDataSource(),root);verifyEmpty(t,b.Reservation);b.newSession();
verifyEqual(t,b.Reservation.session_id,"S002");verifyNotEqual(t,b.Reservation.session_uuid,first.session_uuid);
verifyTrue(t,isfolder(fullfile(root,first.participant_id,first.session_id)));
end
function testDifferentSessionUUIDsProduceReproducibleBalancedOrders(t)
seeds=[myoSessionSeed("12345678-1234-4234-8234-123456789abc"),myoSessionSeed("87654321-1234-4234-8234-123456789abc")];
first=buildMyoOfficialProtocol(seeds(1));second=buildMyoOfficialProtocol(seeds(2));
verifyEqual(t,buildMyoOfficialProtocol(seeds(1)),first);verifyNotEqual(t,first.condition_id,second.condition_id);
verifyEqual(t,sort(first.condition_id),sort(second.condition_id));
end
function testPracticeUsesSameCuesAndTimingWithoutWriting(t)
[a,src,root]=app(t);a.startPractice();verifyEmpty(t,a.Session);verifyEmpty(t,a.Reservation);verifyFalse(t,src.Connected);
p=a.PracticeProtocol;active=p.condition=="MOVEMENT";verifyEqual(t,nnz(active),8);
verifyEqual(t,p.move_s(active),4*p.movement_level(active));
for k=find(active)'
 row=table2struct(p(k,:));verifyEqual(t,a.CueEngine.cue(row,2+row.move_s).target,row.target_end);
end
a.advancePractice(sum(p.duration_s));verifyFalse(t,isfolder(root));
end
function testPrecheckInstructionsAreDiagnosticOnly(t)
verifyTrue(t,contains(myoPrecheckInstruction(0),"REPOSO"));
verifyTrue(t,contains(myoPrecheckInstruction(8),"ABRE"));
verifyTrue(t,contains(myoPrecheckInstruction(15),"CIERRA"));
verifyTrue(t,contains(myoPrecheckInstruction(22),"REPOSO"));
[a,src,root]=app(t);a.createParticipant();a.newSession();a.connect();confirm(a);a.testSignal();
verifyEqual(t,string(a.InstructionLabel.Text),"DIAGNÓSTICO DE SEÑAL");verifyTrue(t,contains(a.PracticeBanner.Text,'NO ES UN TRIAL CIENTÍFICO'));
src.advance(30);a.pulse();verifyEmpty(t,a.Session);verifyFalse(t,isfolder(fullfile(root,a.Reservation.participant_id,a.Reservation.session_id)));
end
function testFlatWarningRequiresReviewBeforeStart(t)
[a,src,~]=app(t,MockMyoPrecheckSource());ready(a,src);
verifyTrue(t,a.QualityComplete);verifyTrue(t,a.QualityAssessment.requires_review);verifyFalse(t,a.QualityReviewAccepted);
verifyTrue(t,contains(a.QualityAssessment.message,'CH1'));verifyEqual(t,string(a.Buttons.Start.Enable),"off");
verifyError(t,@()a.startSession(),'MyoGUI:QualityReviewRequired');
a.acceptQualityReview();verifyEqual(t,string(a.Buttons.Start.Enable),"on");a.startSession();
verifyTrue(t,a.Session.Metadata.quality_warnings_reviewed);a.finishSession();
end
function testClippingWarningIsDisplayedAndNotSilentlyAccepted(t)
src=MockMyoPrecheckSource();src.Mode="clipped";[a,~,~]=app(t,src);ready(a,src);
verifyTrue(t,contains(a.QualityAssessment.message,'CH2'));verifyTrue(t,any(a.QualityAssessment.significant_warnings=="CLIPPING_OVER_1_PERCENT"));
verifyFalse(t,a.QualityReviewAccepted);verifyEqual(t,string(a.Buttons.Start.Enable),"off");
a.acceptQualityReview();verifyEqual(t,string(a.Buttons.Start.Enable),"on");
end
function testSignalErrorsCannotBeAcknowledgedAway(t)
src=MockMyoPrecheckSource();src.Mode="nonfinite";[a,~,~]=app(t,src);ready(a,src);
verifyFalse(t,a.QualityComplete);verifyTrue(t,a.QualityAssessment.has_errors);
verifyError(t,@()a.acceptQualityReview(),'MyoGUI:QualityErrors');verifyEqual(t,string(a.Buttons.Start.Enable),"off");
end
function testSmallRateVariationDoesNotTriggerNewThreshold(t)
time=(1:5900)'/197;raw=.15*sin(time*(7:14));q=computeMyoQualityMetrics(time,raw,30);
review=myoPrecheckReview(q);verifyFalse(t,review.has_errors);verifyFalse(t,review.requires_review);
verifyTrue(t,contains(review.message,'No hay un detector automático'));
end
function testRetestingClearsPreviousWarningAcknowledgement(t)
[a,src,~]=app(t,MockMyoPrecheckSource());ready(a,src);a.acceptQualityReview();a.testSignal();
verifyFalse(t,a.QualityReviewAccepted);verifyEmpty(t,a.QualityAssessment);verifyEqual(t,string(a.Buttons.Start.Enable),"off");
end
function testLegacyPostureAssetsAndPilotProtocolRemainReadable(t)
c=myoCampaignConfig();asset=myoPostureAssetPath(c.posture_reference_asset);verifyTrue(t,isfile(asset));
p=buildMyoCampaignProtocol();verifyTrue(t,all(p.arm_posture_id=="P0_FORWARD_EXTENDED"));validateMyoPilot2Protocol(p);
p=buildMyoPilot2Protocol();verifyTrue(t,all(p.arm_posture_id=="P0_NEUTRAL_90"));validateMyoPilot2Protocol(p);
end
function testAssetRegenerationPreservesLegacyManifestAndInstalledJPG(t)
c=myoOfficialCampaignConfig();image=myoPostureAssetPath(c.posture_reference_asset);before=myoFileSHA256(image);
manifest=fullfile(c.asset_root,'cues_manifest.json');original=myoFileSHA256(manifest);root=string(tempname);
prepareMyoCampaignAssets(root);verifyEqual(t,myoFileSHA256(fullfile(root,'cues_manifest.json')),original);
verifyEqual(t,myoFileSHA256(image),before);verifyFalse(t,isfile(fullfile(root,'postures','P0_SEATED_ARMREST.png')));
end
function testOfficialModalControlsAndImageFitAt768Pixels(t)
[a,~,~]=app(t);a.Figure.WindowState='normal';a.Figure.Position=[0 0 1366 768];a.createParticipant();a.newSession();a.reviewSetup();drawnow;
verifyLessThanOrEqual(t,a.SetupDialog.Position(4),700);verifyEqual(t,numel(fieldnames(a.SetupChecks)),10);
verifyGreaterThanOrEqual(t,a.Buttons.Test.Position(4),28);
for field=string(fieldnames(a.SetupChecks))',verifyFalse(t,a.SetupChecks.(field).Value);end
end
