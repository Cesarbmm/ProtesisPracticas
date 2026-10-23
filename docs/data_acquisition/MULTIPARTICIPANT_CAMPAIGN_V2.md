# Campaña multi-participante V2 — OPEN/CLOSE instruido

**Documento histórico del piloto.** Para nuevas capturas, `runMyoMultiParticipantApp()` utiliza la [campaña oficial](OFFICIAL_MYO_ACQUISITION_PROTOCOL.md), con P0_SEATED_ARMREST, referencia JPG instalada directamente, checklist ampliado y seed por sesión. Los builders y el descriptor piloto de este documento siguen disponibles para lectura/regresión; no migran metadata antigua.

Esta interfaz prepara la ampliación del piloto a varias personas. OPEN/CLOSE durante MOVE es una señal preliminar prometedora; no se ha demostrado separabilidad robusta de cuatro niveles. No se entrenan modelos, no hay cámara/visión/MediaPipe/pose medida y no se inicia hardware automáticamente. `measured_aperture` sigue vacío y `measured_aperture_available=false`.

## Protocolo conservado

Se reutiliza `buildMyoPilot2Protocol` sin modificar ese builder ni `myoProtocolTarget`. `buildMyoCampaignProtocol` conserva exactamente condiciones, objetivos, tiempos, semilla y orden; añade identidad de campaña y corrige la postura operacional para las nuevas sesiones.

- Opening y closing, cada uno con niveles .25/.50/.75/1.00.
- Seis repeticiones por condición: 48 movimientos, tres bloques de 16; dos instancias de cada una de las ocho condiciones por bloque.
- Randomización reproducible con seed 20261008; no más de dos direcciones iguales consecutivas, incluso entre bloques. No se impone una nueva subdivisión en ciclos de ocho, que cambiaría el orden de S04.
- PREPARE 2 s; MOVE 1/2/3/4 s; HOLD 2 s; RELEASE 2 s; REST estable 5 s después de RELEASE. REST inicial 5 s.
- Tres descansos de bloque de 60 s, incluido el último; no son trials ni guardan RAW científico.
- Total: 48 movimientos + 49 REST = 97 registros científicos; tres eventos de descanso; 833 s nominales, más precheck y operación.

`target_aperture` siempre significa 0=cerrada, 1=abierta. Opening empieza en 0 y termina en el nivel. Closing empieza en 1 y termina en 1−nivel. `movement_level` es recorrido cómodo instruido, no fuerza ni medición física. Cierre completo: «NO APRIETES CON FUERZA».

## Postura y confirmación

La postura nueva es `P0_FORWARD_EXTENDED`: tronco erguido, hombro aproximadamente 90° de flexión, codo extendido aproximadamente 0°, muñeca neutra, brazo/palma según la imagen operacional aprobada. La imagen muestra la orientación de la palma; no se deducen otros ángulos ni posiciones desde un texto.

El archivo aportado existe como `acquisition/references/Referencia.jpg` (no `referencia.jpeg`). Se convierte sin generar contenido nuevo a `acquisition/assets/postures/P0_FORWARD_EXTENDED.png`; se conserva el hash de la fuente y de la imagen presentada.

Después de reservar una sesión, «Identidad / postura» presenta participante, sesión, campaña, brazo, placement e imagen. Hay tres confirmaciones sin preseleccionar: participante correcto, Myo colocado según referencia y postura correcta. Sólo entonces se habilita Test signal 30s. Cambiar la identidad/colocación invalida la confirmación y el precheck. Se verifica el hash de la postura antes de confirmar/iniciar. Falta de imagen aprobada bloquea la confirmación.

La nota de orientación continúa **opcional**. Esto sustituye, para la nueva campaña, el flujo anterior sin confirmación de postura; no altera ningún dato previo. Se guarda `posture_confirmed=true`, el asset relativo, su SHA256 y la hora de confirmación. La IMU sigue siendo auxiliar de estabilidad/postura, nunca label de mano.

## Registro de participantes

`MyoParticipantRegistry` mantiene `participants_registry.csv`: participant_id, created_utc, status, optional_alias, notes. La GUI utiliza un dropdown no editable: Pxxx, alias opcional y número de sesiones. Muestra última sesión y placement previo sólo como referencia, sin aplicarlo silenciosamente. Los recuentos corresponden a carpetas fuente; no resuelven automáticamente la identidad histórica pendiente de S04 ni aplican correcciones del ledger a los RAW.

