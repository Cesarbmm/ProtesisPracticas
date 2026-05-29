# MATLAB Code Guide

Guia operativa corta del arbol `matlab_code/`.

## Fase actual: Benchmark TD3 seeded retrain + motor 2 diagnostic

La linea activa vuelve al TD3 base para diagnosticar si la falla visual
recurrente del motor 2 viene del entrenamiento residual o ya existe en el
entorno/simulador/mapeo.

Esta fase usa:

- agente: `td3`
- reward: `trackingMseActionRateReward`
- estado: `markov52`
- dataset pregrabado
- motores simulados
- `connect_glove=false`
- `unifyActions=false`
- `actionInterfaceVariant="baselineQuantized"`

Todo corre en software/simulacion. No usa hardware fisico, no cambia
COM3/COM4 y no activa ejecucion real.

Residual Lift y stop-band se pausaron porque no superaron de forma robusta
al benchmark `Agent7250` y mostraron falla visual recurrente en motor 2.
Los launchers se preservan en:

```text
workflows/future_experiments/residual_lift/
workflows/future_experiments/residual_stopband/
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

## Smoke benchmark + motor 2

Prueba corta antes de lanzar una campana larga:

```matlab
cd('C:/ruta/al/repo/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()

results = run_benchmark_td3_seeded_retrain_motor2_diagnostic(struct( ...
    'seeds', 66, ...
    'trainingEpisodes', 200, ...
    'trainingSaveEvery', 100, ...
    'episodeSaveFreq', 100, ...
    'auditFastSimulations', 2, ...
    'auditFullSimulations', 2, ...
    'auditTopK', 1, ...
    'finalTestEpisodes', 2, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true, ...
    'runMotor2SanityCheck', true));
```

El smoke debe generar al menos:

- `figures/seed_066_training_progress.png`
- `figures/seed_066_selected_checkpoint_episode_2_visual_test.png`
- `figures/seed_066_motor_diagnostic.png`
- `figures/motor2_diagnostic_summary.png`
- `summary/benchmark_seeded_summary.*`
- `summary/benchmark_seeded_figures.md`

## Campana real sugerida

```matlab
cd('C:/ruta/al/repo/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()

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

Si `12000` episodios es demasiado pesado, cambia solo
`trainingEpisodes` a `8000` o `15000` desde el struct de opciones.

Cada checkpoint seleccionado se evalua con `finalTestEpisodes=50` en la
campana real.

## Salidas

Cada ejecucion crea una carpeta nueva, sin sobrescribir corridas previas:

```text
../../Agentes/benchmark_td3_seeded_retrain_motor2_diagnostic/YY-MM-DD_HH-mm-ss/
```

Estructura principal:

```text
summary/
  benchmark_seeded_summary.csv
  benchmark_seeded_summary.txt
  benchmark_seeded_results.mat
  benchmark_seeded_figures.md
figures/
  seed_011_training_progress.png
  seed_011_selected_checkpoint_episode_50_visual_test.png
  seed_011_motor_diagnostic.png
  benchmark_training_overview.png
  benchmark_selected_checkpoints.png
  benchmark_final_comparison.png
  motor2_diagnostic_summary.png
seed_011/
  training/
  checkpoint_audit/
  final_test_50/
  motor_diagnostic.csv
motor2_sanity_check/
  motor2_sanity_check.csv
  motor2_sanity_check.png
```

El checkpoint seleccionado por seed se consulta con:

```matlab
results.perSeedTable(:, {'seed','selectedCheckpointEpisode', ...
    'selectedCheckpointPath','selectionReason'})
```

La informacion de GPU queda en:

```matlab
results.gpuInfo
```

Si MATLAB no expone una configuracion GPU segura para la version local, el
flujo sigue en CPU y guarda el motivo en `gpuFallbackReason`.

## Sanity check aislado del motor 2

Tambien se puede correr sin entrenamiento:

```matlab
results = run_motor2_simulation_sanity_check();
```

Guarda resultados bajo:

```text
../../Agentes/motor2_simulation_sanity_check/YY-MM-DD_HH-mm-ss/
```

Este helper manda acciones fijas al simulador para revisar indice, signo,
escala y respuesta del motor 2.

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
