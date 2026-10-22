function tests=testMyoAcquisitionV1
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
old=path;t.addTeardown(@()path(old));addpath(fullfile(t.TestData.root,'acquisition'));
end
function [a,src,folder]=app(t,varargin)
src=MockMyoDataSource();folder=string(tempname);
p=buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3,restSeconds=6);
a=MyoContinuousAcquisitionApp('Source',src,'Protocol',p,'OutputRoot',folder,'Visible','off','AutoTimer',false,varargin{:});
t.addTeardown(@()delete(a));
end
function [tmp,dst]=files
folder=string(tempname);mkdir(folder);tmp=fullfile(folder,'new.tmp');dst=fullfile(folder,'state.json');
write(tmp,'new');write(dst,'old');
end
function write(file,txt)
f=fopen(file,'w');fwrite(f,txt);fclose(f);
end
function move(from,to,replace,atomic)
opts=javaArray('java.nio.file.CopyOption',double(replace)+double(atomic));
if replace,opts(1)=java.nio.file.StandardCopyOption.REPLACE_EXISTING;end
if atomic,opts(2)=java.nio.file.StandardCopyOption.ATOMIC_MOVE;end
java.nio.file.Files.move(from,to,opts);
end
function testNioReplaceContentAndNoOrphan(t)
[tmp,dst]=files;r=myoAtomicPromote(tmp,dst,true);
verifyEqual(t,string(fileread(dst)),"new");verifyFalse(t,isfile(tmp));verifyFalse(t,r.fallback_used);
verifyEqual(t,r.sha256,myoFileSHA256(dst));
end
function testNeverOverwriteFinal(t)
[tmp,dst]=files;verifyError(t,@()myoAtomicPromote(tmp,dst,false),'MyoSave:NoOverwrite');
verifyEqual(t,string(fileread(dst)),"old");verifyTrue(t,isfile(tmp));
end
function testBoundedTransientRetry(t)
[tmp,dst]=files;count=0;
r=myoAtomicPromote(tmp,dst,true,MoveFunction=@flaky,BackoffSeconds=0);
verifyEqual(t,count,3);verifyEqual(t,r.attempts,3);verifyEqual(t,string(fileread(dst)),"new");
 function flaky(from,to,replace,atomic)
  count=count+1;if count<3,error('MyoSaveTest:TransientLock','Lock simulado.');end
  move(from,to,replace,atomic);
 end
end
function testExplicitUnsupportedFallback(t)
[tmp,dst]=files;count=0;
w=warning('off','MyoSave:NonAtomicFallback');c=onCleanup(@()warning(w)); %#ok<NASGU>
r=myoAtomicPromote(tmp,dst,true,MoveFunction=@unsupported);
verifyTrue(t,r.fallback_used);verifyEqual(t,count,2);verifyFalse(t,isfile(tmp));
 function unsupported(from,to,replace,atomic)
  count=count+1;if atomic,error('MyoSaveTest:AtomicUnsupported','ATOMIC_MOVE no soportado.');end
  move(from,to,replace,atomic);
 end
end
function testPermanentErrorPreservesEvidence(t)
[tmp,dst]=files;count=0;
verifyError(t,@()myoAtomicPromote(tmp,dst,true,MoveFunction=@failed),'MyoSave:PromotionFailed');
verifyEqual(t,count,1);verifyEqual(t,string(fileread(dst)),"old");verifyTrue(t,isfile(tmp));
 function failed(varargin)
  count=count+1;error('MyoSaveTest:DiskFailure','Disco fallido.');
 end
end
function testExhaustedRetriesAreExplicit(t)
[tmp,dst]=files;count=0;
verifyError(t,@()myoAtomicPromote(tmp,dst,true,MoveFunction=@failed,MaxAttempts=3,BackoffSeconds=0),'MyoSave:PromotionFailed');
verifyEqual(t,count,3);verifyEqual(t,string(fileread(dst)),"old");verifyTrue(t,isfile(tmp));
 function failed(varargin)
  count=count+1;error('MyoSaveTest:TransientLock','Lock persistente.');
 end
