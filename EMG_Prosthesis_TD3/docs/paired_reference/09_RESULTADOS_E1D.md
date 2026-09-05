# ETAPA E1D — Calibración supervisada del sujeto · Resultados

**Fecha:** 2026-09-05 · **Rama:** `experiment/no-glove-paired-reference-td3` · **SHA de inicio:** `1f254c67`

> **Veredicto: `E1D_RESULT = E1D_FAIL`.** Pasa 3 de 8 condiciones del gate.
> **`FINAL_TEST_EXECUTED = NO`.** MATEO y SANDRA siguen sellados.
> Se cierra la línea de guante virtual con este dataset.

---

## 1. Formulación

```
GLOVE-ASSISTED CALIBRATION  +  GLOVE-FREE OPERATION
```

Durante calibración: EMG + guante. Durante evaluación: decoder congelado, sin leer guante; el
guante de evaluación es sólo verdad de terreno offline.

## 2. Resultado principal — CV anidada

Selección anidada **conjunta** de presupuesto y `lambda_personal`: para cada fold la configuración
se elige minimizando el MSE medio sobre los otros nueve.

| | MSE | mejora |
|---|---|---|
| A ridge global | 0.040639 | — |
| media de calibración | 0.040534 | — |
| media de train | 0.041368 | — |
| **C personalizado (anidado)** | **0.036353** | **+10.5 % vs A** · **+10.3 % vs media de calibración** |
| D gesto+fase (`DIAGNOSTIC_ORACLE`) | 0.018365 | — |

Umbrales preregistrados: **20 %** frente a A y **15 %** frente al predictor media. **No se alcanzan
ninguno de los dos.** Mediana de la mejora por sujeto: +11.1 %. Sujetos que mejoran: **7 de 10**
(umbral 8).

El oráculo gesto+fase sigue siendo **el doble de bueno** que el mejor decoder personalizado.

## 3. Curva de presupuesto

| N por gesto | episodios | segundos | A global | media cal. | B solo sujeto | C personalizado | C vs A |
|---|---|---|---|---|---|---|---|
| 1 | 2 | 6.1 | 0.040639 | 0.039063 | 0.034423 | 0.034184 | +15.9 % |
| 2 | 4 | 12.2 | 0.040639 | 0.039417 | 0.034743 | 0.034432 | +15.3 % |
| 5 | 10 | 30.5 | 0.040639 | 0.039552 | 0.034312 | 0.033935 | +16.5 % |
| 10 | 20 | 61.0 | 0.040639 | 0.039963 | 0.033054 | **0.032608** | **+19.8 %** |
| 20 | 40 | 122.0 | 0.040639 | 0.040368 | 0.034497 | 0.034070 | +16.2 % |
| 50 *(diagnóstico, 5.08 min, fuera del límite)* | 100 | 305.0 | 0.040639 | 0.039129 | 0.031570 | 0.031467 | +22.6 % |

Tres lecturas:

1. **La curva es casi plana.** De 6.1 s a 305 s de calibración —cincuenta veces más datos— el MSE
   baja de 0.034184 a 0.031467, un 8 %. No es un problema de cantidad de datos.
2. **No es monótona:** N=20 es peor que N=10. Las diferencias entre presupuestos están dentro del
   ruido.
3. **B ≈ C.** El ridge entrenado *sólo* con la calibración del sujeto (B) casi iguala al
   personalizado regularizado (C): 0.033054 frente a 0.032608 con N=10. El prior poblacional aporta
   muy poco, coherente con que el ridge global apenas superaba a la media en E1.

El mejor presupuesto dentro del límite (N=10, 61 s) da +19.8 %, que **tampoco** alcanza el 20 %.
Con selección anidada honesta la cifra cae a +10.5 %.

## 4. Detalle por sujeto (presupuesto modal N=5, 30.5 s)

| sujeto | A global | A + intercepto | media cal. | C personalizado | C vs A |
|---|---|---|---|---|---|
| BLANCA | 0.034378 | 0.035846 | 0.038481 | 0.034499 | −0.4 % |
| CECILIA | 0.042895 | 0.045646 | 0.049304 | 0.054263 | **−26.5 %** |
| DENIS | 0.024375 | 0.022077 | 0.022296 | 0.020631 | +15.4 % |
| EMILIA | 0.023379 | 0.024735 | 0.025076 | 0.022814 | +2.4 % |
| GABI | 0.045165 | 0.049925 | 0.050409 | 0.038516 | +14.7 % |
| GABRIEL | 0.049768 | 0.036981 | 0.038306 | 0.026932 | +45.9 % |
| IVANNA | 0.047203 | 0.049005 | 0.049608 | 0.051043 | −8.1 % |
| JOE | 0.037816 | 0.037319 | 0.039763 | 0.036505 | +3.5 % |
| JONATHAN | 0.058754 | 0.035754 | 0.040397 | 0.023859 | +59.4 % |
| KHAROL | 0.042656 | 0.039912 | 0.041878 | 0.030284 | +29.0 % |
| **media** | 0.040639 | 0.037720 | 0.039552 | **0.033935** | **+16.5 %** |
| mediana | | | | | +9.1 % |

Dos sujetos empeoran de forma clara (CECILIA −26.5 %, IVANNA −8.1 %). La desviación entre sujetos
no baja al personalizar (0.010459 → 0.010947): la personalización no homogeneiza el desempeño.

**Cuánto es sólo el offset:** el brazo A' —pesos globales con intercepto recalibrado del sujeto—
da 0.037720. El personalizado completo aporta un **+10.0 %** adicional sobre ese offset. Es decir,
casi la mitad de la ganancia aparente frente a A es simplemente corregir el nivel medio del sujeto.

