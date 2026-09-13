# E3E — Cross-Subject EMG Domain Audit · RESULTADOS

**Fecha:** 2026-09-09  
**Worktree:** `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`  
**Rama:** `experiment/no-glove-paired-reference-td3`  
**HEAD:** `165be049eb41fc41254435181c9857fe0f22ed1c`  
**Estado:** Cierre de auditoría de dominio entre sujetos. Sin entrenamiento RL, sin cambios en Git, sin push.

---

## 1. Resumen Ejecutivo

| Clave | Valor |
|---|---|
| `CLEAN_FULL_REGRESSION` | **356 / 356 PASS** (326 regresiones históricas + 30 E3D) |
| `E3D_RESULT` | **TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED** (respetado) |
| `DATA_COVERAGE_PROBLEM` | **NO** (apertura y cierre 50.0% / 50.0% simétricos) |
| `INITIAL_WINDOW_STABLE` | **NO** (100% features difieren apertura vs cierre en $N=1$) |
| `SUBJECT_SHIFT_DETECTED` | **YES** (sujeto explica 107× más varianza que intención) |
| `SUBJECT_TO_INTENT_VARIANCE_RATIO` | **Media: 107.86** · **Mediana: 22.09** |
| `SUBJECT_ID_ACCURACY_ORIGINAL` | **79.14%** (azar: 14.29%) · Macro-F1 = 0.7845 |
| `SUBJECT_ID_ACCURACY_NORMALIZED` | **83.00%** (aumentó la firma de sujeto) |
| `NORMALIZATION_SUPPORTED` | **NO** (7 PASS, 4 FAIL: fallan A, C, D, E) |
| `E3E_RESULT` | **NORMALIZATION_NOT_SUPPORTED** |
| `NEXT_BOTTLENECK` | **SUBJECT_ADAPTATION_REQUIRED** |
| `MATEO_SANDRA_SEALED` | **YES** |
| `REFERENCE_CONTRACT_VALIDATED` | **NO** |
| `HARDWARE_AUTHORIZED` | **NO** |

---

## 2. Verificación Técnica Previa (Regresión Limpia)

Antes de iniciar cualquier trabajo de E3E, se ejecutó la batería completa extremo a extremo con el launcher E3D corregido (`e3dRunRegressionTests(false)` + `runE3DTemporalIntentAudit('testsCore')`):
- Regresiones históricas (E0P, E2A–E2G, E3AX, CAP192, E3B, E3C): **326 / 326 PASS**.
- Pruebas E3D (`testE3DTemporalIntent`): **30 / 30 PASS**.
- **Resultado consolidado:** `CLEAN_FULL_REGRESSION = 356/356 PASS` en una sola corrida limpia, resolviendo definitivamente la advertencia de trazabilidad de E3D.

---

## 3. Auditoría del Pipeline WMoos y Procedencia

1. **Pipeline de features:**
   - Señal bruta: Myo Armband, 8 canales bipolares @ 200 Hz.
   - En cada paso ($T_s = 0.2$ s), se toman $m = 40$ muestras ($40 \times 8$).
   - `getWmoosFeatures`:
     - $X = \text{emg}'$ ($8 \times 40$).
     - $f_1 = \text{WMoos\_F1}(X)$: Desviación estándar por canal ($8 \times 1$).
     - $f_2 = \text{WMoos\_F2}(X)$: Envolvente absoluta. *Peculiaridad histórica respetada:* `hilbert` y `sgolayfilt` se aplican sobre $X$, por lo que operan a través de los 8 canales espaciales en vez de a lo largo del tiempo.
     - $f_3 = \text{WMoos\_F4}(X)$: Mean Absolute Value ($8 \times 1$).
     - $f_4 = \text{WMoos\_F5}(X)$: Energía ($8 \times 1$).
     - $f_5 = \text{WMoos\_F13}(\text{emg})$: RMS ($8 \times 1$).
     - Concatenación: vector crudo de 40 variables.
   - Normalización histórica: `normalize(features, 'center', C, 'scale', S)`.
