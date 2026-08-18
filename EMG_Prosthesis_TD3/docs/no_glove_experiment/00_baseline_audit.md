# Auditoría de base para la línea EMG-only sin guante

**Etapa:** 0 — orientación, base y rama

**Fecha de auditoría:** 2026-08-18 (`America/Guayaquil`)

**Resultado:** PASS

**Rama:** `experiment/no-glove-intent-control`

**SHA base:** `6b213ba5c624fffb3f1094585c67d9c8ac43b737`

## 1. Alcance y reglas congeladas

Esta etapa solo orienta el repositorio, fija la procedencia y verifica la línea
histórica. No cambia la política, el entorno, la reward, el simulador, la
cuantización, la conversión encoder-flex ni los defaults. No inicia
entrenamiento y no porta código de `benchmark-motor2-diagnostic`.

Las reglas que gobiernan las siguientes etapas son:

- `Agent7250_valid_baseline.mat` es el benchmark histórico canónico. No se
  sobrescribe, mueve, reentrena ni usa como inicialización silenciosa de una
  política nueva.
- El soporte del guante se conserva para reproducir el benchmark. La nueva
  línea añadirá otra fuente de referencia.
- Toda ejecución de esta línea mantiene `simMotors=true` hasta una autorización
  posterior expresa.
- `saturationFraction` es la fracción de componentes motor-paso con
  `abs(effectiveAction) >= 0.95`; no significa que los cuatro motores estén al
  máximo durante esa fracción del tiempo.
- Los logs contienen comandos y PWM calculado/aplicado al simulador. No prueban
  corriente eléctrica medida.
- Las 40 salidas de WMoos son features estandarizadas, no amplitudes físicas
  acotadas a `[0,1]`.
- El MSE se mantiene como una hipótesis parcial para estudiar saturación o
  respuesta plana, no como causa raíz única.

## 2. Git, rama y preservación del trabajo local

Se ejecutó `git fetch origin --prune`. Antes del fetch, el `main` local estaba
en `672175735824a72b3f5f831584b3cdcfe7c46be6`; `origin/main` avanzó de ese SHA
a `6b213ba5c624fffb3f1094585c67d9c8ac43b737`. La divergencia era `0 1`, por lo
que el `main` local se adelantó por fast-forward y quedó idéntico a
`origin/main`.

La rama nueva se creó desde ese `main` verificado en un worktree separado:

```text
C:/Users/Cesarbmm/ProtesisPracticas_no_glove_intent_control
```

Esto evitó alterar el checkout original, que sigue en
`benchmark-motor2-diagnostic` y conserva 17 archivos no rastreados bajo
`docs/benchmark_motor2_diagnostic/`. Tampoco se tocaron los worktrees locales
`benchmark-base-multiseed-hardware-prep`, `hardware-agent7250-prep` ni
`myo-agent7250-preview`, todos con cambios no publicados.

No se hizo push y no se abrió PR.

## 3. Benchmark Agent7250 congelado

### 3.1 Artefactos canónicos

| Artefacto | Ruta versionada | Tamaño | SHA-256 |
|---|---|---:|---|
| Checkpoint | `matlab_code/checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat` | 398479 B | `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54` |
| Configuración de origen | `matlab_code/checkpoints/canonical/Agent7250_valid_baseline/00_configs.mat` | 13600 B | `F1DA3E89C22281DB8A256F5B18067EC4E2E9AD7119D283887C476C83F377C1B7` |

El checkpoint corresponde al blob Git
`4723e8b03efb50d95fbbc5198c6c1ae6315a7ad8`. Ese blob es idéntico en `main`,
`experiment/no-glove-intent-control` y `benchmark-motor2-diagnostic`. El smoke
de esta etapa no modificó el archivo y el hash se volvió a comprobar al
terminar.

El MAT contiene `saved_agent` (`rl.agent.rlTD3Agent`) y
`savedAgentResult` (`rl.train.rlTrainingResult`). El helper
`src/checkpoints/getAgent7250CheckpointPath.m` resuelve la ruta por medio de
`getAgent7250Benchmark.m`.

