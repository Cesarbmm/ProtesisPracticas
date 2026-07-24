# Paused Motor 2 Training And Ablations

Esta carpeta conserva launchers funcionales de fases previas. No se borran
porque sirven para reproducibilidad, pero ya no son la linea activa.

Motivo de pausa:

- los reentrenamientos TD3 desde cero mejoraron algunas metricas de motor 2,
  pero no pasaron validacion all-motor;
- M4 aparecio plano o con `action-no-motion` en checkpoints nuevos;
- `motorCalibratedQuantized` y la reward ponderada no se promueven;
- `motor2Calibrated` queda solo como variante experimental de evaluacion.
- el sanity extendido solo-M2 queda como referencia historica; el flujo activo
  usa el sanity all-motor de `published/`.

La linea activa esta en `../published/` y debe usar `Agent7250` congelado:

```matlab
run_agent7250_frozen_conversion_evaluation()
run_motor2_only_correction_evaluation()
```

Si se retoma algun launcher de esta carpeta, debe compararse contra
`Agent7250` congelado y pasar `all_motor_final_gate` antes de considerarse
como candidato.
