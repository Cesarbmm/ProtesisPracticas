# E3D — Ablación del contexto temporal de intención EMG · RESULTADOS

Worktree `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit` · rama `experiment/no-glove-paired-reference-td3` · HEAD `165be049eb41fc41254435181c9857fe0f22ed1c`.
Cierre de auditoría supervisada. Sin entrenamiento RL, sin cambios en Git, sin push. E3C permanece `TEMPORAL_INFORMATION_NOT_DEMONSTRATED` y no se reinterpreta.

## 1. Resultado

| Clave | Valor |
|---|---|
| `E3D_RESULT` | **TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED** |
| `TEMPORAL_EMG_CONTEXT_SUPPORTED` | **NO** |
| Gates preregistrados superados | **7 de 9** (fallan C y D) |
| `E3E_PREPARATION` | NO |
| `RECURRENT_FACTORIZED_CATEGORICAL_PPO_PREPARED` | NO |
| `RECURRENT_RL_TRAINING_STARTED` | NO |

La hipótesis E3D era que la historia **exclusivamente de EMG** aporta información temporal de intención cuando el estado mecánico **actual** entra por una rama separada. La memoria EMG mejora de forma clara la **clasificación** de dirección y fase-dirección, pero **no** mejora el control closed-loop: la apertura empeora un 9.71 % y el control de orden temporal no alcanza el umbral preregistrado. Al fallar cualquier gate, el preregistro obliga a cerrar la vía recurrente con Denis/WMoos actuales.

## 2. Diseño evaluado

- **BASELINE**: `WMoos40` actual → FC64/ReLU, concatenado con `[q_t, delta_q_t, previousEffectiveAction_t]` (12 mecánicas actuales). Sin memoria.
- **TEMPORAL_EMG**: `WMoos40` causal de los últimos **L = 8** pasos → **GRU64** (salida final), concatenado con las mismas 12 mecánicas **actuales**.
- **Sin historia mecánica** en ninguna arquitectura. L = 8 congelado. Sin fuga de futuro.
- Objetivos primarios: `direction` y `phase_direction`. Oracle-action es **secundario diagnóstico**, sin gate.
- `teacher`, `direction` y `phase` se usan **sólo como labels**, nunca como entradas.
- Seeds pareadas: 20260923, 20260924, 20260925 · 40 épocas · receta supervisada común · checkpoint único época 40.
- 200 episodios: 140 TRAIN (BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA) y 60 VALIDATION (JOE, JONATHAN, KHAROL). MATEO/SANDRA sellados.

## 3. Tabla de gates preregistrados A–I

Todos los valores son **media de los tres seeds sobre VALIDATION**. PASS global sólo si los nueve pasan.

| Gate | Criterio preregistrado | Medido | Umbral | Resultado | Nota |
|---|---|---|---|---|---|
| **A** | Direction macro-F1 temporal ≥ baseline + 0.03 | `0.856371` | `≥ 0.840528` | ✅ PASS | ganancia +4.5843 pp |
| **B** | Phase-direction macro-F1 temporal ≥ baseline + 0.05 | `0.587667` | `≥ 0.560308` | ✅ PASS | ganancia +7.7359 pp |
| **C** | Ordered − shuffled phase-direction F1 ≥ 0.02 | `0.011998` | `≥ 0.020000` | ❌ **FAIL** | orden +1.1998 pp |
| **D** | Opening MSE temporal ≤ 0.90 × baseline | `0.063697` | `≤ 0.052255` | ❌ **FAIL** | cambio +9.7063 % |
| **E** | Closing MSE temporal ≤ 1.05 × baseline | `0.101780` | `≤ 0.126199` | ✅ PASS | cambio −15.3177 % |
| **F** | Global MSE temporal < baseline | `0.082738` | `< 0.089126` | ✅ PASS | cambio −7.1667 % |
| **G** | Cero ciclos y periodicidades finales | `ciclos 0 / periodicidades 0` | `= 0` | ✅ PASS | los tres seeds |
| **H** | M3: ≤ 1 reversión adicional en total de 3 seeds | `temporal 0 vs baseline 0` | `≤ 1` | ✅ PASS | delta 0 |
| **I** | Media MAX_CATEGORY_FRACTION ≤ 0.90 | `0.852282` | `≤ 0.900000` | ✅ PASS | baseline 0.840681 |

