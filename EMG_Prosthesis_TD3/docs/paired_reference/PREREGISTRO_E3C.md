# E3C — Auditoría de información temporal

2026-09-09. Creado antes de entrenar probes o medir VALIDATION E3C.
Rama experiment/no-glove-paired-reference-td3, HEAD165be049eb41fc41254435181c9857fe0f22ed1c.
Worktree real ProtesisPracticas_e2b_audit. Historia Git pendiente, no repararla ni publicar.

## Pregunta y límites

Historia causal de markov52, ¿permite imitar mejor Oracle H5 y mejorar apertura en lazo cerrado que el estado instantáneo?
E3C es supervisado offline, no RL. No cambiar Env, runtime E2A, PPO E3B, teacher, reward, Ts=.2, PWM, h(q), planta, WMoos ni markov52. Referencia física no validada. No E1–E1D, decoder, sandbox ni hardware.

TRAIN: BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA.
VALIDATION: JOE, JONATHAN, KHAROL. MATEO/SANDRA sellados.
Los mismos200 episodios congelados E2B:140TRAIN,60VALIDATION. No ampliar demostraciones por rendimiento. Evaluación no ajusta LR, épocas ni arquitectura. Tres seeds, sin escoger la mejor en validation.

## Datos y causalidad

Se reutilizan las200 demostraciones originales Oracle H5 de e2f_results/trajectories.mat, columna7, sin recalcular ni optimizar el Oracle. Para cada episodio, reconstruir sus estados ejecutando sus PWM guardados desde su q inicial en GloveFreePolicyRuntime. Exigir igualdad exacta con q de la demostración. Etiqueta: cuatro categorías Oracle de la transición actual. Entrada: markov52 ANTES de dicha transición.

Entrada contiene sólo40WMoos,4encoder normalizados,4delta encoder,4acciones efectivas PREVIAS. No contiene teacher, reward, acción actual/futura, futuro EMG/q, sujeto, dirección, índice de paso ni longitud final del episodio. Pasado del Oracle influye en la mecánica y previousAction de la demostración, lo que es causalmente válido pero puede inducir dependencia de la distribución del experto. La evaluación posterior usando acciones propias es obligatoria para detectar esa limitación. El Oracle conoce futuro teacher; su etiqueta puede ser impredecible desde información disponible en ejecución. No prometer reconstrucción continua individual del guante.

Contexto t: estados max(1,t-7):t del MISMO episodio. Como máximo8 decisiones; prefijos reales de1..7, sin relleno ni datos de otro episodio. GRU parte de hidden=0 en cada ventana; esto limita estrictamente memoria a L8, también en inferencia. El wrapper conserva la ventana entre decisiones y se reinicia por episodio; no transporta hidden de una ventana anterior más allá de L8. No confundir esta prueba de ventana corta con recurrencia indefinida E3D.

## Modelos y receta congelada

- FF:52→FC64/ReLU→FC64/ReLU→4FC15.
- GRU:sequenceInput52→GRU64(OutputMode=last)→FC64/ReLU→4FC15. GRU unidireccional, no estado compartido con otro episodio ni critic.
- Las15categorías y desempate conservan E3B: [0,-64,+64,-96,+96,-128,+128,-160,+160,-192,+192,-224,+224,-255,+255].
- Seeds supervisadas:20260912,20260913,20260914; CPU serial. Ambas familias usan misma seed y orden de datos por pareja; no exige pesos iniciales equivalentes entre arquitecturas.
- Adam LR=.001, beta1=.9,beta2=.999,epsilon=1e-8;40 épocas fijas; batch≤64; clip de norma global1; sin weight decay, dropout, early stopping, schedule ni nueva normalización de observación/reward.
- Loss: media de NLL de las4cabezas y muestras; sin reponderación de clases. Registrar desbalance y matriz de confusión completa; el gate usa macro-F1 y NLL, no sólo accuracy.
- Batches agrupados por longitud REAL de prefijo (1..8), permutación TRAIN por seed/época; se baraja el orden de batches y se usa el último incompleto. Mismo plan de batches para FF/GRU. Todos los ejemplos una vez por época.
- Congelar modelo al terminar época40. Guardar modelo, config, seed, plan/procedencia, logs y hashes antes de evaluación. No seleccionar seed ni época usando VALIDATION. Figuras/viewer principales: primera seed20260912, escogida ahora por índice, no por rendimiento; métricas y compactas para las3seeds.

