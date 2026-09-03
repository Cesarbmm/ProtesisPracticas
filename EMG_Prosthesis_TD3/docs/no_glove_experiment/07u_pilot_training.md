# ETAPA 7U — auditoría del pipeline de entrenamiento y piloto de 500 episodios

Fecha: 2026-09-03. Depende de la confirmación en lazo cerrado
(`07u_motion_permission_ablation.md` §4).

## 1. Auditoría del pipeline de entrenamiento (verificada en código)

Se inspeccionó directamente el código fuente del toolbox de RL de MATLAB
(no solo el de este repositorio):
`toolbox/rl/rl/+rl/+env/+internal/MATLABSimulator.m`, función
`simInternal_` (líneas ~104-124):

```matlab
act = evaluateAction(expProcessor,obs);   % salida del actor (con ruido si entrena)
[nobs,rwd,isd] = step(this,act);          % this=Env; act se pasa sin modificar
exp.Action = rl.util.cellify(act);        % <- exactamente `act`, u_actor_raw
exp.Reward = rwd;                          % <- refleja la ejecución YA gateada
```

**Confirmado, no solo inferido:** `exp.Action` (lo que el critic aprende
como "acción") es exactamente `u_actor_raw` — se captura ANTES de llamar a
`step()`, y `Env.step` sólo modifica la variable local `warpedAction`
(nunca el argumento `action`), así que el gate es invisible para el
mecanismo de registro de experiencias. `exp.Reward`/`exp.NextObservation`
sí reflejan la ejecución real (gateada). Esto es internamente coherente:
critic y actor aprenden sobre el mismo espacio de acción (`u_raw`), y la
recompensa/siguiente estado corresponden genuinamente a lo que el
entorno hizo con esa acción — exactamente como MATLAB maneja cualquier
transformación determinista interna al entorno (clipping, cuantización).

Verificado además en `EMG_Prosthesis_TD3/matlab_code/src/reward_functions/trackingIntentActionRateReward.m`:
el reward usa `effectiveAction` (post-gate), nunca `u_raw` — confirmado
también por un test determinista nuevo
(`testRewardUsesGatedActionNotRawAction`, `actionL2` en el reward es
exactamente 0 cuando el permiso está inactivo, sin importar cuán grande
sea `u_raw`).

**Consecuencia correcta, no un bug:** durante pasos con permiso inactivo,
el reward no depende de la magnitud de `u_raw` (porque `effectiveAction=0`
siempre ahí), así que el crítico no recibe gradiente que penalice o
premie `u_raw` específicamente en esos pasos — el actor no "aprende" nada
sobre esas transiciones. Esto es exactamente la intención de la
arquitectura: dejar de exigirle al actor que aprenda a no moverse en
reposo, porque el permiso ya lo garantiza estructuralmente.

**Limitación real y esperada (no corregida, porque es inherente al
diseño pedido):** el entorno responde de forma distinta a un mismo
`u_raw` según el estado OCULTO del gate (`onCount`/`offCount`), que no
está en `state60` ni se pasa al actor. Esto es observabilidad parcial
acotada — TD3 tolera bien este tipo de ruido no-Markoviano moderado, y
es justamente lo que la arquitectura pide (el actor NO debe saber si está
permitido).

**Registros verificados, todos ya disponibles por separado:**
`actionLog` (`u_actor_raw`), `actionWarpLog` (`u_requested`, post-gate
pre-cuantización), `actionSatLog` (`u_effective`), `actionPwmLog` (PWM),
`motionPermissionLog`, `rewardLog`/`rewardInfoLog`. `EpisodeQ0` (valor
del crítico en el estado inicial de cada episodio) se obtiene sin ningún
cambio al entrenamiento vía `trainingInfo.EpisodeQ0` (objeto
`rl.train.rlTrainingResult` devuelto por `train()`) — antes se
descartaba; se corrigió para guardarse (`training_info.mat` +
`training_metrics_per_episode.csv`). Pérdidas de actor/crítico por paso
NO están expuestas nativamente por `train()` para TD3 (sólo para agentes
MBPO) — no se fuerza una extracción no soportada.

**No se encontró ningún mismatch acción/reward/replay.** No se requirió
ningún cambio de código en `Env`/`step`/reward para la coherencia causal
del pipeline de aprendizaje — sólo se corrigió el registro de
`trainingInfo` (antes descartado) y se añadió el test de coherencia del
reward.

## 2. Piloto: 500 episodios, `motionPermissionEnabled=true` desde episodio 1

Actor nuevo desde cero (no Agent200), semilla 11, checkpoints cada 100
episodios. Corrida:
`Agentes\no_glove_intent_control\stage7u_pilot_training\2026-09-03_00-25-46-785`.

### 2.1 Salud del aprendizaje

| | ep 1-50 | ep 51-100 | ep 226-275 | ep 451-500 |
|---|---|---|---|---|
| reward medio | −11.69 | −6.80 | −5.56 | **−1.94** |
| trackingMse (entrenamiento) | 0.137 | — | — | **0.025** |
| Q0 medio (crítico) | 0.17 | −0.31 | −1.06 | −0.70 |

Reward y `trackingMse` mejoran de forma monótona y sustancial a lo largo
del entrenamiento — curva de aprendizaje sana. `Q0` fluctúa (normal a
mitad de entrenamiento) sin señales de divergencia (sin NaN/Inf, sin
errores de las numerosas aserciones de finitud de `Env`).

### 2.2 El gate se sostuvo perfectamente durante TODO el entrenamiento

`restPwmNonZeroFraction = 0.000000` en las 100 muestras de episodios de
entrenamiento guardadas (episodios 5 a 500) **y** en las 50 evaluaciones
finales deterministas. Cero excepciones. El permiso nunca dejó pasar PWM
no solicitado, ni al inicio (actor sin entrenar, acciones esencialmente
aleatorias) ni al final.

### 2.3 Comparación contra Agent200 + `motionPermission` (el baseline correcto)

| Métrica (test final, 50 episodios deterministas) | Agent200+gate (ya validado) | Agent500 nuevo (piloto) |
|---|---|---|
| `trackingMse` | 0.0097 | 0.0137 (peor) |
| `actionL2` efectivo | 0.1220 | 0.4342 (peor, ~3.6×) |
| `restPwmNonZeroFraction` | 0 | **0** (igual) |
| `activeStepFraction` | 0.4754 | 0.4754 (idéntico, esperado) |
| intervenciones de seguridad (50 ep) | — | 3200 |

**El agente nuevo de 500 episodios todavía NO alcanza a Agent200+gate.**
Esto es esperado, no una falla: Agent200 es el checkpoint final de una
corrida histórica de 200 episodios SIN gate (densidad de gradiente
completa en cada paso); el piloto, con gate activo desde el episodio 1,
recibe señal de aprendizaje efectiva sólo en ~47.5% de los pasos (los
activos) — un presupuesto de aprendizaje efectivo comparable, no mayor,
pese a más episodios nominales. La curva de reward/trackingMse sigue
mejorando con pendiente clara al episodio 500, sin meseta.

## 3. Veredicto del piloto

`PILOT_TRAINING = PASS` como verificación de sanidad (que es el único
objetivo declarado de este piloto): sin mismatch, sin divergencia, el
control activo sigue aprendiendo, el gate no destruye información y se
sostiene perfectamente durante el entrenamiento real. NO se declara que
el piloto ya iguale o supere a Agent200+gate — no era su objetivo, y no
lo logra todavía. Esto justifica, no contradice, pasar a una campaña
larga con más presupuesto de episodios.
