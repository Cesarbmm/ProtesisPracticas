function asset=myoPostureAssetPath(relative,assetRoot)
% Resolver assets existentes; nunca copiar/converter la referencia del operador.
if nargin<2,assetRoot=fullfile(fileparts(mfilename('fullpath')),'assets');end
relative=replace(string(relative),"\","/");
assert(~any(split(relative,"/")==".."),'MyoSession:PosturePath','Ruta de postura no válida.');
if startsWith(relative,"assets/")
 asset=fullfile(assetRoot,extractAfter(relative,"assets/"));
elseif startsWith(relative,"references/")
 asset=fullfile(fileparts(mfilename('fullpath')),relative);
else,error('MyoSession:PosturePath','Usar una referencia relativa existente en assets/ o references/.');end
end
