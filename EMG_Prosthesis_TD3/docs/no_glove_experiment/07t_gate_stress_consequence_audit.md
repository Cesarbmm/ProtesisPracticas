# ETAPA 7T — auditoría de consecuencias del estrés sintético del gate (resultado)

Fecha: 2026-09-02. Preinscripción: `07t_preregistration.md` (commit `61bb06ee`),
enmendada dos veces antes de la corrida canónica (`07t_preregistration.md`
§9 y §10). Commit del árbol de trabajo en el momento de la corrida:
`1ce5cd6903d8aead5032f10e70bc3dfbab3cc4c7` (árbol sucio: implementación de
7T y esta corrección aún no confirmadas).

## 1. Resultado operativo

**PASS.** Las 27 verificaciones del gate operativo pasan, incluidas las dos
nuevas de la Enmienda 2 (`firstStepMechanicalInvariant`,
`upperEquilibriumConsistent`). 21/21 pruebas deterministas de preflight
pasaron (`testNoGloveStage7tGateStressAudit`,
`testNoGloveStage7sProspectiveRestSupport`). Ningún actor, `Env`, simulador,
entrenamiento ni hardware fue usado; ningún dato de 7S fue modificado.

Corrida: `Agentes\no_glove_intent_control\stage7t_gate_stress_consequence_audit\2026-09-02_23-14-13-854`.

## 2. Corrección aplicada antes de esta corrida (Enmienda 2)

La primera corrida canónica (misma noche) falló `firstStepMechanicalInvariant`
porque los 40 episodios `firstStep` de tipo Opening no llegan al
`positionMax=1` idealizado: se estabilizan de forma exactamente reproducible
(desviación `~2e-16` entre episodios) en
`q=[0.4218, 0.5796, 0.8835, 0.6979]`. La causa es que
`prosthesis_simulator.m` reproduce una curva empírica ajustada cuyo índice se
satura en la longitud de la curva grabada (`fit_C2.mat`); más allá de ese
punto, PWM=255 sostenido no puede mover la posición — es un punto fijo
genuino del simulador, no una foto de una trayectoria en curso.

Se corrigió `analyzeNoGloveStage7tGateStress.m` para derivar el límite
superior desde el propio corpus `firstStep` congelado
(`deriveNoGloveStage7tReachableEndpoints.m`), certificando consistencia
(`upperEquilibriumConsistent`) en vez de asumir `positionMax=1`. No se tocó
ningún dato de 7S, ni `Env.reset`, ni el simulador, ni la calibración global,
ni la seguridad, ni el reward. Detalle completo en
`07t_preregistration.md` §10.

## 3. Resultado científico

```text
scientificResult = broadSyntheticGateStressConsequence
recommendation   = preregisterSingleFactorGateAggregationAblation
```

Regla cumplida (Sección 7 de la preinscripción): en `firstStep`, 7/7 canales
dominantes y 4/4 motores tienen `PWM!=0` en ≥50% de sus componentes, y existen
intervenciones de seguridad (182 de 320 componentes `firstStep`, 4072 en todo
el corpus). Es la categoría más amplia posible de las tres — no hay canal ni
motor que se libre.

### 3.1 Respuesta directa (`firstStep`, n=320 componentes = 80 episodios × 4 motores)

| Métrica | Valor |
|---|---|
| Fracción `PWM≠0` | 0.98125 |
| Fracción saturación (`\|u_eff\|≥0.95`) | 0.20625 |
| Fracción con intervención de seguridad | 0.56875 |
| PWM mínimo no nulo | 64 |
| Media `\|u_raw\|` | 0.660 |
| P95 `\|u_raw\|` | 0.993 |
| `homeAtDecision` (límite inferior) | 0.5 (40/80 episodios) |
| `upperEndpointAtDecision` (equilibrio superior certificado) | 0.5 (40/80 episodios) — suman 1.0: ya no queda ningún estado "interior" |
| `zeroControlDemand` | 1.0 (los 320 componentes) |

Todos estos comandos ocurren con acción efectiva anterior=0, `Δq=0`,
`q_ref=q`, `v_ref=0` y demanda de control cero verificada — es decir, son
comandos simulados no solicitados por la referencia en el sentido estricto
preinscrito. Esto no demuestra reposo fisiológico humano ni que el mismo
efecto ocurra con Myo: el dataset es un estrés sintético diseñado para
excitar los 7 canales dominantes.

### 3.2 Divergencia contextual (`postFirst`)

De 2809 queries con demanda de control cero y candidato EMG válido, sólo 320
(11.4%) encuentran un donante con los cinco bloques de contexto dentro de
`contextMaximum≤0.25`. Esto es consistente con — no nuevo respecto a — el
hallazgo de 7S de que el matching se degrada después del primer paso porque
la trayectoria mecánica diverge por episodio; el diagnóstico de restauración
por bloque queda en `context_block_summary.csv` de la corrida para trabajo
futuro, pero no se interpretará como acción contrafactual del actor (tal como
exige la preinscripción).

## 4. Clasificación

`STAGE_7T = PASS`. `STAGE_7T_CLASSIFICATION = broadSyntheticGateStressConsequence`.

Por la propia regla de decisión de la preinscripción (Sección 7), una
consecuencia amplia recomienda preinscribir una ablación futura de un solo
factor sobre agregación/watchdog del gate, manteniendo todo lo demás
congelado — exactamente la hipótesis `motionPermission` evaluada a
continuación en este mismo ciclo de trabajo (ver
`07u_preregistration.md` / `07u_motion_permission_ablation.md`).

ETAPA 7T se da por cerrada. No se hizo push.
