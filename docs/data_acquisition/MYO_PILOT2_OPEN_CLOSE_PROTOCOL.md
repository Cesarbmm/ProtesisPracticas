# Campaña piloto 2 — dirección + nivel de movimiento instruido

**Preparación histórica de S04.** La nueva interfaz de campaña está en [MULTIPARTICIPANT_CAMPAIGN_V2](MULTIPARTICIPANT_CAMPAIGN_V2.md). Conserva este diseño científico, usa P0_FORWARD_EXTENDED y un ledger separado para la postura de S04 informada posteriormente como incorrecta en metadata. Este documento no reescribe la sesión ni asigna automáticamente su identidad real.

Objetivo: ampliar la exploración con un participante, P001/S04, para estudiar si EMG permite distinguir dirección y nivel de recorrido voluntario cómodo. S03 mostró un gradiente preliminar prometedor según el operador; S02 fue menos consistente. **No se ha demostrado separabilidad robusta de cuatro niveles.** Esta preparación no entrena modelos ni inicia adquisición humana.

## Contrato de coordenadas e intención

`target_aperture` siempre sigue 0=cerrada, 1=abierta. `movement_level` es el recorrido instruido en la dirección indicada; no es fuerza ni apertura medida.

| Dirección | Inicio cómodo | Nivel | Apertura final instruida |
|---|---|---:|---:|
| opening | Cerrada | 25/50/75/100 % | .25/.50/.75/1 |
| closing | Abierta | 25/50/75/100 % | .75/.50/.25/0 |

En cierre la GUI muestra CIERRE XX % y recuerda NO APRIETES CON FUERZA. Cierre 100 % significa **CIERRE COMPLETO CÓMODO — NO APRIETES CON FUERZA**. La barra conserva apertura interna; el número grande muestra el nivel de movimiento solicitado y su dirección. Durante RELEASE/REST no se prescribe apertura.

Los porcentajes sólo son **INTENCIÓN INSTRUIDA**, sin sensor de mano. Measured aperture permanece vacío/false por compatibilidad. **Cámara, webcam, visión, MediaPipe y hand tracking quedan definitivamente fuera de este proyecto**. No se implementarán ahora ni como siguiente etapa.

## Tiempos congelados

| Fase | Duración | Instrucción |
|---|---:|---|
| PREPARE opening | 2 s | CIERRA LA MANO; Prepárate para abrir |
| PREPARE closing | 2 s | ABRE COMPLETAMENTE LA MANO; Prepárate para cerrar |
| MOVE | 1/2/3/4 s para 25/50/75/100 % | ABRE PROGRESIVAMENTE HASTA XX % / CIERRA PROGRESIVAMENTE XX % |
| HOLD | 2 s | MANTÉN APERTURA XX % / MANTÉN EL CIERRE XX % |
| RELEASE | 2 s | RELÁJATE; VUELVE A TU POSICIÓN NATURAL |
| REST estable | 5 s después de RELEASE | REPOSO; No busques una posición concreta |

Velocidad **nominal de instrucción**: .25 del rango voluntario por segundo en ambas direcciones. No es una medición de la velocidad física. RELEASE tiene fase propia, target NaN y no se etiqueta REST. REST empieza en un registro posterior, tras acabar RELEASE. Se añade un REST inicial de 5 s.

## Postura y colocación fija

`arm_posture_id=P0_NEUTRAL_90`: tronco erguido, codo aproximadamente 90°, antebrazo frente al torso, muñeca neutra; evitar mover hombro/antebrazo durante el trial. No variar postura ni recolocar el Myo durante S04.

Registrar placement P1. La verificación física de postura y colocación queda a cargo del operador; la GUI no exige describirla ni validarla para continuar. La nota de orientación es opcional y puede quedar vacía antes del precheck y del inicio; no se inventa una descripción. Se mantiene el precheck de señal de 30 s. Si se cambia la metadata después del precheck, éste debe repetirse. La metadata y controles se congelan al iniciar; no se incorpora P2/recolocación a esta campaña. La IMU permanece a su tasa nominal 50 Hz para análisis posterior de postura/estabilidad, no como label de mano.

## Repeticiones, bloques y randomización