### 3.2 Configuración histórica

`00_configs.mat` contiene 45 campos. Se verificaron:

- `run_training=true`, `newTraining=true` en la configuración de origen;
- `usePrerecorded=true`;
- `simMotors=true`;
- `connect_glove=false`;
- `stateLength=52`, `observationVariant="markov52"`;
- `numEMGFeatures=40`, `emgHistoryLength=3`;
- `rewardType="trackingMseActionRateReward"`;
- `td3.useRecurrent=false`;
- `period=0.2 s`.

El campo `actionInterfaceVariant` no existe en este MAT histórico. Durante la
evaluación actual, `runCheckpointTest` recupera los campos disponibles y el
valor faltante proviene del default vigente
`actionInterfaceVariant="baselineQuantized"`. Por tanto, el checkpoint está
congelado, pero la reproducción no está completamente autocontenida: futuros
cambios de defaults deben usar un perfil/override explícito que preserve la
interfaz histórica.

El MAT también serializa function handles con rutas absolutas antiguas bajo
`C:/Users/pc/Desktop/PROTESIS_PRACTICAS/...`; no deben tomarse como rutas
portables. Además, el default actual `td3Residual.baseCheckpointPath` resuelve
silenciosamente a Agent7250 cuando el helper existe. La nueva política deberá
crear un agente explícitamente nuevo y deshabilitar ese residual; nunca debe
heredar este fallback.

### 3.3 Métricas canónicas

`src/checkpoints/getAgent7250Benchmark.m:25-35` fija las cifras publicadas:

| Métrica | Valor canónico |
|---|---:|
| `trackingMSE` | 0.043045 |
| `trackingMAE` | 0.160336 |
| `actionL2` | 0.596444 |
| `saturationFraction` | 0.392086 |
| `deltaActionL2` | 0.321385 |
| `absPwmMean` | 178.288566 |

Estas cifras también aparecen en el README raíz y en los reportes curados. No
hay junto al checkpoint un manifiesto ni logs crudos de las 50 simulaciones que
permitan recalcularlas desde un clon limpio; en el código son constantes
redondeadas. Deben conservarse como referencia canónica, sin sustituirlas por
un smoke nuevo ni por una evaluación realizada con otro seed/protocolo.

Existe además una ambigüedad de agregación que debe resolverse antes de comparar
nuevos resultados: `trackingMseActionRateReward.m:18-20` registra por paso
`mean((u_t-u_{t-1}).^2)` e incluye la transición inicial desde cero, mientras
`summarizeEpisodeDirectory.m:76-83` vuelve a calcular
`mean(sum(diff(u_eff).^2,2))`, excluye la transición inicial y suma los cuatro
motores. Ambos valores se llaman `deltaActionL2`, pero no son equivalentes.
La cifra canónica publicada `0.321385` corresponde a la convención de
evaluación/agregador.

## 4. Evidencia de campañas posteriores

Las campañas 20k y 50k no están publicadas en `main`. Su launcher, informes y
figuras se encuentran como cambios locales no rastreados en el worktree
`ProtesisPracticas_benchmark_base_multiseed`; los resultados crudos están bajo
`Agentes/`, que Git ignora. Se leyeron sin modificarlos y se recalcularon las
medias desde `summary/benchmark_base_multiseed_summary.csv`.

| Campaña | `trackingMSE` | `trackingMAE` | `actionL2` | `saturationFraction` | `deltaActionL2` | A/B/Rejected | Flags |
|---|---:|---:|---:|---:|---:|---|---:|
| 20k | 0.049695446530 | 0.173306618623 | 0.794785995152 | 0.627400058275 | 0.463241722880 | 0/0/5 | 9 |
| 50k | 0.049149089804 | 0.171188292543 | 0.715601025784 | 0.532328671329 | 0.491518550741 | 0/0/5 | 0 |

