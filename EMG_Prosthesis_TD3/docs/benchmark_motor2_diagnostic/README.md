# Benchmark Motor 2 Diagnostic

Resumen de la fase `Benchmark TD3 seeded retrain + motor 2 diagnostic`.
El objetivo es decidir si el problema del motor 2 viene de entrenamiento,
seleccion de checkpoint, reward, simulador o mapeo antes de retomar
Residual Lift o stop-band.

## Campana base analizada

Fuente local:

```text
Agentes/benchmark_td3_seeded_retrain_motor2_diagnostic/26-05-27_23-44-39/
```

Configuracion:

- seeds: `[11 22 33 44 55]`
- training episodes: `12000` por seed
- final test: `50` episodios
- GPU: RTX 5070 Laptop GPU con CUDA Forward Compatibility
- reward: `trackingMseActionRateReward`
- estado: `markov52`

Resultado:

- agregado: `Rejected`
- `ConditionA = 0`
- `ConditionB = 0`
- `Rejected = 5`
- mejor seed global: seed 22, episodio 6900

Metricas de campana:

- `trackingMSE mean = 0.053591`
- `trackingMAE mean = 0.181093`
- `actionL2 mean = 0.737733`
- `saturationFraction mean = 0.573518`
- `deltaActionL2 mean = 0.349939`

Motor 2:

- `trackingMSE_motor2 mean = 0.045047`
- `responseRange_motor2 mean = 0.140268`
- `motor2_flat_response flags = 3`
- `motor2_action_no_motion flags = 3`
- `motor2_tracking_outlier flags = 0`

Comparacion contra `Agent7250` en la evaluacion reproducida:

- `Agent7250 trackingMSE = 0.043045`
- `Agent7250 saturationFraction = 0.392086`
- `Agent7250 trackingMSE_motor2 = 0.043548`
- `Agent7250 responseRange_motor2 = 0.108838`

## Informe principal

Ver `motor2_ablation_report.md` para la lectura completa de sanity
extendido, permutation check y ablation corta.

## Motor response calibration before reward tuning

La reward ponderada redujo `trackingMSE_motor2`, pero no aumento
`responseRange_motor2` ni redujo de forma robusta los flags
`motor2_flat_response` y `motor2_action_no_motion`. Por eso la siguiente
fase revisa primero la cadena simulador -> `encoder2Flex` ->
`flexJoined_scale` antes de seguir ajustando reward.

El launcher `run_motor_response_conversion_diagnostic` separa tres rangos:

- encoder del simulador;
- flex crudo despues de `encoder2Flex`;
- flex normalizado despues de `flexJoined_scale`.

La variante `motorCalibratedQuantized` es experimental y solo de
simulacion. Usa niveles PWM por motor para evitar que el motor 2 quede
atrapado en niveles bajos que mueven encoder pero no producen flex util. No
reemplaza `baselineQuantized` ni se promueve a hardware.

Comandos desde `matlab_code/`:

```matlab
results = run_motor_response_conversion_diagnostic();
```

```matlab
results = run_motor2_simulation_sanity_check_extended(struct( ...
    'initialMode','all'));
```

