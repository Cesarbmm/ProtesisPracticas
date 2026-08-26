# Historia técnica consolidada — línea EMG-only sin guante, ETAPAS 0–6C

Fecha de consolidación: 2026-08-26

Rama: `experiment/no-glove-intent-control`

Base histórica: `main@6b213ba5c624fffb3f1094585c67d9c8ac43b737`

## 1. Propósito y alcance

Este documento consolida qué se hizo, por qué se hizo, qué matemáticas se
implementaron, qué evidencia se obtuvo y qué sigue sin resolverse desde la
ETAPA 0 hasta la ETAPA 6C. Los informes por etapa continúan siendo la fuente
detallada de comandos, hashes y rutas; esta historia los conecta en una sola
explicación técnica.

La nueva línea no intenta reinterpretar el benchmark anterior. Su arquitectura
es:

```text
EMG cruda
  -> calibración de sesión y detección de reposo
  -> decoder de intención de dos sinergias
  -> referencia mecánicamente viable
  -> controlador cerrado TD3 o convencional
  -> seguridad determinista
  -> cuantización/PWM
  -> simulador
```

Hasta ETAPA 6C toda ejecución permaneció en simulación. No se autoriza inferir
movimiento, corriente, fuerza o seguridad de una prótesis física a partir de
estos resultados.

## 2. Invariantes preservados

### 2.1 Benchmark histórico

`Agent7250_valid_baseline.mat` permanece congelado:

- checkpoint SHA-256:
  `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`;
- TD3 feedforward;
- estado `markov52`;
- reward `trackingMseActionRateReward`;
- interfaz `baselineQuantized`;
- cuatro acciones continuas cuantizadas a PWM;
- referencia histórica proveniente del guante.

Métricas canónicas en 50 simulaciones:

| Métrica | Agent7250 |
|---|---:|
| `trackingMSE` | 0.043045 |
| `trackingMAE` | 0.160336 |
| `actionL2` | 0.596444 |
| `saturationFraction` | 0.392086 |
| `deltaActionL2` | 0.321385 |

`saturationFraction=0.392086` significa que el 39.2086% de los componentes
motor-paso cumplen `abs(effectiveAction)>=0.95`; no significa que los cuatro
motores permanezcan simultáneamente al máximo durante ese porcentaje del
tiempo.

Las campañas 20k y 50k no reemplazaron Agent7250:

| Campaña | MSE | MAE | actionL2 | saturación | deltaActionL2 | Resultado |
|---|---:|---:|---:|---:|---:|---|
| 20k | 0.049695 | 0.173307 | 0.794786 | 0.627400 | 0.463242 | 0/0/5, 9 flags |
| 50k | 0.049149 | 0.171188 | 0.715601 | 0.532329 | 0.491519 | 0/0/5, 0 flags |

El target de guante y el target EMG-only tienen semánticas distintas. Sus MSE
no se usan como si midieran exactamente la misma tarea.

### 2.2 Seguridad y trazabilidad

Durante toda la línea:

- `simMotors=true`;
- datos pregrabados o sintéticos;
- sin puertos COM, PWM físico, Myo real o guante real;
- sin medición de corriente o temperatura;
- commits por etapa y launchers reproducibles;
- perfiles efectivos y overrides, sin alterar silenciosamente los defaults del
  benchmark;
- preservación del archivo local ajeno `matlab_code.zip`;
- ningún push previo a la autorización que originó esta consolidación.

### 2.3 Convenciones métricas

Se conservaron dos cantidades históricamente homónimas:

```text
deltaActionL2_step = mean_motor((u_t-u_t-1)^2)
deltaActionL2_eval = mean_time(sum_motor(diff(u)^2))
```

La primera aparece en el reward por paso e incluye la transición inicial desde
la acción previa. La segunda es la convención del agregador histórico, omite el
primer salto y es la usada en gates y comparaciones publicadas. Los informes
indican cuál se utiliza.

## 3. Contratos matemáticos implementados

### 3.1 Envolvente de EMG cruda

Para una ventana completa de `N` muestras y canal `c`:

```text
m_c(t) = (1/N) sum_n |x_c[n]|
```

