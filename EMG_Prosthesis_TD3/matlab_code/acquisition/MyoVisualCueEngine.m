classdef MyoVisualCueEngine
 % Selector sin reloj propio ni decoder de vídeo durante captura.
 properties (SetAccess=private)
  Root
  Sequences
  ManifestHash=""
 end
 methods
  function obj=MyoVisualCueEngine(root)
   obj.Root=string(root);obj.Sequences=struct();file=fullfile(root,'cues_manifest.json');
   if isfile(file)
    m=jsondecode(fileread(file));obj.Sequences=m.sequences;obj.ManifestHash=myoFileSHA256(file);
    obj.verifyIntegrity();
   end
  end
  function verifyIntegrity(obj)
   file=fullfile(obj.Root,'cues_manifest.json');
   assert(isfile(file)&&myoFileSHA256(file)==obj.ManifestHash,'MyoCues:Manifest','Manifest ausente o cambiado. Preparar assets offline.');
   m=jsondecode(fileread(file));
   for k=1:numel(m.files)
    asset=fullfile(obj.Root,m.files(k).file);
    assert(isfile(asset)&&myoFileSHA256(asset)==string(m.files(k).sha256),'MyoCues:Integrity','Frame/asset ausente o modificado: %s.',asset);
   end
  end
  function v=cue(obj,row,elapsed)
   v=myoParticipantInstruction(row,elapsed);v.frame_index=0;v.progress=0;v.asset="";
   if ~isfield(row,'move_s'),return;end
   phase=v.phase;
   if phase=="MOVE"||phase=="HOLD"
    key=string(row.direction)+compose('_%03d',100*row.movement_level);
    if phase=="HOLD",v.progress=1;else,v.progress=min(1,max(0,(elapsed-row.prepare_s)/row.move_s));end
    if isfield(obj.Sequences,key)
     frames=string(obj.Sequences.(key).frames);n=numel(frames);
     v.frame_index=1+floor(v.progress*(n-1));v.asset=fullfile(obj.Root,frames(v.frame_index));
    end
    if row.direction=="opening"
     if phase=="MOVE",v.instruction=compose('ABRE HASTA %.0f %%',100*row.movement_level);
     else,v.instruction=compose('MANTÉN APERTURA %.0f %%',100*row.movement_level);end
    else
     if phase=="MOVE",v.instruction=compose('CIERRA %.0f %%',100*row.movement_level);
     else,v.instruction=compose('MANTÉN CIERRE %.0f %%',100*row.movement_level);end
     if row.movement_level==1&&phase=="HOLD"
      v.instruction="CIERRE COMPLETO CÓMODO — NO APRIETES CON FUERZA";v.detail="Mantén el cierre cómodo; sin fuerza";
     end
    end
   elseif phase=="PREPARE"
    if row.direction=="opening",v.asset=fullfile(obj.Root,'prepare_closed.png');else,v.asset=fullfile(obj.Root,'prepare_open.png');end
   elseif phase=="REST",v.asset=fullfile(obj.Root,'rest_relaxed.png');
   elseif phase=="RELEASE",v.asset=fullfile(obj.Root,'release.png');
   end
   if ~isfile(v.asset),v.asset="";end
  end
 end
end