```matlab
results = run_motor2_calibrated_action_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

Criterio para promover la calibracion: debe bajar flags de motor 2, subir
`responseRange_motor2`, no empeorar `trackingMSE_motor2`, no empeorar
tracking global mas de 10% y no subir saturacion mas de 15%.

Resultado del 2026-06-04:

- El aplanamiento de motor 2 en niveles bajos aparece despues del encoder.
  La accion `0.25` movio el encoder `3598`, pero `encoder2FlexRange` y
  `normalizedFlexRange` quedaron en `0`. A partir de `0.50`, motor 2 ya
  produjo flex normalizado (`0.175801`).
- Las acciones negativas desde `home` siguen sin ser concluyentes. Desde
  `mid`, motor 2 tuvo `negativeMeanRangeFlex=0.280059`; desde `closed`,
  tuvo `negativeMeanRangeFlex=0.560117`.
- En la ablation corta, `motorCalibratedQuantized` bajo `trackingMSE`
  global de `0.099748` a `0.092527`, bajo `trackingMSE_motor2` de
  `0.112913` a `0.070589` y bajo `saturationFraction` de `0.169857` a
  `0.053934`.
- No se promovio la calibracion como solucion final, porque
  `responseRange_motor2` no subio (`0.170200` baseline vs `0.167690`
  calibrada) y quedo `motor2_action_no_motion=1/2`.

PDF de esta etapa: `motor2_calibration_report.pdf`.

## Motor 2 conversion fix attempt

Despues de ver que la accion calibrada y la reward ponderada no resolvieron
por completo los flags, se reviso la conversion `encoder2Flex` antes de
seguir ajustando reward. La hipotesis fue que motor 2 tiene una zona baja
que mueve encoder, pero queda debajo de `gap.idx=3650`, por lo que
`encoder2Flex` entrega flex plano.

Se agrego una variante experimental:

- `encoder2FlexVariant = "baseline"`: comportamiento oficial.
- `encoder2FlexVariant = "motor2Calibrated"`: baja solo el umbral `gap` de
  motor 2. El candidato experimental actual usa
  `motor2Encoder2FlexGapOffset=-64`.

Esto no cambia el default y no se promueve a hardware.

Diagnostico sin entrenamiento:

```matlab
results = run_motor2_conversion_fix_diagnostic(struct( ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"], ...
    'initialMode', 'all'));
```

Resultado del diagnostico:

| Motor | Range baseline | Range calibrado | Cambio | Regresion |
| --- | ---: | ---: | ---: | --- |
| M1 | 0.210989 | 0.210989 | 0.000% | no |
| M2 | 0.226875 | 0.227364 | 0.216% | no |
| M3 | 0.294546 | 0.294546 | 0.000% | no |
| M4 | 0.209136 | 0.209136 | 0.000% | no |

En home, motor 2 con accion `0.25` paso de
`encoder2FlexRange=0.000000` a `0.005336` en flex normalizado. No se
detecto inversion de signo ni regresion en M1, M3 o M4. Como correccion de
conversion, la variante queda aceptada solo para diagnostico experimental.

Ablation corta:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'useGpu', true));
```

| Config | MSE | MSE M2 | Range M2 | Saturacion | Flat | No-motion | Aceptada |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline + conversion baseline | 0.099748 | 0.112913 | 0.170200 | 0.169857 | 1 | 0 | no |
| baseline + conversion calibrada | 0.102556 | 0.098362 | 0.137716 | 0.149650 | 2 | 1 | no |
| accion calibrada + conversion baseline | 0.092527 | 0.070589 | 0.167690 | 0.053934 | 1 | 1 | no |
| accion calibrada + conversion calibrada | 0.092789 | 0.095213 | 0.169227 | 0.004167 | 1 | 0 | no |

La conversion calibrada bajo la saturacion y redujo algunos errores, pero no
subio de forma clara `responseRange_motor2` ni elimino los flags. Por eso no
se promueve como default. La decision actual es conservarla como variante
experimental y revisar limites/mapeo con mas evidencia antes de volver a
reward, residual o stop-band.

Informe: `motor2_conversion_fix_report.md`.

### Barrido de limites encoder2Flex

Despues del primer intento con `gapOffset=-128`, se hizo un barrido sin
entrenamiento para no escoger el offset a mano:

```matlab
results = run_motor2_encoder2flex_limit_sweep_diagnostic(struct( ...
    'gapOffsets', [0 -32 -64 -96 -128 -192 -256], ...
    'breakOffsets', 0, ...
    'initialMode', 'all'));
```

Resultado:

| Candidato | gap.idx exp. | Range M2 | Low action M2 | Max deviation | Aceptado |
| --- | ---: | ---: | ---: | ---: | --- |
| baseline | 3650 | 0.226875 | 0.000000 | 0.000000 | no |
| gapOffset -32 | 3618 | 0.227048 | 0.000000 | 0.001560 | si |
| gapOffset -64 | 3586 | 0.227189 | 0.000849 | 0.003108 | si |
| gapOffset -128 | 3522 | 0.227364 | 0.005336 | 0.006166 | si |

El candidato seleccionado fue `gapOffset=-64`, porque es el mas
conservador que recupera una salida util para la accion baja `0.25` desde
`home`. Se actualizo el default experimental de `motor2Calibrated` a `-64`.
El default oficial sigue siendo `encoder2FlexVariant="baseline"`.

