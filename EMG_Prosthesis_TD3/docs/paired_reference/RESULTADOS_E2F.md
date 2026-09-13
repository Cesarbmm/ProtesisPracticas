# E2F — Oracle de controlabilidad y auditoría del espacio de acción

**Existe una política privilegiada estable y claramente mejor que P2 dentro
del MDP actual. Sin embargo, RL_PILOT_AUTHORIZED=NO bajo los gates preregistrados.**

H5 reduce MSE de .0254003364 a **.0159219917 (37.3158 %)** y mejora reward de
−.0327283771 a **−.0176264006 (46.1434 %)**. Los20casos fijos alcanzan una estrategia
estable, sin órbitas; no hay ciclos finales, nuevas trayectorias periódicas ni
inversiones M3. Ningún sujeto, motor o dirección se degrada >5 %.

Falla exclusivamente el gate científico3: el mínimo error de un paso desde los
estados P2 conserva **61.1792 %** de su MSE, frente al máximo preregistrado50 %.
No se cambia el umbral tras medir. Este FAIL de preparación para RL **no significa
incapacidad general de control**, ni invalida la política mejor que acabamos de
encontrar. El campo CURRENT_MDP_CONTROL_FEASIBLE se utiliza como resultado de los
gates completos de E2F; STABLE_BETTER_POLICY_FOUND=YES conserva la distinción.

La explicación posterior del suelo local apunta sobre todo al soporte conjunto
teacher/h(q)/planta: **51.0163 %** de los targets queda fuera de la envolvente h(q)
del grafo auditado; ese límite explica **82.4818 %** del suelo de error local.
No se atribuye ese residuo exclusivamente a la separación entre niveles PWM.

## Estado, preregistro e integridad

Preregistro: 2026-09-06, antes de comparar oracles; cierre/verificación: 2026-09-07.
Worktree existente `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`; rama
`experiment/no-glove-paired-reference-td3`; HEAD conservado
`165be049eb41fc41254435181c9857fe0f22ed1c`. La grafía anidada solicitada no es
una carpeta existente. E2C–E2E locales recibidos se auditaron y conservaron.

[PREREGISTRO_E2F.md](PREREGISTRO_E2F.md), SHA256
`52d2b643ca5f717b14c36c2a2638767cfe8a4a5f928802d559849d1128e3a177`.
**169/169 tests: 144 históricos +25 nuevos. 663/663 hashes históricos intactos.**

E0P/E2A PASS, E2B FAIL, E2C CHARACTERIZED, E2D DEADBAND_NOT_SUFFICIENT y E2E
REVERSAL_GUARD_NOT_SUFFICIENT permanecen congelados. E1–E1D cerradas. Sin reparar
Git, cambiar rama, commit ni push. Sin sandbox, hardware, training o nueva heurística.
MATEO/SANDRA no se abrieron ni compararon; los tests históricos conservan BLANCA
y fixtures autorizados. Nuevas mediciones sólo reutilizan el MAT E2B existente.

## 1. Qué permite la interfaz real

La [auditoría de interfaz y separabilidad](AUDITORIA_INTERFAZ_E2F.md) identifica
código y líneas exactas. Controller acepta enteros entre −255 y255 y serializa
hexadecimal; el firmware decodifica incluso el ejemplo `B04` (PWM4). No restringe
el parser a los niveles históricos. La ruta real de remap redondea raw×255; la
ruta de simulación cuantizada selecciona la lista histórica.

**HISTORICAL_LEVELS_PHYSICAL_REQUIREMENT=NO según el código disponible.**
**INTEGER_PWM_AVAILABLE=YES en protocolo/firmware de alto nivel.** La biblioteca
MotorControl modificada no está íntegra/versionada en este checkout: realización
eléctrica del firmware instalado y movimiento útil con PWM intermedios = UNKNOWN.
No se presenta un protocolo fino como una planta fina ya medida.

También se documenta la convención histórica 3F=63,5F=95,... frente a las etiquetas
internas64,96,...,256. El comando255 usa sp_FF; E0P preservó esa representación.
No se corrige, interpola ni crea ninguna curva en E2F.

## 2. Separabilidad y definición exacta del oracle

ORACLE_SEPARABLE=YES para el simulador/coste auditado. Cada motor tiene transición
q_i_next=f_i(q_i,PWM_i), transformación h_i independiente y acciones independientes
con unifyActions=false. El reward es la media de cuatro costes negativos:

```text
error_i = h_i(q_i_next) - reference_after_i
coste_i = error_i^2 + .01*u_i^2 + .05*(u_i-u_previous_i)^2
u_i = PWM_i/255
```