end
function testWindowsRealExclusiveLock(t)
assumeTrue(t,ispc);[tmp,dst]=files;
stream=System.IO.File.Open(char(dst),System.IO.FileMode.Open,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None);
c=onCleanup(@()stream.Dispose());
verifyError(t,@()myoAtomicPromote(tmp,dst,true,MaxAttempts=3,BackoffSeconds=.01),'MyoSave:PromotionFailed');
verifyTrue(t,isfile(tmp));clear c
verifyEqual(t,string(fileread(dst)),"old");myoAtomicPromote(tmp,dst,true);verifyEqual(t,string(fileread(dst)),"new");
end
function testSameDirectoryAndDifferentFile(t)
[tmp,dst]=files;verifyError(t,@()myoAtomicPromote(tmp,tmp,true),'MyoSave:SameFile');
verifyError(t,@()myoAtomicPromote(tmp,fullfile(fileparts(fileparts(dst)),'other.json'),true),'MyoSave:DifferentDirectory');
end
function testReducedProtocolUnchanged(t)
p=buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3,restSeconds=6);
verifyEqual(t,height(p),9);verifyEqual(t,p.condition, ["REST";"HOLD";"REST";"HOLD";"REST";"HOLD";"REST";"HOLD";"REST"]);
verifyEqual(t,p.target_end(2:2:8),[.25;.5;.75;1]);verifyEqual(t,p.prepare_s(2:2:8),repmat(2,4,1));
verifyEqual(t,p.ramp_s(2:2:8),repmat(2,4,1));verifyEqual(t,p.duration_s(2:2:8),repmat(7,4,1));
end
function testOpeningPhaseInstructions(t)
p=buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3);r=table2struct(p(4,:));
v=myoParticipantInstruction(r,0);verifyEqual(t,v.instruction,"CIERRA LA MANO");verifyEqual(t,string(v.detail),"Posición inicial 0 %");
v=myoParticipantInstruction(r,3);verifyEqual(t,v.instruction,"ABRE PROGRESIVAMENTE HASTA 50 %");verifyEqual(t,v.target,.25);verifyEqual(t,v.remaining,1);
v=myoParticipantInstruction(r,5);verifyEqual(t,v.instruction,"MANTÉN 50 %");verifyEqual(t,v.remaining,2);
end
function testClosingInstructionsAndCountdown(t)
p=buildMyoContinuousProtocol(repetitions=1);r=table2struct(p(find(p.direction=="closing",1),:));
v=myoParticipantInstruction(r,0);verifyEqual(t,v.instruction,"ABRE LA MANO");
v=myoParticipantInstruction(r,3);verifyEqual(t,v.instruction,"CIERRA PROGRESIVAMENTE HASTA 75 %");
v=myoParticipantInstruction(r,r.duration_s);verifyEqual(t,v.instruction,"MANTÉN 75 %");verifyEqual(t,v.remaining,0);
end
function testRestInstructionNeverImpliesZero(t)
p=buildMyoContinuousProtocol();v=myoParticipantInstruction(table2struct(p(1,:)),2);
verifyEqual(t,v.instruction,"RELAJA LA MANO");verifyEqual(t,v.detail,"REST no equivale a 0 %");verifyTrue(t,isnan(v.target));
end
function testPracticeCreatesNoSessionOrDirectory(t)
[a,src,folder]=app(t);a.startPractice();verifyEqual(t,a.UIState,"PRÁCTICA");verifyFalse(t,src.Connected);
verifyTrue(t,contains(a.PracticeBanner.Text,'NO SE GUARDAN'));verifyEqual(t,string(a.Buttons.Start.Enable),"off");
a.advancePractice(6);verifyEqual(t,a.InstructionLabel.Text,'CIERRA LA MANO');a.advancePractice(3);
verifyTrue(t,contains(a.InstructionLabel.Text,'25 %'));verifyEmpty(t,a.Session);verifyFalse(t,isfolder(folder));
a.advancePractice(100);verifyFalse(t,a.PracticeActive);verifyFalse(t,isfolder(folder));
end
function testPracticeBlocksRealStart(t)
[a,~,folder]=app(t);a.startPractice();verifyError(t,@()a.startSession(),'MyoGUI:PracticeActive');verifyFalse(t,isfolder(folder));
end
function testGUIStatesAndQualityGate(t)
[a,src]=app(t);verifyEqual(t,a.UIState,"DESCONECTADO");verifyEqual(t,string(a.Buttons.Start.Enable),"off");
a.connect();verifyEqual(t,a.UIState,"CONECTADO");a.testSignal();verifyEqual(t,a.UIState,"PRECHECK");
src.advance(29);a.pulse();verifyFalse(t,a.QualityComplete);verifyEqual(t,string(a.Buttons.Start.Enable),"off");
src.advance(1);a.pulse();verifyEqual(t,a.UIState,"LISTO");verifyEqual(t,string(a.Buttons.Start.Enable),"on");
a.startSession();verifyEqual(t,a.UIState,"CAPTURANDO");src.advance(.1);a.pulse();a.pauseSession();verifyEqual(t,a.UIState,"PAUSA");
a.startSession();verifyEqual(t,a.UIState,"CAPTURANDO");a.abortSession();verifyEqual(t,a.UIState,"FINALIZADO");
end
function testFinishWithoutSessionDoesNotClaimSaved(t)
[a,~,folder]=app(t);a.finishSession();verifyTrue(t,contains(a.StatusLabel.Text,'sin sesión'));
verifyFalse(t,contains(a.StatusLabel.Text,'datos guardados'));verifyFalse(t,isfolder(folder));verifyEqual(t,a.UIState,"FINALIZADO");
end
function testGUIWindowNormalMaximizedSafeClose(t)
[a,~]=app(t);verifyEqual(t,string(a.Figure.WindowState),"maximized");verifyEqual(t,string(a.Figure.WindowStyle),"normal");
verifyEqual(t,string(a.Figure.Resize),"on");verifyNotEmpty(t,a.Figure.CloseRequestFcn);
end
function testAssetAbsentFallsBack(t)
[a,~,folder]=app(t,AssetRoot=string(tempname));a.startPractice();verifyEqual(t,string(a.GuideFallback.Visible),"on");
verifyEqual(t,string(a.GuideImage.Visible),"off");verifyFalse(t,isfolder(folder));
end
function testAssetPresentUsesUiimage(t)
asset=string(tempname);mkdir(asset);imwrite(uint8(ones(8,8,3)*100),fullfile(asset,'Reposo.png'));
[a,~]=app(t,AssetRoot=asset);a.startPractice();verifyEqual(t,string(a.GuideImage.Visible),"on");
verifyEqual(t,a.CurrentAsset,fullfile(asset,'Reposo.png'));verifyEqual(t,string(a.GuideFallback.Visible),"off");
end
function testPilotS02Constructor(t)
[a,~,folder]=app(t,ParticipantID="P001",SessionID="S02",PlacementID="P1");
verifyEqual(t,a.Participant.Value,'P001');verifyEqual(t,a.SessionID.Value,'S02');verifyEqual(t,a.Placement.Value,'P1');verifyFalse(t,isfolder(folder));
end
function testConfiguredProtocolDisplayedCorrectly(t)
[a,~]=app(t);verifyEqual(t,a.Repetitions.Value,1);verifyEqual(t,a.HoldSeconds.Value,3);verifyEqual(t,a.RestSeconds.Value,6);
verifyEqual(t,string(a.HoldSeconds.Enable),"off");
end
function testMyoMexRuntimeProvenancePreserved(t)
s=MyoMexDataSource();c=onCleanup(@()delete(s)); %#ok<NASGU>
info=s.info();f=which('MyoMex');if ~isempty(f),verifyEqual(t,info.myoMex_source_sha256,myoFileSHA256(f));end
f=which('MyoData');if ~isempty(f),verifyEqual(t,info.myoData_source_sha256,myoFileSHA256(f));end
f=which(['myo_mex.' mexext]);if ~isempty(f),verifyEqual(t,info.mex_sha256,myoFileSHA256(f));end
verifyFalse(t,s.Connected);
end
function testAbortedStatusNotOverwrittenByFinish(t)
[a,src]=app(t);a.connect();a.testSignal();src.advance(30);a.pulse();a.startSession();a.abortSession();a.finishSession();
d=jsondecode(fileread(fullfile(a.Session.Directory,'session_status.json')));
verifyEqual(t,string(d.status),"ABORTED");verifyFalse(t,d.protocol_complete);
end
function testGUIErrorCallbackAndSafePrefix(t)
[a,src]=app(t);a.connect();a.testSignal();src.advance(30);a.pulse();a.startSession();src.advance(.1);a.pulse();src.disconnect();
w=warning('off','MyoGUI:Operation');c=onCleanup(@()warning(w)); %#ok<NASGU>
cb=a.Buttons.Pause.ButtonPushedFcn;cb([],[]);
verifyEqual(t,a.UIState,"ERROR");verifyNotEmpty(t,a.LastError);verifyEmpty(t,a.Timer);
verifyTrue(t,isfile(fullfile(a.Session.Directory,'trials','trial_0001.mat')));
end
function testPracticeThenRealBannerChanges(t)
[a,src]=app(t);a.startPractice();a.stopPractice();a.connect();a.testSignal();src.advance(30);a.pulse();a.startSession();
verifyTrue(t,contains(a.PracticeBanner.Text,'CAPTURA ACTIVA'));verifyFalse(t,contains(a.PracticeBanner.Text,'NO SE GUARDAN'));a.abortSession();
end
function testStressManyReplacementsAndLongMock(t)
s=runMyoAcquisitionStress(string(tempname));verifyEqual(t,string(s.result),"PASS");
verifyEqual(t,s.explicit_promotions,3000);verifyGreaterThanOrEqual(t,s.simulated_seconds,500);
verifyEqual(t,s.orphan_temps,0);verifyTrue(t,s.trial_overwrite_blocked);verifyFalse(t,s.real_hardware_started);
end