- Ocho condiciones: opening y closing × cuatro niveles.
- Seis repeticiones por condición: **48 movimientos**.
- Tres bloques de 16 movimientos: dos instancias de cada una de las ocho condiciones por bloque.
- Seed congelada: **20261008**, generador local mt19937ar; no altera el RNG global de MATLAB.
- Permutaciones por rechazo hasta que no haya más de dos movimientos consecutivos de la misma dirección, incluyendo los límites entre bloques. Esta restricción se aplica sólo a movimientos activos, ignorando los REST intermedios.
- Se registran `block_id`, `randomized_order`, seed y la lista completa de las 48 condiciones en protocolo/metadata.

Después de **cada** bloque, incluido el tercero, se muestra DESCANSO DE BLOQUE — 60 s. Son eventos no científicos: no se escribe un MAT de trial ni RAW durante ellos. Sólo se guarda su duración/estado en `block_break_events.csv`; al reanudar después de pausa se reinicia el descanso, dejando trazabilidad. No se confunden con los REST estables del experimento.

Plan completo: **100 filas**, con **97 registros científicos** (48 movimientos y 49 REST) y **tres descansos de bloque**. Duración nominal **833 s = 13 min 53 s**, más precheck de 30 s, práctica y sobrecoste de guardado. La GUI muestra movimiento/48, registro/97 y bloque/3.

## Práctica y guía visual

Práctica / Demo enseña una vez las ocho condiciones: apertura 25/50/75/100 y después cierre 25/50/75/100, con preparación, movimiento, hold, release y reposo. Ese orden pedagógico **no cambia** el protocolo científico aleatorizado. No conecta hardware, crea sesión, directorios ni MAT. El banner indica MODO PRÁCTICA — NO SE GUARDAN DATOS CIENTÍFICOS.

Se reutilizan las imágenes locales de acquisition/references: apertura/cierre por nivel, posiciones iniciales y transiciones en ambos sentidos. No se generan imágenes y no se usan rutas absolutas. Si falta o falla un asset, aparecen instrucciones textuales. Una imagen orientativa jamás se convierte en measured aperture.

## Compatibilidad y persistencia

`buildMyoContinuousProtocol` y la ruta v1 siguen disponibles. Los archivos previos S01/S02/S03 se conservan íntegros; sus fases RAMP originales no se reinterpretan como MOVE/RELEASE. El piloto nuevo se genera con `buildMyoPilot2Protocol` y sus MAT usan `schema_version=myo-continuous-v2`. El validador acepta ambas versiones. Los campos nuevos aparecen también en el manifest de v2.

La persistencia atómica de V1, las validaciones round-trip y hashes permanecen activas. Los eventos de bloque usan CSV con promoción atómica; la validación numérica del CSV admite hasta 1 ns de redondeo de texto, sin cambiar la igualdad exacta del MAT RAW. Pausa/repetición conserva los prefijos con IDs nuevos; no reemplaza MAT previos. S04 existente se rechaza, nunca se sobrescribe.

## Comando manual P001/S04

