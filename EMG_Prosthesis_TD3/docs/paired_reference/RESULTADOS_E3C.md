# Resultados E3C — auditoria temporal

E3C_RESULT = TEMPORAL_INFORMATION_NOT_DEMONSTRATED. No se prepara E3D. Se conservaron la receta y los gates antes de medir: tres seeds supervisadas (20260912/13/14), 40 epocas, Adam LR0.001, batch64, L8 real. No hubo entrenamiento RL. Los 2.076 estados TRAIN y 862 VALIDATION proceden de las200 demostraciones Oracle H5, reconstruidas con igualdad exacta de planta y estado previo causal. Cada una de las seis politicas congeladas se evaluo en140TRAIN+60VALIDATION con sus propias acciones y runtime EMG-only.

GRU mejora apertura frente a FF: MSE 0.048368 vs 0.070800 (-31.68%), flat_response 27.78% vs 82.50%. Sin embargo, Oracle-action macro-F1 gana solo 0.232 pp (se exigian3), y NLL empeora 1.87% en lugar de mejorar5%. NLL empeora en las tres seeds. Los gatesA/B, orden y consistencia entre seeds fallan. No ajustar umbrales ni receta.

Desordenar el pasado conservando el estado actual reduce F1 0.631pp y aumenta NLL 4.77% frente a GRU ordenado. Se altera el orden en 86.08% de ventanas VALIDATION; prefijos1/2 no tienen pasado permutable. Existe sensibilidad al orden, pero la perdida F1 no alcanza1pp preregistrado. La perturbacion es fuera de distribucion y las arquitecturas no tienen igual numero de parametros; por tanto la diferencia GRU/FF no aisla exclusivamente memoria.

Frente a E3B BEST, GRU mejora apertura (MSE0.048368 vs0.056553; flat27.78% vs45.83%; accion activa sin movimiento42.95% vs87.50%), pero empeora cierre (0.091429 vs0.058324) y MSE global VALIDATION (0.069898 vs0.057439). Cero retrocesosM3, ciclos finales y periodicidades finales en cada seed GRU VALIDATION. La categoria mas frecuente por motor llega como maximo a72.39%, inferior al gate90%; no equivale a control suficiente. La comparacion favorable frente al FF debil no prueba superioridad global frente a la politica RL anterior.

Entrada al modelo: exclusivamente markov52 ANTES de la accion. Teacher/Oracle/reward/fase/indice de episodio no entran a la red. La ventana nunca cruza episodios y no incluye futuro. GRU se evalua desde hidden0 sobre la ultima ventana real de hasta8estados; no persiste memoria anterior a L8. El readout lineal secundario de fase/direccion se ajusto sobre latentes congelados, soloTRAIN, sin gradiente hacia la politica. No es decoder ni controlador nuevo. Teacher original solo sirve para etiquetas y metricas posteriores; reward, planta, Ts, PWM, WMoos y markov52 historicos no se modificaron.

## Imitacion Oracle: media de tres seeds

| Split | Modelo | Macro-F1 | NLL/head | Accuracy/head | Top2/head | Exact4 | NLL conjunta |
|---|---|---|---|---|---|---|---|
| TRAIN | FF | 0.198791 | 0.633548 | 0.761039 | 0.925177 | 0.367694 | 2.534190 |
| TRAIN | GRU | 0.248645 | 0.467763 | 0.818200 | 0.958293 | 0.477521 | 1.871050 |
| TRAIN | GRU shuffled | 0.225249 | 0.560319 | 0.778300 | 0.941073 | 0.402537 | 2.241275 |
| VALIDATION | FF | 0.160006 | 0.965688 | 0.652939 | 0.859725 | 0.221964 | 3.862753 |
| VALIDATION | GRU | 0.162325 | 0.983758 | 0.625290 | 0.872003 | 0.196442 | 3.935033 |
| VALIDATION | GRU shuffled | 0.156016 | 1.030676 | 0.609822 | 0.859822 | 0.174401 | 4.122706 |

## Lazo cerrado: media de tres seeds

| Split | Direccion | Modelo | MSE | Reward | MAE | Correlacion | Flat | Accion sin movimiento |
|---|---|---|---|---|---|---|---|---|
| TRAIN | Global | FF | 0.075954 | -0.076224 | 0.215834 | 0.340399 | 0.805952 | 0.296642 |
| TRAIN | Global | GRU | 0.046614 | -0.047560 | 0.165656 | 0.438345 | 0.369643 | 0.389337 |
| TRAIN | Cierre | FF | 0.094456 | -0.094887 | 0.240184 | 0.662937 | 0.695238 | 0.409059 |
| TRAIN | Cierre | GRU | 0.047850 | -0.049081 | 0.163860 | 0.843458 | 0.215476 | 0.439736 |
| TRAIN | Apertura | FF | 0.057452 | -0.057560 | 0.191485 | 0.073157 | 0.916667 | 0.205505 |
| TRAIN | Apertura | GRU | 0.045379 | -0.046038 | 0.167452 | 0.033231 | 0.523810 | 0.338938 |
| VALIDATION | Global | FF | 0.090174 | -0.090575 | 0.238411 | 0.361771 | 0.725000 | 0.354725 |
| VALIDATION | Global | GRU | 0.069898 | -0.070903 | 0.204160 | 0.521686 | 0.297222 | 0.428445 |
| VALIDATION | Cierre | FF | 0.109547 | -0.110082 | 0.262887 | 0.653582 | 0.625000 | 0.378477 |
| VALIDATION | Cierre | GRU | 0.091429 | -0.092475 | 0.236891 | 0.716539 | 0.316667 | 0.427436 |
| VALIDATION | Apertura | FF | 0.070800 | -0.071068 | 0.213935 | 0.031200 | 0.825000 | 0.323935 |
| VALIDATION | Apertura | GRU | 0.048368 | -0.049331 | 0.171428 | 0.326834 | 0.277778 | 0.429453 |

