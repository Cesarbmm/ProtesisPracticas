function report = recoverMyoSession(sessionDir)
% Recuperar artefactos persistidos, no continuar ni concatenar una contraccion.
metadata=jsondecode(fileread(fullfile(sessionDir,"metadata.json")));
recovery=fullfile(sessionDir,"recovery","active_trial.mat");recovered=false;
if isfile(recovery)
 d=load(recovery,"trial");t=d.trial;validateMyoTrial(t);
 assert(string(t.participant_id)==string(metadata.participant_id)&&string(t.session_id)==string(metadata.session_id)&&string(t.placement_id)==string(metadata.placement_id),"MyoRecovery:Identity","Datos o estado incompatibles con MyoRecovery:Identity.");
 destination=fullfile(sessionDir,"trials",compose("trial_%04d.mat",t.trial_id));
 if ~isfile(destination)
  t.status="RECOVERED_PARTIAL";
  % Antes de anadir, reconstruir un manifest que pudiera haber quedado incompleto.
  rebuild();saveMyoTrialAtomic(sessionDir,t);recovered=true;
 end
end
T=rebuild();report=struct("trials",height(T),"active_prefix_recovered",recovered,"training_started",false);
myoWriteJSONAtomic(fullfile(sessionDir,"recovery_report.json"),report);
 function T=rebuild()
  files=dir(fullfile(sessionDir,"trials","trial_*.mat"));T=table();
  for f=files'
   file=fullfile(f.folder,f.name);d=load(file,"trial");validateMyoTrial(d.trial);
   assert(string(d.trial.session_id)==string(metadata.session_id)&&string(d.trial.placement_id)==string(metadata.placement_id),"MyoRecovery:Identity","Datos o estado incompatibles con MyoRecovery:Identity.");
   T=[T;struct2table(myoManifestRow(d.trial,file))]; %#ok<AGROW>
  end
  if ~isempty(T)
   T=sortrows(T,"trial_id");temp=fullfile(sessionDir,"manifest_recovery_"+string(java.util.UUID.randomUUID())+".tmp.csv");
   writetable(T,temp);myoAtomicPromote(temp,fullfile(sessionDir,"session_manifest.csv"),true);
  end
 end
end