Implementación con dlnetwork/dlarray/dlfeval en MATLAB R2023b; GRU last real, no simulación feed-forward de una recurrente. Referencias de API: [GRU MathWorks](https://www.mathworks.com/help/deeplearning/ref/nnet.cnn.layer.grulayer.html), [loops personalizados](https://www.mathworks.com/help/deeplearning/ug/custom-training-loops.html). Compatibilidad verificada además contra instalación local.

## Control temporal y diagnóstico secundario

ORDER_SHUFFLED: conservar estado actual al final; permutar determinísticamente sólo estados anteriores del contexto, mismas muestras/multiconjunto. RNG local20260921+100*episodio+paso; si permutación identidad y hay≥2estados previos, rotar una posición. Con longitud1/2 no hay orden pasado alterable; reportar esa fracción. No usar control para training.

Diagnóstico secundario de fase/dirección: etiqueta6clases = dirección opening/closing × EARLY/MIDDLE/LATE, con fase=min(3,1+floor(3*(t-1)/N)), N horizonte teacher válido. Etiqueta privilegiada no disponible al actor. Tras congelar actor, extraer activación latente64 y ajustar un clasificador LINEAL6clases separado exclusivamente TRAIN: Adam/40épocas/batch64/LR.001 y seed correspondiente+500. No retropropagar al actor. Medir accuracy/macro-F1/NLL de6clases, dirección y fase marginal. Es lectura diagnóstica de representaciones, no nuevo decoder ni parte de política. No interviene en gate.

## Métricas y gate

Imitación: confusion15×15 por motor, accuracy, macro-F1 (media de15clases, F1=0 si denominador0), NLL media por cabeza, top2; conjunta exact4acciones y NLL suma4. Categorías ausentes siguen visibles con soporte0; no elegir categorías por VALIDATION. Métrica global media de heads, seeds con igual peso. Desgloses TRAIN/VALIDATION, sujeto, opening/closing y motor.

Lazo cerrado:200episodios por modelo/seed (1200replays), argmax causal sobre estados propios hasta EMG exhausted; teacher sólo métricas posteriores en horizonte común histórico. Reutilizar métricas y detectores E2B/E2D/E2F. Guardar q,state,PWM,probs,entropy,reference,reward. Métricas macro por sujeto/dirección como E3B; conteos M3/ciclos/periodicidad son sumas. MAX_CATEGORY_FRACTION por motor incluyendo cero, reportar global y dirección.

Gate primario sobre media de3seeds VALIDATION:
 A. macro-F1 GRU−FF≥.03.
 B. NLL GRU≤.95*NLL FF (NLL media por cabeza; suma conjunta equivalente en proporción).
 C. MSE apertura GRU≤.95*MSE apertura FF.
 D. flat_response apertura GRU≤flat_response FF−.05.
 E. MSE cierre GRU≤1.05*MSE cierre FF.
 F. Cero ciclos finales y periodicidades finales GRU en cada seed VALIDATION; suma de retrocesos M3 GRU no excede FF+1 sobre las3seeds y ninguna seed excede su FF+1. Ese≤1evento adicional define aquí «no material» y no demuestra seguridad universal. MAX_CATEGORY_FRACTION≤.90 por motor VALIDATION, y reportar aparte direcciones sin ocultarlas.
 G. Control desordenado pierde≥.01 macro-F1 y aumenta≥1%NLL frente GRU ordenado, medias3seeds. Requiere pérdida direccional de F1 y NLL en al menos2/3seeds. No atribuir todo a orden si sólo mejora GRU frente FF: capacidad/arquitectura también difieren y el control es perturbación fuera de distribución.
 A/B/C deben tener mejora del signo correspondiente en al menos2/3seeds, sin exigir umbral completo en cada seed. No ajustar gates después.

Bootstrap pareado por episodio: promediar semillas primero; diferencias GRU−FF de MSE y flat_response;5000 réplicas, seed20260922;60episodios VALIDATION global y30apertura por separado; percentiles2.5/97.5. No tratar seeds/pasos/motores como episodios independientes. CI descriptivo, no cambia gate; episodios del mismo sujeto pueden correlacionarse.

Si cualquier gate falla: TEMPORAL_INFORMATION_NOT_DEMONSTRATED; no E3D ni barrido adicional. PASS autoriza preparar E3D, nunca entrenar. No escalar PPO feed-forward.

## Figuras congeladas y viewer

Seleccionar ahora usando exclusivamente E3B existente, con CSV de selección congelado antes de entrenar. Unión: peor apertura VALIDATION por MSE; máxima flat_response apertura (empate mayor MSE, sujeto/fila); apertura mediana por MSE; cierre con mayor mejora de MSE frente TD3 BEST; apertura mediana de cada JOE/JONATHAN/KHAROL. Empates siempre sujeto/fila ascendente. El archivo diagnostic_selection.csv identifica los casos y motivos. No elegir usando E3C.

Compactas:reutilizar e3axPlotEpisode,200por modelo/seed (1200PNG+1200FIG). BEST/LAST E3B400existentes se conservan y enlazan. Annotated:4filas×2columnas para FFvsGRU y E3BBESTvsGRU, primera seed fijada; teacher,h(q), acción efectiva PWM/255 con signo por paso. Probabilidad separada de acción, valores exactos enCSV/MAT:step,teacher,h,category,PWM,effective,selectedProbability,headEntropy,q,deltaQ.

Viewer: extensión mínima explícita de exportE3AXViewerTrace para reset/clase E3C, conservando formato y ruta histórica. Cada actor guardado recorre runtimeEMG-only; contrastar su q/PWM con replay ya evaluado, no importar ni simular con sandbox. CSV selección y traces de las3políticas en mismos episodios. Modificación del exportador será única excepción histórica autorizada y se auditará por diff; nunca cambiar Env/runtime.

## Integridad y tests

Congelar hashes históricos, E3B1M, audit y fuentes anteriores antes de cambios. Pruebas nuevas:ventanas/episodios/no futuro,Oracle sólo label,GRU reset/longitud/shuffle,4heads/acciones,probabilidades finitas,teacher ausente,closed-loop determinista,figuras2formatos,CSV/MAT/viewer,hashes. Las294regresiones disponibles deben conservarse; pruebas que escriben artefactos se ejecutan controladamente y se verifica igualdad de bytes cuando corresponda. No entrenamiento RL largo, no Git repair/push, no E3D antes del resultado.