La envolvente se calcula antes de WMoos. Las 40 features WMoos se preservan para
la red, pero no se interpretan como amplitudes físicas `[0,1]`: son features
estandarizadas y pueden ser negativas o superiores a uno.

### 3.2 Calibración de la misma sesión

```text
a_c(t) = clip((m_c(t)-b_c)/(s_c-b_c+epsilon), 0, 1)
```

Donde:

- `b_c`: mediana de reposo;
- `s_c`: máximo de los percentiles 95 por instrucción para ese canal;
- `epsilon`: estabilización numérica;
- `a_c`: activación normalizada, separada de WMoos.

La calibración guarda usuario, sesión, fecha, orden de canales, frecuencia,
unidades, procedencia, baseline, niveles de señal, canales planos, decoder,
límites y checksum. Una incompatibilidad de usuario, sesión, canales, unidades,
timing o checksum hace fallar la carga.

Un canal cuyo rango no supera el umbral robusto de ruido se marca plano:

```text
s_c-b_c < max(minCalibrationRange, 6*1.4826*MAD_rest,c)
```

Su activación y su contribución al decoder se fijan en cero.

### 3.3 Decoder de intención de rango dos

Se definieron dos sinergias firmadas:

```text
close          -> [+1,  0]
open           -> [-1,  0]
oppose         -> [ 0, +1]
releaseOppose  -> [ 0, -1]
```

Un ridge ponderado ajusta `W` y bias sobre `atanh(target)`. En runtime:

```text
z_t = tanh(W a_t + b),              z_t in [-1,1]^2
v_des,t = v_max .* clip(B z_t,-1,1), v_des,t in R^4
```

`B` es explícita `4x2`, versionada, acotada y de rango dos. No se supone una
correspondencia canal-motor ni independencia de cuatro DoF.

### 3.4 Histéresis de reposo

La actividad escalar es la media de `a_c` sobre canales válidos:

```text
A_t = mean_c_valid(a_c(t))
```

La compuerta:

```text
activar: A_t >= theta_on  durante n_on ventanas
reposo:  A_t <= theta_off durante n_off ventanas
theta_off < theta_on
```

Un pulso aislado no activa. Durante apagado se ordena frenado hasta poder
alcanzar `v_ref=0` sin violar aceleración. Con gate inactivo la referencia no
deriva.

### 3.5 Referencia mecánicamente viable

La integración nominal es:

```text
q_ref,t = clip(q_ref,t-1 + DeltaT*v_ref,t, q_min, q_max)
```

La implementación proyecta la velocidad sobre la intersección de:

- límite de velocidad;
- límite de aceleración;
- límite de posición;
- margen de frenado.

Después del clip numérico de posición se recalcula la velocidad realmente
aplicada. En `reset`:

```text
q_ref,0 = q_encoder,0
v_ref,0 = 0
```

Un encoder inicial fuera de límites se rechaza en vez de recortarse creando un
salto artificial.

### 3.6 Estados

Se preservaron las variantes históricas:

```text
legacy44      = [phi_EMG(40), q(4)]
markov52      = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4)]
stackedEmg132 = [phi_history(120), q(4), Deltaq(4), u_eff,t-1(4)]
```

La nueva observación principal es:

```text
intentMarkov60 = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4),
                  q_ref(4), v_ref(4)]
```

`q_ref` tiene memoria por integración; exponerlo evita ocultar esa memoria al
agente.

### 3.7 Reward causal sin DTW

```text
e_q,t = q_t-q_ref,t
e_v,t = Deltaq_t/DeltaT-v_ref,t
Delta u_t = u_eff,t-u_eff,t-1

r_t = -[
  w_q   mean(e_q,t^2)
  + w_v mean(e_v,t^2)
  + w_u mean(u_eff,t^2)
  + w_du mean(Delta u_t^2)
  + w_sat mean(max(0,|u_eff,t|-u_soft)^2)
]
```

Primer perfil:

| Peso | Valor |
|---|---:|
| `w_q` | 1.00 |
| `w_v` | 0.00 |
| `w_u` | 0.01 |
| `w_du` | 0.05 |
| `w_sat` | 0.02 |
| `u_soft` | 0.90 |

