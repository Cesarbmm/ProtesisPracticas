# MATLAB Code Guide

Guia operativa corta del arbol `matlab_code/`.

## Fase actual: Frozen Agent7250 + motor 2 isolated correction

La linea activa usa `Agent7250` congelado y evalua correcciones aisladas de
motor 2 antes de volver a entrenar campanas largas o retomar Residual
Lift/stop-band. El benchmark TD3 base ya confirmo que el problema tambien
aparece sin residual, y los reentrenamientos desde cero pueden degradar M4.

Los flujos activos usan:

- agente: `Agent7250` congelado para la validacion activa
- reward: `trackingMseActionRateReward`
- estado: `markov52`
- dataset pregrabado
- motores simulados
- `connect_glove=false`
- `unifyActions=false`
- `actionInterfaceVariant="baselineQuantized"`
- GPU si esta disponible mediante `configureGpuForTraining(true)`

Todo corre en software/simulacion. No usa hardware fisico, no cambia
COM3/COM4 y no activa ejecucion real.

Residual Lift y stop-band se pausaron porque no superaron de forma robusta
al benchmark `Agent7250` y mostraron falla visual recurrente en motor 2.
Los launchers se preservan en:

```text
workflows/future_experiments/residual_lift/
workflows/future_experiments/residual_stopband/
workflows/future_experiments/paused_motor2_training/
```

## Arranque minimo

Trabaja desde esta carpeta:

