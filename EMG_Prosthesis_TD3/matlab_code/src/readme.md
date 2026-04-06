Main MATLAB runtime code and active workflows.

## Estado actual

Esta carpeta contiene ahora:

- `runtime/`: bootstrap, configuracion aplicada, dataset y utilidades de ejecucion
- `evaluation/`: test, auditoria, resumenes y diagnosticos
- `checkpoints/`: resolucion y descubrimiento de checkpoints
- `@.../`, `preprocess/`, `plotting/`: clases y utilidades base del entorno
- `reward_functions/`: carpeta estable de rewards sin espacios

## Regla operativa

Por ahora:

- no borrar archivos historicos
- no volver a meter launchers legacy aqui
- dejar aqui solo core reusable y helpers operativos

## Camino oficial vigente

Los puntos de entrada mas importantes siguen siendo:

- `runtime/trainInterface.m`
- `evaluation/runCheckpointTest.m`
- `evaluation/runCheckpointAudit.m`
- `../workflows/published/run_residual_lift_pilot.m`
- `../workflows/published/run_residual_lift_stopband_discovery.m`
- `../workflows/published/run_residual_lift_stopband_confirmation.m`
- `../workflows/published/run_repo_smoke_validation.m`

## Objetivo de la siguiente limpieza

La reorganizacion objetivo restante es:

- mantener aqui solo core reusable y helpers operativos
- mantener los launchers vigentes en `../workflows/published/`
- mantener fuera de aqui los viewers legacy y utilidades no portables
- mantener `reward_functions/` como nombre definitivo para evitar fragilidad en paths
