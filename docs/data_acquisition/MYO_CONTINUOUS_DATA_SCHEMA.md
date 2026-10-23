# Esquema `myo-continuous-v1`

La [campaña oficial](OFFICIAL_MYO_ACQUISITION_PROTOCOL.md) y la [campaña piloto V2](MULTIPARTICIPANT_CAMPAIGN_V2.md) conservan lectura de v1/v2 y añaden session_uuid, campaign_id, capture_utc, protocol_version, random_seed y confirmaciones de identidad/postura. Para campaign_id presente el backend exige reserva válida, confirmaciones y hash de la referencia de postura. Los MAT v2 admiten P0_NEUTRAL_90, P0_FORWARD_EXTENDED y P0_SEATED_ARMREST, siempre igual a su protocolo; no sustituyen metadata histórica. Registro de participantes, reservas y anotaciones se guardan fuera de las carpetas de sesión y permanecen ignorados por Git.

Formato incremental:

```text
data_acquisition/P001/S01/
  metadata.json
  protocol.csv
  quality_precheck.mat
  session_manifest.csv
  session_status.json
  trials/trial_0001.mat
  trials/trial_0002.mat
  recovery/active_trial.mat
```

Cada MAT definitivo contiene una estructura `trial`. Identificadores seguros: letras/dígitos/guion/guion bajo; ningún componente puede ser una ruta. Cada trial usa ID entero positivo único incluso al repetir o pausar. La sesión y colocación son inmutables después de iniciar.

| Variable | Dimensión / unidad / significado |
|---|---|
| schema_version | `myo-continuous-v1` |
| participant_id, session_id, placement_id | Escalares de texto; P1/P2 distinguen colocación |
| trial_id / protocol_index | ID único del archivo / fila del protocolo (puede repetirse) |
| condition_id, condition, direction, speed, repetition | Etiquetas del estímulo; REST/HOLD/RAMP; opening/closing/rest |
| arm, placement_note | right/left y nota del operador |
| source_info | Proveedor, escala, tasas nominales y limitaciones del tiempo |
| protocol_sha256 / acquisition_code_hashes | Hash del protocolo y código de captura; MyoMex registra además hashes de wrappers y del MEX si está disponible |
| protocol | Copia de la fila congelada, con prepare_s/ramp_s/hold_s/duration_s |
| phase | N×1 strings: PREPARE/RAMP/HOLD/REST; OUTSIDE_STIMULUS_CLOCK si el reloj reconstruido cae fuera del estímulo asignable |
| target_start / target_end | Fracción de apertura **instruida** [0,1]; NaN en REST |
| target_aperture | N×1, protocolo visual evaluado en `time_emg`; [0,1] o NaN cuando no se prescribe/asigna apertura |
| reference_source | Siempre VISUAL_TARGET |
| rest_intent | Booleano; independiente de apertura |
| measured_aperture | `[]` en v1; **nunca copia de target** |
| measured_aperture_available | false; el validador rechaza medición ficticia |
| measured_aperture_provider | NONE; medición de apertura fuera del alcance definitivo de este proyecto |
| emg_raw | N×8 double, exactamente MyoData.emg_log: códigos SDK divididos por 128; no voltios, no WMoos, no filtro/offset de GUI |
| time_emg | N×1 segundos relativos al inicio de trial; conserva orden y diferencias del tiempo suministrado |
| source_time_emg | N×1 timestamps originales de MyoData, segundos desde inicialización del proveedor; **reconstruidos**, no hardware timestamps |
| arrival_time_emg | N×1 tiempo host/fuente de recepción del lote, repetido para las muestras de ese lote |
| time_imu / source_time_imu | K×1 segundos, relativo / original reconstruido a 50 Hz nominales |
| quat | K×4, quaternion unitario [w x y z]; MyoData ya lo renormalizó |
| gyro | K×3, grados/s en marco del sensor |
| accel | K×3, g en marco del sensor |
| pose_aux | K×1 enumeración Myo; auxiliar, no label continuo de apertura |
| arrival_time_imu | K×1 reloj de llegada del lote IMU |
| target_events | Tabla source_time/trial_time/target/phase de solicitudes de estímulo en los callbacks; no certifica el instante físico de refresco del monitor |
| trial_start_source_time | Ancla para relacionar tiempos relativos y originales |
| duration | Tiempo transcurrido observado del trial; duración nominal en `protocol.duration_s` |
| sample_count | N |
| actual_emg_fs / actual_imu_fs | (N−1)/(último−primero) o NaN; **estimación por tiempos suministrados**, no certificación de hardware |
| quality | Fs, conteos, tiempo host, gaps estimados por timestamps, flat, clipping, RMS/MAV, repetición, avisos; dropout_certified=false |
| outside_stimulus_clock_samples | RAW preservado con target no asignable, por discrepancia de reloj/borde |
| status | COMPLETED, PAUSED_PARTIAL, REPEATED_PARTIAL, ABORTED_PARTIAL, FINISHED_PARTIAL, ERROR_PARTIAL o RECOVERED_PARTIAL |

