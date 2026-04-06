# MATLAB Code Guide

Guia operativa del codigo MATLAB de `EMG_Prosthesis_TD3`.

## Punto actual

El flujo activo del proyecto ya no es una corrida residual larga ni una corrida base larga. El flujo activo es:

1. usar `Agent7250` como benchmark oficial y base congelada;
2. entrenar residual con checkpoints densos;
3. auditar toda la trayectoria;
4. seleccionar temprano dentro de la `stop-band` confirmada.

Referencias activas:

- benchmark oficial: `Agent7250`
- linea residual activa: `stop-band` confirmada alrededor de `2000` episodios
- mejor residual historico single-run: `Agent1850`

## Antes de ejecutar

Trabaja desde esta carpeta:

```matlab
cd('C:/ruta/al/repo/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
```

Limpia la configuracion persistente antes de cada corrida:

```matlab
clearConfigurablesOverride()
```

## Tests canonicamente publicados

Benchmark oficial:

```matlab
runCheckpointTest(getAgent7250CheckpointPath(), 50, true);
```

Residual canonico historico:

```matlab
runCheckpointTest(getResidualFinalCheckpointPath(), 50, true);
```

## Flujo residual activo: stop-band confirmada

La linea recomendada ahora es confirmation sobre la banda ya validada.

```matlab
results = run_residual_lift_stopband_confirmation();
```

Defaults relevantes:

- seeds = `[66 77 88 99 111]`
- `trainingEpisodes = stopBandEpisode + 500`
- guardado cada `100` episodios
- auditoria completa `mode = "all"`
- retest final por seed

Interpretacion:

- `Agent7250` sigue como benchmark oficial;
- la fase confirmada pasa a ser la referencia residual operativa;
- la banda util queda alrededor de `2000` episodios.

## Discovery de una nueva stop-band

Si quieres volver a descubrir una banda desde cero:

```matlab
results = run_residual_lift_stopband_discovery();
```

Defaults relevantes:

- seeds = `[11 22 33 44 55]`
- `trainingEpisodes = 10000`
- `trainingSaveEvery = 250`
- `episodeSaveFreq = 250`
- auditoria completa `mode = "all"`

### Smoke test validado de discovery

```matlab
results = run_residual_lift_stopband_discovery(struct( ...
    'seeds', [11 22], ...
    'trainingEpisodes', 100, ...
    'trainingSaveEvery', 50, ...
    'episodeSaveFreq', 50, ...
    'auditFastSimulations', 2, ...
    'auditFullSimulations', 2, ...
    'auditTopK', 1, ...
    'comparisonSimulations', 2, ...
    'generateReport', false, ...
    'compileReport', false));
```

### Smoke test validado de confirmation

```matlab
results = run_residual_lift_stopband_confirmation(struct( ...
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

## Residual generico sobre cualquier base

Si quieres abrir una residual sobre otro checkpoint TD3:

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

## Rehacer toda la linea desde cero

Entrenamiento base de referencia:

```matlab
trainInterface('td3','','')
```

Auditoria de esa corrida:

```matlab
results = runCheckpointAudit(20, 50, 2, struct( ...
    'experimentDir', 'C:/ruta/a/una/corrida', ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',50,'n',12)));
```

Residual generica sobre el checkpoint escogido:

```matlab
results = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat"));
```

## Portabilidad a otra PC

El repo queda pensado para simulacion primero. En otra PC suele bastar con revisar:

- `dataset_folder`
- `agents_directory`

Y solo si hay hardware:

- `comUNO`
- `comGlove`

Arranque minimo:

```matlab
cd('C:/ruta/al/clon/ProtesisPracticas/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()
```
