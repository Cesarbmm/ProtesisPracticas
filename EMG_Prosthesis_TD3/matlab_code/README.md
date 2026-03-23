# MATLAB Code Guide

Guia operativa del proyecto `EMG_Prosthesis_TD3`.

## Flujo soportado en esta publicacion

El flujo principal soportado y documentado es:

- entrenamiento en simulacion;
- test en simulacion;
- auditoria de checkpoints.

Los scripts orientados a hardware en tiempo real se consideran secundarios y requieren configuracion manual adicional.

## Antes de ejecutar

Trabaja desde esta carpeta:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
```

Y resetea la configuracion persistente antes de cada corrida:

```matlab
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
```

## Entrenamiento en simulacion

Revisa en `config/configurables.m`:

- `params.run_training = true`
- `params.newTraining = true`
- `params.usePrerecorded = true`
- `params.simMotors = true`
- `params.connect_glove = false`

Luego ejecuta:

```matlab
trainInterface('td3','','')
```

## Test o evaluacion en simulacion

Revisa en `config/configurables.m`:

- `params.run_training = false`
- `params.newTraining = false`
- `params.agentFile = "ruta/al/checkpoint.mat"`

Luego ejecuta:

```matlab
trainInterface('td3','','')
```

Si quieres guardar plots por episodio durante el test:

- activa `params.plotEpisodeOnTest = true`

## Auditoria de checkpoints

Para comparar checkpoints bajo el mismo protocolo:

```matlab
results = runCheckpointAudit(50, 200, 3);
```

El ranking prioriza:

1. menor `trackingMseMean`
2. menor `saturationFractionMean`
3. menor `deltaActionL2Mean`
4. menor `actionL2Mean`

## Parametros locales que debes cambiar

En `config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.agentFile`
- `params.comUNO`
- `params.comGlove`

Notas:

- `dataset_folder` debe apuntar a la carpeta local del dataset.
- `agents_directory` define donde se guardan corridas de entrenamiento y test.
- `agentFile` solo se usa para test o para reanudar una corrida.
- `comUNO` y `comGlove` solo importan en hardware.

## Scripts legacy

Estos scripts se conservan por referencia historica y pueden requerir revision manual antes de usarse:

- `runProsthesis.m`
- `src/evalTrainedAgent.m`
- `src/fineTuning.m`

El flujo recomendado hoy es `trainInterface('td3','','')`.
