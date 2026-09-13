# E2G — Teacher–plant support alignment

**REFERENCE_CONTRACT_NOT_VALIDATED. RL_PILOT_AUTHORIZED=NO.**
El oracle estable mejor encontrado en E2F permanece válido. E2G localiza una
incompatibilidad computacional entre el mapa encoder→flex heredado y el soporte
registrado de la planta, sin evidencia suficiente para atribuirla a un límite
mecánico real o validar una recalibración del teacher.

La proyección diagnóstica elimina targets fuera del intervalo y conserva la
estabilidad de H5. Sin embargo, no aporta la calibración física faltante y M2
retiene sólo 36.1543 % del rango temporal en cierre y35.3076 % en apertura,
frente al mínimo preregistrado 50 %. **Fallan gates A y D.** No se adopta una
transformación para training, no se prueba alineación afín y no se prepara E3A.

## Estado, alcance e integridad

2026-09-07. Worktree existente `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`;
la grafía anidada solicitada no existe. Rama
`experiment/no-glove-paired-reference-td3`, HEAD
`165be049eb41fc41254435181c9857fe0f22ed1c`. Cambios recibidos E2C–E2F conservados;
archivos nuevos exclusivamente E2G. Sin reparación Git, cambio de rama, commit,
push, RL ni sandbox. E0P/E2A PASS, E2B FAIL, E2C CHARACTERIZED, E2D/E2E
NOT_SUFFICIENT y E1–E1D cerradas no cambian.

[Preregistro E2G](PREREGISTRO_E2G.md), SHA256
`a973ae8c177c1bd0f3b737d7223f35268e73c09610e247612ec0c15fdc106a07`,
congelado antes de distribuciones y contrafactuales. Mismos200 episodios
DEVELOPMENT,2938 pasos por controlador/11752 muestras motor-paso; no se abrieron
datasets nuevos para estas comparaciones. MATEO/SANDRA sellados.

**Tests: 196/196 = 169 históricos + 27 E2G.**
**740/740 hashes históricos intactos.** La comprobación independiente anterior
confirmó E2F:663 hashes/52 artefactos/169 tests. Los tests E0P conservan la regresión
784 casos con máximo error 1.164e-10; los13 tests causales E2A pasan.

## 1. Las coordenadas que realmente compara el reward

[AUDITORIA_COORDENADAS_E2G.md](AUDITORIA_COORDENADAS_E2G.md) contiene fuentes,
líneas, unidades declaradas, huecos de evidencia y procedencia por constante.

```text
Guante: números seriales/registro histórico (sin calibración angular demostrada)
 → suma de sensores por DoF: [anular+meñique, índice, pulgar, medio]
 → división [4092,2046,1023,2046], sin restar reposo ni escalar por sujeto
 → última fila de la ventana: reference_after utilizada en reward.

Encoder: cuentas firmadas q
 → abs(q)
 → suelo constante debajo de gap; recta gap→breakLimit; saturación superior
 → división por los mismos [4092,2046,1023,2046]
 → última fila: h(q_after).
```

La suma usa4/2/1/2 sensores por motor. Los divisores son 1023 multiplicado por esa
cantidad, una convención numérica; no prueban máximos articulares medidos. Los
datos del guante no se convierten a grados en esta ruta. M1 además mezcla dos
dedos humanos: una suma no identifica una postura única.

| Motor/dedo | gap | breakLimit | mínimo flex | divisor | h(0) | h máximo del grafo |
|---|---:|---:|---:|---:|---:|---:|
| M1 anular/meñique |7500|26500|1800|4092|.43988270|.72720813|
| M2 índice |3650|11500|900|2046|.43988270|.65502245|
| M3 pulgar |4000|8500|300|1023|.29325513|.86826276|
| M4 medio |3550|9000|900|2046|.43988270|.72054086|