«Nuevo participante» propone el siguiente Pxxx y lo muestra antes de confirmar. Se solicita sólo alias opcional, sin nombre real por defecto. El cálculo considera el registro, IDs inactivos/reservados y carpetas históricas. La reserva se escribe antes de crear `participant.json`; un fallo posterior no libera el ID. No hay API de borrado/renombrado de identidad. `setStatus` permite inactive/withdrawn sin reutilizar IDs. La identidad canónica no se edita en la GUI; se verifica `participant.json` al reservar sesiones.

Las operaciones de escritura usan un lock de directorio exclusivo entre procesos y promociones CSV atómicas con round-trip y hashes. Un preview obsoleto se rechaza; nunca asigna otro ID sin nueva confirmación. No se eliminan automáticamente locks de procesos interrumpidos: si persiste uno, revisar que no exista otro escritor antes de intervenir manualmente. El registro y las reservas son datos operacionales que deben respaldarse; borrar manualmente toda su evidencia pierde el historial de reservas.

Inicializar el registro importa únicamente IDs de carpetas históricas; no infiere identidades reales ni reescribe sesiones. `created_utc` de entradas legacy queda vacío porque no se conoce la fecha de creación del participante. Las consultas y la práctica no inicializan ni escriben el registro.

## Sesiones e identidad de campaña

«Nueva sesión» reserva S001, S002… por participante; interpreta S01 y S001 como el mismo ordinal para calcular el siguiente. P001 con S01–S04 conserva esas carpetas y recibe S005. La reserva durable queda en `session_reservations.csv` con UUID y campaña, antes de crear el directorio de sesión. Cancelar una reserva consume el ordinal: nunca se reutiliza.

Una sesión nueva exige otra confirmación y otro precheck. La misma app puede finalizar, seleccionar otra persona y reservar una nueva sesión. No se puede cambiar identidad durante captura o práctica. Los directorios finales se crean de forma exclusiva; nunca hay overwrite. Los estados y recovery existentes continúan funcionando.

Metadatos: participant_id, session_id, session_uuid, campaign_id=`PILOT2_OPEN_CLOSE_V1`, capture_utc, arm, placement_id, arm_posture_id, protocol_version=`OPEN_CLOSE_S04_V1`, random_seed, protocol_sha256 y acquisition_code_hashes, además de confirmaciones y procedencia visual. `myoCampaignConfig` es un descriptor con builder, postura, assets y seed; futuras campañas pueden proporcionar otro descriptor compatible sin editar la GUI central.

## Cues sincronizados y práctica

`MyoVisualCueEngine` no tiene reloj ni reproduce vídeo. Obtiene el mismo `elapsed` del protocolo que el target. En MOVE:

```text
progress = clip((elapsed - prepare_s) / move_s, 0, 1)
frame = 1 + floor(progress * (N - 1))
```

HOLD fija el último frame, PREPARE muestra prepare_closed/open y RELEASE/REST muestran texto propio; admiten `release.png` y `rest_relaxed.png` opcionales. Como esos dos assets no fueron aportados, se usa fallback textual explícito, sin representar REST como una apertura obligatoria. No se muestra RAMP al participante.

La auditoría visual detectó que los nombres de los MP4 no representan el sentido canónico: `Cierre-Apertura.mp4` va cerrada→abierta y `Apertura-Cierre.mp4` abierta→cerrada. Algunos clips parciales incluyen retorno al inicio. La preparación offline usa los frames revisados 36:106 de los dos clips completos; cada nivel utiliza el prefijo nominal correspondiente. Tras la revisión del operador, **sólo opening 25 %** amplía su guía visual de 36:54 a **36:63**, para hacer visible la apertura de dedos. Los otros siete tramos no cambian. El target .25, MOVE de 1 s y todas las demás condiciones científicas permanecen intactos. Se registra `visual_revision=OPENING25_VISIBLE_ENDPOINT_63` en el manifest. Los porcentajes de una guía visual no son calibración de pose ni medición de mano. El manifest registra fuente, hash, tramo y secuencia exactos. No se alteran los MP4 originales.

Los frames derivados se excluyen de Git y se regeneran offline. Se fija únicamente el metadato PNG `ImageModTime` a 2000-01-01 para evitar que el momento de conversión cambie los hashes; no representa la fecha de captura. La hora real de adquisición está en la metadata de sesión. Antes de sesión se verifican los hashes del manifest y de todos los assets usados; se conserva una copia exacta del manifest en la sesión. No se decodifica vídeo en captura. La sincronización es de reloj/selección lógica: no certifica latencia física de pantalla ni seguimiento real del participante.

