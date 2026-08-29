# ETAPA 7N — smoke conductual emparejado 60 frente a 62

Fecha de cierre: 2026-08-29.

## 1. Resultado de la etapa: PASS

La ejecución de ETAPA 7N es **PASS**: se preinscribió el contraste, se crearon
desde cero dos TD3 feedforward, se entrenaron exactamente 200 episodios con seed
11 por variante, se conservaron los ocho checkpoints y se evaluó cada uno con
50 episodios de aceptación y 24 de reposo. No hubo NaN/Inf ni violaciones de
posición.

El resultado científico es **`actionRegularityGateFailed`** y el gate
preinscrito es **FAIL**. Por tanto:

- no se autoriza piloto ni campaña multisemilla;
- no se declara que el estado 62 resuelva el problema de reposo o saturación;
- no se identificó una causa raíz única;
- ETAPA 7N se detiene aquí.

La semántica causal del estado 62 sí pasó: hubo cero mismatches en los bits
61/62 y cero activaciones del latch cuando el reposo declarado comenzó lejos del
target. El fallo científico se debe a regularidad de acción y, adicionalmente, a
reposo y funcionalidad; no a una inconsistencia causal de los bits.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- base canónica de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- HEAD antes de ETAPA 7N:
  `5a39bed0eceec16691bc9ed007e9a6d6b0a0dc36`;
- preinscripción:
  `b103a4578d3c200a586d6368b22a5fafc3c616eb`;
- implementación inicial:
  `78186a15f0a6a62854f1099f21a2a127df60dc10`;
- normalización de resultados directos/reanudados:
  `45012ccf2ca28a986fc142a2b48f276845cc242f`;
- corrección del gate para respetar la recurrencia 7M:
  `c2d9f54811b05550c1bf2fbd52aafcd5a081e3dc`.

El manifiesto canónico fue producido con `gitCommit=c2d9f548...`,
`gitTrackedDirty=false`. `gitDirty=true` se explica exclusivamente por el archivo
local ajeno y no seguido `matlab_code.zip`, que se preservó sin modificar.

## 3. Archivos creados y modificados

Creados:

- `docs/no_glove_experiment/07n_preregistration.md`;
- `docs/no_glove_experiment/07n_state_ablation.md`;
- `matlab_code/src/evaluation/summarizeNoGloveStage7nEpisodes.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7nStateAblation.m`;
- `matlab_code/workflows/published/run_no_glove_stage7n_state_ablation.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7nStateAblation.m`.

Modificados:

- `matlab_code/agents/agentNoGloveIntentTd3.m`;
- `matlab_code/src/runtime/buildNoGloveStage6Override.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage6Evaluation.m`;
- `matlab_code/workflows/published/run_no_glove_stage6_training.m`.

Los cambios genéricos conservan `intentMarkov60` como default. La variante 62
solo se selecciona mediante override explícito. No se modificó `main`, el
simulador, la cuantización, el target, la reward ni Agent7250.

## 4. Decisiones técnicas y justificación

### Contraste causal

El único factor intervenido fue la observación:

```text
s60 = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4), q_ref(4), v_ref(4)]

s62 = [s60, declaredRest_t, holdLatch_t]
```

`declaredRest_t` ocupa el índice 61 y `holdLatch_t` el 62. El latch usa:

```text
near_t = mean((q_t - q_ref,t).^2) <= 1e-4

L_t = 0                              si declaredRest_t = 0
L_t = 1                              si declaredRest_t = 1 y near_t = 1
L_t = L_t-1                          si declaredRest_t = 1 y near_t = 0
```

La última línea es importante: si el latch se activó cerca del target, permanece
activo durante el reposo declarado aunque después la posición derive. Por ello se
separaron dos métricas:

- `farStartedLatchCount`: activación al **comenzar** reposo lejos; es un fallo;
- `holdLatchFarFromTargetCount`: latch previamente activo que persiste lejos; es
  informativo y permitido por la recurrencia 7M.

Una primera versión del análisis agrupó ambos casos y clasificó erróneamente un
`state62SemanticFailure`. Se corrigió antes del cierre, se añadió una prueba
determinista de persistencia y se repitió la evaluación desde los mismos
checkpoints. No se reentrenó.

