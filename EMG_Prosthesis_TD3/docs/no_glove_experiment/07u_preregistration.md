# ETAPA 7U — preinscripción de la ablación mínima `motionPermission`

Fecha: 2026-09-02. Depende de ETAPA 7T cerrada
(`broadSyntheticGateStressConsequence`, recomendación
`preregisterSingleFactorGateAggregationAblation`).

## 1. Hipótesis

ETAPA 7T mostró que, en `firstStep` (home/límite calibrado, `Δq=0`,
`u_eff,t-1=0`, `v_ref=0`, demanda de control cero verificada), el actor
Agent200 comanda PWM no nulo en 7/7 canales dominantes y 4/4 motores, con
intervenciones de seguridad ya en el primer paso. Las etapas 7F-7O ya
descartaron: penalización `w_u`, umbral global único, penalización de hold,
latch geométrico, estado 62 con bits `declaredRest`/`holdLatch` observados
por el actor, y contrafactuales de esos bits — ninguno cambia de forma
robusta la salida cruda del actor.

Hipótesis 7U: el problema no es que el actor carezca de información sobre
la intención (7M-7O demostraron que sí la recibe cuando se le da como
entrada, y aun así no la usa de forma confiable) — es que se le exige
aprender simultáneamente "si debe moverse" y "cuánto". Separar ambas
decisiones con un permiso EXTERNO al actor (no observado, no aprendido, no
parte del reward) debería suprimir el PWM no solicitado sin necesidad de
reentrenar ni modificar el actor.

## 2. Diseño: reutilización de una señal ya validada

`motionPermission` no es un detector nuevo. Es el bit `gateActive` que ya
calcula `mapEmgToIntentVelocity.m` en cada transición (histéresis
`thetaOn=0.14` / `thetaOff=0.06`, confirmaciones `nOn`/`nOff`, ya validado
causalmente en 7K/7L y expuesto sin éxito conductual al actor en 7M-7O). La
diferencia con 7M-7O es dónde actúa: antes se OBSERVABA; ahora se APLICA
externamente, entre la salida cruda del actor y la cuantización:

```text
u_actor_raw --(actor congelado, sin cambios)--> 
permission = gateActive_t (misma señal causal que ya congela q_ref/v_ref) -->
u_requested = permission * u_actor_raw -->
remapActionForActuator (cuantización, sin cambios) -->
PWM -->
limitSimulationPosition (seguridad, sin cambios, conserva autoridad final)
```

Justificación de por qué debería funcionar donde 7M-7O no: `updateIntentReference.m`
fuerza `q_ref`/`v_ref` congelados exactamente cuando `restMask=~gateActive`.
Es decir, `gateActive=false` ya es condición NECESARIA para que exista
demanda de movimiento en la referencia. Aplicar el mismo booleano al actor
no puede, por construcción, suprimir un movimiento que la referencia esté
pidiendo: cuando la referencia pide movimiento, `gateActive=true` y
`permission=1`, y `u_requested=u_actor_raw` sin cambio alguno.

Justificación bibliográfica breve (investigación completa en el informe
final, no se repite aquí): histéresis de dos umbrales para permitir/inhibir
movimiento es la práctica establecida en control mioeléctrico clásico
(Bottomley 1963) y en control conmutado (evita chattering/Zeno de un umbral
único); la separación intención/control proporcional tiene precedente
directo en prótesis mioeléctricas (Scheme & Englehart 2011); shielding/CBF
en RL seguro actúan de forma análoga pero sobre magnitud/dinámica, no sobre
"si debe existir" acción — de ahí que el permiso deba ser una capa distinta
de `safety`, no una extensión de ella.

## 3. Qué permanece congelado

Actor (Agent200, nunca se recarga con pesos nuevos ni se reentrena), decoder,
estado (60 dims, sin bits nuevos), reward, dataset (se reutilizan corpus ya
existentes, ninguno nuevo), planta/simulador, safety, cuantización, gate
(`thetaOn/thetaOff/nOn/nOff` sin cambios). El único factor manipulado es la
inserción del gate de permiso entre `u_actor_raw` y la cuantización.

## 4. Método: contrafactual offline exacto, sin recargar el actor ni el `Env`