En el tramo lineal, h=L/U+(1−L/U)(abs(q)−gap)/(breakLimit−gap).
El suelo positivo es una consecuencia del mapa antes de cualquier límite de
planta. En holgura puede moverse el encoder sin cambiar h. El mapa global tiene
techo 1, pero el soporte empírico auditado no alcanza las anclas correspondientes.

**Procedencia:** constantes HEREDADAS; breakLimit coincide con firmware, pero
la procedencia física de esos números es UNKNOWN. Los mínimos se describen
como reposo sin registros de calibración; recta/abs/agregación son el modelo
HEURÍSTICO heredado. Las curvas son datos empíricos de encoder procesados,
no mediciones pareadas con guante. No se ha demostrado equivalencia física de
teacher y h(q). Esto no demuestra que sean necesariamente incompatibles en toda
postura: indica que la calibración requerida no es verificable aquí.

El encoder normalizado de markov52 usa q/breakLimit y **no es h(q)**. Guante y
h(q) siguen en reward/tracking; el teacher permanece en reset/disponibilidad y
terminación histórica. No se han modificado actor, state, reward, runtime E2A
ni su ejecución EMG-only. La proyección existe sólo en copias offline.

## 2. Distribuciones y soporte

Fracciones macro: media temporal por episodio-motor, repeticiones por
sujeto/lado/motor, media de grupos. Cuantiles: por muestras, interpolación
lineal, con ponderación distinta explícita. No confundir una distribución de
estados únicos del grafo con la visitación temporal de una política.

| Motor | Debajo | Dentro | Encima | Fuera |
|---|---:|---:|---:|---:|
| M1 | 14.0431 % | 55.2616 % | 30.6953 % | 44.7384 % |
| M2 | 7.5103 % | 28.4338 % | 64.0558 % | 71.5662 % |
| M3 | 13.7446 % | 63.2881 % | 22.9673 % | 36.7119 % |
| M4 | 18.3945 % | 48.9514 % | 32.6541 % | 51.0486 % |

Global: 13.4231 % debajo,48.9837 % dentro,37.5932 % encima; **51.0163 % fuera**.
La fracción bruta por muestras es 50.2297 %, diferente por duración de episodios.

Cuantiles del teacher original:

| Motor | min | p1 | p5 | mediana | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|
| M1 | 0.247801 | 0.294993 | 0.365518 | 0.612292 | 0.932099 | 0.968140 | 0.986804 |
| M2 | 0.259042 | 0.347019 | 0.401197 | 0.751222 | 0.999022 | 1.000000 | 1.000000 |
| M3 | 0.197458 | 0.217986 | 0.257087 | 0.532747 | 0.999022 | 1.000000 | 1.000000 |
| M4 | 0.266862 | 0.305528 | 0.366080 | 0.614614 | 0.960973 | 0.999511 | 1.000000 |

Los mismos siete cuantiles de teacher/P2/H5 original/H5 proyectado y referencia
proyectada, por motor, sujeto, dirección y todas sus combinaciones, están en
`coordinate_distributions.csv`. `graph_h_distributions.csv` registra estados
únicos del grafo: es el mismo soporte para los sujetos, no una distribución
empírica nueva por persona. `support_and_transformation.csv` conserva las
fracciones y cambios en todos esos estratos, no sólo el promedio global.

## 3. M2: predomina el techo del soporte representado

M2 tiene 64.0558 % de targets por encima y 7.5103 % por debajo. Su teacher mediano
.75122190 ya supera el techo .65502245. El bound exterior explica 98.3447 % de su
suelo local E2F; globalmente explica 82.4818 %.

El escalador común sólo divide ambas magnitudes por el mismo U positivo: no
crea por sí solo la incompatibilidad de intervalos, que ya existe antes de esa
división. El problema observable está en el mapa encoder→flex y el recorrido
registrado frente a los valores de sensores del teacher. El h alcanzado nunca
llega a su saturación superior 1; no predomina un clamp superior activo de h.
Los cuantiles del teacher M2 llegan a1, pero la falta de calibración no permite
decidir si ese valor corresponde a una postura comparable. No se diagnostica
un offset de guante erróneo ni un límite mecánico sólo a partir del scatter.