Los valores coinciden al redondear a seis decimales con el contexto canónico.
La campaña 50k no sobrescribió la 20k y ninguna reemplazó a Agent7250.

Evidencia local congelada por hash:

| Evidencia local no versionada | SHA-256 |
|---|---|
| CSV 20k `Agentes/benchmark_base_20k_multiseed/2026-07-07_00-09-43/summary/benchmark_base_multiseed_summary.csv` | `6E446FD0DDCF50342255C97C08CB68250DEE275BD8526E9CCA0150F032675CED` |
| MAT de resultados 20k | `4B380CC445B34B4AC4522AAC1524BDCE686EEBBFA222A3082BAF1839B1F834B7` |
| CSV 50k `Agentes/benchmark_base_20k_multiseed/2026-07-07_20-35-30/summary/benchmark_base_multiseed_summary.csv` | `634EDBC367BE6EF954FF6D108E36B88C9714A665C33E07C87EA10610E906F15B` |
| MAT de resultados 50k | `A71DE36D23152C49FA359C8B5FBF446EA8AB5E2E47414214979ECFE013A70DA2` |
| Reporte 20k `docs/benchmark_base_multiseed/benchmark_base_20k_selection_report.md` | `811137C72F791761967A1BE0C373767057DD36267F69056DE1EEF661F61EA660` |
| Reporte 50k `docs/benchmark_base_multiseed/benchmark_base_50k_selection_report.md` | `57AFAA1CF8980F6B93D02807E1EB4040075707DA65A63806BCB24F1235A62D00` |

Estos hashes documentan el estado local observado; no convierten los artefactos
en reproducibles desde un clon. Si se publican más adelante, deben añadirse con
su procedencia y sin promover ninguna política.

## 5. Evidencia Myo y compuerta de reposo

El README raíz solo resume esta línea. La evidencia detallada está sin publicar
en el worktree `myo-agent7250-preview` y en su `Agentes/` ignorado:

- se validó adquisición real de ocho canales y la ruta
  `Myo -> 40 features -> markov52 -> Agent7250 -> SimController`;
- Agent7250 produjo acciones altas en reposo (el informe local registra medias
  aproximadas `[0.820, 0.973, 0.921, 0.864]` en M1-M4 para una auditoría);
- la validación de consistencia de dos corridas terminó
  `Failed_InconsistentGate`, con 0/2 corridas aceptadas;
- corrida 1: reducción PWM de reposo `0.982328`, paso de contracción
  `0.966667`, PWM gated medio en reposo `2.266667`;
- corrida 2: reducción PWM de reposo `0.060473`, paso de contracción `1.0`,
  PWM gated medio en reposo `128.433333`;
- recomendación guardada: `Rest gate was not reproducible. Tune and repeat in simulation.`

El reporte de consistencia tiene SHA-256
`DDFD2059FA5FD5CF6D8D4491DDEDD74F1E0B9F5C1FBBC17C6F975D90AC450750` y
el CSV por corrida
`437961F67C385941F5B32872B1C3358A1426EB3C715DAAAE41866377B3FB3987`.
Esta evidencia respalda que la compuerta fue diagnóstica y no reproducible; no
es una solución validada ni una autorización de hardware.

## 6. Mapa del flujo publicado en `main`

### 6.1 Configuración, estado y acción