IMU ausente: time_imu 0×1; quat 0×4; gyro/accel 0×3; pose_aux 0×1. Pose Myo: 0 rest, 1 fist, 2 wave_in, 3 wave_out, 4 fingers_spread, 5 double_tap, 65535 unknown. Ninguna pose sustituye la intención visual ni mide apertura.

## Tiempo y conservación de RAW

El timer de GUI es de 50 ms y MyoMex consulta su FIFO cada 40 ms. Esto no cambia la tasa de muestreo del proveedor. Entre trials se conserva el lote completo, incluido lo acumulado durante escritura: no se recorta RAW por el jitter de la GUI. Los samples cuyo tiempo reconstruido no cae dentro del trial se marcan OUTSIDE_STIMULUS_CLOCK, con target NaN; no se inventa una etiqueta. Al iniciar/reanudar se descarta el backlog previo al protocolo activo. Los intervalos de Pausa no se presentan como trials continuos.

`target_aperture` es la trayectoria planificada del estímulo, muestreada con el reloj suministrado; `target_events` permite auditar las decisiones de presentación. Ninguna variable garantiza sincronía submilisegundo entre pantalla, paquetes y contracción. Para estudiar esa sincronía harían falta timestamps de hardware y una medición externa de presentación.

## Persistencia y recuperación

Cada trial se escribe a un MAT temporal único en el mismo directorio, se carga y valida, se compara su contenido y se renombra. En V1 se usa `java.nio.file.Files.move` sin reemplazo para trials finales. Metadatos/status/recovery/manifiesto solicitan ATOMIC_MOVE + REPLACE_EXISTING, con fallback explícito sólo si no se soporta ATOMIC_MOVE y reintentos acotados de E/S. Se verifica SHA256 tras promoción. El manifiesto contiene SHA256 del MAT, conteos, condición, estado, duración y frecuencia estimada. Ningún fallo elimina automáticamente temporales de evidencia ni trials anteriores.

`session_status.json` V1 añade `protocol_complete` (sólo true al superar la última fila) y `last_error` (informe de error si lo hubo). `FINISHED` por cierre manual no significa necesariamente que el protocolo se completara; revisar ambas variables y el manifest. Finalizar no sustituye un estado ERROR/ABORTED por FINISHED. El esquema RAW de los trials y la semántica de target permanecen intactos.

El backend conserva además un prefijo activo cada segundo mediante reemplazo de `recovery/active_trial.mat`. Abort/pausa/cierre de GUI guardan el buffer disponible como trial parcial. Si el proceso termina abruptamente, `recoverMyoSession` puede promover el último prefijo persistido como RECOVERED_PARTIAL y reconstruir el manifiesto desde los MAT completos. Es idempotente y no cambia trials existentes. Puede perderse el último intervalo aún en RAM; no se promete protección absoluta ante pérdida de alimentación o fallo del disco. Temporales incompletos no se eliminan automáticamente.

La recuperación no reanuda una contracción ni concatena sesiones. Para continuar adquisición usar una nueva sesión y conservar la procedencia de los trials parciales.

