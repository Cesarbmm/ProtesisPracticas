# Resultados auditados E3B categorial

La corrida completo exactamente 1.000.000 de pasos: 69.959 episodios iniciados, 69.958 terminados por disponibilidad teacher y uno truncado por presupuesto, conservando bootstrap. BEST es 500k (episodio 34.969); LAST es 1M (episodio 69.959). La clasificacion preregistrada es CAT_LEARNING_SIGNAL: BEST reduce MSE VALIDATION 4.24% frente a TD3 BEST, pero es 11.32% peor que Agent7250. LAST empeora 7.03% frente a BEST. No se recomienda escalar a 5M ni entrenamiento masivo.

Auditoria nueva: 640 replays deterministas independientes (200 BEST, 200 LAST, 60 en cada uno de los otros cuatro checkpoints); 120 coincidencias adicionales entre evaluaciones intermedias y finales de VALIDATION. Diferencias maximas de estado, accion representativa, accion efectiva, PWM, q y reward: cero. Error maximo de CSV por redondeo: 3.64e-11. Verificados 980 rollouts sin huecos, 62.516 actualizaciones minibatch y las 2.624 transiciones conservadas en los seis checkpoints. Reward y previous effective action exactos; todas las heads tuvieron gradiente, logs finitos. No se conserva la trayectoria completa de entrenamiento: la auditoria de cada transicion interna solo cubre los rollouts guardados, no los 1M pasos. Se conservan agente/critic/Adam, pero FULL_TRAINING_RESUME_AVAILABLE=NO.

summary.json original contiene medias ALL=200, que mezclan 140 TRAIN y 60 VALIDATION. No se usan como evidencia de generalizacion. El criterio de seleccion y las tablas principales usan exclusivamente VALIDATION. Las metricas continuas son macro: media por episodio, grupo sujeto/direccion y luego grupos; conteos M3/ciclos son sumas. Entropia y distribuciones categoricas estan ponderadas por comandos, por eso no siempre coinciden con porcentajes macro.

## Comparacion VALIDATION (60 episodios)

| Politica | MSE VALIDATION | Reward | M3 | Flat response | Accion sin movimiento |
|---|---|---|---|---|---|
| ZERO | 0.104020 | -0.104020 | 0 | 100.00% | nan% |
| Agent7250 | 0.051598 | -0.064199 | 82 | 16.67% | 69.43% |
| P2 | 0.028083 | -0.034423 | 0 | 1.67% | 47.20% |
| Oracle_H5 | 0.019681 | -0.021512 | 0 | 3.33% | 31.78% |
| TD3_BEST | 0.059981 | -0.075616 | 134 | 15.00% | 68.44% |
| TD3_LAST | 0.065642 | -0.079472 | 81 | 21.67% | 68.12% |
| CATEGORICAL_BEST | 0.057439 | -0.062961 | 0 | 23.33% | 77.27% |
| CATEGORICAL_LAST | 0.061475 | -0.067177 | 0 | 20.42% | 68.41% |

## Evolucion de checkpoints

| Steps | Episodio | MSE VALIDATION | Reward | M3 | Ciclos | Categoria maxima |
|---|---|---|---|---|---|---|
| 50000 | 3527 | 0.091277 | -0.105113 | 12 | 1 | 98.96% |
| 100000 | 6992 | 0.073628 | -0.081388 | 10 | 0 | 81.32% |
| 250000 | 17498 | 0.058611 | -0.066624 | 2 | 0 | 48.26% |
| 500000 | 34969 | 0.057439 | -0.062961 | 0 | 0 | 48.72% |
| 750000 | 52463 | 0.058434 | -0.063656 | 0 | 0 | 47.91% |
| 1000000 | 69959 | 0.061475 | -0.067177 | 0 | 0 | 47.91% |

## TRAIN separado de VALIDATION

| Checkpoint | TRAIN MSE | VALIDATION MSE | TRAIN reward | VALIDATION reward |
|---|---|---|---|---|
| CATEGORICAL_BEST | 0.045887 | 0.057439 | -0.050092 | -0.062961 |
| CATEGORICAL_LAST | 0.040058 | 0.061475 | -0.044404 | -0.067177 |

## Direcciones VALIDATION

| Direccion | Politica | MSE | Reward | Flat response | Accion sin movimiento | Correlacion |
|---|---|---|---|---|---|---|
| Cierre | TD3_BEST | 0.069040 | -0.083057 | 3.33% | 61.64% | 0.536 |
| Apertura | TD3_BEST | 0.050921 | -0.068175 | 26.67% | 75.24% | 0.499 |
| Cierre | CATEGORICAL_BEST | 0.058324 | -0.063373 | 0.83% | 67.04% | 0.576 |
| Apertura | CATEGORICAL_BEST | 0.056553 | -0.062549 | 45.83% | 87.50% | -0.067 |
| Cierre | CATEGORICAL_LAST | 0.066377 | -0.071854 | 5.00% | 58.45% | 0.561 |
| Apertura | CATEGORICAL_LAST | 0.056572 | -0.062499 | 35.83% | 78.36% | 0.091 |

