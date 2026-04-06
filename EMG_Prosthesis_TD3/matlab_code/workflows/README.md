# Workflows Target

Carpeta de launchers y campanas fuera del core MATLAB.

## Estado actual

Esta carpeta concentra ahora:

- `legacy/`: estudios y barridos historicos
- `published/`: launchers vigentes y helpers de campana activos

## Contenido esperado

- `legacy/`: estudios y barridos historicos ya apartados del core
- `published/`: flujos vigentes ya separados del core reutilizable

## Regla

- los launchers historicos deben entrar aqui, no volver a `src/`
- los launchers vigentes deben vivir en `published/`
- `src/` debe quedar reservado para runtime, evaluacion, checkpoints y utilidades del entorno
