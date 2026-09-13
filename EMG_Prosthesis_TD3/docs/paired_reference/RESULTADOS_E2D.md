# E2D — Intervención mínima mediante zona muerta de error

**E2D_RESULT = DEADBAND_NOT_SUFFICIENT. SELECTED_EPSILON = ninguno.**
**RL_AUTHORIZED = NO. E2B = FAIL. E2C = CHARACTERIZED.**

La zona muerta elimina los ciclos finales con epsilon .08 y .12 y mejora el MSE
y reward globales. Sin embargo, ambos valores incumplen el gate preregistrado de
movimiento: aumentan la respuesta plana y convierten en PWM0 una fracción excesiva
de los comandos originalmente activos. .12 también supera el límite de aumento
de action_no_motion en grupos específicos. No se elige un candidato fallido.

Fecha: 2026-09-06. **107/107 tests: 81 históricos y 26 nuevos.** Los **539 archivos
históricos protegidos**, incluidos los archivos locales E2C, conservan sus hashes.
No se cambiaron parámetros, gates o rejilla después de medir. No se implementó
histéresis, otra solución ni integración en Env/TD3.

## 1. Auditoría y preregistro

Worktree real: `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`; rama
`experiment/no-glove-paired-reference-td3`; HEAD conservado
`165be049eb41fc41254435181c9857fe0f22ed1c`. Los cambios previos eran exclusivamente
los archivos E2C conocidos, sin seguimiento; su comprobador de artefactos pasó
antes de E2D. Se preservaron. No se reparó historia Git, cambió rama, hizo commit,
fetch, pull ni push. No se usó código, resultados o hipótesis del sandbox.

[PREREGISTRO_E2D.md](PREREGISTRO_E2D.md) se guardó antes de las comparaciones:
SHA256 **`9a9527571f9fac8524aa8b3ef90ee0110ed1bfce075146596868b7e5cd1ee8c9`**.

Rejilla fija **[0,.03,.05,.08,.12]**, elegida usando sólo E2C ya cerrado. La escala
es h(q)/teacher: .03 representa tres puntos porcentuales del intervalo unitario,
no porcentaje de encoder o de carrera. Con Kp=2, el umbral histórico raw=.05 ya
implica |error|=.025. .01/.02 serían redundantes para PWM. Los errores de corrección
conocidos E2C, aproximadamente .051–.108, justificaron incluir .08/.12 antes de medir.
No se añadieron valores, ganancias por motor ni otra búsqueda.

Única intervención:

```text
error = reference_before - h(q_before)
raw_histórico = clip(2*error,-1,1)
raw_deadband = 0 si abs(error)<=epsilon; raw_histórico en otro caso
effective/PWM = remapeo histórico baselineQuantized(raw_deadband)
```

Kp=2, Ts=.2, muestreo API=.14, niveles/velocidades/umbral PWM, planta canónica,
límites, h(q), teacher, reward/pesos, markov52, WMoos, runtime E2A y TD3 permanecen
intactos. La intervención es exclusivamente un helper diagnóstico del P privilegiado.
Usa teacher; no se presenta como una solución ya integrada en ejecución sin guante.

## 2. Comparación causal y reproducción del basal

Se reutilizaron los mismos 200 episodios DEVELOPMENT del MAT E2B: referencias
previas/posteriores, q0, horizonte teacher y acción efectiva previa inicial cero.
**2938 pasos /11752 comandos motor-paso por epsilon**, 1000 episodios en total.
Las nuevas comparaciones no abren archivos originales de sujetos. Las regresiones
históricas conservan sus pruebas BLANCA y fixtures; MATEO/SANDRA no se abren ni
comparan. E1–E1D siguen cerradas, sin decoder ni guante virtual.

La planta se ejecuta mediante la API canónica real; el remapeo utiliza el cuerpo
histórico intacto en la fixture E2C. El reward se evalúa con la función original
`trackingMseActionRateReward`, entregando los mismos campos teacher/h(q)/acción
previa que consume. No se crea un modo de entrenamiento con reward ficticio.
El horizonte sigue siendo el de disponibilidad teacher E2B; no se cambia done.

