function cleanup=myoAcquireDataLock(root)
% Exclusión entre procesos; nunca borrar un lock de otro escritor.
if ~isfolder(root),mkdir(root);end
file=fullfile(root,'.acquisition_registry.lock');acquired=false;
for attempt=1:40
 try
  java.nio.file.Files.createDirectory(java.io.File(char(file)).toPath(),javaArray('java.nio.file.attribute.FileAttribute',0));
  acquired=true;break
 catch ex
  if ~isfolder(file),rethrow(ex);end
  pause(.05);
 end
end
assert(acquired,'MyoRegistry:Locked','Registro ocupado. Si otro proceso terminó inesperadamente, revisar el lock manualmente: %s',file);
cleanup=onCleanup(@()rmdir(file));
end