```matlab
cd('C:/ruta/al/repo/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

Comprobacion minima:

```matlab
c = configurables();
disp(c.dataset_folder)
disp(getAgent7250CheckpointPath())
```

## Sanity all-motor sin entrenamiento

Primera prueba recomendada para revisar indice, signo, zona muerta y escala
del simulador por motor:

```matlab
cd('C:/ruta/al/repo/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()

results = run_all_motor_actuation_sanity_check_extended(struct( ...
    'initialMode', 'all', ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"]));
```

Guarda resultados bajo:

```text
../../Agentes/all_motor_actuation_sanity_check_extended/YY-MM-DD_HH-mm-ss/
```

## Calibracion de respuesta antes de reward

Esta fase revisa si el bajo rango util del motor 2 aparece en el simulador
de encoder, en `encoder2Flex` o en `flexJoined_scale`, antes de ajustar mas
la reward.

```matlab
results = run_motor_response_conversion_diagnostic();
```

Para no concluir sobre acciones negativas desde una posicion ya abierta:

```matlab
results = run_motor2_simulation_sanity_check_extended(struct( ...
    'initialMode','all'));
```

Smoke de accion calibrada, sin campana larga:

```matlab
results = run_motor2_calibrated_action_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

La variante `motorCalibratedQuantized` es experimental y solo de
simulacion. No reemplaza `baselineQuantized` ni se debe llevar a hardware.

Resultado corto del 2026-06-04:

- `run_motor_response_conversion_diagnostic()` mostro que motor 2 si mueve
  encoder en niveles bajos, pero `encoder2Flex` lo aplana hasta cruzar la
  zona util. Ejemplo: accion `0.25` aplica PWM `64`, mueve encoder
  `3598`, pero deja `encoder2FlexRange=0` y `normalizedFlexRange=0`.
- Con `initialMode='all'`, las acciones negativas desde `home` no son
  concluyentes porque la mano ya esta abierta. Desde `mid` y `closed`, motor
  2 si muestra rango flex util con acciones negativas.
- La ablation corta de 500 episodios con seeds `[11 55]` favorecio
  `motorCalibratedQuantized` en tracking global y saturacion, pero no paso
  aceptacion:
  - baseline: `trackingMSE=0.099748`, `trackingMSE_motor2=0.112913`,
    `responseRange_motor2=0.170200`, `saturationFraction=0.169857`
  - calibrada: `trackingMSE=0.092527`, `trackingMSE_motor2=0.070589`,
    `responseRange_motor2=0.167690`, `saturationFraction=0.053934`
  - flags calibrada: `motor2_flat_response=1/2`,
    `motor2_action_no_motion=1/2`

Lectura: la calibracion de accion ayuda al error y reduce saturacion, pero
todavia no aumenta el rango util promedio de motor 2. Antes de volver a
reward/residual/stop-band conviene revisar `encoder2Flex`, `gap.idx`,
`breakLimit.idx` y la dinamica del simulador en posiciones `mid/closed`.

## Intento experimental de conversion encoder2Flex

Se agrego `encoder2FlexVariant="motor2Calibrated"` como variante
experimental. El default sigue siendo `encoder2FlexVariant="baseline"`.
La variante baja solo el umbral de motor 2 con
`motor2Encoder2FlexGapOffset=-64`; no cambia `definitions.m`, no toca
hardware y no reemplaza la conversion oficial.

Diagnostico sin entrenamiento:

```matlab
results = run_motor2_conversion_fix_diagnostic(struct( ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"], ...
    'initialMode', 'all'));
```

Ablation corta:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

Resultado corto inicial del 2026-06-09:

- el diagnostico before/after marco `calibration_accepted=true` como
  conversion aislada: motor 2 paso de `0.226875` a `0.227364` en rango
  normalizado promedio y M1/M3/M4 no cambiaron;
- en `home`, accion `0.25` paso de `normalizedFlexRange=0` a `0.005336`;
- la ablation de entrenamiento no acepto ninguna configuracion:
  `baseline + conversion calibrada` bajo `trackingMSE_motor2` a `0.098362`
  pero redujo `responseRange_motor2` a `0.137716` y subio flags;
- `accion calibrada + conversion calibrada` bajo saturacion a `0.004167`,
  pero no mejoro suficientemente `trackingMSE_motor2` ni los flags.

Decision: conservar `motor2Calibrated` como herramienta experimental de
diagnostico, no como default. El siguiente paso debe revisar limites/mapeo
de motor 2 antes de volver a reward o campanas largas.

Resultado actualizado del 2026-06-18 con `gapOffset=-256` y
`selectionMode="motor2_final_gate"`:

| Config | MSE | MSE M2 | Range M2 | Saturacion | Flat | No-motion | Aceptada |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline + conversion baseline | 0.099748 | 0.112913 | 0.170200 | 0.169857 | 1 | 0 | no |
| baseline + conversion motor2Calibrated | 0.092616 | 0.078885 | 0.181432 | 0.133639 | 0 | 0 | si |
| accion calibrada + conversion baseline | 0.092527 | 0.070589 | 0.167690 | 0.053934 | 1 | 1 | no |
| accion calibrada + conversion motor2Calibrated | 0.075777 | 0.078055 | 0.172212 | 0.108406 | 1 | 1 | no |

La mejora que paso el smoke centrado en motor 2 fue
`baselineQuantized + motor2Calibrated` con
`motor2Encoder2FlexGapOffset=-256`. Frente al baseline bajo el MSE global,
bajo el MSE de motor 2, subio `responseRange_motor2` y dejo los flags de
motor 2 en cero para ese smoke. Esa lectura quedo revocada por la validacion
all-motor posterior: no se acepta como fix global. El default oficial sigue
siendo `encoder2FlexVariant="baseline"` y
`actionInterfaceVariant="baselineQuantized"`.

Validacion mediana del 2026-06-18 con seeds `[11 22 55]`,
`trainingEpisodes=1500`, `finalTestEpisodes=20` y `gapOffset=-256`:

```text
Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57/
```

La lectura cambio: no se debe aceptar la variante mirando solo motor 2. Se
genero una validacion por todos los motores en:

```text
summary/all_motor_regression_validation_by_seed.csv
summary/all_motor_regression_validation_summary.csv
summary/baseline_vs_motor2_calibrated_all_motor_comparison.csv
summary/all_motor_regression_validation.md
```

Comparacion `baseline + baseline` contra `baseline + motor2Calibrated`:

| Motor | Baseline MSE | Cal MSE | Baseline range | Cal range | Baseline sat | Cal sat | Flat B/C | No-motion B/C | Regression |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| M1 | 0.049273 | 0.046642 | 0.158289 | 0.184793 | 0.110094 | 0.410934 | 2/1 | 1/1 | si |
| M2 | 0.087531 | 0.071070 | 0.155809 | 0.160425 | 0.109722 | 0.105740 | 1/1 | 0/0 | no |
| M3 | 0.118077 | 0.120305 | 0.428794 | 0.441262 | 0.137444 | 0.090938 | 0/0 | 0/0 | no |
| M4 | 0.073825 | 0.070127 | 0.149345 | 0.151670 | 0.309727 | 0.415941 | 2/3 | 2/3 | si |

Motor 2 mejora en MSE y rango, pero mantiene 1 flag flat agregado. Motor 4
no empeora en MSE ni rango promedio, pero si empeora en saturacion y flags
(`flat` y `action-no-motion`). Visualmente, motor 4 sigue casi plano con
acciones altas/saturadas en seed 55; esto ya existia en baseline, pero la
variante lo empeora en conteo de flags. Por eso la direccion correcta queda:
`Motor 2 fix + all-motor regression validation`.

## Seleccion experimental con compuerta final de motor 2

La ablation con `motor2Calibrated` mostro que algunos checkpoints auditados
tenian buen motor 2, pero el test final podia terminar con flags. Por eso se
agrego `selectionMode="motor2_final_gate"`.

Este modo:

- rankea checkpoints por flags de motor 2, rango de motor 2, MSE motor 2,
  tracking global, saturacion y esfuerzo;
- prueba varios candidatos finales, no solo el primero;
- guarda `motor2_final_gate_attempts.csv` dentro de `seed_xxx/final_test_N/`;
- acepta el primer candidato sin `motor2_flat_response`, sin
  `motor2_action_no_motion`, con `responseRange_motor2 >= 0.17` o al menos
  `40%` de `targetRange_motor2`;
- registra `globalOk` y `saturationOk` para revisar el tradeoff, pero no los
  usa como bloqueo duro;
- si ningun candidato pasa motor 2, usa fallback al mejor intento y lo deja documentado en
  `selectionReason`.

Smoke recomendado:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'auditTopK', 8, ...
    'selectionMode', 'motor2_final_gate', ...
    'useGpu', true));
```

No cambia la seleccion oficial del benchmark, que sigue por defecto en
`selectionMode="global"`.

Para nuevas validaciones de esta linea, usar la compuerta all-motor:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 22 55], ...
    'trainingEpisodes', 1500, ...
    'finalTestEpisodes', 20, ...
    'auditTopK', 8, ...
    'selectionMode', 'all_motor_final_gate', ...
    'motor2Encoder2FlexGapOffset', -256, ...
    'useGpu', true));
```

Ese modo prueba candidatos finales y exige que todos los motores pasen
flags/rango antes de aceptar. Si no hay candidato all-motor limpio, usa
fallback y deja el motivo documentado en `all_motor_final_gate_attempts.csv`.

La validacion de 1500 episodios en
`../../Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57/` mostro
que `baselineQuantized + motor2Calibrated` mejora M2, pero no pasa M1-M4:
M1 sube saturacion y M4 sube saturacion junto con flags `flat` y
`action-no-motion`. Por eso la fase activa es ahora:
`Motor 2 fix + all-motor regression validation`.

Revision visual comparable de esa corrida:

```matlab
results = run_all_motor_visual_comparison_from_run(struct( ...
    'runRoot', 'Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57', ...
    'configsToCompare', ["baseline_quantized_conversion_baseline", ...
                         "baseline_quantized_conversion_motor2_calibrated"], ...
    'seeds', [11 22 55]));
```

Sanity all-motor sin entrenamiento:

```matlab
results = run_all_motor_actuation_sanity_check_extended(struct( ...
    'initialMode', 'all', ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"]));
```

Comparacion contra Agent7250:

```matlab
results = run_compare_against_canonical_benchmark_all_motor(struct( ...
    'runRoot', 'Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57', ...
    'finalTestEpisodes', 20));
```

Resultado de validacion corta del 2026-06-22:

```text
../../Agentes/motor2_conversion_fix_ablation/26-06-22_09-21-51/
```

Configuracion: seeds `[11 55]`, `trainingEpisodes=300`,
`finalTestEpisodes=5`, `auditTopK=4`,
`selectionMode="all_motor_final_gate"`, `gapOffset=-256`.

Lectura:

- `baselineQuantized + motor2Calibrated` mejora MSE global
  `0.106857 -> 0.100075`, baja saturacion global `0.100641 -> 0.006250`,
  mejora MSE motor 2 `0.141460 -> 0.100132`, sube rango motor 2
  `0.130941 -> 0.169585` y elimina flags de motor 2 `flat 2 -> 0`.
- M4 baja saturacion `0.369231 -> 0.000000` y elimina
  `high_action_flat`, pero sigue con `flat 2/2` y `action-no-motion 2/2`.
- M1 empeora en trackingMSE `0.066164 -> 0.080685`.
- Ninguna configuracion fue aceptada: `acceptedConversion=0` en todas y
  cada seed quedo con
  `selectionReason="fallback_diagnostic_no_checkpoint_passed_all_motor_gate"`.

Decision: hay mejora diagnostica clara en M2 y saturacion, pero no mejora
aceptable all-motor. No promover `motor2Calibrated` ni
`motorCalibratedQuantized`; mantener la siguiente fase enfocada en M1-M4.

## Agent7250 congelado + correccion aislada de motor 2

La fase activa ya no entrena TD3 desde cero. Las corridas de
`run_benchmark_td3_seeded_retrain_motor2_diagnostic` y
`run_motor2_conversion_fix_ablation` entrenaban desde cero
(`newTraining=true` crea un agente nuevo en `trainInterface`).
`Agent7250` se usaba como benchmark historico, no como politica congelada.
La degradacion de M4 aparecio en esos checkpoints nuevos.

La validacion final congelada se hizo con 50 episodios:

```matlab
resultsFrozen = run_agent7250_frozen_conversion_evaluation(struct( ...
    'gapOffsets', [0 -64 -128 -256], ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

Salida revisada:

```text
../../Agentes/agent7250_frozen_conversion_evaluation/26-06-23_09-38-15/
```

| Config | MSE | MSE M2 | Range M2 | M2 flags | MSE M4 | Range M4 | M4 flags | Aceptada |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Agent7250 baseline | 0.037229 | 0.042474 | 0.109618 | 3 | 0.026250 | 0.231700 | 0 | no |
| Agent7250 + motor2Calibrated -64 | 0.037113 | 0.041993 | 0.110996 | 3 | 0.026250 | 0.231700 | 0 | no |
| Agent7250 + motor2Calibrated -128 | 0.037003 | 0.041534 | 0.112352 | 3 | 0.026250 | 0.231700 | 0 | no |
| Agent7250 + motor2Calibrated -256 | 0.036800 | 0.040681 | 0.115000 | 3 | 0.026250 | 0.231700 | 0 | no |

La conversion `motor2Calibrated` no dano M4 con `Agent7250` congelado, pero
no se acepta porque conserva 3 flags en M2.

Luego se probo una correccion heuristica que solo puede cambiar motor 2:

```matlab
results = run_motor2_only_correction_evaluation(struct( ...
    'mode', 'heuristic', ...
    'gapOffset', -256, ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

Salida revisada:

```text
../../Agentes/agent7250_motor2_only_correction_evaluation/26-06-23_09-28-45/
```

| Config | MSE | MSE M2 | Range M2 | M2 flags | MSE M4 | Range M4 | M4 flags | non-M2 delta | Aceptada |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Agent7250 baseline | 0.037229 | 0.042474 | 0.109618 | 3 | 0.026250 | 0.231700 | 0 | 0 | no |
| Agent7250 + motor2Calibrated -256 | 0.036800 | 0.040681 | 0.115000 | 3 | 0.026250 | 0.231700 | 0 | 0 | no |
| Agent7250 + M2 heuristic | 0.037127 | 0.042015 | 0.110570 | 3 | 0.025986 | 0.231700 | 0 | 0 | no |
| Agent7250 + M2 heuristic + motor2Calibrated -256 | 0.036692 | 0.040224 | 0.115923 | 3 | 0.025986 | 0.231700 | 0 | 0 | no |

La correccion M2-only si mantiene M1, M3 y M4 intactos
(`maxNonMotor2ActionDelta=0`), pero tambien queda rechazada porque M2
mejora en metricas y conserva flags. Decision actual: no aceptar el fix
global entrenado desde cero ni el candidato M2-only actual. La ruta
correcta sigue siendo `Agent7250` congelado + correcciones aisladas de M2,
pero solo se aceptaran si limpian flags de M2 sin tocar M1/M3/M4.
`baselineQuantized` sigue siendo la accion oficial; `motorCalibratedQuantized`
queda como experimento futuro y no se recomienda para la linea principal.

Barrido de limites sin entrenamiento:

```matlab
results = run_motor2_encoder2flex_limit_sweep_diagnostic(struct( ...
    'gapOffsets', [0 -32 -64 -96 -128 -192 -256], ...
    'breakOffsets', 0, ...
    'initialMode', 'all'));
```

Resultado corto del 2026-06-09:

- candidato seleccionado: `gapOffset=-64`, `breakOffset=0`;
- `gap.idx` experimental: `3650 -> 3586`;
- motor 2 low-action range en `home` para accion `0.25`:
  `0.000000 -> 0.000849`;
- rango promedio motor 2: `0.226875 -> 0.227189`;
- M1/M3/M4 sin regresion y sin inversion de signo.

Decision: usar `-64` como default experimental de
`motor2Calibrated`, pero seguir dejando `encoder2FlexVariant="baseline"`
como default oficial. No lanzar campana larga hasta repetir una ablation
corta con este candidato conservador.

## Smoke integrado del diagnostico

```matlab
results = run_motor2_targeted_diagnostic_ablation(struct( ...
    'mode', 'smoke', ...
    'seeds', [11 55], ...
    'trainingEpisodes', 300, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

## Ablation corta

```matlab
results = run_motor2_reward_ablation(struct( ...
    'seeds', [11 22 55], ...
    'trainingEpisodes', 3000, ...
    'finalTestEpisodes', 20, ...
    'useGpu', true, ...
    'selectionMode', 'motor2_aware'));
```

Salidas:

```text
../../Agentes/motor2_targeted_diagnostic_ablation/YY-MM-DD_HH-mm-ss/
../../Agentes/motor2_reward_ablation/YY-MM-DD_HH-mm-ss/
```

## Benchmark TD3 base largo solo si se necesita

```matlab
results = run_benchmark_td3_seeded_retrain_motor2_diagnostic(struct( ...
    'seeds', [11 22 33 44 55], ...
    'trainingEpisodes', 12000, ...
    'trainingSaveEvery', 100, ...
    'episodeSaveFreq', 100, ...
    'auditFastSimulations', 20, ...
    'auditFullSimulations', 50, ...
    'auditTopK', 5, ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true, ...
    'runMotor2SanityCheck', true));
```

Cada ejecucion crea una carpeta nueva bajo `../../Agentes/`. Esa carpeta no
se versiona.

Criterios para considerar una mejora en campana corta:

- `motor2_flat_response <= 1/3`
- `motor2_action_no_motion <= 1/3`
- `responseRange_motor2 >= 0.20` promedio o al menos 50% de
  `targetRange_motor2`
- `trackingMSE_motor2` mejora contra baseline actual o `Agent7250`
- tracking global no empeora mas de 10%
- saturacion no empeora mas de 15%

## Smoke integral de repo

```matlab
results = run_repo_smoke_validation();
```

Este helper valida toolboxes, dataset, `Agent7250`, un test corto del
checkpoint canonico y una corrida benchmark TD3 muy pequena.

## Artefactos canonicos

- benchmark historico: `getAgent7250CheckpointPath()`
- checkpoints publicados: `checkpoints/canonical/`
- documentacion curada: `../docs/td3_training_report/`
- configuracion global: `config/configurables.m`

## Guia de estructura

- `src/`: core operativo reusable
- `agents/`: definiciones de agentes y variantes residuales
- `config/`: configuracion global y definiciones
- `data/`: dataset portable para simulacion
- `workflows/published/`: launchers activos
- `workflows/future_experiments/`: Residual Lift y stop-band pausados
- `workflows/legacy/`: launchers historicos no prioritarios
- `analysis/legacy/`: viewers legacy con rutas antiguas
- `development/archive/`: material historico preservado
