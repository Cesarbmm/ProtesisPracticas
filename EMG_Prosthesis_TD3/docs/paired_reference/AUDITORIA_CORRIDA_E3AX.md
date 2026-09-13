# Auditoría de corrida E3A-X y cierre visible

Corrida: `run_20260908_141321_916_6ebf347b`, bajo
`matlab_code/results/e3ax_long/`. Entrenamiento manual del usuario terminado:
20000 episodios, 285641 pasos, seed 20260908, ocho checkpoints programados.
La auditoría no ejecutó entrenamiento nuevo ni modificó sus checkpoints.

## Qué existía al recibir el trabajo

Los archivos y diary demuestran que la evaluación ya había terminado a las
15:50 del 8 de septiembre. BEST es Episode10000, seleccionado exclusivamente
por reward macro VALIDATION; LAST es Episode20000. Había 200 PNG y 200 FIG
para cada checkpoint, repartidos en 140 TRAIN y 60 VALIDATION. No faltaba ningún
episodio, pero las carpetas eran profundas y el mensaje final no ofrecía un
test comportamental claro ni acceso directo a las figuras.

Ahora la raíz de la corrida contiene **TEST_COMPORTAMENTAL.html**, una galería
con filtro por conjunto, checkpoint y sujeto, métricas y enlace PNG/FIG de
cada episodio; también TEST_COMPORTAMENTAL.md/json y un índice CSV. Se han
verificado todos los PNG/FIG existentes sin reemplazarlos innecesariamente.

## Qué significa test en esta entrega

- **Test comportamental:** inferencia determinista del actor congelado sobre
  DEVELOPMENT, sin glove en GloveFreePolicyRuntime. Teacher original sólo
  para métricas posteriores en el horizonte común. 140 TRAIN y 60 VALIDATION
  por checkpoint. P2 y Oracle son comparadores privilegiados; Agent7250 es
  diagnóstico histórico.
- **Regresiones/unitarios:** pruebas de código y artefactos, separadas de los
  episodios de política. No se dibuja una figura por prueba unitaria.
- **Test final:** MATEO/SANDRA permanecen sellados. No se ejecutó.

## Verificación independiente

Se repitieron los **400 episodios completos** de BEST/LAST usando EMG y los
actores guardados. Máximas diferencias de estado, acción raw, acción efectiva,
PWM, q y reward: **0**. Las referencias originales y los horizontes coinciden.
Se recalcularon métricas por episodio y motor; diferencia máxima con CSV:
3.637978807091713e-11 (tolerancia 1e-9 para campos que incluyen encoder counts;
reward/estado/acción preservan sus exigencias anteriores).

Evidencia reproducible en `matlab_code/analysis/paired_reference/e3ax_run_audit/`:
`deterministic_replay.csv`, `replay_summary.json`, manifiestos de integridad,
resultados de pruebas y resumen de auditoría. El PASS de auditoría significa
reproducción de resultados, no éxito de control ni validación física del reward.

## Resultado medido en VALIDATION

| Política | MSE | Reward medio | Ciclos finales | Retrocesos M3 |
|---|---:|---:|---:|---:|
| ZERO | 0.104020255 | -0.104020255 | 0 | 0 |
| Agent7250 diagnóstico | 0.051597962 | -0.064198631 | 0 | 82 |
| P2 privilegiado | 0.028083004 | -0.034422684 | 0 | 0 |
| Oracle H5 privilegiado | 0.019681292 | -0.021512320 | 0 | 0 |
| BEST TD3, episodio10000 | 0.059980845 | -0.075616210 | 0 | 134 |
| LAST TD3, episodio20000 | 0.065642221 | -0.079472400 | 0 | 81 |

BEST reduce MSE un **42.34% frente a ZERO**, pero tiene un MSE **16.25% mayor
que Agent7250** en esta evaluación con planta canónica. Tampoco supera a P2 ni
Oracle privilegiados. LAST empeora MSE VALIDATION un 9.44% frente a BEST;
mantener BEST10000 sigue la selección congelada, sin elegir por TRAIN.

BEST tiene saturación macro VALIDATION 56.77%, PWM alto 86.01%, flat_response
15.00% y action_no_motion macro 68.44%. En los 200 episodios, MSE BEST es
0.0514412525322879, reward -0.0657460666206639 y aparecen **526 retrocesos M3**;
LAST tiene 412. No hay ciclos finales detectados en ambos, lo cual no implica
estabilidad universal. No se alteran reward, cuantizador o planta para rescatar
el resultado. La referencia física sigue NO VALIDADA y no se autoriza hardware.

## Mejora del runner

1. Distingue TRAINING_COMPLETED de POST_TRAINING_STATUS. El fin de train no se
   presenta como test terminado.
2. Anuncia TEST COMPORTAMENTAL, imprime progreso de inferencia y de figuras,
   y guarda métricas/trazas antes de exportar imágenes.
3. Antes de marcar COMPLETE verifica cobertura exacta por episodio y presencia
   de PNG/FIG legibles. Después publica HTML/Markdown/JSON y un enlace visible
   en MATLAB Desktop. El monitor estándar no se cierra.
4. Si el cierre falla, registra FAILED con el error y deja un comando de
   recuperación sin entrenamiento. `runE3AXPostTraining(carpeta)` reutiliza las
   evaluaciones existentes y reconstruye figuras ausentes desde las trazas;
   si falta la evaluación, la calcula usando checkpoints guardados.

Para abrir directamente esta entrega desde MATLAB:

```matlab
web('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e3ax_long\run_20260908_141321_916_6ebf347b\TEST_COMPORTAMENTAL.html','-browser');
```

Para recuperar/publicar el cierre sin volver a entrenar:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code');
report = runE3AXPostTraining('C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit\EMG_Prosthesis_TD3\matlab_code\results\e3ax_long\run_20260908_141321_916_6ebf347b');
```

Todo permanece local en la rama científica. No se reparó Git, no se hizo push,
no se cambió de rama y no se accedió al sandbox.