No se reentrena ni se reejecuta el simulador. Se reutilizan registros reales
ya guardados por `Env.saveEpisode` (`rawActionLog`, `effectiveActionLog`/
`actionSatLog`, `appliedPwmLog`, `intentProvenanceLog` con `gateActive` por
paso, `rewardInfoLog`, `positionSafetyInterventionLog`). Dos cohortes:

**Cohorte de reposo (primaria, exacta).** Los 80 episodios congelados de
ETAPA 7S (`stage7s_prospective_declared_rest`, ya usados y validados por
hash en 7T). Se verificará empíricamente (no se asumirá) que
`gateActive=false` en el 100% de los 1600 pasos — el diseño de 7S fija
`targetActivity=0.13<thetaOn=0.14` exactamente para esto. Si `gateActive`
fuera verdadero en algún paso, ese hallazgo se reportará y detendría la
cohorte primaria (fallo cerrado). Cuando `gateActive=false` en todo el
episodio, `u_requested=0` en todo el episodio: la posición nunca se mueve
del punto inicial certificado en 7T (límite inferior o equilibrio superior),
por lo que `limitSimulationPosition` no puede intervenir — cero
intervenciones de seguridad se sigue por construcción, no se re-simula.

**Cohorte de movimiento (validación de preservación).** 50 episodios reales
de evaluación de aceptación de Agent200 (`checkpoint_evaluations/control60/
episode_200/acceptance` de la corrida `stage7n_corrected_final/
2026-08-29_07-34-46-814`, checkpoint episodio 200 = Agent200, coincide con
el actor evaluado en 7T/7C/7O). Aquí `gateActive` alterna dentro de cada
episodio. Se reportan dos resultados distintos y no se confunden:

1. **Exacto:** fracción de pasos con demanda de referencia activa
   (`v_ref≠0` o `q_ref` cambia) donde `gateActive=false` — debe ser
   exactamente 0 por construcción; se verifica, no se asume. Esto acota la
   tasa de inhibición falsa y la latencia adicional de activación en
   exactamente cero, porque en los pasos con `gateActive=true`,
   `permission=1` y `u_requested=u_actor_raw` sin cambio, luego
   `trackingMse`/`actionL2`/`PWM` en esos pasos son idénticos al baseline
   por construcción — no se recalculan.
2. **Descriptivo, con límite explícito:** para los pasos con
   `gateActive=false` DENTRO de episodios de movimiento, se reporta cuánto
   PWM/acción efectiva ya emite el baseline (mismo fenómeno que la cohorte
   de reposo, ahora dentro de un episodio activo) y cuánto suprimiría el
   permiso. El efecto de esa supresión sobre el `trackingMse` de los pasos
   POSTERIORES de ese mismo episodio NO se recalcula (requeriría
   resimulación en lazo cerrado con el actor recargado) y se reporta como
   límite conocido del método, no como resultado.

## 5. Métricas

Reposo: `restPWMNonZeroFraction`, `firstStepUnsolicitedPWMFraction`,
`actionL2(u_raw)` (sin cambio, prueba de que el actor sigue siendo
patológico), `actionL2`/`deltaActionL2` de la acción efectiva, saturación,
intervenciones de seguridad — por motor, baseline vs `motionPermission`.

Movimiento: fracción de inhibición falsa (exacta), `trackingMse`/`trackingMae`
durante ventanas activas (idénticas por construcción), PWM/acción efectiva
suprimida durante ventanas de reposo intra-episodio (descriptivo).

## 6. Criterio de éxito

`IMPROVEMENT_VALIDATED=YES` si: (a) la cohorte de reposo primaria muestra
`restPWMNonZeroFraction` y `firstStepUnsolicitedPWMFraction` reducidas a
exactamente 0 sin excepción, y (b) la cohorte de movimiento muestra 0
pasos de inhibición falsa exacta. `PARTIAL` si (a) se cumple pero persiste
alguna duda razonable sobre (b) que requiera resimulación en lazo cerrado
para resolver. `NO` si `gateActive` resulta verdadero en la cohorte de
reposo (contradice el diseño de 7S) o si se detecta inhibición falsa real
en la cohorte de movimiento.

## 7. Prohibiciones

No se reentrena TD3, no se modifica el actor, no se cambian reward, gate,
cuantización, estado, safety, simulador ni dataset. No se hace push sin
autorización explícita. No se declara mejora si `u_actor_raw` deja de
reportarse o dejase de ser patológico solo porque el PWM efectivo bajó.
