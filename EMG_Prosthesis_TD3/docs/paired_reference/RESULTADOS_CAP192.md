# Resultados del diagnóstico CAP192

CAP192_SUPPORTED = NO. El recorte conserva casi el mismo tracking y elimina los retrocesos M3 observados, pero concentra el **70.678654 %** de los comandos de BEST VALIDATION en el nuevo límite. El gate fijado antes de medir era <=50 %. No se prepara E3B ni se entrena.

## Diseño e integridad

Se aplicó solamente clip(raw,±192/255), sin multiplicar las acciones interiores ni cambiar el cuantizador. BEST Episode10000 y LAST Episode20000, 200 episodios cada uno, OFF y CAP: **800 ejecuciones completas EMG-only**, 400 reproducciones OFF exactas frente a la corrida guardada. Todos los estados, raw, effective, PWM y q OFF coinciden exactamente; reward tiene diferencia cero. Mismos 140 TRAIN /60 VALIDATION; teacher y horizonte común originales. Ningún peso se actualizó.

El actor recibe el estado realmente alcanzado. Cada estado siguiente contiene PWM_aplicado/255 en previousAction; por ello el contrafactual no es un recorte cosmético de las trazas antiguas. Se guardaron desiredRaw y commandRaw por separado, además de runtime completo y métricas teacher posteriores.

El preregistro y 977 archivos quedaron protegidos antes de las comparaciones; todos conservaron sus hashes, incluidos runtime, planta, remapeo, reward, pruebas y checkpoints históricos. HEAD: 165be049eb41fc41254435181c9857fe0f22ed1c. Sin reparación Git ni publicación.

## Resultado por split

MSE y reward mantienen la agregación macro sujeto/dirección histórica. Las fracciones en el límite se ponderan por número de comandos e incluyen PWM0.

| Split | Política | MSE | Reward | Retrocesos M3 | Fracción en 192 |
|---|---|---|---|---|---|
| TRAIN | BEST_OFF | 0.04778143 | -0.06151601 | 392.00000000 | 0.05033719 |
| TRAIN | BEST_CAP192 | 0.04827531 | -0.05717755 | 0.00000000 | 0.83080443 |
| TRAIN | LAST_OFF | 0.04774581 | -0.05817802 | 331.00000000 | 0.09995183 |
| TRAIN | LAST_CAP192 | 0.04791487 | -0.05574090 | 0.00000000 | 0.56539017 |
| VALIDATION | BEST_OFF | 0.05998085 | -0.07561621 | 134.00000000 | 0.05394432 |
| VALIDATION | BEST_CAP192 | 0.06034757 | -0.07089614 | 0.00000000 | 0.70678654 |
| VALIDATION | LAST_OFF | 0.06564222 | -0.07947240 | 81.00000000 | 0.09541763 |
| VALIDATION | LAST_CAP192 | 0.06714693 | -0.07747510 | 0.00000000 | 0.58323666 |

BEST VALIDATION: MSE empeora **0.611404 %**, reward mejora **6.242145 %**, retrocesos M3 **134→0**. LAST VALIDATION: MSE 0.0671469254201835 y retrocesos **81→0**. No hay ciclos finales, ventanas alternantes detectadas ni periodicidad final en ninguno de los cuatro grupos, tanto en el horizonte teacher común como en el runtime EMG-only completo. Esto no demuestra estabilidad universal.

| Política | MAE | actionL2 | deltaActionL2 | flat_response | action_no_motion |
|---|---|---|---|---|---|
| BEST_OFF | 0.19365023 | 0.72228235 | 0.16825082 | 0.15000000 | 0.68441544 |
| BEST_CAP192 | 0.19408626 | 0.46500665 | 0.11796999 | 0.15416667 | 0.78199951 |
| LAST_OFF | 0.19830191 | 0.59716640 | 0.15717030 | 0.21666667 | 0.68121494 |
| LAST_CAP192 | 0.20033780 | 0.40804183 | 0.12495519 | 0.20833333 | 0.75158439 |

El reward mejora por reducción de penalizaciones, no por mejor tracking: en BEST VALIDATION el término tracking pasa de -0.059980845187 a -0.060347570209; action penalty de 0.007222823518 a 0.004650066489; delta-action penalty de 0.008412540958 a 0.005898499314. Los pesos siguen siendo .01 y .05.

La fracción macro action_no_motion aumenta **9.758407 puntos porcentuales**. No se usa esta subida como un gate añadido retrospectivamente, pero refuerza la limitación operacional medida. flat_response aumenta de 15.0000 % a15.4167 % en BEST VALIDATION. La saturationFraction histórica >=.95 es cero por construcción al recortar; no constituye evidencia de estabilidad ni de eliminación de saturación.

## Concentración en el límite

BEST VALIDATION: **2437/3448 comandos** en abs(PWM)=192; **68.039443 %** de desiredRaw fueron recortados. Son cantidades distintas porque el remapeo histórico puede enviar PWM192 sin que el raw supere192/255.

