# Preregistro E3B — PPO multicategórico factorizado

Fecha: 2026-09-08. Antes del smoke y del entrenamiento científico.
Rama experiment/no-glove-paired-reference-td3, HEAD165be049eb41fc41254435181c9857fe0f22ed1c. No reparar Git ni publicar. E3A-X y CAP192 cerrados. Referencia original NO validada físicamente.

## Hipótesis y alcance

Comparar una política que representa directamente las15acciones canónicas de cada motor con TD3 continuo seguido de cuantización. Se cambia algoritmo/representación de política, no el conjunto de transiciones físicas. Esta comparación no aísla causalmente sólo la representación: PPO es on-policy, TD3 es off-policy; una mejora futura será evidencia del conjunto algoritmo/representación, no una ablación que atribuya todo a la categorización.

Cuatro cabezas independientes condicionadas por un tronco compartido; cada cabeza tiene logits para [0,-64,+64,-96,+96,-128,+128,-160,+160,-192,+192,-224,+224,-255,+255]. Nunca enumerar15^4. Política conjunta=producto de probabilidades por motor; log probabilidad y entropía conjuntas=suma de las cuatro cabezas.

## Implementación y soporte real

El código instalado R2023b de rl.function.rlDiscreteCategoricalActor construye una distribución única y comprueba que el tamaño de salida coincida con getNumberOfElements(ActionInfo). No se presenta ese constructor como multicategórico factorizado. Se usa un loop propio con dlnetwork, dlarray, dlfeval/dlgradient y adamupdate. El monitor será el de loop personalizado, no una ventana rlTD3Agent.

