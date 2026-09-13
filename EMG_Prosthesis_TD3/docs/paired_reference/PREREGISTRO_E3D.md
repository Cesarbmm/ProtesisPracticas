# E3D — Ablación del contexto temporal de intención EMG

Preregistro 2026-09-09, anterior a entrenamiento o medición E3D. HEAD 165be049eb41fc41254435181c9857fe0f22ed1c, rama experiment/no-glove-paired-reference-td3, worktree real ProtesisPracticas_e2b_audit. Git pospuesto. E3C permanece TEMPORAL_INFORMATION_NOT_DEMONSTRATED; ésta es una hipótesis nueva.

## Datos y contrato

Auditoría supervisada, sin RL. Reutilizar exactamente supervised_data.mat de E3C: 200 episodios, 140 TRAIN y 60 VALIDATION. TRAIN: BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA. VALIDATION: JOE, JONATHAN, KHAROL. MATEO/SANDRA sellados. No modificar teacher original, reward, Ts=.2, PWM, patternCurveCanonical, WMoos, markov52 ni runtime E2A.

Usar estados anteriores a cada acción Oracle H5 ya reconstruidos en E3C. Labels Oracle sólo offline; la mecánica previa de esas demostraciones procede del experto. Evaluación closed-loop con acciones propias sobre los mismos 200 episodios es obligatoria. No inferir que las etiquetas privilegiadas sean completamente predecibles.

## Arquitecturas y objetivos

BASELINE: WMoos40 actual -> FC64/ReLU. TEMPORAL_EMG: WMoos40 causal max(1,t-7):t -> GRU64, salida final. Ambas concatenan únicamente las 12 variables mecánicas ACTUALES (q normalizado, delta q, previousEffectiveAction) -> FC64/ReLU. Cuatro heads FC15 producen acciones auxiliares. Dos heads adicionales, FC2 dirección y FC6 fase-dirección, reciben el mismo latent y son exclusivamente salidas diagnósticas. Ninguna predicción de dirección/fase se reintroduce en las heads de acción.

Pérdida multitarea fija: CE(direction) + CE(phase_direction) + mean_m CE(action_m). Los dos objetivos primarios tienen peso unitario cada uno; la imitación auxiliar tiene peso unitario conjunto, evitando que cuatro motores la multipliquen por cuatro. Los seis objetivos propagan gradiente al encoder. Misma pérdida y arquitectura posterior al encoder en A/B; no ajustar pesos. La comparación evalúa historia EMG bajo supervisión conjunta de intención y acción, no la capacidad de PPO recurrente entrenado sólo con reward.

Fase exactamente E3C: phase=min(3,1+floor(3*(t-1)/N)), N=horizonte teacher común. side=1 cierre, side=2 apertura. phase_direction=phase+3*(side-1): cierre early/middle/late, apertura early/middle/late. La duración final y direction son labels privilegiados, nunca inputs. Direction head predice side directamente. Etiquetas se pasan únicamente a la pérdida y métricas.

Ventanas reales de longitud 1..8, sin padding ni concatenar episodios. GRU hidden=0 al inicio de cada ventana; el wrapper conserva sólo ocho vectores EMG y se reinicia al comenzar episodio. No recurrencia indefinida ni historia mecánica. No futuro, teacher, reward, sujeto, dirección, índice/longitud de episodio ni acción actual en inputs. La mecánica actual entra por un input separado de 12 valores, no por la GRU.

## Receta congelada

Seeds pareadas 20260923, 20260924, 20260925. 40 épocas completas, Adam LR=.001, beta1=.9, beta2=.999, epsilon=1e-8, minibatch64, clipping norma global gradiente=1. Sin normalización adicional, class weighting, dropout, early stopping ni selección de checkpoint. Inicialización MATLAB estándar CPU single. Agrupar minibatches por longitud real del prefijo, barajar sólo ejemplos TRAIN. Mismos planes de batches por seed A/B. Único checkpoint final época40. No tuning en VALIDATION.

