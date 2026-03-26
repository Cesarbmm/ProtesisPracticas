# Avance acumulado 2026-03-25: exploracion sobre `Agent7250` y cambio de direccion

## 1. Estado de partida

El benchmark operativo del proyecto sigue siendo `Agent7250`, obtenido en la corrida valida de `8000` episodios posterior al fix del simulador.

Referencia congelada:

| Metrica | Valor |
|---|---:|
| `trackingMSE` | `0.043045` |
| `trackingMAE` | `0.160336` |
| `actionL2` | `0.596444` |
| `saturationFraction` | `0.392086` |
| `deltaActionL2` | `0.321385` |
| `absPWM mean` | `178.288566` |

La meta de esta fase no fue entrenar otro baseline desde cero, sino intentar mejorar el compromiso entre:

- tracking
- esfuerzo de control
- agresividad residual

sin tocar:

- observacion `markov52`
- reward `trackingMseActionRateReward`
- arquitectura TD3 feedforward
- cuantizacion y remapeo efectivo del actuador

## 2. Idea anterior: continuacion de `Agent7250` con menor exploracion

### Hipotesis

Como el benchmark ya seguia bien la referencia pero seguia siendo agresivo, la idea fue continuar el entrenamiento del propio `Agent7250` con menos ruido de exploracion, en vez de crear otra reward o entrenar un agente nuevo.

### Implementacion

Se implemento el flujo de `resume training` con reaplicacion real del ruido de exploracion al checkpoint cargado y se ejecuto una continuation sweep sobre:

- `explorationStd`
- `explorationStdMin`
- con `Agent7250` como punto de partida

Corrida consolidada:

- `Agentes/agent7250_low_exploration_finetune/26-03-24 23 16 56`

### Resultado

La mejor combinacion fue:

- `explorationStd = 0.05`
- `explorationStdMin = 0.005`
- `explorationStdDecayRate = 1e-4`
- mejor checkpoint: `Agent1100`

Metricas auditadas del mejor punto:

| Metrica | Valor |
|---|---:|
| `trackingMSE` | `0.044022` |
| `trackingMAE` | `0.16345` |
| `actionL2` | `0.57794` |
| `saturationFraction` | `0.35271` |
| `deltaActionL2` | `0.19154` |

Interpretacion:

- el tracking empeoro poco: `+2.27%`
- la saturacion bajo `-10.04%`
- la agresividad cayo mucho en `deltaActionL2`
- pero el `actionL2` no bajo el `8%` requerido por `ConditionB`

### Test visual del mejor candidato

Se corrio un test completo de `50` simulaciones sobre ese `Agent1100`.

Resultado agregado:

| Metrica | Valor |
|---|---:|
| `trackingMSE` | `0.0479` |
| `trackingMAE` | `0.1721` |
| `actionL2` | `0.5306` |
| `saturationFraction` | `0.3377` |
| `deltaActionL2` | `0.2752` |
| `absPWM mean` | `162.8764` |

Conclusion:

- como candidato mas suave, fue interesante;
- como reemplazo del benchmark, no;
- el tracking cayo demasiado en test real.

## 3. Idea siguiente ya cerrada: exploracion `threshold-aware`

### Por que surgio

Revisando el repo aparecio un hecho importante:

- `actionCommandActivationThreshold = 0.05`
- el primer nivel no nulo cuantizado es `64/255 ~= 0.251`

Eso significa que una accion continua apenas por encima del umbral ya salta al primer comando fisicamente efectivo del actuador. La exploracion gaussiana no opera entonces sobre una interfaz suave, sino sobre una discontinuidad real.

### Protocolo

Se implemento un launcher por etapas:

1. `stage1`: sweep fino de `explorationStd` alrededor del umbral
2. `stage2`: ablation de `explorationStdDecayRate`
3. `stage3`: prueba unica con `ResetExperienceBufferBeforeTraining = true`

Corridas:

- `Agentes/agent7250_threshold_exploration_sweep/26-03-25 01 14 53__stage1`
- `Agentes/agent7250_threshold_exploration_sweep/26-03-25 02 24 44__stage2`
- `Agentes/agent7250_threshold_exploration_sweep/26-03-25 06 06 09__stage3`

### Resultado

La mejor configuracion volvio a ser:

- `0.05 / 0.005 / 1e-4`

Y sus metricas quedaron en:

| Metrica | Valor |
|---|---:|
| `trackingMSE` | `0.044022` |
| `actionL2` | `0.57794` |
| `saturationFraction` | `0.35271` |
| `deltaActionL2` | `0.19154` |

Conclusiones:

- el mejor punto fue exactamente el casi-acierto ya conocido;
- ni bajar mas `explorationStd` ni cambiar el decaimiento ayudo;
- el reset del replay buffer no abrio una mejora nueva.

## 4. Nueva intervencion ejecutada: piloto de accion continua alineada al actuador

### Por que se intento

La lectura que dejo la fase anterior fue que el cuello de botella ya no parecia ser cuanto ruido meter, sino la desalineacion entre:

