# PREREGISTRO — SANDBOX S1 + S2

> Se completa y se commitea ANTES de ejecutar nada en MATLAB. No se edita después de ver
> resultados; si hay que cambiarlo, se añade una sección "Enmienda" fechada y justificada.
>
> Cubre **sólo S1 (replay canónico) y S2 (visor cinemático)**. La identificación dinámica
> (S4) exige su propio preregistro, con sus propios umbrales, escrito antes de ajustar
> ningún parámetro.

Fecha de redacción: 2026-09-06 · Autor del sandbox: sesión separada, worktree
`ProtesisPracticas_physics_sandbox`.

## 1. Pregunta

¿Se puede reproducir un episodio development con el pipeline auditado y dibujar su `q(t)`
en 3D sin alterar ninguna magnitud del pipeline?

## 2. Hipótesis

- **H1**: el replay del sandbox reproduce la ruta B de E2A con igualdad exacta, y el visor
  es una función determinista de `q` que no modifica estado, acción, tiempo ni planta.
- **H0** (lo que se acepta si H1 falla): el sandbox introduce alguna diferencia; entonces
  la causa está en la integración del sandbox y **no** se toca ni el modelo ni la planta
  hasta encontrarla.

## 3. Qué se mide

| Métrica | Cómo se calcula | Dónde queda registrada |
|---|---|---|
| `maxStateDiff` | `max|estado_sandbox − estado_E2A_B|` sobre `n+1` estados | `results/s1_canonical_replay/s1_summary.json` |
| `maxRawActionDiff`, `maxEffectiveActionDiff`, `maxPwmDiff` | ídem sobre `n` acciones | mismo archivo |
| `maxQDiff` | ídem sobre `n+1` posiciones | mismo archivo |
| `CANONICAL_REPLAY_MATCH` | `EXACT` / `MISMATCH` / `REFERENCE_ABSENT` | mismo archivo |
| Determinismo del visor | `isequal(pose(q), pose(q))` tras pasar por otra `q` | `testSandboxViewerDeterminism` |
| Rigidez de segmentos | `max|‖Δjunta‖ − longitud declarada|` sobre 11 flexiones | mismo test |
| Monotonía visual | `diff(flexión) ≥ 0` y punta que no se auto-invierte, 25 muestras × 4 motores | mismo test |
| Neutralidad del visor | rollout de planta con y sin visor intercalado | `testSandboxReplayStateContract` |
| Intocabilidad histórica | tamaño y fecha de 13 archivos críticos antes/después | mismo test |
| Equivalencia sub-paso | `max|q_fino_final − q_paso_histórico|` | `testSandboxCanonicalAdapterRegression` |
| Contraste cruzado de planta | `max|MATLAB − fixture Python|` sobre 1176 casos | mismo test |

## 4. Umbral de decisión ← escrito ANTES de correr

- **SIGUE a S3/S4** si y sólo si se cumple **todo**:
  1. `CANONICAL_REPLAY_MATCH = EXACT` en los episodios ejecutados, con las cinco
     diferencias máximas **exactamente 0**.
  2. Las tres suites del sandbox pasan **sin fallos ni incompletos**.
  3. Los tests base de E0P y E2A **siguen pasando** en la misma sesión de MATLAB.
  4. `max|q_fino_final − q_paso_histórico| = 0`.
  5. Los 13 archivos históricos protegidos conservan tamaño y fecha.
- **PARA** si `CANONICAL_REPLAY_MATCH = MISMATCH`, o si algún test base de E0P/E2A que hoy
  pasa deja de pasar. En ese caso no se sigue a S4 y se busca la causa en el sandbox.
- **UNVERIFIED (no es aprobado)** si `causal_trajectories.mat` no está disponible: el
  replay se ejecuta pero **G1 no se declara aprobado**; queda pendiente de referencia.
- **VUELVE a S0** si la auditoría de recepción no cuadra: `BASE_SHA` distinto del esperado,
  worktree no aislado, o cambios sin commitear en el worktree base.

Ninguno de estos umbrales es ajustable después de ver los datos. Todos son de tipo
"igualdad exacta" o "cero fallos": no hay margen que pueda moverse a conveniencia.

## 5. Baselines

No aplican en S1/S2: **no se mide calidad de control**. `u = 0`, control P y las
comparaciones con Agent7250 son obligatorias en cuanto se toque tracking, es decir a partir
de S5/S6, y se preregistrarán entonces. Escribirlo aquí evita la tentación de leer la
animación como si fuera un resultado de control.

## 6. Datos

- Sujetos: sólo DEVELOPMENT (`BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE,
  JONATHAN, KHAROL`). Episodio por defecto: DENIS, repetición 1, lados 1 y 2.
- **MATEO / SANDRA: no se cargan.** El rechazo ocurre antes de cualquier I/O y hay test.
- Semilla: `20260905`, la misma de E2A, para que la comparación sea legítima.
- Actor: Agent7250 congelado, CPU, sin exploración, `getAction(actor,{state})`.
- No hay escaler que ajustar en esta fase: no se entrena nada.

## 7. Qué NO se toca en esta etapa

`src/@Env` completo · `src/@SimController/prosthesis_simulator.m` ·
`pattern_curve.mat` · `plant_limits_canonical.csv` · `fit_C2.mat` · reward y sus pesos ·
`config/configurables.m` y `config/definitions.m` · `agents/agentTd3.m` · checkpoints ·
dataset Denis · `analysis/paired_reference/e2a_results/` (sólo lectura) · la rama
`experiment/no-glove-paired-reference-td3`.

El override de configuración que usa el replay es **temporal**, idéntico al de E2A, y se
restaura con `onCleanup` al salir.

## 8. Coste estimado

Un episodio son 8-10 pasos de control. S1 sobre DENIS (dos lados) es del orden de segundos
más la carga del checkpoint. Las tres suites del sandbox: minutos. Los tests base de E0P +
E2A: los que ya costaban. Sin entrenamiento, sin campañas.

## 9. Resultado (se rellena después de ejecutar)

```
BASE_SHA =
BRANCH =
WORKTREE =
BASE_TESTS =                 (E0P + E2A antes de tocar nada)
CANONICAL_REPLAY_MATCH =
MAX_STATE_DIFF =
MAX_RAW_ACTION_DIFF =
MAX_EFFECTIVE_ACTION_DIFF =
MAX_PWM_DIFF =
MAX_Q_DIFF =
VIEWER_INPUT_UNITS =
VIEWER_DETERMINISTIC =
SUBSTEP_ENDPOINT_ERROR =
CROSS_LANGUAGE_PLANT_DIFF =
PROTECTED_FILES_UNCHANGED =
GLOVE_USED_AS_PLANT_STATE = NO
MATEO_SANDRA_USED = NO
RL_EXECUTED = NO
FILES_CHANGED =
TESTS =
COMMIT =
PUSH = NO
```

## 10. Veredicto

SIGUE / PARA / VUELVE — se escribe después, contra el umbral del §4.
