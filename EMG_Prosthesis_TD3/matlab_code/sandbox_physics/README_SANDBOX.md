# README_SANDBOX — cómo ejecutar

Sandbox aislado para **visualización 3D** y **estudio de planta**. No entrena, no toca
`src/@Env` y no hace push. Lee `SANDBOX_PLAN.md` antes de ampliar el alcance y
`PREREGISTRO_SANDBOX.md` antes de ejecutar.

## Orden de ejecución

Abrir **MATLAB nuevo** (las constantes de `Env` se congelan al cargar la clase; E2A aborta
si la sesión ya tenía otra configuración) y situarse en `EMG_Prosthesis_TD3/matlab_code`.

### 0. Gate G0 — los tests base deben pasar ANTES de tocar nada

```matlab
addpath(genpath('src')); addpath('config'); addpath(genpath('lib'));
addpath('analysis/paired_reference'); addpath(genpath('tests'));
baseTests = runtests(fullfile('tests','paired_reference'));
table(baseTests)
```

Si algo que hoy pasa deja de pasar, **parar**: el problema no es del sandbox.

### 1. S1 — replay canónico

```matlab
addpath(genpath('sandbox_physics'));
s1 = runSandboxS1CanonicalReplay(subject="DENIS", sides=[1 2]);
```

Salidas en `sandbox_physics/results/s1_canonical_replay/`:
`s1_summary.json`, `s1_replay_traces.csv`, `s1_replay_trajectories.mat`,
`plant_manifest.json`.

El gate G1 se lee en `s1.CANONICAL_REPLAY_MATCH`:

- `EXACT` → el replay reproduce la ruta B de E2A con diferencia cero. **Aprobado.**
- `MISMATCH` → parar y buscar la causa en el sandbox, no en la planta.
- `REFERENCE_ABSENT` → falta `analysis/paired_reference/e2a_results/causal_trajectories.mat`;
  el replay corre pero **G1 no queda aprobado**.

### 2. S2 — visor cinemático

```matlab
s2 = replayDenisIn3D(subject="DENIS", side=1);      % cierre
s2 = replayDenisIn3D(subject="DENIS", side=2);      % apertura
```

Salidas en `sandbox_physics/results/s2_viewer/`: GIF (si hay Image Processing Toolbox),
PNG por frame y `pose_sequence_*.csv` con `q` y flexión visual por frame.

Uso directo del visor:

```matlab
viewer = HandKinematicViewer(units="encoder");     % o units="normalized"
viewer.update([11176 6665 7509 6280]);
viewer.update(q, gloveNormalizedFlexion);          % overlay opcional, sólo dibujo
```

### 3. Tests del sandbox

```matlab
sandboxTests = runtests(fullfile('sandbox_physics','tests'));
table(sandboxTests)
```

### 4. Rellenar el preregistro y commitear **en local**

`PREREGISTRO_SANDBOX.md` §9 y §10. Después:

```bash
git add sandbox_physics
git commit -m "sandbox: S0 auditoria, S1 replay canonico, S2 visor cinematico"
# NO push
```

## Contrato del visor

| Entrada | Unidad | Regla |
|---|---|---|
| `q` | `units="encoder"` (cuentas) o `units="normalized"` | se **declara**, nunca se adivina |
| `gloveNormalizedFlexion` | normalizada `[0,1]` por motor | sólo overlay; recibirla en cuentas de encoder es un **error** y se rechaza |

`HandKinematicViewer.poseFromQ` es una función pura: misma `q` → misma pose bit a bit, sin
gráficos de por medio. Todo lo geométrico (escala, reparto de falanges, ángulos, abducción)
está marcado `VISUALIZATION_ONLY` en `handKinematicModel.m`: **no** describe la cinemática
real de la prótesis.

## Dos cosas que sorprenden y son correctas

1. **En apertura, la mano no arranca cerrada del todo.** El reset histórico cierra durante
   *un* periodo de 0.2 s, no durante 10000. Ver `AUDITORIA_S0.md` §F1.
2. **La mano nunca se cierra al 100 %.** Las curvas empíricas sólo llegan al 65 / 58 / 90 /
   70 % de los límites de encoder de firmware. Ver `AUDITORIA_S0.md` §F2. Con
   `rangeMode="encoderLimit"` se ve el efecto crudo; con el modo por defecto se normaliza
   contra el recorrido que la planta alcanza de verdad.

## Prohibiciones vigentes

No entrenar · no `git push` · no merge a `paired-reference` ni a `main` · no MATEO/SANDRA ·
no usar el guante como estado de planta · no reconstruir markov52 a mano · no modificar
`pattern_curve.mat` para que encaje con un modelo nuevo · no evaluar una planta por
"verse más suave".
