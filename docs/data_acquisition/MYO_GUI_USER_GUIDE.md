# Guía de adquisición Myo

La GUI captura RAW e instrucciones visuales. No controla motores ni ejecuta entrenamiento. Abrirla no conecta el Myo automáticamente.

**Campaña actual multi-participante:** abrir `runMyoMultiParticipantApp()` y seguir [MULTIPARTICIPANT_CAMPAIGN_V2](MULTIPARTICIPANT_CAMPAIGN_V2.md): IDs automáticos, nuevas sesiones, confirmación de identidad/postura P0_FORWARD_EXTENDED y precheck. El [documento de preparación de S04](MYO_PILOT2_OPEN_CLOSE_PROTOCOL.md) y las instrucciones P001/S02 de abajo documentan los flujos anteriores. S01/S02/S03/S04 se conservan; no reutilizar sus IDs para adquirir de nuevo. Visión/cámara y medición de apertura quedan fuera del alcance definitivo de este proyecto.

## Runtime físico y procedencia V1

P001/S01 ya fue un piloto físico, fallido en persistencia. El MEX externo está compilado y funcional. No se copia al repositorio ni se recompila aquí. S01 se conserva íntegramente, incluidos los temporales; no es un dataset científico válido.

`MyoMexDataSource` usa `which('MyoMex')`, `which('MyoData')` y `which(['myo_mex.' mexext])`, y registra los hashes de los archivos realmente utilizados. Prepara PATH desde `MYO_SDK_ROOT/bin` y `MW_MINGW64_LOC/bin`; requiere `myo64.dll` y un MEX compatible con R2023b. No añadir a ciegas la antigua carpeta `lib/myo mex`, pues podría ocultar la instalación funcional de Add-Ons.

Mantener Myo Connect emparejado y esas variables de entorno configuradas. No abrir otra instancia MyoMex que compita por el dispositivo. Los tests de esta revisión no conectan hardware; el próximo piloto es manual.

## Abrir GUI completa, manualmente

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
app = MyoContinuousAcquisitionApp(SessionID="S02");
```

1. Para el segundo piloto: P001, sesión S02, brazo, placement P1 y nota de orientación. No incluir identificadores personales innecesarios.
2. Pulsar **Conectar Myo**, con el dispositivo emparejado en Myo Connect. No abrir otra instancia MyoMex que compita por el mismo MEX.
3. Pulsar **Test signal 30s**. Revisar ocho canales, ausencia de plano/clipping constante y avisos. Relajar y mover suavemente. RMS/MAV son diagnósticos, no medidas de intención ni de apertura.
4. Elegir repeticiones y tiempos antes de iniciar. La configuración avanzada se entrega como `Protocol=buildMyoContinuousProtocol(...)` al constructor. Cambiar colocación después del diagnóstico requiere una nueva prueba de señal.
5. Pulsar **Iniciar / Seguir**. Se congelan metadata y protocolo; aparece barra 0–100%, número, dirección, fase y progreso del trial. En REST sólo se pide relajar, sin asociarlo a mano abierta/cerrada.
6. **Pausa** guarda un prefijo parcial. **Iniciar / Seguir** reinicia la fila actual desde el principio con otro ID. **Repetir trial** también conserva el prefijo e inicia otra instancia de la fila actual; no reemplaza un MAT previo.
7. **Abortar seguro** conserva lo completado y el prefijo activo. **Finalizar** guarda lo disponible y desconecta. Cerrar la GUI intenta guardar el trial activo antes de desconectar.

El RAW se guarda sin los offsets verticales usados para separar CH1–CH8 en pantalla. El live view conserva sólo los últimos dos segundos; los archivos por trial conservan todos los samples recibidos dentro de la captura activa.

## Segundo piloto físico P001/S02 — sólo ejecución manual

Una sola persona, sesión y colocación; REST y cuatro niveles, una repetición, aproximadamente un minuto de protocolo más 30 segundos de diagnóstico:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
p = buildMyoContinuousProtocol(repetitions=1,includeRamps=false,holdSeconds=3,restSeconds=6);
app = MyoContinuousAcquisitionApp(Protocol=p,ParticipantID="P001",SessionID="S02",PlacementID="P1");
```

Pulsar Conectar/Test signal/Iniciar únicamente cuando el hardware esté preparado. El propósito es verificar infraestructura, no entrenar ni validar generalización.

## Ubicación y recuperación

Con el comando anterior: `matlab_code/data_acquisition/P001/S02/`. Puede elegirse otra raíz con `OutputRoot="D:\MyoDataset"`. Una sesión existente se rechaza; para una recolocación P2 usar otra sesión nueva, por ejemplo S03. Las carpetas RAW están ignoradas por Git.