| Archivo | Función actual | Hallazgo relevante para la línea nueva |
|---|---|---|
| `matlab_code/config/configurables.m` | Defaults, overrides, estado, reward, acción y dispositivos | Defaults: entrenamiento 12k, `simMotors=true`, `markov52`, reward histórica e interfaz cuantizada. La línea nueva debe usar perfiles/overrides, no cambiar defaults globales. |
| `matlab_code/src/@Env/defineObservationInfo.m` | Declara `legacy44`, `markov52` y `stackedEmg132` según `stateLength` | `markov52` queda 40+4+4+4. No existe aún `intentMarkov60`. |
| `matlab_code/src/@Env/calculateState.m` | Calcula 40 WMoos, encoder normalizado, delta y acción efectiva previa | El estado no contiene la referencia. `intentMarkov60` deberá hacer explícitos `q_ref` y `v_ref`. |
| `matlab_code/src/@Env/updateEmgFeatureHistory.m` | Historial de features estandarizadas | En `markov52` el historial no se concatena; `emgHistoryLength=3` corresponde a `stackedEmg132`. |
| `matlab_code/src/@Env/remapActionForActuator.m` | Clip y cuantización de acción a PWM | `baselineQuantized` usa niveles `[0 64 96 128 160 192 224 255]` y umbral `0.05`; debe permanecer sin cambios en las primeras ablaciones. |

Varias configuraciones de `Env` son propiedades `Constant` evaluadas al cargar
la clase (`Env.m:31-81`). `setConfigurablesOverride` solo limpia la función
persistente `configurables`, no la clase. Una prueba aislada confirmó que, tras
cargar `Env.simMotors=false`, cambiar el override a `true` deja
`Env.simMotors=false` aunque `configurables('simMotors')` ya devuelva `true`.
`referenceSource` no debe implementarse como constante de clase: debe ser una
propiedad por instancia o usarse una recarga de clase explícita y controlada.
Existe otra divergencia del mismo tipo: `configurables.m:68` declara
`returnHomeAtEndEpisode=true`, pero `Env.m:43-45` ignora ese campo y fija la
constante a `false`.

### 6.2 Features EMG

`lib/WMoos_Features/getWmoosFeatures.m` recibe EMG cruda `m x 8`, calcula cinco
familias por canal (40 valores) y, con `C`/`S`, llama a `normalize(...,
'center',C,'scale',S)`. Esas 40 features pueden ser negativas o superar uno.
La envolvente de intención de la etapa 2 debe calcularse desde la EMG cruda,
antes y por una ruta separada de esta estandarización.

Una ventana determinista publicada de `40 x 8` produjo 40 features finitas en
el rango `[-1.94734136, 2.91885419]`, confirmando que no son amplitudes `[0,1]`.
`normValues.mat` mide 39041695 B, tiene SHA-256
`7DDA997F59E1327C8A4EF9CDDE07463506754FB73A52001E983B3A3877B017B2` y
contiene matrices/objetos históricos además de `C/S`, sin metadatos de sesión,
usuario u orden de canales. No es una calibración de intención reutilizable.

### 6.3 Simulador y conversiones

| Archivo | Rol | Observación |
|---|---|---|
| `src/@SimController/SimController.m` | Sustituto en software de `Controller` | `sendAllSpeed` solo actualiza velocidades simuladas; no mide corriente. |
| `src/@SimController/prosthesis_simulator.m` | Dinámica de cuatro motores | Carga `fit_C2.mat` y `pattern_curve.mat` mediante rutas relativas a `matlab_code`; el launcher debe fijar ese directorio. |
| `src/preprocess/encoder2Flex.m` | Convierte encoder a escala flex con `gap`, tramo lineal y saturación | Usa `abs(encoder)`. Devuelve `finishEpisode`, pero `step.m` no consume ese segundo resultado. |
| `src/preprocess/reduceFlexDimension.m` | Reduce nueve sensores del guante a cuatro referencias | Es dependencia exclusiva de la referencia histórica del guante y no debe ejecutarse en `emgIntent`. |

`SimController` usa un muestreo interno de `0.14 s`, distinto del periodo del
entorno `0.2 s`. Los modelos operativos quedaron identificados por SHA-256:

- `src/@SimController/fit_C2.mat`:
  `16382EC6F79228F9D0CFD80A59E2A8A094C65566EE769ECE986C0C81AF334030`;
- `src/@SimController/pattern_curve.mat`:
  `A519555BCFCBBC7B140843D6FC1240118738CD3A6CA69F6F5517617372073590`.

### 6.4 Reward y logging