### Variables mantenidas constantes

Ambas políticas usaron:

```text
referenceSource                 = emgIntent
rewardType                      = trackingIntentActionRateReward
w_q, w_v, w_u, w_du, w_sat      = 1, 0, 0.05, 0.05, 0.02
u_soft                          = 0.90
actionInterfaceVariant          = baselineQuantized
actor/critics                   = feedforward
training seed                   = 11
evaluation seed                 = 7601
episodes                        = 200
checkpoint cadence              = 50
simulationPositionSafety        = enabled
simMotors                       = true
```

La reward fue:

```text
r_t = -[
    mean(e_q,t.^2)
  + 0.05 mean(u_eff,t.^2)
  + 0.05 mean((u_eff,t-u_eff,t-1).^2)
  + 0.02 mean(max(0, abs(u_eff,t)-0.90).^2)
]
```

Se mantuvo `w_v=0`; `velocityMSE` se midió, pero no modificó la reward. No se usó
DTW.

### Inicialización

Las dos redes usaron el mismo generador, seed y arquitectura. No se afirmó
identidad de tensores entre variantes porque la capa de entrada cambia de 60 a
62 valores. El actor control tuvo 8 324 parámetros y el candidato 8 452: los 128
parámetros adicionales corresponden a dos entradas por 64 unidades ocultas.

La reconstrucción con seed 11 fue exactamente reproducible dentro de cada
variante:

```text
control actor SHA-256   E169E901BE9A04647CB1DD079ED9DF71580554DD2C6CE56140BBEE231A11C0C4
candidate actor SHA-256 E579B6C7421F6F0A7B251ECAAD2ACA19B2CC476A99B48250413B69FB2DAEE099
```

### Reanudación sin reentrenamiento

El ensamblado inicial terminó las dos corridas y las 16 simulaciones de
evaluación, pero falló al leer `seedResults`: la ejecución directa entregaba un
`struct` y la carga desde disco una celda. Se normalizaron ambos contratos. Las
dos corridas completas se reutilizaron por ruta y hash; no se reanudó aprendizaje
desde un checkpoint ni se creó otra política.

## 5. Comandos/pruebas ejecutados y resultados exactos

Pruebas dirigidas y análisis estático antes de entrenar:

```text
checkcode de 8 archivos                  0 issues
testNoGloveStage6Training                8/8 PASS
testIntentDeclaredRestHoldMarkov62      10/10 PASS
testNoGloveStage7nStateAblation          5/5 PASS
total dirigido                          23/23 PASS
```

Regresión completa antes y después del resultado final:

```text
runtests(matlab_code/tests/no_glove, IncludeSubfolders=true)
total=171, passed=171, failed=0, incomplete=0
```

Launcher de entrenamiento, ejecutado una sola vez para crear cada política:

```matlab
run_no_glove_stage7n_state_ablation(struct( ...
    'resultsRoot', ...
    'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_final'))
```

Reanudación final, sin entrenamiento:

```matlab
run_no_glove_stage7n_state_ablation(struct( ...
    'resultsRoot', ...
    'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_corrected_final', ...
    'completedControlRunRoot', '<run control60 completo>', ...
    'completedCandidateRunRoot', '<run candidate62 completo>'))
```

Resultado exacto del launcher:

```text
ETAPA 7N STATE ABLATION PASS
Scientific result: actionRegularityGateFailed
Scientific gate passed: 0
```

La reproducción offline volvió a ejecutar
`analyzeNoGloveStage7nStateAblation` sobre el MAT publicado:

```text
classification=actionRegularityGateFailed
gate=0
checks=17
match=1
```

## 6. Métricas y artefactos generados

### Evolución completa de checkpoints

Cada fila usa 50 episodios de aceptación. Reposo usa 24 episodios adicionales.
`M2 flags` y `otros flags` son conteos funcionales, no corriente medida.

