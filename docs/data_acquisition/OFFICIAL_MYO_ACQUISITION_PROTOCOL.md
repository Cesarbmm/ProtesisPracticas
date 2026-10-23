# Protocolo oficial de adquisición Myo — OPEN/CLOSE

La campaña `MYO_OPEN_CLOSE_OFFICIAL_V1` usa `protocol_version=OPEN_CLOSE_OFFICIAL_V1` y postura `P0_SEATED_ARMREST` **sólo para sesiones nuevas**. Mantiene el protocolo científico de S04 y sus cues. Estandariza colocación y preparación; no demuestra todavía separabilidad robusta de cuatro niveles ni validez de un dataset general.

La confirmación es responsabilidad del operador: la GUI no puede inferir si el brazalete está bien colocado. No se entrenan modelos ni se controla hardware protésico. Cámara, visión, MediaPipe y medición de apertura quedan fuera del proyecto.

## A. Antes de colocar el Myo

1. Seleccionar el participante registrado o crear un ID automático Pxxx. El alias es opcional; no se solicita nombre real. Verificar que corresponde a la persona presente.
2. Pulsar **Nueva sesión**: el registro reserva Sxxx y un UUID irrepetible; nunca sobrescribe una carpeta. S01/S02/S03/S04 y las demás sesiones anteriores conservan nombres y contenido.
3. Definir el brazo `right` o `left`. Limpiar/secar la piel si es necesario.
4. Sentar al participante con espalda apoyada y postura cómoda. Dejar el brazo relajado, codo apoyado sobre el reposabrazos, antebrazo descansando naturalmente, muñeca neutra y mano libre. No levantar el brazo ni cambiar deliberadamente la postura durante los trials.

Esta postura operacional es **P0_SEATED_ARMREST**. La imagen instalada por el operador es la referencia; no se deducen otros ángulos desde el texto.

## B. Colocación P1

- Aproximadamente **dos dedos distal al codo**, directamente sobre piel.
- Usar clips/pinzas apropiados al diámetro del antebrazo.
- Comprobar contacto firme y estable de los **ocho sensores**.
- Ajustar sin comprimir excesivamente el brazo.
- Mantener orientación fija, con **tapa/puerto de carga hacia el exterior del brazo**, según la referencia experimental.
- Una vez colocado, **no rotar ni reajustar durante la sesión**. Si es necesario recolocar, detener la captura y documentar el cambio en una sesión nueva; no mezclar colocaciones.

El identificador `P1` no certifica por sí solo una buena colocación. El campo muestra esta definición como ayuda; la campaña oficial lo mantiene fijo.

## C. Conexión, estabilización y confirmaciones

Conectar/sincronizar con Myo Connect, ajustar clips y dejar estabilizar contacto y temperatura antes del precheck. No se impone un tiempo de calentamiento sin validación física; lo confirma el operador.

En **Identidad / postura** revisar participante, sesión, campaña, brazo, placement e imagen. Completar las diez casillas, inicialmente desmarcadas:

1. Participante correcto.
2. Brazo correcto.
3. Myo aproximadamente dos dedos debajo del codo.
4. Tapa/puerto de carga hacia el exterior.
5. Clips correctamente colocados.
6. Ocho sensores con contacto firme.
7. Myo colocado, ajustado y estabilizado antes del precheck.
8. Codo apoyado en el reposabrazos.
9. Muñeca neutra.
10. Postura coincide con la imagen.

**Test signal 30s** permanece bloqueado hasta confirmar todo. Cambiar participante, sesión, brazo, placement o nota invalida la preparación/precheck y obliga a repetirlos.

La referencia se lee directamente de `acquisition/references/Referencia.jpg`: se conserva nombre y path, sin crear otra copia. La imagen reemplazada por el operador tiene SHA256 `8673addf727fdfe1a0f5deba2891f5d00011474f61781b0b640476eaf31a91c4` en esta revisión. Cada sesión calcula y guarda el hash del archivo realmente presentado y vuelve a verificarlo antes de comenzar. Ausencia o cambio de imagen después de confirmar bloquea el inicio.

Se guardan `participant_confirmed`, `placement_confirmed`, `posture_confirmed`, `arm_confirmed`, `myo_fit_confirmed`, `myo_orientation_confirmed` y `stabilization_confirmed`, además de la hora de confirmación y la definición de P1. Son declaraciones del operador, no medidas automáticas.

## D. Diagnóstico de señal — 30 segundos

Pulsar **Conectar Myo** y **Test signal 30s**. La pantalla indica **DIAGNÓSTICO DE SEÑAL**, sin crear un trial científico:

| Tiempo del diagnóstico | Instrucción |
|---|---|
| 0–8 s | Reposo, relajar la mano |
| 8–15 s | Abrir cómodamente |
| 15–22 s | Cerrar cómodamente, sin apretar con fuerza |
| 22–30 s | Volver a reposo, sin buscar una posición concreta |

Revisar ocho canales RAW, frecuencia, planos, clipping, timestamps y estabilidad visual. Los umbrales existentes de calidad no cambian. Canales planos, clipping >1 %, frecuencia fuera de 180–220 Hz o repetición elevada de filas requieren revisión explícita del operador **antes** de habilitar Iniciar. El botón **Revisar señal** permite volver a ver los avisos. Samples insuficientes, número de canales incorrecto, valores no finitos o timestamps desordenados impiden iniciar y no se resuelven pulsando «continuar».

