# ETAPA 3 — Estado `intentMarkov60`

Fecha de cierre: 2026-08-25

## 1. Resultado de la etapa

`PASS` en pruebas deterministas y smoke de episodio completo con simulador.

Se añadió la observación causal:

```text
s60 = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4), q_ref(4), v_ref(4)]
```

No se cambió el reward, la interfaz `baselineQuantized`, el simulador ni el
significado de los estados históricos. No se cargó ni entrenó un agente.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Padre de ETAPA 3 / commit de ETAPA 2:
  `49883962765a25bd27d111b4f6eb4625d893e41c`.
- El SHA actual de ETAPA 3 es el commit que contiene este documento. Se resuelve
  mediante `git rev-parse HEAD` y el launcher post-commit lo registra. El único
  estado dirty esperado es el ZIP local ajeno documentado abajo; no se inserta el
  SHA del propio commit dentro de su contenido.

Agent7250 continúa congelado. No se usó como checkpoint ni como punto de partida
de la nueva política.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/state/buildObservationLayout.m`
- `matlab_code/src/@Env/advanceIntentReference.m`
- `matlab_code/src/runtime/buildNoGloveStage3Override.m`
- `matlab_code/tests/no_glove/testIntentMarkov60.m`
- `matlab_code/workflows/published/run_no_glove_stage3_state_validation.m`
- `docs/no_glove_experiment/03_intent_markov60.md`

### Modificados

- `matlab_code/config/configurables.m`
- `matlab_code/src/@Env/Env.m`
- `matlab_code/src/@Env/reset.m`
- `matlab_code/src/@Env/step.m`
- `matlab_code/src/@Env/calculateState.m`
- `matlab_code/src/@Env/defineObservationInfo.m`
- `matlab_code/src/@Env/updateEmgFeatureHistory.m`
- `matlab_code/src/@Env/saveEpisode.m`
- `matlab_code/workflows/published/README.md`

El archivo local no relacionado `EMG_Prosthesis_TD3/matlab_code.zip` no forma
parte de la etapa y se preservó sin añadirlo al commit.

## 4. Decisiones técnicas y justificación

### Contrato de índices explícito

`buildObservationLayout` define y prueba los índices en vez de inferir su
semántica únicamente por longitud:

| Variante | Dimensión | Orden |
|---|---:|---|
| `legacy44` | 44 | `phi(40), q(4)` |
| `markov52` | 52 | `phi(40), q(4), Deltaq(4), u_eff,t-1(4)` |
| `stackedEmg132` | 132 | `phi_history(120), q(4), Deltaq(4), u_eff,t-1(4)` |
| `intentMarkov60` | 60 | `phi(40), q(4), Deltaq(4), u_eff,t-1(4), q_ref(4), v_ref(4)` |

Los checkpoints históricos que solo contienen `stateLength` conservan inferencia
44/52/132. Una combinación explícita variante/longitud inconsistente falla.

### Inicialización y memoria visible

En `reset`, `q_ref` se copia exactamente del encoder normalizado, `v_ref=0` y la
histéresis parte de un estado canónico inactivo. Así no existe salto integrado
antes de la primera observación. Después, `q_ref` y la velocidad mecánicamente
aplicada quedan visibles en el estado 60.

### Alineación temporal

`state_t` se registra antes de `action_t`. La recompensa de esa transición usa
exactamente el `q_ref,t` de los índices 53:56. Solo después de validar reward y
sus métricas, la EMG recién leída actualiza histéresis, `v_ref,t+1`, `q_ref,t+1`
y la observación devuelta. Por tanto una EMG disponible únicamente en `t+1` no
puede modificar retroactivamente la recompensa de `action_t`.

La ruta `glove` conserva el orden histórico. El decoder solo puede activarse con
`referenceSource="emgIntent"`, calibración compatible e `intentMarkov60`.

### Perfil experimental

`buildNoGloveStage3Override` fija datos pregrabados, `simMotors=true`,
`connect_glove=false`, `run_training=false`, `baselineQuantized` y el reward de
ETAPA 1. La calibración sintética de ETAPA 2 se valida nuevamente y su `DeltaT`
debe coincidir con el período del entorno.

## 5. Comandos/pruebas ejecutados y resultados exactos

Pruebas específicas:

```matlab
runtests(fullfile(pwd,'tests','no_glove','testIntentMarkov60.m'))
```

Resultado: `7/7 PASS`, 0 fallos, 0 incompletas. Incluye persistencia y
recarga del contrato de estado en el MAT de episodio.

Regresión consolidada:

```matlab
runtests(fullfile(pwd,'tests','no_glove'),'IncludeSubfolders',true)
```

Resultado: `21/21 PASS`, 0 fallos, 0 incompletas. Incluye ETAPA 1, ETAPA 2,
ruta glove, EMG-only y los estados 44/52/60/132.

Regresión congelada de Agent7250:

```matlab
opts = struct( ...
    'resultsRoot','<ruta-de-salida>', ...
    'overridePatch',struct('randomSeed',11));
