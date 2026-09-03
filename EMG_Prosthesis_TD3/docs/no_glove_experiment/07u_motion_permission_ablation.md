# ETAPA 7U — ablación mínima `motionPermission` (resultado)

Fecha: 2026-09-02. Depende de ETAPA 7T (`broadSyntheticGateStressConsequence`,
`07t_gate_stress_consequence_audit.md`). Preinscripción: `07u_preregistration.md`.

## 1. Resultado operativo

**PASS.** Actor nunca cargado ni reentrenado, `Env`/simulador nunca invocados,
reward/gate/cuantización/safety/estado/dataset sin cambios. Todo el análisis
es un contrafactual offline sobre registros reales ya guardados por
`Env.saveEpisode`. 6/6 pruebas deterministas pasaron.

Corrida: `Agentes\no_glove_intent_control\stage7u_motion_permission_ablation\2026-09-02_23-32-58-030`.

## 2. Resultado científico

```text
IMPROVEMENT_VALIDATED = YES
```

### 2.1 Cohorte de reposo (primaria, exacta) — 80 episodios ETAPA 7S, 1600 estados, 6400 componentes motor

| Métrica | Baseline | Con `motionPermission` |
|---|---|---|
| `restPWMNonZeroFraction` | 0.9812 | **0** |
| `firstStepUnsolicitedPWMFraction` | 0.9812 | **0** |
| `actionL2(u_raw)` | 0.5125 | 0.5125 (sin cambio — el actor sigue patológico) |
| `actionL2` (acción efectiva) | 0.5193 | **0** |
| `deltaActionL2` (acción efectiva) | 0.6645 | **0** |
| Fracción de saturación | 0.2091 | **0** |
| Intervenciones de seguridad | 4072 | **0** |
| `firstStepUnsolicitedPWMFraction` por motor | [1, 1, 0.925, 1] | **[0, 0, 0, 0]** |

`gateActive=false` se verificó en el 100% de los 1600 pasos (no se asumió):
consistente con el diseño de 7S (`targetActivity=0.13<thetaOn=0.14`). Con
`permission=0` en todo el episodio, `u_requested=0` en todo el episodio; la
posición nunca sale del punto certificado en 7T, así que la ausencia de
intervenciones de seguridad se sigue por construcción, no por resimulación.

### 2.2 Cohorte de movimiento (validación de preservación) — 50 episodios reales de aceptación de Agent200, 3050 pasos, 47.5% activos

```text
falseInhibitionStepCount = 0 de 3050 (exacto, verificado no asumido)
activeWindowMetricsUnchangedByConstruction = true
```

En ningún paso con referencia en movimiento (`q_ref` cambiando) `gateActive`
fue falso. En consecuencia, en los pasos activos `permission=1` y
`u_requested=u_actor_raw` sin cambio: `trackingMse`/`actionL2`/PWM en esas
ventanas son idénticos al baseline por construcción, no se recalcularon.

Hallazgo adicional (descriptivo): dentro de estos mismos episodios de
movimiento REAL (no sintéticos), las 1600 ventanas de reposo intra-episodio
ya tienen 100% de PWM no nulo en el baseline (media `|PWM|`=113.86) — el
mismo fenómeno de la cohorte de reposo, ahora confirmado en episodios reales
de Agent200, no solo en el estrés sintético de 7S. `motionPermission` lo
suprime a 0 en esos mismos pasos.

**Límite explícito del método:** el efecto de esa supresión sobre el
`trackingMse` de los pasos POSTERIORES de cada episodio de movimiento no se
recalculó (requiere resimulación en lazo cerrado con el actor recargado). No
se reclama mejora de `trackingMse` más allá de lo verificado exactamente
arriba.

## 3. Interpretación