En MATLAB Desktop, con la instalación física MyoMex existente configurada:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
p = buildMyoPilot2Protocol(Seed=20261008);
app = MyoContinuousAcquisitionApp(Protocol=p,ParticipantID="P001",SessionID="S04",PlacementID="P1");
```

Seleccionar brazo y, opcionalmente, introducir una nota de orientación real; practicar, conectar, completar Test signal 30s, revisar calidad y pulsar Iniciar / Seguir. No utilizar una nota inventada de ejemplo como registro físico. El comando sólo abre la GUI; no conecta ni adquiere automáticamente. Finalizar y revisar manifest/status al terminar. Mantener S01/S02/S03 sin modificaciones.

## Validación y gate

Validación inicial en MATLAB R2023b, 8 de octubre de 2026: **80/80 tests de adquisición PASS**, con 60 regresiones previas y 20 tests nuevos. Se verificaron coordenadas opening/closing, velocidad nominal, RELEASE distinto de REST, balance/randomización por seed, límites de dirección, el requisito de nota vigente entonces, metadatos, práctica sin archivos, assets presentes/ausentes y compatibilidad v1/v2. Esta evidencia histórica se conserva; la revisión posterior elimina el requisito de nota, como se describe abajo.

La suite conserva el estrés atómico de V1: 1000 iteraciones y 3000 promociones, sin temporales huérfanos tras éxito y con rechazo de overwrite de trials. Incluye el estrés mock prolongado de 526 s/81 trials. Después se ejecutaron explícitamente `runMyoAcquisitionSmoke` (25 trials sintéticos, PASS) y `runMyoPilot2Smoke` (833 s simulados, 48 movimientos, 49 REST, tres descansos de bloque sin MAT de trial, PASS). En piloto 2 se conservaron 130600 muestras EMG mock, incluidas 19248 muestras RELEASE, con hashes válidos en los 97 registros científicos. Las capturas de GUI se revisaron para PREPARE/MOVE/HOLD/RELEASE en ambos sentidos y descanso de bloque; la tarjeta de porcentaje se oculta en RELEASE.

Se leyeron y validaron 26 trials existentes de S01/S02/S03 para compatibilidad, sin modificarlos ni copiarlos. Los 47 archivos de esas sesiones conservaron exactamente sus hashes y no se añadieron/eliminaron archivos. Los 17 archivos de infraestructura previa, builder v1, tests previos y assets reservados también conservaron sus hashes. No existe una sesión humana P001/S04 creada por esta preparación. Los RAW humanos y resultados MAT mock permanecen fuera de Git.

Evidencia ligera local reproducible: [resumen](pilot2_validation/summary.json), [tests](pilot2_validation/test_results.csv), [protocolo congelado](pilot2_validation/protocol.csv), [integridad](pilot2_validation/integrity.json) y [hashes del código validado](pilot2_validation/implementation_hashes.csv). Ejemplos de GUI mock: [preparación de cierre](pilot2_validation/practice_closing_prepare.png), [hold de cierre](pilot2_validation/practice_closing_hold.png), [release](pilot2_validation/practice_closing_release.png) y [descanso de bloque](pilot2_validation/block_break_mock.png). El resumen identifica la carpeta de logs y resultados mock completos, ignorada por Git.

```text
PILOT2_PROTOCOL_READY = YES
OPEN_CLOSE_CONTRACT = PASS
CONSTANT_NOMINAL_SPEED = YES (nominal, no medida)
RELEASE_REST_SEPARATED = YES
RANDOMIZATION_TESTED = PASS
PRACTICE_UPDATED = YES
ALL_TESTS = 80/80 PASS; smoke V1 PASS; smoke piloto 2 PASS
READY_FOR_P001_S04 = YES
HUMAN_ACQUISITION_STARTED = NO
TRAINING_STARTED = NO
PUSH = NO
```

READY habilita el siguiente piloto manual de infraestructura e intención instruida, sujeto al precheck de señal; no declara DATASET_GENERAL_READY ni éxito científico de separabilidad. Cámara/visión permanecen excluidas definitivamente. Todos los cambios quedan locales, sin commit ni push.

## Revisión del 16 de octubre de 2026: nota de colocación opcional

A petición del operador, se elimina el bloqueo por nota de orientación vacía tanto en la GUI como en el backend. No se exige confirmación de postura: el operador comprueba físicamente codo/antebrazo/colocación. La nota queda opcional, sin texto inventado ni confirmación automática registrada. Tras completar el precheck de señal de 30 s puede iniciarse la sesión con ese campo vacío. El requisito de precheck de señal y la protección contra sobrescritura siguen activos.

Las dos pruebas que antes exigían la nota se sustituyen por pruebas del flujo precheck/inicio con nota vacía y aceptación de nota vacía, en blanco o ausente en el backend. Resultado: **80/80 tests PASS**, incluido el estrés atómico y el smoke mock previo, sin hardware. Los 47 archivos de S01/S02/S03 conservaron sus hashes. Evidencia separada de la validación inicial: [resumen](pilot2_validation/note_optional_20261016_summary.json), [tests](pilot2_validation/note_optional_20261016_tests.csv) y [hashes de los archivos revisados](pilot2_validation/note_optional_20261016_hashes.csv).
