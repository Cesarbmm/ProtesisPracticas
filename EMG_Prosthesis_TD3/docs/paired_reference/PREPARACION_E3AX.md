# E3A-X — Ejecución manual exploratoria

La preparación incluye un smoke completo de cinco episodios. La IA no ha
ejecutado la corrida de 20000 episodios. El contrato físico de referencia
continúa **NO VALIDADO**; E3A-X está autorizado expresamente como exploración.
Teacher ORIGINAL, planta canónica, markov52, reward y receta TD3 históricos.
MATEO/SANDRA siguen sellados. Sin hardware, reparación Git ni push.

## Comando manual exacto

Abrir **MATLAB Desktop R2023b** y pegar:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code'); summary = runE3AXLongTraining();
```

Esta es la ruta que existe y donde se verificó el smoke. No utilizar la grafía
anidada `ProtesisPracticas\_e2b\_audit` ni otro worktree. El comando inicia un
TD3 NUEVO, no Agent7250 ni el agente smoke. No requiere respuestas durante
la corrida. No usar `-batch`, `-nodesktop` ni `-noFigureWindows` para training.
El runner rechaza una sesión sin Desktop y una clase Env previamente cargada
con constantes incompatibles. En ese caso, abrir MATLAB de nuevo; no intentar
forzar las constantes con `clear classes` durante una sesión activa.

Antes de ejecutar: conectar corriente, evitar suspensión/hibernación, mantener
espacio de disco y memoria disponibles, y no cerrar MATLAB. Cerrar otras
sesiones de MATLAB que ya no se necesiten antes de iniciar la corrida. No se
cambia automáticamente la configuración de energía. Bloquear pantalla permite
seguir calculando mientras Windows permanezca activo.

## Qué hace el runner

Un solo `train`, 20000 episodios máximos, seed 20260908, CPU, sin parallel.
TRAIN: BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA.
VALIDATION: JOE, JONATHAN, KHAROL. Split definido antes del smoke por orden
alfabético, sin selección por rendimiento. VALIDATION ya fue explorada en
etapas anteriores: no equivale a test final inédito.

`Plots="training-progress"` muestra la ventana estándar de rlTD3Agent. El
evaluador R2023b devuelve reward macro VALIDATION como Evaluation Statistic
en los checkpoints programados. El runner no cierra el monitor al terminar.
Los gráficos auxiliares se crean invisibles y cierran únicamente sus propias
figuras. Se guarda todo trainingStats, además de CSV y gráficos reproducibles.

Cada ejecución crea una carpeta nueva con timestamp y UUID:

```text
matlab_code/results/e3ax_long/run_<timestamp>_<UUID>/
  STARTED.txt, config.mat/json, split.json, seed.txt
  manifest.json, plant_manifest.json, diary.log
  training_incremental.csv
  checkpoints/AgentEpisode000250.mat ... AgentEpisode020000.mat
  checkpoints/TrainingEpisode000250.mat ... TrainingEpisode020000.mat
  trainingStats.mat/csv
  training_progress.fig/png/pdf/svg
  evaluation/checkpoints/Episode00250/... (métricas y un resumen PNG)
  evaluation/best_checkpoint/metrics/
  evaluation/best_checkpoint/figures/TRAIN/ y VALIDATION/
  evaluation/last_checkpoint/metrics/
  evaluation/last_checkpoint/figures/TRAIN/ y VALIDATION/
  evaluation/comparison/ALL/, TRAIN/, VALIDATION/
  summary.mat/json, COMPLETED.txt
