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
addpath(genpath(pwd))
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

## Reproducibilidad multi-seed del residual final

Para una corrida reviewer-facing del residual con seeds fijas:

```matlab
results = run_residual_lift_multiseed();
```

Defaults publicados:

- seeds = `[11 22 33 44 55]`
- base congelada = `Agent7250`
- `alpha_res = 0.20`
- `trainingEpisodes = 2000`
- auditoria de cola `k = 50`, `n = 12`
- test final de `50` simulaciones por seed

Para un smoke test corto del launcher multi-seed:

```matlab
results = run_residual_lift_multiseed(struct( ...
    'trainingEpisodes', 5, ...
    'trainingSaveEvery', 1, ...
    'trainingPlots', "none", ...
    'auditFastSimulations', 1, ...
    'auditFullSimulations', 1, ...
    'auditTopK', 1, ...
    'visualTestSimulations', 1));
```

## Corrida larga de evaluacion en otro ordenador

Para una maquina distinta, el repo ya queda casi portable por defecto:

- `dataset_folder` es relativo al repo;
- `agents_directory` guarda resultados en `../../Agentes`;
- solo cambian `comUNO` y `comGlove` si hubiese hardware.

Launcher recomendado para una corrida larga de evaluacion:

```matlab
results = run_residual_lift_longrun();
```

Defaults de ese launcher:

- base congelada = `Agent7250`
- `alpha_res = 0.20`
- `trainingEpisodes = 50000`
- `trainingSaveEvery = 500`
- `episodeSaveFreq = 500`
- `trainingPlots = "none"`
- `alwaysRunVisualTest = true`

Si quieres una corrida larga con seed fija:

```matlab
results = run_residual_lift_longrun(struct( ...
    'randomSeed', 22));
```

Si quieres usar otra base TD3 tuya:

```matlab
results = run_residual_lift_longrun(struct( ...
    'baseCheckpointPath', "C:/ruta/a/tu/AgentXXXX.mat", ...
    'baseLabel', "MiBaseTD3"));
```

### Sobre la idea de `1,000,000` episodios

No se recomienda arrancar con `1e6` episodios en una sola corrida.

Motivos practicos:

- las corridas previas de este proyecto no mostraron una mejora monotona al seguir entrenando sin control;
- el costo temporal y de almacenamiento crece mucho, aunque espacies checkpoints y episodios guardados;
- una corrida tan larga puede derivar y terminar peor que un checkpoint intermedio bueno.

Recomendacion operativa:

1. correr primero `50000` episodios;
2. auditar el mejor checkpoint;
3. solo si la tendencia es buena, subir a `100000` o continuar por bloques.

Si luego quieres continuar un residual ya entrenado por otro bloque, usa el
checkpoint residual guardado y reanuda entrenamiento asi:

```matlab
clearConfigurablesOverride()
setConfigurablesOverride(struct( ...
    'run_training', true, ...
    'newTraining', false, ...
    'agent_id', "td3_residual_lift", ...
    'agentFile', "C:/ruta/a/tu/ResidualCheckpoint.mat", ...
    'trainingMaxEpisodes', 50000, ...
    'trainingSaveAgentEvery', 500, ...
    'trainingPlots', "none", ...
    'flagSaveTraining', true, ...
    'episode_save_freq', 500));
trainInterface('td3_residual_lift','','')
clearConfigurablesOverride()
```

Si igual quieres lanzar una prueba extrema, hazlo explicito y con guardado espaciado:

```matlab
results = run_residual_lift_longrun(struct( ...
    'trainingEpisodes', 1e6, ...
    'trainingSaveEvery', 5000, ...
    'episodeSaveFreq', 5000, ...
    'randomSeed', 22));
```

Eso se puede ejecutar, pero queda como experimento exploratorio de alto costo, no como configuracion recomendada.

## Corrida larga base antes del residual

Si quieres separar "mejoro porque el residual ayuda" de "mejoro porque seguimos entrenando mas tiempo una base fuerte", el flujo nuevo recomendado es:

1. continuar `Agent7250` como TD3 plano en una corrida larga exploratoria;
2. auditar toda la trayectoria;
3. solo si el mejor checkpoint final supera a `Agent7250`, usarlo como nueva base de trabajo para abrir una residual nueva.

### Paso 1: corrida larga base sobre `Agent7250`

```matlab
results = run_agent7250_longrun();
```

Defaults:

- base = `Agent7250`
- `trainingEpisodes = 50000`
- `trainingSaveEvery = 500`
- `episodeSaveFreq = 500`
- `trainingPlots = "none"`

### Smoke test corto del long run base

```matlab
results = run_agent7250_longrun(struct( ...
    'trainingEpisodes', 5, ...
    'trainingSaveEvery', 1, ...
    'episodeSaveFreq', 1, ...
    'trainingPlots', "none"));
```

### Paso 2: auditar la corrida larga base

Usa la carpeta del experimento que produjo `run_agent7250_longrun()`. Luego:

```matlab
audit = run_longrun_td3_audit(struct( ...
    'experimentDir', string(results.trainingRunDir)));
```

Ese flujo:

- analiza la curva de entrenamiento;
- audita todos los checkpoints;
- retestea el top 1 con `50` simulaciones;
- compara contra `Agent7250`, `Agent1850` y `seed 22`;
- genera un reporte standalone en `docs/td3_training_report/`.

