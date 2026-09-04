# Plan por etapas — `experiment/no-glove-paired-reference-td3`

Cinco etapas. Tope duro. TD3 se conserva en las cinco. **No hay DQN en ningún punto de este plan.**

Sólo dos etapas gastan episodios de entrenamiento (E3 y, condicionalmente, E4). Las tres primeras
son auditoría y trabajo offline, y cualquiera de ellas puede terminar el proyecto con un resultado
válido sin entrenar nada.

---

## E0 — Auditoría de planta y de datos · sin RL

**Pregunta:** ¿la planta de `main` es físicamente consistente, y qué contiene realmente el dataset?

### E0.1 Sanity de planta (bloqueante)

> **Actualización 2026-09-04.** Antes de ejecutar nada se inspeccionó `fit_C2.mat` y se encontró
> que `ws` es un objeto `cfit` con `numel(ws) == 1`, lo que colapsa el índice del simulador y deja
> la trayectoria constante. Ver `02_HALLAZGO_PLANTA.md`. E0.1 pasa de trámite a etapa decisiva, y
> se **espera** que su gate falle.

Riesgo concreto ya localizado en `main`, en `src/@SimController/prosthesis_simulator.m`:

- línea 100 → `y_sat = sat(pos, min_l, max_l)`
- línea 114 → `t = numel(curve)` **es el valor por defecto**: si la búsqueda de la posición inicial
  no encuentra ningún punto de la curva, el episodio arranca **en el final de la curva**
- líneas 106-112 → cuando `ws` está vacío se usa `PATTERN_CURVE` como respaldo
- líneas 131-132 → `x_0 = t` con respaldo, `x_0 = tail_length + t` sin respaldo (dos orígenes
  distintos según el camino)

Test determinista, sin agente:

    4 motores × 7 niveles PWM no nulos × 2 signos × 21 posiciones iniciales en [0,1] = 1176 llamadas

Se verifica: `closing ⇒ q_{t+1} ≥ q_t`, `opening ⇒ q_{t+1} ≤ q_t`, y ausencia de saltos por encima
de un umbral declarado. Se registra en cuántos casos se activa `useCurveFallback` y en cuántos
`t` queda en `numel(curve)`.

**Gate:** si aparecen saltos no físicos → fix mínimo, re-correr, y sólo entonces seguir. Si no
aparecen → se documenta que `main` está sana y no se porta nada de ETAPA 8.

### E0.2 Inventario del dataset

Los 12 sujetos de `data/datasets/Denis Dataset` (BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL,
IVANNA, JOE, JONATHAN, KHAROL, MATEO, SANDRA): pares gesto/lado por sujeto, longitudes de `emgs` y
`gloves`, desfase de longitud, campos de `metadata`.

Se deja escrito y firmado qué **no** existe: reposo etiquetado, MVC/P95 por sesión, calibración por
sesión, garantía de colocación anatómica y de orden de canales entre capturas. Este párrafo es el
que impide que la línea vuelva a derivar hacia reposo y oposición.

### E0.3 Rango de lag

Con `finddelay`/`xcorr` sobre una muestra de sujetos, acotar el rango plausible de `k` para el
target desplazado `f(φ_t) → flexConverted_{t+k}`. **Sólo acotar `k`.** No se alinean señales, no se
toca el entorno, no se usa DTW.

### E0.4 Contrato de splits

Partición por sujeto 8/2/2 con nombres concretos, o LOSO para la fase offline. Se congela aquí y
se usa **igual** en E1 y en E3.

- **Entrega:** doc + workflow + test + fila en `DECISIONES.md`
- **Coste:** 0 episodios
- **Puede terminar el proyecto:** sí, si la planta está rota de forma no reparable

---

## E1 — Guante virtual offline · sin RL

**Pregunta:** ¿puede un regresor predecir la referencia del guante a partir de EMG, en sujetos que
no ha visto?

**Target exacto:** `flexConverted(end,:) ∈ R⁴`, tal como lo construye `src/@Env/step.m:123-124` (main).
Ya escalado. Nada de inventar una representación nueva.

**Features:** las 40 WMoos que el entorno ya calcula. **Prohibido** construir un pipeline de
features paralelo — es la vía rápida a que el decoder funcione offline y no funcione dentro del
entorno.

**Escalera de modelos**, parando en el primero que pase el gate:

1. baseline trivial A — predecir el último valor
2. baseline trivial B — **la trayectoria media del gesto**, ignorando EMG por completo
3. ridge lineal 40 → 4
4. ridge con contexto causal `[φ_t, φ_{t-1}, φ_{t-2}]` 120 → 4
5. MLP pequeño, sólo si 3 y 4 fallan

El baseline B es el que de verdad importa y no estaba en la propuesta original. Los episodios son
trayectorias monótonas cortas: un modelo que aprende "la mano se cierra siguiendo una sigmoide
media" puede dar métricas excelentes **sin leer EMG**.

**Ablación obligatoria:** repetir con las ventanas EMG barajadas entre episodios. Si el resultado
no se degrada, el decoder no está usando EMG y el número bueno era el baseline B disfrazado.

**Métricas** (subject-disjoint, partición de E0.4): MSE, MAE, ρ, `sign(Δŷ) == sign(Δy)`, DTW como
secundaria de forma. Barrido de `k` sobre el rango de E0.3.

**Gate:** el ridge lineal debe batir a los dos baselines triviales en sujetos no vistos, en MSE
**y** en sign accuracy, y la ablación de barajado debe degradarlo.

