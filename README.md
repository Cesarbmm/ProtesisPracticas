# ProtesisPracticas

Repositorio principal del proyecto de control de una protesis mioelectrica con aprendizaje por refuerzo.

El contenido activo de esta publicacion esta centrado en:

- entrenamiento y evaluacion en simulacion;
- codigo MATLAB del proyecto `EMG_Prosthesis_TD3`;
- documentacion tecnica y guia didactica del baseline actual.

## Estructura

- `EMG_Prosthesis_TD3/`: proyecto principal de MATLAB.
- `EMG_Prosthesis_TD3/matlab_code/`: codigo operativo para train, test y auditoria.
- `EMG_Prosthesis_TD3/docs/td3_training_report/`: reportes tecnicos y guia didactica.

Las salidas locales de entrenamiento y test no se versionan:

- `Agentes/`
- `Imagenes/`

## Quick Start

1. Abre MATLAB.
2. Entra a `EMG_Prosthesis_TD3/matlab_code`.
3. Revisa los paths configurables en `config/configurables.m`.
4. Ejecuta uno de estos flujos:

### Entrenamiento en simulacion

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
trainInterface('td3','','')
```

### Test o evaluacion en simulacion

Antes de ejecutar:

- pon `params.run_training = false`;
- define `params.agentFile` con el checkpoint que quieres evaluar.

Luego ejecuta:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
trainInterface('td3','','')
```

### Auditoria de checkpoints

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
if isappdata(0,'configurables_override'), rmappdata(0,'configurables_override'); end
clear configurables
results = runCheckpointAudit(50, 200, 3);
```

## Paths que debes revisar

En `EMG_Prosthesis_TD3/matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.agentFile`
- `params.comUNO`
- `params.comGlove`

`comUNO` y `comGlove` solo importan si vas a usar hardware. El flujo principal publicado en este repo es simulacion.

## Documentacion

Consulta:

- `EMG_Prosthesis_TD3/README.md` para la guia del proyecto.
- `EMG_Prosthesis_TD3/matlab_code/README.md` para la guia operativa.
- `EMG_Prosthesis_TD3/docs/td3_training_report/README.md` para los documentos tecnicos canónicos.
