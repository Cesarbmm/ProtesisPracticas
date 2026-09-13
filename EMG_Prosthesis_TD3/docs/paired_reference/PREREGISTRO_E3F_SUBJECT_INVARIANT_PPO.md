# PREREGISTRO CIENTÍFICO — ETAPA E3F: SUBJECT-INVARIANT FACTORIZED CATEGORICAL PPO

- **Proyecto:** EMG_Prosthesis_TD3
- **Worktree:** C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit
- **Rama:** experiment/no-glove-paired-reference-td3
- **HEAD Base:** 165be049eb41fc41254435181c9857fe0f22ed1c
- **Fecha de Congelación:** Septiembre 2026
- **Estado:** CONGELADO ANTES DEL SMOKE TEST Y ENTRENAMIENTO

---

## 1. Motivación y Decisión Científica

La auditoría de dominio de la etapa **E3E** demostró de forma concluyente:
1. **Sin problema de cobertura:** Apertura ($ muestras) vs Cierre ($ muestras) descarta que el fallo de apertura se deba a desbalance de clases (DATA_COVERAGE_PROBLEM = NO).
2. **Ventana inicial activa:** En =1$, el 100% de los 40 features WMoos difiere significativamente entre apertura y cierre ( < 0.05$), impidiendo asumir reposo pasivo (INITIAL_WINDOW_STABLE = NO).
3. **Fuerte domain shift entre sujetos:** La razón de varianza entre sujeto e intención motora ($\\eta^2_{\\text{subject}}/\\eta^2_{\\text{intent}}$) tiene una media de .86$ y mediana de .09$, dominando el sujeto en 40/40 features (SUBJECT_SHIFT_DETECTED = YES). Un clasificador lineal sobre WMoos40 predice la identidad del sujeto con .14\%$ de exactitud (chance: .29\%$).
4. **Rechazo de normalización estática/robusta:** La estandarización robusta empeoró la exactitud de predicción de sujeto (.00\%$), degradó el F1 de dirección de fase (.5103 \to 0.4584$) y no superó el gate de mejora del 10% en closed-loop (NORMALIZATION_SUPPORTED = NO, E3E_RESULT = NORMALIZATION_NOT_SUPPORTED).
5. **Cuello de botella identificado:** NEXT_BOTTLENECK = SUBJECT_ADAPTATION_REQUIRED.

Por consiguiente, la etapa **E3F** adopta una estrategia de **aprendizaje de representación invariante al sujeto** mediante entrenamiento adversarial con capa de inversión de gradiente (**Gradient Reversal Layer - GRL**).

---

## 2. Hipótesis Científica Formal

> **Hipótesis E3F:**  
> Un agente PPO multicategórico factorizado generaliza mejor en control en bucle cerrado a sujetos no vistos (JOE, JONATHAN, KHAROL) si su encoder EMG es entrenado de manera adversarial para preservar la información de control motor mientras elimina la información predictiva de la identidad del sujeto, manteniendo el espacio de acciones categóricas discretizadas y el MDP idéntico a E3B.

---

## 3. Arquitectura del Modelo

### 3.1 Rama EMG (Encoder Latente)
\\text{WMoos40} \\xrightarrow{\\text{FC64}} \\text{ReLU} \\xrightarrow{\\text{FC64}} \\text{ReLU} \\longrightarrow \\text{EMG\_LATENT64}
- Entrada: 40 features causales de WMoos originales (sin normalización estática adicional).
- Salida: vector latente de 64 dimensiones ($\\text{EMG\_LATENT64}$).

### 3.2 Rama Mecánica
\\text{mechanical}_{12} = [q_4, \\Delta q_4, a_{t-1, \\text{eff}}] \\quad (12 \\text{ entradas})
- Excluida estrictamente del discriminador de sujeto (la cinemática de la prótesis no debe entrar al discriminador).

### 3.3 Tronco de Control y Cabezas de Acción (Actor Feed-Forward)
[\\text{EMG\_LATENT64} \\,;\\, \\text{mechanical}_{12}] \\xrightarrow{\\text{FC64}} \\text{ReLU} \\longrightarrow 4 \\text{ cabezas categóricas} \\times 15 \\text{ categorías}
- Las 4 cabezas corresponden a los 4 motores independientes de la prótesis.
- En tiempo de inferencia / despliegue: el actor se evalúa exclusivamente como red feed-forward  \\to [4 \\times 15]$, sin invocar ni requerir el discriminador ni etiquetas de sujeto.