### Smoke test corto de la auditoria base

```matlab
audit = run_longrun_td3_audit(struct( ...
    'experimentDir', string(results.trainingRunDir), ...
    'auditFastSimulations', 1, ...
    'auditFullSimulations', 1, ...
    'auditTopK', 1, ...
    'comparisonSimulations', 1, ...
    'comparisonPlotEpisodes', false, ...
    'generateReport', false));
```

### Paso 3: abrir residual solo si la base larga se promueve

Por defecto, la auditoria base no abre una residual nueva automaticamente. Si el mejor checkpoint largo base pasa `ConditionA` o `ConditionB`, puedes relanzar la auditoria con el puente residual:

```matlab
audit = run_longrun_td3_audit(struct( ...
    'experimentDir', string(results.trainingRunDir), ...
    'launchResidualIfPromoted', true));
```

Eso hace dos cosas adicionales:

- promueve el mejor checkpoint largo como nueva base de trabajo;
- abre una residual nueva sobre esa base y la compara contra:
  - la base promovida,
  - `Agent7250`,
  - `Agent1850`,
  - `seed 22`.

## Rehacer toda la linea desde cero

Si quieres repetir la estrategia completa sobre una base nueva tuya, el orden recomendado ahora es:

1. entrenar un TD3 base nuevo,
2. auditar esa corrida y elegir un checkpoint,
3. abrir una nueva rama `Residual Lift` sobre ese checkpoint.

No hace falta editar `config/configurables.m` para esta prueba corta. El repo ya queda por defecto en modo "base nueva desde cero":

- `params.run_training = true`
- `params.newTraining = true`

Solo usa `setConfigurablesOverride(...)` para acortar episodios y no ensuciar la configuracion fija.

### Prueba corta end-to-end

Bloque sugerido para copiar y pegar en MATLAB:

```matlab
cd('C:/Users/pc/Desktop/PROTESIS_PRACTICAS/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))
clearConfigurablesOverride()

% 1) Base TD3 nueva y corta
setConfigurablesOverride(struct( ...
    'run_training', true, ...
    'newTraining', true, ...
    'trainingMaxEpisodes', 30, ...
    'trainingSaveAgentEvery', 10, ...
    'trainingPlots', "none"));
trainInterface('td3','','')
clearConfigurablesOverride()

% 2) Encontrar la corrida base mas reciente
root = fullfile('..','..','Agentes','trainedAgentsProtesisTest','td3','_');
runs = dir(root);
runs = runs([runs.isdir]);
runs = runs(~ismember({runs.name},{'.','..'}));
[~,idx] = max([runs.datenum]);
latestRun = fullfile(runs(idx).folder, runs(idx).name)

% 3) Auditar y escoger un checkpoint base
audit = runCheckpointAudit(2, 2, 1, struct( ...
    'experimentDir', latestRun, ...
    'samplingPolicy', struct('mode','tail_every_k_last_n','k',10,'n',3)));
baseCheckpoint = string(audit.phaseBTable.checkpointPath(1))

% 4) Abrir una residual nueva sobre ese checkpoint
residualResults = run_residual_lift_pilot(struct( ...
    'baseCheckpointPath', baseCheckpoint, ...
    'trainingEpisodes', 30, ...
    'trainingSaveEvery', 10, ...
    'trainingPlots', "none", ...
    'auditFastSimulations', 2, ...
    'auditFullSimulations', 2, ...
    'auditTopK', 1, ...
    'visualTestSimulations', 2));

% 5) Test rapido del mejor residual
bestResidualCheckpoint = string(residualResults.consolidatedTable.bestCheckpointPath(1));
runCheckpointTest(bestResidualCheckpoint, 2, false);
```

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
- en este repo publicado, `dataset_folder` y `agents_directory` ya vienen en forma portable para otro ordenador.

## Checkpoints canonicos publicados

- benchmark: `checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat`
- residual final: `checkpoints/canonical/Agent1850_residual_alpha020/Agent1850_residual_alpha020.mat`

Usa siempre:

- `getAgent7250CheckpointPath()`
- `getResidualFinalCheckpointPath()`

en vez de hardcodear rutas locales.

Si vas a abrir una nueva linea residual sobre un agente tuyo, entonces si debes pasar explicitamente `baseCheckpointPath` al launcher `run_residual_lift_pilot(...)`.

## Si quieres tocar `configurables.m` manualmente

No es necesario para la prueba corta, pero estos son los cambios manuales correctos:

### Base nueva desde cero

```matlab
params.run_training = true;
params.newTraining = true;
```

### Continuar un TD3 viejo

```matlab
params.newTraining = false;
params.agent_id = "td3";
params.agentFile = "C:/ruta/a/AgentXXXX.mat";
```

### Continuar un residual viejo

```matlab
params.newTraining = false;
params.agent_id = "td3_residual_lift";
params.agentFile = "C:/ruta/a/ResidualAgentXXXX.mat";
```

### Residual nueva sobre otra base

No se recomienda cambiar `params.td3Residual.baseCheckpointPath` a mano cada vez. Es mejor usar:

```matlab
run_residual_lift_pilot(struct('baseCheckpointPath',"C:/ruta/a/AgentXXXX.mat"))
```
