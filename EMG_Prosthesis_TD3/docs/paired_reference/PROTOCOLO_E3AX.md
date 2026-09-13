# E3A-X — Preparación de entrenamiento exploratorio manual

2026-09-08. Autorización explícita del usuario: preparar una corrida TD3 nueva
de 20000 episodios, ejecutar sólo smoke de 5 episodios y dejar el comando manual.
No cambia el cierre E2G: REFERENCE_CONTRACT_VALIDATED=NO. El entrenamiento es
exploratorio bajo referencia ORIGINAL, no una validación del contrato físico.
No proyección, recalibración, guard, deadband, hardware ni sandbox. Sin reparar
Git, cambiar rama o push. MATEO/SANDRA sellados; E1–E1D cerradas.

## Split congelado antes del smoke

Orden alfabético de los diez sujetos DEVELOPMENT, primeros siete TRAIN y
últimos tres VALIDATION. No se selecciona por rendimiento. TRAIN: BLANCA,
CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA. VALIDATION: JOE, JONATHAN, KHAROL.
Se guardan este split y su hash al inicio. Todos habían sido explorados en
etapas anteriores: VALIDATION es separada del nuevo entrenamiento, no un test
final inédito. No se cargan MATEO/SANDRA.

Training largo: todas las filas TRAIN, semántica histórica de Env (pares
cierre/apertura, permutación de filas, reset y agotamiento EMG o teacher).
Seed único20260908; CPU, sin parallel. TD3 nuevo feedforward64/64, receta
agentTd3/configurables histórica: markov52, Ts=.2, baselineQuantized,
PWM0±[64,96,128,160,192,224,255], planta patternCurveCanonical, h(q) y teacher
originales, reward trackingMseActionRateReward y pesos.01/.05 intactos.
El máximo histórico50pasos se comprueba contra las longitudes teacher; no se
truncan silenciosamente episodios más largos.

SMOKE:5episodios; sólo subconjunto TRAIN de hasta3filas que permiten al menos
20transiciones por dirección, para superar minibatch64 y comprobar cambios
reales del actor y críticos. Misma receta de agente, sin warm start artificial.
Checkpoints smoke2/5, evaluación2episodios TRAIN y2VALIDATION de la lista E2B.
Resultados exclusivamente results/e3ax_smoke; sin interpretación científica.

## Checkpoints, evaluaciones y selección

Milestones largos:250,500,1000,2000,5000,10000,15000,20000. Un solo train continuo;
no se divide en llamadas que reinicien contadores o exploración. rlCustomEvaluator
R2023b conecta el reward macro de VALIDATION a Evaluation Statistic del monitor.
En los milestones se guarda primero un checkpoint inmutable y se evalúa una
copia cargada, preservando RNG y sin usar/resetear el Env de training.

Evaluación determinista: mismos200episodios E2B/E2F,140TRAIN y60VALIDATION según
split. Intermedios: sólo60VALIDATION, MAT/CSV/métricas y una figura resumen.
BEST se selecciona exclusivamente por mayor reward macro VALIDATION original;
empate exacto:menor MSE, luego episodio más temprano. LAST es Episode20000
si se completó; si el usuario detiene antes, el resumen lo declara incompleto.
No se rellena ni se etiqueta un checkpoint anterior como Episode20000.

Inferencia usa getAction(actor,{markov52}) y GloveFreePolicyRuntime sin glove,
hasta agotar EMG. Referencias E2B sólo se consultan para métricas posteriores
en el horizonte teacher común; el tramo EMG restante se guarda separadamente,
sin inventar reward fuera de disponibilidad teacher. Configuración temporal,
acción y q0 conservados; teacher no entra al actor ni al runtime.

Final: evaluar BEST y LAST en los200episodios y generar una figura PNG+FIG
por episodio con cuatro motores. Comparadores ZERO, Agent7250 diagnóstico,
P2 y OracleH5 privilegiados se reutilizan de trazas E2F con idénticas referencias
y q0, y se agrupan por el mismo split. TD3 es EMG-only durante ejecución.
No interpretar un oracle privilegiado como demostración de información EMG.

## Persistencia y ventana

Carpeta única results/e3ax_long/run_timestamp_UUID. Antes de entrenar:config MAT/JSON,
split,seed,manifiesto,STARTED y diary. CSV incremental por episodio; snapshots
de stats en milestones. Checkpoints con InfoToSave ExperienceBuffer/Optimizer/
PolicyState/Target=true según API local R2023b, más RNG y orden/contador Env.
No sobrescribir checkpoints existentes. No hay runner de reanudación exacta:
AGENT_CHECKPOINT_AVAILABLE=YES; FULL_TRAINING_RESUME_AVAILABLE=NO (no validada).

Comando principal dentro de MATLAB Desktop, sin -batch/-nodesktop/noFigureWindows.
Plots='training-progress' explícito. Guardar objeto completo trainingStats MAT,
CSV de campos realmente disponibles y figura reproducible FIG/PNG/SVG.
No cerrar Training Progress al finalizar. Captura del monitor opcional y no
fiable como API portable; la evidencia principal son stats y figuras exportadas.

El runner rechaza una sesión con constantes Env incompatibles ya cargadas:
usar MATLAB recién abierto en ese caso. No borra variables ni ejecuta clear classes.
Las evaluaciones históricas que llaman close all no se invocan. El plotter
compacto local se deriva de createRepresentativeEpisodeFigure del audit largo
histórico; corrige nombres de motor y usa explícitamente h/reference normalizados.

## Criterio de preparación

PASS exige smoke5 completo, actor y críticos actualizados, monitor visible,
trainingStats/checkpoints recargables, evaluación determinista y figuras correctas,
196 regresiones y nuevos tests. El smoke no mide calidad de control.
La IA nunca inicia la corrida20k. El usuario la ejecutará manualmente.

Antes de dejar la máquina: corriente, espacio libre suficiente, evitar suspensión
o hibernación y no cerrar MATLAB. Bloquear pantalla no detiene el cálculo si
Windows permanece activo. No se cambia configuración de energía automáticamente.
