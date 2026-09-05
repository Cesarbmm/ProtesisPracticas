# ETAPA E1B — Calibración EMG-only por usuario · Resultados

**Fecha:** 2026-09-04 · **Rama:** `experiment/no-glove-paired-reference-td3`

> **Veredicto: `E1B_EMG_ONLY_CALIBRATION_FAIL`. Falla las 8 condiciones del gate.**
> `TEST_FINAL_EXECUTED = NO`. MATEO y SANDRA siguen sellados.

---

## 1. Qué se probó

La hipótesis era que el fallo de transferencia de E1 fuese un *domain shift* de las 40 features
EMG, corregible con una renormalización afín por sujeto estimada **sólo con su EMG**:

```
phi -> z = (phi - mu_S) / (sigma_S + eps)
```

LOSO sobre los 10 sujetos de development. Evaluación fija por sujeto (50 % de sus episodios),
idéntica para todos los presupuestos y brazos. Calibración tomada del otro 50 %, nunca de
evaluación. Los 9 sujetos de entrenamiento bajo el mismo contrato: sus estadísticos salen de un
subconjunto de calibración del mismo tamaño, no de todos sus episodios.

**Nota de comparabilidad:** el MSE de E1B no es directamente comparable con el 0.052142 de E1. El
protocolo cambió (LOSO sobre 10, mitad de episodios como evaluación). La comparación válida es
interna: brazo A frente a brazo B sobre el mismo conjunto.

## 2. Resultado principal

| brazo | CV optimista | CV anidada |
|---|---|---|
| **A** ridge40 sin calibrar | 0.040639 | 0.046120 |
| **B** ridge40 + calibración EMG-only | **0.039702** | **0.042594** |
| **C** predictor media de train | 0.041368 | — |
| **D** gesto+fase (`DIAGNOSTIC_ORACLE`) | 0.018365 | — |

- Mejora de B sobre A: **+2.3 %** optimista, **+7.6 %** anidada. Umbral preregistrado: **15 %**.
- B frente a la media: **+4.0 %**. Umbral preregistrado: **20 %**.
- El oráculo gesto+fase sigue siendo **2.2 veces mejor** que el mejor ridge calibrado.

En las dos configuraciones seleccionadas `lambda` queda pegada al extremo de la malla (1e6) y `k`
al extremo del rango (+2). Los dos brazos siguen operando casi en el régimen de "predecir la
media": la correlación media es **r = +0.079** sin calibrar y **+0.095** calibrado.

## 3. Curva de presupuesto

| N por gesto | episodios | EMG de calibración | MSE B | vs A | vs media |
|---|---|---|---|---|---|
| 2 | 4 | 12.2 s | 0.040413 | +0.6 % | +2.3 % |
| 5 | 10 | 30.5 s | 0.040658 | −0.0 % | +1.7 % |
| 10 | 20 | 61.0 s | 0.039947 | +1.7 % | +3.4 % |
| 20 | 40 | 122.0 s | 0.039702 | +2.3 % | +4.0 % |

La curva es monótona pero plana: **decuplicar la calibración de 12 s a 122 s compra 1.7 puntos
porcentuales.** No existe un presupuesto pequeño útil, y tampoco uno grande: la extrapolación no
se acerca al umbral.

## 4. Por sujeto

| sujeto | A sin calibrar | B calibrado | C media | D oráculo | B vs A |
|---|---|---|---|---|---|
| BLANCA | 0.034378 | 0.036464 | 0.036228 | 0.013991 | −6.1 % |
| CECILIA | 0.042895 | 0.043889 | 0.044966 | 0.019748 | −2.3 % |
| DENIS | 0.024375 | 0.023517 | 0.023062 | 0.009969 | +3.5 % |
| EMILIA | 0.023379 | 0.023545 | 0.023852 | 0.007047 | −0.7 % |
| GABI | 0.045165 | 0.043542 | 0.045000 | 0.013163 | +3.6 % |
| GABRIEL | 0.049768 | 0.047134 | 0.051305 | 0.028721 | +5.3 % |
| IVANNA | 0.047203 | 0.044168 | 0.045296 | 0.021736 | +6.4 % |
| JOE | 0.037816 | 0.036655 | 0.040076 | 0.015246 | +3.1 % |
| JONATHAN | 0.058754 | 0.054741 | 0.059356 | 0.040031 | +6.8 % |
| KHAROL | 0.042656 | 0.043366 | 0.044544 | 0.013994 | −1.7 % |
| **media** | 0.040639 | 0.039702 | 0.041368 | 0.018365 | **+2.3 %** |

