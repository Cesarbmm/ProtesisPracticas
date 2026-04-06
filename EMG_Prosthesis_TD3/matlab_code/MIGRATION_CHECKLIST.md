# Migration Checklist

Checklist operativo para dejar `matlab_code/` listo en otro ordenador.

## 1. MATLAB y toolboxes

- confirmar que MATLAB abre sin error de licencia
- confirmar `R2023b` o version compatible
- confirmar estas toolboxes:
  - `MATLAB`
  - `Reinforcement Learning Toolbox`
  - `Deep Learning Toolbox`
  - `Signal Processing Toolbox`

Comando sugerido:

```matlab
ver
```

## 2. Repo y dataset

- clonar el repo completo
- entrar a `EMG_Prosthesis_TD3/matlab_code`
- confirmar que existe `data/datasets/Denis Dataset/`
- confirmar que existen los checkpoints en `checkpoints/canonical/`

## 3. Bootstrap minimo

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
configurables();
getAgent7250CheckpointPath();
getResidualFinalCheckpointPath();
```

Si esto falla, clasificar el problema en una de estas clases:

- licencia o arranque de MATLAB
- toolbox faltante
- path del repo
- dataset ausente
- checkpoint ausente
- incompatibilidad de codigo legacy con la version de MATLAB

## 4. Smoke tests oficiales

Smoke benchmark:

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 2, false);
```

Smoke residual reducido:

```matlab
run_residual_lift_stopband_confirmation(struct( ...
    'stopBandEpisode', 2000, ...
    'stopBandWindow', [1750 2250], ...
    'seeds', 66, ...
    'trainingEpisodes', 200, ...
    'trainingSaveEvery', 100, ...
    'episodeSaveFreq', 100, ...
    'auditFastSimulations', 2, ...
    'auditFullSimulations', 2, ...
    'auditTopK', 1, ...
    'comparisonSimulations', 2, ...
    'generateReport', false, ...
    'compileReport', false));
```

Alternativa automatizada:

```matlab
run_repo_smoke_validation();
```

## 5. Criterio de listo para entrenar

Se considera que la migracion quedo operativa si:

- MATLAB abre con licencia valida
- `ver` muestra las toolboxes requeridas
- `configurables()` corre sin error
- `getAgent7250CheckpointPath()` resuelve una ruta existente
- `runCheckpointTest(..., 2, false)` completa
- el smoke reducido de stop-band escribe resultados en `Agentes/`

## 6. Alcance de esta migracion

Esta checklist deja listo el flujo de simulacion.

No cubre:

- conexion de hardware real
- verificacion de `COM3` o `COM4`
- pruebas con guante o protesis fisica

Eso debe revisarse despues y por separado.