Epsilon0 reproduce los 200 episodios: **q, raw, effective, PWM y reward exactamente
iguales**. Las pruebas aceptan 1e-12 para reward; el máximo medido fue 0.

| Basal congelado | Valor |
|---|---:|
| MSE cero, de E2B | .09270421488254463 |
| MSE P2 | .025400336373607925 |
| Reward P2 | -.03272837710980499 |
| Ciclos finales P2 | 2 |
| Retrocesos M3 P2 | 0 |

Se mantiene TRACKING_CONTROLABILITY=SUPPORTED y la mejora histórica aproximada
72.60 % frente a cero. E2D no vuelve a seleccionar Kp ni reabre esa pregunta.

## 3. Métricas y gates de todos los epsilon

Agregación E2B: media temporal por episodio, episodios por sujeto/lado y media de
20 grupos. Cambio MSE=100*(MSE_e−MSE_0)/MSE_0. Deterioro reward=
100*(R_0−R_e)/abs(R_0). **Valores negativos significan mejora**, incluso para reward
negativo. Mayor reward es mejor. Los CSV conservan precisión completa de salida;
las tablas siguientes redondean sólo para lectura.

| Epsilon | MSE | Deterioro MSE % | Reward | Deterioro reward % | Ciclos finales | Gate que falla |
|---:|---:|---:|---:|---:|---:|---|
| 0 | .0254003364 | 0 | -.0327283771 | 0 | 2 | A: basal con ciclos |
| .03 | .0252430506 | -.61923 | -.0322986036 | -1.31315 | 2 | A |
| .05 | .0244978726 | -3.55296 | -.0305573319 | -6.63353 | 1 | A y F |
| .08 | .0242843741 | -4.39349 | -.0295803726 | -9.61858 | 0 | F |
| .12 | .0245178949 | -3.47413 | -.0291734523 | -10.86190 | 0 | F |

Todos pasan los límites globales de MSE/reward y el gate de nuevas inversiones M3.
El gate F se fijó como flat_response +2 puntos porcentuales y action_no_motion
+5 puntos, globalmente y en cada motor/dirección; además, no convertir a cero más
del 20 % de los comandos originalmente activos. No se cambió tras estos resultados.

| Epsilon | MAE | actionL2 | deltaActionL2 | Saturación % | flat_response % | action_no_motion % |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | .1191157 | .1188514 | .1227905 | .76921 | 1.625 | 45.6242 |
| .03 | .1188467 | .1162029 | .1178705 | .72692 | 1.875 | 45.9645 |
| .05 | .1180805 | .1069227 | .0998046 | .52066 | 2.750 | 46.9601 |
| .08 | .1192129 | .0974669 | .0864266 | .35640 | 4.500 | 48.0878 |
| .12 | .1217203 | .0887443 | .0753623 | .27671 | 7.625 | 47.8554 |

Saturación conserva |effective|>=.95. flat_response usa rango h(q)<=1e-9 incluyendo
q0; no implica necesariamente encoder inmóvil, debido a los gaps de h. No-motion
cuenta comandos activos con |delta_q|<=1e-9, dividido por activos, después agregado
como en E2B. No se confunde con PWM0. Quedan sin comandos activos 0,0,1,3,6
combinaciones episodio-motor según epsilon; sus NaN de no-motion se conservan y
sus respuestas planas permanecen contabilizadas.

La descomposición exportada es siempre:
`reward = trackingTerm − actionPenalty − deltaActionPenalty`, donde
`trackingTerm=−MSE`, `actionPenalty=.01*actionL2` y
`deltaActionPenalty=.05*deltaActionL2`, incluido el salto inicial desde cero.
La mejoría de reward combina tracking y menores penalizaciones; no equivale a
demostrar estabilidad o conservación de movimiento útil.

## 4. Degradaciones y motivo exacto del rechazo