`w_v=0` aisló el cambio de referencia. `velocityMse` se calculó y registró, pero
no influyó todavía en el aprendizaje. La reward no se considera una capa de
seguridad.

### 3.8 Controlador convencional y cuantización

El baseline P/PD implementa:

```text
u_raw = Kp .* (q_ref-q) + Kd .* (v_ref-v)
```

Perfil validado:

```text
Kp=1.5, Kd=0, maxAction=64/255,
positionTolerance=0.01, velocityTolerance=0.03
```

Luego se aplica `baselineQuantized` con niveles PWM:

```text
[0,64,96,128,160,192,224,255]
```

### 3.9 Seguridad de posición en simulación

La ablación 6A añadió un adaptador externo a la dinámica interna:

```text
q_limited = clip(q_simulated, [0,0,0,0], [1,1,1,1])
```

Escalas encoder:

```text
[26500,11500,8500,9000]
```

Cada muestra interna intervenida se cuenta por motor. El adaptador está
desactivado por default y solo puede activarse con `simMotors=true`. No modifica
`prosthesis_simulator.m` y no oculta NaN o Inf.

## 4. ETAPA 0 — orientación, benchmark y mapa del repositorio

**Resultado: PASS.**

Se verificó `main`, se creó la rama experimental desde
`6b213ba5c624fffb3f1094585c67d9c8ac43b737` en un worktree separado y se
congelaron hashes, métricas y dependencias históricas.

Hallazgos principales:

1. La ruta `markov52` era `40+4+4+4=52` y no contenía referencia explícita.
2. El dataset pregrabado cargaba siempre `emgs`, `gloves` y metadata.
3. Constructor, `reset`, `step`, terminación, reward y plots dependían del
   guante aunque el guante no estuviera en `markov52`.
4. En 7405/7420 pares, el guante tenía menor duración nominal que la EMG; quitar
   el guante cambia de forma esperada la duración de episodios.
5. `simMotors=true` no era suficiente para impedir `Myo()` real si
   `usePrerecorded=false`; por ello la nueva línea debe rechazar ese modo.
6. Las properties `Constant` de `Env` podían ocultar overrides por caché de
   clase MATLAB.
7. La rama `benchmark-motor2-diagnostic` mezclaba diagnóstico con cambios de
   reward, conversión y calibraciones. No se portó en bloque.
8. La compuerta Myo histórica no fue reproducible; se conservó como evidencia,
   no como solución.

Una evaluación corta reprodujo 50 episodios históricos con MSE
`0.040798954456`, saturación `0.396016899767` y cero alteraciones del checkpoint.
Estas cifras corresponden a ese smoke; el benchmark canónico sigue siendo la
tabla de la sección 2.1.

## 5. ETAPA 1 — desacoplamiento de la fuente de referencia

**Resultado: PASS.**

Se añadió:

```text
referenceSource = "glove" | "emgIntent"
```

La ruta `glove` mantuvo su comportamiento. En `emgIntent`:

- no se cargan `gloves`;
- no se construye `RecordedGlove`;
- no se leen `flexData` ni `reduceFlexDimension`;
- el episodio termina por agotamiento de EMG;
- se rechazan Myo real y controlador físico;
- se guardan `intentTarget`, `intentVelocity`, `referenceHistory` y contador;
- se normalizó un contrato único y versionado de `rewardInfo`.

Como scaffold, sin anticipar ETAPA 2, `q_ref` mantuvo el encoder inicial y
`v_ref=0`. Dos episodios de nueve pasos produjeron tracking exacto y cero deriva;
ese cero verificó desacoplamiento, no desempeño.

La regresión Agent7250 comparó 14 variables legacy en 50 episodios:
`GLOVE_CORE_MISMATCHES=0` y métricas idénticas antes/después.

Solución estructural importante: configurables sensibles pasaron de constantes
de clase a propiedades inmutables por instancia, haciendo efectivos los
overrides sin cambiar una instancia ya creada.

## 6. ETAPA 2 — calibración e intención offline

