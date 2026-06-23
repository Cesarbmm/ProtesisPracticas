# Published Workflows

Launchers activos y estables que no forman parte del core reusable de
`src/`.

## Contenido activo

- `run_benchmark_td3_seeded_retrain_motor2_diagnostic.m`: fase actual,
  reentrenamiento TD3 base por seeds y diagnostico del motor 2.
- `run_motor2_simulation_sanity_check.m`: prueba controlada del simulador
  con acciones fijas, sin aprendizaje y sin hardware.
- `run_motor2_simulation_sanity_check_extended.m`: matriz extendida de
  respuesta, ganancia y signo por motor/nivel de accion, con posiciones
  iniciales `home`, `mid` y `closed`.
- `run_motor_response_conversion_diagnostic.m`: separa respuesta del
  simulador, `encoder2Flex` y normalizacion `flexJoined_scale`.
- `run_motor2_targeted_diagnostic_ablation.m`: orquestador corto para
  sanity, auditoria de mapeo, Agent7250, checkpoints recientes y ablation.
- `run_motor2_reward_ablation.m`: ablations cortas de reward/accion con
  seleccion experimental `motor2_aware`.
- `run_motor2_calibrated_action_ablation.m`: compara `baselineQuantized`,
  accion continua y `motorCalibratedQuantized` antes de tocar reward.
- `run_motor2_conversion_fix_diagnostic.m`: compara `encoder2Flex`
  baseline contra la variante experimental `motor2Calibrated`, sin
  entrenamiento y con regression check de todos los motores.
- `run_motor2_encoder2flex_limit_sweep_diagnostic.m`: barre offsets
  experimentales de `gap.idx`/`breakLimit.idx` para motor 2 y selecciona el
  candidato mas conservador sin entrenamiento.
- `run_motor2_conversion_fix_ablation.m`: ablation corta que combina
  conversion baseline/calibrada con accion baseline/calibrada, sin promover
  defaults.
  Usa por defecto `selectionMode="motor2_final_gate"` para confirmar varios
  checkpoints finales y guardar `motor2_final_gate_attempts.csv`.
- `run_all_motor_regression_validation_from_run.m`: revisa una corrida ya
  terminada, recalcula diagnosticos por M1-M4 y compara baseline contra
  `motor2Calibrated` sin volver a entrenar.
- `run_all_motor_visual_comparison_from_run.m`: regenera figuras visuales
  comparables por seed/configuracion desde `episode*.mat`, con metadata de
  seed, episodio, variante de accion, variante `encoder2Flex`, selector y
  checkpoint.
- `run_all_motor_actuation_sanity_check_extended.m`: sanity all-motor sin
  entrenamiento para M1-M4, posiciones `home/mid/closed` y variantes
  `encoder2Flex` baseline/calibrada.
- `run_compare_against_canonical_benchmark_all_motor.m`: compara Agent7250
  contra checkpoints actuales con diagnostico y figuras M1-M4.
- `run_agent7250_frozen_conversion_evaluation.m`: evalua Agent7250
  congelado con conversion baseline y `motor2Calibrated`, sin entrenamiento.
- `run_motor2_only_correction_evaluation.m`: evalua una correccion
  heuristica aislada de motor 2 sobre Agent7250 congelado. M1/M3/M4 deben
  quedar con `maxNonMotor2ActionDelta=0`.
- `run_motor_reference_permutation_batch.m`: agrega permutation checks de
  varios test runs sin cambiar columnas ni mapeos.
- `run_repo_smoke_validation.m`: validacion automatizada corta del repo.

## Experimentos pausados

Los flujos Residual Lift y residual stop-band se movieron a
`../future_experiments/`. Siguen disponibles con `addpath(genpath(pwd))`,
pero no son la linea principal actual.

## Regla

- mantener aqui los puntos de entrada activos del proyecto
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`
- no mezclar aqui launchers legacy o pausados