Shuffle en evaluación: permutar únicamente EMG pasado, conservar EMG actual al final y mecánica actual idéntica. Orden determinista E3C, seed 20260921+100*episodio+t; forzar permutación no identidad cuando hay al menos dos pasos pasados. Longitudes1/2 no admiten cambio de orden. No entrenar con shuffle. Evaluar clasificación ordered/shuffled, no cambiar acción del ensayo closed-loop principal.

## Medición y gates congelados

Dirección macro-F1 sobre las dos clases, fase-dirección macro-F1 sobre las seis clases, NLL y accuracy por TRAIN/VALIDATION/sujeto. Oracle-action macro-F1 sobre las 15 categorías por head y promedio, NLL por head: secundarios, sin gate. Reportar los tres seeds y su media sin elegir el mejor.

Closed-loop argmax por motor; PWM/255 representativo por baselineQuantized idéntico; previousEffectiveAction siempre realmente aplicada. GloveFreePolicyRuntime termina por EMG; teacher sólo se adjunta posteriormente para métricas en horizonte común. Métricas macro históricas (sujeto/dirección con igual peso): MSE, MAE, reward, acción, cambio de acción, flat_response, action_no_motion, correlación. PWM0, distribución/categoría, ciclos finales, ventanas, periodicidad y M3 según detectores históricos. MAX_CATEGORY_FRACTION: mayor fracción de una categoría entre las cuatro heads sobre todas las transiciones VALIDATION de cada seed; reportar media y máximo de seeds.

PASS sólo si TODOS los siguientes gates sobre medias de tres seeds VALIDATION:

A. Direction F1 temporal >= baseline +.03.
B. Phase-direction F1 temporal >= baseline +.05.
C. Ordered phase-direction F1 - shuffled >=.02.
D. Opening MSE temporal <=.90*baseline.
E. Closing MSE temporal <=1.05*baseline.
F. Global MSE temporal < baseline.
G. Cero ciclos y periodicidades finales (media cero implica cero en los tres seeds).
H. Sin incremento material de M3: se define antes de medir como no más de una reversión adicional en TOTAL de los tres seeds frente a baseline. Informar también conteos por seed, sin ocultar empeoramientos.
I. Media de MAX_CATEGORY_FRACTION <=.90.

No gates adicionales, no modificación posterior. Comparar gaps global/apertura/cierre a E3B BEST exclusivamente como diagnóstico. Si falla cualquier gate: TEMPORAL_EMG_CONTEXT_NOT_SUPPORTED y cerrar vía recurrente con Denis/WMoos actuales; no L16/L32/LSTM/Transformer. Si todos pasan: preparar E3E, no entrenar.

## Evidencia visual e integridad

Compactas: 200 episodios por cada uno de seis probes, PNG+FIG, e3axPlotEpisode. Annotated: reutilizar seis episodios congelados en diagnostic_selection.csv E3C (selección previa por resultados E3B); usar exclusivamente primer seed preregistrado para visualizar, no el mejor. Dos comparaciones por episodio: BASELINE vs TEMPORAL_EMG y E3B BEST vs TEMPORAL_EMG. Reutilizar e3cPlotAnnotatedEpisode y CSV/MAT exactos. Viewer: tres políticas por esos seis episodios, mismo formato y procedencia saved_actor -> runtime glove-free -> planta canónica. Única extensión de infraestructura histórica permitida: reconocimiento del nuevo wrapper en exportE3AXViewerTrace, con copia/hash/diff explícitos, sin cambiar campos ni simulación.

Mantener 326 tests existentes; resultados nuevos fuera de directorios históricos. Congelar hashes antes de ejecutar; proteger fuentes, pesos y resultados anteriores. Añadir tests de interfaces40/12, causalidad, ausencia de mecánica en memoria, reset, prefijos, shuffle pasado, labels offline, tres seeds/receta, closed-loop, heads, figuras, CSV/MAT, viewer, determinismo e integridad. Ningún entrenamiento RL, cambio Git ni push.
