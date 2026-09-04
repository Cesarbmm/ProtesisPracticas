# ETAPA E1C — Alineación espacial de canales EMG · Resultados

**Fecha:** 2026-09-04 · **Rama:** `experiment/no-glove-paired-reference-td3`

> **Veredicto: `E1C_RESULT = STOPPED_AFTER_ORACLE`.**
> `ORACLE_ALIGNMENT_POTENTIAL = NO` · `CHANNEL_ALIGNMENT_HYPOTHESIS = REFUTED` como ruta a la
> transferencia entre sujetos. No se construyó el selector EMG-only. MATEO y SANDRA siguen sellados.

---

## 1. Verificación previa (§5.1) — hizo su trabajo

El desplazamiento se aplica **antes** de WMoos, así que hubo que recalcular las 40 features desde la
EMG cruda fuera de MATLAB. La verificación bloqueante detectó un error real de reconstrucción antes
de que contaminara nada:

- **Primer intento:** rellenaba con ceros la última ventana de cada episodio. `RecordedMyo.readEmg`
  devuelve una ventana **parcial**. Error relativo de hasta **2.3e+01** en 5 de 10 sujetos.
- **Corregido:** ventana `t` = filas `[40(t−1) : min(40t, n)]`, sin relleno. Error absoluto máximo
  global **2.7e-15** sobre 940 000 celdas.

El criterio se corrigió por Enmienda 1 (relativo ≤ 1e-10 **o** absoluto ≤ 1e-12) porque dos celdas
de ~380 000 tenían valor exportado ~6e-7 y diferencia absoluta ~2e-16: degeneración del
denominador, no del cálculo.

**Nota técnica confirmada:** bajo desplazamiento circular, F1, F4, F5 y F13 sólo se permutan, pero
`WMoos_F2` cambia de forma no trivial — aplica `hilbert` y `sgolayfilt` a lo largo del eje de
canales, y Savitzky-Golay no es circular. Por eso el experimento exigía recomputar y no permutar.

## 2. El primer número del oráculo era un artefacto

La primera lectura, siguiendo la letra de §6 (`k` y `lambda` seleccionados por folds internos **por
separado para cada brazo**), dio **+21.9 %**. Es engañosa por dos motivos:

1. Al cambiar `k` entre brazos, **los conjuntos de evaluación tienen distinto tamaño** y la
   comparación deja de ser pareada.
2. Siete de los diez sujetos elegían **shift 0**, es decir, ninguna rotación. Su "mejora" venía
   íntegramente de haber elegido otro `(k, lambda)`, no de alinear.

Con **la misma configuración para ambos brazos**, que es la única comparación que aísla el
desplazamiento, la cifra baja a **+15.5 %**. Y esa cifra tampoco mide alineación:

| | DENIS | media de los 10 |
|---|---|---|
| `lambda` elegida por el anidado en ese fold | **0.01** | 1e6 en los otros 9 |
| A sin alinear | 0.078007 | 0.046120 |
| C oráculo | 0.023746 | 0.038985 |
| mejora | **+69.6 %** | +15.5 % |

La curva de `lambda` es plana (8.2 % de variación entre su mejor y su peor valor), así que el
argmin anidado se vuelca por ruido. En el fold de DENIS eligió `lambda = 0.01`, que arruina el
brazo A, y el desplazamiento recupera parte de ese destrozo. **No es alineación: es una patología
de selección de hiperparámetro.**

## 3. El oráculo real

Con `lambda` fijada al valor modal (1e6) y `k = +2` en los diez folds:

| sujeto | sin alinear | oráculo | mejora | shift |
|---|---|---|---|---|
| BLANCA | 0.034378 | 0.034378 | +0.0 % | 0 |
| CECILIA | 0.042895 | 0.042494 | +0.9 % | 3 |
| DENIS | 0.024375 | 0.021879 | +10.2 % | 1 |
| EMILIA | 0.023379 | 0.023123 | +1.1 % | 1 |
| GABI | 0.045165 | 0.043990 | +2.6 % | 5 |
| GABRIEL | 0.049768 | 0.049768 | +0.0 % | 0 |
| IVANNA | 0.047203 | 0.047133 | +0.1 % | 4 |
| JOE | 0.037816 | 0.037816 | +0.0 % | 0 |
| JONATHAN | 0.058754 | 0.052928 | +9.9 % | 4 |
| KHAROL | 0.042656 | 0.038761 | +9.1 % | 2 |
| **media** | **0.040639** | **0.039227** | **+3.5 %** | |

Mediana por sujeto: **+1.0 %**. Sin DENIS, la versión anidada cae de +15.5 % a **+4.5 %**.

Por motor mejora 4 de 4, pero por márgenes mínimos (M1 0.028033 → 0.026683). Sign accuracy
0.539 → 0.541. MAE 0.1690 → 0.1662.

## 4. Transferencia por mitades — el test decisivo

El oráculo elige el desplazamiento **con los mismos datos en que se mide**, así que parte de su
ganancia es ajuste de ruido: escoger el mínimo de 8 números ruidosos siempre baja el error. Para
separarlo, se elige el desplazamiento con la mitad 1 de los episodios de evaluación y se mide en la
mitad 2:

| | ganancia |
|---|---|
| desplazamiento elegido en la mitad 1, medido en la mitad 2 | **+3.3 %** |
| oráculo medido en su propia mitad 2 | +3.4 % |