**Resultado global: FAIL** — 7 PASS, 2 FAIL. No se redefinió ningún gate ni umbral tras la medición.

### Lectura de los dos fallos

- **Gate C (orden temporal).** Al permutar únicamente el EMG pasado, la macro-F1 de fase-dirección cae sólo **1.1998 pp** (0.587667 ordenado frente a 0.575669 desordenado), frente a los 2.00 pp exigidos. La ganancia de la rama temporal proviene mayoritariamente de disponer de **más muestras EMG** en la ventana, no del **orden** en que llegan: el GRU se comporta en gran medida como un agregador del contenido de la ventana.
- **Gate D (apertura closed-loop).** La MSE de apertura pasa de `0.058062` a `0.063697`, un **+9.7063 %**, cuando el gate exigía una reducción de al menos el 10 %. Es un empeoramiento claro, no un empate.

## 4. Métricas VALIDATION — media de tres seeds

### 4.1 Clasificación de intención

| Métrica | BASELINE | TEMPORAL_EMG | Diferencia |
|---|---|---|---|
| Direction macro-F1 | 0.810528 | 0.856371 | **+4.5843 pp** |
| Phase-direction macro-F1 | 0.510308 | 0.587667 | **+7.7359 pp** |
| Oracle-action macro-F1 *(secundario)* | 0.129422 | 0.137854 | +0.8432 pp |
| Oracle NLL *(secundario)* | 1.066747 | 1.043682 | -0.023065 |

**Control de orden (shuffle del pasado EMG, media de tres seeds):**

| Métrica | Ordenado | Desordenado | Pérdida por desorden |
|---|---|---|---|
| Direction macro-F1 | 0.856371 | 0.842929 | +1.3442 pp |
| Phase-direction macro-F1 | 0.587667 | 0.575669 | **+1.1998 pp** |
| Oracle-action macro-F1 | 0.137854 | 0.129679 | +0.8175 pp |

### 4.2 Control closed-loop causal

| Métrica | BASELINE | TEMPORAL_EMG | Cambio |
|---|---|---|---|
| MSE global | 0.089126 | 0.082738 | **-7.1667 %** |
| MSE apertura | 0.058062 | 0.063697 | **+9.7063 %** |
| MSE cierre | 0.120190 | 0.101780 | **-15.3177 %** |
| Reward medio | -0.089623 | -0.083510 | +0.006113 |
| Correlación apertura | 0.340372 | -0.208029 | -0.548402 |

El patrón es asimétrico y consistente en los tres seeds: **el cierre mejora, la apertura empeora**. La mejora global (−7.17 %) está enteramente traccionada por el cierre (−15.32 %), que domina numéricamente la media. La correlación de apertura cae a valor **negativo** en la rama temporal, señal de que su respuesta en apertura deja de seguir la referencia.

### 4.3 Patologías y saturación de acción

| Métrica | BASELINE | TEMPORAL_EMG |
|---|---|---|
| Flat response (apertura) | 0.502778 | **0.569444** |
| Flat response (global) | 0.640278 | 0.533333 |
| Fracción PWM 0 | 0.792440 | 0.766338 |
| Acción sin movimiento | 0.315441 | 0.404358 |
| Sin movimiento (apertura) | 0.359230 | 0.415380 |
| Máx. fracción categórica | 0.840681 | 0.852282 |
| Ciclos finales | 0 | 0 |
| Periodicidades finales | 0 | 0 |
| Reversiones M3 | 0 | 0 |