## Identidad de campaña oficial (extensión de metadata, sin migración RAW)

Las nuevas sesiones `MYO_OPEN_CLOSE_OFFICIAL_V1` / `OPEN_CLOSE_OFFICIAL_V1` guardan `arm_posture_id=P0_SEATED_ARMREST`, referencia relativa `references/Referencia.jpg`, SHA256 actual y hora de confirmación. Se conservan los flags participant/placement/posture_confirmed y se añaden arm_confirmed, myo_fit_confirmed, myo_orientation_confirmed, stabilization_confirmed; todos son confirmaciones del operador. P1 incluye definición escrita de ubicación distal, orientación exterior, ajuste y contacto, no certificación automática.

`random_seed` y `randomization_seed` corresponden a los primeros 32 bits del UUID persistido en la reserva; `session_seed_source=UUID_FIRST_32_BITS_V1`. El protocolo y orden completo se guardan como antes. `quality_warnings_reviewed` registra la revisión explícita cuando hay avisos significativos del precheck. Los cinco campos del CSV de reservas no cambian; al leerlo se puede volver a derivar la seed sin reescribirlo.

No se cambia el esquema de muestras, fases, target, reloj ni persistencia de trials. Los lectores siguen admitiendo P0_NEUTRAL_90 y P0_FORWARD_EXTENDED; nunca sustituyen postura/hash de archivos antiguos. Véase el [protocolo oficial](OFFICIAL_MYO_ACQUISITION_PROTOCOL.md).

## Exclusión de medición de apertura y de visión (vigente)

Webcam, visión, MediaPipe y hand tracking están definitivamente fuera del alcance de este proyecto. No se implementará measured aperture aquí. `measured_aperture=[]`, `measured_aperture_available=false` y proveedor NONE permanecen por compatibilidad con los archivos existentes. La mano no se mide con el Myo ni con las imágenes de guía; todos los niveles son intención instruida. La IMU se conserva para estabilidad/postura, nunca como label de apertura.

## Extensión piloto 2: `myo-continuous-v2`

V1 continúa siendo legible con sus fases PREPARE/RAMP/HOLD/REST. Los nuevos registros de P001/S04 usan v2 con estos campos adicionales:

| Campo | Contrato |
|---|---|
| campaign | MYO_PILOT2_OPEN_CLOSE |
| direction | opening / closing en movimientos; rest en registros REST |
| movement_level | .25/.50/.75/1 en movimientos; NaN en REST |
| target_start / target_end | Opening: 0 → level; closing: 1 → 1−level |
| block_id | 1/2/3 |
| randomized_order | 1..48 para movimientos, NaN para REST |
| randomization_seed | Seed preregistrada 20261008, repetida en protocolo y metadata |
| arm_posture_id | P0_NEUTRAL_90; descripción en metadata |
| protocol.move_s | 1/2/3/4 s; ramp_s se conserva como alias para herramientas antiguas |
| protocol.release_s | 2 s después de HOLD; fase separada de REST |
| phase | PREPARE/MOVE/HOLD/RELEASE en movimientos; REST en registro de reposo |

RELEASE no prescribe apertura: `target_aperture=NaN`, `rest_intent=false`. El siguiente registro REST tiene también target NaN, pero `rest_intent=true` y condición REST. El validador v2 verifica que los labels y targets correspondan al protocolo y que RELEASE no se convierta en REST.

La tabla de protocolo contiene 100 filas de planificación: 97 registros científicos (48 movimientos + 49 REST) y tres eventos BLOCK_BREAK. Para éstos `is_scientific_trial=false`; no hay MAT en trials, no aumentan trial_id, no almacenan RAW científico y no se presentan como REST. `block_break_events.csv` guarda sólo bloque, tiempos, duración y estado; una pausa puede producir varias instancias de un descanso. En el live view el Myo puede continuar enviando muestras, pero no se incorporan a los MAT científicos durante ese descanso. Al volver a un registro científico se descarta el backlog de dicho intervalo.
