# Esquema `myo-continuous-v1`

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
| measured_aperture_provider | NONE; reserva explícita para un proveedor futuro separado |
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

Cada trial se escribe a un MAT temporal único en el mismo directorio, se carga y valida, se compara su contenido y se renombra. En Windows se usa `System.IO.File.Move`, que no sobrescribe un destino existente. Metadatos/manifiesto usan reemplazo atómico independiente. El manifiesto contiene SHA256 del MAT, conteos, condición, estado, duración y frecuencia estimada.

El backend conserva además un prefijo activo cada segundo mediante reemplazo de `recovery/active_trial.mat`. Abort/pausa/cierre de GUI guardan el buffer disponible como trial parcial. Si el proceso termina abruptamente, `recoverMyoSession` puede promover el último prefijo persistido como RECOVERED_PARTIAL y reconstruir el manifiesto desde los MAT completos. Es idempotente y no cambia trials existentes. Puede perderse el último intervalo aún en RAM; no se promete protección absoluta ante pérdida de alimentación o fallo del disco. Temporales incompletos no se eliminan automáticamente.

La recuperación no reanuda una contracción ni concatena sesiones. Para continuar adquisición usar una nueva sesión y conservar la procedencia de los trials parciales.

## Medición externa futura

Un futuro `MeasuredApertureSource` deberá suministrar su propio tiempo, unidades, calibración y valores observados (webcam/visión, goniómetro, flex sensor u otro sensor). Requerirá una nueva versión del contrato/validador. En v1 se rechaza activar measured sin esa implementación. El Myo por sí solo no observa «50% de apertura».
