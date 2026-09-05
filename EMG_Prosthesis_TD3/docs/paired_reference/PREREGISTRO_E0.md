# PREREGISTRO — ETAPA E0

**Rama:** `experiment/no-glove-paired-reference-td3` (creada en `main` = `6b213ba5`)
**Fecha de registro:** 2026-09-04
**Estado:** registrado, pendiente de ejecución

> Este documento se escribió **antes** de ejecutar nada. Los umbrales de la sección 4 no se
> modifican después de ver resultados; si hay que cambiarlos, se añade una sección "Enmienda"
> fechada y justificada.

---

## 1. Pregunta

¿La planta de `main` es físicamente consistente, y qué contiene realmente el dataset Denis?

## 2. Hipótesis

- **H1a** — La planta de `main` produce trayectorias monótonas en la dirección comandada para todo
  motor, todo nivel PWM y toda posición inicial.
- **H1b** — El dataset contiene únicamente pares `closing`/`opening`, sin reposo etiquetado, sin
  MVC/P95 y sin calibración por sesión.
- **H0a** — Existen combinaciones (motor, PWM, posición inicial) donde la planta produce saltos no
  físicos o movimiento en dirección contraria.
- **H0b** — El dataset contiene información de reposo o calibración que la rama anterior no usó.

## 3. Qué se mide

| Métrica | Cómo se calcula | Dónde queda |
|---|---|---|
| `nCurveFallback` | combinaciones (velocidad × dirección × motor) con `ws` vacío | `results.plant.map` |
| `nInexactLevels` | niveles de `actionCommandLevels` que no caen exactos en `SIM_SPEEDS` | `results.plant.speedSnapping` |
| `nSearchFailures` | veces que la búsqueda de posición inicial no encuentra punto y `x_0` arranca al final de la curva | `results.plant.initialSearch` |
| `nMonotonicityFailures` | casos del barrido con dirección incorrecta | `results.plant.sweep` |
| `nCrossTalk` | casos donde comandar un motor movió a otro | `results.plant.sweep` |
| `nJumpFlags` | pasos con \|Δq\| > 1.5 × mayor incremento de la trayectoria de referencia | `results.plant.sweep` |
| `nPairs`, tamaños, desfases | inventario por registro | `results.dataset.records` |
| `metadataFields` | unión de campos de metadata de los 12 sujetos | `results.dataset` |
| `lag.kRange` | p10–p90 del retardo EMG→movimiento, en pasos de control | `results.lag` |

**Barrido:** 4 motores × 7 niveles PWM no nulos × 2 signos × 21 posiciones iniciales × 2 duraciones
(0.2 s operativa y 3.0 s de forma) = **2 352 llamadas** al simulador. Segundos de MATLAB.

**Umbral de salto:** `jumpFactor = 1.5`, aplicado sobre el mayor incremento de una muestra presente
en la propia trayectoria de referencia `ws` (o `avg` cuando hay fallback). El umbral se deriva de los
datos, no de una intuición.

## 4. Umbral de decisión ← fijado antes de correr

- **SIGUE a E1** si `nMonotonicityFailures == 0` **y** `nCrossTalk == 0` **y** `nJumpFlags == 0`,
  y el dataset confirma H1b.
- **PARA y corrige** si cualquiera de los tres contadores es > 0. Se propone el fix mínimo, se
  aplica, se re-corre el barrido completo, y sólo entonces se pasa a E1. El fix se commitea por
  separado y se documenta en `DECISIONES.md`.
- **VUELVE a discusión** si el dataset resulta contener reposo etiquetado o calibración: eso
  cambiaría el alcance de toda la línea.

`nSearchFailures > 0` **no** es por sí solo motivo de parada: es diagnóstico. Sólo importa si va
acompañado de fallos de monotonicidad o de saltos. Se registra el número exacto para poder citarlo.

## 5. Baselines

No aplica: E0 no entrena ni compara controladores.

## 6. Datos

- Sujetos: los 12 de `params.dataset` (BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE,
  JONATHAN, KHAROL, MATEO, SANDRA).
- Semilla: `20260904`, sólo para elegir los 240 registros del muestreo de lag.
- Tasas asumidas: EMG 200 Hz, guante 10 Hz (`RecordedGlove.samplingRate`). La asunción se declara
  como parámetro y se contrasta contra `metadata`.