`rewardFunctionSelector.m` selecciona la reward; la ruta canónica llama
`trackingMseActionRateReward.m`. Esta última usa:

```text
reward_i = -(error_i^2 + 0.01*u_i^2 + 0.05*Delta_u_i^2)
reward   = mean(reward_i)
```

La saturación se registra, pero `saturationPenalty=0` en esta reward. `step.m`
accede sin guardas a `trackingMse`, `trackingMae`, `actionL2`, `progressTerm`,
`smoothnessPenalty`, `deltaActionL2` y `saturationFraction`; solo protege
`saturationPenalty` con `isfield`. Antes de añadir otra reward debe existir un
contrato único de `rewardInfo` para evitar campos ausentes y conservar lectores
históricos.

### 6.5 Launchers y diagnósticos publicados

- `src/evaluation/runCheckpointTest.m`: evaluación, no entrenamiento; fuerza
  pregrabado, simulación y guante desconectado antes de aplicar un patch
  opcional.
- `src/evaluation/runCheckpointAudit.m` y `evaluateCheckpointSuite.m`: no
  entrenan, pero deben ejecutarse solo tras confirmar los flags efectivos del
  checkpoint/perfil.
- `examples/02 testing simulator/test_simulator.m` y `test_integration.m`:
  diagnósticos visuales de `SimController`, sin asserts propios.
- Los launchers `run_residual_lift_*` y
  `runResidualStopbandCampaignCore.m` entrenan o encadenan entrenamiento; no son
  smokes admisibles para esta etapa.

## 7. Acoplamiento exacto al guante

La ruta pregrabada actual no es EMG-only aunque el guante no forme parte de la
observación `markov52`.

1. **Dataset y launcher.** `getDataset.m:49-57` carga obligatoriamente
   `vars.emgs`, `vars.gloves` y `metadata`; `trainInterface.m:123-129` solicita
   ambos y construye `Env(agent_dir,true,emg,glove)`.
2. **Constructor.** `Env.m:165-201` acepta `gloveDatas`, lo guarda como
   `gloveSet` e instancia `RecordedGlove(gloveDatas{1})`. Un conjunto EMG sin
   guante falla antes del primer reset.
3. **Reset.** `reset.m:100-105` elige `g=gloveSet{repetitionId,side}` e instancia
   otro `RecordedGlove`. `reset.m:119-168` reinicia y lee el guante y solo sale
   del bucle cuando tanto `flexData` como EMG son no vacíos.
4. **Step.** `step.m:69-103` lee `this.glove`, conserva el `flexData` previo si
   llega vacío y no tiene una rama sin referencia de guante.
5. **Target/reward.** `step.m:122-125` ejecuta
   `reduceFlexDimension(this.flexData)` para construir `flexConverted`; la
   reward compara ese target con `encoder2Flex(this.motorData)`.
6. **Terminación.** `checkEndEpisode.m:12-16` termina datos pregrabados cuando
   `this.myo.exhausted || this.glove.exhausted`.
7. **Logs/gráficas.** `saveEpisode.m` persiste `flexConvertedLog`; los plots
   históricos esperan una trayectoria de guante.

Los 12 MAT publicados se inspeccionaron sin modificarlos: todos contienen
`emgs`, `gloves` y `metadata`, con formas de `300-330 x 2`, sin celdas vacías y
7420 pares gesto/lado en total. Cada EMG es `double`, `370-1022 x 8`; cada
guante es un vector de `18-54` structs con 14 campos. `RecordedMyo` modela
200 Hz y `RecordedGlove` 10 Hz. En 7405/7420 celdas (99.7978%) el guante tiene
menor duración nominal que la EMG, con diferencia máxima observada de 0.520 s;
por ello casi todos los episodios actuales terminan primero por guante. Quitar
esa dependencia cambia naturalmente el número de pasos y debe registrarse.
La metadata observada no incluye sesión, orden de canales ni calibración, y
`data/datasets/readme.md` no documenta el esquema ni las tasas.

