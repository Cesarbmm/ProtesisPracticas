# ETAPA E1 — Guante virtual offline · Resultados

**Fecha:** 2026-09-04 · **Rama:** `experiment/no-glove-paired-reference-td3`
**Artefacto:** `Agentes/paired_reference/stage1/export/` (12 `.mat`, 113 057 pasos)

> **Veredicto: `E1_SUBJECT_SPECIFIC_ONLY`. El gate NO pasa. PARA.**
> El test final **no se ejecutó**: el preregistro §10 lo condiciona a que E1 pase. El conjunto de
> test (MATEO, SANDRA) queda intacto y disponible para una línea corregida.

---

## 1. Auditoría del artefacto exportado

Los ocho puntos, antes de ajustar ningún modelo.

| # | Comprobación | Resultado |
|---|---|---|
| 1 | 12 sujetos y split congelado | **OK** — los 12 archivos coinciden exactamente con el split de la Enmienda 3 |
| 2 | Opening/Closing y conteos | **OK** — 7420 episodios, perfectamente balanceados (p. ej. BLANCA 310/310) |
| 3 | `phi = 40`, `target = 4` | **OK** en los 12 sujetos |
| 4 | `phi` contra `fGetFeatures` | **OK a precisión de máquina** |
| 5 | Sin `Env`, `SimController` ni agente | **OK** — sólo aparecen en comentarios |
| 6 | Pérdida en extremos por `k` | **OK** — exactamente 7420 pares por unidad de \|k\| |
| 7 | `PREPROCESSING_LEAKAGE_STATUS` | conservado en `POSSIBLE_LEAKAGE` |
| 8 | Semánticas históricas WMoos | conservadas sin corregir |

### 1.4 Validación de features (30 ventanas, 3 sujetos)

Se invirtió la normalización (`raw = phi·S + C`) y se recalcularon las features sobre exactamente
la misma ventana de 40 muestras. Error relativo máximo por bloque:

| bloque | dims | error rel. máx |
|---|---|---|
| `WMoos_F1` desviación estándar | 8 | 8.2 × 10⁻¹⁶ |
| `WMoos_F2` hilbert + sgolay + trapz | 8 | 5.0 × 10⁻¹⁵ |
| `WMoos_F4` valor absoluto medio | 8 | 6.5 × 10⁻¹⁶ |
| `WMoos_F5` energía | 8 | 6.1 × 10⁻¹⁴ |
| `WMoos_F13` RMS | 8 | 3.7 × 10⁻¹⁶ |

Los 40 features coinciden. Esto valida a la vez la definición de features, el alineamiento de
ventana (paso `t` → muestras `[40(t−1)+1 : 40t]`) y los `C`/`S` históricos.

**Nota sobre la semántica histórica, conservada sin corregir:** `WMoos_F2` aplica `hilbert` y
`sgolayfilt` sobre `emg'` de 8×m, y MATLAB opera **por columnas** — es decir a lo largo de los 8
canales, no del tiempo. Es casi seguro que no era la intención original. Se documenta y **no se
toca**, tal como se pidió.

### 1.6 Pérdida de muestras por `k`

| k | TRAIN | VALIDATION | TEST | TOTAL | pérdida |
|---|---|---|---|---|---|
| 0 | 75 265 | 18 815 | 18 977 | 113 057 | 0.00 % |
| ±1 | 70 345 | 17 575 | 17 717 | 105 637 | 6.56 % |
| ±2 | 65 425 | 16 335 | 16 457 | 98 217 | 13.13 % |

Exactamente un episodio de pérdida por unidad de \|k\| (7420), como corresponde a recortar dentro
de cada episodio. Simétrico en signo.

### 1.7 Comprobación registrada en `05_AUDITORIA_NORMALIZACION.md` §6

Centro y escala calculados con los 12 sujetos de Denis, frente a los `C`/`S` almacenados:

| bloque | \|ΔC\|/C mediana | ejemplo `C` almacenado → `C` Denis |
|---|---|---|
| F1 std | 0.087 | 0.0660 → 0.0541 |
| F2 hilbert | **0.942** | **63.86 → 3.66** (17×) |
| F4 mav | 0.508 | 0.0311 → 0.0409 |
| F5 energía | **0.957** | **3.898 → 0.118** (33×) |
| F13 rms | 0.087 | 0.0666 → 0.0540 |