2. **Procedencia de `normValues.mat`:**
   - Archivo: `matlab_code/config/normValues.mat` (39 041 695 bytes, MD5: `650ac152f78b3840872aa92b3806b2aa`).
   - Contiene la matriz $F$ de $40 \times 45900$ correspondiente a 306 usuarios $\times$ 6 gestos discretos $\times$ 25 repeticiones.
   - $C$ y $S$ **no provienen de los sujetos de Denis** ni de trayectorias continuas de tracking.
   - `CURRENT_WMOOS_PIPELINE = WMoos_F1_F2_F4_F5_F13`
   - `CURRENT_NORMALIZATION = GLOBAL_AFFINE_CENTER_SCALE`
   - `NORMALIZATION_PROVENANCE = EXTERNAL_306_SUBJECTS_DISCRETE_GESTURES`
   - `SUBJECT_SPECIFIC = NO`
   - `CAUSAL_FOR_NEW_SUBJECT = YES`
   - `LEAKAGE_STATUS = POSSIBLE_LEAKAGE` (conservador).

---

## 4. Cobertura de Datos (Sección 17)

Se auditó la distribución completa de muestras de apertura y cierre por sujeto y split:

| Sujeto | Split | Episodios Cierre | Episodios Apertura | Muestras Cierre | Muestras Apertura | Longitud Media | Imbalance (Open/Close) |
|---|---|---|---|---|---|---|---|
| BLANCA | TRAIN | 10 | 10 | 150 | 150 | 15.0 | 1.000 |
| CECILIA | TRAIN | 10 | 10 | 149 | 150 | 15.0 | 1.007 |
| DENIS | TRAIN | 10 | 10 | 150 | 150 | 15.0 | 1.000 |
| EMILIA | TRAIN | 10 | 10 | 149 | 150 | 15.0 | 1.007 |
| GABI | TRAIN | 10 | 10 | 140 | 140 | 14.0 | 1.000 |
| GABRIEL | TRAIN | 10 | 10 | 150 | 150 | 15.0 | 1.000 |
| IVANNA | TRAIN | 10 | 10 | 151 | 147 | 14.9 | 0.974 |
| **TRAIN TOTAL** | **TRAIN** | **70** | **70** | **1039** | **1037** | **14.8** | **0.998** |
| JOE | VAL | 10 | 10 | 139 | 140 | 14.0 | 1.007 |
| JONATHAN | VAL | 10 | 10 | 150 | 151 | 15.1 | 1.007 |
| KHAROL | VAL | 10 | 10 | 142 | 140 | 14.1 | 0.986 |
| **VAL TOTAL** | **VAL** | **30** | **30** | **431** | **431** | **14.4** | **1.000** |
| **GLOBAL** | **TOTAL** | **100** | **100** | **1470** | **1468** | **14.7** | **0.999** |

**Conclusión:** `DATA_COVERAGE_PROBLEM = NO`.  
La pobre generalización en apertura observada en E3B y E3D no se debe a escasez ni desbalance de datos de apertura.

---

## 5. Auditoría de la Ventana Inicial (Sección 18)

Evaluación de los primeros $N$ pasos ($N \in \{1, 2, 3, 5\}$) para determinar si existe una condición de reposo neutro:

| $N$ | Diferencia Media Open vs Close | Diferencia Máxima | Fracción Features Significativos ($p < 0.05$) | Varianza Intra-Sujeto | Varianza Total | Deriva Temporal ($1 \to N$) |
|---|---|---|---|---|---|---|
| **1** | **0.6425** | **2.1120** | **100.0% (40/40)** | 1.6820 | 2.3832 | 0.0000 |
| **2** | 0.5977 | 1.8363 | 97.5% (39/40) | 1.3945 | 2.0524 | 0.3096 |
| **3** | 0.5210 | 1.5408 | 97.5% (39/40) | 1.0110 | 1.5742 | 0.4747 |
| **5** | 0.3871 | 1.3112 | 90.0% (36/40) | 0.6113 | 1.0409 | 0.6560 |

