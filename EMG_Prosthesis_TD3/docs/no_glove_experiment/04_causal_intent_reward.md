# ETAPA 4 — Reward causal de intención sin DTW

Fecha de cierre: 2026-08-25

## 1. Resultado de la etapa

`PASS` en verificación numérica determinista, regresión consolidada, smoke de
episodio EMG-only completo y regresión exacta del benchmark histórico.

Se implementó `trackingIntentActionRateReward` con la forma:

```text
e_q     = q_t - q_ref,t
e_v     = Deltaq_t / DeltaT - v_ref,t
Delta u = u_eff,t - u_eff,t-1

r_t = -[w_q mean(e_q^2) + w_v mean(e_v^2) +
         w_u mean(u_eff,t^2) + w_du mean(Delta u^2) +
         w_sat mean(max(0,abs(u_eff,t)-u_soft)^2)]
```

El primer perfil fija `w_v=0` para aislar esta ablación, pero calcula, registra y
prueba `velocityMse`. No se introdujo DTW. No se cambió el target, el estado
`intentMarkov60`, la cuantización `baselineQuantized` ni el simulador. No se creó
o entrenó ningún agente.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Padre de ETAPA 4 / commit de ETAPA 3:
  `5c497312913f26da1232968a5a228d8a095a970c`.
- El SHA actual de ETAPA 4 es el commit que contiene este documento. El launcher
  post-commit lo registra mediante `git rev-parse HEAD`; no se inserta el SHA del
  propio commit dentro de su contenido.

Agent7250 permanece congelado. Se evaluó para regresión, pero no se reentrenó, no
se sobrescribió y no se usó como inicialización de una política nueva.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/reward_functions/trackingIntentActionRateReward.m`
- `matlab_code/src/runtime/buildNoGloveStage4Override.m`
- `matlab_code/tests/no_glove/testTrackingIntentActionRateReward.m`
- `matlab_code/workflows/published/run_no_glove_stage4_reward_validation.m`
- `docs/no_glove_experiment/04_causal_intent_reward.md`

### Modificados

- `matlab_code/config/configurables.m`
- `matlab_code/src/@Env/Env.m`
- `matlab_code/src/@Env/reset.m`
- `matlab_code/src/@Env/step.m`
- `matlab_code/src/@Env/saveEpisode.m`
- `matlab_code/src/reward_functions/rewardFunctionSelector.m`
- `matlab_code/src/reward_functions/normalizeRewardInfo.m`
- `matlab_code/src/evaluation/summarizeEpisodeDirectory.m`
- `matlab_code/tests/no_glove/testReferenceSources.m`
- `matlab_code/workflows/published/README.md`

El archivo local ajeno `EMG_Prosthesis_TD3/matlab_code.zip` se preservó sin
modificar y no forma parte del commit.

## 4. Decisiones técnicas y justificación

### Límite temporal causal

La acción efectiva de `t` se evalúa contra `q_ref,t` y `v_ref,t`, visibles en
`state_t`. La velocidad observada se calcula con el encoder de la transición y
`prevEncoderNorm`:

```text
v_t = (q_t - q_t-1) / DeltaT
```

El contexto también recibe explícitamente `u_eff,t-1`. La función de reward no
lee memoria mutable de `Env`. Solo después de validar reward y `rewardInfo`, la
EMG recién leída puede avanzar `q_ref,t+1` y construir `state_t+1`. Así no se
penaliza `action_t` con intención disponible únicamente en `t+1`.

### Pesos explícitos del perfil

`buildNoGloveStage4Override` deriva el perfil de ETAPA 3 y cambia solo el tipo de
reward. Registra explícitamente:

| Parámetro | Valor |
|---|---:|
| `w_q` | 1.00 |
| `w_v` | 0.00 |
| `w_u` | 0.01 |
| `w_du` | 0.05 |
| `w_sat` | 0.02 |
| `u_soft` | 0.90 |

`w_v=0` no elimina el diagnóstico de velocidad; evita mezclar ese término en la
primera ablación. Los valores son una configuración inicial auditable, no pesos
declarados óptimos.

### Contrato aditivo de métricas

`rewardInfo` conserva los campos históricos y añade:

- `velocityMse`
- `softSaturationPenalty`
- `referenceSource`

El contrato normalizado queda compuesto por `trackingMse`, `trackingMae`,
`velocityMse`, `actionL2`, `progressTerm`, `smoothnessPenalty`,
`deltaActionL2`, `saturationFraction`, `softSaturationPenalty`,
`saturationPenalty`, `referenceSource` y `schemaVersion`.

`softSaturationPenalty` es el valor crudo medio; `saturationPenalty` conserva el
campo legacy y guarda el término ya ponderado por `w_sat`. Los episodios antiguos
sin los campos nuevos siguen siendo legibles: `velocityMse` se reporta como no
disponible y la penalización suave como cero.

La semántica de `saturationFraction` no se cambió: es la fracción de componentes
motor-paso con `abs(effectiveAction)>=0.95`. No significa que los cuatro motores
permanezcan simultáneamente al máximo.

### Agregador histórico preservado

El reward registra `deltaActionL2 = mean((u_t-u_t-1).^2)` por paso, incluyendo la
transición desde la acción previa inicial. `summarizeEpisodeDirectory` conserva
su cálculo publicado anterior: media temporal de la suma sobre motores de
`diff(actionSatLog)`, sin el primer paso. Por ello ambos números no se equiparan
ni se cambió silenciosamente el lector histórico.

## 5. Comandos/pruebas ejecutados y resultados exactos

Prueba específica:

```matlab
runtests('tests/no_glove/testTrackingIntentActionRateReward.m')
```

Resultado: `7/7 PASS`, 0 fallos, 0 incompletas. Verifica tracking perfecto,
reposo, error, cambio brusco, saturación suave, cada motor individual, término de
velocidad, selector, configuración inválida, persistencia y esquema antiguo.

Regresión consolidada:

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado: `28/28 PASS`, 0 fallos, 0 incompletas. Incluye ETAPAS 1–4, ruta glove,
EMG-only y estados 44/52/60/132.

Smoke reproducible:

```matlab
run_no_glove_stage4_reward_validation(struct( ...
    'seed',11,'maxSteps',20,'resultsRoot','<ruta-de-salida>'))
