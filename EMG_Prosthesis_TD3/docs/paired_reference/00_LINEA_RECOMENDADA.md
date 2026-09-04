# Línea recomendada — `experiment/no-glove-paired-reference-td3`

Documento de decisión previo a cualquier implementación.
Fecha: 2026-09-04. Autor de la auditoría: revisión sobre el worktree
`ProtesisPracticas_no_glove_intent_control` + informe TD3 (marzo 2026) + Avance actual (julio 2026).

---

## 0. Veredicto en una línea

**Tu propuesta es correcta y la adopto, con tres correcciones y un riesgo que tu propuesta no
declara.** Se abre rama nueva desde `main`, se conserva TD3 continuo, y el guante se sustituye por
un **estimador de referencia entrenado con los pares históricos EMG–guante**. No se pasa a DQN.

---

## 1. Refutación del pivote a DQN-81 (esto es lo más importante)

El prompt de ETAPA 12 afirma que la planta sólo distingue, por motor:

    a_i ∈ {-64, 0, +64}   ->   3^4 = 81 acciones conjuntas

**Eso es falso para el proyecto. Es un artefacto autoinducido en ETAPA 10.**

Evidencia en el propio worktree:

| Hecho | Archivo | Valor |
|---|---|---|
| Niveles PWM del cuantizador | `matlab_code/config/configurables.m:224` (main) | `[0 64 96 128 160 192 224 255]` |
| Velocidad máxima por motor | `matlab_code/config/configurables.m:221` (main) | `255 * [1 1 1 1]` |
| Escala de acción en `main` | no existe: `actionCommandScale` fue introducido por la rama experimental | equivale a `1.0` |
| Escala usada en ETAPA 10/12 | `docs/no_glove_experiment/12_constant_exploration_pilot.md:24` | `0.250980` |
| Consecuencia documentada | `docs/no_glove_experiment/10_action_range_pilot.md:77` | "dentro del rango escalado el cuantizador sólo puede devolver **0 o ±64**" |

Con la configuración por defecto la planta distingue **7 magnitudes no nulas × 2 signos + 0 = 15
comandos por motor**, es decir **15^4 = 50 625 acciones conjuntas**, no 81.

Los `{-64, 0, +64}` aparecieron porque ETAPA 10 multiplicó la salida del actor por 0.2510 y con eso
el cuantizador quedó atrapado en el primer nivel. La "dispersión Q espuria del 74 % dentro de bins
físicamente idénticos" que midió ETAPA 12 es real, pero **mide la patología que introdujo ETAPA 10**,
no una propiedad de la prótesis.

**Conclusión:** la respuesta correcta a ETAPA 12 no era cambiar de algoritmo, era quitar
`actionCommandScale`. Cambiar TD3 por Double-DQN para resolver un aliasing creado por un factor de
escala habría sido rediseñar el agente para acomodar un bug de configuración. Tu instinto de que
"pasar a otro algoritmo es un error" está respaldado por el código.

Esto además hace innecesario el prompt de ETAPA 12 completo. Se archiva.

---

## 2. Reencuadre correcto del problema (confirmado en código)

El guante **nunca fue entrada de la política**. La observación `markov52` es
`40 EMG + 4 enc + 4 Δenc + 4 a_{t-1}`; no contiene guante (`src/@Env/calculateState.m`).

El guante entra sólo aquí, en `src/@Env/step.m:123-124` (main):

    this.flexConverted   = this.flexJoined_scaler(reduceFlexDimension(this.flexData));
    this.referenceTarget = this.flexConverted(end, :)';

Es decir: **el guante es la fuente de la referencia de la reward, y nada más.**

Por tanto el objetivo de la nueva línea es exactamente:

    sustituir  flexConverted(end,:)  por  f_theta(features EMG del paso actual)

y **el target supervisado del decoder está perfectamente definido y ya escalado**: es
`flexConverted(end,:) ∈ R^4`. El drop-in es exacto: si el decoder produce ese vector, `markov52`,
`trackingMseActionRateReward`, `baselineQuantized`, TD3 y todas las métricas quedan intactos.

Esto es lo que hace defendible tu propuesta y lo que la distingue de la rama anterior, que tuvo que
**inventar** una estructura de intención (dos sinergias, reposo, oposición, calibración por sesión)
que el dataset Denis no soporta.

---

## 3. El riesgo que tu propuesta no declara (y que decide la tesis)

> Si `f(EMG) → ŷ` funciona bien, **¿para qué hace falta RL?**

