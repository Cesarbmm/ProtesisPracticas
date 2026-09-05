# ETAPA E0 — Cierre formal

**Fecha:** 2026-09-04 · **Rama:** `experiment/no-glove-paired-reference-td3`
**Autorización de la Enmienda 2 (opción A):** César, 2026-09-04.

---

## 1. Estado de los gates

```
GATE_GLOBAL_ORIGINAL              = FAIL
monotonicityFailuresTotalAfterFix = 28
GATE_OPERATIVO                    = PASS
monotonicityFailuresOperational   = 0
```

El gate global se registró **antes** de medir, evaluaba todo el barrido y falló. Sigue fallando
después del fix. **No se reescribe.** El gate operativo se añadió **después** de ver los datos, con
la justificación completa en la Enmienda 2 del preregistro. Los dos deben citarse juntos.

Los 28 fallos residuales están acotados a motor 3 / `closing` / duración de estrés de 3.0 s, un
régimen que `Env` no produce nunca. Pasan a `BACKLOG.md` como
`MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION`, sin tocar la curva experimental.

---

## 2. Hallazgos de planta fijados como hechos medidos

**Antes del fix**

- 73 de 1176 casos del paso operativo se movían en dirección contraria al comando.
- Coincidencia **exacta** con las 73 búsquedas de `x_0` que no encontraban punto dentro de la curva,
  con idéntica distribución por motor y signo (M1 7/10, M2 7/17, M3 7/11, M4 7/7 en
  opening/closing).

**Después del fix**

- 0 fallos en el paso operativo.
- 28 fallos sólo en el estrés de 3.0 s, motor 3 `closing`.
- 146 de 2352 casos (6.2 %) cambian de resultado.

**Comportamiento nuevo, fijado**

- Si la búsqueda no encuentra posición dentro del recorrido de la curva → **HOLD** (mantener
  posición).
- **No** saltar al extremo de la curva.
- Verificado que el fallo ocurre siempre en el extremo lejano, nunca en el cercano, así que HOLD es
  correcto en ambas direcciones.
- Test de regresión: `tests/paired_reference/testPairedReferencePlantHoldOutsideCurve.m`.

**Resolución de la planta, fijada**

- `pattern_curve` muestreada a ≈ 1 ms.
- `params.period = 0.2 s` → un paso avanza `delta_ms = 200` índices.
- Un paso recorre entre **12.7 %** (PWM 64, closing) y **47.2 %** (PWM 255, opening) de la carrera.
- A PWM altos, uno o dos pasos agotan gran parte de la carrera.
- Destinos distinguibles desde 21 posiciones iniciales, mediana por motor: M1 12.5 · M2 **2** ·
  M3 6 · M4 **1**.

> **Esto es documentación, no autorización.** No habilita tocar `speeds`, `actionCommandLevels`,
> `params.period`, la reward ni TD3. Cualquiera de esos cambios necesita su propio preregistro.

---

## 3. A.1 — Curve Fitting Toolbox y reproducibilidad

### 3.1 Lo que está verificado sobre el archivo

Inspección binaria de `matlab_code/src/@SimController/fit_C2.mat`
(MD5 `067db7fe2c1a3c2029c47258f2761282`, idéntico en las tres copias del repo en disco):

| | |
|---|---|
| variables | `params`, `tail_length` |
| `tail_length` | 150 |
| campos de velocidad | `sp_3F sp_5F sp_7F sp_9F sp_BF sp_DF sp_FF` — 7, **no existe `sp_zeroF`** |
| estructura | `params.(sp).(dir).(m_i).{ws, min_lim, max_lim}` → 7 × 2 × 4 = 56 |
| **`ws` almacenado** | objeto **MCOS de clase `cfit`** (Curve Fitting Toolbox) |
| `min_lim` / `max_lim` | escalares (p. ej. `m_1 / sp_3F / closing` → 0 y 17016) |

### 3.2 Lo que MATLAB reportó en la ejecución de E0

```
nNumericWs      = 56      -> las 56 entradas se leyeron como NUMERICAS
nCurveFallback  = 56      -> y con numel(ws) == 0, es decir VACIAS
```

Un objeto `cfit` no es numérico y su `numel` vale 1. La lectura consistente es que, **en el momento
en que se ejecutó E0**, esta instalación de MATLAB no podía instanciar la clase `cfit` y cargó los
objetos como `[]`.

**Cambio de estado conocido:** César instaló Curve Fitting Toolbox **después** de esa ejecución. Los
números de E0 corresponden por tanto a un entorno **sin** la toolbox.

### 3.3 Qué rama del simulador se ejecuta

En `prosthesis_simulator.m`:

```matlab
ws_len = numel(ws);
useCurveFallback = ws_len == 0;
if useCurveFallback
    ws = curve;  ws_len = curve_len;     % rama medida en E0
end
...
x_0 = max(1, min(x_0, ws_len));
idx = max(1, min(round(x_0 + delta_ms*t), ws_len));
t_i(t) = ws(idx);
```

