# Exportación pasiva de trazas canónicas

Cuatro ejemplos verificados están en viewer/BEST_OFF, BEST_CAP192, LAST_OFF y LAST_CAP192, cada uno con viewer_trace.mat. Todos corresponden a BLANCA fila1 cierre, elegido antes de medir.

Ejemplo real, desde MATLAB Desktop situado en matlab_code (usar un archivo de salida nuevo; el exportador no sobrescribe):

```matlab
trace = exportE3AXViewerTrace(fullfile(pwd,'results','e3ax_long','run_20260908_141321_916_6ebf347b','checkpoints','AgentEpisode010000.mat'), 'BLANCA', 1, 'closing', fullfile(pwd,'results','viewer_best_original','viewer_trace.mat'));
```

Para exportar el contrafactual, añadir `cap192=true`. No se entrena ni se modifica el checkpoint. El helper exige un episodio development de la lista congelada y rechaza MATEO/SANDRA antes de cargar archivos del sujeto. Carga sólo saved_actor del checkpoint y emgs del dataset; no carga la variable gloves. Obtiene q inicial de la traza histórica del episodio.

Campos públicos del MAT:

| Campo | Contrato |
|---|---|
| q | N+1 ×4, encoder counts, primera fila = estado inicial |
| PWM | N ×4, comando firmado aplicado; PWM(k,:) transforma q(k,:) en q(k+1,:) |
| step / commandStep | 0..N para estados /1..N para comandos |
| Ts / time | .2 segundos /tiempos de estados |
| subject,row,direction | Identificador development exacto |
| policy,checkpoint,checkpointSHA256 | Actor congelado y trazabilidad |
| plantManifest | Manifiesto E0P de patternCurveCanonical |
| desiredRaw,commandRaw,effectiveAction,state | Acción antes/después de cap, PWM/255 y markov52 realmente usado |
| termination | EMG_ONLY; incluye cola posterior al horizonte de métricas teacher |
| source,teacherLoaded,trainingExecuted | Procedencia y ausencia de teacher/training en el exportador |

Futuro contrato de HandKinematicViewer, únicamente cuando se autorice reabrirlo: leer estas posiciones directamente, sin simular de nuevo la planta y sin DynamicPlantAdapter/S4. No hay cambios en sandbox. Este exportador sirve para checkpoints E3A-X con saved_actor y config.mat de su corrida. P2/Oracle tienen procedencia privilegiada; Agent7250 requiere su carga histórica correspondiente. No se presentan como exportaciones saved_actor ya implementadas aquí.
