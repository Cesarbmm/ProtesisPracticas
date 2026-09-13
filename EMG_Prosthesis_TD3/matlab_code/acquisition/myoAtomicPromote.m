function myoAtomicPromote(temp,destination,replace)
% Renombrar en el MISMO directorio/volumen; nunca sobrescribir un trial.
if nargin<3,replace=false;end
assert(strcmp(fileparts(temp),fileparts(destination)),"MyoSave:DifferentDirectory","Datos o estado incompatibles con MyoSave:DifferentDirectory.");
if ~replace,assert(~isfile(destination),"MyoSave:NoOverwrite","Ya existe %s.",destination);end
if ispc
 if replace && isfile(destination)
  System.IO.File.Replace(char(temp),char(destination),[]);
 else
  System.IO.File.Move(char(temp),char(destination));
 end
else
 % Files.move sin REPLACE_EXISTING protege los trials. ATOMIC_MOVE para metadatos.
 from=java.io.File(char(temp)).toPath();to=java.io.File(char(destination)).toPath();
 if replace
  opts=javaArray('java.nio.file.CopyOption',2);opts(1)=java.nio.file.StandardCopyOption.ATOMIC_MOVE;opts(2)=java.nio.file.StandardCopyOption.REPLACE_EXISTING;
 else
  opts=javaArray('java.nio.file.CopyOption',0);
 end
 java.nio.file.Files.move(from,to,opts);
end
end