La penalización delta acopla tiempos del mismo motor, no motores. La DP incluye
(q_i,u_previous_i); eliminar esa memoria resolvería otro problema. Teacher/done
es un horizonte exógeno congelado. Las pruebas contrastan transición vectorial
con cuatro transiciones independientes y el óptimo conjunto con la suma de mínimos.
No se infiere independencia mecánica/eléctrica del hardware.

Se construyó por la API canónica real el cierre finito de estados sembrado con
q0 y estados de los tres comparadores, más los pares E2C:

| Motor | Semillas | Estados cerrados | Aristas |
|---:|---:|---:|---:|
| M1 | 241 | 4646 | 69690 |
| M2 | 61 | 635 | 9525 |
| M3 | 102 | 823 | 12345 |
| M4 | 45 | 613 | 9195 |

Total **6717 estados /100755 aristas**. Claves double bit-exactas, sin poda ni
aproximación de planta. Se mantienen las15acciones incluso si comparten destino.
Orden fijo de desempate:0,−64,+64,−96,+96,...,−255,+255.

Horizontes **H=[1,2,3,5]**, **H5 primario antes de medir**. H1 es miope; H2/H3
añaden previsión; H5 ve hasta un segundo nominal de teacher futuro. DP exacta
con coste acumulado sin descuento y terminal0; se trunca al final teacher y se
aplica sólo la primera acción. No es el óptimo de episodio completo ni una prueba
de equivalencia con un objetivo TD3 de descuento distinto. El raw representativo
PWM/255 atraviesa el remapeo original, sin guard o deadband.

Bellman coincide exactamente con enumeración exhaustiva H1/H2/H3 en12casos,
incluida primera acción. La verificación Python independiente contrasta además
128decisiones mediante recurrencia propia. Las transiciones de todos los rollouts
oracle se contrastaron con la API real, además de consultar el grafo.

## 3. Comparación en los mismos 200 episodios

Comparadores congelados ZERO/P2/AGENT7250:600episodios; oracles:800episodios.
Todos comparten referencias before/after, q0 y horizonte teacher. P2 usa teacher
previo; el oracle puede ver target posterior y futuro. No se atribuye esa ventaja
de información a una política desplegable. Agent7250 no se vuelve a cargar ni se
compara con métricas históricas de su entrenamiento; es sólo diagnóstico E2B.

Agregación como E2B: media temporal por episodio, episodios por sujeto/lado y
media de20grupos. Los CSV conservan sujeto, motor y dirección. Datos importados:
transiciones canónicas exactas y reward reconstruido dentro de1e-12.

| Controlador | MSE | MAE | Reward | Ciclos finales |
|---|---:|---:|---:|---:|
| Cero | .0927042149 | .2413793688 | −.0927042149 | 0 |
| P2 | .0254003364 | .1191157075 | −.0327283771 | 2 |
| Agent7250 | .0471052724 | .1661715774 | −.0590142433 | 0 |
| Oracle H1 | .0190087671 | .1043177623 | −.0208382441 | 0 |
| Oracle H2 | .0167185440 | .0942699593 | −.0182695798 | 0 |
| Oracle H3 | .0163202118 | .0917798130 | −.0179422804 | 0 |
| **Oracle H5** | **.0159219917** | **.0899861692** | **−.0176264006** | **0** |

H5 mejora tracking y reward, con0/10sujetos,0/4motores y0/2direcciones degradados
>5 %. La definición usa MSE O reward, no un promedio que oculte degradación.

| Métrica H5 | Valor |
|---|---:|
| actionL2 | .0630235549 |
| deltaActionL2 | .0214834672 |
| Saturación | .4492643 % |
| PWM alto, media macro | 8.6764886 % |
| tracking term | −.0159219917 |
| action penalty | .0006302355 |
| delta-action penalty | .0010741734 |
| flat_response | 4.125 % |
| action_no_motion | 31.5190017 % |
| responseRange h(q) | .3115013916 |

Flat/no-motion permanecen diagnósticos en E2F; no se importan retrospectivamente
los gates de neutralización E2D/E2E. La pregunta cambió a viabilidad de una política.
La proporción no-motion por episodio divide comandos activos sin movimiento por
todos los activos antes de agregar; no equivale a promediar cuatro proporciones
de motor sin ponderar. Cero no tiene comandos activos: se conserva NaN.

H5 presenta0ciclos finales y0trayectorias periódicas detectadas;0inversiones M3
y0movimientos con PWM0. Las395inversiones del comparador Agent7250 son las
históricas E2B, no una patología nueva creada por el oracle. Distribuciones PWM,
ventanas de todos los prefijos y resultados de cada H permanecen exportados.

## 4. Los ciclos E2C no son inevitables