Un grupo cuenta como degradado si MSE **o** reward empeora más del 5 %.

| Epsilon | Sujetos degradados | Motores degradados | Direcciones degradadas |
|---:|---:|---:|---:|
| .03 | 0/10 | 0/4 | 0/2 |
| .05 | 0/10 | 1/4 | 0/2 |
| .08 | 0/10 | 1/4 | 0/2 |
| .12 | 0/10 | 1/4 | 0/2 |

El motor degradado es **M1**: deterioro MSE 6.5482 %, 15.4421 % y 29.7056 % para
.05/.08/.12. Su reward cambia −.1658 %, +4.3146 % y +15.6262 % de deterioro.
Estos recuentos pasan D porque se permite un motor, pero se mantienen visibles.

Falla F por los siguientes efectos, aplicando los umbrales preregistrados:

- .05: flat_response de M2 aumenta **3.5 puntos**, por encima de 2.
- .08: flat_response global aumenta **2.875 puntos**, M2 **9 puntos**, y apertura
  **4.75 puntos**; el 35.5948 % de comandos basales activos termina en cero.
- .12: flat_response global aumenta **6 puntos**, M2 **19.5 puntos**, y apertura
  **10.5 puntos**; no-motion aumenta **6.5215 puntos** en M2 y **6.1965 puntos** en
  apertura; el 50.8154 % de comandos basales activos termina en cero.

Por tanto el rechazo no depende solamente del guard adicional20%: .08/.12 también
fallan el límite preregistrado de respuesta plana. No se relajan esos criterios.

## 5. Cuántas acciones se convierten en cero

Dos estimandos distintos, ambos guardados con numerador y denominador:

1. **Directo, mismo estado intervenido:** PWM que enviaría P2 sin deadband !=0,
   frente a PWM intervenido=0. Principal ZEROED_ACTION_FRACTION: divide entre
   los 11752 comandos. Aísla la inhibición local, sin comparar estados distintos.
2. **Pareado con trayectoria P2 original:** PWM basal activo frente a PWM actual0
   en el mismo episodio/paso/motor. Incluye consecuencias indirectas porque q
   puede haber divergido. El guard divide entre **9566 comandos basales activos**.

| Epsilon | Ceros directos /11752 | Fracción directa % | Ceros pareados /9566 activos | Fracción para gate % |
|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 0 | 0 |
| .03 | 403 | 3.4292 | 486 | 5.0805 |
| .05 | 1812 | 15.4187 | 1846 | 19.2975 |
| .08 | 3521 | 29.9609 | 3405 | 35.5948 |
| .12 | 5151 | 43.8308 | 4861 | 50.8154 |

Fracción directa por motor y dirección para los valores sin ciclos finales:

| Epsilon | M1 % | M2 % | M3 % | M4 % | Cierre % | Apertura % |
|---:|---:|---:|---:|---:|---:|---:|
| .08 | 34.6154 | 20.9666 | 30.0204 | 34.2410 | 27.1259 | 32.7997 |
| .12 | 48.3322 | 31.9605 | 42.3077 | 52.7229 | 40.9014 | 46.7643 |

`zeroed_actions.csv` incluye todos los epsilon y también motor×dirección, junto
con fracciones sobre comandos activos del P2 contrafactual en el mismo estado.
Los porcentajes de comandos anulados no son porcentajes de desplazamiento perdido:
algunas acciones activas ya producen HOLD. No se presenta lo uno como lo otro.

## 6. Qué ocurre en los dos casos E2C

| Epsilon | BLANCA fila1 cierre M3: ciclo final | IVANNA fila104 apertura M4: ciclo final |
|---:|---|---|
| 0 | Sí | Sí |
| .03 | Sí | Sí |
| .05 | No | Sí |
| .08 | No | No |
| .12 | No | No |