### 3.4 Discriminador de Dominio / Sujeto (Solo en Entrenamiento)
\\text{EMG\_LATENT64} \\xrightarrow{\\text{GRL}(\\lambda_{\\text{adv}} = 0.10)} \\text{FC32} \\xrightarrow{\\text{ReLU}} \\text{FC7} \\longrightarrow \\text{Softmax}(\\text{TRAIN Sujetos})
- Clases de salida ($ sujetos de desarrollo):
  1. BLANCA
  2. CECILIA
  3. DENIS
  4. EMILIA
  5. GABI
  6. GABRIEL
  7. IVANNA
- Los sujetos de VALIDATION (JOE, JONATHAN, KHAROL) **no** son clases del discriminador.
- Los sujetos SELLADOS (MATEO, SANDRA) **no** se cargan bajo ninguna circunstancia.

### 3.5 Crítico
V(s): 52 \\xrightarrow{\\text{FC64}} \\text{ReLU} \\xrightarrow{\\text{FC64}} \\text{ReLU} \\xrightarrow{\\text{FC1}} 1
- Totalmente independiente; no comparte capas con el actor ni con el discriminador adversarial.

---

## 4. Implementación y Parámetros de la GRL

### 4.1 Formulación Matemática
- **Paso Forward:**
  \\text{GRL}(x) = x
- **Paso Backward:**
  \\frac{\\partial L}{\\partial x} = -\\lambda_{\\text{adv}} \\frac{\\partial L}{\\partial (\\text{GRL}(x))}

### 4.2 Hiperparámetro $\\lambda_{\\text{adv}}$ Congelado
- Valor único preregistrado:
  \\lambda_{\\text{adv}} = 0.10
- Queda estrictamente congelado antes del smoke test. No se realiza barrido ni optimización sobre el conjunto de VALIDATION.

### 4.3 Dinámica de Optimización
- El discriminador se optimiza para minimizar la entropía cruzada de sujeto: $\\min_{\\theta_{\\text{disc}}} L_D$.
- El encoder de EMG recibe dos flujos de gradientes sumados:
  g_{\\text{enc}} = \\nabla_{\\theta_{\\text{enc}}} L_{\\text{PPO}} - \\lambda_{\\text{adv}} \\nabla_{\\theta_{\\text{enc}}} L_D
  forzando a las representaciones latentes a ser invariantes a los sujetos de entrenamiento sin destruir la señal de control.

---

## 5. Hiperparámetros de PPO (Receta Congelada de E3B)

- Descuento ($\\gamma$): .99$
- Parámetro GAE ($\\lambda$): .95$
- Longitud de Rollout: $ pasos de agente
- Épocas PPO: $
- Tamaño de minibatch: $
- Clip ratio ($\\epsilon$): .20$
- Coeficiente de entropía: .01$
- Learning rate del Actor (Adam):  \\times 10^{-4}$
- Learning rate del Crítico (Adam):  \\times 10^{-3}$
- Límite global de gradiente (norm clipping): .5$
- Normalización de ventajas: Activada (por lote)
- Normalización de observaciones: HISTORICAL_ONLY (la normalización histórica de 
ormValues.mat)
- Normalización de reward: Desactivada (False$)

---

## 6. Espacio de Acciones y Equivalencia de Transición

- **Acciones:** $ cabezas $\\times 15$ categorías discretas.
- **Valores discretos de PWM:**
  \\mathcal{C} = [0, -64, +64, -96, +96, -128, +128, -160, +160, -192, +192, -224, +224, -255, +255]
- **Acción efectiva:**
  a_{\\text{eff}} = \\frac{\\text{PWM}}{255}
- **Contrato de equivalencia:** E3F debe preservar idéntico PWM, idéntica acción efectiva, idéntica respuesta del simulador patternCurveCanonical e idéntico reward que E3B para cualquier categoría dada.

---

## 7. Protocolo de División de Sujetos

- **TRAIN (7 sujetos):** BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA.
- **VALIDATION (3 sujetos):** JOE, JONATHAN, KHAROL.
- **SELLADOS (2 sujetos):** MATEO, SANDRA (estrictamente sellados; cualquier acceso invalida la campaña).

---

## 8. Presupuesto y Checkpoints de Evaluación

- **Presupuesto Total:** ,000,000$ pasos de agente.
- **Checkpoints Programados:**
  [50000, 100000, 250000, 500000, 750000, 1000000]
- **Evaluación en Checkpoints:**
  - $ episodios deterministas de VALIDATION (argmax).
  - Métricas registradas: MSE, MAE, Reward, ActionL2, DeltaActionL2, distribución de PWM, MAX_CATEGORY_FRACTION, flat_response, acción sin movimiento, ciclos, periodicidades, reversiones M3.

---

## 9. Criterios Cuantitativos y Gates de Decisión