**Conclusión:** `INITIAL_WINDOW_STABLE = NO`.  
Desde el paso 1, los 40 features exhiben diferencias significativas entre apertura y cierre. No existe reposo neutro; cualquier resta o calibración basada en los primeros samples destruiría la información de intención motora.

---

## 6. Estadísticas por Sujeto y Descomposición de Varianza (Secciones 12 y 13)

Descomposición ANOVA de dos vías (Sujeto $\times$ Intención) sobre las 2076 muestras de TRAIN:
- `ETA2_SUBJECT_MEAN`: **0.3055** (la identidad del sujeto explica el 30.55% de la varianza total).
- `ETA2_INTENT_MEAN`: **0.00288** (la intención motora explica sólo el 0.29% de la varianza total).
- `SUBJECT_TO_INTENT_VARIANCE_RATIO`:
  - Media: **107.86**
  - Mediana: **22.09**
  - Mínimo: **3.54**
  - Máximo: **2554.74**
  - Features donde el sujeto domina a la intención: **40 de 40 (100%)**.

`SUBJECT_SHIFT_DETECTED = YES`.

---

## 7. Probes Diagnósticos de Sujeto e Intención (Secciones 15 y 16)

### 7.1 Subject-ID Probe (5-fold Cross-Validation por Episodios en TRAIN)
- **Precisión (Accuracy):** **79.14%** frente a azar del **14.29%** ($1/7$).
- **Macro-F1:** **0.7845**.
- F1 por sujeto:
  - BLANCA: 0.5394
  - CECILIA: 0.7094
  - DENIS: 0.9318
  - EMILIA: 0.8453
  - GABI: 0.7661
  - GABRIEL: 0.9261
  - IVANNA: 0.7736
Un clasificador lineal simple reconoce la identidad del sujeto con casi 80% de precisión a partir de un solo vector WMoos40.

### 7.2 Intent Probe de Referencia (BASELINE E3D sobre VALIDATION)
- `DIRECTION_F1_ORIGINAL`: **0.810528**
- `PHASE_DIRECTION_F1_ORIGINAL`: **0.510308**
- Brecha TRAIN $\to$ VALIDATION original:
  - Dirección: **0.104292** (0.914820 $\to$ 0.810528)
  - Fase-Dirección: **0.190580** (0.700888 $\to$ 0.510308)

---

## 8. Evaluación de la Normalización Candidata y Gates A–K

