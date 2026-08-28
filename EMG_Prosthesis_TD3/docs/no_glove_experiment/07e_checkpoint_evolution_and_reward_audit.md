# ETAPA 7E - evolución por checkpoint y auditoría de reward en reposo

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada para determinar si los comandos de reposo observados
en Agent200 ya existían en checkpoints tempranos o emergieron durante el
entrenamiento. Se congelaron Agent50, Agent100, Agent150 y Agent200 y se
evaluaron sobre el mismo corpus de 2200 estados reales `preActivationHold`
extraído en ETAPA 7D. La etapa fue estrictamente offline: no creó `Env`, no
invocó el simulador ni la función de reward, no entrenó, no calculó DTW y no
usó hardware.

## 1. Resultado de la etapa: PASS

La ejecución de ingeniería es **PASS**:

- se localizaron, cargaron, auditaron y hashearon los cuatro checkpoints;
- se verificó que todos son TD3 de 60 observaciones y 4 acciones, con la misma
  arquitectura y 8324 parámetros aprendibles;
- cada actor congelado fue reproducido mediante `getAction` sobre exactamente
  los mismos 2200 estados de reposo previo observados durante entrenamiento;
- todas las salidas se pasaron por la interfaz histórica
  `baselineQuantized`, sin modificarla;
- se mantuvieron separados el replay determinista de checkpoints y los
  `actionLog` históricos, que mezclan una política cambiante con exploración;
- se reconstruyeron solamente los términos de reward realmente registrados;
- no se calculó una reward contrafactual para acciones de otro checkpoint;
- pasaron pruebas unitarias, análisis estático, regresión completa y una
  ejecución reproducida independientemente;
- no se eligió retrospectivamente un checkpoint ganador.

El resultado científico pre-registrado es:

```text
classification=presentFromEarlyCheckpoint
firstActiveCheckpoint=Agent50
earlyCheckpointActive=true
laterCheckpointActive=true
finalCheckpointActive=true
materialAttenuation=false
rootCauseIdentified=false
```

Agent50, guardado después de 50 episodios, ya produce al menos un comando en
100% de las ventanas y activa 98.9091% de los componentes motor-paso. Agent200
activa 98.3182% de los componentes y 100% de las ventanas. El PWM absoluto
medio baja de 172.827159 a 134.874205, una reducción relativa de 21.9601%, pero
no alcanza el umbral pre-registrado de atenuación material de 25%. Por tanto,
el comportamiento está presente en el primer checkpoint disponible y persiste
en el final.

La clasificación no significa que el problema estuviera presente en la
inicialización: no existe Agent0 y Agent50 ya incorpora 50 episodios de
optimización. Tampoco identifica una causa raíz. La evidencia descarta la
hipótesis estrecha de una aparición únicamente tardía entre Agent100 y
Agent200, pero no separa reward, exploración, inicialización, arquitectura,
datos u optimización.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7E:
  `bbb079aaf44bf0d349b632ae26dd6be5a8b0af8f`;
- commit de código, pruebas, launcher y README registrado en el manifiesto:
  `456de2a4a64b8c0c94818eb924da9b04b8729371`;
- el commit documental que contiene este informe se crea al cierre y se puede
  consultar con `git log -1 --oneline`.

El manifiesto registra `gitTrackedDirty=false`. `gitDirty=true` se debe
exclusivamente a `matlab_code.zip`, archivo local ajeno y no rastreado que se
preservó sin cambios. No se hizo push ni se abrió PR.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage7eCheckpointEvolution.m`:
  validación fail-closed, replay común, métricas por checkpoint/motor/episodio,
  comparación observacional con acciones históricas, auditoría de reward y
  clasificación pre-registrada.
- `matlab_code/tests/no_glove/testNoGloveStage7eCheckpointEvolution.m`: ocho
  pruebas deterministas de las cuatro clasificaciones, separación de fuentes,
  contrato causal y consistencia de reward.
- `matlab_code/workflows/published/run_no_glove_stage7e_checkpoint_evolution.m`:
  launcher reproducible, inventario, hashes, carga de checkpoints, smoke,
  manifiesto y artefactos.
- `docs/no_glove_experiment/07e_checkpoint_evolution_and_reward_audit.md`:
  este informe.

### Modificado

- `matlab_code/workflows/published/README.md`: registro del launcher 7E y sus
  límites de uso.

No se modificaron `Env`, `reset`, `step`, `calculateState`, el decodificador de
intención, el generador de referencia, la reward, `baselineQuantized`, el
simulador, `encoder2Flex`, la seguridad, Agent50/100/150/200 ni Agent7250.

## 4. Decisiones técnicas y justificación

### 4.1 Pregunta experimental y corpus común

ETAPA 7D demostró que Agent200 emite comandos sobre estados reales de reposo
previo de su entrenamiento. ETAPA 7E pregunta cuándo es observable ese
comportamiento en la secuencia de checkpoints publicada.

Se reutilizaron los 2200 estados `preActivationHold`: 11 estados por cada uno
de los 200 episodios. Para una fila del episodio `e` y paso `t>=2`, el contrato
causal de ETAPA 7D exige:

```text
H_e,t = 1[ ||v_ref,e,t||_inf <= 1e-12 ]
        * 1[ ||q_ref,e,t - q_ref,e,t-1||_inf <= 1e-12 ]
