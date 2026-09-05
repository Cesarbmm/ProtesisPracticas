# PREREGISTRO — ETAPA E1B (calibración EMG-only por usuario)

**Rama:** `experiment/no-glove-paired-reference-td3`
**Fecha de registro:** 2026-09-04 — **antes de ejecutar ningún ajuste**
**Antecedente:** `E1_GENERALIZATION = FAIL`, veredicto `E1_SUBJECT_SPECIFIC_ONLY`.

---

## 1. Pregunta

¿El fallo de transferencia entre sujetos proviene principalmente de un *domain shift* de las 40
features EMG, y puede corregirse con una calibración **EMG-only** del nuevo usuario?

## 2. Hipótesis

- **H1** — Normalizar `phi` con estadísticos del propio sujeto, estimados **sólo con su EMG**,
  recupera una parte material del desempeño perdido entre sujetos.
- **H0** — El fallo no es de escala/desplazamiento de features sino de la relación EMG→guante, y la
  normalización por sujeto no aporta mejora material.

## 3. Restricción dura de la calibración

La calibración del sujeto nuevo **no puede usar**: guante, target `y`, `flexConverted`, reward, ni
datos de evaluación. **Sólo sus features EMG.**

```
NEW_USER_GLOVE_REQUIRED_FOR_CALIBRATION = NO
```

## 4. Sujetos

```
DEVELOPMENT (10) : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN, KHAROL
FINAL TEST  (2)  : MATEO, SANDRA          <- SELLADOS, no se tocan en E1B
```

JONATHAN y KHAROL pasan a development porque ya fueron observados en E1. Toda selección
(`k`, `lambda`, presupuesto) se hace con LOSO sobre los 10 de development.

## 5. Protocolo por fold (leave-one-subject-out, 10 folds)

Para el sujeto dejado fuera `S`:

1. Sus episodios se parten **por episodio**, con semilla fija, en dos mitades: `POOL_CALIBRACION`
   (50 %) y `EVALUACION` (50 %). **`EVALUACION` es idéntico para todos los presupuestos y para
   todos los brazos**, para que los MSE sean comparables.
2. La calibración toma `N` episodios por gesto de `POOL_CALIBRACION`, nunca de `EVALUACION`.
3. Los 9 sujetos de entrenamiento siguen **el mismo contrato**: sus estadísticos de normalización
   se estiman con un subconjunto de calibración del mismo tamaño `N`, no con todos sus episodios.

## 6. Presupuestos de calibración

```
CALIBRATION_BUDGETS = 2, 5, 10, 20 episodios por gesto
```

Se reporta el tiempo real de EMG de cada uno. **El objetivo es el menor presupuesto útil, no el
mejor resultado:** entre los que pasen el gate se elige el más pequeño.

## 7. Normalización subject-specific, EMG-only

No se reemplazan los `C`/`S` históricos:

```
EMG cruda -> WMoos con C/S actuales -> phi in R40 -> z = (phi - mu_S)/(sigma_S + eps) -> ridge global
```

`mu_S` y `sigma_S` se estiman **únicamente** con la EMG de calibración del sujeto. `eps = 1e-8`.
Sin targets en ningún punto de la estimación.

## 8. Modelo

`RIDGE 40 -> 4`. Sin contexto 120, sin MLP, sin LSTM. Target `flexConverted` histórico en R⁴.
`k ∈ [-2,+2]`, `lambda` en malla logarítmica. El único factor nuevo es la normalización por sujeto.

## 9. Brazos comparados (mismo conjunto de evaluación)

| | |
|---|---|
| **A** | ridge40 de E1, sin normalización por sujeto |
| **B** | ridge40 + normalización subject-specific EMG-only |
| **C** | predictor media de train |
| **D** | baseline gesto+fase — `DIAGNOSTIC_ORACLE`, no competidor operacional |

El baseline A de E1 (hold) **no** entra: requiere guante previo.

## 10. Estimación honesta del desempeño