### Regla de splits (E0.4) — se fija aquí, se congela al final de E1

No se eligen sujetos de test todavía, y esto es deliberado: elegirlos ahora es elegirlos a ciegas,
y elegirlos después de ver resultados es cherry-picking.

**Regla:** E1 se evalúa con **leave-one-subject-out** sobre los 12 sujetos. Al terminar, se ordenan
los sujetos por error del decoder y se toman como **test** los 2 sujetos cuyo error queda más cerca
de la mediana, y como **validation** los 2 siguientes más cercanos a la mediana. El resto es train.
Esto evita tanto el test más fácil como el más difícil, y queda determinado por una regla escrita
antes de ver un solo número. El resultado se congela en `config/pairedReferenceSplits.m` y se usa
**igual** en E3.

## 7. Qué NO se toca en esta etapa

`Env`, `calculateState`, `step`, la reward, la interfaz de acción, los agentes, los checkpoints, la
configuración, y el simulador — salvo el fix mínimo que autorice explícitamente la sección 4.

Sin `git push`. Sin entrenamiento. Sin agentes nuevos.

## 8. Coste estimado

0 episodios de entrenamiento. Minutos de MATLAB.

## 9. Cómo se ejecuta

```matlab
cd('<repo>/EMG_Prosthesis_TD3/matlab_code')
addpath(genpath(pwd))

% tests bloqueantes primero
runtests("tests/paired_reference/testPairedReferenceStage0PlantSanity")

% auditoria completa
results = run_paired_reference_stage0_audit();

% o por partes
results = run_paired_reference_stage0_audit(part="plant");
results = run_paired_reference_stage0_audit(part="dataset");
```

Salida: `Agentes/paired_reference/stage0/stage0_audit_results.mat`.

## Enmienda 1 — 2026-09-04, antes de ejecutar

Al preparar los entregables se inspeccionó `fit_C2.mat` y se encontró que
`params.(sp).(dir).(m).ws` es un objeto `cfit`, no un vector muestreado. Ver
`02_HALLAZGO_PLANTA.md`. Esto se registra **antes** de ejecutar nada y modifica el preregistro así:

**Se añade el bloque E0.0** — interfaz de la dinámica: clase y tamaño de `ws`, si el clamp
`idx = max(1, min(idx, ws_len))` colapsa a 1, y si el arreglo mínimo propuesto sería viable.

**Se añaden dos métricas:**

| Métrica | Qué mide | Dónde |
|---|---|---|
| `nIdxCollapsed` | combinaciones con `numel(ws) <= 1` | `results.dynamics` |
| `nInvariantFinalPosition` | grupos donde la posición final no depende de la inicial | `results.plant` |
| `nEvalMonotone` | combinaciones donde evaluar `ws` sobre el dominio de la curva da un recorrido monótono | `results.dynamics` |

**Cambia el resultado esperado, no el umbral.** El umbral de la sección 4 se mantiene intacto: si
los contadores de fallo son > 0, se PARA y se corrige. Lo que cambia es la predicción: ahora se
**espera** que el gate falle. Se deja escrito de antemano para que un fallo no se reinterprete
después como "el test estaba mal".

**Predicción registrada:** `nIdxCollapsed == 56`, `nCurveFallback == 0`,
`nInvariantFinalPosition == número de grupos`, y `nMonotonicityFailures > 0` para posiciones
iniciales por encima del valor constante de destino.

Si la predicción falla, el hallazgo se retira y se documenta como refutado.

## 10. Resultado

Ejecutado 2026-09-04. Detalle completo en `03_RESULTADOS_E0.md`.

| Métrica | Valor | Umbral |
|---|---|---|
| `nSweep` | 2352 | — |
| `nMonotonicityFailures` | **174** | 0 |
| `nCrossTalk` | 0 | 0 |
| `nJumpFlags` | **6** | 0 |
| `nInvariantFinalPosition` | 76 de 112 | diagnóstico |
| `nCurveFallback` | 56 de 56 | diagnóstico |
| `nInexactLevels` | 1 (255 → 256) | diagnóstico |
| `hasLabelledRest` | 0 | confirma H1b |
| `nPairs` | 7420 | — |
| `lag.kRange` | [−2, +2], mediana 0 | — |