```

Checkpoints y evaluación determinista: **250, 500, 1000, 2000, 5000, 10000,
15000, 20000**. Se escribe el checkpoint antes de evaluar. Si la evaluación
falla, ese checkpoint permanece guardado; `EVALUATION_ERROR.json` conserva la
excepción original que rlCustomEvaluator oculta en su mensaje genérico.
CSV incremental por episodio y snapshots de estadísticas en cada milestone.
Un fallo posterior deja `FAILED.txt` sin borrar los archivos ya escritos.

Cada checkpoint guarda `saved_agent`, `saved_actor`, configuración, RNG,
orden/contador de episodios y posiciones finales del Env. Se solicita guardar
ExperienceBuffer, Optimizer, PolicyState y Target mediante InfoToSave de R2023b.
La evaluación carga sólo `saved_actor`, evitando duplicar el replay buffer en
RAM. **AGENT_CHECKPOINT_AVAILABLE=YES; FULL_TRAINING_RESUME_AVAILABLE=NO**:
no se implementó ni validó una reanudación exacta de toda la sesión. No usar
un checkpoint de agente para afirmar una continuidad exacta del optimizador,
exploración, entorno y Training Manager. No se sobrescriben checkpoints.

## Evaluación y figuras

Intermedios: los 60 episodios VALIDATION del conjunto E2B de 200 episodios;
CSV/MAT de métricas, trazas y un resumen PNG por checkpoint. BEST se selecciona
sólo por mayor reward macro VALIDATION; desempate menor MSE y luego episodio
anterior. LAST corresponde al episodio 20000 si terminó. Una interrupción
anterior no se etiqueta falsamente como Episode20000.

BEST y LAST se evalúan al final sobre los 200 episodios (140 TRAIN y 60
VALIDATION). Una figura por episodio, cuatro paneles verticales M1–M4 con
teacher/reference y h(q). Archivos `SUJETO_row0001_closing.png/.fig` o opening,
sin valores numéricos escritos sobre cada muestra. Las acciones completas
permanecen en CSV/MAT. Se reutilizó el diseño compacto de
`workflows/legacy/run_longrun_td3_audit.m`, mediante `e3axPlotEpisode`; no se
invoca el runner legacy ni su cierre global de figuras.

Inferencia mediante GloveFreePolicyRuntime y actor congelado, hasta EMG
exhausted. Teacher se consulta sólo después para métricas en el horizonte
común. El tramo EMG adicional se conserva en runtimeTraces sin inventar reward.
Comparación final: ZERO, Agent7250 diagnóstico, P2 privilegiado, Oracle H5
privilegiado, BEST TD3 y LAST TD3. MSE, reward, actionL2, deltaActionL2,
saturación, ciclos y retrocesos M3; también resúmenes por split/sujeto/dirección/
motor. Los comparadores históricos usan las mismas referencias, q0 y episodios.

Los tests unitarios/regresiones no generan una figura por test. Las figuras
por episodio pertenecen a la evaluación de políticas. Los tres plotters se
prueban además con fixtures pequeños, sin entrenar.

## Smoke verificado y error corregido

Smoke exitoso:
`results/e3ax_smoke/run_20260908_070829_356_11986845/`.
**5 episodios, 110 pasos**, actor y ambos críticos con parámetros actualizados.
Checkpoints 2 y 5 recargables; evaluación VALIDATION en ambos; selección y
evaluación visual BEST/LAST completas sobre cuatro episodios del smoke.
Se exportaron trainingStats MAT/CSV, curvas FIG/PNG/PDF/SVG y ocho figuras
de episodios PNG+FIG (cuatro BEST y cuatro LAST). Todos los resultados smoke
son exclusivamente evidencia de infraestructura, sin interpretación científica.

El error comunicado de rlCustomEvaluator procedía de añadir el primer
resultado a `struct([])` mediante indexación con campos distintos. El primer
registro se asigna ahora directamente y los siguientes se añaden. La corrección
se verificó primero reutilizando el checkpoint ya guardado, sin entrenar.
También se corrigió el callback de guardado: R2023b entrega una estructura
histórica de estadísticas con EpisodeIndex vector, no EpisodeCount escalar.

Los intentos fallidos se conservaron separados. Un preflight posterior detectó
un archivo histórico vacío: el nuevo verificador SHA256 admite archivos vacíos
y lee por bloques, sin modificar el helper histórico. Otro intento completó
training y stats pero agotó memoria exportando una figura mientras persistían
sesiones fallidas de MATLAB. Se cerraron únicamente las sesiones fallidas
abiertas por la IA y se redujo memoria de evaluación cargando sólo el actor;
después pasó el smoke completo. No se cambió minibatch, reward ni TD3 para
resolver estos errores de infraestructura.

Se observó y capturó la ventana estándar al finalizar cinco episodios
(`training_monitor_observed.png`). La captura Win32 tuvo recorte por escala DPI;
no se ofrece una captura automática portable como garantía:
**TRAINING_MONITOR_SCREENSHOT=NOT_RELIABLY_SUPPORTED**. La evidencia principal
completa son trainingStats y training_progress.fig/png/pdf/svg. El runner dejó
el monitor abierto al retornar.

Los resultados de regresiones y la integridad de los 816 archivos históricos
están en `analysis/paired_reference/e3ax_preparation/regression/`. La verificación
puede repetirse sin entrenamiento desde matlab_code con:

```matlab
addpath('analysis/paired_reference/e3ax'); e3axRunTests();
```

Cierre: **196/196 regresiones históricas + 29/29 pruebas E3AX = 225/225**.
Las 196 pasaron en la ejecución completa. Después se corrigieron únicamente
dos comprobaciones nuevas de CSV (redondeo numérico y delimitador explícito)
y se repitieron las 29 nuevas conservando evidencia de las 196 y verificando
otra vez los 816 hashes. El comando anterior ejecuta todo por defecto.
Las pruebas de artefactos verifican que los estados guardados reproducen las
acciones del actor, las transiciones de planta, el estado de acción anterior,
el reward histórico y las referencias originales. Ninguna prueba entrena.

La corrida larga queda pendiente de ejecución manual por el usuario.

## Estado posterior a la preparación

El usuario ejecutó después la corrida `run_20260908_141321_916_6ebf347b`.
Consultar [la auditoría de esa corrida](AUDITORIA_CORRIDA_E3AX.md). El cierre
actual publica TEST_COMPORTAMENTAL.html/md/json en raíz, con todas las figuras
enlazadas, y verifica cobertura antes de COMPLETE. La preparación y el smoke
descritos arriba se conservan como evidencia histórica de ese momento.
