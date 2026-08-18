# ETAPA 1 — Fuente de referencia desacoplada

Fecha de ejecución: 2026-08-18
Rama: `experiment/no-glove-intent-control`
SHA base de la línea: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`
Padre de esta etapa: `9a1d153f20af120d6d84b9068f25fb4fb19b4a72`

## 1. Resultado de la etapa

`PASS`.

Se añadió una fuente de referencia por instancia, seleccionable mediante
`setConfigurablesOverride`:

- `referenceSource="glove"`: ruta histórica y valor por defecto;
- `referenceSource="emgIntent"`: ruta pregrabada que no carga ni construye un
  guante y que termina el episodio únicamente por agotamiento de EMG.

No se implementó todavía un decodificador de intención. Para validar el
desacoplamiento sin anticipar la ETAPA 2, `emgIntent` mantiene como referencia la
posición normalizada de encoder medida en `reset` y fija
`intentVelocity=zeros(4,1)`.

## 2. Rama y revisiones

- Rama: `experiment/no-glove-intent-control`.
- Base `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Etapa 0: `9a1d153f20af120d6d84b9068f25fb4fb19b4a72`.
- El SHA del commit de ETAPA 1 debe resolverse con `git rev-parse HEAD` después
  de aplicar este commit; no se introduce una referencia circular en el propio
  documento.

## 3. Archivos

### Creados

- `matlab_code/src/reward_functions/normalizeRewardInfo.m`
- `matlab_code/src/reward_functions/normalizeRewardOutputs.m`
- `matlab_code/src/runtime/buildNoGloveStage1Override.m`
- `matlab_code/tests/no_glove/testReferenceSources.m`
- `matlab_code/workflows/published/run_no_glove_stage1_validation.m`
- `docs/no_glove_experiment/01_reference_source.md`

### Modificados

- `docs/no_glove_experiment/00_baseline_audit.md` (errata de `simOpts`)
- `matlab_code/config/configurables.m`
- `matlab_code/src/@Env/Env.m`
- `matlab_code/src/@Env/reset.m`
- `matlab_code/src/@Env/step.m`
- `matlab_code/src/@Env/checkEndEpisode.m`
- `matlab_code/src/@Env/saveEpisode.m`
- `matlab_code/src/@Env/plot_episode.m`
- `matlab_code/src/@Env/plot_episode2.m`
- `matlab_code/src/reward_functions/trackingMseActionRateReward.m`
- `matlab_code/src/runtime/getDataset.m`
- `matlab_code/src/runtime/trainInterface.m`
- `matlab_code/src/runtime/buildMarkov52BaselineOverride.m`
- `matlab_code/src/evaluation/runCheckpointTest.m`
- `matlab_code/src/evaluation/evaluateCheckpointSuite.m`
- `matlab_code/src/evaluation/summarizeEpisodeDirectory.m`
- `matlab_code/workflows/published/README.md`

## 4. Decisiones técnicas

1. `referenceSource` es `"glove"` por defecto y propiedad inmutable de cada
   instancia de `Env`, no `Constant`. Esto evita que un cambio de override quede
   oculto por la caché de clase de MATLAB.
2. Todos los configurables que antes eran propiedades `Constant` de `Env`
   pasaron a propiedades inmutables de instancia; solo `v=2.4` permanece
   constante. Así, la reward, el simulador, el periodo, los límites de buffers y
   los flags de guardado/plot no quedan enmascarados por la caché de clase.
3. Durante ETAPA 1, `emgIntent` exige `usePrerecorded=true`, `simMotors=true` y
   `trackingMseActionRateReward`. Los accesos a Myo real, controlador físico y
   rewards aún acopladas al guante se rechazan antes de construir dispositivos.
4. `getDataset(...,"emgIntent")` inspecciona y carga solo `emgs` y `metadata`;
   no carga ni valida la variable `gloves`.
5. En `reset`, `emgIntent` no indexa `gloveDatas`/`gloveSet`, no construye
   `RecordedGlove`, no resetea ni lee un guante y no espera `flexData`.
6. En `step`, `emgIntent` no lee `this.glove`, no usa `flexData`,
   `reduceFlexDimension`, `flexConverted`, `encoder2Flex` ni `adjustEnc`.
   La reward recibe un contexto neutro con target y predicción en las mismas
   coordenadas de encoder normalizado.
7. Los nombres legacy `flexConvertedLog` y `encoderAdjustedLog` se conservan sin
   cambio para el benchmark de guante. En EMG-only permanecen vacíos; los campos
   neutrales son `referenceHistory` y `trackingPredictionHistory`.
8. `referenceHistory` contiene una fila por acción realmente evaluada y
   `referenceHistoryCount` indica las filas válidas. También se guardan
   `intentTarget`, `intentVelocity`, `referenceSource` y `rewardInfoLog`.