**Resultado: PASS sobre fixture sintético; sin RL.**

Se implementaron las ecuaciones de envolvente, normalización, dos sinergias,
histéresis y referencia viable. DENIS no se usó para inventar una calibración
porque carece de reposo, MVC/P95 compatible, oposición de pulgar y metadata de
sesión/canales suficiente.

El fixture determinista incluyó reposo, cierre, apertura, oposición, liberación,
intensidades moderada/máxima, ruido y un canal plano.

Resultados seed 11, 62 ventanas:

| Evidencia | Valor |
|---|---:|
| canales activos/planos | 7/1 |
| RMSE del ajuste | 0.008217491 |
| rango de `W` activa / `B` | 2/2 |
| precisión de signo | 1.0 |
| falsa activación reposo/ruido | 0 |
| deriva con gate inactivo | 0 |
| error inicial encoder/referencia | 0 |
| máximo `abs(v_ref)` | 0.125697688 |
| máximo `abs(a_ref)` | 0.628488439 |
| violaciones posición/velocidad/aceleración | 0/0/0 |

Pruebas: 8/8 específicas y 14/14 consolidadas. El PASS valida software e
invariantes; no demuestra separabilidad humana ni límites físicos.

## 7. ETAPA 3 — observación causal `intentMarkov60`

**Resultado: PASS.**

Se integró el decoder en `Env` y se añadió un mapa explícito de índices para
44/52/60/132 dimensiones.

Contrato temporal:

```text
state_t contiene q_ref,t y v_ref,t
action_t se aplica a la planta
reward_t usa q_ref,t y encoder_t+1
EMG recién leída actualiza solamente q_ref,t+1 y state_t+1
```

Por tanto, `action_t` nunca se penaliza con intención disponible solo en
`t+1`.

Smoke seed 11:

- 61 pasos y estado 60;
- datos finitos;
- error inicial de referencia 0;
- desalineación estado/reward 0;
- residuo de integración 0;
- desalineación de acción previa 0;
- cero violaciones de posición, velocidad, aceleración o límites del estado.

Pruebas: 7/7 específicas y 21/21 consolidadas. La regresión glove conservó
exactamente las 14 variables legacy.

## 8. ETAPA 4 — reward causal sin DTW

**Resultado: PASS.**

Se implementó la reward de la sección 3.7, se añadieron `velocityMse`,
`softSaturationPenalty` y `referenceSource` al contrato de logging, y se
preservaron lectores antiguos.

Nueve casos manuales verificaron tracking perfecto, reposo, error de posición,
cambio brusco, saturación y cada motor individual. El residuo numérico máximo
entre reward y reconstrucción fue `5.551115123125783e-17`.

El smoke artificial de 20 pasos produjo saturación `0.25` deliberadamente para
activar términos de prueba; no representa una política entrenada.

Pruebas: 7/7 específicas y 28/28 consolidadas. La regresión Agent7250 mantuvo
700 comparaciones legacy con cero diferencias.

Limitación clave: `w_v=0`. El error de velocidad existe como diagnóstico, pero
el agente posterior no fue incentivado directamente a seguir `v_ref`.

## 9. ETAPA 5 — baseline convencional y diagnóstico de planta

**Resultado: PASS diagnóstico, con fallos de planta conservados.**

Se realizaron 112 barridos abiertos:

```text
2 posiciones x 4 motores x 2 signos x 7 niveles PWM
```

y 32 escenarios cerrados:

```text
2 posiciones x 4 motores x 2 perfiles x 2 signos
```

La resolución temporal observable fue aproximadamente `0.142857 s`, limitada
por el muestreo interno del probe.

Planta abierta desde posición intermedia:

| Motor | Ganancia positiva | Ganancia negativa | Velocidad máx. norm/s |
|---:|---:|---:|---:|
| 1 | 0.224841 | 1.009501 | 2.410157 |
| 2 | -0.057307 | 1.011379 | 3.979652 |
| 3 | 0.438009 | 1.050937 | 5.598216 |
| 4 | 0.353057 | 1.034982 | 4.885093 |

