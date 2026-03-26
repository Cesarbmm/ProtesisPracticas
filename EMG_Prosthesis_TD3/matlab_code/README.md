# MATLAB Code Guide

Guia operativa del codigo MATLAB de `EMG_Prosthesis_TD3`.

## Flujo publicado

El flujo principal ya no es entrenar `td3` plano desde cero. El flujo publicado y recomendado es:

1. usar el benchmark canonico `Agent7250`,
2. entrenar una nueva corrida residual con rama residual inicializada en cero,
3. comparar contra `Agent7250` y contra el residual final canonico `Agent1850`.

Ademas, el codigo ya soporta una variante generica de esa misma idea con nombre operativo `Residual Lift`, para usar cualquier checkpoint TD3 compatible como base congelada.

## Antes de ejecutar

Trabaja desde esta carpeta:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
```

Limpia la configuracion persistente antes de cada corrida:

```matlab
clearConfigurablesOverride()
```

## Entrenamiento residual recomendado

```matlab
results = run_agent7250_residual_policy_pilot();
```

Eso hace lo siguiente:

- carga el benchmark canonico `Agent7250`;
- congela la politica base;
- inicializa la rama residual en cero;
- entrena una nueva correccion residual por estado.

## Rehacer toda la linea desde cero

Si quieres repetir la estrategia completa sobre una base nueva tuya, el orden recomendado ahora es:

1. entrenar un TD3 base nuevo,
2. auditar esa corrida y elegir un checkpoint,
3. abrir una nueva rama `Residual Lift` sobre ese checkpoint.

### Paso 1: entrenar una base nueva

```matlab
trainInterface('td3','','')
```

### Paso 2: auditar la corrida y elegir checkpoint

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

### Paso 3: abrir una residual nueva sobre esa base

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

## Entrenamiento residual generico sobre una base nueva

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

Eso hace lo siguiente:

- usa el checkpoint indicado como politica base congelada;
- deja la rama residual en cero al inicio;
- entrena una nueva correccion residual sobre esa base;
- mantiene la misma observacion, reward y entorno del flujo residual publicado.

## Test del residual final canonico

```matlab
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

## Test del benchmark canonico

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

## Auditoria de checkpoints

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

El ranking prioriza:

1. menor `trackingMseMean`
2. menor `saturationFractionMean`
3. menor `deltaActionL2Mean`
4. menor `actionL2Mean`

## Entrenamiento base de referencia

Usa esto solo como referencia historica o para abrir nuevas lineas fuera del workflow residual:

```matlab
trainInterface('td3','','')
```

## Parametros locales a cambiar

En `config/configurables.m`:

- `params.dataset_folder`
- `params.agents_directory`
- `params.comUNO`
- `params.comGlove`

Notas:

- `dataset_folder` debe apuntar a la carpeta local del dataset.
- `agents_directory` define donde se guardan corridas locales.
- `agentFile` no hace falta si usas los helpers canonicos.
- `comUNO` y `comGlove` solo importan en hardware.

## Checkpoints canonicos publicados

- benchmark: `checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat`
- residual final: `checkpoints/canonical/Agent1850_residual_alpha020/Agent1850_residual_alpha020.mat`

Usa siempre:

- `getAgent7250CheckpointPath()`
- `getResidualFinalCheckpointPath()`

en vez de hardcodear rutas locales.

Si vas a abrir una nueva linea residual sobre un agente tuyo, entonces si debes pasar explicitamente `baseCheckpointPath` al launcher `run_residual_lift_pilot(...)`.