**6 de 10 mejoran**, y en 4 empeora. La mejor mejora individual (+6.8 %) sigue por debajo del
umbral. Dispersión entre folds: sd 0.0140 (A) y 0.0121 (B) — del mismo orden que la media, así que
ni siquiera el signo del efecto es estable.

## 5. Métricas agregadas

| | MSE | MAE | r | sign acc |
|---|---|---|---|---|
| A sin calibrar | 0.040560 | 0.1690 | +0.079 | 0.539 |
| B calibrado | 0.039631 | 0.1673 | +0.095 | **0.531** |
| D oráculo | 0.018197 | 0.1021 | +0.751 | 0.582 |

La sign accuracy **empeora** al calibrar (0.539 → 0.531) y queda por debajo de 0.55.

**Por motor (MSE):**

| | M1 | M2 | M3 | M4 |
|---|---|---|---|---|
| A | 0.028033 | 0.033066 | 0.069087 | 0.032056 |
| B | 0.028799 | 0.033484 | 0.063396 | 0.032845 |

**1 de 4 motores mejora** (sólo M3). La calibración empeora M1, M2 y M4.

**Por gesto:** closing A 0.047896 · B 0.046904 · D 0.022594. Opening A 0.033242 · B 0.032375 ·
D 0.013810.

## 6. Controles de permutación sobre el brazo calibrado

| | MSE | degradación | umbral |
|---|---|---|---|
| shuffle global | 0.041391 | **+4.3 %** | ≥ 15 % |
| shuffle condicionado | 0.039921 | **+0.6 %** | > 5 % |

Romper la asociación EMG–target por completo cuesta un 4.3 %. Es la medida más directa de cuánto
usa el modelo la EMG entre sujetos: **casi nada**. Con la fase conocida, romperla cuesta 0.6 %,
que es ruido.

## 7. Evaluación del gate

| # | condición | umbral | medido | |
|---|---|---|---|---|
| 1 | MSE_B ≤ 0.85·MSE_A | 0.034543 | 0.039702 | **NO** |
| 2 | MSE_B ≤ 0.80·MSE_C | 0.033094 | 0.039702 | **NO** |
| 3 | ≥ 3 de 4 motores mejoran | 3 | 1 | **NO** |
| 4 | sign acc calibrada > genérica y > 0.55 | — | 0.531 < 0.539 | **NO** |
| 5 | shuffle global ≥ +15 % | 15 % | +4.3 % | **NO** |
| 6 | shuffle condicionado > +5 % | 5 % | +0.6 % | **NO** |
| 7 | ≥ 7 de 10 sujetos mejoran | 7 | 6 | **NO** |
| 8 | presupuesto pequeño que pase | — | ninguno pasa | **NO** |

**0 de 8.**

## 8. Conclusión

```
E1B_RESULT = E1B_EMG_ONLY_CALIBRATION_FAIL
```

**La hipótesis del *domain shift* de features queda refutada en su forma afín EMG-only.** Alinear
media y varianza de las 40 features por sujeto, con hasta dos minutos de EMG de calibración, no
recupera la transferencia. El fallo de E1 no era principalmente de primer y segundo momento de las
features.

Esto es informativo, no sólo negativo: descarta la explicación más barata y más probable a priori.
Lo que queda como candidato es que **la relación EMG→guante en sí misma difiere entre sujetos** —
colocación del Myo, rotación del brazalete, orden de canales, anatomía— y eso no lo arregla una
renormalización marginal.

**El test no se toca.** La siguiente hipótesis posible, `SUPERVISED_SUBJECT_CALIBRATION` (unas
pocas repeticiones **con guante** durante la calibración inicial), queda registrada y **sin
implementar**. Nótese que rompe la restricción `NEW_USER_GLOVE_REQUIRED_FOR_CALIBRATION = NO` y
por tanto cambia la promesa de la línea: el usuario necesitaría el guante una vez, aunque no en
operación.

## 9. Lo que E1B no levanta

```
E2_PLANT_BLOCKED = YES
```

E1B es completamente offline. El bloqueo de planta por la dependencia de Curve Fitting Toolbox
sigue vigente y no se resolvió aquí, deliberadamente, para no mezclar factores.

## 10. Figura

`figuras/E1B_resumen.png` — MSE por sujeto dejado fuera para los brazos A, B y D; curva de
presupuesto contra el umbral del 15 %; y las dos degradaciones de permutación contra sus umbrales.
