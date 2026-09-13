# PREREGISTRO CIENTÍFICO: ETAPA E4 — FINAL DEVELOPMENT TRAINING

**Fecha de Preregistro:** 2026-09-10  
**Proyecto:** EMG_Prosthesis_TD3 (Paired Reference Benchmark)  
**Worktree:** `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`  
**Rama:** `experiment/no-glove-paired-reference-td3`  
**Estado:** CONGELADO ANTES DEL ENTRENAMIENTO

---

## 1. Justificación y Cambio de Fase

La fase de exploración de arquitecturas (E3A-X, E3B, E3C, E3D, E3E, E3F) ha concluido y queda oficialmente **CERRADA**:
- **TD3 / Agent7250:** Baseline histórico de referencia (Validation MSE ≈ 0.051598).
- **E3A-X (TD3 nuevo):** Aprendió frente a ZERO (Best Validation MSE ≈ 0.05998), pero presentó saturación severa y retrocesos en M3.
- **E3B (Factorized Categorical PPO Feed-Forward):** Mostró el mejor compromiso en tracking, estabilidad, discreción estricta de PWM (15 categorías), ausencia de retrocesos patológicos y generalización (Best Validation MSE ≈ 0.057439 a 500k pasos; Last 1M ≈ 0.061475).
- **E3C / E3D (Temporal / Contexto):** No demostraron beneficio empírico (`TEMPORAL_INFORMATION_NOT_DEMONSTRATED`).
- **E3E (Domain Audit):** Confirmó domain shift significativo inter-sujeto (`NORMALIZATION_NOT_SUPPORTED`).
- **E3F (Subject-Invariant PPO con GRL):** Redujo sustancialmente Subject-ID, pero destruyó información de intención direccional (`SUBJECT_INVARIANT_CONTROL_NOT_SUPPORTED`, Best Validation MSE ≈ 0.058306 a 1M pasos).

Se selecciona formalmente la arquitectura **E3B — Factorized Categorical PPO Feed-Forward** para el entrenamiento final de desarrollo: **Etapa E4**.

---

## 2. Objetivo de la Etapa E4

Entrenar un único agente de desarrollo final incorporando **todos los 10 sujetos DEVELOPMENT** disponibles durante la fase de diseño.
- **Sujetos de Entrenamiento (10 sujetos DEVELOPMENT):**
  `BLANCA`, `CECILIA`, `DENIS`, `EMILIA`, `GABI`, `GABRIEL`, `IVANNA`, `JOE`, `JONATHAN`, `KHAROL`.
- **Sujetos Sellados (NO utilizados, NO abiertos):**
  `MATEO`, `SANDRA`.
- **Split de Validación:**
  **NINGUNO (`NONE`)**. `JOE`, `JONATHAN` y `KHAROL` ya cumplieron su rol de validación durante la selección de arquitectura y ahora aportan su variabilidad al modelo final de desarrollo. No se crean particiones de validación artificiales.

---

## 3. Principio Estadístico

E4 **NO** se utilizará para optimizar hiperparámetros, modificar el presupuesto, ajustar la arquitectura ni seleccionar checkpoints. Todo queda congelado a priori. El propósito exclusivo es maximizar la cobertura del dominio de desarrollo antes del congelamiento final previo al test sellado.

---

## 4. Arquitectura y Espacio de Acción Congelados (Idénticos a E3B)

- **Vector de Observación (markov52):**
  - Dimensión: 52 entradas.
  - Componentes: 40 WMoos (EMG) + 4 $q$ normalizados + 4 $\Delta q$ + 4 acciones efectivas previas ($PWM_{t-1} / 255$).
  - Prohibido: No añadir subject ID, dirección, fase, teacher, reward, historia temporal, memoria recurrente ni latentes GRL/E3F.