## Sujetos VALIDATION

| Sujeto VALIDATION | TD3 BEST MSE | Categorical BEST MSE | Cambio |
|---|---|---|---|
| JOE | 0.046879 | 0.050919 | +8.62% |
| JONATHAN | 0.074393 | 0.070456 | -5.29% |
| KHAROL | 0.058670 | 0.050942 | -13.17% |

## Distribuciones BEST VALIDATION

| Motor | Entropia media (nats) | Categoria mas frecuente | PWM255 (fraccion absoluta) |
|---|---|---|---|
| 1 | 1.5771 | 32.02% | 1.16% |
| 2 | 1.4740 | 48.72% | 0.93% |
| 3 | 1.3564 | 35.85% | 0.00% |
| 4 | 1.5189 | 47.68% | 0.00% |

BEST mejora el reward VALIDATION 16.74% frente a TD3 BEST y 1.93% frente a Agent7250. Este ultimo resultado convive con peor MSE: menores penalizaciones de accion y cambio de accion explican la diferencia. Se reportan por separado trackingTerm, actionPenalty y deltaActionPenalty en los CSV. P2 y Oracle son comparadores privilegiados.

La mejora no es uniforme. En apertura VALIDATION BEST tiene 45,83% de respuestas planas y 87,50% de acciones activas sin movimiento; su MSE empeora frente a TD3 BEST en esa direccion y la correlacion media es -0,067. Cierre mejora. Se reduce uso de extremos y no hay colapso global de una categoria por motor bajo el umbral 90%, pero eso no demuestra seguimiento adecuado. BEST y LAST tienen cero ciclos finales, ventanas alternantes y periodicidades detectadas en los 200 episodios; no implica estabilidad universal. BEST tiene cero retrocesos M3 en VALIDATION y uno en TRAIN: DENIS fila101 cierre, paso3, PWM+224, q=7523,6667 -> 7513,6667 (delta=-10). LAST tiene cero en ambos splits. Con una sola seed y seleccion en estos 60 episodios VALIDATION, no se ha establecido significacion estadistica ni generalizacion al test final. REFERENCE_CONTRACT_VALIDATED=NO. MATEO/SANDRA permanecen sellados.

Regresiones previas: 294/294 registradas en preparacion (258 historicas +36 E3B). No se reejecutaron en esta auditoria; se verificaron hashes de 1.070 archivos historicos y 25 fuentes de implementacion. Los 1.055 archivos originales de la corrida permanecen byte a byte intactos. La comprobacion nueva corresponde a replays, rollouts, agregacion y figuras; no se suma artificialmente a matlab.unittest.

Las 400 figuras PNG y 400 FIG corresponden exactamente a 200 episodios por checkpoint, cada uno con cuatro motores. Se contrastaron las 3.200 curvas de los FIG contra MAT con diferencia cero.

## Artefactos

- [Informe comportamental original con los 400 episodios](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/results/e3b_long/run_20260909_002700_470_a733a786/TEST_COMPORTAMENTAL.html)
- [BEST: figuras TRAIN y VALIDATION](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/results/e3b_long/run_20260909_002700_470_a733a786/evaluation/best_checkpoint/figures)
- [LAST: figuras TRAIN y VALIDATION](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/results/e3b_long/run_20260909_002700_470_a733a786/evaluation/last_checkpoint/figures)
- [Auditoria JSON](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3b_run_audit/audit_summary.json)
- [Replays verificados](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3b_run_audit/deterministic_replay.csv)
- [Datos de figuras verificados](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3b_run_audit/figure_data_audit.csv)
- [Metricas completas por split](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3b_run_audit/comparison_by_split.csv)
- [Resumen de checkpoints](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3b_run_audit/checkpoint_audit.png)
- [Ejemplo apertura JOE fila1 BEST](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/results/e3b_long/run_20260909_002700_470_a733a786/evaluation/best_checkpoint/figures/VALIDATION/JOE_row0001_opening.png)

## Reproducir auditoria sin entrenar

Desde matlab_code, con paths e3b y paired_reference, ejecutar `e3bAuditRun('results/e3b_long/run_20260909_002700_470_a733a786')` y `e3bAuditPresentation('results/e3b_long/run_20260909_002700_470_a733a786')`. Luego `python analysis/paired_reference/e3b/e3bAuditIntegrity.py after` y `python analysis/paired_reference/e3b/e3bSummarizeAudit.py`. No se invoca ningun runner de training.

AUDIT_RESULT = PASS

E3B_RESULT = CAT_LEARNING_SIGNAL

CONTINUE_TO_5M_STEPS = NO

MASSIVE_TRAINING_JUSTIFIED = NO

GIT_REPAIR_ATTEMPTED = NO

PUSH = NO