- la accion continua que emite el actor en `[-1,1]`
- el umbral de activacion `0.05`
- la cuantizacion posterior a niveles PWM efectivos

Sobre esa base se implemento una nueva interfaz de accion llamada `alignedContinuousWarp`. La idea era deformar la magnitud continua del actor antes del remapeo final al actuador, para aproximarla a los niveles fisicamente utiles del sistema sin tocar reward, observacion ni arquitectura.

### Protocolo aplicado

El piloto mantuvo fijo:

- checkpoint base: `Agent7250`
- observacion `markov52`
- reward `trackingMseActionRateReward`
- TD3 feedforward
- exploracion `0.05 / 0.005 / 1e-4`
- `1500` episodios adicionales con guardado cada `50`

La warp uso:

- `deadzone = 0.05`
- niveles de salida `[64 96 128 160 192 224 255] / 255`
- conservacion del signo de la accion original

Entrenamiento:

- `Agentes/agent7250_aligned_action_pilot/26-03-25 10 44 29/training_run/26-03-25 10 44 38`

La auditoria integrada no cerro bien el resumen final, asi que se reconstruyo manualmente en:

- `Agentes/agent7250_aligned_action_pilot/26-03-25 10 44 29/audit_rebuilt`

### Resultado auditado

La fase rapida ya mostraba un patron claro: podia aparecer un `trackingMSE` atractivo, pero a costa de mucho mas borde y mucho mas esfuerzo. La fase completa confirmo que la mejor politica del piloto fue `Agent1450`, y que aun asi quedaba rechazada.

| Checkpoint | trackingMSE | actionL2 | saturationFraction | deltaActionL2 |
|---|---:|---:|---:|---:|
| `Agent1450` | `0.044561` | `0.847337` | `0.676780` | `0.300599` |
| `Agent1350` | `0.047558` | `0.824998` | `0.645571` | `0.431538` |
| `Agent7250` benchmark | `0.043045` | `0.596444` | `0.392086` | `0.321385` |

Frente al benchmark:

- `trackingMSE`: peor, `+3.5%`
- `actionL2`: peor, `+42.1%`
- `saturationFraction`: peor, `+72.6%`
- `deltaActionL2`: mejora solo ligera

El piloto no paso ni el filtro practico previo al test visual, asi que no se genero `visual_test` final.

### Que enseno el logging nuevo

El experimento fue valioso como diagnostico. Sobre toda la corrida:

- `trackingMSE mean = 0.045688`
- `actionL2 mean = 0.751889`
- `saturationFraction mean = 0.519368`
- `deltaActionL2 mean = 0.414207`
- `rawToWarpedActionErrorMean = 0.043347`
- fraccion cruda en la zona `0.05 <= |u| < 64/255`: `0.065893`

En el mejor checkpoint auditado (`Agent1450`):

- `rawToWarpedActionErrorMean = 0.027231`
- `rawDeadzoneToFirstLevelFractionMean = 0.038733`
- fraccion en `effectiveAction = +1.0`: `0.621576`
- fraccion en `effectiveAction = 0`: `0.005055`

Interpretacion:

- la warp no ayudo a usar mejor la zona intermedia;
- en la practica, el agente aprendio a explotar mucho mas el borde superior positivo del actuador.

## 5. Conclusion tecnica actualizada de la fase

A esta altura, tres lineas distintas ya quedaron suficientemente exploradas:

- continuacion con baja exploracion
- exploracion `threshold-aware`
- piloto de accion continua alineada con warp fija

Las tres dejaron aprendizaje util, pero ninguna reemplazo al benchmark `Agent7250`.

Lectura consolidada:

- bajar un poco la exploracion ayuda a suavizar, pero no alcanza para ganar en tracking y control a la vez;
- seguir exprimiendo exploracion gaussiana no abre una mejora nueva;
- alinear la interfaz de accion con una warp fija tampoco funciona, porque la politica tiende a colapsar a bins altos;
- el benchmark `Agent7250` sigue siendo el punto operativo mas solido del proyecto.

## 6. Siguiente intervencion distinta recomendada

La siguiente intervencion ya no deberia ser:

- otra reward nueva
- otro sweep de exploracion
- ni otra warp fija en la interfaz del entorno

Si se sigue por la cuestion del actuador, la idea nueva debe ser mas estructural: no una deformacion fija impuesta fuera de la politica, sino una parametrizacion de accion o una restriccion de uso de bins acoplada al aprendizaje y que no incentive el colapso al nivel maximo.

## 7. Mensaje final de avance

La conclusion de avance ya puede dejarse asi:

- `Agent7250` sigue siendo el benchmark operativo vigente;
- la rama de baja exploracion dejo un candidato mas suave, pero no un nuevo baseline;
- la rama `threshold-aware` cerro la hipotesis de exploracion alrededor del umbral;
- el piloto `alignedContinuousWarp` mostro que una warp fija puede empeorar el compromiso al colapsar a bins altos;
- la siguiente fase debe abandonar la exploracion como variable principal y replantear la interfaz de accion desde una representacion mas estructural.