F2 y F5 son las dos features que **escalan con la longitud de ventana**, y difieren por factores de
17× y 33×. Eso es una discrepancia estructural, no un efecto de muestreo de sujetos: el corpus de
306 usuarios se calculó con ventanas de otra longitud y otra tarea.

**Conclusión:** la evidencia apunta a `KNOWN_CLEAN`. Por instrucción explícita se **conserva
`POSSIBLE_LEAKAGE`**; el cambio de etiqueta es tuyo, no mío.

**Efecto secundario que sí importa:** con `C`/`S` desajustados en esos dos bloques, las features
normalizadas quedan mal escaladas (`phi` llega a 41.5). Eso interactúa con la penalización del
ridge. Se controla explícitamente en §4.

---

## 2. Baselines (validation, por `k`)

| k | A hold MSE | B oráculo MSE | A MAE | B MAE |
|---|---|---|---|---|
| −2 | 0.005433 | 0.028322 | 0.0418 | 0.1253 |
| −1 | 0.000000 | 0.027168 | 0.0000 | 0.1209 |
| 0 | 0.005053 | 0.026161 | 0.0383 | 0.1175 |
| +1 | 0.016095 | 0.027180 | 0.0785 | 0.1198 |
| +2 | 0.031211 | 0.028776 | 0.1204 | 0.1237 |

`k = −1` es degenerado por construcción: `y_{t−1}` **es** el target. Se marca y se excluye de
cualquier comparación.

- **BASELINE A** = `y_{t−1}` → `DIAGNOSTIC_ONLY`. Requiere el guante en tiempo de ejecución, que es
  justo lo que la línea quiere eliminar.
- **BASELINE B** = media de `y` por gesto y bin de fase (10 bins), ajustada en TRAIN →
  `DIAGNOSTIC_ORACLE`. Requiere conocer de antemano el gesto y la fase temporal.

---

## 3. Ridge 40 → 4 · selección con VALIDATION

| k | mejor λ | val MSE | B oráculo |
|---|---|---|---|
| −2 | 3.162e5 | 0.053848 | 0.028322 |
| −1 | 3.162e5 | 0.052602 | 0.027168 |
| 0 | 3.162e5 | 0.052563 | 0.026161 |
| **+1** | **3.162e5** | **0.052142** | 0.027180 |
| +2 | 1e6 | 0.052193 | 0.028776 |

```
BEST_K = +1     LAMBDA = 3.162e5     RIDGE40_VALIDATION_MSE = 0.052142
```

**El λ óptimo está en el extremo del rango, y eso es el resultado.** Con λ = 3.16e5 los pesos
quedan en `max|W| = 0.0138`: el modelo está a un paso de predecir la media de train.

| | val MSE |
|---|---|
| predecir la media de TRAIN | 0.055592 |
| ridge40 con el λ seleccionado | 0.052142 |
| **ventaja del ridge sobre la media** | **6.2 %** |

Y con λ pequeño, donde el ridge sí ajusta:

| λ | train MSE | val MSE |
|---|---|---|
| 1e-4 | 0.028254 | **0.060351** |
| 1 | 0.028366 | 0.060863 |
| 1e4 | 0.032388 | 0.057540 |
| 3.16e5 | 0.035900 | 0.052142 |

Ajusta train a 0.0283 y en sujetos nuevos queda **peor que predecir la media**. El patrón es
inequívoco: lo que aprende no transfiere entre sujetos.

---

## 4. Control del confound de escala

Podría objetarse que el fracaso lo causa el desajuste de `C`/`S` de §1.7, porque la penalización del
ridge sí es sensible a la escala. Se controló estandarizando con estadísticos **sólo de TRAIN** —
sin tocar `C`/`S` ni la definición de features, sólo la geometría del ridge:

| | val MSE | mejora sobre la media |
|---|---|---|
| features tal cual | 0.052142 | 6.2 % |
| estandarizados con TRAIN | 0.052580 | 5.4 % |

**El confound queda descartado.** El fracaso no es un artefacto de regularización.

---

## 5. Métricas del modelo seleccionado (validation)

| | MSE | MAE | r | ρ | sign acc |
|---|---|---|---|---|---|
| **ridge40** | **0.052142** | **0.1977** | **+0.402** | +0.343 | **0.557** |
| baseline A hold | 0.016095 | 0.0785 | +0.839 | +0.850 | 0.762 |
| baseline B oráculo | 0.027180 | 0.1198 | +0.821 | +0.786 | 0.560 |