Estabilidad limpia en ambas ramas: **cero** ciclos, periodicidades y reversiones M3 en los tres seeds (gates G y H). Pero la rama temporal aumenta la fracción de **respuesta plana en apertura** (0.502778 → 0.569444) y la acción sin movimiento (0.315441 → 0.404358): responde menos, justo donde el gate D falla. La estabilidad no rescata E3D porque fallan los gates de utilidad temporal y de control.

## 5. Métricas por seed (VALIDATION)

Se reportan los tres seeds sin elegir el mejor, según preregistro.

### BASELINE

| Seed | Dir F1 | Phase-dir F1 | MSE global | MSE apertura | MSE cierre | Flat apert. | PWM0 | Máx. cat. | Ciclos | Period. | M3 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 20260923 | 0.825250 | 0.487186 | 0.087087 | 0.054716 | 0.119459 | 0.491667 | 0.812355 | 0.861949 | 0 | 0 | 0 |
| 20260924 | 0.785029 | 0.526368 | 0.090961 | 0.053675 | 0.128248 | 0.375000 | 0.702146 | 0.744780 | 0 | 0 | 0 |
| 20260925 | 0.821305 | 0.517369 | 0.089328 | 0.065793 | 0.112863 | 0.641667 | 0.862819 | 0.915313 | 0 | 0 | 0 |
| **media** | **0.810528** | **0.510308** | **0.089126** | **0.058062** | **0.120190** | **0.502778** | **0.792440** | **0.840681** | **0** | **0** | **0** |

### TEMPORAL_EMG

| Seed | Dir F1 | Phase-dir F1 | MSE global | MSE apertura | MSE cierre | Flat apert. | PWM0 | Máx. cat. | Ciclos | Period. | M3 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 20260923 | 0.857418 | 0.574305 | 0.083277 | 0.061525 | 0.105028 | 0.575000 | 0.793503 | 0.870070 | 0 | 0 | 0 |
| 20260924 | 0.852683 | 0.584415 | 0.087842 | 0.076135 | 0.099550 | 0.700000 | 0.775812 | 0.860789 | 0 | 0 | 0 |
| 20260925 | 0.859012 | 0.604282 | 0.077096 | 0.053431 | 0.100761 | 0.433333 | 0.729698 | 0.825986 | 0 | 0 | 0 |
| **media** | **0.856371** | **0.587667** | **0.082738** | **0.063697** | **0.101780** | **0.569444** | **0.766338** | **0.852282** | **0** | **0** | **0** |

### Shuffle del pasado EMG, por seed

| Seed | Dir F1 | Phase-dir F1 | Oracle F1 | Oracle NLL |
|---|---|---|---|---|
| 20260923 | 0.849015 | 0.570458 | 0.127115 | 1.051820 |
| 20260924 | 0.842128 | 0.567122 | 0.132078 | 1.023001 |
| 20260925 | 0.837646 | 0.589429 | 0.129844 | 1.078096 |
| **media** | **0.842929** | **0.575669** | **0.129679** | **1.050973** |

El gate C falla en los tres seeds por separado, no por promediado: las pérdidas por desorden individuales son +0.3847 pp, +1.7294 pp y +1.4853 pp, todas por debajo de 2.00 pp.

## 6. TRAIN frente a VALIDATION — el hallazgo central

### 6.1 Clasificación de intención (macro-F1)

| Modelo | Tarea | TRAIN | VALIDATION | Brecha |
|---|---|---|---|---|
| BASELINE | direction | 0.914820 | 0.810528 | **0.104292** |
| BASELINE | phase-direction | 0.700888 | 0.510308 | **0.190580** |
| TEMPORAL_EMG | direction | 0.992132 | 0.856371 | **0.135761** |
| TEMPORAL_EMG | phase-direction | 0.845020 | 0.587667 | **0.257353** |

