# PREREGISTRO — ETAPA E1D (calibración supervisada del sujeto)

**Rama:** `experiment/no-glove-paired-reference-td3` · **SHA de inicio:** `1f254c67`
**Fecha de registro:** 2026-09-05 — **antes de ajustar ningún modelo**

**Antecedentes congelados, que no se reabren:**

```
E1_RESULT  = E1_SUBJECT_SPECIFIC_ONLY
E1B_RESULT = E1B_EMG_ONLY_CALIBRATION_FAIL
E1C_RESULT = STOPPED_AFTER_ORACLE   (CHANNEL_ALIGNMENT_HYPOTHESIS = REFUTED)
             efecto real transferible +3.3 % a +3.5 %
             el +15.5 % nominal fue un artefacto de seleccion de lambda en el fold DENIS
```

---

## 1. Pregunta

¿Cuántos datos **etiquetados del propio usuario** hacen falta para aprender una relación EMG →
referencia lo bastante buena como para operar después sin guante?

## 2. Formulación correcta

```
GLOVE-ASSISTED CALIBRATION  +  GLOVE-FREE OPERATION
```

Durante **calibración**: EMG + guante permitidos. Durante **evaluación/operación**: el decoder está
congelado y **no puede leer el guante**; el guante de evaluación es sólo verdad de terreno offline.

No se describe esta línea como "sin guante" a secas. La promesa cambia y debe decirse así en la
tesis.

```
NEW_USER_GLOVE_REQUIRED_FOR_CALIBRATION = YES
GLOVE_REQUIRED_DURING_OPERATION         = NO
```

## 3. Sujetos

```
DEVELOPMENT (10) : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN, KHAROL
FINAL TEST  (2)  : MATEO, SANDRA        <- SELLADOS
```

MATEO y SANDRA no se usan para elegir modelo, `lambda`, `lambda_personal`, `k`, presupuesto,
arquitectura ni umbrales. Sólo se abren si E1D pasa **todos** los gates en development.

## 4. Protocolo LOSO

10 folds. Para el sujeto dejado fuera: los 9 restantes forman el prior global; sus propios episodios
se parten **por episodio** en `CALIBRATION` y `EVALUATION`.

Se reutiliza la partición determinista ya congelada en E1B/E1C: mitad `POOL_CALIBRACION`, mitad
`EVALUATION`, con semilla fija por sujeto. **`EVALUATION` es idéntico para todos los presupuestos y
todos los brazos.** La calibración toma los `N` primeros episodios por gesto del pool, ordenados por
identificador — determinista y fijado antes de evaluar. Nunca se mezclan ventanas del mismo episodio.

## 5. Presupuestos de calibración

Cálculo previo, **antes** de fijar el límite: 15.27 pasos por episodio × 0.2 s = **3.05 s por
episodio**. El pool de calibración tiene ~150 episodios por gesto y sujeto, así que el techo
disponible ronda los 15 minutos.

| N por gesto | episodios | segundos | minutos |
|---|---|---|---|
| 1 | 2 | 6.1 | 0.10 |
| 2 | 4 | 12.2 | 0.20 |
| 5 | 10 | 30.5 | 0.51 |
| 10 | 20 | 61.0 | 1.02 |
| 20 | 40 | 122.0 | 2.03 |
| 50 (diagnóstico, fuera del límite) | 100 | 305.0 | 5.08 |

```
CALIBRATION_BUDGETS = 1, 2, 5, 10, 20 episodios por gesto
PRESUPUESTO RAZONABLE = <= 5 minutos  ->  <= 49 episodios por gesto
```

Los cinco presupuestos primarios caben con holgura. El de 50 se calcula sólo como sonda del techo y
queda marcado como fuera del límite. La pregunta principal es **cuál es el menor presupuesto con
mejora material y estable**, no cuál minimiza el MSE.

## 6. Brazos

Sin MLP, sin LSTM, sin contexto 120. Las 40 features WMoos históricas exactas, `C`/`S` históricos.

