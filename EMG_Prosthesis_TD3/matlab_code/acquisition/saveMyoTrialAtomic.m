function [file,row] = saveMyoTrialAtomic(sessionDir,trial)
validateMyoTrial(trial);
folder=fullfile(sessionDir,"trials");if ~isfolder(folder),mkdir(folder);end
file=fullfile(folder,compose("trial_%04d.mat",trial.trial_id));
assert(~isfile(file),"MyoSave:NoOverwrite","Datos o estado incompatibles con MyoSave:NoOverwrite.");
temp=fullfile(folder,"."+compose("trial_%04d",trial.trial_id)+"_"+string(java.util.UUID.randomUUID())+".tmp.mat");
save(temp,"trial","-v7");persisted=load(temp,"trial");validateMyoTrial(persisted.trial);
assert(isequaln(trial,persisted.trial),"MyoSave:RoundTrip","Datos o estado incompatibles con MyoSave:RoundTrip.");
myoAtomicPromote(temp,file,false);
row=myoManifestRow(trial,file);
manifest=fullfile(sessionDir,"session_manifest.csv");
if isfile(manifest),T=readtable(manifest,TextType="string");else,T=table();end
assert(isempty(T)||~any(T.trial_id==trial.trial_id),"MyoSave:ManifestDuplicate","Datos o estado incompatibles con MyoSave:ManifestDuplicate.");
T=[T;struct2table(row)];
tmp=fullfile(sessionDir,"manifest_"+string(java.util.UUID.randomUUID())+".tmp.csv");
writetable(T,tmp);myoAtomicPromote(tmp,manifest,true);
end