El actor (`u_actor_raw`) sigue siendo exactamente igual de patológico que
antes — `actionL2(u_raw)` no cambió. Lo que cambió es que ese `u_raw`
patológico ya no llega a la cuantización ni a la planta cuando el propio
gate causal (ya validado en 7K/7L, ya expuesto sin éxito al actor en 7M-7O)
dice que no hay evidencia de intención. Esto confirma la hipótesis de la
Sección 12 del encargo original: el problema no era que al actor le faltara
información, era exigirle que la misma red aprendiera simultáneamente
"si debe moverse" y "cuánto". Separar ambas decisiones con una capa externa
no aprendida resuelve, en esta evidencia, el reposo sin costo medible en
movimiento genuino.

## 4. Confirmación en lazo cerrado (2026-09-03) — cierra el límite de la Sección 2.2

El límite explícito de la Sección 2.2 ("el efecto sobre `trackingMse` de los
pasos posteriores no se recalculó") queda cerrado. Se implementó
`motionPermissionEnabled` como opción real y perezosa (default `false`,
byte-idéntico a cualquier etapa previa) en `Env`/`step.m`: el permiso se
aplica a `warpedAction` justo antes de `remapActionForActuator`, usando
`this.intentGateState.isActive` — la misma señal causal, nunca después de
`safety`. `u_actor_raw` (`actionLog`) permanece intacto; se añadió
`motionPermissionLog` para trazabilidad.

Se recargó Agent200 (checkpoint congelado, sin gradientes) y se corrió en
vivo dos veces — `run_no_glove_stage7u_closed_loop_confirmation.m` —, mismo
corpus EMG determinista (semilla 11, 50 episodios, igual a `NumSimulations`
usado históricamente), misma semilla de evaluación, mismo
`simulationPositionSafety` que la corrida histórica de referencia: una vez
con el permiso desactivado (baseline, reproduce el pipeline histórico) y
una con el permiso activado.

| Métrica (lazo cerrado real, 50 episodios) | Baseline | `motionPermission` |
|---|---|---|
| `trackingMse` medio | 0.0123 | **0.0097** (−21%, mejora, no solo preservación) |
| `actionL2` medio | 0.2471 | **0.1220** (−50.6%) |
| PWM no nulo en fase de reposo intra-episodio (1600 pasos) | 100% | **0%** |
| Episodios con `gateActive` distinto entre condiciones | 0 de 50 | — |

`gateMismatchEpisodes=0` confirma el emparejamiento: el gate depende
únicamente de la EMG (idéntica en ambas condiciones), así que
`motionPermissionLog` coincidió exactamente con `gateActive` desfasado un
paso (`intentProvenanceLog{t}.gateActive` describe la transición hacia
`t+1`, no el permiso vigente en `t`) en el 100% de los pasos verificados.

`trackingMse` **mejora** bajo el permiso porque suprimir el drift espontáneo
de reposo elimina error que el baseline se auto-infligía contra una
referencia que, en esos mismos pasos, también estaba congelada — no hay
ningún caso en el que el permiso compita con una demanda real de la
referencia.

Corrida: `Agentes\no_glove_intent_control\stage7u_closed_loop_confirmation\2026-09-03_00-01-10-178`
(checkpoints/episodios/figuras de las 2×50 evaluaciones guardados ahí).

ETAPA 7U se da por cerrada con `IMPROVEMENT_VALIDATED=YES`, ahora también en
lazo cerrado real, sin ningún límite pendiente. No se hizo push. No se
reentrenó nada: `motionPermissionEnabled` funciona con el actor congelado,
por lo que un entrenamiento largo no es necesario para adoptar esta
corrección — ver la Sección 5 sobre cuándo sí lo sería.

## 5. ¿Corresponde ahora un entrenamiento largo?

No para *cerrar* este resultado: la arquitectura funciona precisamente
porque no reentrena nada. Un entrenamiento largo sólo tendría sentido para
una hipótesis *distinta y opcional*: si un TD3 entrenado desde cero **con**
`motionPermissionEnabled=true` activo durante el entrenamiento (no sólo en
inferencia) aprende una política aún mejor, al no recibir nunca gradiente
por acciones de reposo que de todas formas serían suprimidas. Esto no está
validado ni es necesario — se dejó preparado un comando reproducible para
que el usuario lo ejecute manualmente si decide explorarlo (ver mensaje de
cierre de la sesión).