Motor 2 mostró ganancia negativa para cierre positivo intermedio. Hubo dos
inconsistencias abiertas de dirección y 56/112 trials tocaron o salieron de
`[0,1]` antes de existir la capa correctiva.

Baseline P cerrado:

| Motor | MSE | MAE | actionL2 | deltaActionL2 | saturación | flags |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.008076 | 0.068014 | 0.007874 | 0.009099 | 0 | 0 |
| 2 | 0.048050 | 0.159832 | 0.011723 | 0.006649 | 0 | 2 |
| 3 | 0.036842 | 0.170896 | 0.015048 | 0.037795 | 0 | 4 |
| 4 | 0.025337 | 0.131419 | 0.014523 | 0.038845 | 0 | 0 |

No se portó ninguna calibración de signo o conversión. Los fallos de M2 y M3 se
dejaron como evidencia para no confundir diagnóstico con corrección.

## 10. ETAPA 6 — primer TD3 sin guante

**Resultado: PARTIAL; piloto bloqueado.**

Se creó `td3_no_glove_intent` desde cero:

- actor y dos críticos feedforward nuevos;
- 60 entradas `intentMarkov60`;
- replay buffer vacío;
- sin Agent7250 ni residual;
- `baselineQuantized` sin cambios;
- seed 11 y 200 episodios;
- corpus sintético de la misma sesión declarada;
- checkpoints 50/100/150/200, sin escoger retrospectivamente el mejor.

Entrenamiento original:

| Métrica | Valor |
|---|---:|
| episodios/pasos | 200/12200 |
| trackingMSE | 0.083552 |
| trackingMAE | 0.183890 |
| actionL2 | 0.394485 |
| deltaActionL2 | 0.482923 |
| saturationFraction | 0.127766 |
| episodios fuera de posición | 200/200 |

Aceptación original de Agent200:

| Métrica | Valor/gate |
|---|---|
| trackingMSE | 0.028423, informativa |
| deltaActionL2 | 0.130050, PASS |
| saturationFraction | 0.020492, PASS |
| episodios fuera de posición | 50/50, FAIL |
| flags Motor 2 | 25, FAIL |
| flags M1/M3/M4 | 150, FAIL |

El decoder tuvo falsa activación `0/96` en reposo y la política tuvo saturación
0, pero la planta salió de posición en 24/24 episodios de reposo. El smoke
demostró que entrenar más no debía preceder una corrección determinista de
posición.

## 11. ETAPA 6A — ablación de seguridad de posición

**Resultado: PARTIAL; posición corregida, funcionalidad no.**

La única variable fue el clip de posición de la sección 3.9. Se repitieron los
mismos 200 episodios, seed 11 y corpus.

Gate de Agent200 con posición limitada:

| Check | Resultado |
|---|---|
| NaN/Inf | PASS, 0 |
| violaciones de posición | PASS, 0 |
| saturación aceptación | PASS, 0.110656 |
| deltaActionL2 aceptación | PASS, 0.167321 |
| Motor 2 | FAIL, 25 flags |
| M1/M3/M4 | FAIL, 100 flags |
| saturación reposo | FAIL, 0.008333 |
| falsa activación decoder | PASS, 0/96 |

Aceptación:

```text
MSE=0.075152
MAE=0.165273
velocityMSE=0.383399
actionL2=0.306535
deltaActionL2=0.167321
saturationFraction=0.110656
```

Intervenciones de seguridad:

```text
entrenamiento=28895
aceptación=6000
reposo=876
```

La capa eliminó valores inválidos, pero su alta frecuencia mostró que la
política seguía empujando contra límites. Seguridad no equivale a control
funcional.

## 12. ETAPA 6B — diagnóstico offline de bordes, comandos y respuesta

**Resultado: PASS diagnóstico; ninguna causa única validada.**

Se analizaron 200 episodios de entrenamiento, 50 de aceptación y 24 de reposo,
sin cargar agente ni simulador. Cada fila respetó:

```text
stateLog(t)                   -> estado antes de action_t
referenceHistory(t)          -> q_ref visible para action_t
actionPwmLog(t)              -> comando aplicado
trackingPredictionHistory(t) -> encoder después de action_t
```