Al terminar revisar `session_manifest.csv`, `session_status.json`, avisos por trial, tamaño y hash de los MAT. COMPLETED y *_PARTIAL son estados distintos. Después de una interrupción abrupta:

```matlab
report = recoverMyoSession('C:\ruta\al\dataset\P001\SESION_NUEVA');
```

La ruta debe ser la de la sesión nueva adquirida. No invocar recuperación sobre datasets históricos. Se recupera el último prefijo disponible, sin reanudar artificialmente una contracción ni borrar trials. Los archivos temporales quedan para inspección si hubo fallo de disco/escritura.

## Tests y smoke sin hardware

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
r = runtests('tests/acquisition');
assert(all([r.Passed]));
addpath('acquisition');
summary = runMyoAcquisitionSmoke();
stress = runMyoAcquisitionStress();
```

El smoke identifica sus datos como MOCK/no científicos. Verifica GUI, cambio de target, 25 trials sintéticos cortos, RAW, manifiesto y hashes. No conecta MyoMex ni entrena modelos. El screenshot documenta una GUI probada, no una sesión humana.

La interfaz usa [uigridlayout](https://www.mathworks.com/help/matlab/ref/uigridlayout.html) y captura la evidencia con [exportapp](https://www.mathworks.com/help/matlab/ref/exportapp.html). Los gráficos están encapsulados en paneles propios para conservar su encuadre en el render/export de R2023b; se revisó visualmente la imagen, además de probar los callbacks.

## Flujo visual V1 y práctica

La ventana abre maximizada con marco normal de Windows y controles de minimizar, restaurar y cerrar. Cerrar conserva el callback seguro. La instrucción, el porcentaje, la guía, la fase y su cuenta regresiva tienen prioridad; los ocho canales permanecen debajo.

**Práctica / Demo** funciona incluso desconectado, sin MyoAcquisitionSession, directorios ni MAT. Muestra permanentemente `MODO PRÁCTICA — NO SE GUARDAN DATOS CIENTÍFICOS`. El mismo botón termina la práctica. Después: Conectar → Test signal 30s → revisar calidad → Iniciar / Seguir. Inicio está deshabilitado hasta finalizar el precheck; cambiar identidad/colocación exige repetirlo.

`includeRamps=false` no elimina la transición dentro de HOLD. En P001/S02: CIERRA LA MANO (2 s), ABRE PROGRESIVAMENTE (2 s), MANTÉN XX % (3 s), RELAJA LA MANO (6 s). REST no equivale a 0 %. Las instrucciones también contemplan cierre en el protocolo completo.

Estados visibles: DESCONECTADO, CONECTADO, PRECHECK, LISTO, PRÁCTICA, CAPTURANDO, PAUSA, FINALIZADO y ERROR. Finalizar sin sesión dice `Diagnóstico finalizado, sin sesión`. Una finalización anticipada indica protocolo INCOMPLETO. El JSON nuevo registra `protocol_complete`; finalizar no borra un estado ERROR/ABORTED previo.

Los assets se resuelven junto al código en `acquisition/references`, sin rutas absolutas. Si faltan o no se leen se muestran instrucciones textuales. La imagen REST no exige cerrar la mano y la flecha de apertura no se usa para cierre.

## Persistencia V1

Se usa `java.nio.file.Files.move` en el mismo directorio. Para status/recovery/manifest/JSON se pide ATOMIC_MOVE + REPLACE_EXISTING; sólo ante AtomicMoveNotSupportedException se usa fallback explícito con warning. No se promete atomicidad en un filesystem que no la soporte. Para trials se usa movimiento sin reemplazo: ATOMIC_MOVE puede ignorar otras opciones según la API Java, por eso no se utiliza para autorizar sobrescritura.

Se validan MAT/JSON antes de promoción y SHA256 después. Errores de E/S potencialmente transitorios reciben hasta seis intentos con esperas de 25, 50, 100, 200 y 200 ms. Los errores definitivos o el agotamiento fallan explícitamente y preservan evidencia; no se borran temporales fallidos ni archivos anteriores. No hay garantía frente a pérdida eléctrica completa.

La suite prueba locks exclusivos reales de Windows, reintentos/fallback inyectados, preservación ante fallo y 3.000 promociones explícitas. El smoke prolongado añade una sesión mock de 526 s simulados, 81 trials y recovery periódico. No sustituye la validación manual del segundo piloto.

Referencia: [Java NIO Files.move](https://docs.oracle.com/javase/8/docs/api/java/nio/file/Files.html#move-java.nio.file.Path-java.nio.file.Path-java.nio.file.CopyOption...-).