| Fuente M2 | q máximo | h en ese máximo |
|---|---:|---:|
| Grafo operativo E2F |6665.1666667|.6550224455|
| Todas las curvas promedio |6665.6666667|.6550581218|
| Repeticiones/CSV originales |6821|.6661415470|
| Ancla histórica breakLimit |11500|1|

La diferencia grafo–promedio es sólo 0.5 cuentas. Incluso las adquisiciones
completas quedan muy por debajo del ancla heredada. No corresponde atribuir
el desajuste principal sólo a Ts, cuantización o poda de estados. Tampoco se
demuestra que 6821 sea el límite mecánico real. M2 cierre PWM64 tiene avg máximo
3598<gap3650: toda esa curva se convierte en el suelo de h aunque el encoder
cambie. No demuestra inmovilidad física del dedo.

[AUDITORIA_SOPORTE_E2G.md](AUDITORIA_SOPORTE_E2G.md) separa grafo/avg/data/raw y
límites de firmware, con 56 filas por motor/PWM/dirección y fuentes.56/56 límites
coinciden con extremos de data; el procesamiento histórico recorta y promedia.
El cierre del grafo es un bound para sus semillas y contrato, no para cualquier
q inicial ni para el hardware. Tampoco cada punto del intervalo es alcanzable.

Cuantiles M2:

| Señal | min | p1 | p5 | mediana | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|
| teacher | 0.259042 | 0.347019 | 0.401197 | 0.751222 | 0.999022 | 1.000000 | 1.000000 |
| projected | 0.439883 | 0.439883 | 0.439883 | 0.655022 | 0.655022 | 0.655022 | 0.655022 |
| p2H | 0.439883 | 0.439883 | 0.439883 | 0.628517 | 0.655022 | 0.655022 | 0.655022 |
| originalOracleH | 0.439883 | 0.439883 | 0.439883 | 0.643344 | 0.655022 | 0.655022 | 0.655022 |
| projectedOracleH | 0.439883 | 0.439883 | 0.439883 | 0.641925 | 0.655022 | 0.655022 | 0.655022 |

![Soporte y scatter M2](../../matlab_code/analysis/paired_reference/e2g_results/e2g_support.png)

El scatter usa el h más próximo entre estados del grafo completo; el error
firmado es bestH−teacher. Es una cota optimista sin tiempo de llegada, distinta
del destino local de un paso y de la proyección continua al intervalo.

**SUPPORT_MISMATCH_CAUSE=MIXED:** mapa h(q) heredado y soporte empírico de planta
no alineados. El origen físico de esa combinación sigue UNKNOWN; no se afirma
MECHANICAL_RANGE_LIMIT ni una calibración teacher equivocada sin evidencia.

## 4. Contrafactual permitido y conservación de información

PROJECTION=clip(reference,h_min,h_max), por motor y únicamente en copias de
reference_before/after. Es la alteración escalar mínima que entra al intervalo
del soporte demostrado. No ajusta anclas ni garantiza alcanzabilidad interior.
AFFINE_ALIGNMENT_TESTED=NO: faltan posturas emparejadas independientes; no se
ajusta una recta a cuantiles o al MSE para producir un resultado favorable.

| Motor | Muestras modificadas, macro | Cambio absoluto medio macro | p95 por muestras | máximo |
|---|---:|---:|---:|---:|
| M1 | 44.7384 % | 0.04577356 | 0.20489108 | 0.25959539 |
| M2 | 71.5662 % | 0.13259296 | 0.34400004 | 0.34497755 |
| M3 | 36.7119 % | 0.02535128 | 0.13075973 | 0.13173724 |
| M4 | 51.0486 % | 0.05026664 | 0.24043177 | 0.27945914 |

Global:fracción modificada **51.0163 % macro**
(50.2297 % bruta), cambio medio macro
0.063496109962, p95 0.276037827222,
máximo 0.344977554464. Estos valores están en coordenadas
históricas adimensionales, no grados físicos.