Hay además un error de logging en `reset.m:176-177`: la etiqueta informa tamaño
de guante, pero el tercer valor vuelve a usar `size(motorData,1)`.

`simMotors=true` solo evita crear el `Controller` físico. No impide crear un
`Myo()` real: con `usePrerecorded=false`, `Env.m:202-216` instancia `Myo()` y
solo sustituye el guante por `FakeGlove` cuando `connect_glove=false`. Por eso
no se ejecutaron `evalTrainedAgent.m`, `fineTuning.m`, `runProsthesis.m` ni otros
scripts que construyen `Env` en modo no pregrabado. `evalRandomAgent.m` además
referencia `dataset1_sep` y `dataset2_extended`, ausentes del árbol publicado.

## 8. Comparación con `benchmark-motor2-diagnostic`

### 8.1 Divergencia

- `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- rama diagnóstica: `bedc3e2bb343e3350bb02ca90d6c6e247d706930`.
- merge-base: `672175735824a72b3f5f831584b3cdcfe7c46be6`.
- divergencia: un commit solo en `main`, cinco solo en la rama diagnóstica.
- delta propio desde el merge-base: 242 archivos, `+13949/-221`;
  174 PNG, 46 M, 10 MD, 8 PDF, 2 TEX, 1 BIB y 1 `.gitignore`.

Los cinco commits diagnósticos mezclan documentación, figuras y análisis con
reentrenamiento, rewards ponderadas, calibración por motor, cambio de interfaz,
postprocesado de acción y conversión encoder-flex. No son cherry-picks seguros.

### 8.2 Evidencia útil y límites

La rama aporta 185 archivos bajo `docs/benchmark_motor2_diagnostic/` (174 PNG,
7 PDF, 3 MD y 1 TEX), pero ningún CSV/MAT de resultados y ningún archivo bajo
`tests/`. Los runs citados viven en `Agentes/`, que no está versionado. Sus
conclusiones útiles son históricas:

- la campaña agregada fue `ConditionA=0`, `ConditionB=0`, `Rejected=5`;
- calibraciones de acción/conversión y la variante all-motor no fueron
  promovidas;
- la auditoría forense final clasificó baseline y candidatas como `rejected`;
- Agent7250 debe mantenerse congelado y no se justifica una campaña larga.

La rama también reporta `MSE=0.037229` para otra evaluación congelada. Su
protocolo/seed no está reconciliado con la cifra canónica `0.043045`; se conserva
como evidencia de otro run, no como reemplazo.

### 8.3 Decisión de port

En ETAPA 0 no se porta ningún archivo. Para ETAPA 5 quedan como candidatos a
adaptación individual, baseline-only y con pruebas nuevas:

- `analyzeMotor2Diagnostic.m`;
- `checkMotorReferencePermutation.m`;
- `compareAllMotorRegression.m`;
- `run_motor_response_conversion_diagnostic.m`;
- la parte baseline de `run_all_motor_actuation_sanity_check_extended.m`.

No se portarán calibraciones, `motorCalibratedQuantized`, heurísticas de M2,
offsets de conversión, reward ponderada ni launchers de entrenamiento/ablación
sin una decisión explícita y una ablación aislada.

## 9. Inconsistencias de documentación y artefactos no publicados

1. `matlab_code/README.md` presenta `run_repo_smoke_validation()` como smoke
   integral, pero el launcher configura 200 episodios y llama una campaña
   residual con `run_training=true`. No es admisible como smoke de ETAPA 0.
2. El comando sin argumentos `run_residual_lift_stopband_confirmation()` se
   anuncia como flujo activo, pero en un clon limpio intenta inferir una
   discovery desde `Agentes/residual_lift_stopband_discovery` y falla porque la
   carpeta no se versiona.
3. Los README inferiores llaman a stop-band “línea activa/nueva línea
   operativa”, mientras el README raíz más reciente fija Agent7250 como
   benchmark y trata las líneas posteriores como derivadas. El README raíz se
   toma como canónico; los textos inferiores son históricos/ambiguos.
4. Se presenta seed 22 como referencia distinta de Agent1850, pero no existe un
   checkpoint seed 22 canónico. En un clon limpio,
   `getResidualSeed22CheckpointPath` hace fallback a Agent1850, por lo que se
   pueden comparar dos etiquetas para el mismo checkpoint.
5. `EMG_Prosthesis_TD3/README.md` dice que los launchers están bajo `src/`; los
   launchers activos están en `workflows/published/`.
6. “Tests canónicos” son evaluaciones batch con `runCheckpointTest`; no existe
   una suite `matlab_code/tests/` versionada.
7. El README raíz menciona campañas 12k/20k/50k. En `main`, la evidencia 20k no
   está publicada; se localizó solo como evidencia local no rastreada. Las
   rutas `Agentes/...` citadas por múltiples reportes no se pueden resolver en
   un clon limpio.
8. `configurables.m:157` asigna `simMotors=true` pero el comentario dice
   “run in hardware/RT”; el valor es seguro para simulación, el comentario es
   incorrecto y riesgoso.
9. `configurables.m` deja por defecto `run_training=true`, 12000 episodios y
   `randomSeed=NaN`; el comando genérico `trainInterface('td3','','')` no cumple
   la política nueva de launcher, seed y manifiesto.
10. Los ejemplos de simulador solo hacen plots y requieren que el árbol completo
    esté en el path. Ejecutarlos mediante `run(...)` sin `addpath(genpath(pwd))`
    falla al resolver `SimController`.

Cruces positivos: los 12 MAT del dataset Denis, los dos checkpoints canónicos
prometidos y sus `00_configs.mat` sí están versionados.

## 10. Pruebas y verificaciones de ETAPA 0

### 10.1 Bootstrap estático MATLAB

En MATLAB `23.2.0.3097123 (R2023b) Update 11` se verificó:

```text
simMotors=1
connect_glove=0
usePrerecorded=1
observationVariant=markov52
rewardType=trackingMseActionRateReward
actionInterfaceVariant=baselineQuantized
checkpoint existente=1
```

Resultado: PASS.

### 10.2 Evaluación corta del checkpoint

Se ejecutó el launcher existente:

```matlab
opts = struct( ...
    'resultsRoot', ...
      'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage0_artifacts/agent7250_smoke_seed11', ...
    'overridePatch', struct( ...
      'randomSeed', 11, ...
      'simMotors', true, ...
      'connect_glove', false, ...
      'usePrerecorded', true, ...
      'run_training', false));
