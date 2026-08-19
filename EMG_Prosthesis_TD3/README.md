# EMG_Prosthesis_TD3

Proyecto MATLAB para entrenar y evaluar agentes TD3 en el control de una protesis mioelectrica usando senales EMG.

## Estado publicado

La version actual del proyecto deja este punto fijo historico:

- benchmark oficial: `Agent7250`
- linea residual `stop-band` confirmada alrededor de `2000` episodios, ahora pausada
- referencia residual reproducible historica previa: `seed 22`
- mejor residual single-run historico: `Agent1850`

La fase activa ya no promueve residual ni stop-band. El trabajo actual es
`Benchmark TD3 seeded retrain + motor 2 diagnostic`, con una subfase de
calibracion de respuesta del motor 2 antes de ajustar reward. `Agent7250`
sigue siendo el benchmark historico.

## Requisitos

- MATLAB
- Reinforcement Learning Toolbox
- Deep Learning Toolbox
- Signal Processing Toolbox
- dataset en `matlab_code/data/datasets/Denis Dataset/`

## Estructura relevante

- `matlab_code/config/`: configuracion global
- `matlab_code/src/`: entorno, reward, auditoria y launchers
- `matlab_code/agents/`: definicion de agentes y rama residual
- `matlab_code/checkpoints/canonical/`: benchmark y residual publicado
- `docs/td3_training_report/`: documentacion final curada
- `docs/benchmark_motor2_diagnostic/`: diagnostico actual de motor 2

## Flujos principales

Trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```

### Diagnostico actual de motor 2

```matlab
results = run_motor_response_conversion_diagnostic();

results = run_motor2_simulation_sanity_check_extended(struct( ...
    'initialMode','all'));

results = run_motor2_calibrated_action_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

Todo este flujo es solo software/simulacion.

### Flujo residual pausado con stop-band

```matlab
results = run_residual_lift_stopband_confirmation();
```

Esto usa:

- base congelada `Agent7250`
- una banda de parada temprana ya confirmada
- auditoria completa y retest final por seed

No es la linea principal actual; se conserva como experimento futuro.

### Discovery de una nueva stop-band

```matlab
results = run_residual_lift_stopband_discovery();
```

### Residual generico sobre cualquier base

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

### Tests canonicos

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

### Entrenamiento base de referencia

```matlab
trainInterface('td3','','')
```

## Portabilidad

En otra PC normalmente solo hay que revisar en `matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`

Y solo si se usa hardware:

- `params.comUNO`
- `params.comGlove`

`dataset_folder` y `agents_directory` deben quedar relativos/portables para el flujo publicado.

## Documentacion adicional

- `matlab_code/README.md`: guia operativa detallada
- `docs/td3_training_report/README.md`: documentos, figuras y compilacion manual
- `docs/benchmark_motor2_diagnostic/motor2_calibration_report.pdf`: reporte corto de calibracion de motor 2