| Estado | Episodio | MSE | MAE | actionL2 | deltaActionL2 | Saturación | Rest windows con PWM | Rest sat. | M2 flags | Otros flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 60 | 50  | 0.097143901 | 0.204083969 | 0.401309703 | 0.613917908 | 0.202131148 | 1.000 | 0 | 0 | 75 |
| 60 | 100 | 0.036548264 | 0.124756165 | 0.243984543 | 0.277836504 | 0.061475410 | 1.000 | 0 | 25 | 100 |
| 60 | 150 | 0.013327485 | 0.083055551 | 0.247184127 | 0.083492523 | 0.040983607 | 1.000 | 0 | 25 | 100 |
| 60 | 200 | 0.012314755 | 0.080405373 | 0.247026334 | 0.068113310 | 0.020491803 | 1.000 | 0 | 25 | 100 |
| 62 | 50  | 0.095543922 | 0.214892109 | 0.190093244 | 0.224191772 | 0.084016393 | 1.000 | 0 | 50 | 25 |
| 62 | 100 | 0.080811899 | 0.196226271 | 0.284701929 | 0.310376214 | 0.081967213 | 1.000 | 0 | 0 | 150 |
| 62 | 150 | 0.011926713 | 0.080716706 | 0.224699015 | 0.060723517 | 0.000327869 | 1.000 | 0 | 0 | 100 |
| 62 | 200 | 0.006861768 | 0.065307255 | 0.301699667 | 0.037137737 | 0.111311475 | 1.000 | 0.125 | 25 | 100 |

La saturación mantiene su definición canónica: fracción de componentes
motor-paso con `abs(effectiveAction)>=0.95`; no significa que los cuatro motores
estuvieran simultáneamente al máximo.

### Checkpoint primario preseleccionado: episodio 200

| Métrica | Control 60 | Candidato 62 | Ratio 62/60 | Gate |
|---|---:|---:|---:|---|
| trackingMSE | 0.012314755 | 0.006861768 | 0.557199 | PASS |
| actionL2 | 0.247026334 | 0.301699667 | 1.221326 | FAIL, máximo 1.05 |
| deltaActionL2 | 0.068113310 | 0.037137737 | 0.545235 | PASS; además `<0.257108` |
| saturationFraction | 0.020491803 | 0.111311475 | 5.432000 | FAIL relativo; PASS absoluto `<0.196043` |
| ventanas reposo con PWM | 1.000000 | 1.000000 | — | FAIL, máximo 0.01 |
| saturación reposo | 0 | 0.125000 | — | FAIL, debe ser 0 |
| falsa activación decoder | 0 | 0 | — | PASS |

Aunque el MSE del candidato disminuyó 44.28% y `deltaActionL2` 45.48%, la acción
media subió 22.13% y la saturación fue 5.432 veces la del control. Estas
observaciones no prueban que MSE cause saturación.

En candidato 62, checkpoint 200:

```text
declaredRest replay mismatches       0
holdLatch replay mismatches          0
farStarted                           200
farStarted con latch activo          0
activaciones prematuras              0
latch activo lejos tras deriva       470  (informativo, permitido)
PWM en ventanas latch activo         1.0
PWM en ventanas latch inactivo       1.0
PWM en ventanas de reposo            1.0
```

Por tanto, no hay evidencia de que la política aprendiera separación conductual
con los bits en este presupuesto. Es una asociación observada; todavía no es una
ablación contrafactual de entradas.

Por motor en el checkpoint 200, Motor 2 concentró la saturación del candidato:
0.445246 en aceptación y 0.5 en reposo. Esto demuestra comandos guardados, no
corriente eléctrica medida.

Las intervenciones de seguridad acumuladas fueron:

```text
control:   training 22462 + acceptance 5984 + rest 720 = 29166
candidate: training 21494 + acceptance 5689 + rest 720 = 27903
violaciones de posición: 0 en ambos
```

Una intervención de clipping preventivo no equivale a una violación consumada;
se reportan ambas por separado.

