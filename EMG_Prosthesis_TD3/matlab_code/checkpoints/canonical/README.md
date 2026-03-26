# Canonical Checkpoints

Esta carpeta contiene los checkpoints pequenos que se publican junto al codigo para que el workflow residual sea reproducible desde un clon limpio.

## Checkpoints incluidos

- `Agent7250_valid_baseline/Agent7250_valid_baseline.mat`
- `Agent1850_residual_alpha020/Agent1850_residual_alpha020.mat`

Cada subcarpeta incluye tambien su `00_configs.mat` de origen para que `runCheckpointTest(...)` pueda recuperar la configuracion asociada al checkpoint.

## Proveniencia

### Agent7250

- experimento original: `Agentes/trainedAgentsProtesisTest/td3/_/26-03-22 10 5 40`
- rol en el proyecto: benchmark canonico valido

### Agent1850

- experimento original: `Agentes/agent7250_residual_policy_pilot/26-03-25 17 08 56/training_run/26-03-25 17 9 8`
- rol en el proyecto: candidato final residual con `alpha_res = 0.20`

## Uso recomendado

En MATLAB, usa siempre los helpers:

- `getAgent7250CheckpointPath()`
- `getResidualFinalCheckpointPath()`

en vez de escribir rutas locales manualmente.