| | |
|---|---|
| **A** | **global ridge** — decoder de E1, sin calibración del nuevo usuario. Baseline. |
| **A'** | global ridge + **sólo intercepto** recalibrado con la calibración del sujeto. Diagnóstico: cuánto se gana con un simple offset. |
| **B** | **subject-only ridge** — ridge 40→4 entrenado únicamente con los episodios de calibración del sujeto. |
| **C** | **regularized personalized ridge** — candidato principal. |
| **M** | predictor media de la calibración del sujeto (además de la media de train). |
| **D** | gesto+fase — `DIAGNOSTIC_ORACLE`, no desplegable. |

### Formulación del brazo C

```
min_W  ||Ycal - Xcal W||^2  +  lambda_personal * ||W - W_global||^2
```

Solución cerrada, con centrado por las medias de calibración:

```
Xc = Xcal - mean(Xcal),  Yc = Ycal - mean(Ycal)
W  = (Xc' Xc + lambda_p I)^{-1} (Xc' Yc + lambda_p W_global)
b  = mean(Ycal) - mean(Xcal) W
```

Equivalencia verificable: con `lambda_p -> 0` recupera el brazo B; con `lambda_p -> inf` recupera
los pesos globales con **intercepto del sujeto**, que es exactamente el brazo A'. Por eso A' se
reporta: delimita por abajo lo que C puede atribuirse.

## 7. `k` temporal — fijado por preregistro, con justificación previa

```
k = +2  fijo
```

Justificación registrada **antes** de ejecutar: la selección anidada sobre folds de development
eligió `k = +2` en **10 de 10 folds** en E1B, y otra vez en **10 de 10** en la configuración común
de E1C. Es un modo robusto, seleccionado siempre dentro de development y nunca con test. Fijarlo
elimina un grado de libertad y evita que cada presupuesto elija su propio `k` mirando su evaluación,
que es justo lo que §7 del encargo prohíbe.

`lambda_global` se fija por el mismo argumento en **1e6**, valor modal de las mismas selecciones
anidadas. Ambos quedan documentados aquí, antes de correr.

`lambda_personal` **sí** se selecciona, y sólo por CV anidada.

## 8. CV anidada obligatoria

El conjunto sobre el que se reporta **no** puede ser el que selecciona `lambda_personal`. Para cada
fold externo `f`, `lambda_personal` se elige minimizando el MSE medio sobre los **otros 9 folds**, y
se reporta sobre los episodios de evaluación de `f`. Si además se selecciona presupuesto, se hace
con la misma regla.

La CV optimista se calcula sólo como diagnóstico. **El número científico es el anidado.**

## 9. Controles de información

Para el brazo personalizado elegido:

- **CONTROL 1:** barajar los targets entre episodios de `CALIBRATION`.
- **CONTROL 2:** barajar el emparejamiento EMG–target dentro del mismo gesto y bin de fase de
  `CALIBRATION`.

El desempeño en `EVALUATION` debe degradarse. Esto distingue aprendizaje real de reproducir una
trayectoria media del gesto.

## 10. Métricas

MSE · MAE · Pearson r · Spearman rho · sign accuracy de Δy · por motor · opening · closing · por
sujeto · media · mediana · desviación entre sujetos · `calibration_episodes` ·
`calibration_seconds` · curva MSE frente a segundos de calibración.

## 11. GATE E1D — umbrales fijados AHORA

E1D pasa si el mejor decoder personalizado cumple las ocho:

| # | condición | umbral |
|---|---|---|
| 1 | reducción de MSE frente al global ridge (A) | **≥ 20 %** |
| 2 | reducción de MSE frente al predictor media | **≥ 15 %** |
| 3 | sign accuracy | **mejora** frente a A |
| 4 | sujetos que mejoran | **≥ 8 de 10** |
| 5 | motores que mejoran | **≥ 3 de 4** |
| 6 | CONTROL 1 (targets barajados) degrada | **≥ +15 %** de MSE |
| 6b | CONTROL 2 (condicionado) degrada | **> +5 %** de MSE |
| 7 | el efecto se mantiene con CV anidada | el número anidado cumple 1 y 2 |
| 8 | presupuesto razonable | **≤ 5 min** (≤ 49 episodios por gesto) |