runCheckpointTest(getAgent7250CheckpointPath(), 2, false, opts);
```

`runCheckpointTest` además fija evaluación, `newTraining=false` y carga el
checkpoint existente. Resultado: PASS en 58.3 s; se crearon 50 archivos de
episodio.

**Errata identificada en ETAPA 1:** no fueron resets internos de dos
simulaciones. `localFinalizeRuntimeSettings` reemplazaba silenciosamente el
`simOpts` del launcher por `NumSimulations=50`; por tanto, la corrida efectiva
fue de 50 simulaciones. ETAPA 1 corrige el finalizador para respetar el perfil
explícito. La evidencia numérica de esta auditoría no cambia, pero el argumento
`2` de este comando histórico no describía la configuración efectiva.

El `00_configs.mat` guardado en la salida confirmó `randomSeed=11`,
`run_training=0`, `newTraining=0`, `usePrerecorded=1`, `simMotors=1`,
`connect_glove=0`, `stateLength=52`, reward e interfaz canónicas.
El `overridePatch` se fusiona después de los seguros internos del launcher; en
esta ejecución se fijaron de nuevo explícitamente todos los flags seguros. Un
patch futuro no debe poder revertirlos accidentalmente.

Resumen del smoke (no sustituye métricas canónicas):

| Campo | Resultado |
|---|---:|
| Episodios guardados | 50 |
| Pasos medios por episodio | 16.040000 |
| `trackingMSE` | 0.040798954 |
| `trackingMAE` | 0.158924490 |
| `actionL2` | 0.614399597 |
| `saturationFraction` | 0.396016900 |
| `deltaActionL2` del summarizer | 0.245806200 |
| `absPwmMean` | 182.263563520 |

Los artefactos se escribieron fuera del repositorio experimental para mantener
el commit de etapa pequeño.

### 10.3 Ejemplos del simulador

- Primer intento con `run('examples/.../test_simulator.m')` y sin añadir todo
  el proyecto al path: FAIL esperado de bootstrap,
  `Unable to resolve the name 'SimController.prosthesis_simulator'`.
- Repetición con `addpath(genpath(pwd))`, figuras invisibles y asserts de forma
  y finitud: PASS.
- `test_simulator.m`: salida final `401 x 4`, todos los valores finitos.
- `test_integration.m`: salida final `29 x 4`, todos los valores finitos.

No se ejecutó `run_repo_smoke_validation()` porque entrena. No se ejecutaron
launchers Myo, glove, COM, hardware, PWM físico ni campañas.

## 11. Riesgos y cuestiones abiertas

- Las métricas canónicas Agent7250 están publicadas como constantes, pero no
  pueden recalcularse desde logs crudos versionados.
- La configuración histórica no fija todos los campos conductuales actuales;
  en particular, no contiene `actionInterfaceVariant`.
- `deltaActionL2` tiene dos definiciones de agregación con el mismo nombre.
- Las propiedades `Constant` de `Env` pueden dejar overrides obsoletos entre
  experimentos de una misma sesión MATLAB.
- El flujo pregrabado exige guante en constructor, reset, step, terminación,
  reward y dataset; no basta con cambiar el target en una única línea.
- Como el guante agota antes que la EMG en casi todo el dataset, cambiar la
  terminación puede alterar la longitud de episodios incluso si la señal EMG no
  cambia.
- `rewardInfo` no tiene aún un contrato formal compartido por todas las rewards.
- `simMotors=true` no evita por sí solo la conexión al Myo real.
- La evidencia 20k/50k, Myo y gran parte del diagnóstico M2 sigue local y no es
  reproducible desde un clon limpio.
- Las pruebas de simulador son scripts visuales, no unit tests.
- No hay medición de corriente ni temperatura; cualquier afirmación eléctrica
  queda fuera de la evidencia disponible.

## 12. Propuesta de ETAPA 1 — no ejecutada

Tras una orden explícita `CONTINUAR ETAPA 1`, la siguiente etapa debe:

1. añadir `referenceSource="glove"|"emgIntent"` mediante override, con valor
   por instancia en `Env`, no como propiedad `Constant` cacheada;
2. preservar bit a bit la ruta `glove` y cubrirla con una prueba de regresión;
3. separar la carga de dataset EMG de `gloves` cuando la fuente sea
   `emgIntent`;
4. hacer que constructor, reset, step y terminación no lean `RecordedGlove`,
   `gloveSet`, `flexData` ni `reduceFlexDimension` en `emgIntent`;
5. añadir `intentTarget`, `intentVelocity`, `referenceHistory` y
   `referenceHistoryCount` con inicialización determinista;
6. definir un constructor común de `rewardInfo` y un logging compatible hacia
   atrás;
7. crear pruebas bajo `matlab_code/tests/no_glove/` para ambas fuentes y un
   launcher EMG-only de episodio completo, siempre con `simMotors=true`, seed y
   ruta de salida explícitos.

ETAPA 1 no ha sido iniciada.

## 13. Confirmación de seguridad

Durante ETAPA 0 no se creó `Controller`, no se abrió ningún puerto COM, no se
conectó Myo ni guante, no se envió PWM físico y no se entrenó ninguna política.
Todas las ejecuciones dinámicas usaron datos pregrabados y `SimController` con
`simMotors=true`.
