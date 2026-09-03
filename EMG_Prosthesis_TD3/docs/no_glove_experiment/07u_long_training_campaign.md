# ETAPA 7U — campaña larga de 10 000 episodios (auditoría de resultado)

Fecha: 2026-09-03. Corrida auditada:
`Agentes\no_glove_intent_control\stage7u_optional_long_training\2026-09-03_00-49-48-172`
(ejecutada manualmente por el usuario con
`run_no_glove_stage7u_optional_long_training()`, comando dejado listo en el cierre de
la sesión anterior). Depende de `07u_pilot_training.md`.

## 1. Artefactos recuperados

20 checkpoints (`Agent500.mat` … `Agent10000.mat`), 1000 logs de episodio de
entrenamiento muestreados (cada 10), `training_info.mat`
(`rl.train.rlTrainingResult` con `EpisodeReward`/`EpisodeSteps`/`EpisodeQ0` para los
10 000 episodios completos), `checkpoint_comparison.csv` (los 20 checkpoints evaluados
sobre exactamente los mismos 50 episodios deterministas, semilla 4001).

## 2. Clasificación

```text
LONG_TRAINING_RESULT = UNSTABLE
```

No se decide por reward solo. Evidencia combinada:

1. **Reward**: meseta de ~-1.1 durante ≈7500 episodios (601-8000), con dos colapsos
   súbitos que luego se recuperan (media móvil hasta -3.8 hacia el episodio 2100-2300;
   hasta -2.5 hacia el episodio 7800-8000).
2. **EpisodeQ0**: deriva no monótona — se vuelve más negativo durante la meseta
   (-0.27 en ep. 2501-3000 hasta -0.39 en ep. 7001-7500) mientras el reward real se
   mantiene plano, y se recupera después.
3. **Saturación del actor**: en Agent4000 y Agent6000, el 100% de las acciones activas
   (evaluación determinista) tienen `|u_raw|≥0.95`. El actor colapsó a un controlador
   tipo relé, no a control proporcional.
4. **`u_actor_raw` en reposo**: pese a que `motionPermission` bloquea correctamente el
   PWM, la media de `u_raw²` en pasos de reposo sube de ~0.5 a ~0.99 hacia el episodio
   4000 y se mantiene ahí el resto de la campaña.
5. **`actionL2` efectivo**: 3-4× el baseline (Agent200+gate=0.122) en los 20
   checkpoints, sin excepción.
6. **Intervenciones de seguridad**: ~2900-3200 por 50 episodios de test, casi el doble
   del orden de magnitud del baseline.
7. **Único punto perfecto**: `restPwmNonZeroFraction=0` en los 20 checkpoints, sin
   ninguna excepción — el gate externo se sostuvo incluso frente a un actor
   patológicamente saturado.

## 3. Mejor checkpoint

**Agent9000**: menor `actionL2` efectivo (0.340) y menor fracción de saturación
(0.238) de los 20, con `trackingMse` (0.00619) todavía mejor que el baseline. Ningún
checkpoint iguala o supera de forma convincente a Agent200+`motionPermission` en
tracking **y** esfuerzo/seguridad simultáneamente.

## 4. Causa raíz identificada y corrección

`explorationStdDecayRate=1e-4` (heredado de ETAPA 6, calibrado para el horizonte de
200 episodios de Agent200) hace que la exploración llegue a su piso
(`explorationStdMin=0.02`) dentro del primer 1-2% de una campaña de 10 000 episodios,
dejando ~98% del entrenamiento con exploración casi nula. Combinado con la capa de
salida `tanh` del actor, esto es una trampa de saturación conocida en RL continuo.

**Corrección de un solo factor** (`computeNoGloveStage7uExplorationDecayRate.m`, 4
pruebas deterministas): escalar la tasa de decaimiento proporcionalmente al horizonte,
de forma que la exploración termine en el mismo multiplicador relativo que Agent200
experimentó (~0.295×), en vez de colapsar casi de inmediato. Nada más se modifica.

## 5. Validación corta (1000 episodios)

Corrida: `stage7u_exploration_fix_validation/2026-09-03_03-24-39-724`, comparada
contra Agent1000 de la campaña original al mismo número de episodios:

| Métrica (Agent1000) | Original (1e-4) | Con corrección (~2e-5) |
|---|---|---|
| Fracción activa con `|u_raw|≥0.95` | 0.8534 | **0.7824** |
| Media cuadrática `u_raw` (activo) | 0.9508 | **0.8874** |
| Media cuadrática `u_raw` (reposo) | 0.7722 | **0.6051** |
| `trackingMse` | 0.00609 | 0.00610 (sin cambio) |

Mejora real, consistente en las 4 métricas, sin perjudicar el tracking. Modesta a 1000
episodios — esperado, dado que el beneficio se acumula sobre un horizonte más largo.

## 6. Figuras

Reconstruidas sin reentrenar, desde `training_info.mat` + logs muestreados
(`buildNoGloveStage7uTrainingFigures.m`): `training_figures/01`…`10` (reward, media
móvil, Q0, trackingMSE, actionL2, deltaActionL2, saturación, safety, fracción activa,
`u_raw` en reposo). Figuras de test rediseñadas con paneles separados por señal
(`plotNoGloveStage7uEpisode.m`, sin números superpuestos salvo eventos de seguridad).
Insertadas en `docs/latex_report/informe_completo.pdf`.

## 7. Decisión

Rama B del encargo: **no** se recomienda repetir 10 000 episodios con múltiples
semillas todavía. Se identificó la causa raíz, se implementó y validó (corto plazo) la
corrección de un solo factor. La campaña larga corregida queda preparada pero no
autorizada a ejecutarse automáticamente.
