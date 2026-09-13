# Preparación E3B — PPO multicategórico factorizado

E3B_PREPARATION = PASS. Se preparó la campaña de1M de pasos; **no se inició**. El smoke completó6episodios /132pasos, actualizó actor y critic y pasó las pruebas. No es un resultado científico de control.

## Qué implementa

Actor dlnetwork nuevo: markov52→FC64/ReLU→FC64/ReLU→cuatro cabezas FC15. Salida:60logits. Cada cabeza representa [0,-64,+64,-96,+96,-128,+128,-160,+160,-192,+192,-224,+224,-255,+255]. La política conjunta es el producto de cuatro categóricas; log probability y entropy conjuntas se suman por motor. No se enumeran15^4acciones.

Loop propio MATLAB R2023b/dlarray, probado en la instalación local. No se presenta rlDiscreteCategoricalActor como un constructor multicategórico. [La API documentada](https://www.mathworks.com/help/reinforcement-learning/ref/rl.function.rldiscretecategoricalactor.html) representa una categórica; el loop usa [autodiferenciación y Adam de MathWorks](https://www.mathworks.com/help/deeplearning/custom-training-loops.html) y la [pérdida PPO clipped](https://arxiv.org/abs/1707.06347).

La categoría determina PWM. Se usa PWM/255 únicamente como representante de transporte al puerto numérico del Env/runtime histórico. No hay raw continuo aprendido. Se comprobó para60casos (4motores×15categorías) que el adaptador, el puerto baselineQuantized histórico y la aplicación directa a SimController producen exactamente el mismo q siguiente; effectiveAction y reward también coinciden. Error máximo q/reward=0. En cada step se aserta previous effective action=PWM aplicado/255.

Env, su reset/done, reward, markov52/WMoos, h(q), teacher ORIGINAL, Ts=.2 y planta canónica no se editaron. Glove permanece fuera de actor/estado/transición y dentro de reward/disponibilidad teacher. Runtime de evaluación conserva terminaciónEMG_ONLY y métricas sobre horizonte común. REFERENCIA NO VALIDADA; hardware no autorizado.

## Receta preregistrada

Ver [preregistro completo](PREREGISTRO_E3B_CATEGORICAL.md), escrito antes del smoke. Seed científico20260910; seed smoke20260911. Sin cambios posteriores de hiperparámetros.

| Componente | Valor |
|---|---|
| Critic | V(s),52→64→64→1, red separada |
| Gamma /GAE lambda | .99 /.95 |
| Rollout | 1024steps máximo, on-policy; se vacía tras actualización |
| PPO epochs /minibatch | 4 /64; último minibatch incompleto incluido |
| Clipping /entropía | .2 /.01 por entropía conjunta |
| Actor loss | -mean(min(ratio*A,clip(ratio,.8,1.2)*A))-.01mean(sum(entropy_heads)) |
| Critic loss | .5mean((V-return)^2) |
| Adam LR actor/critic | .0003 /.001 |
| Adam beta1/beta2/epsilon | .9 /.999 /1e-8 |
| Norma global de gradiente | Máximo .5 por red |
| Normalización | Sólo advantages por rollout; no nueva normalización de estado/reward |
| Acción determinista | argmax independiente, empate por primera categoría |
| Presupuesto científico | 1000000agent steps exactos |
| Checkpoints | 50000,100000,250000,500000,750000,1000000 |

GAE respeta done real: el agotamiento teacher anula bootstrap y propagación al episodio siguiente. Un corte de rollout/checkpoint/presupuesto no inventa un terminal; se usa V(next) al cortar sin done. Los checkpoints se guardan después de actualizar el rollout recolectado hasta ese paso exacto. El último episodio puede quedar truncado por presupuesto; se registra explícitamente.

PPO cambia también el algoritmo frente a TD3. La campaña futura compara el conjunto algoritmo/representación bajo el mismo MDP, y no permite atribuir cualquier mejora exclusivamente a la representación de acción.

## Split y evaluación

TRAIN: BLANCA,CECILIA,DENIS,EMILIA,GABI,GABRIEL,IVANNA.
VALIDATION: JOE,JONATHAN,KHAROL.
MATEO/SANDRA no se cargaron.

Se reutilizan los200episodios congelados:140TRAIN y60VALIDATION. Cada checkpoint científico evalúa60VALIDATION y deja métricas, CSV/MAT, distribución categórica y resumen gráfico. Sin200figuras intermedias.

BEST se selecciona por menor MSE macro VALIDATION, empate por mayor reward y menos pasos, fijado antes del smoke. BEST y LAST reciben evaluación completa200episodios cada uno y **400PNG+400FIG en total**, una figura por episodio con4motores mediante e3axPlotEpisode. e3axCheckEvaluationFiles verifica identificación, cobertura y archivos legibles antes de marcarCOMPLETE. El informe TEST_COMPORTAMENTAL.html enlaza cada episodio.

Comparadores guardados: ZERO,Agent7250,P2,OracleH5,TD3BEST,TD3LAST y categórico actual. P2/Oracle identificados como privilegiados. Se guardan MSE,MAE,reward,actionL2,deltaActionL2,saturación,flat_response,action_no_motion,retrocesosM3,ciclos,periodicidad,distribución por15categorías y fracciónabs(PWM)=255, por split/sujeto/motor/dirección.

Las entropías por cabeza se miden en nats sobre estados previos a cada acción. MAX_CATEGORY_FRACTION incluye categoría0 y usa la distribución de acciones aplicadas por motor. No se confunde entropía softmax con diversidad del argmax.

## Clasificación futura y límites

CAT_STRONG_SIGNAL: BEST VALIDATION MSE<.051598 y sin patologías preregistradas.
CAT_LEARNING_SIGNAL: MSE<.059980845 sin alcanzar strong y sin patologías.
SIGNAL_WITH_PATHOLOGY: mejora MSE pero hay ciclos/periodicidad final, retrocesosM3 o categoría dominante>.90 en algún motorVALIDATION.
NO_LEARNING: no alcanza el umbralTD3 fijado. Se reporta además el porcentaje de mejora.

El escalado a5M requiere checkpoint1M strong y tendencia500k→750k→1M no creciente en MSE, con algún descenso estricto y sin patologías en los tres. No se ejecuta escalado automático. ~28Msteps/~2Mepisodios no autorizados.

## Smoke y pruebas

Salida smoke: C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e3b_smoke\run_20260908_204945_939_f411b82c

-6episodios completos;132steps; checkpoints66 y132, episodios3 y6.
-16minibatches de optimización en total; actor y critic cambiaron.
-Normas máximas de gradiente por cabeza antes de clipping: [4.032737226291452, 3.243154872903776, 4.046293979053639, 4.080906435315209].
-Acciones legales, log probabilities/entropías/valores/rewards finitos y rollouts on-policy verificados.
-Evaluación intermedia y final completa del subconjunto smoke;8PNG+8FIG verificadas.
-Viewer categórico exportado y comparado exactamente con q/PWM del runtime.
-Monitor personalizado de R2023b creado y actualizado en prueba oculta; durante la corrida manual Desktop se mostrará visible. No se afirma haber usado rlTD3Agent Training Progress para este loop.

Regresiones históricas:258/258. Nuevas:36/36. Total:294/294.
Las primeras pruebas detectaron una diferencia de tipo/formato en OutputNames y una máscara que reducía a single los ejemplos analíticos double. Se corrigieron; la matemática conserva el tipo de entrada. La política entrenada del smoke usa single y sus pesos/trazas se conservaron. Se mantuvieron los logs de la primera pasada y de la revisión.

Los ajustes de cierre posteriores al smoke separan el planificador de checkpoints para probar sus fronteras, preservan la ventana, evitan trabajo cuadrático al calcular promedios de100episodios, y guardan updateStats.mat por separado. No cambian la receta de aprendizaje ni los resultados del smoke.

## Ejecución manual

Abrir MATLAB Desktop y pegar:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code'); summary = runE3BCategoricalTraining();
```

El runner crea carpeta única en results/e3b_long/run_timestamp_UUID, registra configuración/split/seed/manifiesto/diary/STARTED y crea redes nuevas. No carga BEST/LAST para inicializar el nuevo PPO. Los checkpoints contienen actor, critic, momentos Adam, contador de updates, RNG, último rollout y snapshot de episodio; se escriben sin sobrescribir checkpoints previos.

AGENT_CHECKPOINT_AVAILABLE=YES. FULL_TRAINING_RESUME_AVAILABLE=NO: no se ha validado restauración exacta de todos los estados transient de Env. No se promete reanudación exacta.

El monitor es trainingProgressMonitor del loop personalizado (reward/promedio, pérdidas actor/critic y validationMSE). Se conserva una referencia de la ventana al finalizar. Los datos no dependen de ella: training_incremental.csv, update_stats.csv, trainingStats.mat y gráficas training_progress.PNG/FIG/PDF/SVG. EpisodeV0 queda registrado como V(s), no se inventa EpisodeQ0. La tabla completa y los logs de updates permanecen disponibles.

Si sólo falla el cierre/evaluación, usar runE3BPostTraining('ruta_de_corrida'); no entrena, regenera estadísticas/figuras y verifica cobertura. No utilizarlo para reanudar optimización.

Conectar el equipo a corriente, evitar suspensión/hibernación, asegurar espacio de disco y no cerrar MATLAB. El bloqueo de pantalla no implica detener el loop mientras Windows continúe activo. No se modificó la configuración de energía.

## Viewer e integridad

exportE3AXViewerTrace reconoce E3BCategoricalActor, conserva el formato q/PWM/step/time/Ts/subject/row/direction/policy/checkpoint/hash y rechaza cap en actores categóricos. q proviene de saved_actor→GloveFreePolicyRuntime→patternCurveCanonical. La ruta TD3 anterior sigue pasando sus pruebas.

Única adaptación de archivo histórico autorizada: exportador; diff en e3b_preparation/authorized_viewer.diff. Otros 1070 archivos protegidos conservan hash. Env/reward/planta y agentes históricos intactos. No se modificó ni importó sandbox. Su futura visualización debe leer q(t), sin DynamicPlantAdapter/S4 ni nueva simulación.

Worktree:C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit.
Rama:experiment/no-glove-paired-reference-td3.
HEAD:165be049eb41fc41254435181c9857fe0f22ed1c.
GIT_REPAIR_ATTEMPTED=NO. PUSH=NO. LONG_TRAINING_STARTED_BY_AI=NO.