| Motor | Dirección | Mediana de rango temporal conservado | Aumento referencias constantes | Tendencia firmada retenida |
|---|---|---:|---:|---:|
| M1 | Cierre | 58.8472 % | 1.0 pp | 99.0000 % |
| M1 | Apertura | 62.4021 % | 0.0 pp | 100.0000 % |
| M2 | Cierre | 36.1543 % | 3.0 pp | 97.0000 % |
| M2 | Apertura | 35.3076 % | 3.0 pp | 97.0000 % |
| M3 | Cierre | 80.9124 % | 2.0 pp | 97.9798 % |
| M3 | Apertura | 82.6132 % | 2.0 pp | 100.0000 % |
| M4 | Cierre | 63.8539 % | 1.0 pp | 99.0000 % |
| M4 | Apertura | 64.4914 % | 0.0 pp | 100.0000 % |

M2 incumple el mínimo 50 % en ambas direcciones. El clipping no vuelve todos
los episodios constantes, pero comprime de forma excesiva su amplitud temporal
y acumula gran parte del teacher en el techo. Los otros límites preregistrados
de referencias constantes (+5 pp) y signo (95 %) pasan. No se baja el umbral.

## 5. Oracle y evaluación cruzada

Mismo H5 exacto E2F, reward .01/.05, acciones 15, Ts=.2, samplingAPI=.14, planta
canónica y q0; no guard, deadband ni cambio de controlador/planta. El oracle
continúa privilegiado y no es evidencia de información EMG disponible.

| Política | Referencia con que se evalúa | MSE macro | Reward macro |
|---|---|---:|---:|
| ORIGINAL | ORIGINAL | 0.015921991669 | -0.017626400577 |
| ORIGINAL | PROJECTED | 0.002556053466 | -0.004260462374 |
| PROJECTED | ORIGINAL | 0.016911201768 | -0.018274811066 |
| PROJECTED | PROJECTED | 0.002633584833 | -0.003997194130 |

**Comparar sólo la diagonal cambia el problema.** La política PROJECTED empeora
al evaluarla contra el teacher ORIGINAL. Su MSE propio reducido no prueba mejor
control original ni calibración válida. Frente al teacher PROJECTED, el oracle
original incluso tiene MSE algo menor; el nuevo obtiene mejor reward por sus
penalizaciones de acción. H5 minimiza coste finito, no exclusivamente MSE.

| Estimando del suelo de un paso (MSE) | ORIGINAL | PROJECTED |
|---|---:|---:|
| Desde exactamente los estados P2 originales |0.015539734967|0.002651285367|
| Desde estados visitados por cada oracle |0.015064532889|0.002205984852|
| Bound exterior a la envolvente |0.012817458627|0|
| Fracción targets fuera |51.0163 %|0 %|

Se guardan 15 destinos por estado en cuatro tablas de alcanzabilidad,705120 filas.
El primer contraste aísla referencia manteniendo q de P2. El segundo mezcla
transformación y nueva visitación y es descriptivo. El floor no es un mínimo
global multietapa. El criterio50 % de E2F no se vuelve a aplicar en E2G.

PROJECTED: 0 ciclos finales,0 ventanas alternantes,0 trayectorias periódicas 2..8,
0 retrocesos M3,0 movimientos PWM0;20/20 replays fijos terminan con q constante en
las últimas 20 transiciones y sin órbitas. Es estabilidad en estos casos, no
un teorema universal. MSE/MAE/reward y componentes, PWM, flat/no-motion están
disponibles por motor/sujeto/dirección en las tablas de métricas.

## 6. Gates y decisión

| Gate | Resultado |
|---|---|
| A: coordenadas físicamente defendibles | **FAIL: calibración pareada no demostrada** |
| B: target exterior no domina | PASS numérico: 0 outside; bound 0/suelo P2=.0026512854 |
| C: oracle estable en muestra y 20 fijos | PASS |
| D: variación útil conservada | **FAIL: M2 cierre 36.1543 %, apertura 35.3076 % <50 %** |
| E: causalidad E2A intacta | PASS:13/13 tests y fuentes intactas |
| F: tests/hashes/sellados | PASS:196/196 tests;740/740 hashes; sellados |

