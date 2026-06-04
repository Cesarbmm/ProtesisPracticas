# Published Workflows

Launchers activos y estables que no forman parte del core reusable de
`src/`.

## Contenido activo

- `run_benchmark_td3_seeded_retrain_motor2_diagnostic.m`: fase actual,
  reentrenamiento TD3 base por seeds y diagnostico del motor 2.
- `run_motor2_simulation_sanity_check.m`: prueba controlada del simulador
  con acciones fijas, sin aprendizaje y sin hardware.
- `run_motor2_simulation_sanity_check_extended.m`: matriz extendida de
  respuesta, ganancia y signo por motor/nivel de accion.
- `run_motor2_targeted_diagnostic_ablation.m`: orquestador corto para
  sanity, auditoria de mapeo, Agent7250, checkpoints recientes y ablation.
- `run_motor2_reward_ablation.m`: ablations cortas de reward/accion con
  seleccion experimental `motor2_aware`.
- `run_repo_smoke_validation.m`: validacion automatizada corta del repo.

## Experimentos pausados

Los flujos Residual Lift y residual stop-band se movieron a
`../future_experiments/`. Siguen disponibles con `addpath(genpath(pwd))`,
pero no son la linea principal actual.

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy o pausados