### 6.2 Control closed-loop

| Modelo | Split | MSE global | MSE apertura | MSE cierre | Flat apert. | PWM0 | Sin movim. | Máx. cat. |
|---|---|---|---|---|---|---|---|---|
| BASELINE | TRAIN | 0.074752 | 0.058751 | 0.090752 | 0.9012 | 0.8928 | 0.2204 | 0.9204 |
| BASELINE | VALIDATION | 0.089126 | 0.058062 | 0.120190 | 0.5028 | 0.7924 | 0.3154 | 0.8407 |
| TEMPORAL_EMG | TRAIN | 0.055303 | 0.051691 | 0.058915 | 0.6012 | 0.7542 | 0.3565 | 0.8235 |
| TEMPORAL_EMG | VALIDATION | 0.082738 | 0.063697 | 0.101780 | 0.5694 | 0.7663 | 0.4044 | 0.8523 |

Este contraste es el resultado más informativo de E3D y no era visible en las medias de VALIDATION por sí solas:

- En **TRAIN**, la memoria EMG **mejora** la apertura: `0.058751` → `0.051691` (**-12.02 %**).
- En **VALIDATION**, la misma arquitectura la **empeora**: `0.058062` → `0.063697` (**+9.71 %**).
- La brecha TRAIN→VALIDATION en phase-direction crece de 0.190580 (baseline) a 0.257353 (temporal); en direction, de 0.104292 a 0.135761.

Es decir: **el contexto temporal EMG sí contiene información utilizable, y la rama temporal la explota — pero la explota de forma específica a los sujetos de entrenamiento.** El fallo de E3D no es de capacidad ni de optimización; es de **generalización entre sujetos**. Esto no estaba preregistrado como gate y se reporta como observación, no como reinterpretación del resultado.

## 7. Comparación con E3B BEST

Comparación exclusivamente diagnóstica, según preregistro.

| Métrica | E3B BEST (PPO categórico, 500k) | E3D TEMPORAL_EMG | Brecha |
|---|---|---|---|
| MSE global | 0.057439 | 0.082738 | **+0.025299** |
| MSE apertura | 0.056553 | 0.063697 | +0.007144 |
| MSE cierre | 0.058324 | 0.101780 | +0.043455 |

Los probes supervisados E3D siguen por detrás de E3B BEST en las tres métricas. La comparación no es directa —E3B es una política PPO entrenada con reward, E3D son probes supervisados— pero fija la escala: la memoria EMG no acerca el control a E3B, y la brecha global sigue siendo de **0.025299**.

## 8. Comparación con E3C

| | E3C | E3D |
|---|---|---|
| Hipótesis | memoria sobre el estado markov52 completo (GRU full-markov52) | memoria **sólo EMG** + mecánica actual por rama separada |
| Oracle imitation | no mejora (FF 0.160006 vs GRU 0.162325; NLL empeora +1.87 %) | secundario, sin gate |
| Direction / phase | mejora secundaria (FF ≈ 0.8888 → GRU ≈ 0.9598; fase ≈ 0.5684 → 0.6390) | mejora primaria confirmada (+4.58 pp / +7.74 pp) |
| Apertura closed-loop | **mejora** (FF 0.070800 → GRU 0.048368) | **empeora** (0.058062 → 0.063697) |
| Resultado | `TEMPORAL_INFORMATION_NOT_DEMONSTRATED` | `TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED` |

E3C mostró que un GRU sobre el estado completo mejoraba la apertura **frente a un FF débil**, y esa evidencia secundaria fue precisamente lo que motivó abrir E3D. E3D responde la pregunta que E3C dejó abierta: al **separar** la historia EMG de la mecánica actual, la ganancia de clasificación se confirma y se amplía, pero la ventaja en apertura **desaparece y se invierte**. La mejora de apertura observada en E3C no se reproduce cuando la memoria se restringe al EMG, lo que sugiere que aquella ventaja dependía de la historia **mecánica**, no de la EMG.

