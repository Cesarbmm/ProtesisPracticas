# MATLAB Code Guide

Guia operativa corta del arbol `matlab_code/`.

## Fase actual: Motor 2 targeted diagnostic and ablation

La linea activa aisla el problema del motor 2 antes de volver a entrenar
campanas largas o retomar Residual Lift/stop-band. El benchmark TD3 base ya
confirmo que el problema tambien aparece sin residual.

Los flujos activos usan:

- agente: `td3`
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

## Sanity extendido sin entrenamiento

Primera prueba recomendada para revisar indice, signo, zona muerta y escala
del simulador por motor:

```matlab
cd('C:/ruta/al/repo/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()

results = run_motor2_simulation_sanity_check_extended();
```

Guarda resultados bajo:

```text
../../Agentes/motor2_simulation_sanity_check_extended/YY-MM-DD_HH-mm-ss/
```

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
