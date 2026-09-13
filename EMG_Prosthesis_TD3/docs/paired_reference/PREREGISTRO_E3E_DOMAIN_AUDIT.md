# PREREGISTRO E3E — Cross-Subject EMG Domain Audit

**Fecha:** 2026-09-09  
**Worktree:** `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`  
**Rama:** `experiment/no-glove-paired-reference-td3`  
**HEAD:** `165be049eb41fc41254435181c9857fe0f22ed1c`  
**Etapa:** E3E — CROSS-SUBJECT EMG DOMAIN AUDIT  

---

## 1. Contexto Científico y Justificación

Tras los resultados de E3D (`TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED`), donde la adición de memoria temporal EMG empeoró la apertura en VALIDATION (+9.71% MSE) pese a mejorarla en TRAIN, se descartó la línea de PPO recurrente y se abrió la presente auditoría de dominio entre sujetos.

### 1.1 Hallazgos de la Auditoría Diagnóstica Previa (Fase 1)
1. **Cobertura de datos:** `OPENING_DATA_COVERAGE = 1468`, `CLOSING_DATA_COVERAGE = 1470`, `OPEN_CLOSE_IMBALANCE = 0.9986`. El conjunto está perfectamente balanceado entre apertura y cierre tanto en TRAIN (1037 vs 1039) como en VALIDATION (431 vs 431). `DATA_COVERAGE_PROBLEM = NO`.
2. **Ventana inicial ($N=1, 2, 3, 5$):** A paso $N=1$, el 100% (40/40) de los features `WMoos` presentan diferencias estadísticamente significativas entre apertura y cierre ($p < 0.05$, diferencia media absoluta = 0.6425, máxima = 2.1120). No existe un estado de reposo neutro al inicio de los episodios. `INITIAL_WINDOW_STABLE = NO`. No es científicamente defendible usar los primeros pasos para calibración de reposo por episodio.
3. **Descomposición de varianza:** ANOVA de 2 vías (Sujeto $\times$ Intención) sobre TRAIN revela que la identidad del sujeto explica en promedio el 30.55% de la varianza total de cada feature, frente a sólo el 0.29% explicado por la intención. `SUBJECT_TO_INTENT_VARIANCE_RATIO`: Media = 107.86, Mediana = 22.09, Mínimo = 3.54 (los 40 features son dominados por el sujeto).
4. **Subject-ID Probe en TRAIN:** Un clasificador lineal fuera de pliegue (5-fold cross-validation por episodios) identifica al sujeto generador con **79.14% de accuracy** y **Macro-F1 = 0.7845** (frente a un azar de 14.29%). `SUBJECT_SHIFT_DETECTED = YES`.
5. **Procedencia de `normValues.mat`:** `normValues.mat` no proviene de los sujetos de Denis ni de la tarea de tracking; proviene de un corpus externo de 306 sujetos y 6 gestos discretos (`C` y `S` no alineados con el rango dinámico de Denis).

---

## 2. Normalización Candidata Preregistrada

Dado que `INITIAL_WINDOW_STABLE = NO`, no se autoriza ninguna normalización por ventana de inicio ni por calibración local de episodio.  
Se preregistra **UNA SOLA** transformación: **Estandarización Robusta Global Ajustada Estrictamente en TRAIN** (`ROBUST_TRAIN_STANDARDIZATION`):

$$x'_i = \frac{x_i - \text{median}_{\text{TRAIN}, i}}{\text{MAD}_{\text{TRAIN}, i} + \epsilon}$$

donde:
- $\text{median}_{\text{TRAIN}, i}$ es la mediana del feature $i$ ($i \in \{1, \dots, 40\}$) calculada exclusivamente sobre los 2076 samples de TRAIN.
- $\text{MAD}_{\text{TRAIN}, i} = \text{median}(|x_{\text{TRAIN}, i} - \text{median}_{\text{TRAIN}, i}|)$ calculada exclusivamente sobre TRAIN.
- $\epsilon = 10^{-6}$ (constante para estabilidad numérica).

### Propiedades Obligatorias
- **Causalidad estricta:** La transformación consiste en parámetros estáticos fijos ($A_i = \frac{1}{\text{MAD}_i + \epsilon}$, $B_i = -\frac{\text{median}_i}{\text{MAD}_i + \epsilon}$). Para un sujeto nuevo de test, la transformación es instantánea, punto a punto, sin retraso temporal y sin depender de muestras futuras ni de etiquetas.
- **Sin fuga:** Ni un solo dato de VALIDATION (`JOE`, `JONATHAN`, `KHAROL`) ni de los sujetos sellados interviene en el cálculo de $\text{median}_{\text{TRAIN}}$ ni $\text{MAD}_{\text{TRAIN}}$.