9. `normalizeRewardInfo` es una función pura: no recibe `Env` y completa un
   contrato versionado sin posibilidad de leer guante o EMG. El esquema 1 tiene
   `trackingMse`, `trackingMae`, `actionL2`, `progressTerm`,
   `smoothnessPenalty`, `deltaActionL2`, `saturationFraction`,
   `saturationPenalty`, `referenceSource` y `schemaVersion`.
10. `normalizeRewardOutputs` rechaza rewards o vectores por motor no numéricos,
    complejos, no finitos o de dimensión incorrecta. El historial genérico solo
    avanza después de validar ambos outputs y `rewardInfo`.
11. `summarizeEpisodeDirectory` conserva `referenceSource` y rechaza directorios
    que mezclen episodios `glove` y `emgIntent`. El evaluador de aceptación de
    Agent7250 rechaza fuentes distintas de `glove`.
12. Los checkpoints históricos que no contienen `referenceSource` se interpretan
    explícitamente como `glove`. El perfil `markov52` histórico también lo fija.
13. `localFinalizeRuntimeSettings` respeta ahora un `simOpts` explícito. Antes
    sustituía silenciosamente el número pedido por 50; el launcher y el
    manifiesto registran tanto el valor solicitado como el efectivo.

## 5. Comandos y resultados

### Suite unitaria

```matlab
cd('.../EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
clearConfigurablesOverride();
r = runtests(fullfile(pwd,'tests','no_glove'), ...
    'IncludeSubfolders',true);
assert(all([r.Passed]));
```

Resultado exacto: `6/6 Passed`, `0 Failed`, `0 Incomplete`.

La suite cubre default/enum inválido, MAT sin variable `gloves`, contratos de
`rewardInfo` y outputs de reward, rechazo de Myo/controlador físico, ejecución
consecutiva de las dos fuentes dentro de la misma sesión MATLAB, guardado y
resumen EMG-only, y rechazo de un directorio con fuentes mezcladas.

### Launcher EMG-only

```matlab
run_no_glove_stage1_validation(struct( ...
    'seed',11, ...
    'numEpisodes',2, ...
    'resultsRoot','<ruta-de-salida>'))
```

Resultado previo al commit: `PASS`. Artefacto:
`C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage1_artifacts/precommit_ready/2026-08-18_02-55-03`.

| Episodio | Pasos | Reward media | trackingMSE | Saturación | Hold | Fin por Myo |
|---:|---:|---:|---:|---:|:---:|:---:|
| 1 | 9 | 0 | 0 | 0 | sí | sí |
| 2 | 9 | 0 | 0 | 0 | sí | sí |

El cero no es evidencia de desempeño: surge de una acción cero sobre una
referencia de mantenimiento inicial. Su única finalidad es comprobar el
desacoplamiento y la ausencia de deriva antes de la calibración.

### Regresión Agent7250

Se ejecutó el evaluador canónico con seed 11, `simMotors=true`, datos
pregrabados, `connect_glove=false`, sin entrenamiento y sin `overridePatch` de
referencia. Se solicitaron explícitamente `NumSimulations=50` y el manifiesto
confirmó `effectiveNumSimulations=50`. La corrida de ETAPA 0 también tuvo 50
simulaciones efectivas, aunque su launcher recibió `2`: el finalizador reemplazó
ese valor. El bug quedó corregido y cubierto por una prueba unitaria.

```matlab
opts = struct( ...
    'resultsRoot', ...
      'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage1_artifacts/agent7250_precommit_manifest', ...
    'overridePatch', struct('randomSeed',11));
runCheckpointTest(getAgent7250CheckpointPath(),50,false,opts);
```

Artefacto aceptado:
`C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage1_artifacts/agent7250_precommit_manifest/26-08-18 02 51 18`.

| Métrica de smoke | ETAPA 0 | ETAPA 1 | Diferencia |
|---|---:|---:|---:|
| episodios guardados | 50 | 50 | 0 |
| pasos medios | 16.040000000000 | 16.040000000000 | 0 |
| trackingMSE | 0.040798954456 | 0.040798954456 | 0 |
| trackingMAE | 0.158924490463 | 0.158924490463 | 0 |
| actionL2 | 0.614399597474 | 0.614399597474 | 0 |
| saturationFraction | 0.396016899767 | 0.396016899767 | 0 |
| deltaActionL2 del agregador | 0.245806200412 | 0.245806200412 | 0 |
| absPWM medio | 182.263563519814 | 182.263563519814 | 0 |