## Gate congelado

| Criterio | Resultado |
|---|---|
| A_macroF1_gain_3pp | FAIL |
| B_NLL_reduction_5pct | FAIL |
| C_opening_MSE_reduction_5pct | PASS |
| D_opening_flat_reduction_5pp | PASS |
| E_closing_MSE_no_worse_5pct | PASS |
| F_cycles_and_periodicity | PASS |
| F_M3_no_material_increase | PASS |
| F_no_global_category_collapse | PASS |
| G_order_shuffle_loses_gain | FAIL |
| paired_seed_consistency | FAIL |

## Bootstrap pareado GRU menos FF

| Grupo | Metrica | Diferencia | IC95% | Episodios |
|---|---|---|---|---|
| VALIDATION | trackingMSE | -0.020275 | [-0.026211, -0.014428] | 60 |
| VALIDATION | flat_response | -0.427778 | [-0.502778, -0.352778] | 60 |
| OPENING | trackingMSE | -0.022433 | [-0.031627, -0.012811] | 30 |
| OPENING | flat_response | -0.547222 | [-0.641667, -0.450000] | 30 |

## Diagnostico secundario de fase

| Target | Modelo | Accuracy | Macro-F1 | NLL |
|---|---|---|---|---|
| direction | FF | 0.889018 | 0.888811 | 0.277273 |
| direction | GRU | 0.959783 | 0.959769 | 0.136278 |
| phase | FF | 0.583527 | 0.568389 | 0.921505 |
| phase | GRU | 0.642305 | 0.639030 | 0.791140 |
| phase_direction | FF | 0.578500 | 0.566215 | 1.037209 |
| phase_direction | GRU | 0.636118 | 0.628101 | 0.880239 |

La politica FF emite PWM0 en 93.25% de comandos de apertura VALIDATION, frente a 64.31% GRU (media de motor y seed, ponderada por comandos dentro de motor). action_no_motion excluye acciones cero; su valor menor en FF no demuestra mas movimiento util. FF presenta colapso global de alguna cabeza en2/3seeds (maximos96.52%,90.26%,77.15%); GRU no lo presenta bajo el umbral90%. Esa debilidad del FF limita la interpretacion de la ventaja en lazo cerrado. El bootstrap es pareado por episodio, con semillas promediadas primero; no usa pasos como replicas independientes ni cambia gates. Episodios de un mismo sujeto pueden correlacionarse; no es un test final. La distribucion de entrada supervisada usa acciones previas del experto; la propia politica puede visitar otros estados. Oracle H5 conoce teacher futuro, por lo que parte de su accion puede no ser inferible causalmente. Las categorias poco frecuentes cuentan en macro-F1 de15clases (F1=0 con denominador0). Este resultado no demuestra ausencia universal de informacion temporal: se limita a L8, GRU64, esta receta/dataset y estas etiquetas.

Pruebas:294/294 regresiones historicas reejecutadas y32/32 E3C:326/326. Se verificaron2179 entradas historicas; unica excepcion autorizada: exportE3AXViewerTrace reconoce/reset E3CProbeActor y etiqueta su procedencia, manteniendo formato/rutas previas. El diff esta guardado. No se reparo Git, no push ni cambio de rama. MATEO/SANDRA sellados; referencia fisica no validada, hardware no autorizado. Se comprobaron determinismo de los seis modelos, teacher contrafactual sin cambios de accion, ventanas causales, CSV/MAT anotados y viewer contra trazas.

## Figuras y trazas

1200 figuras compactas PNG+FIG (200por probe/seed),12comparaciones anotadas PNG+FIG+CSV+MAT y18viewer_trace.mat. Se conservan las400figuras BEST/LAST E3B originales. Primera seed para diagnosticos elegida antes de medir; ninguna seleccion por resultados E3C.

[Informe navegable](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3c_results/RESULTADOS_E3C.html)

[Resumen JSON](C:/Users/Cesarbmm/ProtesisPracticas_e2b_audit/EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/e3c_results/summary.json)

Comandos desde matlab_code: addpath('analysis/paired_reference/e3c'); runE3CTemporalAudit('testsCore'); runE3CTemporalAudit('testsArtifacts'); Los modelos existentes no se sobrescriben ni reentrenan; stages evaluate/figures permiten completar postprocesado. python analysis/paired_reference/e3c/e3cAnalyze.py reproduce estadisticas; e3cHistory.py after verifica integridad; e3cFinalize.py reconstruye este cierre.

E3C_RESULT = TEMPORAL_INFORMATION_NOT_DEMONSTRATED

E3D_PREPARATION = NO

E3D_LONG_TRAINING_STARTED = NO

PUSH = NO