```

Además, estos estados ocurren antes de la primera activación de referencia del
episodio. No se equipararon los holds posteriores a reposo fisiológico. El
analizador comprueba nuevamente que `v_ref=0` y que `q_ref` mantiene su valor;
si una fila incumple el contrato, falla con `NonholdState`.

El estado conserva el orden causal de `intentMarkov60`:

```text
s_t = [phi_EMG,t(40), q_t(4), Deltaq_t(4),
       u_eff,t-1(4), q_ref,t(4), v_ref,t(4)]
```

Las 40 features son WMoos estandarizadas. No se interpretaron como amplitudes
físicas, envolventes `[0,1]` ni MVC.

### 4.2 Inventario congelado de checkpoints

| Checkpoint | Episodio | SHA-256 | Pasos del agente |
|---|---:|---|---:|
| Agent50 | 50 | `B456E634D0AC0099EAF0D3DE6599E733E184EB67F3BD4D8B1FDF9BE6F04654BA` | 3050 |
| Agent100 | 100 | `56AB5FD030C5D27E46C671E13D5FB2C8B921E6C5C8B4A36B2C6982FAD04061A3` | 6100 |
| Agent150 | 150 | `93D32E725F6D1C0DA877928CB1CF4B5704F9C0DC9D23543DDA0572BDCB0DC814` | 9150 |
| Agent200 | 200 | `C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973` | 12200 |

Los cuatro checkpoints son `rl.agent.rlTD3Agent`, reciben 60 observaciones,
producen 4 acciones y tienen 8324 parámetros aprendibles. Sus replay buffers
tienen longitud 0 y capacidad 100000. Se verificaron hashes antes y después de
la evaluación; ningún checkpoint fue cargado para entrenamiento.

Agent7250 se mantuvo congelado, no se cargó y conserva SHA-256:

```text
0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

### 4.3 Replay determinista y cuantización

Para checkpoint `k` y estado registrado `s_i` se calculó:

```text
u_raw,i,k = pi_k(s_i)
(u_eff,i,k, PWM_i,k) = baselineQuantized(u_raw,i,k)
```

La ruta del actor usa `getAction` y no ejecuta exploración. La cuantización usa
los valores del perfil efectivo de entrenamiento: límite PWM, umbral de
activación y niveles discretos registrados. No se cambió la interfaz.

Las métricas principales son:

```text
active_i,m,k = 1[ |u_eff,i,m,k| > 0 ]

componentActiveFraction_k
  = mean_i,m(active_i,m,k)

windowAnyCommandFraction_k
  = mean_i( any_m(active_i,m,k) )

saturationFraction_k
  = mean_i,m( 1[|u_eff,i,m,k| >= 0.95] )

meanAbsPWM_k = mean_i,m(|PWM_i,m,k|)
```

La saturación es la fracción de componentes motor-paso que cumplen el umbral;
no significa que los cuatro motores estén simultáneamente al máximo.

### 4.4 Umbrales pre-registrados y clasificación

Antes de observar el resultado se fijaron:

```text
falseActivationLimit = 0.01
materialRelativeAttenuation = 0.25
firstCheckpoint = Agent50
```

Un checkpoint se considera activo si más de 1% de sus ventanas tiene algún
comando. La atenuación relativa se define como:

```text
R_PWM = (meanAbsPWM_Agent50 - meanAbsPWM_Agent200)
        / meanAbsPWM_Agent50
```