Normalización evaluada: `ROBUST_TRAIN_STANDARDIZATION` ($x' = (x - \text{med}_{\text{TRAIN}}) / (\text{MAD}_{\text{TRAIN}} + 10^{-6})$).  
Entrenada bajo condiciones supervisadas idénticas en 3 semillas (`20260923, 20260924, 20260925`).

### 8.1 Tabla de Gates Preregistrados

| Gate | Criterio | Valor BASELINE (ORIGINAL) | Valor NORMALIZED | Umbral Preregistrado | Resultado |
|---|---|---|---|---|---|
| **A** | Reducción predictibilidad Subject-ID | Acc = 0.7914 | **Acc = 0.8300** | $\le 0.7123$ ($-10\%$) | ❌ **FAIL** (+3.86 pp) |
| **B** | Direction F1 VALIDATION no empeora | F1 = 0.8105 | **F1 = 0.8056** | $\ge 0.7905$ ($-2$ pp) | ✅ **PASS** ($-0.49$ pp) |
| **C** | Phase-Direction F1 VALIDATION no empeora | F1 = 0.5103 | **F1 = 0.4584** | $\ge 0.4903$ ($-2$ pp) | ❌ **FAIL** ($-5.19$ pp) |
| **D** | Gap TRAIN $\to$ VAL disminuye | Dir: 0.1043 / Phase: 0.1906 | **Dir: 0.1256 / Phase: 0.2806** | Menor que baseline | ❌ **FAIL** (Brecha aumenta) |
| **E** | Opening MSE VALIDATION mejora $\ge 10\%$ | MSE = 0.05806 | **MSE = 0.05424** | $\le 0.05226$ ($-10\%$) | ❌ **FAIL** (Mejora 6.57%) |
| **F** | Closing MSE no empeora $>5\%$ | MSE = 0.12019 | **MSE = 0.10431** | $\le 0.12620$ ($+5\%$) | ✅ **PASS** (Mejora 13.22%) |
| **G** | Global MSE mejora | MSE = 0.08913 | **MSE = 0.07928** | $< 0.08913$ | ✅ **PASS** (Mejora 11.05%) |
| **H** | Estabilidad (ciclos y periodicidad) | 0 ciclos / 0 periodicidad | **0 ciclos / 0 periodicidad** | $= 0$ | ✅ **PASS** |
| **I** | Reversiones M3 no aumentan | 0 reversiones | **0 reversiones** | $\le 1$ | ✅ **PASS** |
| **J** | Diversidad de acción | Max frac = 0.8407 | **Max frac = 0.8480** | $\le 0.90$ | ✅ **PASS** |
| **K** | Causalidad para nuevo sujeto | N/A | **100% Causal y desplegable** | Causal = YES | ✅ **PASS** |

**Resultado Global:** **7 PASS, 4 FAIL** $\implies$ **`NORMALIZATION_SUPPORTED = NO`**.

---

## 9. Interpretación Científica y Causa Raíz

1. **Por qué falló el Gate A (Predictibilidad de sujeto aumentó de 79.1% a 83.0%):**
   Una normalización global escalar ajusta a la población media, pero no remueve la firma espacial individual (relaciones relativas entre los 8 canales Myo). Al estandarizar las escalas de todos los features, la firma individual de cada sujeto se vuelve numéricamente más nítida y más fácilmente separable linealmente.
2. **Por qué falló el Gate D (La brecha de generalización creció):**
   La red neuronal aprende a sobre-especializarse en las firmas individuales de los 7 sujetos de TRAIN con mayor facilidad, reduciendo la transferencia a los sujetos de VALIDATION (la brecha de fase-dirección creció de 19.1 pp a 28.1 pp).
3. **Por qué el Gate E no alcanzó el 10%:**
   Aunque la MSE de apertura mejoró un 6.57% (0.05806 $\to$ 0.05424) y la MSE global un 11.05%, la representación sigue sin generalizar la cinemática fina de apertura a sujetos nuevos.

---

## 10. Decisión Final y Siguiente Cuello de Botella

```
E3E_RESULT                                   = NORMALIZATION_NOT_SUPPORTED
NORMALIZATION_SUPPORTED                      = NO
E3F_PREPARATION                              = NO
RECURRENT_POLICY                             = NO
MAX_AGENT_STEPS                              = 0
LONG_TRAINING_STARTED                        = NO
MATEO_SANDRA_SEALED                          = YES
REFERENCE_CONTRACT_VALIDATED                 = NO
HARDWARE_AUTHORIZED                          = NO
E3D_FILES_MODIFIED                           = NO
GIT_REPAIR_ATTEMPTED                         = NO
PUSH                                         = NO
```

### Clasificación del Cuello de Botella:
`NEXT_BOTTLENECK = SUBJECT_ADAPTATION_REQUIRED`

### Hipótesis Científica Recomendada para la Siguiente Etapa (no implementada):
Dado que una transformación escalar global no puede eliminar el acoplamiento espacial entre canales específico de cada sujeto, y dado que no existe un período de reposo implícito en los datos actuales (`INITIAL_WINDOW_STABLE = NO`), la solución científica requiere:
1. **Blanqueamiento / decorrelación espacial invariante de sujeto** (e.g. Mahalanobis / PCA espacial de canales) o
2. **Aprendizaje de representaciones invariantes de sujeto** mediante regularización adversarial (Gradient Reversal Layer penalizando la predictibilidad de Subject-ID) o
3. **Protocolo de adquisición con calibración explícita previa** (sesión de 2 segundos de reposo activo etiquetado antes del uso).

*No se implementa ni se ejecuta ninguna variante en esta sesión.*
