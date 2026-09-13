# E4_DOCUMENTATION_1M — sólo documentación

> **DOCUMENTATION_ONLY = YES**  
> **SCIENTIFIC_FINAL_MODEL = NO**  
> **SEALED_TEST_REUSE = FORBIDDEN**  
> **MATEO_SANDRA_ALLOWED = NO**

Preregistro: 12 de septiembre de 2026, antes de ejecutar la corrida. Seed nuevo fijo **20261001**. No se ejecutó entrenamiento durante la preparación.

El resultado final sellado sigue siendo FAIL. Esta corrida documenta una curva más larga y no cambia FINAL_AGENT (500k, SHA256 `2aa39fdf166c62fb6da057f1ddecb6455fbaa142f476718dd4e2725dfde08c90`). No selecciona BEST, no reemplaza el modelo científico y no evalúa sujetos sellados.

La receta procede de `e4Config("long")`: PPO multicategórico factorizado E3B/E4, entrada markov52, FC64/ReLU → FC64/ReLU → cuatro cabezas de 15 categorías y critic feed-forward histórico. Se reutilizan `e3bNetworks`, `e3bSample`, `e3bUpdate` y `E3BTrainingEnv`. Se mantienen PPO/GAE/Adam, reward, teacher original, WMoos, Ts=.2, acciones y planta canónica. No GRL ni recurrencia ni normalización nueva.

TRAIN contiene exactamente BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN y KHAROL. No existe VALIDATION. El loader histórico E4 rechaza sujetos sellados; la configuración completa se valida antes de cargar datos.

Presupuesto: **1.000.000 agent steps**, con checkpoints exactos en **250000, 500000, 750000 y 1000000**. Guardar un checkpoint intermedio no fuerza una actualización PPO: los rollouts siguen siendo de 1024 pasos como en E4, con la truncación final habitual. Se conserva el buffer parcial para auditoría. Un checkpoint disponible no equivale a reanudación exacta del proceso; `fullTrainingResumeAvailable=false`.

Salida única: `matlab_code/results/e4_documentation_1m/run_<timestamp>_<UUID>/`. Desde el inicio: config MAT/JSON, split, seed, manifiesto de planta, diario y STARTED. Durante la corrida: CSV incremental, optimizadores y checkpoints sin sobrescritura. Al terminar: trainingStats MAT/CSV y figura reproducible PNG/FIG/PDF/SVG. No se crea `FINAL_AGENT.mat` ni se escribe en `e4_final_development`.

El monitor es `trainingProgressMonitor`, apropiado al loop PPO personalizado; no se presenta como el monitor de un rlTD3Agent. V(s inicial) se registra como EpisodeV0 y no se inventa EpisodeQ0. La ventana permanece disponible al terminar. No hay evaluación del test final ni selección posterior automática.

Dependencias locales: datasets DEVELOPMENT y el archivo de regresión E2F usado por `e4LoadData` (no versionado por tamaño). Este worktree tiene esos fixtures; una copia nueva necesita recuperarlos del archivo autorizado. Un archivo ausente produce un error explícito y nunca habilita sujetos sellados como sustitución.

## Comandos manuales

Pruebas, sin iniciar la corrida:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_final_publish\EMG_Prosthesis_TD3\matlab_code');
results = runtests('tests/paired_reference/testE4Documentation1M.m');
assert(all([results.Passed]));
```

Sólo cuando el usuario decida iniciar, en MATLAB Desktop:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_final_publish\EMG_Prosthesis_TD3\matlab_code');
summary = runE4Documentation1M();
```

Conectar el equipo a corriente, evitar suspensión/hibernación, reservar espacio de disco y mantener MATLAB abierto. No se cambian automáticamente las opciones de energía.

## Validación de preparación

12/12 pruebas específicas pasaron en MATLAB R2023b: redes idénticas bajo igual semilla, receta, sujetos, presupuesto, checkpoints sin cambio de cadencia PPO, rechazo de configuración alterada/sujetos sellados, acciones legales e integridad del runner científico. [Resultados por prueba](../../EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/publication_results/documentation_tests.csv). Se ejecutaron únicamente tests, sin smoke de entrenamiento ni corrida de 1M.
