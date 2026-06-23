# Published Workflows

Launchers activos de la fase actual:

**Frozen Agent7250 + motor 2 isolated correction**

El alcance es solo software/simulacion. No se activa hardware, no se cambian
puertos COM y no se entrena TD3 desde cero como propuesta principal.

## Defaults oficiales

Estos defaults siguen siendo la linea base historica y no se promueven cambios
experimentales:

- `actionInterfaceVariant = "baselineQuantized"`
- `encoder2FlexVariant = "baseline"`
- `actionPostprocessVariant = "none"`
- `rewardType = "trackingMseActionRateReward"`
- `observationVariant = "markov52"`

## Contenido activo

- `run_agent7250_frozen_conversion_evaluation.m`: evalua `Agent7250`
  congelado con conversion baseline y variantes experimentales
  `motor2Calibrated`, sin entrenamiento.
- `run_motor2_only_correction_evaluation.m`: evalua una correccion
  heuristica aislada de motor 2 sobre `Agent7250` congelado. M1, M3 y M4
  deben quedar sin cambios de accion (`maxNonMotor2ActionDelta = 0`).
- `run_all_motor_actuation_sanity_check_extended.m`: sanity all-motor sin
  entrenamiento para M1-M4, posiciones `home/mid/closed` y variantes
  `encoder2Flex` baseline/calibrada.
- `run_compare_against_canonical_benchmark_all_motor.m`: compara `Agent7250`
  contra corridas actuales con diagnostico y figuras M1-M4.

## Experimentos pausados

Los launchers que reentrenaban TD3 desde cero, probaban
`motorCalibratedQuantized`, hacian ablations de reward/accion o revisiones
visuales de corridas anteriores estan en:

`../future_experiments/paused_motor2_training/`

Siguen disponibles con `addpath(genpath(pwd))`, pero no son la linea activa.

## Regla

- mantener aqui solo puntos de entrada activos;
- no promover `motorCalibratedQuantized` ni `motor2Calibrated` como default;
- no aceptar una mejora de M2 si M1, M3 o M4 retroceden;
- no mover runtime, evaluacion ni checkpoints reutilizables fuera de `src/`.