| entorno | `numel(ws)` | `useCurveFallback` | `ws_len` | resultado |
|---|---|---|---|---|
| sin Curve Fitting Toolbox (E0) | 0 | **true** | `curve_len` (424–1576) | recorre la curva media; hay dinámica |
| con Curve Fitting Toolbox | 1 | **false** | **1** | `idx` colapsa a 1 en todos los pasos → `t_i = ws(1)`, constante |

Esa segunda columna es aritmética del código, no una hipótesis: con `ws_len = 1`, tanto
`max(1, min(x_0, 1))` como `max(1, min(idx, 1))` valen 1 para cualquier entrada.

**Consecuencia inmediata:** re-ejecutar E0 ahora, con la toolbox ya instalada, **no produciría
números comparables**. No re-ejecutes E0 sin fijar antes el contrato de la sección 3.5.

### 3.4 Lo que NO se afirma

No se afirma nada sobre qué toolboxes había instaladas cuando se entrenó `Agent7250` ni las
campañas de 12k/20k/50k. No existe registro de la configuración de toolboxes junto a esos
checkpoints. La única conclusión que los datos soportan es:

> **La reproducción histórica de la planta puede depender de la disponibilidad de Curve Fitting
> Toolbox, y esa dependencia no quedó registrada junto al checkpoint.**

No se reconstruye `fit_C2.mat`. No se inventan datos.

### 3.5 Contrato reproducible de la nueva línea

```
CANONICAL_PLANT_SOURCE_NEW_LINE = pattern_curve.mat
  MD5 pattern_curve.mat  = 3fd6ff436d1a7c209d70ab8ea9f911ba
  MD5 fit_C2.mat         = 067db7fe2c1a3c2029c47258f2761282   (presente, no utilizable hoy)
  MD5 normValues.mat     = 650ac152f78b3840872aa92b3806b2aa
```

La física de E1–E3 **no puede cambiar según una toolbox opcional**. Los 56 `ws` son inutilizables en
esta instalación, y en una instalación con la toolbox el clamp los vuelve degenerados. En ambos
casos la única fuente de dinámica utilizable hoy es `pattern_curve.mat`, y así queda fijada.

### 3.6 Cambio de código propuesto — DEMOSTRADO, NO APLICADO

Hoy la elección de rama es una **dependencia silenciosa de toolbox**. Para eliminarla haría falta
un cambio de una línea:

```diff
- useCurveFallback = ws_len == 0;
+ % La rama de dinamica se fija por configuracion, no por el resultado de
+ % cargar un objeto de una toolbox opcional.
+ useCurveFallback = ws_len == 0 || configurables("forcePatternCurvePlant");
```

más un parámetro nuevo en `configurables.m`:

```matlab
params.forcePatternCurvePlant = true;   % contrato E1-E3 de la linea paired-reference
```

**Qué cambiaría exactamente:**

| escenario | hoy | con el cambio |
|---|---|---|
| esta máquina, antes de instalar CFT | `pattern_curve` | `pattern_curve` — **byte-idéntico** |
| esta máquina, ahora con CFT | `ws` (colapso a constante) | `pattern_curve` — igual que E0 |
| otra máquina con CFT | `ws` (colapso) | `pattern_curve` |
| `main` y ramas históricas | sin cambios | sin cambios (parámetro nuevo, no existe allí) |

**Por qué:** hace que la física sea función de un parámetro versionado en vez de un efecto
colateral del entorno, y deja los números de E0 reproducibles en cualquier máquina.

**Riesgo:** la planta de esta rama pasa a diferir explícitamente de la de `main` en una máquina con
CFT. Eso es exactamente lo que se quiere, pero debe quedar escrito en cada informe.

**Estado: NO APLICADO.** Requiere tu autorización.

---

## 4. A.3 — Condiciones de cierre

```
PLANT_OPERATIONAL_GATE      = PASS
DATASET_SCOPE_DEFINED       = YES    7420 pares, 12 sujetos, sin reposo etiquetado
LAG_RANGE_DEFINED           = YES    k in [-2, +2], hipotesis primaria k = 0
SUBJECT_SPLIT_FROZEN        = YES    Enmienda 3
TOOLBOX_DEPENDENCY_RECORDED = PARCIAL
```

`TOOLBOX_DEPENDENCY_RECORDED` queda en **PARCIAL** hasta ejecutar
`run_paired_reference_stage0_toolbox_manifest.m`, que captura `ver`,
`license('test','Curve_Fitting_Toolbox')`, `which cfit -all`, la inspección de los 56 `ws` y los
hashes, y los guarda en `Agentes/paired_reference/stage0/stage0_toolbox_manifest.{mat,txt}`.

Es la única pieza que falta para el cierre completo. Todo lo demás está fijado.

### Rango temporal

```
k ∈ [-2, +2]     k = 0 como hipotesis primaria
```

No se asume retardo causal fijo: la mediana medida fue exactamente 0 y hubo valores positivos y
negativos, algunos no físicos. El rango es una cota de búsqueda, no una estimación.

### Split congelado

```
TRAIN      : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE
VALIDATION : JONATHAN, KHAROL
TEST       : MATEO, SANDRA
```