**Precisión sobre la condición 2:** el "predictor media" de referencia es la **media de la
calibración del sujeto**, no la de train. Es la más exigente de las dos y es lo que haría un sistema
trivialmente personalizado. Se reportan ambas.

Superar el baseline D (gesto+fase) sería especialmente fuerte, pero **no** se convierte en
requisito: no estaba preregistrado como tal.

## 12. Resultados posibles

```
E1D_SUPERVISED_CALIBRATION_PASS  -> se abre MATEO/SANDRA, una sola vez, con todo congelado
E1D_DATA_HUNGRY                  -> funciona pero exige demasiados datos; no se abre E2
E1D_FAIL                         -> se cierra la linea de guante virtual con este dataset
```

## 13. Test final

Sólo si development pasa todos los gates. Antes de abrirlo se congelan: modelo, `lambda_global`,
`lambda_personal`, `k`, presupuesto, selección exacta de episodios de calibración, preprocesado,
métricas y hashes. Se ejecuta **una sola vez** y no se ajusta nada después.

## 14. Fuera de alcance

```
E2_PLANT_BLOCKED = YES
```

E1D es puramente offline: no construye `Env`, `SimController`, `prosthesis_simulator` ni TD3. El
bloqueo de planta por la dependencia de Curve Fitting Toolbox sigue vigente y **no se resuelve
aquí**. Tampoco: RL, Myo real, hardware, MLP, LSTM, corregir WMoos, recalcular `C`/`S`,
`actionCommandScale`, `motionPermission`, reposo, oposición, reward, ni tocar `main`.

## 15. Resultado

Ejecutado 2026-09-05. Detalle en `09_RESULTADOS_E1D.md`.

```
GLOBAL_RIDGE_MSE                   = 0.040639
SUBJECT_ONLY_RIDGE_MSE             = 0.034312 (N=5) / 0.033054 (N=10)
PERSONALIZED_RIDGE_MSE             = 0.036353 anidado / 0.033935 (N=5) / 0.032608 (N=10)
PERSONALIZED_IMPROVEMENT_VS_GLOBAL = +10.5% anidado   (umbral 20%)
PERSONALIZED_IMPROVEMENT_VS_MEAN   = +10.3% anidado   (umbral 15%)
GLOBAL_SIGN_ACCURACY               = 0.539
PERSONALIZED_SIGN_ACCURACY         = 0.565
SUBJECTS_IMPROVED                  = 7/10   (umbral 8/10)
MOTORS_IMPROVED                    = 4/4
SHUFFLED_TARGET_DEGRADATION        = +0.9%  (umbral 15%)
SHUFFLED_CONDITIONED_DEGRADATION   = +1.2%  (umbral 5%)
SELECTED_BUDGET                    = 5 episodios por gesto (modal), 10 episodios, 30.5 s
```

Gate: pasa 3 de 8 condiciones (3, 5 y 8).

**Correccion de metodo declarada:** la primera implementacion de CONTROL 1 daba +19.1 % y habria
pasado el umbral. Redimensionaba trayectorias de distinta longitud y con ello **desalineaba la
fase**, midiendo la destruccion de la fase y no la de la relacion EMG-target. La version corregida
asigna a cada episodio la trayectoria de otro episodio del mismo gesto remuestreada por fase, y da
+0.9 %.

## 16. Veredicto

```
E1D_RESULT          = E1D_FAIL
FINAL_TEST_EXECUTED = NO
```

No es `E1D_DATA_HUNGRY`: la curva de presupuesto esta saturada (50 veces mas datos compran un 8 %) y
los dos controles muestran que lo aprendido es la trayectoria media del gesto en funcion de la fase,
no una relacion EMG-movimiento. Mas calibracion daria mas trayectorias medias, no mas informacion.

Se cierra la linea de guante virtual con este dataset. MATEO y SANDRA siguen sellados.
