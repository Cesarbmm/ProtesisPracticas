# SANDBOX_PLAN — visualización 3D y estudio de planta

Rama: `experiment/physical-plant-sandbox` · worktree: `ProtesisPracticas_physics_sandbox`
Base: cierre de E2A. Ver `COMO_EMPEZAR.md` para el aislamiento Git.

## 1. Alcance cerrado

**Dentro:**

1. Reproducir episodios development con el pipeline real y auditado
   (EMG → WMoos → markov52 → Agent7250 → baselineQuantized → PWM → planta canónica).
2. Visualizar `q(t)` en una mano 3D **cinemática**.
3. Más adelante: identificar una planta dinámica reducida **contra `pattern_curve.mat`**.
4. Comparar canónica vs dinámica, primero con la misma secuencia PWM y después en lazo
   cerrado.

**Fuera, explícitamente:**

- Entrenar TD3 o cualquier otro agente. No se abre RL por completar este sandbox.
- Tocar `src/@Env`, reward, periodo, niveles PWM, WMoos, `pattern_curve.mat` o el dataset.
- Usar MATEO/SANDRA.
- Usar el guante como estado de planta, o mezclar guante escalado con encoder.
- Merge o push hacia `paired-reference` o `main`.
- Afirmar que una EDO con parámetros heurísticos representa la física real.
- Declarar mejor una planta porque "se ve más suave".

## 2. Las tres cosas que este sandbox NO confunde

| Pregunta | Qué la responde | Qué NO permite concluir |
|---|---|---|
| ¿Cómo se ve el movimiento? | Visor cinemático (S2) | Nada sobre la física ni sobre el control |
| ¿Qué pasa si la planta tiene estado dinámico? | Planta reducida identificada (S4-S5) | Que sea "más realista" por defecto |
| ¿Agent7250 es robusto a otra planta? | Replay en lazo cerrado (S6) | Un benchmark comparable con campañas históricas |

## 3. Unidades — registro obligatorio

Está en `AUDITORIA_S0.md` §2. Resumen de las trampas:

- El estado normaliza el encoder con `[26500 11500 8500 9000]` (límites de **firmware**).
- La planta canónica sólo alcanza el **65 / 58 / 90 / 70 %** de esos límites: `q`
  normalizada nunca llega a 1.
- El índice de `pattern_curve` está en **milisegundos**; un paso de control avanza 200.
- El guante vive en cuentas de flex, no de encoder. **Nunca se mezclan.**

## 4. Fases y gates

| Fase | Entregable | Gate | Si falla |
|---|---|---|---|
| **S0** Auditoría y congelado | `AUDITORIA_S0.md`, `SANDBOX_PLAN.md`, `PREREGISTRO_SANDBOX.md`, estructura de carpetas | **G0**: rama y worktree aislados; tests base E0P/E2A siguen pasando | No continuar |
| **S1** Replay canónico | `replay/runSandboxS1CanonicalReplay.m`, trazas y resumen en `results/` | **G1**: reproduce la ruta B de E2A con igualdad exacta en estado, acción raw, acción efectiva, PWM y `q` | Corregir la integración, nunca el modelo |
| **S2** Visor cinemático | `visualization/HandKinematicViewer.m`, `replayDenisIn3D.m`, animación de un episodio | **G2**: misma `q` → misma pose; extremos sin geometría imposible; el visor no altera acciones, tiempos, estado ni planta | Corregir sólo visualización |
| **S3** Adaptadores de planta | `plants/CanonicalPlantAdapter.m` | **G3a**: el adaptador reproduce `prosthesis_simulator` exactamente | Es un bug del adaptador |
| **S4** Identificación | *no abierta* | **G3b**: el modelo reducido ajusta la evidencia empírica con error documentado, con partición de repeticiones | No llamarlo modelo válido |
| **S5/S6** Action replay y lazo cerrado | *no abiertas* | **G4**: ambos replays reproducibles y **separados** | No interpretar robustez |
| **S7** Simscape Multibody | *no abierta* | Sólo si S2-S6 demuestran que aporta | — |

**Parada obligatoria: al terminar S2 se muestran resultados antes de pasar a
identificación dinámica.**

## 5. Decisiones de diseño ya tomadas (y por qué)

1. **El replay usa `GloveFreePolicyRuntime`, no una reimplementación.** E2A ya contrastó
   esa ruta contra `Env` con diferencia cero. Reescribir markov52 a mano introduciría una
   variable nueva justo donde el plan pide que la única variable sea la planta.
2. **El visor es una función pura de `q`.** `HandKinematicViewer.poseFromQ` no tiene
   estado, no lee configuración y no dibuja. La figura sólo pinta lo que esa función
   devuelve. Así el determinismo es demostrable sin gráficos y los tests corren en
   headless.
3. **La normalización visual usa el recorrido real de la planta**, no los límites de
   firmware (hallazgo F2). Es una decisión de dibujo, declarada y conmutable.
4. **Los sub-pasos de la animación son la misma curva empírica muestreada más fino.**
   Medido: el punto final coincide exactamente con el paso histórico (F4). No es
   interpolación inventada, y aun así se marca `VISUALIZATION_ONLY` y no entra en ningún
   gate.
5. **El adaptador de planta exige `dt == period`.** La planta histórica avanza por contador
   de periodos, no por tiempo continuo. Aceptar otro `dt` sería inventar una semántica.
6. **El motor 1 mueve anular y meñique.** Es evidencia del repositorio (F5), no una
   licencia estética.
7. **No se montan las mallas STL en S2.** Existen, pero los ejes de articulación no están
   documentados; usarlas ahora produciría una mano bonita y falsa. Queda para S7.

## 6. Estructura

```
sandbox_physics/
├── AUDITORIA_S0.md              auditoría de recepción, unidades y hallazgos
├── SANDBOX_PLAN.md              este archivo
├── PREREGISTRO_SANDBOX.md       umbrales de S1 y S2, escritos antes de correr
├── README_SANDBOX.md            cómo ejecutar
├── visualization/               HandKinematicViewer, handKinematicModel, replayDenisIn3D
├── plants/                      CanonicalPlantAdapter, sandboxPlantReachableRange
├── identification/              vacío hasta S4
├── replay/                      sandboxInitialPosition, runSandboxS1CanonicalReplay
├── tests/                       3 suites + fixture de contraste cruzado
└── results/                     salidas (no versionadas salvo que se decida)
```

## 7. Qué resultado sirve aunque la planta dinámica no mejore nada

- Si Agent7250 cambia mucho bajo una planta que respeta las curvas empíricas → se documenta
  **sensibilidad a la dinámica**.
- Si cambia poco → evidencia de **robustez**.
- Si el modelo reducido no puede reproducir `pattern_curve` con pocos estados → se aprende
  que la representación empírica **no conviene reemplazarla**.

Cualquiera de los tres desenlaces informa el diseño del futuro entorno TD3. Ninguno de los
tres autoriza entrenarlo.