**BLANCA, referencia histórica:** .05 ya cambia el trayecto antes del ciclo.
Anula los comandos +64 de los pasos1/2 (errores .03324 y .02737). El paso3 aplica
+128 desde q=0 y llega a 6414.8333, en vez de partir de 4159.3333 y llegar a
7286.3333. El paso4 queda en cero; después los +64 no desplazan ese q por el HOLD
de la planta histórica. Se evita visitar el par original, sin demostrar que .05
pueda romperlo si se inicia dentro de él. No se cambia ese HOLD ni la curva M3.

**IVANNA, referencia histórica:** .08 anula varias correcciones desde q=6280.8333,
pero los pasos20–22 todavía aplican −64,+96,−64 y visitan 2976.3333/6049.75.
No completa las cuatro transiciones alternas requeridas al final; ése es el
alcance de CYCLES=0. .12 mantiene M4 en su posición inicial durante todo el episodio,
que cuenta como respuesta plana y ausencia de comandos activos.

El detector de gate es el histórico: últimas cuatro transiciones/cinco q,
tolerancia1e-9 encoder, amplitud h>.05 y PWM alternos. No se cambió para declarar
resuelto un par. Aplicado además a todos los prefijos, como diagnóstico separado:

| Epsilon | Ventanas alternantes totales | Nuevas frente a la ventana basal correspondiente |
|---:|---:|---:|
| 0 | 48 | 0 |
| .03 | 45 | 4 |
| .05 | 32 | 11 |
| .08 | 8 | 1 |
| .12 | 6 | 1 |

Son ventanas que pueden solaparse, no un número de órbitas independientes. No hay
nuevos ciclos **finales** en ningún epsilon. Sí hay nuevos transitorios: con .08,
JOE fila293 apertura M4, ventana finalizada en paso9, par2976.3333/6049.75; con .12,
GABRIEL fila167 apertura M3, ventana hasta paso18, par−238.25/7510. No se ocultan por
haber desaparecido los dos casos conocidos al final.

## 7. Referencia fija y mapa local

Se repiten los 20 replays E2C por epsilon: cinco referencias, ambos estados de
cada par, 100 pasos. Total **100 replays /10000 transiciones**.

| Epsilon | Ciclos al final /20 | Replays con últimos20 comandos cero /20 |
|---:|---:|---:|
| 0 | 20 | 0 |
| .03 | 20 | 0 |
| .05 | 20 | 0 |
| .08 | 11 | 9 |
| .12 | 0 | 20 |

No aparecen pares nuevos al final de estos replays fijos. En las referencias
primarias, M3 necesita .12 en la rejilla para romper el par: q=7532.5 tiene error
−.1080694, queda PWM0 y mantiene posición. M4 necesita .08: q=6049.75 tiene error
−.0511415 y queda PWM0. Estos valores no garantizan tracking de una referencia
que continúe moviéndose. .08 tampoco elimina todas las órbitas fijas ensayadas.

Se conservan los 5832 pares q/reference E2C por epsilon: **29160 puntos**, más
228 pruebas alrededor de error±.025 y de los bordes ±epsilon con perturbaciones
1e-10. Epsilon0 reproduce exactamente PWM y q_next del mapa E2C.

Alrededor de error±.025, P2 histórico puede activar PWM64 porque raw=±.05.
Todos los epsilon positivos de esta rejilla inhiben esa zona, pero **no reducen
el salto del cuantizador**: trasladan la activación a |error|>epsilon. Justo fuera
de la banda, |raw|=2*epsilon sigue pasando por el remapeo original; para los bordes
ensayados se reactiva el nivel mínimo64. No se introduce un PWM más pequeño.
Los CSV conservan error, raw antes/después, effective, PWM y q_next para mostrarlo.

## 8. Planta, artefactos y validación

No se intenta corregir M3. **Cero inversiones M3 con PWM positivo en los cinco
epsilon**. Sus intervalos E2C y baja repetibilidad siguen siendo una limitación
de planta. El resto de errores de dirección y movimiento con PWM0 se registra
en las métricas; las pruebas contrastan las transiciones con la API canónica.