**REFERENCE_TRANSFORMATION_SELECTED=NONE_FOR_TRAINING.** La proyección queda
sólo como diagnóstico. **E2G_RESULT=REFERENCE_CONTRACT_NOT_VALIDATED.**
**RL_PILOT_AUTHORIZED=NO. E3A_PREPARED=NO. E3A_EXECUTED=NO.**

Información necesaria: posturas/magnitudes funcionales identificadas por motor
con encoder y guante emparejados; origen y repetibilidad de cero, holgura y
extremos; correspondencia de sensores/DoF; configuración mecánica/firmware de
las curvas respecto a los límites heredados. Para sostener una recta hacen
falta anclas independientes y evidencia intermedia, no sólo endpoints elegidos
del dataset. Nada de esa calibración se ejecuta aquí. No se propone otro
reescalado ad hoc ni se modifica teacher/h/reward/planta para rescatar E2G.

## 7. Agente futuro y visualización

Mantener inicialmente TD3 histórico por continuidad si un contrato posterior
permite el piloto. Challenger estructural futuro: **FACTORIZED_CATEGORICAL**,
4 cabezas × 15 acciones, porque ésta es la acción que recibe la planta canónica
y optimiza el oracle; evitar enumeración conjunta 15^4. No se implementa ahora.
SAC queda como challenger útil si posteriormente se caracteriza PWM fino.

El objetivo eventual sigue siendo apertura/cierre estable condicionado por EMG
y estado mecánico, con guante como teacher durante training. E1–E1D no demostraron
trayectoria individual continua EMG específica suficiente; no se promete esa
reconstrucción ni se reabre decoder. No hay especificación E3A ni training.

HandKinematicViewer sólo podría visualizar pasivamente trazas canónicas si una
futura E3A da señal positiva: P2/oracle/Agent7250/nuevoTD3 en mismos episodios.
Integración diferida; ningún código sandbox ni plantaS4 importados.

## 8. Artefactos, reproducción y límites de integridad

Carpeta `matlab_code/analysis/paired_reference/e2g_results`: trazas MAT/CSV;
distribuciones y soporte;variación;matriz 2×2; métricas y alcanzabilidad;
20 fijos; auditoría de curvas/raw; manifiesto E0P; gates/JSON; tests/hashes;
figura PNG y SVG. Fuentes E2G y 27 tests nuevos; helpers históricos sin editar.

El inventario inicial 740 no se recaptura. De76CSVraw inspeccionados para soporte,
33 tenían hash en ese inventario:33/33coinciden.43 carecían de baseline histórico;
se declara esa limitación sin ampliar retroactivamente el inventario. El artefacto
guarda 67 hashes de originales seleccionados:67/67coinciden. Esto no acredita
trazabilidad física de la adquisición. Los scripts de soporte quedan conservados.

Desde `EMG_Prosthesis_TD3/matlab_code`, MATLABR2023b y Python3 estándar:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');runPairedReferenceE2G;"
python analysis/paired_reference/verifyE2GArtifacts.py
```

No ejecutar e2gCaptureHistory otra vez. El runner sólo reconstruye E2G y dirige
salidas de regresiones a E2G. No entrena ni opera Git. La comprobación Python
independiente reconstruye 23504 filas motor-paso,705120 destinos y 32 decisiones
Bellman H5; error máximo reconstrucción reward 8.19e-16. La figura requirió
tipado explícito de etiquetas ALL/número al importar CSV; se corrigió sólo el
exportador gráfico y se verificó de nuevo, sin cambiar mediciones ni tests.

**MATEO_SANDRA_SEALED=YES. HISTORICAL_HASHES_INTACT=YES (740 archivos inventariados).
GIT_REPAIR_ATTEMPTED=NO. PUSH=NO.**