Aceptación, 3800 componentes con `v_ref` activa:

- sin movimiento: `3325/3800 = 87.500%`;
- de la inmovilidad:
  - borde o seguridad: `1775/3325 = 53.383%`;
  - interior con PWM cero: `87/3325 = 2.617%`;
  - interior con PWM no cero: `1463/3325 = 44.000%`;
- PWM opuesto a `v_ref`: `1950/3800 = 51.316%`;
- PWM opuesto a `q_ref-q`: `6875/10875 = 63.218%`;
- respuesta opuesta al PWM: `642/2592 = 24.769%`;
- PWM hacia fuera en límite: `5775/6150 = 93.902%`;
- `v_ref` hacia fuera del límite propio de `q_ref`: 0.

Reposo:

- 1440 componentes con `v_ref=0`;
- 780 componentes sin demanda conjunta de velocidad o posición;
- PWM no cero en `780/780` de esos componentes;
- Motor 2 saturó en `12/204` componentes sin demanda.

Conclusión: el borde explica una fracción importante, pero no la inmovilidad
interior con PWM no cero. La zona muerta PWM cero no es dominante. Existen
errores de comando y de respuesta que deben separarse.

## 13. ETAPA 6C — comparación emparejada Agent200/control P

**Resultado: PASS diagnóstico; gate TD3 todavía fallido.**

Agent200 se trató como evidencia inmutable. Para cada uno de los 50 episodios de
aceptación y 24 de reposo, el P comenzó desde exactamente la misma posición y
consumió exactamente `q_ref(t)` y `v_ref(t)`. Solo cambió la fuente del comando.

Emparejamiento:

```text
error máximo q_ref=0
error máximo v_ref=0
error máximo posición inicial=0
error temporal fuente=0
74/74 hashes fuente preservados
```

Aceptación:

| Métrica | Agent200 | P | Cambio P |
|---|---:|---:|---:|
| trackingMSE | 0.075152412 | 0.033790824 | -55.04% |
| trackingMAE | 0.165273319 | 0.112553904 | -31.90% |
| velocityMSE | 0.383398803 | 0.420108440 | +9.57% |
| actionL2 | 0.306535002 | 0.033044542 | -89.22% |
| deltaActionL2 | 0.167320743 | 0.215744714 | +28.94% |
| saturationFraction | 0.110655738 | 0 | -100% |
| seguridad | 6000 | 450 | -92.50% |
| flags M2 | 25 | 25 | 0% |
| flags otros | 100 | 50 | -50% |

El P nunca ordenó contra `q_ref-q`, pero conservó flags `[0,25,25,25]` por motor,
ahora de dirección respecto de `v_ref`, no de inmovilidad. Motor 3 concentró
las 450 intervenciones de seguridad del P.

Reposo:

| Métrica | Agent200 | P |
|---|---:|---:|
| trackingMSE | 0.069452113 | 0 |
| actionL2 | 0.243631552 | 0 |
| saturationFraction | 0.008333333 | 0 |
| seguridad | 876 | 0 |

El P demuestra que no se requieren comandos para mantener estas referencias de
reposo sintético. No demuestra que una compuerta Myo real sea válida.

## 14. Problema actual de ETAPA 6

El problema actual no es una única métrica ni un único motor. La evidencia
separa al menos seis mecanismos.

### 14.1 Presión persistente contra límites

La seguridad corrigió todas las violaciones observables, pero intervino 6000
veces en aceptación de Agent200 y 876 en reposo. En 6B, 93.902% de los comandos
emitidos mientras el encoder estaba en un límite apuntaban hacia fuera.

Interpretación: la seguridad impide estados inválidos, pero Agent200 no aprendió
a dejar de pedir movimiento imposible. Esta es una deficiencia de comando o de
observación/aprendizaje, no un fallo de clipping.

### 14.2 Comando TD3 incompatible con el error de posición

Agent200 ordenó contra `q_ref-q` en 63.218% de los componentes elegibles de
aceptación. El P emparejado redujo esa fracción a cero y mejoró MSE/MAE/esfuerzo.

