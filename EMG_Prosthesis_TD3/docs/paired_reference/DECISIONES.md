# Decisiones

Una fila por etapa. El veredicto se escribe **después** de ver los resultados, contra el umbral que
el preregistro fijó **antes**.

| Etapa | Fecha | Veredicto | Motivo |
|---|---|---|---|
| E0 | 2026-09-04 | REGISTRADA | Preregistro escrito y entregables listos. Pendiente de ejecución en MATLAB. |

## Decisiones previas a la apertura de la línea

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-09-04 | No se pasa a DQN / Double DQN / Branching | El espacio `{-64,0,+64}` que motivaba el cambio era consecuencia de `actionCommandScale = 0.2510` impuesto en ETAPA 10, no una propiedad de la planta. En `main` cada motor distingue 15 comandos (`actionCommandLevels = [0 64 96 128 160 192 224 255]`, `speeds = 255`). |
| 2026-09-04 | Se abre rama nueva desde `main` en vez de continuar `experiment/no-glove-intent-control` | 88 commits, 40 workflows y 40 tests, con la secuencia `07a`…`07u` como evidencia de deriva de hipótesis. |
| 2026-09-04 | El guante pasa a ser maestro offline, no sensor de ejecución | En `main`, `src/@Env/step.m:123-124` construye la referencia como `flexJoined_scaler(reduceFlexDimension(flexData))`. El guante nunca entró en `markov52`. Sustituir esa función es todo el cambio necesario. |
| 2026-09-04 | Alcance limitado a OPENING / CLOSING | Es lo único que el dataset Denis contiene. |

## Hallazgos técnicos abiertos

| Fecha | Hallazgo | Estado |
|---|---|---|
| 2026-09-04 | `params.(sp).(dir).(m).ws` en `fit_C2.mat` es un objeto `cfit`, no un vector. `numel(ws) == 1`, el clamp de `prosthesis_simulator.m` fuerza `idx = 1` y la trayectoria queda constante: la planta teletransporta en vez de integrar. El fallback a `pattern_curve` de ETAPA 8 es código muerto. Ver `02_HALLAZGO_PLANTA.md`. | Hipótesis con evidencia estructural. Pendiente de confirmación empírica en E0. |