La decisión se aplica en este orden:

1. `attenuatesButPersists`: Agent50 y Agent200 activos y `R_PWM>=0.25`;
2. `presentFromEarlyCheckpoint`: Agent50 activo, sin atenuación material;
3. `emergesDuringTraining`: Agent50 inactivo y algún checkpoint posterior
   activo;
4. `checkpointEvolutionUnresolved`: ningún caso anterior.

Con `R_PWM=0.21960063884109118`, la decisión canónica es
`presentFromEarlyCheckpoint`. La reducción no se redondeó antes de compararla
con 0.25.

### 4.5 Separación de acciones históricas

Los `actionLog` de los episodios se conservaron como un flujo observacional
distinto:

```text
u_hist,e,t = política vigente durante el episodio + exploración de entrenamiento
```

No equivalen a la salida determinista de Agent50, Agent100, Agent150 o
Agent200. Para cada bloque de 50 episodios se comparó el log histórico con el
checkpoint guardado al final del bloque sobre esos mismos estados. La fracción
de PWM exactamente igual fue 20.4545%, 27.7273%, 30.2273% y 26.5455%,
respectivamente.

Estas diferencias no aíslan el efecto de exploración: dentro de cada bloque
también cambia la política y solo se conserva el checkpoint final. Por eso el
resultado registra:

```text
historicalActionInterpretedAsDeterministicActor=false
explorationEffectIsolated=false
```

### 4.6 Auditoría matemática de reward registrada

Se extrajeron del perfil efectivo, sin sobrescribir configuraciones globales:

```text
w_q   = 1
w_v   = 0
w_u   = 0.01
w_du  = 0.05
w_sat = 0.02
u_soft = 0.9
```

Para cada fila histórica se reconstruyeron los términos ya registrados en
`rewardInfo`:

```text
C_q,t   = w_q   * trackingMse_t
C_v,t   = w_v   * velocityMse_t
C_u,t   = w_u   * actionL2_t
C_du,t  = w_du  * deltaActionL2_t
C_sat,t = w_sat * softSaturationPenalty_t

r_hat,t = -(C_q,t + C_v,t + C_u,t + C_du,t + C_sat,t)
```

Se comprobaron además el vector de reward por motor, `smoothnessPenalty` y
`saturationPenalty`. El error máximo de auditoría fue
`1.1102230246251565e-16`, compatible con redondeo de doble precisión.

No se sustituyeron las acciones históricas por acciones de checkpoints para
recalcular reward. Tal contrafactual sería dinámicamente inconsistente porque
cambiar una acción altera estados, encoders, acción previa y trayectorias
posteriores. El analizador registra:

```text
counterfactualRewardCalculated=false
rewardFunctionInvoked=false
```

### 4.7 Alcance causal

La participación media de cada término describe el costo observado, no su
efecto causal sobre el aprendizaje. Aunque el costo de posición representa
93.5335% del total registrado y el de acción 3.4380%, esto no demuestra que el
MSE sea la causa raíz única de la saturación ni que aumentar `w_u` vaya a
resolverla. Esa intervención requiere una ablación nueva y controlada.

## 5. Comandos y pruebas ejecutados, con resultados exactos

### 5.1 Análisis estático

Se ejecutó `checkcode(...,'-id')` sobre:

```text
analyzeNoGloveStage7eCheckpointEvolution.m  0 issues
run_no_glove_stage7e_checkpoint_evolution.m 0 issues
testNoGloveStage7eCheckpointEvolution.m     0 issues
```

### 5.2 Pruebas específicas

```matlab
r = runtests('tests/no_glove/testNoGloveStage7eCheckpointEvolution.m');
```

Resultado:

```text
8 passed, 0 failed, 0 incomplete
```

Las pruebas cubren las cuatro decisiones posibles, conservación de la
separación histórica, fallo ante reward inconsistente, fallo ante un estado que
no es hold y orden obligatorio Agent50/100/150/200.