Fuentes primarias: [actor categórico MathWorks](https://www.mathworks.com/help/reinforcement-learning/ref/rl.function.rldiscretecategoricalactor.html), [loops propios](https://www.mathworks.com/help/deeplearning/custom-training-loops.html), [PPO original](https://arxiv.org/abs/1707.06347). La compatibilidad concreta se verificará ejecutando R2023b local.

## Contrato inmutable

markov52: WMoos40 + encoder normalizado4 + delta encoder4 + previous effective action4. Teacher original sólo reward/tracking/reset/done. Env y GloveFreePolicyRuntime originales no se editan. Ts=.2, patternCurveCanonical, h(q), baselineQuantized, pesos reward .01/.05 y niveles completos intactos. No cap, proyección, alineación, deadband ni otra heurística.

La categoría determina PWM; effectiveAction=PWM/255. El adaptador entrega ese representante exacto al puerto numérico de Env/runtime, para reutilizar su implementación histórica. No es una salida continua aprendida: el remapeo es identidad sobre este conjunto. Se probarán las15categorías en cada motor contra aplicación directa de PWM en la planta, y contra la ruta histórica, con igualdad de q, effective, reward y estado. Se aserta que previousAction contiene PWM aplicado/255 en cada transición.

## Hiperparámetros congelados

- Seed científico:20260910; smoke:20260911. CPU, ejecución serial.
- Actor nuevo:52→FC64→ReLU→FC64→ReLU; cuatro capas FC15 separadas, sin softmax compartido. Critic V(s) nuevo:52→FC64→ReLU→FC64→ReLU→FC1. Sin recurrente, dropout, batch norm ni capas adicionales.
- Gamma=.99; lambda GAE=.95. Reward sin normalización ni clipping. Observación histórica sin nueva normalización.
- Rollout on-policy:1024transiciones como máximo. Actor fijo durante la recolección. Vaciar después de actualizar; no replay buffer persistente.
- Rollout se corta también exactamente en checkpoint, presupuesto final o final del smoke. Cortar un rollout no convierte el estado en terminal.
- GAE: delta=r+gamma*(1-done)*V(next)-V(s); A=delta+gamma*lambda*(1-done)*A_next. En un corte no terminal usar V(next); en teacher done, bootstrap=0 y no propagar al episodio siguiente.
- Returns=A_original+V(s). Normalizar sólo advantages de cada rollout mediante (A-mean)/max(std poblacional,1e-8). Returns conservan escala original.
- PPO clipping=.2. Actor loss=-mean(min(ratio*A,clip(ratio,.8,1.2)*A))-.01*mean(entropía conjunta). Ratio=exp(logpi_actual-logpi_recolección).
- Critic loss=.5*mean((V-return)^2); redes/optimizadores separados. Sin value clipping ni parada anticipada por KL; registrar KL aproximada y clip fraction.
- Adam actor LR3e-4, critic LR1e-3, beta1=.9,beta2=.999,epsilon1e-8. Sin schedule. Norma global de gradiente máxima .5 por red.
- 4epochs por rollout, minibatch64, nueva permutación por epoch; último minibatch incompleto se usa. Registrar normas por cabeza ANTES del clip, pérdidas, entropía, ratios y finitud.
- Acción de training: muestreo independiente de cada softmax estable, con RNG controlado. Evaluación: argmax por cabeza; empates resueltos por primera categoría del orden congelado (0 primero). Sin ruido ni actualización.

## Disponibilidad y presupuesto

TRAIN: BLANCA,CECILIA,DENIS,EMILIA,GABI,GABRIEL,IVANNA.
VALIDATION: JOE,JONATHAN,KHAROL. MATEO/SANDRA sellados.

Training conserva el muestreo/reset/done históricos de Env con teacher. Inferencia agota sólo EMG; métricas sobre el horizonte teacher común de los mismos200episodios. Validation no entra al gradiente.

Presupuesto científico exacto:1000000agent steps. Checkpoints50k,100k,250k,500k,750k,1M; guardar episodio y si está incompleto. Actualizar el rollout recolectado antes de escribir cada checkpoint; registrar ese orden. Un último episodio incompleto por presupuesto conserva done=false y bootstrap, se etiqueta como truncación presupuestaria, no como agotamiento teacher.

Smoke:6episodios completos de la selección smoke histórica (no resultados científicos); cortar/actualizar al sexto done. Checkpoints al tercer y sexto episodio para probar escritura/evaluación durante el loop. Misma arquitectura, pérdidas y receta; únicamente cambian seed, presupuesto y subconjunto de smoke. Prohibido iniciar la campaña larga automáticamente.

## Evaluación y criterios

Checkpoints intermedios: evaluación determinista de los60episodios VALIDATION, métricas/CSV/MAT y figura resumen, sin200figuras. BEST seleccionado por menor MSE macro VALIDATION; empate por mayor reward y menor número de pasos. Esto se fija ahora conforme al criterio primario MSE; no cambiar a selección por train ni al criterio reward de E3A-X después de ver resultados. Conservar alertas de estabilidad del BEST sin seleccionar retrospectivamente otro checkpoint para eludirlas.

BEST y LAST:200episodios cada uno, PNG+FIG compactos reutilizando e3axPlotEpisode (4motores por figura), métricas por TRAIN/VALIDATION/sujeto/motor/dirección, índice de figuras validado antes de declarar completo. Comparadores guardados ZERO,Agent7250,P2,OracleH5,TD3BEST,TD3LAST y categórico actual. P2/Oracle se etiquetan privilegiados.

Métricas históricas e2bControlMetrics/e2fAggregate, distribución PWM y fracción abs(PWM)=255. Entropía por cabeza en nats promedio sobre estados anteriores a acción; entropía no equivale a diversidad del argmax. MAX_CATEGORY_FRACTION por motor=frecuencia de su categoría más común entre las acciones deterministas aplicadas, incluyendo0. Guardar también proporción por cada categoría y desgloses.

Patología grave operacional para la clasificación: cualquier ciclo final/periodicidad final con los detectores históricos; cualquier retroceso M3 ejecutado; o MAX_CATEGORY_FRACTION>.90 en algún motor de VALIDATION. Son criterios conservadores de diagnóstico, no prueba de seguridad universal. No usar entropía alta para ocultar collapse del argmax.

Al presupuesto1M, CAT_STRONG_SIGNAL si BEST VALIDATION MSE<.051598 y sin esas patologías; CAT_LEARNING_SIGNAL si MSE<.059980845, no cumple strong y sin esas patologías. Si supera el umbral MSE pero falla estabilidad/collapse, clasificar SIGNAL_WITH_PATHOLOGY, sin escalado. NO_LEARNING si no supera el umbral TD3 fijado; reportar además magnitud porcentual, sin redefinir «material» después.

CONTINUE_TO_5M_STEPS=YES sólo si el checkpoint1M también cumple strong y MSE(500k)>=MSE(750k)>=MSE(1M), con alguno de los descensos estricto y sin patologías en los tres. En otro casoNO. No ejecutar ese escalado. Ni5M ni~28M autorizados en esta preparación.

## Durabilidad y verificación

Carpeta única results/e3b_{long|smoke}/run_timestamp_UUID, config/split/seed/manifiesto/STARTED/diary desde el inicio. Logs incrementales por episodio y actualización. Guardar actor, critic, momentos Adam, contador de updates, RNG, último rollout y estado/identificador del episodio en checkpoints escritos primero a archivo temporal. No sobrescribir checkpoint existente.

FULL_TRAINING_RESUME_AVAILABLE=NO: aunque se guardan pesos/optimizadores/RNG, no se declara restauración exacta del estado transient de Env/dataset/sesión sin validación específica. Preparar recuperación sólo del postprocesado sin reentrenar. Mantener monitor abierto; figuras reproducibles desde trainingStats y updateStats.

Pruebas:258previas, categorías/equivalencia, factorización, estabilidad numérica, clipping, GAE done/cortes, gradientes4heads, actor/critic cambiados, rollout finito on-policy, presupuesto/checkpoints, evaluación determinista, figuras completas, integridad y exportación viewer. Smoke evidencia infraestructura, nunca señal de control.

Única adaptación histórica autorizada: exportE3AXViewerTrace añade reconocimiento/carga del actor categórico manteniendo formato y ruta TD3 intactos. Registrar su diff/hash explícitamente; todo otro archivo histórico protegido debe mantener hash. Sandbox no se abre ni importa; viewer futuro lee q(t) sin recalcular planta. No hardware.