Un tribunal lo va a preguntar. Y el proyecto ya tiene evidencia incómoda: en la rama anterior,

    u = 0            trackingMSE = 0.005591
    P con Kp = 0.50  trackingMSE = 0.003483
    óptimo DP HOME   trackingMSE = 0.001661

Un controlador proporcional trivial ya cerraba ~53 % de la distancia entre no hacer nada y el óptimo
dinámico. Si el decoder entrega una referencia limpia, un P bien sintonizado puede ser competitivo.

**Regla que impongo a la nueva línea:** en cada etapa donde haya tracking, se corren SIEMPRE tres
controladores sobre la MISMA referencia estimada:

1. `u = 0` (piso)
2. `P` con Kp barrido (baseline honesto)
3. `TD3`

Y la justificación declarada de TD3 debe escribirse **antes** del piloto. Mi lectura: TD3 se
justifica no por el tracking puro sino porque optimiza el compromiso completo que un P no optimiza —
cuantización de PWM en 15 niveles, umbral de activación τ, `actionL2`, `saturationFraction`,
`deltaActionL2`. Si TD3 no bate a `decoder + P` en ese compromiso, la contribución de la tesis es
**el decoder**, no el agente. Eso sigue siendo un resultado publicable, pero conviene saberlo en la
ETAPA 1, no después de 600 episodios.

---

## 4. Descomposición del error (obligatoria en todas las métricas)

Al estimar la referencia, el error de tracking deja de ser una sola cosa:

    e_total = (ŷ - y_glove)  +  (q - ŷ)
              \___________/     \_____/
              error decoder     error control

Sin esta separación, un decoder perezoso (que predice casi una constante) produce un tracking
"excelente" contra su propia referencia. **Se reportan siempre las dos:**

- `trackingMSE_vs_estimate` — lo que el agente optimiza
- `trackingMSE_vs_trueGlove` — verdad de terreno oculta, sólo auditoría, nunca reward ni observación

---

## 5. Fugas de datos: tres puntos de control

1. **Split por sujeto, no por ventana.** 12 sujetos (`data/datasets/Denis Dataset`: BLANCA, CECILIA,
   DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN, KHAROL, MATEO, SANDRA). 8 / 2 / 2, o LOSO
   para la fase puramente offline.
2. **El mismo particionado para el decoder y para el RL.** Si el agente entrena con sujetos que el
   decoder ya vio, el test final está contaminado dos veces. Este punto no aparece en tu propuesta y
   es el error más fácil de cometer.
3. **`flexJoined_scaler` y `normValues.mat` se ajustan sólo con sujetos de train.**

---

## 6. Reposo y Myo: fuera de alcance, y por qué

El dataset Denis contiene pares `closing` / `opening` y nada más. **No hay reposo etiquetado.** Por
tanto el decoder es out-of-distribution en reposo por construcción. Se declara como limitación
explícita en la tesis y **no** se reintroduce `motionPermission`, gate de reposo, hold latch ni
`intentMarkov60/62`.

Sobre el Myo: la validación de julio dio reducción de PWM en reposo de 98.23 % y 6.05 % en dos
corridas — eso no es un Myo dañado, es una compuerta no reproducible. Puede que además el Myo esté
mal; da igual. **No es diagnosticable mientras la referencia sea sintética.** Se aplaza hasta después
de ETAPA 3.

Nota (hipótesis, no promesa): bajo referencia de *posición*, el reposo deja de necesitar mecanismo
especial — referencia constante ⇒ `e²` y `Δa²` ya penalizan moverse. Si eso se confirma, ETAPAS
07c–07u quedan explicadas de golpe: se estaba peleando contra una referencia de *velocidad* mal
condicionada.

---

## 7. DTW: de acuerdo contigo, con un matiz

No entra en la reward. Ya fue rechazado con umbral pre-registrado del 5 % (beneficio medido: 1.0668 %
Agent200, 3.4972 % P). Se usa como métrica secundaria de forma temporal.

Matiz: para el retardo EMG→movimiento, en vez de alinear señales con `finddelay`/`alignsignals`,
es más limpio **absorber el lag en el target del decoder**: entrenar `f(φ_t) → flexConverted_{t+k}`
y barrer `k`. Es causal, no toca el entorno, y el barrido de `k` da directamente la curva de
sensibilidad al retardo. `finddelay`/`xcorr` se usan para acotar el rango de `k`, no para preprocesar.

---