**El desplazamiento sí es una propiedad reproducible del sujeto**: transfiere casi íntegro, y en
7 de 10 sujetos la mitad 1 y la mitad 2 eligen el mismo. No es ruido.

**Pero vale +3.3 %, no 15 %.**

## 5. Estabilidad física (§11)

| sujeto | global | closing | opening | M1 M2 M3 M4 | moda por episodio | % episodios con la moda |
|---|---|---|---|---|---|---|
| BLANCA | 0 | 7 | 1 | 7, 0, 6, 7 | 7 | 28.7 % |
| CECILIA | 3 | 3 | 7 | 3, 0, 2, 7 | 0 | 20.3 % |
| DENIS | 1 | 7 | 1 | 1, 6, 7, 1 | 1 | 52.3 % |
| EMILIA | 1 | 5 | 1 | 1, 7, 0, 1 | 1 | 39.7 % |
| GABI | 5 | 5 | 5 | 5, 5, 6, 5 | 5 | 48.7 % |
| GABRIEL | 0 | 4 | 0 | 0, 0, 6, 0 | 0 | 50.0 % |
| IVANNA | 4 | 4 | 0 | 4, 0, 7, 4 | 0 | 27.1 % |
| JOE | 0 | 4 | 0 | 0, 1, 0, 0 | 0 | 47.9 % |
| JONATHAN | 4 | 4 | 4 | 4, 0, 2, 4 | 4 | 77.3 % |
| KHAROL | 2 | 3 | 2 | 6, 7, 2, 2 | 6 | 27.2 % |

```
closing y opening coinciden : 2/10
los 4 motores coinciden     : 0/10
moda por episodio == global : 6/10
% episodios con la moda     : 41.9 % de media   (azar con 8 opciones = 12.5 %)
```

Esto es lo que §11 pedía mirar, y responde que no. Una rotación física del brazalete afectaría por
igual a los dos gestos y a los cuatro motores: el canal 3 sería el canal 5 para todo. Aquí
`closing` y `opening` coinciden en **2 de 10** sujetos y los cuatro motores no coinciden en
**ninguno**.

La lectura: el desplazamiento óptimo es reproducible dentro de un sujeto (41.9 % de sus episodios
frente al 12.5 % del azar, y transfiere entre mitades) pero **no se comporta como una rotación
del brazalete**. Se parece más a que el ridge encuentra, por sujeto, una recombinación de canales
que le va algo mejor — un ajuste de la mezcla, no una corrección de identidad espacial.

## 6. Evaluación del gate de potencial

| # | condición | umbral | medido | |
|---|---|---|---|---|
| 1 | reducción media de MSE | ≥ 15 % | +15.5 % nominal / **+3.5 % real** / **+3.3 %** transferido | **NO** |
| 2 | sujetos que mejoran | ≥ 7/10 | 7/10, pero 3 con ≤ 1.1 % y 3 con 0.0 % | límite |
| 3 | motores que mejoran | ≥ 3/4 | 4/4, por márgenes mínimos | sí |

```
ORACLE_ALIGNMENT_POTENTIAL = NO
```

### Por qué el paro es forzado, no una opinión

El gate final de §12 exige **≥ 15 % de mejora de MSE** para el selector EMG-only. Ese selector
**no puede superar al oráculo**: el oráculo ya elige el mejor desplazamiento usando los targets, y
un selector que sólo ve EMG recupera, en el mejor caso, una fracción de esa ganancia.

Techo del oráculo, medido honestamente: **+3.3 %**. Umbral del gate final: **15 %**.

Por tanto **E1C no puede pasar** aunque el selector fuera perfecto. Construirlo consumiría trabajo
con un resultado ya determinado. Se para aquí, como manda §7.

## 7. Enmienda 2 — sobre el número nominal

Se registra explícitamente, y **después** de ver los datos:

> La condición 1, leída al pie de la letra sobre el estimador anidado, da +15.5 % y **pasaría**. No
> se declara `POTENTIAL = YES` porque se puede demostrar que ese número no mide alineación:
> fijando `lambda` al valor modal, el mismo oráculo da +3.5 %, y la transferencia por mitades da
> +3.3 %. El diagnóstico está en §2 y es reproducible.

Se deja constancia de que esto es una **anulación de un aprobado nominal**, no una relajación de un
umbral, y de que la decisión es revisable: si César prefiere atenerse a la letra del preregistro,
el siguiente paso sería construir el selector EMG-only sabiendo que su techo es +3.3 % y que el
gate final pide 15 %.

## 8. Qué queda establecido

- La rotación del brazalete **no explica** el fallo de transferencia entre sujetos. Es la tercera
  hipótesis EMG-only descartada, después de la generalización directa (E1) y la renormalización
  afín (E1B).
- Existe un efecto pequeño, real y estable por sujeto (~3 %) asociado a recombinar canales, pero no
  tiene la forma de una rotación y no cambia el orden de magnitud del problema.
- **Se cierra la línea de adaptación EMG-only entre sujetos.** No se abre otra transformación
  EMG-only.

```
NEXT_DECISION = SUPERVISED_SUBJECT_CALIBRATION  (a discutir, NO implementado)
```

## 9. Figura

`figuras/E1C_resumen.png` — oráculo por sujeto con `lambda` modal; rejilla de desplazamientos
preferidos por condición, con verde cuando coinciden con el global del sujeto; y ganancia por
transferencia entre mitades frente al umbral del 15 %.