```

Resultado: `PASS`, 20 pasos, estado 60, episodio terminado por agotamiento del
EMG sintético recortado, 9 casos manuales y residuo máximo entre reward y
reconstrucción de `5.551115123125783e-17`.

Regresión Agent7250:

```matlab
opts = struct('resultsRoot','<ruta-de-salida>', ...
    'overridePatch',struct('randomSeed',11));
runCheckpointTest(getAgent7250CheckpointPath(),50,false,opts)
```

Resultado: 50/50 episodios. La comparación con ETAPA 3 sobre 14 variables legacy
por archivo dio 700 comparaciones y `GLOVE_CORE_MISMATCHES=0`.

Métricas históricas reproducidas: 16.04 pasos medios, MSE
`0.040798954456`, MAE `0.158924490463`, `actionL2=0.614399597474`,
saturación `0.396016899767`, `deltaActionL2` del agregador
`0.245806200412` y PWM absoluto medio `182.263563519814`.

`checkcode` emitió 0 avisos en los archivos MATLAB nuevos de ETAPA 4. Al incluir
`configurables.m` y `Env.m` completos aparecen dos avisos preexistentes fuera de
los bloques modificados: una condición duplicada y un callback heredado con
argumento no usado. `git diff --check` terminó sin errores.

## 6. Métricas y artefactos generados

### Casos manuales

| Caso | Reward esperado | Reward calculado | Residuo absoluto |
|---|---:|---:|---:|
| perfecto | 0 | 0 | 0 |
| reposo | 0 | 0 | 0 |
| error de posición | -0.052500 | -0.052500 | 0 |
| cambio brusco | -0.009375 | -0.009375 | `1.73e-18` |
| saturación | -0.057204 | -0.057204 | 0 |
| Motor 1 | -0.040000 | -0.040000 | 0 |
| Motor 2 | -0.040000 | -0.040000 | 0 |
| Motor 3 | -0.040000 | -0.040000 | 0 |
| Motor 4 | -0.040000 | -0.040000 | 0 |

### Smoke simulado seed 11

| Métrica | Resultado |
|---|---:|
| pasos | 20 |
| `finiteFraction` | 1 |
| `trackingMseMean` | 0.326756896941 |
| `trackingMaeMean` | 0.470038433705 |
| `velocityMseMean` | 1.086731345404 |
| `actionL2Mean` | 0.276574394464 |
| `deltaActionL2StepMean` | 0.614982698962 |
| `saturationFraction` | 0.25 |
| `softSaturationPenaltyMean` | 0.0025 |
| reward de episodio | -7.206435516683 |

Estas cifras corresponden a un patrón artificial de acciones diseñado para
activar cada término. No son rendimiento de una política y no se comparan con el
MSE de guante de Agent7250 como si el target fuera el mismo.

El launcher guarda `manifest.json/.mat`, perfil efectivo, calibración con
checksum, resultados de pruebas, nueve casos manuales CSV, episodio MAT, traza
CSV, resumen, hashes, reporte offline y comando reproducible. La regresión
histórica añade su manifiesto y `legacy_regression_comparison.json/.mat`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- Los pesos son iniciales y no se han sometido a ablación ni optimización.
- `w_v=0`; aunque `velocityMse` está validada y registrada, su efecto conductual
  todavía no se ha probado.
- La diferencia de encoder amplifica ruido; cualquier activación futura de `w_v`
  requiere revisar escala y retardo sin cambiar otras variables a la vez.
- La calibración y los datos del smoke son sintéticos. No demuestran separabilidad
  de EMG humana ni viabilidad física.
- El patrón del smoke fuerza saturación para verificar el término; su fracción
  0.25 no es un resultado de control ni un gate de aceptación de política.
- La recompensa no es una capa de seguridad. Los límites deterministas completos
  pertenecen a una etapa posterior y no deben depender de estos pesos.
- El MSE se conserva como una hipótesis experimental, no como causa raíz única de
  saturación.
- No se midió retardo, no se introdujo DTW y no se entrenó TD3.
- Los logs prueban comandos simulados; no demuestran corriente eléctrica medida,
  en particular para Motor 2.

## 8. Confirmación explícita de que no se usó hardware

Confirmación: no se abrió ningún puerto COM, no se conectó Myo o guante real, no
se emitió PWM físico y no se midió corriente o temperatura. Todos los episodios
usaron datos pregrabados, `SimController`, `simMotors=true` y
`connect_glove=false`. El manifiesto registra `hardwareUsed=false`,
`simulatorUsed=true` y `reinforcementLearningUsed=false`.

## 9. Commit de la etapa

Commit autorizado por `Continuar etapa 4`.

Mensaje previsto: `feat: add causal intent tracking reward`.

No se hizo push ni se abrió PR. Tras crear el commit se repiten launcher,
regresión y comprobación de Agent7250 desde el SHA versionado. El único estado
dirty esperado será el ZIP local ajeno, que no se añadirá al índice.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

ETAPA 5 debe crear un controlador proporcional/PD cuantizado sobre `q_ref` y un
launcher reproducible de diagnóstico de planta. Debe medir escalones y rampas
positivos y negativos por motor desde home y posición intermedia; tiempo muerto,
ganancia, zona muerta, velocidad, saturación y error de `encoder2Flex`; y ejecutar
pruebas específicas de Motor 2 y regresión cruzada de M1/M3/M4. La medición
inicial no debe modificar simulador ni conversión.

No se ejecutó ninguna parte de ETAPA 5.