### Compuerta final experimental de motor 2

La ablation con `gapOffset=-64` no paso aceptacion. La lectura fue que
algunos checkpoints auditados tenian motor 2 razonable, pero el test final
seleccionado podia caer en `motor2_flat_response` o
`motor2_action_no_motion`. Por eso se agrego
`selectionMode="motor2_final_gate"`.

Este modo no cambia el benchmark oficial. Solo en flujos experimentales:

- rankea por flags, `responseRange_motor2`, `trackingMSE_motor2`, tracking
  global, saturacion y esfuerzo;
- prueba hasta `motor2FinalGateMaxCandidates` candidatos finales;
- guarda `motor2_final_gate_attempts.csv`;
- acepta el primer candidato que mantenga rango y no tenga flags de motor 2;
- registra `globalOk` y `saturationOk`, pero no los usa como bloqueo duro;
- si ninguno pasa, usa fallback al mejor intento y lo deja en
  `selectionReason`.

Comando de validacion:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 500, ...
    'finalTestEpisodes', 5, ...
    'auditTopK', 8, ...
    'selectionMode', 'motor2_final_gate', ...
    'useGpu', true));
```

Smoke aceptado del 2026-06-18:

```text
Agentes/motor2_conversion_fix_ablation/26-06-18_02-49-24/
```

Se probo `motor2Encoder2FlexGapOffset=-256` con
`selectionMode="motor2_final_gate"`. La configuracion que paso ese smoke
centrado en motor 2 fue `baselineQuantized + motor2Calibrated`:

| Config | MSE | MSE M2 | Range M2 | Saturacion | Flat | No-motion | Aceptada |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| baseline + conversion baseline | 0.099748 | 0.112913 | 0.170200 | 0.169857 | 1 | 0 | no |
| baseline + conversion motor2Calibrated | 0.092616 | 0.078885 | 0.181432 | 0.133639 | 0 | 0 | si |
| accion calibrada + conversion baseline | 0.092527 | 0.070589 | 0.167690 | 0.053934 | 1 | 1 | no |
| accion calibrada + conversion motor2Calibrated | 0.075777 | 0.078055 | 0.172212 | 0.108406 | 1 | 1 | no |

La lectura fue revocada despues por la validacion all-motor: el smoke corto
mejoro motor 2, pero no basta para aceptar un fix global. No cambia el
default oficial y no justifica por si solo una campana larga.

### Validacion all-motor con 1500 episodios

Se reviso despues una corrida mediana:

```text
Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57/
```

Configuracion:

- seeds `[11 22 55]`
- `trainingEpisodes=1500`
- `finalTestEpisodes=20`
- `motor2Encoder2FlexGapOffset=-256`
- selector original `motor2_final_gate`

Se genero la tabla all-motor en:

```text
summary/all_motor_regression_validation_by_seed.csv
summary/all_motor_regression_validation_summary.csv
summary/baseline_vs_motor2_calibrated_all_motor_comparison.csv
summary/all_motor_regression_validation.md
```

Comparacion `baseline + baseline` contra `baseline + motor2Calibrated`:

| Motor | Baseline MSE | Cal MSE | Baseline range | Cal range | Baseline sat | Cal sat | Flat B/C | No-motion B/C | Regression |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| M1 | 0.049273 | 0.046642 | 0.158289 | 0.184793 | 0.110094 | 0.410934 | 2/1 | 1/1 | si |
| M2 | 0.087531 | 0.071070 | 0.155809 | 0.160425 | 0.109722 | 0.105740 | 1/1 | 0/0 | no |
| M3 | 0.118077 | 0.120305 | 0.428794 | 0.441262 | 0.137444 | 0.090938 | 0/0 | 0/0 | no |
| M4 | 0.073825 | 0.070127 | 0.149345 | 0.151670 | 0.309727 | 0.415941 | 2/3 | 2/3 | si |

Conclusion: motor 2 mejora, pero la variante no queda aceptada a nivel
all-motor. Motor 4 no muestra regresion de MSE/rango promedio; si muestra
regresion por saturacion y por conteo de flags `flat` y
`action-no-motion`. Visualmente, seed 55 mantiene motor 4 casi plano con
acciones altas/saturadas. Esto obliga a cambiar la direccion a:
`Motor 2 fix + all-motor regression validation`.

Se agrego `selectionMode="all_motor_final_gate"` para no aceptar una
variante solo porque mejora motor 2. El modo nuevo exige flags/rango
aceptables en los cuatro motores antes de pasar el checkpoint final.

### All-motor actuation and regression audit

La fase actual ya no es solo `motor 2 fix`. La direccion correcta es:
`Motor 2 fix + all-motor regression validation`.

La nueva auditoria agrega:

- `high_action_flat_response_motorK`: bandera por motor cuando hay accion
  alta o saturacion alta, pero la respuesta queda plana con una referencia
  que si se mueve.
- revision visual comparable por seed/configuracion con metadata en nombre
  y titulo: seed, episodio, `actionInterfaceVariant`,
  `encoder2FlexVariant`, `selectionMode`, checkpoint y carpeta de corrida.
- sanity general `run_all_motor_actuation_sanity_check_extended`, que prueba
  M1-M4 desde `home`, `mid` y `closed` con conversion baseline y
  `motor2Calibrated`.
- comparacion all-motor contra `Agent7250`, para revisar si M4 ya fallaba
  en el benchmark historico o si aparece por entrenamiento/selector.

Comandos principales:

```matlab
results = run_all_motor_actuation_sanity_check_extended(struct( ...
    'initialMode', 'all', ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"]));
```

```matlab
results = run_all_motor_visual_comparison_from_run(struct( ...
    'runRoot', 'Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57', ...
    'configsToCompare', ["baseline_quantized_conversion_baseline", ...
                         "baseline_quantized_conversion_motor2_calibrated"], ...
    'seeds', [11 22 55]));
```

```matlab
results = run_compare_against_canonical_benchmark_all_motor(struct( ...
    'runRoot', 'Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57', ...
    'finalTestEpisodes', 20));
```

El selector `all_motor_final_gate` queda como gate estricto. Si ningun
checkpoint pasa M1-M4, selecciona el menos malo solo para diagnostico con
`selectionReason="fallback_diagnostic_no_checkpoint_passed_all_motor_gate"`
y `finalGateAccepted=false`.

Resultados generados el `2026-06-19`:

- sanity all-motor:
  `Agentes/all_motor_actuation_sanity_check_extended/26-06-19_00-46-51/`
- visual review:
  `Agentes/motor2_conversion_fix_ablation/26-06-18_09-04-57/figures/all_motor_visual_review/`
- comparacion contra Agent7250:
  `Agentes/canonical_benchmark_all_motor_comparison/26-06-19_00-48-14/`

Lectura nueva:

- M4 tiene zona muerta y asimetria propia, pero el sanity all-motor da el
  mismo resultado para `baseline` y `motor2Calibrated`. La conversion local
  de motor 2 no cambia directamente la respuesta controlada de M4.
- Agent7250 no dispara flags en M4 en la comparacion de 20 episodios:
  `trackingMSE_motor4=0.030795`, `responseRange_motor4=0.198918`,
  `saturationFraction_motor4=0.278977`, flags M4 `0/0/0`.
- Los nuevos checkpoints TD3 si muestran M4 plano en varias seeds. En
  `baseline + motor2Calibrated`, seeds 22 y 55 activan
  `high_action_flat_response_motor4`.

Conclusion operativa: el problema de M4 parece venir mas del
entrenamiento/selector/checkpoint que de la variante `motor2Calibrated`
directamente. Aun asi, la variante queda rechazada porque el sistema final
debe pasar M1-M4.

### Validacion corta all-motor del 2026-06-22

Se ejecuto:

```matlab
results = run_motor2_conversion_fix_ablation(struct( ...
    'seeds', [11 55], ...
    'trainingEpisodes', 300, ...
    'finalTestEpisodes', 5, ...
    'auditTopK', 4, ...
    'selectionMode', 'all_motor_final_gate', ...
    'motor2Encoder2FlexGapOffset', -256, ...
    'useGpu', true));
```

Salida:

```text
Agentes/motor2_conversion_fix_ablation/26-06-22_09-21-51/
```

Comparacion principal `baseline + baseline` contra
`baseline + motor2Calibrated`:

| Motor | MSE baseline | MSE cal | Range baseline | Range cal | Sat baseline | Sat cal | Flat B/C | No-motion B/C | High-action-flat B/C | Regresion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| M1 | 0.066164 | 0.080685 | 0.142948 | 0.152240 | 0.004167 | 0.004167 | 1/1 | 1/1 | 0/0 | si |
| M2 | 0.141460 | 0.100132 | 0.130941 | 0.169585 | 0.020833 | 0.016667 | 2/0 | 0/0 | 0/0 | no |
| M3 | 0.101131 | 0.102842 | 0.370884 | 0.387618 | 0.000000 | 0.000000 | 0/0 | 0/0 | 0/0 | no |
| M4 | 0.112090 | 0.112090 | 0.112263 | 0.112263 | 0.369231 | 0.000000 | 2/2 | 2/2 | 1/0 | no |

Mejoras observadas:

- M2 mejora en MSE, rango y flags.
- Saturacion global baja de `0.100641` a `0.006250`.
- M4 elimina `high_action_flat`, pero sigue plano por `flat` y
  `action-no-motion`.

No se acepta la variante:

- `acceptedConversion=0` para todas las configuraciones.
- El gate estricto no encontro checkpoint limpio M1-M4.
- Todas las seeds usaron fallback:
  `fallback_diagnostic_no_checkpoint_passed_all_motor_gate`.

Figuras curadas:

- `figures/all_motor_review/conversion_fix_20260622_motor2_summary.png`
- `figures/all_motor_review/conversion_fix_20260622_all_motor_summary.png`

### Frozen Agent7250 + motor 2 isolated correction

Se confirmo que las campanas malas entrenaban TD3 desde cero:
`newTraining=true` crea un agente nuevo en `trainInterface`, y
`run_benchmark_td3_seeded_retrain_motor2_diagnostic` usaba `Agent7250`
como benchmark historico, no como politica congelada. La degradacion de M4
aparecio en checkpoints nuevos, no en la evaluacion congelada de
`Agent7250`.

La evaluacion final de esta fase se hizo sin aprendizaje y con 50 episodios:

```matlab
resultsFrozen = run_agent7250_frozen_conversion_evaluation(struct( ...
    'gapOffsets', [0 -64 -128 -256], ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

Salida:

```text
Agentes/agent7250_frozen_conversion_evaluation/26-06-23_09-38-15/
```

| Config | MSE | MSE M2 | Range M2 | M2 flags | MSE M4 | Range M4 | M4 flags | Aceptada | Motivo |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Agent7250 baseline | 0.037229 | 0.042474 | 0.109618 | 3 | 0.026250 | 0.231700 | 0 | no | baseline_reference |
| Agent7250 + motor2Calibrated 0 | 0.037229 | 0.042474 | 0.109618 | 3 | 0.026250 | 0.231700 | 0 | no | motor2_acceptance_failed |
| Agent7250 + motor2Calibrated -64 | 0.037113 | 0.041993 | 0.110996 | 3 | 0.026250 | 0.231700 | 0 | no | m2_metrics_improved_but_flags_remain |
| Agent7250 + motor2Calibrated -128 | 0.037003 | 0.041534 | 0.112352 | 3 | 0.026250 | 0.231700 | 0 | no | m2_metrics_improved_but_flags_remain |
| Agent7250 + motor2Calibrated -256 | 0.036800 | 0.040681 | 0.115000 | 3 | 0.026250 | 0.231700 | 0 | no | m2_metrics_improved_but_flags_remain |

La conversion `motor2Calibrated` mejora M2 en error y rango sin degradar M4
cuando `Agent7250` queda congelado. Aun asi, no se acepta porque conserva
3 flags en M2. La regla final no permite llamar aceptada a una variante que
mejora metricas pero mantiene flags.

Tambien se probo una correccion heuristica aislada de motor 2:

```matlab
results = run_motor2_only_correction_evaluation(struct( ...
    'mode', 'heuristic', ...
    'gapOffset', -256, ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

Salida:

```text
Agentes/agent7250_motor2_only_correction_evaluation/26-06-23_09-28-45/
```

| Config | MSE | MSE M2 | Range M2 | M2 flags | MSE M4 | Range M4 | M4 flags | non-M2 delta | Aceptada | Motivo |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Agent7250 baseline | 0.037229 | 0.042474 | 0.109618 | 3 | 0.026250 | 0.231700 | 0 | 0 | no | baseline_reference |
| Agent7250 + motor2Calibrated -256 | 0.036800 | 0.040681 | 0.115000 | 3 | 0.026250 | 0.231700 | 0 | 0 | no | m2_metrics_improved_but_flags_remain |
| Agent7250 + M2 heuristic | 0.037127 | 0.042015 | 0.110570 | 3 | 0.025986 | 0.231700 | 0 | 0 | no | m2_metrics_improved_but_flags_remain |
| Agent7250 + M2 heuristic + motor2Calibrated -256 | 0.036692 | 0.040224 | 0.115923 | 3 | 0.025986 | 0.231700 | 0 | 0 | no | m2_metrics_improved_but_flags_remain |

La correccion M2-only respeta la restriccion central:
`maxNonMotor2ActionDelta=0`. No modifica las acciones de M1, M3 ni M4.
Sin embargo, tambien queda rechazada porque M2 mejora en MSE/rango pero
conserva flags. La decision final es mantener la linea como experimento
congelado de simulacion, no promover defaults y no volver a entrenar TD3
desde cero hasta resolver los flags de M2.

Figuras curadas nuevas:

- `figures/frozen_agent7250_final/agent7250_frozen_all_motor_comparison_20260623_episode50.png`
- `figures/frozen_agent7250_final/agent7250_frozen_motor4_detail_20260623_episode50.png`
- `figures/frozen_agent7250_final/agent7250_motor2_only_correction_all_motor_comparison_20260623_episode50.png`
- `figures/frozen_agent7250_final/agent7250_motor2_only_correction_motor2_detail_20260623_episode50.png`
- `figures/frozen_agent7250_final/agent7250_m2only_heuristic_motor2Calibrated_gap_neg256_episode50_visual_test_20260623.png`

PDF actualizado de cierre:

- `motor2_calibration_report_frozen_agent7250_v5.pdf`
- `motor2_calibration_report_flag_forensic_v6.pdf`

### Motor 2 flag forensic audit

La siguiente revision no entreno nada. Se evaluo `Agent7250` congelado en
cuatro configuraciones para explicar por que M2 mejora en metricas pero
mantiene flags:

```matlab
results = run_motor2_flag_forensic_audit(struct( ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

Salida revisada:

```text
Agentes/motor2_flag_forensic_audit/26-06-23_12-40-46/
```

| Config | Total flags M2 | Episodios con flags | Flat | No-motion | High-action-flat | Falsos positivos | Delta no-M2 | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Agent7250 baseline | 81 | 27 | 27 | 27 | 27 | 0 | 0 | rejected |
| Agent7250 + motor2Calibrated -256 | 78 | 26 | 26 | 26 | 26 | 0 | 0 | rejected |
| Agent7250 + M2 heuristic | 81 | 27 | 27 | 27 | 27 | 0 | 0 | rejected |
| Agent7250 + M2 heuristic + motor2Calibrated -256 | 78 | 26 | 26 | 26 | 26 | 0 | 0 | rejected |

Los flags no parecen ser falsos positivos bajo la regla actual:
`possibleFalsePositiveCount=0` para todas las configuraciones. En los
episodios marcados, el target de M2 tiene rango claro, mientras la respuesta
queda muy baja. Por ejemplo, en baseline el promedio de episodios con flag
fue `targetRange_M2=0.475309`, `responseRange_M2=0.019729` y
`actionRange_M2=0.097316`. Con `M2 heuristic + motor2Calibrated -256` el
promedio queda en `targetRange_M2=0.469810`, `responseRange_M2=0.014281` y
`actionRange_M2=0.150830`.

La sensibilidad de thresholds tampoco elimina el problema: con umbrales
relajados quedan `25` episodios con flags por configuracion, y con umbral
de respuesta estricto suben a `40-43`. Por eso no conviene solo relajar
thresholds. La correccion aislada si queda validada en integridad:
`maxNonMotor2ActionDelta=0` y M1/M3/M4 no aumentan flags frente a baseline,
pero el candidato sigue rechazado porque M2 conserva demasiados episodios
planos.

Figuras generadas por MATLAB:

- carpeta completa: `figures/frozen_agent7250_final/motor2_flag_forensic/`
- ejemplo baseline: `figures/frozen_agent7250_final/motor2_flag_forensic/a7250_base_episode_002_flags_flat_nomotion_highflat.png`
- ejemplo M2-only + conversion: `figures/frozen_agent7250_final/motor2_flag_forensic/a7250_m2heur_m2cal256_episode_002_flags_flat_nomotion_highflat.png`

Conclusion: `rejected`. `Agent7250` congelado debe mantenerse como base; la
correccion aislada de M2 es segura para no tocar M1/M3/M4, pero todavia no
resuelve el modo plano de M2. No se recomienda una campana larga ni cambios
de reward antes de explicar esos episodios.

## Figuras seleccionadas

- Falla / diagnostico seed 11: `figures/seed_011_motor_diagnostic.png`
- Reaccion mas clara seed 55: `figures/seed_055_motor_diagnostic.png`
- Resumen motor 2 campana base: `figures/motor2_diagnostic_summary.png`
- Sanity extendido de ganancia: `figures/motor_response_gain_matrix.png`
- Ablation motor 2: `figures/ablation_motor2_summary.png`
- Calibracion encoder-flex: `figures/calibration_motor_response_conversion_gain_matrix.png`
- Ablation calibrada: `figures/calibration_ablation_motor2.png`
- Training calibrado seed 11: `figures/calibration_motor_calibrated_seed011_training_progress.png`
- Test visual calibrado seed 11: `figures/calibration_motor_calibrated_seed011_visual_test_episode5.png`
- Conversion before/after: `figures/conversion_fix_before_after_matrix.png`
- Deadzone motor 2 before/after: `figures/conversion_fix_motor2_deadzone_before_after.png`
- Regression all-motor: `figures/conversion_fix_all_motors_regression_check.png`
- Ablation conversion motor 2: `figures/conversion_fix_ablation_motor2_summary.png`
- Ablation conversion all-motor: `figures/conversion_fix_ablation_all_motor_summary.png`
- Test visual conversion experimental seed 11: `figures/conversion_fix_seed011_baseline_quantized_motor2_calibrated_visual_test.png`
- Test visual conversion experimental seed 55: `figures/conversion_fix_seed055_baseline_quantized_motor2_calibrated_visual_test.png`
- Barrido encoder2Flex: `figures/encoder2flex_limit_sweep_score.png`
- Candidato encoder2Flex: `figures/encoder2flex_selected_candidate.png`
- Regresion barrido encoder2Flex: `figures/encoder2flex_sweep_regression.png`

## Hipotesis abiertas

- Indice: no cambiar columnas hasta confirmar con `checkMotorReferencePermutation`.
- Signo: sanity extendido debe confirmar si acciones negativas producen flex util.
- Escala/zona muerta: el sanity extendido puede mostrar menor ganancia o deadzone en motor 2.
- Reward: probar `trackingMseActionRateMotorWeightedReward` sin cambiar el default oficial.
- Seleccion: usar `selectionMode="motor2_aware"` solo como criterio experimental.

## Comandos actuales

La fase activa ya no entrena TD3 desde cero. Desde `matlab_code/`:

```matlab
results = run_motor2_only_correction_evaluation(struct( ...
    'mode', 'heuristic', ...
    'gapOffset', -256, ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

```matlab
resultsFrozen = run_agent7250_frozen_conversion_evaluation(struct( ...
    'gapOffsets', [0 -64 -128 -256], ...
    'finalTestEpisodes', 50, ...
    'plotEpisodeOnTest', true, ...
    'useGpu', true));
```

```matlab
results = run_all_motor_actuation_sanity_check_extended(struct( ...
    'initialMode', 'all', ...
    'encoder2FlexVariant', ["baseline", "motor2Calibrated"]));
```

Los launchers de ablation/reward/reentrenamiento desde cero se preservan en
`matlab_code/workflows/future_experiments/paused_motor2_training/` para
reproducibilidad, pero no son la linea activa.

No versionar `Agentes/`. Solo copiar summaries o figuras ligeras curadas a
esta carpeta de docs.
