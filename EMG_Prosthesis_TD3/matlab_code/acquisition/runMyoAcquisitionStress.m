function summary=runMyoAcquisitionStress(outputRoot,o)
% SOLO MOCK: miles de promociones y una sesion larga con reloj acelerado.
arguments
 outputRoot (1,1) string = string(tempname)
 o.Iterations (1,1) double {mustBePositive,mustBeInteger} = 1000
 o.Repetitions (1,1) double {mustBePositive,mustBeInteger} = 10
end
assert(~isfolder(outputRoot),'MyoStress:Exists','Usar una carpeta nueva.');mkdir(outputRoot);
clock=tic;replacements=fullfile(outputRoot,'replacements');mkdir(replacements);
fallbacks=0;
for k=1:o.Iterations
 myoWriteJSONAtomic(fullfile(replacements,'status.json'),struct('iteration',k,'valid',true));
 trial=struct('iteration',k,'values',(1:8)+k); %#ok<NASGU>
 tmp=fullfile(replacements,'recovery.tmp.mat');save(tmp,'trial','-v7');d=load(tmp);assert(isequaln(trial,d.trial));
 r=myoAtomicPromote(tmp,fullfile(replacements,'recovery.mat'),true);fallbacks=fallbacks+r.fallback_used;
 T=table(k,k*8,VariableNames={'iteration','count'});tmp=fullfile(replacements,'manifest.tmp.csv');writetable(T,tmp);
 r=myoAtomicPromote(tmp,fullfile(replacements,'manifest.csv'),true);fallbacks=fallbacks+r.fallback_used;
 assert(jsondecode(fileread(fullfile(replacements,'status.json'))).iteration==k);
 d=load(fullfile(replacements,'recovery.mat'));assert(isequaln(d.trial,trial));
 assert(isequal(readtable(fullfile(replacements,'manifest.csv')),T));
end
source=MockMyoDataSource();source.connect();cleanup=onCleanup(@()source.disconnect()); %#ok<NASGU>
p=buildMyoContinuousProtocol(repetitions=o.Repetitions,includeRamps=false,holdSeconds=3,restSeconds=6);
m=struct('participant_id','MOCK','session_id','STRESS','placement_id','P1','arm','right');
s=MyoAcquisitionSession(source,outputRoot,m,p);s.start();ticks=0;
while s.Status=="RUNNING"
 source.advance(.25);s.tick();ticks=ticks+1;
end
assert(s.Status=="FINISHED"&&s.Index==height(p)+1);
T=readtable(fullfile(s.Directory,'session_manifest.csv'),TextType='string');assert(height(T)==height(p));
for k=1:height(T)
 f=fullfile(s.Directory,T.file(k));d=load(f);assert(validateMyoTrial(d.trial).schema_valid);
 assert(myoFileSHA256(f)==T.sha256(k));assert(d.trial.sample_count==T.sample_count(k));
 assert(~d.trial.source_info.scientific_data);
end
f=fullfile(s.Directory,T.file(1));d=load(f);sha=myoFileSHA256(f);blocked=false;
try,saveMyoTrialAtomic(s.Directory,d.trial);catch ex,blocked=strcmp(ex.identifier,'MyoSave:NoOverwrite');end
assert(blocked&&myoFileSHA256(f)==sha);
temps=dir(fullfile(outputRoot,'**','*.tmp*'));assert(isempty(temps),'MyoStress:Orphans','Hay temporales tras exito.');
summary=struct('result','PASS','mock_only',true,'replacement_iterations',o.Iterations,'explicit_promotions',3*o.Iterations, ...
 'fallbacks_mat_csv',fallbacks,'simulated_seconds',source.now(),'session_ticks',ticks,'trials',height(T), ...
 'sample_count',sum(T.sample_count),'trial_overwrite_blocked',blocked,'orphan_temps',numel(temps), ...
 'wall_seconds',toc(clock),'real_hardware_started',false,'output_directory',outputRoot);
myoWriteJSONAtomic(fullfile(outputRoot,'stress_summary.json'),summary);disp(summary);
end