- **Red Actor (E3B Feed-Forward Factorizado):**
  - Entrada: 52 $\to$ FC64 $\to$ ReLU $\to$ FC64 $\to$ ReLU $\to$ 4 cabezas independientes de FC15 (una por motor).
  - Distribución conjunta: $P(a|s) = \prod_{m=1}^4 P_m(a_m|s)$.
  - Log-probabilidad conjunta: $\log P(a|s) = \sum_{m=1}^4 \log P_m(a_m|s)$.
  - Entropía conjunta: $H(a|s) = \sum_{m=1}^4 H(P_m)$.
  - Categorías PWM por motor (15 niveles discretos):
    `[0, -64, +64, -96, +96, -128, +128, -160, +160, -192, +192, -224, +224, -255, +255]`.
- **Red Crítico (E3B Feed-Forward):**
  - Entrada: 52 $\to$ FC64 $\to$ ReLU $\to$ FC64 $\to$ ReLU $\to$ FC1 ($V(s)$ escalar).

---

## 5. Receta PPO y Optimización Congeladas

- Factor de descuento ($\gamma$): $0.99$
- Parámetro GAE ($\lambda$): $0.95$
- Longitud máxima de rollout: $1024$ pasos de agente
- Épocas PPO por actualización: $4$
- Tamaño de minibatch: $64$
- Parámetro de recorte PPO ($\epsilon_{clip}$): $0.20$
- Coeficiente de entropía: $0.01$
- Optimizador Actor: Adam ($LR = 3 \times 10^{-4}$, $\beta_1 = 0.9$, $\beta_2 = 0.999$, $\epsilon = 10^{-8}$)
- Optimizador Crítico: Adam ($LR = 1 \times 10^{-3}$, $\beta_1 = 0.9$, $\beta_2 = 0.999$, $\epsilon = 10^{-8}$)
- Límite de norma de gradiente global: $0.5$
- Normalización de ventajas: Normalización por lote de rollout
- Normalización de recompensa: Ninguna adicional
- Programación de LR / Early stopping por KL: Ninguno

---

## 6. Presupuesto Fijo, Checkpoints y Criterio FINAL_AGENT

- **Presupuesto Máximo de Pasos:** **500,000 pasos de agente** (`MAX_AGENT_STEPS = 500000`) exactamente.
  *Justificación científica:* En E3B, la generalización alcanzó su pico óptimo a los 500,000 pasos; continuar a 750k o 1M degradó la generalización.
- **Checkpoints Diagnósticos Guardados:**
  `50000`, `100000`, `250000`, `500000`.
- **Criterio de Selección de Checkpoint:**
  **`CHECKPOINT_SELECTION = NONE`**.
  El agente final será estrictamente el checkpoint al paso 500,000:
  `FINAL_AGENT = CategoricalStep000500000.mat`.
  Queda prohibido seleccionar 250k o cualquier otro paso intermedio en función de curvas de entrenamiento.

---

## 7. Semillas Preregistradas

- **Semilla Científica E4 (Entrenamiento Principal):** `SCIENTIFIC_SEED = 20260920`
- **Semilla Smoke E4 (Prueba de Cableado y Tubería):** `SMOKE_SEED = 20260921`
- Un único agente científico será entrenado. Prohibido ejecutar múltiples semillas para seleccionar la más favorable.

---

## 8. Auditoría de Muestreo (Sampling Audit)

Durante el entrenamiento con los 10 sujetos, se registrará el número de episodios, pasos, aperturas y cierres generados por cada sujeto para garantizar trazabilidad e interpretabilidad completa del régimen de datos.

---

## 9. Postprocesamiento de Desarrollo y Congelamiento

Al finalizar los 500,000 pasos:
1. Se congelará `FINAL_AGENT` registrando su hash SHA-256 inmutable.
2. Se evaluará sobre los 200 episodios DEVELOPMENT únicamente como caracterización in-sample (COMPACT, PRO, CLASSIC, ANNOTATED, trazas numéricas CSV/MAT).
3. **Bajo ninguna circunstancia se abrirán MATEO ni SANDRA durante esta etapa.**
