# Benchmark Motor 2 Diagnostic

Resumen de la fase `Benchmark TD3 seeded retrain + motor 2 diagnostic`.
El objetivo es decidir si el problema del motor 2 viene de entrenamiento,
seleccion de checkpoint, reward, simulador o mapeo antes de retomar
Residual Lift o stop-band.

## Campana base analizada

Fuente local:

```text
Agentes/benchmark_td3_seeded_retrain_motor2_diagnostic/26-05-27_23-44-39/
```

Configuracion:

- seeds: `[11 22 33 44 55]`
- training episodes: `12000` por seed
- final test: `50` episodios
- GPU: RTX 5070 Laptop GPU con CUDA Forward Compatibility
- reward: `trackingMseActionRateReward`
- estado: `markov52`

Resultado:

- agregado: `Rejected`
- `ConditionA = 0`
- `ConditionB = 0`
- `Rejected = 5`
- mejor seed global: seed 22, episodio 6900

Metricas de campana:

- `trackingMSE mean = 0.053591`
- `trackingMAE mean = 0.181093`
- `actionL2 mean = 0.737733`
- `saturationFraction mean = 0.573518`
- `deltaActionL2 mean = 0.349939`

Motor 2:

- `trackingMSE_motor2 mean = 0.045047`
- `responseRange_motor2 mean = 0.140268`
- `motor2_flat_response flags = 3`
- `motor2_action_no_motion flags = 3`
- `motor2_tracking_outlier flags = 0`

Comparacion contra `Agent7250` en la evaluacion reproducida:

- `Agent7250 trackingMSE = 0.043045`
- `Agent7250 saturationFraction = 0.392086`
- `Agent7250 trackingMSE_motor2 = 0.043548`
- `Agent7250 responseRange_motor2 = 0.108838`

## Informe principal

Ver `motor2_ablation_report.md` para la lectura completa de sanity
extendido, permutation check y ablation corta.

## Figuras seleccionadas

- Falla / diagnostico seed 11: `figures/seed_011_motor_diagnostic.png`
- Reaccion mas clara seed 55: `figures/seed_055_motor_diagnostic.png`
- Resumen motor 2 campana base: `figures/motor2_diagnostic_summary.png`
- Sanity extendido de ganancia: `figures/motor_response_gain_matrix.png`
- Ablation motor 2: `figures/ablation_motor2_summary.png`

## Hipotesis abiertas

- Indice: no cambiar columnas hasta confirmar con `checkMotorReferencePermutation`.
- Signo: sanity extendido debe confirmar si acciones negativas producen flex util.
- Escala/zona muerta: el sanity extendido puede mostrar menor ganancia o deadzone en motor 2.
- Reward: probar `trackingMseActionRateMotorWeightedReward` sin cambiar el default oficial.
- Seleccion: usar `selectionMode="motor2_aware"` solo como criterio experimental.

## Plan de ablation

Comandos principales desde `matlab_code/`:

```matlab
results = run_motor2_simulation_sanity_check_extended();
```

```matlab
results = run_motor2_targeted_diagnostic_ablation(struct( ...
    'mode', 'smoke', ...
    'seeds', [11 55], ...
    'trainingEpisodes', 300, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

```matlab
results = run_motor2_reward_ablation(struct( ...
    'seeds', [11 22 55], ...
    'trainingEpisodes', 3000, ...
    'finalTestEpisodes', 20, ...
    'useGpu', true, ...
    'selectionMode', 'motor2_aware'));
```

No versionar `Agentes/`. Solo copiar summaries o figuras ligeras curadas a
esta carpeta de docs.
