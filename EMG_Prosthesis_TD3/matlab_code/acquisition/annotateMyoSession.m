function row=annotateMyoSession(root,source,field,corrected,reason)
% Ledger append-only: no escribe dentro de la sesión fuente.
arguments
 root (1,1) string
 source (1,1) string
 field (1,1) string
 corrected (1,1) string
 reason (1,1) string
end
assert(ismember(field,["participant_id","arm_posture_id","arm","placement_id"]),'MyoAnnotation:Field','Campo no permitido.');
assert(strlength(strtrim(reason))>0&&strlength(strtrim(corrected))>0,'MyoAnnotation:Reason','Corrección y motivo obligatorios.');
base=java.io.File(char(root)).getCanonicalFile().toPath();folder=java.io.File(char(source)).getCanonicalFile().toPath();
assert(folder.startsWith(base)&&~folder.equals(base),'MyoAnnotation:Path','La sesión debe estar dentro de data_acquisition.');
source=string(folder.toString());metadata=fullfile(source,'metadata.json');manifest=fullfile(source,'session_manifest.csv');
assert(isfile(metadata)&&isfile(manifest),'MyoAnnotation:Source','Sesión o manifest no disponible.');
m=jsondecode(fileread(metadata));assert(isfield(m,field),'MyoAnnotation:Field','Campo ausente en metadata original.');
if field=="participant_id"
 registry=MyoParticipantRegistry(root);participants=registry.list();
 assert(any(participants.participant_id==corrected),'MyoAnnotation:Participant','Crear/reservar explícitamente el participante correcto antes de anotarlo.');
end
lock=myoAcquireDataLock(root); %#ok<NASGU>
names={'annotation_id','source_session_path','source_manifest_sha256','source_metadata_sha256','field','original_value','corrected_value','reason','annotation_utc'};
row=table(string(java.util.UUID.randomUUID()),source,myoFileSHA256(manifest),myoFileSHA256(metadata),field,string(m.(field)),corrected,reason, ...
 string(datetime('now',TimeZone='UTC',Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")),'VariableNames',names);
file=fullfile(root,'session_annotations.csv');all=row;
if isfile(file),all=[readtable(file,TextType='string',ReadVariableNames=true,Delimiter=',',Format=repmat('%q',1,9));row];end
myoWriteTableAtomic(file,all);
assert(myoFileSHA256(metadata)==row.source_metadata_sha256&&myoFileSHA256(manifest)==row.source_manifest_sha256,'MyoAnnotation:SourceChanged','La fuente cambió durante la anotación.');
end
