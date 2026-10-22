function report=myoAtomicPromote(temp,destination,replace,o)
% Promocion local: no borrar destino ni temporal para simular atomicidad.
% MoveFunction permite inyectar errores del proveedor SOLO en tests.
arguments
 temp (1,1) string
 destination (1,1) string
 replace (1,1) logical = false
 o.MaxAttempts (1,1) double {mustBeInteger,mustBePositive} = 6
 o.BackoffSeconds (1,1) double {mustBeNonnegative} = .025
 o.MoveFunction (1,1) function_handle = @nioMove
end
from=java.io.File(char(temp)).getCanonicalFile().toPath();
to=java.io.File(char(destination)).getCanonicalFile().toPath();
assert(from.getParent().equals(to.getParent()),'MyoSave:DifferentDirectory','Temporal y destino deben compartir directorio/volumen.');
assert(~from.equals(to),'MyoSave:SameFile','Temporal y destino deben ser distintos.');
assert(isfile(temp),'MyoSave:MissingTemp','No existe el temporal %s.',temp);
assert(~isfolder(destination),'MyoSave:DestinationDirectory','El destino es un directorio: %s.',destination);
if ~replace,assert(~isfile(destination),'MyoSave:NoOverwrite','Ya existe %s.',destination);end
expected=myoFileSHA256(temp);
atomic=replace;fallback=false;
% ATOMIC_MOVE ignora las otras opciones en Java: NO usarlo para trials
% finales, porque su politica frente a un destino existente depende del FS.
for attempt=1:o.MaxAttempts
 try
  o.MoveFunction(from,to,replace,atomic);
  assert(isfile(destination)&&~isfile(temp),'MyoSave:PromotionState','Promocion incompleta: %s.',destination);
  assert(myoFileSHA256(destination)==expected,'MyoSave:HashMismatch','Hash tras promocion incorrecto: %s.',destination);
  report=struct('attempts',attempt,'atomic_requested',replace,'fallback_used',fallback,'sha256',expected);
  return
 catch ex
  detail=string(ex.identifier)+" "+string(ex.message);
  unsupported=contains(detail,'AtomicMoveNotSupportedException') || contains(detail,'MyoSaveTest:AtomicUnsupported');
  if unsupported && atomic
   atomic=false;fallback=true;
   warning('MyoSave:NonAtomicFallback','ATOMIC_MOVE no soportado; movimiento local con REPLACE_EXISTING: %s.',destination);
  else
   permanent=any(contains(detail,["FileAlreadyExistsException","NoSuchFileException","DirectoryNotEmptyException","MyoSave:"]));
   ioFailure=any(contains(detail,["FileSystemException","AccessDeniedException","IOException","MyoSaveTest:TransientLock"]));
   if ~permanent && ioFailure && attempt<o.MaxAttempts
    pause(min(.2,o.BackoffSeconds*2^(attempt-1)));
   else
    failed=MException('MyoSave:PromotionFailed','No se pudo promover %s a %s tras %d intento(s). Se conserva la evidencia disponible. Causa: %s',temp,destination,attempt,ex.message);
    throwAsCaller(addCause(failed,ex));
   end
  end
  if attempt==o.MaxAttempts
   failed=MException('MyoSave:PromotionFailed','Se agotaron %d intentos para %s. Temporal conservado: %s.',attempt,destination,temp);
   throwAsCaller(addCause(failed,ex));
  end
 end
end
end
function nioMove(from,to,replace,atomic)
opts=javaArray('java.nio.file.CopyOption',double(replace)+double(atomic));
if replace,opts(1)=java.nio.file.StandardCopyOption.REPLACE_EXISTING;end
if atomic,opts(2)=java.nio.file.StandardCopyOption.ATOMIC_MOVE;end
java.nio.file.Files.move(from,to,opts);
end