La comparación exacta de estas 14 variables legacy en los 50 archivos de
episodio dio `GLOVE_CORE_MISMATCHES=0`: `stateLog`, `actionLog`,
`actionWarpLog`, `actionSatLog`, `actionPwmLog`, `rewardLog`,
`rewardVectorLog`, `trackingMseLog`, `trackingMaeLog`, `actionL2Log`,
`deltaActionL2Log`, `saturationFractionLog`, `flexConvertedLog` y
`encoderAdjustedLog`. Se usó `isequaln` por archivo y variable. No se eliminó
ninguna variable del MAT histórico; el nuevo esquema añade ocho campos.
El resultado de esta comparación se guardó como
`legacy_regression_comparison.json/.mat` dentro del artefacto aceptado; contiene
ambas rutas, la lista de variables, los conteos y el número de diferencias.

`checkcode` inspeccionó los 20 archivos MATLAB creados o modificados. No emitió
mensajes para los archivos nuevos; conservó 10 avisos estáticos ya presentes en
archivos legacy (`configurables`, `Env`, evaluadores, loader y `trainInterface`).
`git diff --check` terminó sin errores.

## 6. Métricas y artefactos

El launcher crea por corrida:

- `manifest.json` y `manifest.mat`;
- `effective_config.mat`;
- `test_results.mat`;
- `episode_summary.csv`;
- `reproducible_command.txt`.

La regresión histórica crea además `checkpoint_test_manifest.json/.mat`, guarda
las opciones del launcher y añade un comando reproducible. El manifiesto incluye
los hashes del checkpoint, `00_configs.mat` y datasets, además del número de
simulaciones solicitado y efectivo.

El manifiesto EMG-only registra seed, commit, estado dirty, MATLAB, fuente,
scaffold, dataset, SHA-256 del dataset y de la configuración efectiva, flags de
seguridad, acción programada, salida, `hardwareUsed=false` y
`checkpointUsed=""`. El manifiesto de regresión histórica registra el checkpoint
real y su hash, los 12 datasets y sus hashes, el hash de `00_configs.mat`, y los
valores de simulaciones solicitado y efectivo.

Dataset del smoke: `DENIS.mat`, SHA-256
`6D079CEFFA2C4F25FB2594D3D9DC59FCBF5C5972035196ABA4BAEDC73AAB3F99`.

Agent7250 permanece con SHA-256
`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 7. Riesgos y límites

- `intentTarget` es solo un scaffold de mantenimiento, no intención decodificada.
- Las coordenadas de referencia son explícitamente distintas por fuente en esta
  etapa: flexión normalizada para guante y encoder normalizado para EMG-only. No
  deben compararse sus MSE como si fueran el mismo target.
- EMG-only suele durar más que el episodio emparejado con guante porque ahora
  termina por Myo. Es un cambio esperado de criterio, no una mejora.
- ETAPA 1 admite una sola reward en EMG-only para evitar rutas ocultas aún
  acopladas. La reward causal nueva pertenece a ETAPA 4.
- El `deltaActionL2` por paso es la media por componente e incluye la transición
  inicial desde cero; el agregador histórico usa suma por motor sobre `diff` y
  omite esa transición. Se preservó deliberadamente la cifra histórica, pero
  ambas definiciones no deben compararse como si fueran idénticas.
- Algunos campos que no existen en `00_configs.mat` de checkpoints antiguos
  (`period`, `maxNumberStepsInEpisodes`, `episodeDuration` y `randomSeed`, entre
  otros) aún dependen de defaults compatibles o del perfil explícito del commit
  evaluado. La regresión exacta valida este commit, no defaults futuros; no se
  cargan silenciosamente handles históricos con rutas absolutas obsoletas.
- Algunas funciones históricas (`calculateState`, la interfaz de acción y los
  pesos de reward) todavía consultan `configurables` durante el episodio. Los
  launchers mantienen el override fijo; cambiarlo mientras una instancia `Env`
  sigue viva produciría una configuración parcial y no está soportado.
- No se entrenó una política, no se cargó Agent7250 en la ruta EMG-only y no se
  evaluó separabilidad de DoF, reposo ni calibración.

## 8. Hardware

Confirmación explícita: no se abrió ningún puerto COM, no se construyó un
`Controller` físico, no se conectó un Myo real, no se envió PWM físico y no se
midió corriente. Todas las transiciones usaron `SimController` y
`RecordedMyo`.

## 9. Commit

Commit previsto de la etapa: `feat: decouple EMG intent reference source`.
No se realizó push ni se abrió PR.

## 10. Próxima etapa propuesta, no ejecutada

ETAPA 2 debe implementar calibración por sesión, envolvente sobre EMG cruda,
histéresis de reposo, decodificador de dos sinergias y generador de referencia
con límites de posición, velocidad y aceleración. Debe permanecer offline y sin
RL. Esta etapa no contiene ninguna implementación de ETAPA 2.