## 5. Métricas agregadas

| | MSE | MAE | r | rho | sign acc |
|---|---|---|---|---|---|
| A global | 0.040560 | 0.1690 | +0.079 | +0.041 | 0.539 |
| **C personalizado** | 0.033990 | 0.1487 | **+0.438** | +0.420 | **0.565** |
| D gesto+fase | 0.018197 | 0.1021 | +0.751 | +0.738 | 0.570 |

Por motor: A [0.028033, 0.033066, 0.069087, 0.032056] → C [0.023087, 0.028072, 0.060988, 0.023812].
**4 de 4 mejoran.** Closing 0.047896 → 0.039646. Opening 0.033242 → 0.028347.

## 6. Controles de información — el resultado decisivo

Aquí hay que declarar una corrección de método, porque la primera implementación habría producido
un falso aprobado.

**Primera versión de CONTROL 1**, que barajaba los targets entre episodios de calibración
redimensionando trayectorias de distinta longitud: degradación **+19.1 %**, que habría pasado el
umbral del 15 %. Al revisarla se vio que no sólo destruía la identidad del episodio: además
**desalineaba la fase**, porque el redimensionado desplaza cada muestra respecto a su instante del
gesto. Estaba midiendo la destrucción de la fase, no la de la relación EMG–target.

**Versión corregida de CONTROL 1**: cada episodio de calibración recibe la trayectoria de **otro
episodio del mismo gesto, remuestreada por fase**. Preserva gesto y fase, destruye sólo la
identidad del episodio.

| control | MSE | degradación | umbral | |
|---|---|---|---|---|
| C personalizado (N=5) | 0.033935 | — | — | |
| CONTROL 1 · trayectoria de otro episodio del mismo gesto | 0.034250 | **+0.9 %** | ≥ 15 % | **NO** |
| CONTROL 2 · barajado condicionado gesto+fase | 0.034327 | **+1.2 %** | > 5 % | **NO** |

**Los dos controles dicen lo mismo.** Sustituir el target de un episodio por el de cualquier otro
episodio del mismo gesto cuesta un 0.9 %. Es decir: **para este decoder los episodios son
intercambiables**. Lo que ha aprendido de la calibración supervisada es la trayectoria media del
gesto en función de la fase, no una relación EMG → movimiento específica de cada repetición.

Esto explica también por qué el oráculo gesto+fase sigue siendo el doble de bueno: hace
explícitamente, y mejor, lo único que el decoder está capturando.

## 7. Evaluación del gate

| # | condición | umbral | medido | |
|---|---|---|---|---|
| 1 | MSE vs ridge global | ≥ 20 % | +10.5 % anidado (+19.8 % mejor presupuesto fijo) | **NO** |
| 2 | MSE vs predictor media | ≥ 15 % | +10.3 % anidado | **NO** |
| 3 | sign accuracy mejora | — | 0.539 → 0.565 | sí |
| 4 | sujetos que mejoran | ≥ 8/10 | 7/10 | **NO** |
| 5 | motores que mejoran | ≥ 3/4 | 4/4 | sí |
| 6 | CONTROL 1 degrada | ≥ +15 % | +0.9 % | **NO** |
| 6b | CONTROL 2 degrada | > +5 % | +1.2 % | **NO** |
| 7 | el efecto se mantiene anidado | cond. 1 y 2 | no se mantienen | **NO** |
| 8 | presupuesto razonable | ≤ 5 min | 30.5 s | sí |

**Pasa 3 de 8.**

## 8. Veredicto y por qué no es `E1D_DATA_HUNGRY`

```
E1D_RESULT = E1D_FAIL
```

`E1D_DATA_HUNGRY` describiría un método que funciona pero exige demasiados datos. No es el caso:

- la curva de presupuesto está **saturada**, no hambrienta — 50 veces más datos compran un 8 %;
- y sobre todo, **lo poco que aprende no es EMG**. Los dos controles lo demuestran. Más datos de
  calibración darían más trayectorias medias del mismo gesto, no más relación EMG→movimiento.

Se cierra la línea de guante virtual con este dataset. No se siguen inventando arquitecturas.

## 9. Lo que queda establecido, sumando las cuatro etapas

| etapa | hipótesis | resultado |
|---|---|---|
| E1 | generalización directa entre sujetos | FAIL — ablación condicionada −2.7 % |
| E1B | renormalización afín EMG-only por sujeto | FAIL — 0 de 8, condicionada +0.6 % |
| E1C | alineación circular de canales | REFUTED — techo real +3.3 % |
| E1D | calibración supervisada del sujeto | FAIL — controles +0.9 % y +1.2 % |

El hilo es el mismo en las cuatro: **cualquiera que sea el montaje, lo que el modelo captura es la
fase del gesto, no la relación EMG→movimiento.** El oráculo gesto+fase gana siempre, y romper el
emparejamiento EMG–target nunca cuesta nada material.

La conclusión defendible para la tesis no es "no se puede quitar el guante", sino algo más preciso
y más útil:

> Con las 40 features WMoos históricas, la ventana de 0.2 s y el dataset Denis, la señal EMG no
> aporta información sobre la trayectoria del guante más allá de identificar el gesto y su fase —
> ni entre sujetos, ni dentro de un sujeto con calibración supervisada.

Eso acota el problema a su origen: **los datos y la representación**, no el controlador ni el
algoritmo de RL.

## 10. Figura

`figuras/E1D_resumen.png` — curva de presupuesto de los cuatro brazos frente al oráculo; MSE por
sujeto de A y C; y las degradaciones de los dos controles frente a sus umbrales.