Predicciones de la Enmienda 1: 2 acertadas de 4. `nCurveFallback == 0` y
`nInvariantFinalPosition == 112` fallaron. Conforme a la regla escrita, el hallazgo del `cfit`
queda retirado y `02_HALLAZGO_PLANTA.md` marcado como refutado.

Causa raíz identificada con correlación 1:1: 73 búsquedas de `x_0` sin punto encontrado = 73 fallos
de monotonicidad en el paso operativo, con distribución idéntica por motor y signo.

## 11. Veredicto

**PARA Y CORRIGE.**

`nMonotonicityFailures = 174 > 0` y `nJumpFlags = 6 > 0`. El umbral de la sección 4 se aplica sin
reinterpretación: se propuso el fix mínimo (mantener posición cuando la posición queda fuera del
recorrido de la curva), se aplicó, y queda pendiente re-ejecutar el barrido completo.

Efecto medido del fix por replicación validada: paso operativo de 73 fallos a 0.

Queda abierta una decisión de alcance del gate (sección 8 de `03_RESULTADOS_E0.md`): restringirlo al
régimen operativo mediante Enmienda 2, o mantenerlo global. No se toma sin autorización explícita.

---

## Enmienda 2 - 2026-09-04, **DESPUES de observar los datos**

> Esta enmienda se decidio **despues** de ejecutar E0 y ver los resultados. No es una aclaracion de
> lo que el preregistro "siempre quiso decir". El gate original evaluaba todo el barrido y **fallo**;
> lo que se hace aqui es anadir un segundo gate, mas estrecho, y justificar por que es el relevante.
> Ambos quedan registrados.

**Autorizada por Cesar el 2026-09-04 (opcion A).**

### Lo que NO se toca

```
GATE_GLOBAL_ORIGINAL              = FAIL
monotonicityFailuresTotalAfterFix = 28
```

El gate global, tal como se registro antes de medir, fallo y sigue fallando despues del fix. Ese
hecho no se borra ni se reescribe.

### Lo que se anade

```
GATE_OPERATIVO                    = PASS
monotonicityFailuresOperational   = 0
```

### Justificacion

Los 28 fallos restantes ocurren **exclusivamente** en:

- motor 3
- direccion `closing`
- duracion de estres de 3.0 s

La duracion de 3.0 s **no la produce `Env` en operacion normal**: cada paso del entorno avanza
`duration = params.period = 0.2 s`, que con `sampling_period = 0.14` da `n_points = 1`. La duracion
larga fue un caso de estres anadido al disenar el barrido, no un regimen real.

La causa de esos 28 casos es que la **propia curva de referencia** de motor 3 en cierre no es
monotona. Es un defecto del dato de caracterizacion, no del codigo de control. Pasa a `BACKLOG.md`
como `MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION`, **sin modificar todavia la curva
experimental**.

### Efecto sobre el criterio de cierre

E0 cierra con `GATE_OPERATIVO = PASS`. El gate global queda registrado como FAIL y su resolucion
queda pendiente en el backlog. Cualquier informe posterior que cite E0 debe citar los dos.

---

## Enmienda 3 - 2026-09-04, congelacion del split

> Tambien posterior a los datos de E0, aunque **independiente de ellos**: no usa ningun resultado de
> modelado.

La regla de la seccion 6 decia elegir como test los 2 sujetos cuyo error LOSO quedara mas cerca de la
mediana. Al ir a aplicarla aparecio un defecto: **esa regla selecciona el conjunto de test usando
errores medidos sobre los propios sujetos de test**. Aunque evita el cherry-picking de extremos, no
produce un test limpio.

Se sustituye por una regla determinista e **independiente de los datos**, fijada antes de entrenar
nada:

> Ordenar los 12 sujetos alfabeticamente. Los 8 primeros son train, los 2 siguientes validation, los
> 2 ultimos test.

```
TRAIN      : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE
VALIDATION : JONATHAN, KHAROL
TEST       : MATEO, SANDRA
```

`k`, `lambda` y la seleccion de modelo se resuelven **solo** con train + validation. El test se
ejecuta una vez, al final.

Como analisis secundario de robustez se permite LOSO **restringido a los 10 sujetos de
train+validation**; nunca sobre los de test, y nunca para seleccionar nada.