### Artefacto canónico

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_corrected_final\2026-08-29_07-34-46-814
```

Archivos principales:

- `manifest.json`, SHA-256
  `082DADB41DAA1DAB6AE2B5E02AE15191479410F10B5DF0398837814BFC53D480`;
- `stage7n_results.mat`, SHA-256
  `CC4431FC27236ABBCE933821FD898E25163EDCD018C0FD25384C1AB15E869D55`;
- `checkpoint_summary.csv`, SHA-256
  `F8276EB81CC895918855C6FE1D339EE210DEEF32BC960BEA8AABB04A89C2E556`;
- `motor_summary.csv`;
- `checkpoint_comparison.csv`;
- `gate_checks.csv`;
- `profile_audit.csv`, `dataset_audit.csv`;
- `initialization_audit.csv`, `initialization_arrays.csv`;
- `run_audit.csv`, `offline_report.md`, `reproducible_command.txt`;
- trazas completas de las 592 evaluaciones de checkpoint.

Los 14 hashes inventariados en el manifiesto se verificaron de nuevo: 14/14
coinciden.

Agent7250 permanece intacto en:

```text
matlab_code/checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat
SHA-256 = 0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

## 7. Riesgos, supuestos y cuestiones no resueltas

1. Solo se usó seed 11 y un máximo de 200 episodios. No puede inferirse una
   distribución multisemilla.
2. Las inicializaciones son reproducibles dentro de cada dimensión, pero no
   tensorialmente idénticas entre 60 y 62.
3. El checkpoint 150 de 62 tuvo mejor regularidad que el 200, pero no puede
   sustituirlo: el episodio 200 fue preseleccionado y se publicaron todos.
4. La política produjo PWM en 100% de ventanas de reposo tanto con latch activo
   como inactivo. La observabilidad por sí sola no resolvió reposo.
5. `holdLatchFarFromTargetCount=470` muestra persistencia después de deriva; es
   coherente con la recurrencia 7M, pero puede ser una semántica poco útil para
   control y requiere diagnóstico separado.
6. Los flags funcionales afectan Motor 2 y M1/M3/M4. No hay autorización para
   ignorarlos ni seleccionar solo motores favorables.
7. La capa de seguridad intervino muchas veces aunque evitó violaciones. Esta
   carga de clipping debe tratarse como señal de dinámica problemática.
8. No se midió corriente ni temperatura y no puede afirmarse que Motor 2 reciba
   corriente.
9. Las 40 features estandarizadas no se interpretaron como amplitudes físicas;
   la intención mantuvo su calibración sobre EMG cruda.
10. No hay evidencia para declarar que MSE, reward, cuantización, simulador o el
    estado 62 sean la causa raíz única de la saturación.

## 8. Confirmación explícita de que no se usó hardware

**No se usó hardware.** En toda ETAPA 7N:

```text
simMotors=true
usePrerecorded=true
connect_glove=false
hardwareUsed=false
PWM físico/COM/Myo real=false
```

Solo se generaron comandos y PWM simulados. No se abrió ningún puerto ni se
activó ningún motor real.

## 9. Commits de la etapa

Commits de código y preinscripción:

```text
b103a457  Preregister Stage 7N state smoke
78186a15  Add Stage 7N matched state smoke
45012ccf  Fix Stage 7N child result normalization
c2d9f548  Align Stage 7N latch gate with recurrence
```

El commit descriptivo que incorpora este informe se registra en el historial de
la misma rama. No se hizo merge a `main`.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

Se propone **ETAPA 7O — auditoría contrafactual offline del uso de bits**, sin
entrenar:

1. congelar Agent200 de control y candidato por sus SHA-256;
2. construir un corpus común de estados 60 y el prefijo de estados 62;
3. evaluar el actor 62 con combinaciones causales `(declaredRest,holdLatch)`
   `(0,0)`, `(1,0)` y `(1,1)`, manteniendo las otras 60 entradas idénticas;
4. medir por motor `Delta action_raw`, cruce de umbral PWM, nivel cuantizado y
   sensibilidad local a los índices 61/62;
5. separar reposo, `farStarted`, latch activo cerca, latch activo tras deriva y
   movimiento intencional;
6. auditar pesos de entrada del actor sin confundir magnitud de peso con
   importancia causal;
7. determinar si los bits fueron ignorados, usados sin margen de cuantización o
   usados de forma adversa, con atención específica a Motor 2;
8. detenerse sin piloto, nueva reward, nuevo estado, DTW ni hardware.

Si 7O demuestra insensibilidad, la siguiente intervención deberá preinscribir un
solo cambio de aprendizaje o arquitectura; no se autoriza aumentar episodios
para buscar retrospectivamente un checkpoint favorable.

**ETAPA 7O no fue ejecutada.**
