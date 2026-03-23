# EMG_Prosthesis_TD3

Proyecto MATLAB para entrenar y evaluar un agente TD3 que controle una protesis mioelectrica usando senales EMG.

## Estado actual

El flujo principal publicado en este repositorio es:

- entrenamiento en simulacion;
- test en simulacion con checkpoints guardados;
- auditoria de checkpoints;
- documentacion tecnica del baseline actual.

El soporte de hardware se conserva en el codigo, pero no es el flujo principal documentado para esta publicacion.

## Requisitos

- MATLAB con:
  - Reinforcement Learning Toolbox
  - Deep Learning Toolbox
  - Signal Processing Toolbox
- datasets en `matlab_code/data/datasets/Denis Dataset/`

## Estructura relevante

- `matlab_code/config/`: configuracion principal.
- `matlab_code/src/`: entorno, reward, helpers y scripts.
- `matlab_code/agents/`: definicion del agente TD3.
- `matlab_code/data/datasets/Denis Dataset/`: datasets usados en simulacion.
- `docs/td3_training_report/`: reportes tecnicos y guia didactica.

## Flujo recomendado

Trabaja siempre desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
```

### Entrenamiento

```matlab
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
trainInterface('td3','','')
```

### Test o evaluacion

Antes del comando:

- pon `params.run_training = false`;
- define `params.agentFile` con el checkpoint a evaluar.

Luego:

```matlab
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
trainInterface('td3','','')
```

### Auditoria de checkpoints

```matlab
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
results = runCheckpointAudit(50, 200, 3);
```

## Parametros que debes revisar

En `matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.agentFile`
- `params.comUNO`
- `params.comGlove`
- `params.trainingMaxEpisodes`
- `params.trainingSaveAgentEvery`
- `params.trainingPlots`
- `params.plotEpisodeOnTest`

Los puertos `COM` solo son necesarios si vas a usar hardware.

## Salidas locales no versionadas

Las salidas de entrenamiento y test se guardan localmente y no deben entrar a Git:

- `../Agentes/`
- `../Imagenes/`

## Documentacion adicional

- `matlab_code/README.md`: guia operativa detallada.
- `docs/td3_training_report/README.md`: reportes tecnicos canónicos.
