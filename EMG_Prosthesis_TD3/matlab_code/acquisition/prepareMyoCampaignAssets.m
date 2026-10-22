function manifest=prepareMyoCampaignAssets(outputRoot)
% Conversión OFFLINE de assets aprobados existentes, sin generación de imágenes.
% Ejecutar antes de abrir la app. Nunca se invoca desde el loop de captura.
source=string(fullfile(fileparts(mfilename('fullpath')),'references'));
if nargin<1,outputRoot=fullfile(fileparts(mfilename('fullpath')),'assets');end
existing=fullfile(outputRoot,'cues_manifest.json');
if isfile(existing)
 % Un checkout puede traer el manifest sin los frames derivados ignorados.
 % Sólo regenerar si las fuentes aprobadas siguen siendo exactamente iguales.
 previous=jsondecode(fileread(existing));
 for direction=["opening","closing"]
  key=direction+"_100";s=previous.sequences.(key);
  assert(myoFileSHA256(fullfile(source,'Moves',s.source))==string(s.source_sha256),'MyoCues:SourceChanged','Cambió un vídeo aprobado. Revisar antes de regenerar.');
 end
 assert(myoFileSHA256(fullfile(source,'Referencia.jpg'))==string(previous.posture_source_sha256),'MyoCues:SourceChanged','Cambió la referencia aprobada de postura.');
end
if ~isfolder(outputRoot),mkdir(outputRoot);end
if ~isfolder(fullfile(outputRoot,'postures')),mkdir(fullfile(outputRoot,'postures'));end
posture=fullfile(source,'Referencia.jpg');assert(isfile(posture),'MyoCues:Posture','Falta la referencia aprobada.');
% PNG añade tIME por defecto. Fijar sólo ese metadato para regeneración byte a byte;
% la hora real de adquisición vive exclusivamente en metadata de sesión.
imwrite(imread(posture),fullfile(outputRoot,'postures','P0_FORWARD_EXTENDED.png'),'ImageModTime',datenum(2000,1,1));
copyfile(fullfile(source,'PosicionInicial_ManoCerrada.png'),fullfile(outputRoot,'prepare_closed.png'));
copyfile(fullfile(source,'PosicionInicial_ManoAbierta.png'),fullfile(outputRoot,'prepare_open.png'));
sequences=struct();sources=struct();used=strings(0,1);
for direction=["opening","closing"]
 % Auditoría visual: estos nombres describen extremos, no el sentido canónico.
 % Frames 36:106 son el tramo activo revisado; excluir las esperas de los extremos.
 if direction=="opening",name="Cierre-Apertura.mp4";else,name="Apertura-Cierre.mp4";end
 video=fullfile(source,'Moves',name);reader=VideoReader(video);master="master_"+direction;
 folder=fullfile(outputRoot,'frames',master);if ~isfolder(folder),mkdir(folder);end
 frames=strings(0,1);count=0;
 while hasFrame(reader)
  frame=readFrame(reader);count=count+1;
  if count<36||count>106,continue;end
  rel=fullfile('frames',master,compose('frame_%04d.png',count));
  imwrite(frame,fullfile(outputRoot,rel),'ImageModTime',datenum(2000,1,1));frames(end+1,1)=rel; %#ok<AGROW>
 end
 assert(numel(frames)==71,'MyoCues:Video','El vídeo aprobado no tiene el tramo revisado.');
 used=[used;frames]; %#ok<AGROW>
 for level=[25 50 75 100]
  key=direction+compose('_%03d',level);last=1+round((numel(frames)-1)*level/100);
  % Sólo la guía opening 25: el prefijo temporal uniforme casi no movía dedos.
  % Endpoint visual revisado en frame fuente 63; target .25 y MOVE 1 s intactos.
  if direction=="opening"&&level==25,last=63-36+1;end
  sequences.(key)=struct('frames',frames(1:last),'source',name,'source_sha256',myoFileSHA256(video), ...
   'source_first_frame',36,'source_last_frame',36+last-1,'native_frame_rate',reader.FrameRate);
 end
 sources.(master)=struct('file',name,'trim_first',36,'trim_last',106,'review','Revisión visual de extremos y sentido; niveles nominales, no pose medida.');
end
used=[used;"postures/P0_FORWARD_EXTENDED.png";"prepare_closed.png";"prepare_open.png"];
hashes=struct('file',{},'sha256',{});
for k=1:numel(used)
 hashes(k)=struct('file',used(k),'sha256',myoFileSHA256(fullfile(outputRoot,used(k))));
end
manifest=struct('sequences',sequences,'files',hashes,'posture_source_sha256',myoFileSHA256(posture),'sources',sources, ...
 'timing','frame = 1 + floor(clip((elapsed-prepare)/move,0,1)*(N-1)); HOLD = N');
manifest.visual_revision="OPENING25_VISIBLE_ENDPOINT_63";
myoWriteJSONAtomic(fullfile(outputRoot,'cues_manifest.json'),manifest);
end