**E3C no se reinterpreta.** Sigue cerrado como `TEMPORAL_INFORMATION_NOT_DEMONSTRATED`; E3D es una hipótesis distinta con su propio preregistro y su propio resultado.

## 9. Interpretación científica

La conclusión correcta **no** es que la memoria temporal no contenga información. Sería demasiado fuerte y la evidencia la contradice. La formulación que sostienen los datos es:

> Con Denis, WMoos40, contexto causal L = 8, GRU64 y la receta E3D, se observa mejora en la clasificación de > dirección y fase-dirección, pero **no se demuestra** que ese contexto temporal EMG mejore el control closed-loop. > En particular, la apertura empeora y el control de orden temporal no alcanza el gate preregistrado.

Puntos que deben quedar registrados:

- **La señal temporal diagnóstica existe.** +4.58 pp en dirección y +7.74 pp en fase-dirección son consistentes en los tres seeds.
- **Esa señal no se traduce en mejor control.** La apertura empeora un 9.71 % y la respuesta plana en apertura aumenta.
- **El orden importa poco.** Con sólo 1.20 pp de pérdida al desordenar el pasado, la ganancia procede sobre todo del contenido agregado de la ventana, no de su secuencia.
- **No se justifica todavía Recurrent Factorized Categorical PPO.** Añadir memoria EMG a PPO no resuelve el fallo de apertura y generalización de E3B; E3D es evidencia en contra de esa vía tal como estaba planteada.
- **No se afirma ausencia universal de valor de GRU/LSTM.** El resultado está acotado a este dataset, esta representación EMG, este L, esta arquitectura y esta receta.

## 10. Evidencia visual

### 10.1 Figuras compactas

Una figura por episodio, 4 motores, teacher frente a h(q). 200 episodios × 6 probes, en PNG y FIG.

| Probe | TRAIN (PNG + FIG) | VALIDATION (PNG + FIG) | Total |
|---|---|---|---|
| `BASELINE_20260923` | 140 + 140 | 60 + 60 | 400 |
| `BASELINE_20260924` | 140 + 140 | 60 + 60 | 400 |
| `BASELINE_20260925` | 140 + 140 | 60 + 60 | 400 |
| `TEMPORAL_EMG_20260923` | 140 + 140 | 60 + 60 | 400 |
| `TEMPORAL_EMG_20260924` | 140 + 140 | 60 + 60 | 400 |
| `TEMPORAL_EMG_20260925` | 140 + 140 | 60 + 60 | 400 |
| **Total** | **840 + 840** | **360 + 360** | **2400** |

`COMPACT_FIGURES = 2400` archivos (1200 PNG + 1200 FIG), correspondientes a 1200 figuras de episodio.

### 10.2 Figuras annotated

Seis episodios congelados de `diagnostic_selection.csv` (selección previa E3C, por resultados E3B), primer seed preregistrado, dos comparaciones por episodio.

| Sujeto | Row | Side | Motivo de selección | E3B MSE | E3B flat |
|---|---|---|---|---|---|
| JONATHAN | 1 | 2 | peor MSE apertura; máxima flat apertura | 0.103546 | 0.75 |
| JOE | 111 | 2 | mediana inferior apertura VALIDATION | 0.051222 | 0.25 |
| JOE | 220 | 1 | mayor mejora cierre frente TD3 | 0.044143 | 0.00 |
| JOE | 220 | 2 | mediana apertura JOE | 0.061854 | 0.25 |
| JONATHAN | 234 | 2 | mediana apertura JONATHAN | 0.042800 | 0.25 |
| KHAROL | 178 | 2 | mediana apertura KHAROL | 0.049017 | 0.75 |

Comparaciones: `BASELINE_vs_TEMPORAL_EMG` y `E3B_vs_TEMPORAL_EMG`. Cada figura incluye teacher, h(q), `effectiveAction = PWM/255`, más PWM y `selectedProbability`.

