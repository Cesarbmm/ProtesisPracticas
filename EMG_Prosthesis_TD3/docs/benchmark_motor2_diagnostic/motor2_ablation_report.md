# Motor 2 Ablation Report

## A. Resumen ejecutivo

Se intento aislar el problema recurrente del motor 2 observado despues de
pausar Residual Lift y stop-band. La revision cubrio la campana TD3 base
larga, el sanity check extendido del simulador, un permutation check sobre
un test visual existente, el smoke integrado de diagnostico y la ablation
corta de reward/accion.

Corridas revisadas:

- `Agentes/benchmark_td3_seeded_retrain_motor2_diagnostic/26-05-27_23-44-39/`
- una validacion local de sanity extendido de motor 2
- una validacion local de permutation check
- `Agentes/motor2_targeted_diagnostic_ablation/26-05-28_23-01-10/`
- `Agentes/motor2_reward_ablation/26-05-28_23-31-02/`
- validaciones minimas bajo `Agentes/motor2_reward_ablation_*_min_smoke/`

Hallazgo preliminar: el motor 2 no parece estar completamente mal indexado,
porque responde en el sanity check. Sin embargo, tiene menor rango util,
zona muerta clara en niveles bajos y asimetria entre accion positiva y
negativa. La reward ponderada mejora algunas metricas de error, pero no
reduce los flags `motor2_flat_response` ni `motor2_action_no_motion` en la
ablation corta.

## B. Estado previo

Residual Lift y stop-band quedaron pausados como experimentos futuros. Se
volvio al TD3 base con `markov52` y `trackingMseActionRateReward` porque el
residual no supero robustamente a `Agent7250` y mostro problemas visuales en
motor 2.

La campana TD3 base larga mostro que el problema tambien aparece sin
residual:

| Metrica | Valor |
| --- | ---: |
| trackingMSE mean | 0.053591 |
| trackingMAE mean | 0.181093 |
| actionL2 mean | 0.737733 |
| saturationFraction mean | 0.573518 |
| deltaActionL2 mean | 0.349939 |
| trackingMSE_motor2 mean | 0.045047 |
| responseRange_motor2 mean | 0.140268 |
| motor2_flat_response flags | 3 / 5 |
| motor2_action_no_motion flags | 3 / 5 |
| motor2_tracking_outlier flags | 0 / 5 |

La campana agregada fue `Rejected`; no hubo `ConditionA` ni `ConditionB`.
El mejor checkpoint global fue seed 22, episodio 6900.

## C. Sanity check extendido

El sanity extendido probo niveles `[-1 -0.75 -0.50 -0.25 0 0.25 0.50
0.75 1]` por motor. El indice de accion 2 si corresponde al motor 2: la
trayectoria de encoder cambia cuando se aplica accion en la segunda columna.

La lectura importante esta en flex normalizado:

| Motor | positiveMeanRangeFlex | negativeMeanRangeFlex | positiveGainMean |
| --- | ---: | ---: | ---: |
| 1 | 0.264379 | 0.000000 | 0.509691 |
| 2 | 0.148948 | 0.000000 | 0.209970 |
| 3 | 0.436677 | 0.000000 | 0.675111 |
| 4 | 0.268980 | 0.000000 | 0.549256 |

Para motor 2:

| Nivel | PWM | responseRangeEncoder | responseRangeFlex | finalFlexDelta |
| ---: | ---: | ---: | ---: | ---: |
| -1.00 | -255 | 437.333333 | 0.000000 | 0.000000 |
| -0.75 | -192 | 363.750000 | 0.000000 | 0.000000 |
| -0.50 | -128 | 223.500000 | 0.000000 | 0.000000 |
| -0.25 | -64 | 15.000000 | 0.000000 | 0.000000 |
| 0.25 | 64 | 3598.000000 | 0.000000 | 0.000000 |
| 0.50 | 128 | 6113.833333 | 0.175801 | 0.175801 |
| 0.75 | 192 | 6521.000000 | 0.204853 | 0.204853 |
| 1.00 | 255 | 6665.166667 | 0.215140 | 0.215140 |

Conclusion del sanity: no hay evidencia de indice completamente errado.
Si hay evidencia de zona muerta y menor ganancia util en motor 2. Las
acciones negativas producen cambio de encoder, pero no cambio util en flex
normalizado desde la posicion inicial usada por el test. Esto apunta a
escala, limites, dinamica del simulador o conversion encoder-flex antes que
a un simple error de columna.

## D. Permutation check

El permutation check comparo la referencia del guante para motor 2 contra
las respuestas de los cuatro motores. En el test revisado, la menor MSE de
referencia 2 fue contra respuesta 4, seguida por respuesta 1 y luego
respuesta 2:

| Referencia | Respuesta | correlation | trackingMSE | responseRange |
| ---: | ---: | ---: | ---: | ---: |
| 2 | 4 | 0.549175 | 0.039845 | 0.280658 |
| 2 | 1 | 0.541498 | 0.043629 | 0.287325 |
| 2 | 2 | 0.545061 | 0.047959 | 0.215140 |
| 2 | 3 | 0.556092 | 0.064850 | 0.575008 |

Esto no basta para corregir columnas: las correlaciones son similares y el
ranking puede estar afectado por amplitud/rango, no solo por mapeo. Queda
pendiente repetir permutation sobre mas test runs antes de tocar
`reduceFlexDimension`, `encoder2Flex` o el orden de motores.

## E. Ablation baseline vs motor2_weight_2

La ablation corta uso seeds `[11 22 55]`, `3000` episodios y test final de
20 episodios con seleccion `motor2_aware`.

| Config | trackingMSE | trackingMAE | actionL2 | saturationFraction | deltaActionL2 | trackingMSE_motor2 | responseRange_motor2 | flat | action-no-motion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline_current | 0.075065 | 0.216270 | 0.519088 | 0.291174 | 0.259468 | 0.091417 | 0.166997 | 2 | 1 |
| motor2_weight_2 | 0.063219 | 0.197631 | 0.566835 | 0.288082 | 0.241976 | 0.049471 | 0.132968 | 3 | 3 |
| motor2_weight_3 | 0.074795 | 0.214540 | 0.603966 | 0.349985 | 0.168769 | 0.040923 | 0.119698 | 3 | 3 |
| motor2_weight_2_low_action_motor2 | 0.064472 | 0.200514 | 0.644732 | 0.377687 | 0.227693 | 0.040245 | 0.139920 | 2 | 2 |
| continuous_action_baseline | 0.068834 | 0.205349 | 0.474178 | 0.240714 | 0.242199 | 0.078011 | 0.116566 | 3 | 3 |

Ninguna configuracion cumplio los criterios de aceptacion corta. La reward
ponderada redujo `trackingMSE_motor2`, pero tambien redujo el rango de
respuesta del motor 2 y mantuvo o empeoro los flags de respuesta plana.

## F. Lectura tecnica

La reward ponderada en motor 2 no debe promoverse todavia. Con 3000
episodios, mejora el error medio de motor 2, pero no resuelve el problema
visual/funcional: `responseRange_motor2` no sube y los flags siguen altos.
Eso sugiere que el agente puede estar aprendiendo a reducir MSE con una
respuesta conservadora o plana, no a mover mejor el motor 2.

La seleccion `motor2_aware` es util como herramienta de diagnostico, pero
tampoco basta si todos los checkpoints candidatos mantienen rango bajo o
flags. Antes de una nueva campana larga conviene revisar escala y dinamica
del motor 2.

## G. Veredicto provisional

El motor 2 no parece estar completamente mal indexado, porque responde en el
sanity check. Sin embargo, el rango util es menor y existe zona
muerta/asimetria, por lo que el problema apunta mas a escala, dinamica del
simulador o reward/seleccion de checkpoint. La reward ponderada debe
evaluarse con mas cuidado y no debe reemplazar la reward oficial todavia.

## H. Plan futuro

1. Revisar escala/normalizacion del motor 2 en `encoder2state_scale`,
   `flexJoined_scale`, `encoder2Flex` y limites de `definitions`.
2. Revisar zona muerta y cuantizacion: comparar `baselineQuantized` contra
   accion continua y niveles PWM mas densos solo en simulacion.
3. Repetir permutation check en varios test runs para confirmar o descartar
   cruce de columnas antes de tocar mapeos.
4. Validar reward ponderada con una corrida corta adicional solo si el
   simulador/mapeo no explica la zona muerta.
5. Si una configuracion reduce flags y conserva tracking global, lanzar una
   campana mediana antes de otra campana larga.
6. Solo despues retomar Residual Lift/stop-band.
7. Antes de hardware, validar logs por motor, limites de seguridad y
   respuesta esperada en simulacion.

## Figuras curadas

- `figures/seed_011_motor_diagnostic.png`
- `figures/seed_055_motor_diagnostic.png`
- `figures/motor2_diagnostic_summary.png`
- `figures/motor_response_gain_matrix.png`
- `figures/ablation_motor2_summary.png`

## I. Seguimiento 2026-06-04

Se corrio la fase `Motor response calibration before reward tuning`.
El diagnostico mostro que motor 2 si mueve encoder en niveles bajos, pero
la salida queda plana despues de `encoder2Flex` hasta cruzar la zona util.
La ablation corta con `motorCalibratedQuantized` redujo `trackingMSE`
global, `trackingMSE_motor2` y `saturationFraction`, pero no aumento
`responseRange_motor2` y dejo `motor2_action_no_motion=1/2`.

El resumen completo de esta etapa quedo en:

- `motor2_calibration_report.tex`
- `motor2_calibration_report.pdf`
