# MATLAB Code Guide

Guia operativa corta del arbol `matlab_code/`.

## Estado operativo validado en este repo

- MATLAB detectado: `R2023b Update 11`
- toolboxes validadas: `Reinforcement Learning Toolbox`, `Deep Learning Toolbox`, `Signal Processing Toolbox`
- bootstrap validado desde `matlab_code/`
- benchmark canonico validado: `Agent7250`
- smoke residual validado: `run_residual_lift_stopband_confirmation(...)` reducido

El flujo oficial de simulacion queda centrado en:

- checkpoint benchmark: `getAgent7250CheckpointPath()`
- residual historico canonico: `getResidualFinalCheckpointPath()`
- linea residual activa: `run_residual_lift_stopband_confirmation()`
- helper de validacion local: `run_repo_smoke_validation()`

## Arranque minimo

Trabaja desde esta carpeta:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

Comprobacion minima:

```matlab
c = configurables();
disp(c.dataset_folder)
disp(getAgent7250CheckpointPath())
disp(getResidualFinalCheckpointPath())
```

## Test minimo recomendado

Smoke del benchmark canonico:

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 2, false);
```

Smoke integral de repo migrado:

```matlab
results = run_repo_smoke_validation();
```

Este helper:

- comprueba version y toolboxes
- valida `addpath`, `configurables()` y helpers de checkpoints
- corre el smoke del benchmark
- corre el smoke reducido de `stop-band confirmation`
- escribe resultados bajo `Agentes/repo_smoke_validation/`

## Flujo oficial actual

Linea residual activa publicada:

```matlab
results = run_residual_lift_stopband_confirmation();
```

Smoke reducido documentado:

```matlab
results = run_residual_lift_stopband_confirmation(struct( ...
    'stopBandEpisode', 2000, ...
    'stopBandWindow', [1750 2250], ...
    'seeds', 66, ...
    'trainingEpisodes', 200, ...
    'trainingSaveEvery', 100, ...
    'episodeSaveFreq', 100, ...
    'auditFastSimulations', 2, ...
    'auditFullSimulations', 2, ...
    'auditTopK', 1, ...
    'comparisonSimulations', 2, ...
    'generateReport', false, ...
    'compileReport', false));
```

## Artefactos canonicos

- checkpoints publicados: `checkpoints/canonical/`
- documentacion curada: `../docs/td3_training_report/`
- configuracion global: `config/configurables.m`

## Guia de estructura

- `src/`: core operativo reusable
- `agents/`: definiciones de agentes y variantes residuales
- `checkpoints/canonical/`: checkpoints pequenos publicados
- `data/`: dataset portable para simulacion
- `workflows/published/`: launchers vigentes y helpers de campana activos
- `workflows/legacy/`: launchers historicos movidos fuera del core
- `analysis/legacy/`: viewers legacy con rutas absolutas antiguas
- `development/archive/`: material historico y datasets auxiliares con procedencia preservada
- `src/runtime/`, `src/evaluation/`, `src/checkpoints/`: subdivision funcional del core MATLAB

Para clasificacion y reorganizacion prevista:

- ver `REPO_CLASSIFICATION.md`
- ver `MIGRATION_CHECKLIST.md`
- ver `src/readme.md`