Práctica usa el **mismo** motor y las mismas duraciones, enseña las ocho condiciones una vez, y no crea participante, reserva, sesión, manifest ni RAW. Muestra «MODO PRÁCTICA — NO SE GUARDAN DATOS CIENTÍFICOS». No conecta Myo por sí sola.

PREPARE resalta en rojo tanto la instrucción física como la fase; al comenzar MOVE recupera el color normal. El gráfico EMG utiliza un layout que ocupa automáticamente su espacio al redimensionar la ventana. Este cambio sólo afecta presentación: no cambia la ventana temporal de 2 s, canales, timestamps, escalas ni RAW.

## Almacenamiento y anotaciones históricas

```text
data_acquisition/
  participants_registry.csv
  session_reservations.csv
  session_annotations.csv
  Pxxx/
    participant.json
    Sxxx/
      metadata.json
      protocol.csv
      quality_precheck.mat
      visual_cues_manifest.json
      session_manifest.csv
      session_status.json
      trials/
      recovery/
```

Se mantienen los schemas v1/v2 legibles. Ningún archivo S01–S04 se modifica, mueve o renombra. El ledger separado `session_annotations.csv` es append-only: UUID de anotación, ruta fuente, SHA256 del manifest y metadata originales, campo, valor original/corregido, motivo y UTC. Una nueva anotación no elimina las anteriores. Los análisis deben consultar el ledger explícitamente; los lectores RAW conservan los originales.

El operador informó posteriormente que S04 tuvo postura extendida al frente y que el participant_id original no correspondía a la persona real. Se creó una anotación de postura con `annotateMyoSession`, referida a los hashes originales. La identidad real **no se asigna automáticamente** y queda pendiente. Primero el operador debe identificar/crear explícitamente el participante correcto en el registro, y después llamar a la API con ese ID. No se inventan datos personales. El registro se inicializó importando únicamente P001 como entrada legacy; no se crearon personas nuevas ni sesiones humanas. RAW, registro, reservas, participant.json y ledger quedan locales/ignorados por Git.

## Comandos manuales