`n = 61 707` transiciones para la sign accuracy.

**Por motor (MSE):**

| | M1 | M2 | M3 | M4 |
|---|---|---|---|---|
| ridge40 | 0.035164 | 0.035574 | 0.091777 | 0.046052 |
| baseline B | 0.016501 | 0.010444 | 0.062820 | 0.018954 |

**Motores donde ridge40 bate a baseline B: 0 de 4.**

**Por gesto (MSE):** closing — ridge 0.063235 · B 0.036848 · A 0.018161. Opening — ridge 0.041029 ·
B 0.017496 · A 0.014026. El ridge pierde en los dos.

---

## 6. Controles de permutación (5 semillas)

### Entre sujetos (train 8 → validation 2)

| | MSE | degradación |
|---|---|---|
| ridge40 intacto | 0.052142 | — |
| predecir la media | 0.055592 | — |
| ablación 1, global | 0.055448 | **+6.3 %** |
| ablación 2, condicionada | 0.050714 | **−2.7 %** |

Dos lecturas, y la segunda es la decisiva:

1. Romper globalmente la asociación EMG–target devuelve el ridge **exactamente** al predictor de la
   media (0.055448 ≈ 0.055592). Toda su ventaja entre sujetos son esos 6.2 %, y se evapora.
2. Barajar la EMG **dentro del mismo gesto y la misma fase** no lo degrada: lo mejora ligeramente.
   **Conocida la fase, la EMG no aporta nada más entre sujetos.**

### Dentro de sujeto (70/30 por episodios, los 8 de TRAIN)

| sujeto | ridge | media | shuf. global | shuf. condicionada | deg. global | deg. cond. |
|---|---|---|---|---|---|---|
| BLANCA | 0.027856 | 0.038169 | 0.038239 | 0.029822 | +37.3 % | +7.1 % |
| CECILIA | 0.033008 | 0.047823 | 0.048004 | 0.034935 | +45.4 % | +5.8 % |
| DENIS | 0.011852 | 0.023795 | 0.023841 | 0.012341 | +101.1 % | +4.1 % |
| EMILIA | 0.013617 | 0.024739 | 0.024720 | 0.014210 | +81.5 % | +4.4 % |
| GABI | 0.019175 | 0.045992 | 0.045122 | 0.019852 | +135.3 % | +3.5 % |
| GABRIEL | 0.019637 | 0.037446 | 0.037464 | 0.020311 | +90.8 % | +3.4 % |
| IVANNA | 0.029425 | 0.044039 | 0.043937 | 0.034673 | +49.3 % | +17.8 % |
| JOE | 0.019825 | 0.040947 | 0.040958 | 0.020750 | +106.6 % | +4.7 % |
| **media** | **0.021799** | 0.037869 | 0.037786 | 0.023362 | **+80.9 %** | **+6.4 %** |

Aquí sí hay señal. El ridge mejora un 42 % sobre la media, la ablación global lo destruye
(+80.9 %), y la condicionada lo degrada de forma **modesta pero consistente: positiva en los 8
sujetos**, entre +3.4 % y +17.8 %.

**Dentro de un sujeto, la EMG aporta información propia más allá de la fase. Entre sujetos, no.**

---

## 7. Evaluación del gate preregistrado

| # | condición | umbral | medido | |
|---|---|---|---|---|
| 1 | bate a los baselines en sujetos no vistos | — | 0.0521 vs B 0.0272 y A 0.0161 | **NO** |
| 2 | MSE | ridge < B | 0.0521 > 0.0272 | **NO** |
| 3 | sign accuracy | > 0.55 y > B | 0.557 > 0.55 pero < 0.560 | **NO** |
| 4 | ablación global | ≥ +20 % | +6.3 % | **NO** |
| 5 | ablación condicionada | ≥ +10 % | **−2.7 %** | **NO** |
| 6 | consistencia por motor | ≥ 3 de 4 | 0 de 4 | **NO** |
| 7 | sin dependencia del test | — | k y λ elegidos sólo con validation | **SÍ** |

**Falla 6 de 7.**

---

## 8. Clasificación y decisión

