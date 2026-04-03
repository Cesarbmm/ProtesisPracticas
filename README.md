# ProtesisPracticas

Repositorio principal del proyecto de control de una protesis mioelectrica con aprendizaje por refuerzo.

La publicacion actual deja como resultado operativo final la linea residual sobre `Agent7250`:

- benchmark canonico: `Agent7250`
- candidato final canonico: `Agent1850`
- workflow recomendado: entrenar una rama residual desde cero sobre la politica base congelada
- nombre operativo nuevo para esa ruta: `Residual Lift`

## Contenido publicado

- `EMG_Prosthesis_TD3/`: proyecto principal de MATLAB.
- `EMG_Prosthesis_TD3/matlab_code/`: codigo operativo para entrenamiento, test y auditoria.
- `EMG_Prosthesis_TD3/matlab_code/checkpoints/canonical/`: checkpoints canonicamente publicados.
- `EMG_Prosthesis_TD3/docs/td3_training_report/`: documentacion final curada.

Las salidas locales no se versionan:

- `Agentes/`
- `Imagenes/`

## Quick Start

Abre MATLAB y trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
clearConfigurablesOverride()
```

### Workflow publicado recomendado

Entrenar una nueva corrida residual sobre el benchmark canonico:

```matlab
results = run_agent7250_residual_policy_pilot();
```

### Workflow generico recomendado para cualquier base nueva

Entrenar una nueva rama `Residual Lift` sobre cualquier checkpoint base:

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

### Workflow exploratorio nuevo: corrida larga base antes del residual

Si quieres probar primero si `Agent7250` mejora simplemente por seguir entrenando mas tiempo:

```matlab
results = run_agent7250_longrun();
audit = run_longrun_td3_audit(struct( ...
    'experimentDir', string(results.trainingRunDir)));
```

Si la corrida larga base se promueve como nueva base de trabajo y quieres abrir una residual nueva sobre ella:

```matlab
audit = run_longrun_td3_audit(struct( ...
    'experimentDir', string(results.trainingRunDir), ...
    'launchResidualIfPromoted', true));
```

### Rehacer toda la linea desde cero

```matlab
trainInterface('td3','','')
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

La version explicada paso a paso, incluida una prueba corta con pocas epocas y el path real del repo, quedo en:

- `EMG_Prosthesis_TD3/matlab_code/README.md`

### Test del candidato final canonico

```matlab
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

### Test del benchmark canonico

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

### Entrenamiento base de referencia

```matlab
trainInterface('td3','','')
```

### Auditoria de checkpoints

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

## Paths a revisar

En `EMG_Prosthesis_TD3/matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.comUNO`
- `params.comGlove`

`agentFile` ya no es necesario para el flujo publicado si usas los helpers canonicos.

## Documentacion

- `EMG_Prosthesis_TD3/README.md`: estado del proyecto y workflow final.
- `EMG_Prosthesis_TD3/matlab_code/README.md`: guia operativa exacta.
- `EMG_Prosthesis_TD3/docs/td3_training_report/README.md`: documentos y figuras canonicas.