`ANNOTATED_FIGURES = 12` figuras (6 episodios × 2 comparaciones), 48 archivos: PNG + FIG + CSV + MAT por figura.

Columnas exactas de los CSV: `policy, step, motor, teacher, h_q, category, PWM, effectiveAction, selectedProbability, headEntropy, q, delta_q`.

## 11. Viewer traces

`VIEWER_TRACES_READY = YES`

18 trazas = 3 políticas × 6 episodios de la selección diagnóstica congelada:

- `E3B_CATEGORICAL_BEST`
- `E3D_BASELINE`
- `E3D_TEMPORAL_EMG`

Formato verificado en las 18: 26 campos, incluyendo `q`, `PWM`, `step`, `time`, `Ts = 0.2`, `subject`, `row`, `direction`, `policy`, `checkpoint`, `checkpointSHA256`, `plantManifest`, `source`, `termination = EMG_ONLY`, `teacherLoaded = false`, `trainingExecuted = false`. Procedencia `saved_actor → GloveFreePolicyRuntime → patternCurveCanonical`. No se abrió el sandbox, no se recalculó la planta, no se usó S4.

## 12. Tests e integridad

### 12.1 Fallo del launcher de regresiones y su corrección

El nuevo launcher E3D (`e3dRunRegressionTests.m`) falló en dos tests de E3C:

- `testE3CTemporal/testClosedLoopDeterministicAllSixModels`
- `testE3CTemporal/testTeacherCounterfactualDoesNotChangeAction`

**Diagnóstico.** Ambos tests ejecutan un rollout real (`e3axRollout` → `GloveFreePolicyRuntime`). El guard de `GloveFreePolicyRuntime` los bloqueó **correctamente** con `E2A:TrainingForbidden` (*«Fijar run_training=false para ejecutar; esta clase no admite entrenamiento RL»*). La causa es que el launcher E3C original **nunca ejecutaba** `testE3CTemporal.m`: su lista de suites terminaba en `testE3BCategorical.m` y totalizaba 294 tests. Esos tests se ejecutaban dentro de `runE3CTemporalAudit.m`, que sí fija el contexto de inferencia. Al incorporar `testE3CTemporal.m` al launcher E3D (294 + 32 = 326), ese contexto no se estaba fijando.

**Corrección aplicada — únicamente en el launcher nuevo.** Se añadió la función local `inferenceContext`, que reproduce **literalmente** la línea 8 de `runE3CTemporalAudit.m`:

```matlab
cfg=e3cConfig;s=load(fullfile(cfg.e3bRun,"config.mat"),"o");o=s.o;
o.run_training=false;o.newTraining=false;setConfigurablesOverride(o);
```
y se invoca antes de la suite E3C (`if file=="testE3CTemporal.m",inferenceContext;end`), con restauración del override previo al salir.

No se modificaron los tests históricos. No se relajó el guard. No se modificó `GloveFreePolicyRuntime`. No se alteró ninguna constante del Env.

`REGRESSION_LAUNCHER_FIXED = YES`

### 12.2 Conteo de tests

| Conjunto | Tests | Estado |
|---|---|---|
| Regresiones previas (e0p/e2a/e2b/e2c → e2g, E3AX, CAP192, E3B, E3C) | 326 | 326 PASS |
| Nuevos tests E3D (`testE3DTemporalIntent`) | 30 | 30 PASS |
| **Total** | **356** | **356 PASS** |

Desglose de las 326: 81 del bloque `e0p_e2a_e2b_e2c` (59 previos + 22 E2C), más las suites E2D–E2G, E3AX, CAP192, E3B y las 32 de `testE3CTemporal`. Los 30 tests E3D cubren interfaces 40/12, causalidad, ausencia de historia mecánica, reset, prefijos variables, shuffle del pasado, labels offline, receta de tres seeds, closed-loop determinista, heads, selección diagnóstica congelada, correspondencia de gates con el preregistro e integridad histórica.