## 8. Roadmap: cinco etapas, tope duro

| Etapa | Qué | Gate de salida | RL |
|---|---|---|---|
| **E0** | Sanity de planta sobre `main` + inventario del dataset + rango de lag | monotonicidad `closing ⇒ q↑`, `opening ⇒ q↓` para cada motor × PWM × posición inicial | no |
| **E1** | Decoder offline `40 WMoos → 4 flex`, ridge lineal primero | ¿bate al baseline trivial (predecir el último valor / la media del sujeto) con split por sujeto? | no |
| **E2** | Integrar `referenceSource="emgDecoder"` en `Env` | ruta `glove` byte-idéntica; ruta nueva sin cargar `RecordedGlove` | no |
| **E3** | Piloto: `u=0` vs `P(Kp)` vs `TD3` 600 ep, misma referencia | TD3 gana el compromiso (tracking + `actionL2` + saturación + `Δa`) frente a `decoder+P` | sí |
| **E4** | Sólo si E3 lo exige: contexto temporal (`stackedEmg132` o TD3 recurrente) | mejora > umbral pre-registrado | sí |

**Regla anti-deriva:** máximo cinco etapas numeradas. Toda hipótesis nueva va a `BACKLOG.md`, no a
una sub-etapa. Si aparece una `E3a`, la línea ya se rompió: parar y volver a preguntar.

Justificación de la regla: la rama actual tiene **40 workflows publicados y 40 tests**, de los cuales
más de la mitad son ETAPA 7 (`07a` … `07u`). Esa proliferación es el síntoma medible de la deriva de
hipótesis. No es un problema de esfuerzo, es un problema de contrato.

---

## 9. Qué se porta y qué no

**Se porta** (conocimiento, no la rama):

- el mecanismo `referenceSource` de ETAPA 1 — pero con el valor nuevo `"emgDecoder"`, **no**
  reutilizando `"emgIntent"`, para no arrastrar el aparato de intención;
- los logs genéricos `referenceHistory` / `trackingPredictionHistory`;
- el contrato de splits validation/test y el criterio de checkpoint;
- el fix de planta de ETAPA 8, **sólo si E0 demuestra que `main` lo necesita**;
- el analizador temporal de ETAPA 7 (para métricas, no para reward);
- las compuertas `ConditionA` / `ConditionB` y los flags por motor (`flat_response`,
  `action_no_motion`), que son la mejor herencia metodológica del proyecto.

**No se porta:** `intentMarkov60/62`, decoder de dos sinergias, calibración sintética, gate de
reposo, `motionPermission`, hold latch, `actionCommandScale`, σ=0.40 constante, y toda la secuencia
07a–12.

---

## 10. Contrato del experimento

- Planta: `main`, verificada en E0.
- Observación: `markov52`. Sin cambios.
- Reward: `trackingMseActionRateReward`, λ_a = 0.01, λ_Δa = 0.05. Sin cambios.
- Interfaz de acción: `baselineQuantized`, `actionCommandScale = 1.0`, niveles
  `[0 64 96 128 160 192 224 255]`, `speeds = 255`.
- Agente: TD3 feedforward, 64 unidades, receta de `Agent7250`.
- Alcance: **OPENING / CLOSING únicamente**. Sin reposo, sin oposición, sin cuatro intenciones.
- `motionPermission`: **eliminado**, no "OFF en training / ON en evaluación".
- Splits: por sujeto, compartidos entre decoder y RL.
- Piloto: 600 episodios. Sin campañas multiseed hasta pasar E3.
- Baselines obligatorios en E3: `u=0`, `P(Kp)`, y `Agent7250` con guante real como referencia
  histórica de contexto (no como competidor directo — la referencia es distinta).

---

## 11. Pregunta científica de la tesis

> ¿Puede un estimador de referencia entrenado con pares históricos EMG–guante sustituir al guante
> durante la ejecución, conservando el controlador continuo TD3, para los movimientos de apertura y
> cierre que el dataset realmente contiene?

Y la distinción que conviene hacer explícita en el capítulo de método:

- **Sin guante absoluto** — ni siquiera para aprender. El dataset sólo deja etiquetas
  `closing`/`opening` y se pierde el objetivo continuo. No es lo que se hace.
- **Sin guante en operación** — el guante es maestro offline; en ejecución sólo hay EMG. Es lo que se
  hace, y es la posición más fuerte: es el patrón estándar de entrenar con un sensor de referencia
  que después no se necesita.