Interpretación acotada: la política aprendida es responsable de una parte
sustancial del esfuerzo y error observados. Esto no prueba que TD3 sea
inadecuado en general ni que el MSE sea la causa de saturación.

### 14.3 Planta y régimen de movimiento

ETAPA 5 encontró ganancia de signo negativo para cierre positivo intermedio en
Motor 2 y flags en Motor 3. ETAPA 6B observó respuesta opuesta al PWM en 24.769%
de los pasos móviles con comando. Bajo P, la respuesta opuesta al PWM cayó a
2.655%, pero persistieron 25 flags en M2, M3 y M4 respecto de `v_ref`.

Interpretación: parte del problema puede depender de planta, posición inicial,
dirección o régimen. No se justifica un flip fijo por motor sin una ablación.

### 14.4 Conflicto entre posición y velocidad

La reward entrenada fija `w_v=0`. El P siempre sigue el signo de `q_ref-q`, pero
puede oponerse temporalmente a `v_ref` para corregir error acumulado. En 6C el P
mejoró tracking de posición, pero `velocityMSE` aumentó 9.57%.

Interpretación: un flag respecto de velocidad no equivale automáticamente a un
error de posición o de signo. Hace falta medir el desfase y el régimen.

### 14.5 Actividad de política durante reposo sin demanda

El decoder sintético tuvo cero falsas activaciones, pero Agent200 emitió PWM no
cero en todos los 780 componentes con demanda conjunta nula analizados en 6B.
El P produjo acción, error y movimiento exactamente cero en las 24 trazas de
reposo emparejadas.

Interpretación: la actividad de reposo observada pertenece a la fuente de
comando Agent200 bajo este corpus, no a una deriva necesaria de `q_ref` ni a una
activación del decoder. Esto sigue sin validar reposo con Myo real.

### 14.6 Suavidad no resuelta

Aunque P redujo `actionL2` 89.22%, aumentó `deltaActionL2` 28.94%. La menor
saturación del P también está condicionada por su cap de 64 PWM, mientras
Agent200 puede llegar a 255.

Interpretación: energía, saturación y suavidad son objetivos diferentes. No se
puede promover el P ni una nueva política mirando una sola métrica.

### 14.7 Lo que todavía no se sabe

No se ha medido con el corpus de ETAPA 6:

- lag óptimo por motor y dirección;
- cuánto MSE se reduce al permitir un lag fijo;
- cuánto retraso perdona una alineación DTW restringida;
- si el conflicto M2/M3/M4 es temporal, de signo, de límite o de planta;
- si una referencia filtrada causal supera a una métrica tolerante al retraso;
- distribución multisemilla, porque el piloto sigue bloqueado;
- comportamiento con Myo real, OOD, recolocación o canales planos reales.

Por eso ETAPA 6 continúa sin pasar su gate y ETAPA 8 no está autorizada.

## 15. Hipótesis y fuerza de la evidencia

| Hipótesis | Evidencia a favor | Evidencia en contra/límite | Estado |
|---|---|---|---|
| Los límites explican todo | 53.383% de inmovilidad activa ocurre en borde/seguridad | 44% ocurre en interior con PWM no cero | rechazada como explicación única |
| La zona muerta PWM domina | existe cuantización | solo 2.617% de inmovilidad interior tuvo PWM cero | débil |
| Agent200 causa esfuerzo innecesario | P reduce actionL2 89.22%, saturación a cero y reposo a cero | P usa cap 64 | fuerte pero condicionada |
| M2 es el único problema | M2 conserva 25 flags | M3/M4 también conservan flags; M3 concentra seguridad P | rechazada |
| Existe un error fijo de signo | planta M2 mostró inversión en un régimen | P ordena bien respecto de posición y aun así hay flags respecto de velocidad | no demostrada |
| El retardo explica los flags | conflicto posición/velocidad y muestreo de 0.2 s | aún no hay análisis de lag | hipótesis para ETAPA 7 |
| DTW resolverá el control | puede cuantificar desalineación | no se ha probado beneficio ni costo; puede premiar llegar tarde | no demostrada |

## 16. Evolución de pruebas