**Advertencia de trazabilidad, declarada explícitamente.** El `test_results.csv` que arroja 326/326 es la fusión de la corrida inicial (324 PASS + los 2 fallos) con el retry de esos dos tests bajo el contexto corregido (`corrected_inference_context_retry.csv`, ambos PASS). El estado inicial se conserva en `test_results_initial.csv` y `summary_initial.json`. **No se ha ejecutado todavía una corrida limpia extremo-a-extremo del launcher ya corregido**, porque requiere MATLAB y esta sesión no tiene acceso a él. El total 356/356 refleja resultados realmente ejecutados, pero en dos tramos, no en una sola pasada.

### 12.3 Integridad de artefactos históricos

Verificación **independiente**: se recalculó SHA-256 de los 4860 archivos de `historical_hashes_before.csv` y se comparó con el manifiesto congelado antes de E3D.

| Comprobación | Resultado |
|---|---|
| Archivos verificados | 4860 |
| Sin cambios | **4859** |
| Ausentes | 0 |
| Modificados | 1 — `matlab_code/exportE3AXViewerTrace.m` |

El único cambio es la **adaptación autorizada** declarada en `integrity_before.json` (*«exportE3AXViewerTrace: E3D class recognition only»*) y permitida por el preregistro. Su diff completo es de tres líneas y se limita a reconocer la nueva clase:

1. `addpath` del directorio `e3d`;
2. `isE3D=isa(actor,"E3DProbeActor")` y extensión de `isProbe`;
3. etiqueta `policy="E3D_"+actor.Kind+"_PROBE_"+stem`.

No cambia campos de la traza, ni la simulación, ni el runtime, ni la planta.

`Env`, `reward`, planta, E3B y E3C: intactos. MATEO/SANDRA: no abiertos. Sandbox físico: no tocado.

### 12.4 Estado de Git

| Clave | Valor |
|---|---|
| Worktree | `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit` |
| Rama | `experiment/no-glove-paired-reference-td3` |
| HEAD | `165be049eb41fc41254435181c9857fe0f22ed1c` |
| Archivos tracked | 8451 |
| Tracked modificados | **0** |
| Tracked borrados | **0** |
| `git status --short -uno` | vacío (working tree limpio en tracked) |
| `git diff --check` | **PASS** (sin errores de whitespace) |
| Commit | NO |
| Push | NO |
| Reparación de Git | NO intentada |

HEAD coincide exactamente con el histórico esperado. Se verificaron los **8451 archivos tracked** comparando cada blob del índice con el working tree: **0 modificados y 0 borrados**, por lo que `git status --short -uno` está vacío y `git diff --check` pasa trivialmente. Todo el trabajo E3AX/E3B/E3C/E3D es **untracked**: Git está pospuesto desde el commit E2B, tal como fija el preregistro. En particular `exportE3AXViewerTrace.m` **no existe en HEAD**, de modo que la adaptación autorizada no toca ningún archivo versionado. La lectura de Git se hizo con un índice temporal copiado, sin escribir nada en `.git`.

## 13. Limitaciones

