# ETAPA 7I - pre-registro del diagnóstico offline de soporte de hold

Fecha de pre-registro: 2026-08-28.

Este documento fija las entradas, métricas, umbrales y clasificación antes de
inspeccionar los valores por ventana de los logs de ETAPA 7H. ETAPA 7I es
estrictamente offline: no entrena, no carga agentes, no crea `Env`, no invoca
simulador ni reward y no cambia conducta.

## Pregunta

ETAPA 7H terminó como `holdExposureInsufficient`: el indicador estuvo activo
en 53.33% de las ventanas de reposo con `epsilon_q2=1e-4`. ETAPA 7I debe
determinar:

1. cuándo se pierde soporte dentro del episodio;
2. si la salida coincide temporalmente con una acción o intervención de
   seguridad precedente;
3. si existe algún umbral de error de posición que cubra al menos 90% del
   reposo sin etiquetar como hold más de 5% de las correcciones lejanas;
4. cuánto peso daría una familia suave fija, únicamente como diagnóstico de
   continuidad.

No se seleccionará una nueva reward o hiperparámetro en esta etapa.

## Entradas congeladas

Manifiesto padre 7H:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_artifacts\
stage7h_final\2026-08-28_16-00-33-357\manifest.json
```

Se cargarán las tres fuentes de control y candidato:

```text
training:   200 episodios por variante
acceptance:  50 episodios por variante
steadyRest:  24 episodios por variante
total:      548 episodios
```

Se exige `emgIntent`, `intentMarkov60`, reward 7H, simulación y ausencia de
hardware. Se inventariarán SHA-256 de episodios, manifiestos, perfiles y
checkpoints antes y después.

## Reconstrucción por ventana

Desde `state_t`:

```text
q_decision,t = state_t(encoder)
q_ref,t      = state_t(referencePosition)
v_ref,t      = state_t(referenceVelocity)

E_hold,t = mean_m((q_decision,t,m-q_ref,t,m)^2)
V_hold,t = max_m |v_ref,t,m|
stopped_t = 1[V_hold,t <= epsilon_v]
I_hold,t  = stopped_t * 1[E_hold,t <= epsilon_q2]
```

Valores originales fijados en 7H:

```text
epsilon_v  = 1e-12
epsilon_q2 = 1e-4
```

Se verificará que la reconstrucción coincide exactamente con
`rewardInfoLog.holdActive`, `holdPositionMse`, `holdVelocityMaxAbs`,
`holdActionL2` y `holdActionPenalty`.

También se conservarán `u_raw`, `u_eff`, PWM y la intervención de seguridad
por motor. No se ejecutará la reward.

## Diagnóstico temporal en reposo

Para cada episodio `steadyRest`:

```text
initialEligible       = I_hold,1
firstExitStep         = primer t con I_hold,t-1=1 e I_hold,t=0
initialMismatch       = 1 si I_hold,1=0
reentryCount          = número de transiciones 0 -> 1
longestEligibleRun    = máxima longitud consecutiva con I_hold=1
eligibleFraction      = mean_t(I_hold,t)
```

Si existe `firstExitStep=t`, la transición se atribuye temporalmente a la
acción y a la intervención de seguridad registradas en `t-1`, porque
`state_t` contiene el encoder posterior a esa transición. Esto es una
alineación temporal, no una afirmación causal suficiente.

Se reportarán PWM precedente, acción efectiva precedente, intervención
precedente, MSE antes/después y salto de MSE. No se afirmará causalidad raíz.

## Definición pre-registrada de corrección lejana

Una ventana con referencia detenida se considera una posible corrección lejana
si:

```text
stopped_t = 1
E_hold,t >= epsilon_far
epsilon_far = 2.5e-3
```

`epsilon_far` corresponde a RMS agregado normalizado de 5%. Se usa como
estrato conservador: no se presume que toda ventana sea una corrección
correctamente comandada.

La curva principal usa `steadyRest` para cobertura y las ventanas
`training+acceptance` con referencia detenida y error lejano para riesgo de
exposición.

## Curva contrafactual exacta

Se evaluarán umbrales candidatos:

```text
{0, 1e-4, 2.5e-3, 1}
U {todos los E_hold observados con stopped=1}
U {valor inmediatamente superior a cada punto observado}
```

Para cada variante y `epsilon`:

```text
restCoverage(epsilon)
  = mean(1[E_hold<=epsilon]) en steadyRest

farCorrectionExposure(epsilon)
  = mean(1[E_hold<=epsilon]) en ventanas stopped de training+acceptance
    con E_hold>=2.5e-3
```

Gate fijado:

```text
restCoverage >= 0.90
farCorrectionExposure <= 0.05
```

No se aplicará ningún `epsilon` a reward, política o entorno.

## Familia suave solo diagnóstica

Se calculará:

```text
g_tau(E) = stopped * exp(-E/tau)
```

para el conjunto fijo:

```text
tau = [1e-4, 5e-4, 1e-3, 2.5e-3]
```

Se reportará la media de `g_tau` en reposo y corrección lejana. Esta familia no
tiene gate, no se optimiza y no se seleccionará una variante en 7I.

## Clasificación pre-registrada

La clasificación usa el candidato 7H:

1. `offlineHoldSupportDomainExists` si algún umbral pasa cobertura y riesgo;
2. `holdSupportNotSeparableFromFarCorrection` si existe umbral con cobertura
   de reposo suficiente pero ninguno pasa ambos límites;
3. `restCoverageUnresolved` si ningún umbral alcanza 90% de reposo.

En todos los casos:

```text
rootCauseIdentified=false
behavioralInterventionExecuted=false
pilotAuthorized=false
```

## Pruebas y condiciones de salida

Se exigirán:

- dimensiones, orden e índices de `intentMarkov60` correctos;
- datos finitos y cuatro motores por ventana;
- reproducción de diagnósticos 7H dentro de tolerancia `1e-12`;
- `q_ref` constante y `v_ref=0` en `steadyRest`;
- alineación del evento de salida con la acción precedente;
- curva exacta independiente de rejilla;
- fallos cerrados ante campos, hashes o perfiles incompatibles;
- resultados reproducibles en una raíz nueva.

## Exclusiones

- No se carga Agent7250 ni Agent200.
- No se evalúa el actor sobre estados.
- No se entrena ni simula.
- No se modifica reward, estado, referencia, cuantización, simulador o
  seguridad.
- No se calcula DTW.
- No se usa hardware, guante, Myo real, COM ni PWM físico.
- No se autoriza automáticamente otro smoke aunque exista dominio offline.