En los20replays fijos, **todos los H ensayados** encuentran una estrategia
estable; H5 conserva el papel primario. P2 tiene20órbitas; los oracles0, incluidos
los detectores de periodicidad con pausas. Estabilidad aquí significa últimas20
transiciones sin cambio de q, sin órbita y MSE no peor que P2 fijo correspondiente.
No significa error cero ni estabilidad global ante perturbaciones no ensayadas.

Ejemplos del teacher fijo primario:

| Motor / inicio | Destino H5 | MSE final H5 | MSE final P2 |
|---|---:|---:|---:|
| M3 / estado bajo1541.6667 | 7101.8333 | .0016346902 | .1056212527 |
| M3 / estado alto7532.5 | 7532.5 | .0116789960 | .1056212527 |
| M4 / estado alto6049.75 | 6049.75 | .0026154528 | .0224778278 |
| M4 / estado bajo2976.3333 | 5710.6667 | .0002654491 | .0224778278 |

En estos ejemplos los últimos20PWM son cero. Mantener una posición cercana al
target evita pagar una corrección que sobrepasa el objetivo; esto surge de
minimizar el coste histórico, sin introducir deadband ni confirmar reversiones.
El arranque en estados distintos puede conducir a soluciones distintas por el
horizonte corto y el coste de maniobrar, aunque haya mejores posiciones globales.

Las trazas de BLANCA1cierreM3 e IVANNA104aperturaM4 con teacher móvil se guardan
para todos los comparadores/H. No se confunde su ausencia de ciclos detectados
con una prueba matemática de estabilidad universal.

## 5. Alcanzabilidad y gate que bloquea el piloto

Se evaluaron **1233960 destinos**:7controladores×11752comandos motor-paso×15PWM.
Cada alternativa usa el mismo q_before y reference_after de ese paso. Los CSV
incluyen índices exactos del grafo, q, PWM, destino, error y mínimo por estado.

En estados visitados por H5:

- REACHABLE_TARGET_FRACTION=**46.0819255 %**: existe un destino que mejora
  estrictamente el error actual. No significa fracción de targets exactos.
- WITHIN_005_REACHABLE_FRACTION=**49.3090671 %**: algún destino queda a<=.05.
- MINIMUM_REACHABLE_ERROR=**.0853168526**, media macro del menor error absoluto
  de un paso; MSE correspondiente=.0150645329. El mínimo global individual es0.
- Distribución por pasos sin ponderación macro: mediana .0494506, p90 .2221809,
  p95 .2760378 y máximo .3449776. Su media .0831108 difiere por ponderación.

La fracción de mejora depende de los estados visitados: un controlador ya cerca
del target puede tener menos pasos mejorables. Por eso se reportan también los
estados ya en banda, mínimos y comparadores. Los campos bestErrorMin/Max de los
resúmenes macro son medias de extremos por episodio-motor; los extremos globales
y percentiles reales están separados en reachability_error_distribution.csv.

El gate3 utiliza **estados P2 fijados**, no estados elegidos favorablemente por
H5: MSE mínimo de un paso=.0155397350; dividido por MSE P2=.0254003364 da
**.6117924873 > .5**. Ese50 % fue fijado antes de medir como operacionalización
de que la resolución no domine el error. No procede de una nueva selección tras
ver los resultados. No se sustituye por un umbral que permita el piloto.

## 6. Diagnóstico explicativo del soporte, posterior al gate

Para explicar qué restringe la acción/planta, se añadió un análisis descriptivo
de los mismos grafos/targets ya medidos, **después** de obtener el gate. No modifica
preregistro, selección, controller, horizonte ni decisión. Calcula la envolvente
de h(q) del grafo completo y un bound optimista aun permitiendo cualquier estado
de ese grafo, sin coste ni restricción de tiempo de llegada.

| Motor | Envolvente h(q) | Targets fuera, macro | MSE mínimo local P2 |
|---|---|---:|---:|
| M1 | [.43988270,.72720813] | 44.7384 % | .0081700361 |
| M2 | [.43988270,.65502245] | **71.5662 %** | **.0337977737** |
| M3 | [.29325513,.86826276] | 36.7119 % | .0106697237 |
| M4 | [.43988270,.72054086] | 51.0486 % | .0095214064 |

Global:51.0163 % fuera (13.4231 % por debajo,37.5932 % por encima). El bound
de MSE por estar fuera de envolvente es.0128174586, **82.4818 %** del mínimo
local. El mínimo sobre todos los puntos del grafo es.0130357004. Para M2,
el bound fuera de envolvente explica98.3447 % de su suelo local.

