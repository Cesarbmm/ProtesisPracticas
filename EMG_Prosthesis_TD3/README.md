# EMG_Prosthesis_TD3

Proyecto MATLAB para entrenar y evaluar agentes TD3 en el control de una protesis mioelectrica usando senales EMG.

## Estado publicado

La linea final publicada del proyecto es:

- benchmark canonico: `Agent7250`
- candidato final canonico: `Agent1850`
- workflow oficial: entrenamiento residual sobre `Agent7250`
- nombre generico de la ruta residual: `Residual Lift`

El entrenamiento TD3 base se conserva como referencia historica, pero ya no es el entrypoint principal del repositorio.

## Requisitos

- MATLAB
- Reinforcement Learning Toolbox
- Deep Learning Toolbox
- Signal Processing Toolbox
- dataset en `matlab_code/data/datasets/Denis Dataset/`

## Estructura relevante

- `matlab_code/config/`: configuracion global.
- `matlab_code/src/`: entorno, reward, auditoria y launchers.
- `matlab_code/agents/`: definicion de agentes, incluida la rama residual.
- `matlab_code/checkpoints/canonical/`: benchmark y residual final publicados.
- `docs/td3_training_report/`: documentacion final curada.

## Flujo recomendado

Trabaja desde:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
clearConfigurablesOverride()
```

### Entrenamiento residual publicado

```matlab
results = run_agent7250_residual_policy_pilot();
```

Interpretacion:

- la rama residual arranca en cero;
- la politica base congelada es `Agent7250`;
- esta es la forma correcta de "entrenar desde cero" en la linea residual.

### Entrenamiento residual generico sobre cualquier base

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

Interpretacion:

- la rama residual sigue arrancando en cero;
- la politica base congelada ahora puede ser cualquier checkpoint TD3 compatible;
- el benchmark oficial del proyecto sigue siendo `Agent7250`, pero ya no estas nominalmente atado a el para generar una nueva rama residual.

### Rehacer la linea completa desde cero

```matlab
trainInterface('td3','','')
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

Para una prueba corta, usa la guia paso a paso ya preparada en:

- `matlab_code/README.md`

Esa guia incluye:

- una base TD3 corta;
- auditoria corta para escoger checkpoint;
- una residual corta sobre esa base;
- y un test rapido final.

### Test del residual final canonico

```matlab
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

### Test del benchmark canonico

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

### Auditoria explicita de una corrida

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

### Entrenamiento base de referencia

```matlab
trainInterface('td3','','')
```

## Parametros locales a revisar

En `matlab_code/config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.comUNO`
- `params.comGlove`
- `params.trainingMaxEpisodes`
- `params.trainingSaveAgentEvery`
- `params.trainingPlots`

Los puertos `COM` solo importan para hardware. El flujo publicado es simulacion.

## Documentacion adicional

- `matlab_code/README.md`: guia operativa del codigo.
- `docs/td3_training_report/README.md`: reportes, presentacion y referencias canonicas.
