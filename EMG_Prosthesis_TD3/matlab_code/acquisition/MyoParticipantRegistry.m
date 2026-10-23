classdef MyoParticipantRegistry
 % Identidad canónica y reservas durables. Consultar no escribe nada.
 properties (SetAccess=private)
  Root
 end
 methods
  function obj=MyoParticipantRegistry(root),obj.Root=string(root);end
  function initialize(obj)
   lock=myoAcquireDataLock(obj.Root); %#ok<NASGU>
   rows=obj.list();myoWriteTableAtomic(obj.registryFile(),rows);
   for k=1:height(rows)
    file=fullfile(obj.Root,rows.participant_id(k),'participant.json');
    if ~isfile(file)
     if ~isfolder(fileparts(file)),mkdir(fileparts(file));end
     myoWriteJSONAtomic(file,table2struct(rows(k,:)));
    end
   end
  end
  function rows=list(obj)
   rows=obj.readRegistry();ids=obj.folderIDs();
   for id=ids'
    if ~any(rows.participant_id==id),rows=[rows;{id,"","legacy","",""}];end %#ok<AGROW>
   end
   rows=sortrows(rows,'participant_id');
  end
  function id=nextID(obj)
   rows=obj.list();nums=zeros(height(rows),1);
   for k=1:height(rows),nums(k)=str2double(extractAfter(rows.participant_id(k),1));end
   id=compose("P%03d",max([0;nums])+1);
  end
  function id=create(obj,expected,alias,notes)
   arguments
    obj
    expected (1,1) string
    alias (1,1) string = ""
    notes (1,1) string = ""
   end
   lock=myoAcquireDataLock(obj.Root); %#ok<NASGU>
   rows=obj.list();id=obj.nextID();
   assert(id==expected,'MyoRegistry:PreviewChanged','Otra reserva cambió el siguiente ID; revisar y confirmar de nuevo.');
   rows=[rows;{id,obj.utc(),"reserved",alias,notes}];
   myoWriteTableAtomic(obj.registryFile(),rows); % Reserva antes de crear carpeta.
   folder=fullfile(obj.Root,id);mkdir(folder);
   myoWriteJSONAtomic(fullfile(folder,'participant.json'),struct('participant_id',id,'created_utc',rows.created_utc(end),'status',"active",'optional_alias',alias,'notes',notes));
   rows.status(end)="active";myoWriteTableAtomic(obj.registryFile(),rows);
  end
  function setStatus(obj,id,status)
   assert(ismember(status,["active","inactive","withdrawn"]),'MyoRegistry:Status','Estado no permitido.');
   lock=myoAcquireDataLock(obj.Root); %#ok<NASGU>
   rows=obj.list();idx=find(rows.participant_id==id);assert(isscalar(idx),'MyoRegistry:Participant','Participante desconocido.');
   rows.status(idx)=status;myoWriteTableAtomic(obj.registryFile(),rows);
   % El registro es la autoridad; nunca eliminar una fila ni reutilizar su ID.
  end
  function info=describe(obj,id)
   rows=obj.list();idx=find(rows.participant_id==id);assert(isscalar(idx),'MyoRegistry:Participant','Participante desconocido.');
   sessions=dir(fullfile(obj.Root,id,'S*'));sessions=sessions([sessions.isdir]);
   sessions=sessions(~cellfun(@isempty,regexp({sessions.name},'^S\d+$','once')));
   last="";placement="";
   if ~isempty(sessions)
    [~,j]=max([sessions.datenum]);last=string(datetime(sessions(j).datenum,ConvertFrom='datenum',Format='yyyy-MM-dd HH:mm'));
    file=fullfile(sessions(j).folder,sessions(j).name,'metadata.json');
    if isfile(file)
     m=jsondecode(fileread(file));if isfield(m,'placement_id'),placement=string(m.placement_id);end
     if isfield(m,'capture_utc'),last=string(m.capture_utc);elseif isfield(m,'created_utc'),last=string(m.created_utc);end
    end
   end
   info=struct('participant_id',id,'optional_alias',rows.optional_alias(idx),'session_count',numel(sessions), ...
    'last_session_utc',last,'previous_placement',placement,'status',rows.status(idx));
  end
  function reservation=reserveSession(obj,id,campaign)
   lock=myoAcquireDataLock(obj.Root); %#ok<NASGU>
   rows=obj.list();idx=find(rows.participant_id==id);
   assert(isscalar(idx)&&ismember(rows.status(idx),["active","legacy"]),'MyoRegistry:Participant','Seleccionar un participante activo.');
   myoWriteTableAtomic(obj.registryFile(),rows); % Registrar también IDs históricos.
   file=fullfile(obj.Root,'session_reservations.csv');r=obj.readReservations();
   dirs=dir(fullfile(obj.Root,id,'S*'));numbers=0;
   for d=dirs'
    if d.isdir&&~isempty(regexp(d.name,'^S\d+$','once')),numbers(end+1)=str2double(d.name(2:end));end %#ok<AGROW>
   end
   reserved=r.session_id(r.participant_id==id);
   for sid=reserved',numbers(end+1)=str2double(extractAfter(sid,1));end %#ok<AGROW>
   sid=compose("S%03d",max(numbers)+1);uuid=string(java.util.UUID.randomUUID());time=obj.utc();
   r=[r;{id,sid,uuid,campaign,time}];myoWriteTableAtomic(file,r);
   participantFile=fullfile(obj.Root,id,'participant.json');
   if ~isfile(participantFile)
    if ~isfolder(fileparts(participantFile)),mkdir(fileparts(participantFile));end
    myoWriteJSONAtomic(participantFile,table2struct(rows(idx,:)));
   else
    identity=jsondecode(fileread(participantFile));
    assert(string(identity.participant_id)==id,'MyoRegistry:ImmutableID','participant.json no corresponde a su ID canónico.');
   end
   reservation=struct('participant_id',id,'session_id',sid,'session_uuid',uuid,'campaign_id',campaign,'reserved_utc',time, ...
    'random_seed',myoSessionSeed(uuid),'seed_derivation',"UUID_FIRST_32_BITS_V1");
  end
  function reservation=getReservation(obj,id,sid,campaign)
   rows=obj.readReservations();idx=find(rows.participant_id==id&rows.session_id==sid&rows.campaign_id==campaign);
   assert(isscalar(idx),'MyoRegistry:Reservation','Reserva no encontrada o duplicada.');
   reservation=table2struct(rows(idx,:));reservation.random_seed=myoSessionSeed(reservation.session_uuid);
   reservation.seed_derivation="UUID_FIRST_32_BITS_V1";
  end
  function reservation=pendingSession(obj,id,campaign)
   % Sólo lectura: recuperar una reserva sin sesión creada, nunca sobrescribir.
   rows=obj.readReservations();reservation=[];
   for idx=height(rows):-1:1
    if rows.participant_id(idx)==id&&rows.campaign_id(idx)==campaign&&~isfolder(fullfile(obj.Root,id,rows.session_id(idx)))
     reservation=obj.getReservation(id,rows.session_id(idx),campaign);return
    end
   end
  end
  function verifyReservation(obj,m)
   rows=obj.readReservations();valid=rows.participant_id==string(m.participant_id)&rows.session_id==string(m.session_id)& ...
    rows.session_uuid==string(m.session_uuid)&rows.campaign_id==string(m.campaign_id);
   assert(nnz(valid)==1,'MyoRegistry:Reservation','Reserva de sesión/UUID no válida.');
   if isfield(m,'session_seed_source')
    assert(string(m.session_seed_source)=="UUID_FIRST_32_BITS_V1"&&m.random_seed==myoSessionSeed(m.session_uuid), ...
     'MyoRegistry:Seed','Seed no corresponde al UUID reservado.');
   end
  end
 end
 methods (Access=private)
  function file=registryFile(obj),file=fullfile(obj.Root,'participants_registry.csv');end
  function rows=readRegistry(obj)
   rows=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5),'VariableNames',{'participant_id','created_utc','status','optional_alias','notes'});
   if isfile(obj.registryFile()),rows=readtable(obj.registryFile(),TextType='string',ReadVariableNames=true,Delimiter=',',Format=repmat('%q',1,5));end
   for f=string(rows.Properties.VariableNames),missing=ismissing(rows.(f));rows.(f)=string(rows.(f));rows.(f)(missing)="";end
   assert(numel(unique(rows.participant_id))==height(rows)&&all(~cellfun(@isempty,regexp(cellstr(rows.participant_id),'^P\d{3,}$','once'))), ...
    'MyoRegistry:Corrupt','IDs duplicados/no canónicos en el registro.');
  end
  function ids=folderIDs(obj)
   dirs=dir(fullfile(obj.Root,'P*'));dirs=dirs([dirs.isdir]);names=string({dirs.name})';
   ids=names(~cellfun(@isempty,regexp(cellstr(names),'^P\d{3,}$','once')));
  end
  function rows=readReservations(obj)
   rows=table('Size',[0 5],'VariableTypes',repmat({'string'},1,5),'VariableNames',{'participant_id','session_id','session_uuid','campaign_id','reserved_utc'});
   file=fullfile(obj.Root,'session_reservations.csv');if isfile(file),rows=readtable(file,TextType='string',ReadVariableNames=true,Delimiter=',',Format=repmat('%q',1,5));end
  end
 end
 methods (Static, Access=private)
  function value=utc(),value=string(datetime('now',TimeZone='UTC',Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));end
 end
end