```
E1_RESULT = E1_SUBJECT_SPECIFIC_ONLY
```

No es `E1_NO_EMG_INFORMATION`: dentro de un sujeto la asociación EMG–guante es fuerte, sobrevive al
control condicionado y es consistente en los 8 sujetos.

No es `E1_INCONCLUSIVE_PREPROCESSING_LEAKAGE`: una fuga sólo podría **inflar** el desempeño, y el
desempeño es malo. Además §1.7 muestra que `C`/`S` vienen de otro corpus y otra ventana, y §4
descarta el confound de escala.

**Es `E1_SUBJECT_SPECIFIC_ONLY`:** el dataset soporta un decoder específico de sujeto, pero **no
uno independiente del usuario**.

### Consecuencias, según el preregistro

- **PARA.** No se escala a MLP. No se ejecuta el ridge de contexto `120 → 4`: su condición de
  apertura (B.6) exige que ridge40 muestre información EMG real entre sujetos, y no la muestra.
- **El test no se ejecuta.** MATEO y SANDRA quedan intactos.
- No se toca TD3, ni la reward, ni la planta. E2 sigue sin autorizar.

Un resultado negativo es un resultado. Y este es informativo: dice que la pregunta correcta para la
tesis no es "¿se puede quitar el guante?", sino **"¿se puede quitar el guante para un usuario que
aporta unos minutos de calibración?"** — que es, además, como funcionan las prótesis mioeléctricas
reales.

### Lo que este resultado NO autoriza todavía

Aparcado en `BACKLOG.md`, sin abrir etapa: decoder subject-specific con calibración por sesión ·
recalcular `C`/`S` con los 8 sujetos de train · contexto temporal · normalización por sujeto.
Cualquiera de ellos cambia la pregunta científica y necesita su propio preregistro.

---

## 9. Figuras

`figuras/E1_trayectorias_validation.png` — guante real, ridge40 y baseline B por motor, para
JONATHAN y KHAROL, 3 episodios de closing y 3 de opening concatenados. El ridge queda casi plano
alrededor de 0.6–0.7 mientras el guante recorre de 0.3 a 1.0.

`figuras/E1_resumen.png` — MSE por sujeto, MSE por motor, sign accuracy y los cuatro controles de
permutación.

Ambas sobre **validation**, no sobre test, por la razón de la cabecera.

---

## 10. Estatus de la exploracion within-subject — `DIAGNOSTIC_ONLY`

La tabla de la seccion 6 "dentro de sujeto" procede de `e1_diag.py` y de `e1_abl.py`. Hay que
declarar con precision que es y que no es, porque los dos scripts no tienen el mismo estatus.

**`e1_diag.py` (tabla de la seccion 6.2 del guion original, "hay senal EMG dentro de un sujeto"):**
elige `lambda` **barriendo y quedandose con el minimo sobre el 30 % reservado**. Es decir, selecciona
el hiperparametro sobre el mismo conjunto con el que reporta. Eso infla el resultado y **no es una
estimacion honesta de desempeno**.

```
ESTATUS = DIAGNOSTIC_ONLY
```

No puede citarse como validacion de un decoder subject-specific, ni entrar en ninguna tabla de
resultados de la tesis como medida de desempeno.

**`e1_abl.py` (controles de permutacion dentro de sujeto):** usa `lambda = 1e2` **fija**, igual para
el modelo intacto y para las dos versiones barajadas. Como la comparacion es relativa y el
hiperparametro no se ajusta a ningun conjunto, la **degradacion** que mide (+80.9 % global, +6.4 %
condicionada, positiva en 8/8) sigue siendo evidencia valida de que existe asociacion EMG-target
dentro de un sujeto.

```
ESTATUS = evidencia de asociacion, valida como MOTIVACION
```

**Lo que se conserva y lo que no:**

- **Se conserva** como motivacion del siguiente experimento: dentro de un sujeto existe asociacion
  EMG-target que sobrevive al control condicionado.
- **NO se declara** un "decoder subject-specific validado". No lo hay. Ningun numero de desempeno
  within-subject de E1 esta libre de seleccion sobre el conjunto de evaluacion.
- Validar esa hipotesis exige su propio protocolo, con calibracion y evaluacion disjuntas por
  episodios y seleccion de hiperparametros fuera del conjunto de reporte. Eso es lo que hace E1B.