---

## 3. Split y Datos Congelados

- **TRAIN:** `BLANCA`, `CECILIA`, `DENIS`, `EMILIA`, `GABI`, `GABRIEL`, `IVANNA` (140 episodios, 2076 samples).
- **VALIDATION:** `JOE`, `JONATHAN`, `KHAROL` (60 episodios, 862 samples).
- **MATEO y SANDRA:** Estrictamente SELLADOS.
- Fuente de datos: `EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3c_results/supervised_data.mat`.

---

## 4. Arquitectura y Receta de Evaluación

Para comparar `ORIGINAL` vs `NORMALIZED` bajo condiciones científicas idénticas:
- **Red:** Exactamente la arquitectura `BASELINE` de E3D:
  - Entrada EMG: 40 features (originales vs normalizados) $\to$ `FC64` $\to$ `ReLU`.
  - Entrada mecánica actual: 12 valores actuales $\to$ concatenación con EMG $\to$ `FC64` $\to$ `ReLU` (latent).
  - Heads de acción: 4 heads $\times$ 15 categorías.
  - Head de intención: `direction` (2 clases, softmax).
  - Head de intención: `phase_direction` (6 clases, softmax).
- **Optimizador:** Adam, learning rate = 0.001, gradient clipping = 1.0.
- **Épocas:** 40 épocas supervisadas.
- **Batch size:** 64.
- **Semillas:** `20260923, 20260924, 20260925` (3 semillas pareadas, reporte en media).
- **Evaluación closed-loop:** Rollout causal sobre los 200 episodios (`e3axRollout` / `GloveFreePolicyRuntime`) con la planta simulada `patternCurveCanonical`.

---

## 5. Gates Cuantitativos Preregistrados A–K

Para declarar `NORMALIZATION_SUPPORTED = YES`, deben cumplirse simultáneamente los 11 gates siguientes (calculados como media de las 3 semillas sobre VALIDATION):

| Gate | Criterio | Umbral Preregistrado | Justificación |
|---|---|---|---|
| **A** | Reducción de predictibilidad Subject-ID | $\text{Accuracy}_{\text{norm}} \le 0.90 \times \text{Accuracy}_{\text{orig}}$ | Reduce la firma de identidad en al menos 10% relativo |
| **B** | Direction F1 en VALIDATION | $\text{F1}_{\text{norm}} \ge \text{F1}_{\text{orig}} - 0.02$ | No destruye la clasificación de dirección motora |
| **C** | Phase-Direction F1 en VALIDATION | $\text{F1}_{\text{norm}} \ge \text{F1}_{\text{orig}} - 0.02$ | No destruye la intención fina de fase-dirección |
| **D** | Brecha TRAIN $\to$ VALIDATION | $\text{Gap}_{\text{norm}} < \text{Gap}_{\text{orig}}$ | Reduce la sobre-especificidad a los sujetos de entrenamiento |
| **E** | MSE Apertura en VALIDATION | $\text{MSE}_{\text{open, norm}} \le 0.90 \times \text{MSE}_{\text{open, orig}}$ | Mejora material de al menos 10% en el seguimiento de apertura |
| **F** | MSE Cierre en VALIDATION | $\text{MSE}_{\text{close, norm}} \le 1.05 \times \text{MSE}_{\text{close, orig}}$ | No degrada el cierre más de 5% |
| **G** | MSE Global en VALIDATION | $\text{MSE}_{\text{global, norm}} < \text{MSE}_{\text{global, orig}}$ | Mejora neta del control global |
| **H** | Estabilidad | Ciclos = 0, Periodicidades = 0 | Mantiene estabilidad estricta |
| **I** | Reversiones M3 | Reversiones M3 $\le$ Baseline + 1 | No reintroduce inestabilidad M3 |
| **J** | Diversidad de acción | $\text{MAX\_CATEGORY\_FRACTION} \le 0.90$ | Evita colapso a una sola acción constante |
| **K** | Causalidad y Despliegue | Causal para sujeto nuevo = YES | Factible en tiempo real sin ver el futuro ni requerir reposo |

Si cualquiera de los gates falla:
`NORMALIZATION_SUPPORTED = NO`.
No se autoriza probar una segunda normalización de forma automática. Se cierra E3E y se clasifica el siguiente cuello de botella.
