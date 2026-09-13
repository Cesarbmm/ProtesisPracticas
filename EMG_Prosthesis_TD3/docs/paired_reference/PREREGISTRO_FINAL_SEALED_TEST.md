# PREREGISTRO CIENTÍFICO: PROTOCOLO DEL TEST FINAL SELLADO (MATEO & SANDRA)

**Fecha de Preregistro:** 2026-09-10  
**Proyecto:** EMG_Prosthesis_TD3 (Paired Reference Benchmark)  
**Worktree:** `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`  
**Rama:** `experiment/no-glove-paired-reference-td3`  
**Estado:** CONGELADO A PRIORI — SUJETOS COMPLETAMENTE SELLADOS Y NO ABIERTOS

---

## 1. Declaración de Blindaje y Aislamiento

- **Sujetos del Test Sellado:** `MATEO` y `SANDRA`.
- **Regla Fundamental:** Queda estrictamente prohibido acceder, inspeccionar, leer o cargar cualquier dato, EMG, cinemática o archivo perteneciente a `MATEO` o `SANDRA` antes de que el agente final E4 esté completamente entrenado, congelado y con su hash SHA-256 registrado.
- Este documento establece el protocolo, políticas comparadas y compuertas de decisión de manera inmutable antes de la apertura del conjunto sellado.

---

## 2. Políticas Comparadas en el Test Sellado

Se evaluarán de forma apareada exactamente sobre los mismos episodios sellados las siguientes políticas:

1. **ZERO (Control Pasivo / Basal):**
   - Emite acción continua 0 ($PWM = 0$) en todos los pasos temporales.
2. **Agent7250 (Baseline Histórico Congelado TD3):**
   - Agente continuo TD3 histórico de referencia (`experiments/paired_reference/Agent7250.mat`).
3. **P2 Privilegiado (Docente Privilegiado):**
   - Política con acceso directo a la referencia del guante en tiempo real ($q_{ref}$).
   - **Clasificación:** PRIVILEGIADO / NO DEPLOYABLE (sólo sirve como cota de referencia superior).
4. **Oracle H5 Privilegiado (Oráculo Cinemático Privilegiado):**
   - Oráculo cinemático con acceso no causal al horizonte futuro.
   - **Clasificación:** PRIVILEGIADO / NO DEPLOYABLE.
5. **FINAL E4 PPO Categorical (Agente Candidato de Desarrollo):**
   - Checkpoint final congelado `CategoricalStep000500000.mat` entrenado exclusivamente sobre los 10 sujetos DEVELOPMENT.
   - **Clasificación:** DEPLOYABLE / GLOVE-FREE.

### Comparación Primaria Desplegable (Primary Deployable Comparison):
$$\text{FINAL E4 (PPO Categórico)} \quad \text{vs.} \quad \text{Agent7250 (TD3 Histórico)}$$

---

## 3. Compuertas Científicas del Benchmark (Benchmark Gates)

El test sellado no constituye una prueba estadística poblacional infinita (dado que el conjunto de prueba sellado consta de 2 sujetos), sino una compuerta estricta de evaluación de generalización dentro del benchmark:

### Compuerta A — Tracking Superior en Test Sellado:
$$\text{Macro-MSE}_{\text{FINAL\_E4}} < \text{Macro-MSE}_{\text{Agent7250}}$$
calculado sobre la totalidad de los episodios de evaluación sellados de MATEO y SANDRA.

### Compuerta B — Desempeño por Sujeto Sellado:
Ningún sujeto sellado (`MATEO` ni `SANDRA`) puede sufrir una degradación de MSE superior al $10\%$ respecto a `Agent7250`:
$$\frac{\text{MSE}_{\text{FINAL\_E4}}(s) - \text{MSE}_{\text{Agent7250}}(s)}{\text{MSE}_{\text{Agent7250}}(s)} \le 0.10, \quad \forall s \in \{\text{MATEO}, \text{SANDRA}\}$$

### Compuerta C — Ausencia de Ciclos Patológicos:
$$0 \text{ ciclos en la evaluación sellada final} \quad (\text{cycles} = 0)$$

### Compuerta D — Ausencia de Periodicidades Límite:
$$0 \text{ estados periódicos persistentes} \quad (\text{periodic} = 0)$$

### Compuerta E — Control de Retrocesos en M3:
La tasa de reversiones en el motor 3 (M3 reversal rate) de `FINAL_E4` no debe exceder a la tasa registrada por `Agent7250` en los mismos episodios sellados.

### Compuerta F — Control de Saturación y Colapso de Acción:
$$\text{MAX\_CATEGORY\_FRACTION} \le 0.90 \quad \text{por motor}$$

*(Nota: La recompensa total es una métrica secundaria explicativa; las compuertas de decisión se basan estrictamente en tracking cinemático, estabilidad y ausencia de artefactos motores).*

---

## 4. Reglas de Decisión Posterior al Test Sellado

### Caso 1: El Test Sellado NO Cumple las Compuertas (FALLO)
- Se reporta con transparencia científica total.
- **Queda estrictamente prohibido volver a la fase de desarrollo para modificar la política y re-evaluar a MATEO y SANDRA.**
- Un conjunto de test sellado se abre **una sola vez**. Si se falla, el proyecto concluye formalmente que el espacio de características actual no generaliza al test sellado y la siguiente etapa requerirá adquisición de nuevos datos (`NEW DATA ACQUISITION`).

### Caso 2: El Test Sellado Cumple las Compuertas (ÉXITO)
- `FINAL_E4` queda consagrado como el mejor modelo del benchmark y supera al baseline histórico TD3 en generalización sellada libre de guante.
- No obstante, se mantiene explícitamente:
  - `REFERENCE_CONTRACT_VALIDATED = NO` (la referencia docente histórica no está validada clínicamente).
  - `HARDWARE_AUTHORIZED = NO` (no autoriza despliegue en paciente ni banco físico sin validación de hardware y calibración independiente).