Variaciones pequeñas dentro de los límites existentes no añaden un bloqueo nuevo. No existe un detector validado de brazalete flojo ni de «inestabilidad anormal»; si el operador observa saltos, pérdida de contacto o rotación, debe corregir y repetir el precheck. Reconocer un warning no certifica buena calidad física. Se conserva `quality_precheck.mat` y el informe de calidad al comenzar una sesión, separado de los trials.

## E. Práctica

**Práctica / Demo** enseña ambas direcciones y los cuatro niveles con el mismo motor de cues y las mismas duraciones. Funciona desconectada y sin reservar participante/sesión. No crea `MyoAcquisitionSession`, directorios, manifest ni RAW. Muestra **MODO PRÁCTICA — NO SE GUARDAN DATOS CIENTÍFICOS**.

Confirmar que la persona entiende opening, closing, recorrido cómodo y reposo. La guía visual no mide apertura ni constituye ground truth físico.

## F. Captura: protocolo científico conservado

| Propiedad | Contrato |
|---|---|
| Direcciones | opening y closing |
| Movement levels | .25, .50, .75, 1.00 |
| Opening L | target_aperture 0 → L |
| Closing L | target_aperture 1 → 1−L |
| Repeticiones | Seis por condición; 48 movimientos |
| Bloques | Tres de 16; dos repeticiones de cada una de las ocho condiciones por bloque |
| PREPARE | 2 s |
| MOVE | 1 / 2 / 3 / 4 s para 25 / 50 / 75 / 100 % |
| HOLD | 2 s |
| RELEASE | 2 s, relajarse y volver a posición natural; no es REST |
| REST | 5 s; relajar sin buscar posición concreta |
| Descanso de bloque | 60 s, incluido el bloque final; no es trial científico |

Son 100 filas de planificación: 48 movimientos, 49 REST y tres descansos. Se guardan 97 registros científicos completos cuando no hay repeticiones/parciales; duración nominal 833 s más precheck y operación. Los niveles son **intención instruida**, no fuerza ni apertura medida. Cierre completo cómodo: **NO APRIETES CON FUERZA**.

Seguir los cues sin anticipar movimientos, mantener P0_SEATED_ARMREST y respetar descansos. REST no significa mano abierta ni cerrada. Los frames, sus extremos, el ajuste visual de apertura 25 %, el reloj de estímulo y las fases se conservan.

### Orden reproducible por sesión

El UUID se persiste al reservar. `myoSessionSeed` interpreta sus primeros ocho dígitos hexadecimales como un entero de 32 bits (`UUID_FIRST_32_BITS_V1`). Así cada sesión tiene una seed estable, sin usar reloj ni modificar el RNG global. Se guarda en metadata y `protocol.csv`; el orden completo también queda registrado. No hay garantía matemática de que dos seeds nunca coincidan, pero no se impone un mismo orden a todas las personas.

Cerrar/reabrir la GUI recupera, por participante y campaña, la reserva pendiente más reciente que aún no tiene carpeta de sesión. Conserva UUID, seed y orden, **sin escribir ni regenerar la reserva**. Es necesario confirmar de nuevo postura y precheck. «Nueva sesión» es una acción explícita que reserva otro ID/UUID. Una sesión ya creada nunca se retoma automáticamente ni se sobrescribe.

La tabla de reservas mantiene sus cinco columnas anteriores; la seed se deriva del UUID persistido. `buildMyoOfficialProtocol(seed)` utiliza el mismo generador balanceado de S04, con un máximo de dos direcciones iguales seguidas; sólo actualiza los identificadores de postura/campaña/versión. La seed fija del descriptor heredado se conserva exclusivamente para preview/práctica y compatibilidad; no se usa para iniciar una captura oficial.

## G. Después de la captura

Comprobar `session_status.json`: `protocol_complete=true`, estado y errores. Revisar manifest, conteos, hashes y completitud; FINISHED manual no garantiza protocolo completo. Conservar RAW, prefijos y metadata; nunca sobrescribir ni mezclar sesiones. Los datos humanos y registros personales siguen ignorados por Git.

La persistencia atómica, hashes, recuperación y registro de participantes conservan sus garantías anteriores. Los pilotos y sus anotaciones se leen sin modificar postura, metadata o hashes antiguos. El PNG/manifest de cues piloto conserva su procedencia histórica; **no representa la postura oficial**, cuya referencia independiente es el JPG actual.

## Comando manual

Dentro de MATLAB Desktop:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
app = runMyoMultiParticipantApp();
```

Abrir la GUI no conecta ni inicia adquisición. Seleccionar persona → Nueva sesión → colocar/estabilizar → Identidad / postura → Conectar → Test signal → revisar avisos → Iniciar. Práctica está disponible antes de capturar. Preparar los paths externos MyoMex/SDK como en la [guía de usuario](MYO_GUI_USER_GUIDE.md); no se distribuyen MEX/DLL/SDK.

## Validación sin hardware

```matlab
r = runtests('tests/acquisition');
assert(all([r.Passed]));
summary = runMyoMultiParticipantSmoke();
stress = runMyoAcquisitionStress();
```

El smoke oficial recorre 833 s simulados con una fuente MOCK, 48 movimientos, 97 MAT, tres descansos, confirmaciones, hash de postura y seed por sesión. La suite incluye los tests previos de persistencia Windows y lectura de pilotos. No sustituye la comprobación física del operador ni inicia otra adquisición humana.