### 9.1 Criterio Primario de Control (E3F_STRONG_SIGNAL)
Se alcanza señal fuerte si en el MEJOR checkpoint de VALIDATION:
1. $\\text{MSE}_{\\text{VAL}} < 0.051598$ (superando a Agent7250).
2. $ ciclos finales.
3. $ periodicidades finales.
4. Reversiones M3 estables (sin incremento sustancial).
5. $\\text{MAX\_CATEGORY\_FRACTION} \\le 0.90$.

### 9.2 Criterio Secundario de Control (E3F_LEARNING_SIGNAL)
Se alcanza señal de aprendizaje si:
1. $\\text{MSE}_{\\text{VAL}} < 0.057439$ (superando el mejor resultado de E3B a 500k pasos).
2. Libre de patologías cinemáticas (sin ciclos ni colapso de categorías).

### 9.3 Gate de Invariancia de Sujeto (SUBJECT_INVARIANCE_SUPPORTED = YES)
Medido mediante un probe lineal sobre las representaciones congeladas EMG_LATENT64:
1. Exactitud de predicción de identidad de sujeto:
   \\text{LATENT\_SUBJECT\_ID\_ACCURACY} \\le 0.80 \\times 0.7914 \\approx 0.6331
2. $\\text{LATENT\_SUBJECT\_ID\_MACRO\_F1}$ materialmente inferior a .7845$.

### 9.4 Gate de Retención de Intención Motora
Sobre las mismas representaciones congeladas EMG_LATENT64:
1. $\\text{DIRECTION\_MACRO\_F1} \\ge 0.810528 - 0.02 = 0.7905$ (degradación máxima permitida: $ puntos porcentuales).
2. $\\text{PHASE\_DIRECTION\_MACRO\_F1} \\ge 0.510308 - 0.03 = 0.4803$ (degradación máxima permitida: $ puntos porcentuales).

### 9.5 Resultado Decisivo (SUBJECT_INVARIANT_CONTROL_SUPPORTED = YES)
Requiere el cumplimiento simultáneo de:
- A) Mejor MSE supera el de E3B.
- B) Idealmente supera Agent7250 para nivel STRONG.
- C) La brecha de MSE TRAIN $\\to$ VALIDATION disminuye respecto a E3B.
- D) Predictibilidad de identidad de sujeto en el latente disminuye materialmente ($\\le 0.6331$).
- E) F1 de dirección motora no se degrada $> 2$ pp.
- F) F1 de dirección de fase no se degrada $> 3$ pp.
- G) Ausencia total de ciclos y periodicidades.
- H) Reversiones M3 estables.
- I) Sin colapso de categorías.

---

## 10. Criterio de Tendencia y Escalado

- Se reportará la trayectoria de MSE en $[250k, 500k, 750k, 1M]$.
- Si el modelo a $ pasos cumple el criterio E3F_STRONG_SIGNAL y además la tendencia es monótona favorable:
  \\text{MSE}_{500k} \\ge \\text{MSE}_{750k} \\ge \\text{MSE}_{1M} \\quad (\\text{con al menos una mejora estricta})
  y no presenta patologías, entonces:
  \\text{CONTINUE\_TO\_5M\_STEPS} = \\text{YES}
- En caso contrario: CONTINUE_TO_5M_STEPS = NO.

---

## 11. Protocolo de Contingencia (si E3F Falla)

Si tras ,000,000$ de pasos E3F no supera a E3B, no reduce la dependencia de sujeto o degrada la intención motora:
1. **No probar otra arquitectura empírica sobre este dataset histórico.** Se cierra el ciclo de modelado sobre los datos actuales.
2. **Declarar:** NEXT_STEP = NEW_DATA_ACQUISITION.
3. La nueva adquisición de datos deberá registrar explícitamente:
   - Estado de REPOSO (REST) formalmente etiquetado.
   - Movimientos completos de apertura (OPENING) y cierre (CLOSING).
   - Posiciones intermedias estáticas (20%, 40%, 60%, 80%).
   - Múltiples repeticiones a velocidades controladas.
   - Sincronización Myo raw, encoders y referencia geométrica/visual.

---

## 12. Reglas de Integridad y Compromisos Operativos

- LONG_TRAINING_STARTED_BY_AI = NO: La IA solo ejecuta el smoke test de $ episodios y las suites de pruebas. El entrenamiento de 1,000,000 pasos es lanzado manualmente por el usuario en MATLAB Desktop.
- MATEO_SANDRA_SEALED = YES: MATEO y SANDRA permanecen sellados.
- GIT_REPAIR_ATTEMPTED = NO, PUSH = NO.
