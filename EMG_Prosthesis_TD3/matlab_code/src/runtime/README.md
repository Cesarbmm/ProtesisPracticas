# Runtime

Utilidades de ejecucion y bootstrap del flujo MATLAB.

## Contenido

- arranque de entrenamiento y simulacion
- carga de dataset
- overrides de configuracion
- helpers de runtime usados por launchers vigentes

## Archivos clave

- `trainInterface.m`
- `getDataset.m`
- `clearConfigurablesOverride.m`
- `setConfigurablesOverride.m`

## Regla

No colocar aqui logica de auditoria ni resolucion de checkpoints canonicos.
Eso vive en `../evaluation/` y `../checkpoints/`.