- **CV optimista:** mejor configuración por MSE medio sobre los 10 folds.
- **CV anidada (la que decide):** para cada fold, la configuración se elige minimizando el MSE medio
  sobre los otros 9, y se reporta en el fold excluido.

## 11. Métricas

MSE · MAE · sign accuracy de Δy · correlación · por motor · por gesto · por sujeto · dispersión
entre folds.

## 12. Controles de permutación

Aplicados **después** de la normalización del sujeto, sobre los datos de entrenamiento: shuffle
global, y shuffle condicionado por gesto y bin de fase.

## 13. GATE E1B — umbrales fijados AHORA

| # | condición | umbral |
|---|---|---|
| 1 | mejora material sobre el ridge de E1 (brazo A) | **MSE_B ≤ 0.85 · MSE_A** |
| 2 | mejora material sobre el predictor media (brazo C) | **MSE_B ≤ 0.80 · MSE_C** |
| 3 | no la genera un solo motor | **≥ 3 de 4 motores** mejoran frente a A |
| 4 | sign accuracy | calibrada **> genérica** y **> 0.55** |
| 5 | shuffle global degrada | **≥ +15 %** |
| 6 | shuffle condicionado degrada | **> +5 %** |
| 7 | no depende de 1–2 sujetos | **≥ 7 de 10** sujetos mejoran |
| 8 | presupuesto pequeño | **≤ 20** episodios por gesto, y se elige el menor que pase |

**La condición 2 la añado yo, y la justifico:** el brazo A apenas superaba a la media en E1 (6.2 %).
Un umbral definido sólo contra A permitiría declarar éxito con un modelo que sigue sin ser un
decoder. Anclarlo también contra la media impide ese resultado vacío. Los dos umbrales son
consistentes: si A ≈ 0.94·C, entonces 0.85·A ≈ 0.80·C.

### Resultados posibles

```
E1B_EMG_ONLY_CALIBRATION_PASS   -> se autoriza UNA ejecucion de MATEO/SANDRA, todo congelado
E1B_EMG_ONLY_CALIBRATION_FAIL   -> el test NO se toca
```

Si falla, la siguiente hipótesis posible sería `SUPERVISED_SUBJECT_CALIBRATION`. **No se implementa
todavía.**

## 14. Bloqueos que E1B no levanta

```
E2_PLANT_BLOCKED = YES
```

E1B es totalmente offline: no construye `Env`, `SimController`, `prosthesis_simulator` ni TD3. El
bloqueo de planta sigue vigente hasta que la línea fuerce una fuente determinista independiente de
Curve Fitting Toolbox, y **no se resuelve dentro de E1B** para no mezclar factores.

## 15. Se conserva de E0/E1

`PREPROCESSING_LEAKAGE_STATUS = POSSIBLE_LEAKAGE` · `WMoos_F2` sin corregir · `C`/`S` sin
recalcular · sin MLP · sin push · `e1_diag.py` marcado `DIAGNOSTIC_ONLY`.

## 16. Resultado

Ejecutado 2026-09-04. Detalle en `07_RESULTADOS_E1B.md`.

```
GENERIC_RIDGE_MSE_CV     = 0.040639  (optimista)  /  0.046120  (anidada)
CALIBRATED_RIDGE_MSE_CV  = 0.039702  (optimista)  /  0.042594  (anidada)
MSE_IMPROVEMENT          = +2.3%     (optimista)  /  +7.6%     (anidada)
MEDIA_DE_TRAIN (C)       = 0.041368
ORACULO gesto+fase (D)   = 0.018365
GENERIC_SIGN_ACCURACY    = 0.539
CALIBRATED_SIGN_ACCURACY = 0.531     (empeora)
SHUFFLE_GLOBAL_DEGRADATION      = +4.3%
SHUFFLE_CONDITIONED_DEGRADATION = +0.6%
SUBJECTS_IMPROVED        = 6/10
MOTORS_IMPROVED          = 1/4
```

## 17. Veredicto

**`E1B_EMG_ONLY_CALIBRATION_FAIL`. Falla las 8 condiciones del gate.**

El test NO se toca. `TEST_FINAL_EXECUTED = NO`.