- Un único dataset (Denis) y una única representación EMG (`WMoos40`). No se ha probado otra normalización.
- Un único L = 8, un único tamaño de GRU (64) y una única receta. Congelados por preregistro; **no** se han probado L16, L32, LSTM, Transformer, otro GRU, otro reward, otra arquitectura ni otro split, y no deben probarse automáticamente.
- Sólo tres semillas. Suficiente para el criterio preregistrado, insuficiente para estimar bien la varianza.
- Los probes son **supervisados**, no políticas PPO entrenadas con reward. E3D acota la utilidad del contexto temporal EMG bajo supervisión conjunta de intención y acción; no mide directamente lo que haría un PPO recurrente.
- Sólo tres sujetos en VALIDATION (JOE, JONATHAN, KHAROL). La conclusión sobre generalización entre sujetos, aunque consistente, se apoya en una muestra pequeña.
- La referencia física sigue **no validada** (`REFERENCE_CONTRACT_VALIDATED = NO`). Todas las métricas de seguimiento son relativas al teacher reconstruido, no a una referencia física verificada.
- Oracle-action es diagnóstico secundario, sin gate: no debe usarse para sostener ni refutar conclusiones.
- No se ha ejecutado una corrida limpia extremo-a-extremo de la batería completa con el launcher ya corregido (§12.2).

## 14. Decisión final

```
E3D_RESULT                                   = TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED
TEMPORAL_EMG_CONTEXT_SUPPORTED               = NO
E3E_PREPARATION                              = NO
E3E_LONG_TRAINING_STARTED                    = NO
RECURRENT_FACTORIZED_CATEGORICAL_PPO_PREPARED= NO
RECURRENT_RL_TRAINING_STARTED                = NO
MATEO_SANDRA_SEALED                          = YES
REFERENCE_CONTRACT_VALIDATED                 = NO
HARDWARE_AUTHORIZED                          = NO
GIT_REPAIR_ATTEMPTED                         = NO
PUSH                                         = NO
```
No se prepara E3E pese a que dos de los tres gates de intención pasan. No se redefine ningún gate. No se lanza ninguna variante automática.

## 15. Siguiente dirección científica propuesta (no implementada)

Evidencia acumulada que debe pesar en la decisión: el Oracle demuestra que el MDP admite una buena política; TD3 aprende pero satura y generaliza mal; el PPO categórico mejora estabilidad, acciones y cierre; E3B falla principalmente en apertura y generalización; E3C y E3D muestran señal temporal de dirección y fase; esa señal no se traduce en mejor control global; E1–E1D ya habían mostrado la limitación de la información continua de EMG; y la referencia física sigue sin validar.

**Cuello de botella identificado: (C) adaptación a sujeto / generalización, con (A) representación y normalización EMG como causa mecánica inmediata.**

El argumento no es de descarte, sino positivo y medido en E3D: la rama temporal alcanza 0.992132 de macro-F1 en dirección sobre TRAIN y **mejora** la apertura en TRAIN, mientras que sobre VALIDATION cae a 0.856371 y **empeora** la apertura. La capacidad existe y la información temporal existe; lo que no transfiere es de un sujeto a otro. Más pasos de entrenamiento no corrigen esto —E3B ya mostró que 1M empeora respecto a 500k—, y más memoria tampoco, porque la memoria es justamente lo que amplía la brecha TRAIN→VALIDATION.

**Hipótesis recomendada para E3E (a preregistrar antes de tocar código):** que la brecha de apertura de E3B se deba principalmente a que `WMoos40` no está normalizado por sujeto, de modo que la escala de activación de cada sujeto se confunde con la intención. La prueba sería una ablación de normalización por sujeto —estadísticos calculados **sólo** sobre reposo/inicio de episodio, sin usar datos de VALIDATION— evaluada con la misma receta supervisada y los mismos gates de control, comparando explícitamente la brecha TRAIN→VALIDATION de apertura entre la representación actual y la normalizada.

Antes de eso conviene descartar (B): cuantificar cuántas muestras de reposo y de apertura hay realmente por sujeto en el split actual, ya que la apertura es sistemáticamente la fase peor resuelta en todas las etapas. Si la cobertura de apertura resultara insuficiente, el problema sería de datos y no de representación, y la hipótesis anterior quedaría mal planteada.

Se propone; **no se implementa, no se preregistra y no se ejecuta** en esta sesión.

---
*Documento generado en el cierre de E3D. Sin entrenamiento RL, sin preparación de E3E, sin commit y sin push.*