**Desenlace si falla:** PARA. La conclusión de la tesis pasa a ser que el dataset soporta un decoder
*subject-specific* pero no uno independiente del usuario. Eso es un resultado, no un fracaso, y se
reporta con LOSO completo. **No** se escalan arquitecturas para rescatar el número.

- **Entrega:** doc + workflow + test + modelo congelado con checksum
- **Coste:** 0 episodios, horas de CPU
- **Puede terminar el proyecto:** sí

---

## E2 — Integrar la referencia estimada · sin entrenar

**Pregunta:** ¿puede el entorno correr con la referencia estimada sin alterar nada más?

Se añade `referenceSource = "emgDecoder"` en `configurables.m` y en `Env`. Valor **nuevo**; no se
reutiliza `"emgIntent"`, para no arrastrar `src/intent/*` ni el aparato de calibración.

Invariantes:

- `markov52`, `trackingMseActionRateReward`, `baselineQuantized`, `actionCommandScale = 1.0`,
  `actionCommandLevels = [0 64 96 128 160 192 224 255]`, `speeds = 255` — intactos
- el decoder está **congelado**; su checksum se guarda en cada `episode*.mat`
- la ruta nueva **no construye** `RecordedGlove` en training ni validation
- en test el guante sí se carga, pero **sólo** como verdad de terreno de auditoría

**Gate (dos tests bloqueantes):**

1. **Byte-identidad:** un episodio con `referenceSource="glove"` antes y después del cambio produce
   el mismo `episode*.mat`
2. **Smoke:** 5 episodios con `referenceSource="emgDecoder"` sin errores, con
   `referenceHistory` y `trackingPredictionHistory` poblados

- **Coste:** 0 episodios de entrenamiento
- **Puede terminar el proyecto:** no, es puramente de plomería

---

## E3 — Piloto comparativo · aquí entra el RL

**Pregunta:** con la referencia estimada, ¿aporta TD3 algo sobre un control clásico?

Tres controladores sobre **la misma** referencia estimada, mismos sujetos, mismas semillas:

| Controlador | Papel |
|---|---|
| `u = 0` | piso |
| `P` con Kp barrido, elegido en validation | baseline honesto |
| `TD3`, 600 episodios, receta `Agent7250` | candidato |

Referencia de contexto, no competidor: `Agent7250` con guante real. La referencia es distinta, así
que no es comparación directa y se etiqueta como tal en toda tabla.

**Métricas dobles, siempre:** `trackingMSE_vs_estimate` y `trackingMSE_vs_trueGlove`, más la
descomposición `e_total = (ŷ − y_glove) + (q − ŷ)`. Y el paquete completo: `actionL2`,
`saturationFraction`, `deltaActionL2`, y por motor `responseRange`, `flat_response`,
`action_no_motion`.

**Gate — los tres desenlaces se declaran ANTES de correr:**

- **(a) TD3 bate a `decoder + P`** en el compromiso completo → la línea sigue; se replica con 3
  semillas antes de declarar nada
- **(b) TD3 ≈ `decoder + P`** → la contribución de la tesis es **el decoder**; TD3 queda como
  demostración de que el control aprendido iguala al clásico bajo cuantización y penalización de
  esfuerzo. Honesto, defendible, y cierra el trabajo
- **(c) TD3 pierde** → se para el RL y se investiga por qué. La primera hipótesis es que la
  referencia estimada tiene más ruido de alta frecuencia del que `trackingMseActionRateReward`
  tolera, **no** que haga falta otro algoritmo

- **Coste:** 600 episodios × 1 semilla. Nada de multiseed antes de pasar este gate
- **Puede terminar el proyecto:** sí, en cualquiera de los tres desenlaces

---

## E4 — Contexto temporal · sólo si E3 lo exige

Se abre **únicamente** si E1 o E3 muestran que el error dominante es de fase o retardo, no de
amplitud. Entonces, y un cambio a la vez:

1. `stackedEmg132`, o
2. el TD3 recurrente que `main` ya soporta

Nunca los dos. Nunca junto con un cambio de decoder, de reward o de acción.

- **Coste:** un piloto de 600 episodios por variante
- **Gate:** mejora por encima del umbral pre-registrado

---

## Fuera de alcance hasta después de E3

Lista cerrada, escrita para poder señalarla cuando reaparezca la tentación:

reposo · oposición · release · cuatro intenciones · Myo real · hardware · `motionPermission` ·
gate de reposo · hold latch · `intentMarkov60/62` · campañas multiseed · DQN, Double DQN,
Dueling, Branching y cualquier espacio de acción discreto.

**Sobre el aliasing de acción:** si vuelve a aparecer en E3, la primera hipótesis es
`actionCommandScale` o `actionCommandLevels`, **no** el algoritmo. Y el experimento correcto sería
una ablación de niveles de cuantización con TD3 — 8 niveles contra 4 contra 2 — no cambiar de
agente. Cambiar de algoritmo para resolver un problema de configuración ya se intentó una vez, en
ETAPA 12, y se construyó sobre un `actionCommandScale = 0.2510` que nadie cuestionó durante tres
etapas.

---

## Resumen de coste

| Etapa | Episodios | Sesiones de Claude Code | Puede cerrar la tesis |
|---|---|---|---|
| E0 | 0 | 1–2 | sí (si la planta está rota) |
| E1 | 0 | 2–3 | sí |
| E2 | 0 | 1 | no |
| E3 | 600 (×3 semillas si pasa) | 2 | sí |
| E4 | 600 por variante | 1–2 | no |

Total antes de la primera decisión de fondo: **cero episodios de entrenamiento**. Ése es el cambio
respecto a la rama anterior, donde se entrenó antes de saber qué contenían los datos.
