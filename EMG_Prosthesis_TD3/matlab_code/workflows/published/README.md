# Published Workflows

Launchers activos y estables que no forman parte del core reusable de
`src/`.

## Contenido activo

- `run_benchmark_td3_seeded_retrain_motor2_diagnostic.m`: fase actual,
  reentrenamiento TD3 base por seeds y diagnostico del motor 2.
- `run_motor2_simulation_sanity_check.m`: prueba controlada del simulador
  con acciones fijas, sin aprendizaje y sin hardware.
- `run_repo_smoke_validation.m`: validacion automatizada corta del repo.

## Experimentos pausados

Los flujos Residual Lift y residual stop-band se movieron a
`../future_experiments/`. Siguen disponibles con `addpath(genpath(pwd))`,
pero no son la linea principal actual.

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy o pausados