| Agrupación | Valor | Comandos | En 192 | Fracción |
|---|---|---|---|---|
| global | ALL | 3448 | 2437 | 0.706786542923434 |
| motor | 1 | 862 | 549 | 0.636890951276102 |
| motor | 2 | 862 | 504 | 0.584686774941995 |
| motor | 3 | 862 | 757 | 0.878190255220418 |
| motor | 4 | 862 | 627 | 0.72737819025522 |
| direction | 1 | 1724 | 1278 | 0.741299303944316 |
| direction | 2 | 1724 | 1159 | 0.672273781902552 |
| subject | JOE | 1116 | 684 | 0.612903225806452 |
| subject | JONATHAN | 1204 | 896 | 0.744186046511628 |
| subject | KHAROL | 1128 | 857 | 0.759751773049645 |

M3 alcanza el límite en **87.819026 %** de sus comandos. El efecto no se limita a un único sujeto ni dirección. BEST TRAIN tiene83.080443 % en192; LAST VALIDATION58.323666 %. El cap evita las inversiones observadas en estas trazas, pero sigue concentrando la salida del actor en el mayor comando permitido. PWM192 conserva su pequeña región histórica de inversión M3: cero eventos aquí no equivale a seguridad universal de ese PWM.

## Gate congelado

| Criterio | Resultado |
|---|---|
| msePass | PASS |
| rewardPass | PASS |
| m3Pass | PASS |
| orbitPass | PASS |
| boundPass | FAIL |
| zeroMotionPass | PASS |
| offReproduced | PASS |
| testsPass | PASS |
| hashesIntact | PASS |

El único gate científico que falla es boundPass (70.678654 % frente a50 %); los demás criterios y controles de integridad pasan. No se cambió el umbral después de observar datos. No se ensayaron otros caps ni heurísticas.

TD3_CONTINUOUS_SCALING_NOT_JUSTIFIED = YES para el siguiente escalado propuesto. No es una refutación universal de TD3 ni una demostración de que un actor nuevo entrenado con cap deba fallar. Este contrafactual usa actores existentes; según el gate solicitado, no justifica abrir ese entrenamiento.

La siguiente familia recomendada es **FACTORIZED_CATEGORICAL**, cuatro cabezas, cada una sobre15acciones históricas. La recomendación responde al conjunto discreto que recibe esta planta y a la concentración observada; no se implementa ni se entrena.

## Artefactos y figuras

- [Comparación completa](../../matlab_code/analysis/paired_reference/cap192_results/comparison.csv).
- [Figura resumen](../../matlab_code/analysis/paired_reference/cap192_results/comparison.png), también FIG/PDF.
- Métricas por episodio/motor y resúmenes por sujeto/motor/dirección, para ALL/TRAIN/VALIDATION.
- Distribución PWM firmada por episodio/motor, conteos agrupados, ventanas de ciclos, reproducción OFF y cuatro conjuntos de trazas MAT/CSV.
- Ocho figuras PNG+FIG, una con cuatro motores por cada caso BLANCAfila1cierre /IVANNAfila104apertura y cada checkpoint/modo. Se reutiliza e3axPlotEpisode; no se anotan números sobre las muestras. Estas ilustraciones no sustituyen las métricas de los200episodios.
- [Informe navegable local](../../matlab_code/analysis/paired_reference/cap192_results/RESULTADOS.html).

## Viewer pasivo

exportE3AXViewerTrace está probado: cuatro exportaciones BLANCAfila1cierre (BEST/LAST, OFF/CAP) reproducen exactamente las trazas guardadas. Cada viewer_trace.mat contiene q en encoder counts (N+1×4), PWM firmado (N×4), step0..N, commandStep1..N, Ts=.2, tiempo, subject,row,direction,policy,checkpoint/hash y manifiesto de planta. PWM(k) actúa sobre q(k) y produceq(k+1), con índices MATLAB.

La exportación carga saved_actor y únicamente EMG del sujeto autorizado; no carga guante. Procedencia: saved_actor→GloveFreePolicyRuntime→patternCurveCanonical. No se importa ni se abre sandbox.

Futura integración, sólo si se autoriza reabrirla: HandKinematicViewer debe leer q(t) directamente como visualización pasiva. No llamar DynamicPlantAdapter/S4 ni volver a simular dinámica. P2/Oracle requerirán conservar la procedencia privilegiada de sus trazas existentes; no atribuirles procedencia saved_actor. Integración diferida.

## Reproducción y pruebas

Comando del diagnóstico (en MATLAB, desde matlab_code): addpath('analysis/paired_reference/cap192'); runCAP192Diagnostic(). Se niega a sobrescribir measurements.mat si ya existe. Para repetir en otra copia científica, conservar el manifiesto y preregistro originales; no recapturar hashes para ocultar cambios.

Para verificar sin repetir inferencia: cap192RunTests(). El exportador público y su ejemplo están en README_VIEWER.md junto a los resultados. No hay ningún comando nuevo de training.

**Tests históricos: 233/233; nuevos: 25/25; total: 258/258.** Las pruebas unitarias no son episodios de evaluación y no generan una figura por test.

REFERENCE_CONTRACT_VALIDATED = NO. HARDWARE_AUTHORIZED = NO. MATEO/SANDRA sellados. E3B_PREPARED = NO; E3B_STARTED = NO. CONTINUE_TO_500K_RECOMMENDED = NOT_YET. TWO_MILLION_EPISODES_JUSTIFIED = NO_POR_AHORA. GIT_REPAIR_ATTEMPTED = NO. PUSH = NO.
