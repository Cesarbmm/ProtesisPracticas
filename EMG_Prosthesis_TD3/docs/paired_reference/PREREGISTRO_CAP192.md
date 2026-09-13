# Diagnóstico único CAP192, sin entrenamiento

Preregistro creado antes de ejecutar los replays CAP192. Fecha: 2026-09-08.
Worktree: `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`.
Rama: `experiment/no-glove-paired-reference-td3`; HEAD: `165be049eb41fc41254435181c9857fe0f22ed1c`.
No se repara Git ni se publica. E3A-X sigue siendo exploratorio; el contrato de referencia no está validado.

## Pregunta y única intervención

Evaluar si recortar las acciones extremas del actor congelado a ±192/255 mejora su comportamiento bajo las restricciones históricas. BEST = Episode10000; LAST = Episode20000 de `results/e3ax_long/run_20260908_141321_916_6ebf347b`.

`desiredRaw = actor(state)`; `commandRaw = min(192/255,max(-192/255,desiredRaw))`.
Después se llama al `GloveFreePolicyRuntime` original: remapeo `baselineQuantized`, niveles originales, Ts=.2, planta `patternCurveCanonical`. **Recorte, no multiplicación de toda la acción**. Ninguna acción interior cambia directamente. La evolución del estado sí puede cambiar después de aplicar una acción recortada: el actor se consulta otra vez con ese estado real. El bloque previous action de markov52 contendrá la acción efectiva aplicada (PWM/255), nunca la deseada.

Sin nuevos agentes, entrenamiento, modificación de pesos, reward, teacher, h(q), observación, cuantizador ni planta. No se prueban otros caps. No se integra código sandbox.

## Episodios y reproducción OFF

Mismos 200 episodios E2B–E3A-X, mismo orden, EMG, posición inicial, teacher y horizonte común de métricas. TRAIN: 140 episodios de BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL e IVANNA. VALIDATION: 60 de JOE, JONATHAN y KHAROL. MATEO/SANDRA sellados. Seed de replay: 20260908; actor determinista sin ruido.

Se ejecutan OFF y CAP192 para ambos checkpoints (800 episodios de inferencia). OFF exige igualdad exacta de estado, raw, effective, PWM y q contra las trazas E3A-X guardadas; reward con error máximo 1e-12. Cada runtime agota exclusivamente EMG; teacher sólo se incorpora después para métricas en el horizonte común histórico. Se conservan también trazas completas EMG-only y sus diagnósticos, sin confundir ambos horizontes.

## Métricas congeladas

Usar `e2bControlMetrics` y la agregación macro sujeto/dirección de `e2fAggregate`, sin redefinir sus métricas: MSE, MAE, reward y descomposición, actionL2, deltaActionL2, saturationFraction histórica >=.95, flat_response, action_no_motion. Reportar TRAIN/VALIDATION/ALL y desglose por sujeto, motor y dirección.

Guardar distribución PWM firmada, y `BOUND_HIT_FRACTION_192 = número de comandos con abs(PWM)==192 / número de comandos aplicados`, incluyendo PWM0 en el denominador, agrupado por split/motor/dirección/sujeto. El gate utiliza la fracción global por comandos de BEST VALIDATION, no el promedio no ponderado entre episodios. Reportar adicionalmente fracción de desiredRaw recortados; no confundirla con bound hit: la cuantización ya puede producir PWM192 sin recortar.

Retroceso M3: PWM_M3>0 y q_after_M3-q_before_M3<0. PWM0 no debe producir movimiento. Ciclos: detector histórico `e2dCycleScan`, cuatro transiciones finales, amplitud h(q)>.05; todos los prefijos se reportan como ventanas transitorias. Periodicidad final: `e2fPeriodicTrace`, períodos 2–8, cuatro períodos repetidos en (q, PWM previo), tolerancia q=1e-9 y amplitud h(q)>.05. No se declara estabilidad universal.

## Gate fijado antes de observar CAP192

Únicamente BEST VALIDATION determina el apoyo al cap; LAST y TRAIN son diagnósticos:

1. `(MSE_cap-MSE_off)/MSE_off <= .05`.
2. `(reward_off-reward_cap)/abs(reward_off) <= .05`; un valor negativo indica mejora.
3. Retrocesos M3 CAP <= 10% de OFF (con baseline 134, máximo 13 eventos enteros).
4. Cero nuevos pares episodio/motor con ciclo final o periodicidad final respecto a OFF. Se aplica también al runtime EMG-only completo como comprobación de ejecución. Las ventanas transitorias se registran sin convertirlas automáticamente en órbitas autónomas.
5. `BOUND_HIT_FRACTION_192 <= .50` en BEST VALIDATION. Se operacionaliza así «no casi siempre pegada»: el límite no puede ocupar la mayoría de decisiones de motor. Es un umbral diagnóstico explícito y conservador, no una ley física ni una optimización posterior. Se muestran los desgloses para evitar ocultar un motor saturado.
6. Cero movimiento con PWM0; OFF reproducido; tests e integridad histórica pasan.

No se cambian los umbrales después de medir. Si falla algún criterio: CAP192_SUPPORTED=NO; TD3_CONTINUOUS_SCALING_NOT_JUSTIFIED=YES para este siguiente escalado; recomendar FACTORIZED_CATEGORICAL (4 cabezas ×15 acciones), sin implementarlo. El fallo no refuta todas las políticas continuas posibles.

Si todos pasan, preparar exclusivamente especificación/runner E3B desde cero, seed nuevo 20260909, 100000 episodios y checkpoints [1000,5000,10000,20000,30000,50000,75000,100000], con el mismo recorte y selección por VALIDATION. No iniciar training. No recomendar todavía 500k ni 2M.

## Artefactos y viewer

Resultados separados en `analysis/paired_reference/cap192_results/`: configuración, hashes, selección, trazas MAT/CSV, reproducción OFF, métricas, gate JSON y figuras resumen. No sobrescribir la corrida E3A-X.

Crear exportador pasivo `exportE3AXViewerTrace` que carga únicamente `saved_actor`, ejecuta el runtime canónico y exporta q encoder, PWM, step, Ts y metadatos. Demostración fijada a BLANCA fila1 cierre para BEST, LAST, con y sin cap; el formato admite cualquier episodio development autorizado. No usa ninguna planta sandbox; futura integración del viewer permanece diferida. Trazas de P2/Oracle, si se visualizan posteriormente, deben conservar su procedencia privilegiada separada.

Mantener 233 tests existentes y añadir pruebas del cap, previous action real, igualdad OFF, remapeo/reward/planta intactos, determinismo, conteos, gates y formato/procedencia de viewer. Los hashes se capturan antes de medir y se verifican al terminar.
