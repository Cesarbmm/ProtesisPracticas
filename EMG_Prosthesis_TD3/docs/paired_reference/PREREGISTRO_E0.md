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

*(pendiente)*

## 11. Veredicto

*(pendiente — SIGUE / PARA / VUELVE)*
