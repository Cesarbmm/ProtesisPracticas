# Future Experiments

Esta carpeta conserva flujos funcionales que ya no son la linea principal
inmediata. No se borraron para preservar reproducibilidad y contexto
historico.

La fase activa del proyecto queda en `../published/` y se centra en:

```matlab
run_benchmark_td3_seeded_retrain_motor2_diagnostic()
```

## Contenido

- `residual_lift/`: reentrenamientos Residual Lift sobre `Agent7250`
  congelado.
- `residual_stopband/`: discovery y confirmation de stop-band residual.

## Como retomarlo

Desde `matlab_code/`:

```matlab
addpath(genpath(pwd))
```

Los launchers siguen estando en el path por nombre de funcion. Antes de
promoverlos otra vez, comparar contra el benchmark base y revisar el
diagnostico visual del motor 2.