| Cierre | Suite no-glove |
|---|---:|
| ETAPA 1 | 6/6 |
| ETAPA 2 | 14/14 |
| ETAPA 3 | 21/21 |
| ETAPA 4 | 28/28 |
| ETAPA 5 | 33/33 |
| ETAPA 6 | 39 pruebas disponibles |
| ETAPA 6A | 45/45 |
| ETAPA 6B | 50/50 |
| ETAPA 6C | 55/55 |

Todas las cifras corresponden a las suites en el commit de su etapa. El aumento
indica cobertura acumulativa; no sustituye validación experimental.

## 17. Historia de commits

| Etapa | Commit principal |
|---|---|
| 0 | `9a1d153f20af120d6d84b9068f25fb4fb19b4a72` |
| 1 | `7fa62f85c424dda7bf3dedc65455c3045b3c63ec` |
| 2 | `49883962765a25bd27d111b4f6eb4625d893e41c` |
| 3 | `5c497312913f26da1232968a5a228d8a095a970c` |
| 4 | `5eb79c2924b434cd6dc45129e5832e55bba79aad` |
| 5 | `9243989eff1eaf7a57b8c6ee16c53804c17a91e0` |
| 6 | `62748112a064b5a0ad6ba6756d04c2d22b402753` |
| 6A | `ae8b264e7555b0477e036db3c8238eb0c23fc10a` |
| 6B | `b707e49f4c0df6ec81f06b5e211fb0a49fdcc39d` |
| 6C | `c0398c89c941578e8925a7b172d8b6add242b1b5` |

Los commits documentales separados conservan el SHA exacto usado por cada
launcher cuando el informe se creó después de la corrida.

## 18. Reproducción y fuentes detalladas

Informes canónicos:

- `00_baseline_audit.md`
- `01_reference_source.md`
- `02_intent_calibration_offline.md`
- `03_intent_markov60.md`
- `04_causal_intent_reward.md`
- `05_conventional_plant_diagnostic.md`
- `06_td3_no_glove_smoke.md`
- `06a_position_safety_ablation.md`
- `06b_boundary_diagnostic.md`
- `06c_matched_controller_comparison.md`

Cada informe registra launcher, pruebas, métricas, hashes, rutas de artefactos,
riesgos y confirmación de hardware. Los puntos de entrada activos están bajo:

```text
matlab_code/workflows/published/
```

La ejecución reproducible requiere comenzar en `matlab_code`, añadir sus rutas
y suministrar un `resultsRoot` nuevo. Los launchers rechazan reutilizar un
directorio de salida.

## 19. Justificación de la siguiente etapa

ETAPA 7 debe permanecer offline y responder una sola pregunta: si la diferencia
temporal explica una parte material del error sin ocultar el error de extremo.

Debe calcular, sobre las mismas trazas:

1. MSE causal sin desplazamiento;
2. MSE para retardos discretos acotados;
3. correlación y lag asociado por motor y régimen;
4. DTW multivariable compartido, restringido, métrica `squared`;
5. error DTW normalizado por longitud real del camino;
6. penalización de lag medio;
7. reducción de error frente al error de extremo actual.

No debe cambiar `q_ref`, estado, reward, agente, cuantización, seguridad o
simulador. Si la mejora corresponde a un lag fijo, se debe probar primero una
compensación causal o referencia filtrada. DTW solo podría proponerse como
término auxiliar después de evidencia cuantitativa; nunca como recompensa
dominante.

## 20. Estado al cerrar la consolidación

- La arquitectura EMG-only causal existe y está probada en datos sintéticos.
- El benchmark de guante permanece reproducible y congelado.
- La seguridad de posición evita salidas, pero interviene con demasiada
  frecuencia bajo Agent200.
- Agent200 no pasa el gate funcional y produce comandos innecesarios en reposo.
- El P mejora posición, esfuerzo y reposo, pero no resuelve todos los flags ni
  suavidad/velocidad.
- No existe evidencia para declarar una causa raíz única.
- ETAPA 7 es la siguiente medición autorizada; ETAPA 8 permanece bloqueada.
- No se utilizó hardware.
