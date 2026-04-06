# Legacy Workflows

Launchers historicos movidos fuera de `src/`.

## Contenido

- familia `run_agent7250_*`
- barridos `run_markov52_*`
- experimentos `run_priority_*`
- corridas largas y auditorias legacy

## Regla

Estos archivos siguen siendo ejecutables porque `addpath(genpath(matlab_code))` agrega esta carpeta.

No representan el camino oficial actual del proyecto.
El camino oficial sigue documentado en `../README.md`.

## Nota

No se han renombrado funciones ni cambiado firmas.
El movimiento es solo estructural para separar core vigente de historial experimental.