runCheckpointTest(getAgent7250CheckpointPath(),50,false,opts)
```

Resultado: 50/50 episodios. La comparación exacta con el artefacto de ETAPA 1
sobre 14 variables legacy por episodio produjo `GLOVE_CORE_MISMATCHES=0`.
Métricas idénticas: 16.04 pasos medios, MSE `0.040798954456`, MAE
`0.158924490463`, `actionL2=0.614399597474`, saturación `0.396016899767`,
`deltaActionL2=0.245806200412` y PWM absoluto medio `182.263563519814`.

Smoke reproducible:

```matlab
run_no_glove_stage3_state_validation(struct( ...
    'seed',11, ...
    'resultsRoot','<ruta-de-salida>'))
```

Resultado: `PASS`, 61 pasos, episodio terminado por agotamiento de EMG
pregrabada, sin entrenamiento.

`checkcode` dio 0 mensajes en los archivos nuevos de ETAPA 3. Al incluir los
archivos históricos completos `configurables.m` y `Env.m` aparecen dos avisos
preexistentes ajenos a los bloques modificados: una condición duplicada y el
callback heredado con argumento no usado. `git diff --check` terminó sin errores.

## 6. Métricas y artefactos generados

Métricas del smoke seed 11:

| Métrica | Resultado |
|---|---:|
| `episodeSteps` | 61 |
| `stateLength` | 60 |
| `finiteFraction` | 1 |
| error inicial `q_ref`/encoder | 0 |
| desalineación máxima estado/reward | 0 |
| residuo máximo `q_ref,t+1-q_ref,t-DeltaT*v_ref,t+1` | 0 |
| desalineación máxima de `u_eff,t-1` | 0 |
| violaciones de velocidad | 0 |
| violaciones de aceleración | 0 |
| violaciones de posición | 0 |
| violaciones de límites del estado | 0 |
| movimiento máximo de referencia | 0.18302 |
| fracción de rewards finitas | 1 |

La regresión Agent7250 se reporta solo como verificación de no cambio de la ruta
glove. Sus métricas no se comparan con el target de intención.

El launcher guarda:

- `manifest.json` y `manifest.mat`
- `effective_profile.mat`
- `intent_calibration.mat`
- `state_trace.csv`
- `stage3_results.mat`
- `test_results.mat`
- `artifact_hashes.csv`
- `offline_report.md`
- `reproducible_command.txt`

El manifiesto post-commit registra SHA, estado dirty, MATLAB, seed, checksum de
calibración, orden del estado, configuración efectiva, hashes y ruta de salida.

## 7. Riesgos, supuestos y cuestiones no resueltas

- La calibración, `B`, límites y umbrales continúan siendo sintéticos; el PASS no
  demuestra separabilidad sobre EMG humana ni viabilidad física.
- La histéresis tiene memoria interna. ETAPA 3 hace visible la memoria integrada
  `q_ref`, pero no añade sus contadores al estado 60 definido canónicamente.
- El primer estado comienza con `q_ref=encoder` y `v_ref=0`; esta condición de
  arranque segura introduce una ventana de inicialización antes del movimiento.
- La ruta calibrada exige exactamente una ventana EMG completa por transición.
  Buffering de lecturas parciales reales queda pendiente para shadow mode.
- Se preservó el reward anterior; su sustitución causal pertenece a ETAPA 4.
- No se midió retardo, no se introdujo DTW y no se entrenó TD3.
- La evaluación Agent7250 usa target de guante y no se equipara con métricas de
  intención.

## 8. Confirmación explícita de que no se usó hardware

Confirmación: no se abrió ningún puerto COM, no se conectó Myo o guante real, no
se emitió PWM físico y no se midió corriente. Todas las construcciones de `Env`
usaron `RecordedMyo` y `SimController` con `simMotors=true`. El manifiesto registra
`hardwareUsed=false`, `simulatorUsed=true` y `reinforcementLearningUsed=false`.

## 9. Commit de la etapa

Commit autorizado por `continuar etapa 3`.

Mensaje previsto: `feat: add intentMarkov60 observation`.

No se hizo push ni se abrió PR. El SHA exacto se informa tras crear el commit y
repetir launcher y regresión desde el commit. Los archivos versionados quedan sin
diferencias; el ZIP local ajeno permanece sin seguimiento y se reporta aparte.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

ETAPA 4 debe implementar `trackingIntentActionRateReward.m` con los términos
causales de posición, velocidad, acción, tasa de acción y saturación suave;
completar `rewardInfo`; verificar manualmente tracking perfecto, error, reposo,
cambio brusco, saturación y motores individuales; conservar
`baselineQuantized`; y ejecutar un smoke completo. No debe cambiar estado,
target, cuantización ni simulador en esa ablación.

No se ejecutó ninguna parte de ETAPA 4.