Abrir la interfaz, sin conectar hardware ni crear identidades:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_myo_calibration\EMG_Prosthesis_TD3\matlab_code');
addpath('acquisition');
app = runMyoMultiParticipantApp();
```

Seleccionar/crear participante → Nueva sesión → Identidad / postura → tres confirmaciones → Conectar Myo → Test signal 30s → revisar señal → Iniciar / Seguir. Se puede conectar antes de revisar la pantalla, pero el precheck permanece bloqueado hasta confirmar. La práctica está disponible sin crear identidad.

Si faltan los frames derivados después de restaurar el repositorio, prepararlos **antes** de abrir la app:

```matlab
prepareMyoCampaignAssets();
```

El helper verifica que las fuentes coincidan con el manifest previo antes de reconstruirlo. Si cambió una fuente aprobada, falla explícitamente y exige revisión; no se regenera durante una captura.

API de anotación manual de identidad, usando un ID **ya identificado y registrado**, no el literal de ejemplo:

```matlab
root = fullfile(pwd,'data_acquisition');
source = fullfile(root,'P001','S04');
% correctID lo decide el operador; no asumirlo a partir de la carpeta.
annotation = annotateMyoSession(root,source,"participant_id",correctID,"Identidad verificada explícitamente por el operador");
```

Validación sin hardware:

```matlab
r = runtests('tests/acquisition');
smoke = runMyoMultiParticipantSmoke();
```

Los comandos legacy siguen disponibles para reproducir el flujo anterior; para esta campaña debe usarse el runner nuevo. No se inicia adquisición humana desde los tests ni desde el smoke.

## Resultados y gate

Validación cerrada el 22 de octubre de 2026 en MATLAB R2023b. **110/110 pruebas distintas PASS: 80 regresiones y 30 pruebas de campaña nuevas**. Se ejecutó la suite completa entonces disponible (108/108); tras los últimos ajustes de padding de botones y metadato PNG se repitieron las pruebas afectadas y se añadieron sus dos regresiones (30/30 de campaña). El CSV conserva la procedencia de cada resultado, sin presentar esa combinación como una única invocación de 110 tests.

Las regresiones incluyen 1000 iteraciones/3000 promociones atómicas, el estrés mock de 526 s/81 trials, rechazo de overwrite, ausencia de temporales huérfanos tras éxito y smoke V1. El smoke nuevo final recorre los **833 s simulados**, 48 movimientos, 97 registros y tres descansos; verifica los hashes de cada trial, ausencia de RAW científico en descansos, práctica sin escritura y siguiente reserva S002 con UUID nuevo. La regeneración de assets produjo el mismo manifest y hashes byte a byte con las fuentes existentes y MATLAB R2023b.

Se validaron en lectura 123 trials históricos de S01–S04. Los **151 archivos** originales conservaron exactamente sus hashes y su conjunto de rutas. También siguen intactos el builder S04, el cálculo temporal del target, la promoción atómica y MyoMexDataSource recibidos al iniciar esta etapa. No se creó ninguna sesión humana ni se abrió hardware; P001/S001/S002 usados por el smoke viven sólo bajo results, con source MOCK.

Evidencias ligeras, sin MAT/RAW humano: [resumen](campaign_v2_validation/summary.json), [tests y procedencia](campaign_v2_validation/test_results.csv), [protocolo](campaign_v2_validation/protocol.csv), [integridad](campaign_v2_validation/integrity.json), [hashes del código](campaign_v2_validation/implementation_hashes.csv). Capturas mock revisadas: [confirmación de postura](campaign_v2_validation/setup_confirmation_mock.png), [práctica de cierre completo a 768 px](campaign_v2_validation/practice_closing100_768.png), [MOVE](campaign_v2_validation/opening_move_mock.png) y [descanso](campaign_v2_validation/block_break_mock.png). Los logs y MAT mock completos están en las rutas locales indicadas en el resumen, ignoradas por Git.

```text
PARTICIPANT_REGISTRY = PASS
SESSION_MANAGEMENT = PASS
HISTORICAL_DATA_PRESERVED = YES
P0_POSTURE_GATE = PASS
VISUAL_CUE_SYNC = PASS
PRACTICE_MODE = PASS
S04_PROTOCOL_UNCHANGED = YES
ALL_TESTS = 110/110
READY_FOR_MULTIPARTICIPANT_PILOT = YES
HUMAN_ACQUISITION_STARTED = NO
TRAINING_STARTED = NO
PUSH = NO
```

READY sólo se refiere a preparación de infraestructura del siguiente piloto manual. Quedan pendientes el precheck físico por sesión y la asignación explícita de la identidad real de S04. No se declara GENERAL_DATASET_READY, calibración de apertura, separabilidad robusta ni éxito científico multi-participante.

## Revisión visual y preparación de publicación — 22 de octubre de 2026

A petición del operador, PREPARE usa texto rojo de alerta, sólo opening 25 % amplía su endpoint visual al frame 63 y el eje EMG pasa a un grid que ocupa automáticamente el ancho disponible. Las otras siete secuencias y los archivos de imagen usados conservan sus hashes. El target de apertura .25, MOVE de 1 s, protocolo completo y datos de adquisición no cambian.

Se ejecutó nuevamente la suite completa: **113/113 PASS**, incluidas tres pruebas nuevas de color, apertura 25 % y redimensionado sin alterar señales. El smoke completo volvió a pasar (833 s simulados, 48 movimientos, 97 registros). Los 155 archivos locales de datos, registro y anotaciones presentes al inicio de esta revisión permanecieron idénticos por hash. La evidencia actual está en [ui_polish_validation](ui_polish_validation/summary.json), con [tests](ui_polish_validation/test_results.csv), [código validado](ui_polish_validation/implementation_hashes.csv), [PREPARE rojo](ui_polish_validation/prepare_red.png), [opening 25 %](ui_polish_validation/opening25_hold.png) y [gráfico con señal mock](ui_polish_validation/live_mock.png).

El operador autorizó publicar el trabajo acumulado en la rama `experiment/myo-continuous-calibration-dataset`. Los valores PUSH=NO de los informes anteriores corresponden a sus cierres locales. Para la publicación se excluyen RAW humanos, registro de participantes, reservas, ledger, resultados MAT, MEX/DLL/SDK y frames derivados; se incluyen código, documentación, evidencias mock y fuentes visuales de guía. El commit publicado y el estado remoto se verifican con Git. Reabrir la app para cargar los nuevos cues.