La restricción concreta pendiente es la **compatibilidad entre teacher, h(q) y
recorrido representado por patternCurveCanonical**, especialmente M2. No se
demuestra que cambiar sólo la separación PWM arregle ese rango. Tampoco se
demuestra que las curvas no medidas a PWM intermedios amplíen el recorrido. No se
reescalan teacher/h(q), alteran límites, ajustan curvas ni tocan reward en E2F.

El grafo incluye todas las semillas auditadas y su cierre bajo estas acciones;
su envolvente no es un bound de hardware universal. Un bound de un paso desde
estados P2 no es un teorema de imposibilidad multietapa; la estrategia H5 mejor
encontrada debe permanecer visible junto al bloqueo del protocolo de piloto.

## 7. Decisión preregistrada y familia de agente

| Gate | Resultado |
|---|---|
|1:20fijos estables, sin órbitas;0ciclos finales en200 | PASS |
|2:MSE mejora>=10 %, reward no peor; coherencia por grupos | PASS |
|3:suelo local P2<=50 % de su MSE | **FAIL:61.1792 %** |
|4:sin nuevas órbitas periódicas, M3rev0, PWM0 sin movimiento | PASS |
|5:tests, exactitud, hashes, sellados | PASS |

**ORACLE_BEATS_P2=YES. STABLE_BETTER_POLICY_FOUND=YES.**
**CURRENT_MDP_CONTROL_FEASIBLE=NO según el conjunto de gates E2F.**
**RL_PILOT_AUTHORIZED=NO. E3A_PREPARED=NO. E3A_EXECUTED=NO.**

La [investigación de agentes](AUDITORIA_AGENTE_E2F.md) recomienda mantener **TD3
histórico** como principal y **SAC continuo** como challenger conceptual: continuidad
experimental y soporte de PWM entero fino en protocolo. Ambos siguen enfrentando
el cuantizador discreto de la planta actual. Un crítico continuo aproxima mesetas
y fronteras de acción; SAC no elimina esa dificultad por añadir entropía.

La guía oficial R2023b documenta TD3/SAC continuos. Una política categórica
factorizada4×15 evita15^4salidas, pero no es un reemplazo directo documentado de
rlPPOAgent con cuatro cabezas; exigiría un agente/bucle personalizado. No se
atribuye a R2023b soporte discreto/híbrido añadido a SAC en documentación actual.
Véanse fuentes primarias y limitaciones en la auditoría enlazada. No se implementa
ni entrena ninguna familia nueva.

El objetivo eventual sigue siendo **apertura/cierre estable condicionado por EMG
y estado mecánico, supervisado por reward de glove durante training**. El oracle
ve teacher futuro; su éxito no demuestra que markov52 permita inferirlo. E1–E1D
no demostraron información EMG continua específica suficiente; no se promete
reproducir cada trayectoria individual ni se reabre decoder/guante virtual.

## 8. Artefactos y reproducción

Carpeta matlab_code/analysis/paired_reference/e2f_results:

- graphs.mat, graph_edges.csv: cierre exacto por motor y100755aristas.
- trajectories.mat y step_traces.csv:1400episodios/82264filas motor-paso.
- Métricas por episodio/motor, sujeto, dirección, motor, macro; PWM, ventanas,
  periodicidad, degradaciones y primary_gates.csv/JSON.
- reachability_<controller>.csv:15destinos por estado, índices exactos; resúmenes,
  distribuciones globales y diagnóstico de soporte independiente.
- fixed_trajectories.mat, fixed_reference_summary/traces.csv y casos E2C.
- Bellman contra enumeración, manifiesto E0P, hashes históricos y de artefactos,
  tests, resumen JSON y figuras PNG/SVG.

![Resultados E2F](../../matlab_code/analysis/paired_reference/e2f_results/e2f_results.png)

Desde EMG_Prosthesis_TD3/matlab_code, MATLABR2023b y Python3 estándar:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');summary=runPairedReferenceE2F();"
python analysis/paired_reference/verifyE2FArtifacts.py
```

El inventario inicial no se recaptura. El runner reconstruye E2F y dirige salida
de regresiones a E2F; no entrena ni opera Git. El verificador independiente
reconstruye reward/acción/métricas, todos los destinos, ciclos y128decisiones
Bellman con recurrencia propia. Error máximo reward por serialización:1.50e-15.
Tests **169/169**; históricos **144/144**; nuevos **25/25**; hashes **663/663**.

Sólo recomendación futura: HandKinematicViewer pasivo con trazas canónicas de P2,
oracle, Agent7250 y un eventual agente. Integración diferida; no se importa código
sandbox ni planta S4, ni se usa visualización para cambiar training.

**MATEO_SANDRA_SEALED=YES. GIT_REPAIR_ATTEMPTED=NO. COMMIT=NO. PUSH=NO.**