### 5.3 Launcher canónico

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_no_glove_intent_control\EMG_Prosthesis_TD3\matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7e_checkpoint_evolution(struct( ...
  'stage7dRunRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7d_artifacts\stage7d_final\2026-08-27_03-58-12-630', ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7e_artifacts\stage7e_final'));
```

Resultado:

```text
ETAPA 7E CHECKPOINT EVOLUTION PASS
tests=8/8
analysisElapsedSec=3.0882606
output=C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7e_artifacts\stage7e_final\2026-08-27_20-18-42-844
```

### 5.4 Regresión completa

```matlab
r = runtests('tests/no_glove');
```

Resultado:

```text
TOTAL=96 PASS=96 FAIL=0 INCOMPLETE=0
```

El resultado se guardó como `full_no_glove_test_results.mat`, SHA-256:

```text
8241AD1CEB098512508E825EC2F3D27042D5C8F4253A702D604D5EE6270D5B40
```

### 5.5 Reproducción independiente

Se ejecutó el mismo launcher en una raíz distinta:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7e_artifacts\stage7e_repro\2026-08-27_20-22-25-820
```

Resultado:

```text
PASS
tests=8/8
CSV científicos idénticos por SHA-256=19/19
```

Se compararon inventarios, auditorías, resúmenes, componentes de acción,
términos de reward y decisión. Los archivos que contienen timestamp, ruta de
salida o serialización MAT no se exigieron byte-idénticos.

## 6. Métricas y artefactos generados

### 6.1 Evolución agregada sobre el mismo corpus

| Checkpoint | Actividad componentes | Ventanas con comando | Acción cruda abs. media | PWM abs. medio | Saturación |
|---|---:|---:|---:|---:|---:|
| Agent50 | 0.989091 | 1.000000 | 0.662272 | 172.827159 | 0.216477 |
| Agent100 | 0.948295 | 1.000000 | 0.539005 | 145.916250 | 0.265568 |
| Agent150 | 0.871364 | 1.000000 | 0.521267 | 139.263409 | 0.212955 |
| Agent200 | 0.983182 | 1.000000 | 0.524620 | 134.874205 | 0.118523 |

El PWM absoluto medio decrece en cada checkpoint, pero la actividad de
componentes no es monótona: cae hasta Agent150 y vuelve a subir 0.111818 en
Agent200. La saturación también aumenta primero en Agent100 y luego baja. No se
interpreta esta secuencia como mejora uniforme.

Cambios exactos:

| Transición | Delta actividad | Delta PWM abs. medio | Cambio PWM relativo | Delta saturación |
|---|---:|---:|---:|---:|
| 50 -> 100 | -0.040795 | -26.910909 | -0.155710 | +0.049091 |
| 100 -> 150 | -0.076932 | -6.652841 | -0.045594 | -0.052614 |
| 150 -> 200 | +0.111818 | -4.389205 | -0.031517 | -0.094432 |
| 50 -> 200 | -0.005909 | -37.952955 | -0.219601 | -0.097955 |

### 6.2 Evolución por motor

| Checkpoint | Motor | Actividad | Acción cruda abs. media | PWM abs. medio | Saturación |
|---|---:|---:|---:|---:|---:|
| Agent50 | M1 | 1.000000 | 0.857032 | 223.283636 | 0.818182 |
| Agent50 | M2 | 1.000000 | 0.773207 | 196.490455 | 0.047727 |
| Agent50 | M3 | 0.993636 | 0.326504 | 93.541818 | 0 |
| Agent50 | M4 | 0.962727 | 0.692346 | 177.992727 | 0 |
| Agent100 | M1 | 0.953636 | 0.230986 | 75.665455 | 0 |
| Agent100 | M2 | 1.000000 | 0.734517 | 190.506818 | 0.387727 |
| Agent100 | M3 | 0.839545 | 0.510400 | 142.018182 | 0.265455 |
| Agent100 | M4 | 1.000000 | 0.680117 | 175.474545 | 0.409091 |
| Agent150 | M1 | 0.755909 | 0.253785 | 75.985455 | 0 |
| Agent150 | M2 | 0.999545 | 0.608627 | 163.572727 | 0.427273 |
| Agent150 | M3 | 0.730000 | 0.517128 | 139.625455 | 0.389091 |
| Agent150 | M4 | 1.000000 | 0.705530 | 177.870000 | 0.035455 |
| Agent200 | M1 | 1.000000 | 0.494305 | 125.760000 | 0 |
| Agent200 | M2 | 1.000000 | 0.698284 | 181.853182 | 0.474091 |
| Agent200 | M3 | 0.994545 | 0.471593 | 120.974545 | 0 |
| Agent200 | M4 | 0.938182 | 0.434299 | 110.909091 | 0 |

La actividad se redistribuye entre motores. En Agent200, Motor 2 permanece
activo en todos los estados y 47.4091% de sus componentes-paso están en
saturación. Estos son comandos simulados registrados; no demuestran corriente
eléctrica medida.

### 6.3 Acciones históricas durante entrenamiento

| Episodios | Actividad componentes | Ventanas con comando | PWM abs. medio | Saturación |
|---|---:|---:|---:|---:|
| 1-50 | 0.961818 | 1.000000 | 155.761364 | 0.209545 |
| 51-100 | 0.980000 | 1.000000 | 170.446364 | 0.215455 |
| 101-150 | 0.965909 | 1.000000 | 166.532727 | 0.216364 |
| 151-200 | 0.960455 | 1.000000 | 138.242273 | 0.114091 |
| 1-200 | 0.967045 | 1.000000 | 157.745682 | 0.188864 |

Estos valores caracterizan la conducta registrada con política cambiante y
exploración. No se presentan como trayectoria determinista de los checkpoints.

### 6.4 Descomposición de reward observada

| Episodios | Reward media | Posición | Acción | Delta acción | Saturación | Fracción posición |
|---|---:|---:|---:|---:|---:|---:|
| 1-50 | -0.183159 | 0.170051 | 0.004642 | 0.008424 | 0.00004191 | 0.928433 |
| 51-100 | -0.130161 | 0.121401 | 0.005231 | 0.003486 | 0.00004309 | 0.932700 |
| 101-150 | -0.128380 | 0.120421 | 0.005156 | 0.002760 | 0.00004327 | 0.938008 |
| 151-200 | -0.104722 | 0.099214 | 0.003757 | 0.001728 | 0.00002282 | 0.947403 |
| 1-200 | -0.136605 | 0.127772 | 0.004696 | 0.004099 | 0.00003777 | 0.935335 |

En el agregado, las fracciones del costo son:

```text
posición       = 0.935334758470494
velocidad      = 0                  (w_v=0)
acción         = 0.0343795404347555
delta acción   = 0.0300091913596081
saturación     = 0.000276509735142672
```

Son proporciones descriptivas de las trayectorias observadas, no efectos
causales ni sensibilidad del entrenamiento a los pesos.

### 6.5 Integridad y artefactos

Entradas preservadas:

```text
Stage7D manifest SHA-256 = AE782015540903E393A5F2D70E607A739CA3BBBE60634CF97E9EF6CFE00E5957
Stage7D results SHA-256  = B261E7504A74C0A9ECEE64D5A195DCD530207EAEE044337FC87302AAE02C6D92
Stage6 manifest SHA-256 = F27105A62DE2F1EF02B3A0E419A126E0DA6EFD105C6E8ED649D3A3872B9AC0FE
perfil efectivo SHA-256 = 8498E13181B6B37BF0CBB1CBAFD9923F87A858C9338A06C4C4B4FEF94CADC483
episodios entrenamiento = 200/200 hashes preservados
checkpoints             = 4/4 hashes preservados
```

Artefacto canónico:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7e_artifacts\stage7e_final\2026-08-27_20-18-42-844
manifest.json SHA-256       = 8C291DD607872A80C1FB505A27C156A0565B577793E3F945531495F768F206A1
stage7e_results.mat SHA-256 = C989FB0EC45F8A469798CFE7DB32510061F03E7F79F04E58CEB41C2364C2078B
artefactos primarios        = 23/23 con hash
```

Tablas principales:

- inventarios: `training_episode_input_hashes.csv`,
  `checkpoint_input_hashes.csv`, `checkpoint_audit.csv`,
  `training_episode_audit.csv` y `training_profile_audit.csv`;
- replay congelado: `checkpoint_summary.csv`,
  `checkpoint_motor_summary.csv`, `checkpoint_episode_summary.csv`,
  `checkpoint_trend.csv` y `checkpoint_action_components.csv`;
- flujo histórico: `historical_training_summary.csv`,
  `historical_training_motor_summary.csv` y
  `block_end_replay_comparison.csv`;
- reward: `recorded_reward_terms.csv`, `recorded_reward_summary.csv`,
  `recorded_reward_episode_summary.csv` y `reward_audit.csv`;
- decisión y reproducción: `source_decision.csv`, `stage7e_results.mat`,
  `offline_report.md`, `manifest.json` y `reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

1. Agent50 es el primer checkpoint disponible, no una política sin entrenar.
   La aparición exacta entre inicialización y episodio 50 no es observable.
2. Los checkpoints están espaciados cada 50 episodios; no se puede localizar un
   cambio dentro de cada bloque.
3. Solo se estudió seed 11, una sesión sintética y los 200 episodios del smoke.
   No se generaliza a otras semillas, usuarios o Myo real.
4. El corpus común permite comparar actores sobre las mismas entradas, pero
   Agent50 se evalúa también sobre estados provenientes de episodios futuros
   respecto de su guardado. Las tablas por episodio preservan esta distinción.
5. Los replay buffers guardados están vacíos. Los logs prueban estados visitados,
   no frecuencia de muestreo ni composición real de minibatches.
6. Las diferencias entre acciones históricas y checkpoints no aíslan
   exploración, porque también cambia la política dentro de cada bloque.
7. La descomposición de reward es observacional. No demuestra que `w_q`, MSE o
   una penalización débil sean la causa raíz de los comandos.
8. No se calculó qué habría ocurrido con una acción alternativa; hacerlo
   offline sin repropagar la dinámica sería un contrafactual inválido.
9. La actividad decrece y reaparece de forma distinta por motor. No hay una
   mejora monótona ni un checkpoint que satisfaga reposo seguro.
10. Motor 2 conserva saturación elevada en Agent200. Los registros son comandos,
    no mediciones de corriente, temperatura o fuerza.
11. No se evaluó watchdog, cambio de reward, nueva capa de seguridad o
    reentrenamiento. El gate de ETAPA 6 continúa fallido.
12. El gate DTW continúa no aprobado. ETAPA 7E no aporta evidencia para abrir
    ETAPA 8.
13. `rootCauseIdentified=false`: atribuir el resultado únicamente a reward,
    MSE, exploración, OOD o arquitectura sigue siendo una hipótesis.

## 8. Confirmación explícita de que no se usó hardware

No se usó hardware. No se abrieron puertos COM, no se conectó Myo ni guante,
no se generó PWM físico y no se movieron motores reales. `Env` no fue creado y
el simulador no fue invocado. La columna PWM procede únicamente de aplicar
offline la cuantización histórica a salidas numéricas de actores congelados.
La línea mantiene `simMotors=true`; en esta etapa ni siquiera se simuló planta.

## 9. Commit de la etapa

Commit de implementación registrado por el artefacto canónico:

```text
456de2a4a64b8c0c94818eb924da9b04b8729371
Add Stage 7E checkpoint evolution audit
```

El commit documental que incorpora este informe se crea al cierre y debe
consultarse con:

```powershell
git log -1 --oneline
```

No se hizo push ni se abrió PR. `matlab_code.zip` no fue incluido.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8: el gate DTW sigue rechazado. No iniciar piloto 2k,
campaña 12k, watchdog conductual ni hardware.

La propuesta es **ETAPA 7F - ablación corta y aislada de regularización de
acción en reposo**, sujeta a autorización explícita:

1. mantener congelados Agent200, estado `intentMarkov60`, target, decodificador,
   `baselineQuantized`, simulador y seguridad;
2. definir antes del entrenamiento una sola intervención de reward: comparar
   el perfil actual `w_u=0.01` contra `w_u=0.05`, manteniendo todos los demás
   pesos. El candidato iguala `w_du=0.05` y, si la conducta no cambiara,
   elevaría aritméticamente la participación del término de acción desde 3.44%
   hasta aproximadamente 15.11%; esto dimensiona la prueba, no predice su
   resultado dinámico;
3. crear ambos agentes desde cero; no cargar Agent200 ni Agent7250;
4. ejecutar primero pruebas unitarias de la reward y un smoke emparejado de
   hasta 200 episodios, seed 11, con el mismo dataset, inicialización,
   presupuesto y evaluación;
5. reportar todos los checkpoints y separar tracking, actividad de reposo,
   `actionL2`, `deltaActionL2`, saturación y métricas por motor;
6. exigir en reposo `saturationFraction=0` y activación falsa `<=1%`, además de
   no empeorar límites ni funcionalidad de M1, M3 o M4;
7. si falla el smoke, detenerse sin piloto; si pasa, detenerse igualmente y
   solicitar autorización antes de cualquier piloto multisemilla.

Esta propuesta cambia solo un parámetro de reward en una ablación controlada.
No asume que el peso actual sea la causa: prueba esa hipótesis. No se ejecuta
automáticamente.