El hash de pattern_curve permanece
`a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590`, y los límites
`dc643b5a656e5e9e21de6b61f0d2a614aafcfbca452c3e15acc14cbe448e9dc2`.
El manifiesto mantiene presencia de CFT y fit únicamente diagnóstica; la ruta
canónica no consume fit_C2. E0P/E2A/E2B/E2C no se sobrescriben ni reinterpretan.

Carpeta `matlab_code/analysis/paired_reference/e2d_results/`:

- `trajectories.mat`: 200×5 trazas y 200 basales originales, referencias y acciones.
- `step_traces.csv`: 58760 filas motor-paso, errores, raw histórico/intervenido,
  remapeo, q, flags de inhibición y descomposición del reward.
- `episode_metrics.csv`, `episode_motor_metrics.csv`: 1000 episodios y 4000
  episodio-motor; resúmenes global, sujeto, dirección, motor y sujeto/lado.
- `candidate_gates.csv`, `subgroup_degradations.csv`, `zeroed_actions.csv`,
  `pwm_distribution.csv`: gates y denominadores explícitos de todos los candidatos.
- `known_cycle_case_traces.csv`, `cycle_windows.csv`: casos conocidos y detector
  sobre todos los prefijos, con pares nuevos diferenciados de los basales.
- `fixed_reference_summary.csv`, `fixed_reference_traces.csv`,
  `local_counterfactual_map.csv`, `deadband_boundaries.csv`, `diagnostic_artifacts.mat`.
- Preregistro/hash, manifiesto E0P, resúmenes JSON, inventario de integridad,
  tests y manifiesto SHA256 de artefactos. Los tests previos se guardan en una
  subcarpeta E2D, sin regenerar los resultados E2C.
- `e2d_results.png` y `.svg`: figura exportable de tracking, ciclos e inactividad.

![Resultados E2D](../../matlab_code/analysis/paired_reference/e2d_results/e2d_results.png)

Reproducción, desde `EMG_Prosthesis_TD3/matlab_code`, proceso MATLAB nuevo:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');summary=runPairedReferenceE2D();"
python analysis/paired_reference/verifyE2DArtifacts.py
```

El inventario inicial ya existe y no se recaptura después de medir. El comando
regenera sólo E2D y sus regresiones; no ejecuta entrenamiento ni operaciones Git.

**107/107 tests**, ninguno fallido/incompleto: 13 E2A,24 E0P,22 E2B,22 E2C,26 E2D.
Los nuevos cubren epsilon0 en200, banda inclusiva, identidad fuera de banda,
remapeo original, planta, reward con primera acción previa, detector en1000
episodios, gates sintéticos, selección nula, determinismo e integridad histórica.

Una comprobación independiente con Python estándar reconstruye las 58760 filas,
4000 métricas episodio-motor, MSE/MAE/reward/acción, ciclos y gates. Error máximo
de reconstrucción reward: **1.39e-15**. Confirma que ningún epsilon cumple todos
los gates y SELECTED_EPSILON queda null, sin escoger un «mejor fallido».

## Cierre y límites

La zona muerta ensayada puede evitar órbitas concretas mediante PWM0, pero no
satisface conjuntamente los requisitos de estabilidad observada y conservación
de movimiento de E2D. El buen tracking global permanece apoyado; no se confunde
este rechazo con incapacidad general de control. La conclusión sólo cubre la
rejilla y muestra preregistradas, no todo epsilon posible ni cualquier intervención.

No se autoriza ni implementa otra solución, histéresis o etapa posterior. No se
integra el teacher privilegiado en la observación/actor ni se modifica la ruta
glove-free. Los límites de aprender ese control desde EMG siguen abiertos.

**E2D_RESULT=DEADBAND_NOT_SUFFICIENT. SELECTED_EPSILON=null.**
**RL_AUTHORIZED=NO. E3_PREPARED=NO. E3_EXECUTED=NO. MATEO_SANDRA_SEALED=YES.**
**HISTORICAL_HASHES_INTACT=YES. GIT_REPAIR_ATTEMPTED=NO. COMMIT=NO. PUSH=NO.**
