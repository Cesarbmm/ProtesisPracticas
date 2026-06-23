# Future Experiments

Esta carpeta conserva flujos funcionales que ya no son la linea principal
inmediata. No se borraron para preservar reproducibilidad y contexto
historico.

La fase activa del proyecto queda en `../published/` y se centra en
evaluacion congelada de `Agent7250` con diagnostico all-motor:

```matlab
run_agent7250_frozen_conversion_evaluation()
run_motor2_only_correction_evaluation()
run_all_motor_actuation_sanity_check_extended()
run_compare_against_canonical_benchmark_all_motor()
```

## Contenido

- `residual_lift/`: reentrenamientos Residual Lift sobre `Agent7250`
  congelado.
- `residual_stopband/`: discovery y confirmation de stop-band residual.
- `paused_motor2_training/`: reentrenamientos TD3 desde cero, ablations de
  reward/accion/conversion, visual reviews y diagnostics de fases previas.
  Se pausaron porque mejoraban parcialmente M2, pero podian degradar M1/M4
  o dejar flags all-motor. Siguen disponibles para reproducibilidad.

## Como retomarlo

Desde `matlab_code/`:

```matlab
addpath(genpath(pwd))
```

Los launchers siguen estando en el path por nombre de funcion. Antes de
promoverlos otra vez, comparar contra el benchmark base y revisar el
diagnostico visual del motor 2.
