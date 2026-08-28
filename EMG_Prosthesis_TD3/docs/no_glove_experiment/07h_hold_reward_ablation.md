# ETAPA 7H - ablación causal de reward durante hold

Fecha de cierre: 2026-08-28.

ETAPA 7H fue autorizada para probar una hipótesis derivada de 7F y 7G. El
aumento global de `w_u` en 7F redujo esfuerzo sin resolver reposo; el análisis
7G descartó que un umbral global de acción separara reposo de movimiento. La
nueva pregunta fue si una penalización aplicada solo cuando la referencia está
detenida y la posición de decisión ya está cerca del objetivo reduce comandos
innecesarios sin castigar movimiento o corrección lejos del target.

La hipótesis, los parámetros, la clasificación y los gates se fijaron en el
commit `fcfd04f1fe5cfd2a4cc548cb1b70f97620f87fe2`, antes de implementar la
reward o entrenar.

## 1. Resultado de la etapa: PASS

La ejecución de ingeniería es **PASS**. El gate experimental es **FAIL** y la
clasificación científica pre-registrada es:

```text
scientificResult=holdExposureInsufficient
gatePassed=false
rootCauseIdentified=false
pilotAuthorized=false
```

El indicador `I_hold` estuvo activo en `53.3333333%` de las ventanas de reposo
del candidato, por debajo del mínimo pre-registrado de 90%. Por ello no se
clasifica el resultado como refutación completa de la hipótesis: la
intervención dejó de aplicarse una vez que el error de posición salió del
entorno estrecho fijado.

Los demás gates tampoco apoyan al candidato. Continuó enviando PWM en 100% de
las ventanas de reposo, tuvo saturación de reposo `0.125`, empeoró trackingMSE
por un factor `8.117012`, `actionL2` por `1.486483` y `deltaActionL2` por
`7.935386`, y duplicó los flags de Motor 2 de 25 a 50. No hubo NaN/Inf ni
violaciones de posición.

No se inició piloto 2k ni campaña.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7H:
  `e55d70afd8419ad37af00f66e6c06f6124426b91`;
- pre-registro:
  `fcfd04f1fe5cfd2a4cc548cb1b70f97620f87fe2`;
- implementación usada para entrenar:
  `071cf2e23d0c91c5e1812e0ba3e64e3b715fbe4e`;
- corrección fail-closed del agregador y SHA del manifiesto canónico:
  `6f4c202add52721a803227a811e38309efa4a429`;
- el commit documental se informa al finalizar este documento.

El manifiesto registra `gitTrackedDirty=false`. El único elemento local no
rastreado es `matlab_code.zip`, preservado sin cambios. No se hizo push ni se
abrió PR.

Agent7250 permanece intacto:

```text
matlab_code/checkpoints/canonical/Agent7250_valid_baseline/
Agent7250_valid_baseline.mat
SHA-256=0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

No fue cargado ni usado como punto de partida.

## 3. Archivos creados y modificados

### Creados

- `docs/no_glove_experiment/07h_preregistration.md`: hipótesis, parámetros,
  gates y clasificación fijados antes del experimento.
- `matlab_code/src/reward_functions/trackingIntentHoldActionReward.m`: reward
  causal explícita de 7H.
- `matlab_code/src/evaluation/summarizeNoGloveStage7hHoldReward.m`:
  reconstrucción de `I_hold` desde `state_t` y auditoría de logs.
- `matlab_code/src/evaluation/analyzeNoGloveStage7hHoldRewardAblation.m`:
  comparación y clasificación pre-registrada.
- `matlab_code/tests/no_glove/testTrackingIntentHoldActionReward.m`: ocho
  pruebas de matemática, causalidad, selector, configuración y episodio.
- `matlab_code/tests/no_glove/testNoGloveStage7hHoldRewardAblation.m`: siete
  pruebas de gates, clasificaciones, replay y fallo cerrado.
- `matlab_code/workflows/published/run_no_glove_stage7h_hold_reward_ablation.m`:
  launcher emparejado, reanudación sin reentrenar, auditorías y manifiesto.
- `docs/no_glove_experiment/07h_hold_reward_ablation.md`: este informe.

### Modificados

- `matlab_code/config/configurables.m`: defaults inertes y validación de los
  tres parámetros 7H.
- `matlab_code/src/@Env/Env.m`: autoriza únicamente la nueva reward explícita
  dentro de la ruta `emgIntent` simulada.
- `matlab_code/src/@Env/step.m`: añade al contexto
  `decisionPositionPrediction=this.prevEncoderNorm`, correspondiente al
  encoder visible al elegir la acción.
- `matlab_code/src/reward_functions/rewardFunctionSelector.m`: selector de la
  reward 7H.
- `matlab_code/workflows/published/run_no_glove_stage6_training.m`: opciones y
  manifiesto para ejecutar la reward 7H mediante perfil, manteniendo defaults
  históricos.
- `matlab_code/workflows/published/README.md`: documentación del launcher.

No se modificaron el decodificador, `q_ref`, dimensiones del estado,
`baselineQuantized`, umbral PWM, niveles PWM, simulador, `encoder2Flex`,
arquitectura TD3 ni capa de seguridad.

## 4. Decisiones técnicas y justificación

### 4.1 Contrato causal

Se distinguieron dos posiciones:

- `q_decision,t`: encoder normalizado presente en `state_t`, antes de ejecutar
  `u_t`;
- `q_prediction,t`: encoder leído después de aplicar `u_t`, usado por la reward
  base para evaluar la transición.

El indicador usa únicamente información visible cuando el actor eligió la
acción:

```text
e_hold,t = q_decision,t - q_ref,t

I_hold,t = 1[max_m |v_ref,t,m| <= epsilon_v]
           * 1[mean_m(e_hold,t,m^2) <= epsilon_q2]
```

La nueva reward es:

```text
r_7H,t = -[
    w_q   mean(e_q,t^2)
  + w_v   mean(e_v,t^2)
  + w_u   mean(u_eff,t^2)
  + w_du  mean(Delta u_t^2)
  + w_sat mean(max(0, |u_eff,t|-u_soft)^2)
  + w_hold I_hold,t mean(u_eff,t^2)
]
```

No usa EMG leída para `state_(t+1)`, estados futuros ni una bandera fisiológica
oculta. La seguridad no depende de esta reward.

### 4.2 Parámetros pre-registrados

```text
epsilon_v  = 1e-12
epsilon_q2 = 1e-4
w_hold control   = 0.00
w_hold candidato = 0.20
```

`epsilon_q2=1e-4` corresponde a RMS agregado normalizado de `0.01`. El peso
candidato hace que la penalización de acción total durante hold sea
`w_u+w_hold=0.25`; fuera del hold conserva `w_u=0.05`.

### 4.3 Factor único

Los dos perfiles usan `trackingIntentHoldActionReward`. La única diferencia
permitida, aparte de rutas de salida, es:

```text
intentHoldActionWeight: 0.00 -> 0.20
```

Valores compartidos:

```text
w_q=1, w_v=0, w_u=0.05, w_du=0.05
w_sat=0.02, u_soft=0.90
referenceSource=emgIntent
observationVariant=intentMarkov60
actionInterfaceVariant=baselineQuantized
seguridad=clipTrajectoryOutput, enabled
```

La auditoría confirmó perfiles iguales salvo el factor y rutas, seed igual,
presupuesto igual, cadencia igual, seguridad igual y demás parámetros de
reward iguales.

### 4.4 Equivalencia del control

Con `w_hold=0`, se comparó la ruta 7H contra
`trackingIntentActionRateReward` en tres contextos deterministas:

```text
maximumScalarRewardError=0
maximumVectorRewardError=0
exactlyEquivalent=true
```

Por tanto, el nuevo selector no cambia numéricamente la reward del control.

### 4.5 Protocolo emparejado

Cada variante usó:

```text
seed entrenamiento       = 11
episodios                 = 200
checkpoints               = 50, 100, 150, 200
seed evaluación           = 7601
aceptación                = 50 simulaciones
reposo                    = 24 simulaciones
estado                    = intentMarkov60
TD3                       = feedforward 60 -> 64 -> 64 -> 4
política inicial          = nueva
replay inicial            = vacío
simMotors                 = true
```

La comparación de actores recreados antes del entrenamiento produjo:

```text
arreglos aprendibles       = 6
parámetros                 = 8324
error máximo               = 0
exactamente iguales        = true
```

Training, evaluación y reposo usaron contenidos de datasets idénticos y la
misma calibración por contenido.

### 4.6 Diagnósticos persistidos

Cada `rewardInfo` añade:

```text
holdActive
holdVelocityMaxAbs
holdPositionMse
holdActionL2
holdActionPenalty
```

El agregador reconstruye esos cinco valores desde `stateLog` y
`actionSatLog`. El error máximo de replay fue cero para control y candidato.

### 4.7 Gate y orden de clasificación

Se exigieron finitud, cero violaciones de posición, exposición de hold en
reposo al menos 90%, ventanas con PWM como máximo 1%, saturación de reposo
cero, activación falsa del decodificador como máximo 1%, trackingMSE no peor
de 5%, esfuerzo/variación/saturación no peores, límites absolutos históricos y
cero flags funcionales.

El orden pre-registrado clasifica exposición insuficiente antes de tracking,
reposo, funcionalidad y regularidad. Esto impide afirmar retrospectivamente
que se probó adecuadamente una intervención que solo estuvo activa en 53.33%
del estrato objetivo.

## 5. Comandos y pruebas ejecutados y resultados exactos

### 5.1 Análisis estático

`checkcode(...,'-id')` en los nueve archivos MATLAB nuevos o conductualmente
modificados de 7H:

```text
0 issues
```

`configurables.m` mantiene un aviso `IFBDUP` preexistente en una sección no
modificada por 7H; no se alteró ese código ajeno.

### 5.2 Pruebas específicas

```matlab
runtests({ ...
  'tests/no_glove/testTrackingIntentHoldActionReward.m', ...
  'tests/no_glove/testNoGloveStage7hHoldRewardAblation.m'})
```

Resultado:

```text
Total=15, Passed=15, Failed=0, Incomplete=0
```

### 5.3 Regresión completa previa y final

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado antes del entrenamiento y después de la corrección del agregador:

```text
Total=129, Passed=129, Failed=0, Incomplete=0
```

Resultado final guardado:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_postfix_full_results.mat
SHA-256=DA33964514200870D4979DE3C5D065CF513D5BCAA628039A8E3A66610F1DC5D1
```

Cada launcher hijo ejecutó también `129/129` antes de su entrenamiento.

### 5.4 Ejecución experimental

El launcher ejecutado fue:

```matlab
run_no_glove_stage7h_hold_reward_ablation(struct( ...
  'resultsRoot', ...
  'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7h_artifacts/stage7h_final'))
```

Ambos hijos completaron 200 episodios y las 74 simulaciones de evaluación por
variante.

### 5.5 Detención fail-closed y reanudación

Después de completar ambos hijos, el primer padre se detuvo antes de clasificar:

```text
Brace indexing is not supported for variables of this type.
buildVariant: seedResults{1}
```

MATLAB entrega `seedResults` como struct directo en un reporte nuevo y como
celda al cargar un MAT completado. Se añadió una normalización que exige
exactamente un resultado seed y acepta ambas representaciones. No se relajó
ningún gate.

Tras pruebas específicas `15/15` y `checkcode=0`, se creó el commit
`6f4c202a`. El padre se reanudó con las dos rutas hijas completas. El manifiesto
canónico registra `reusedCompletedChildRuns=true`; no volvió a entrenar ni a
simular.

### 5.6 Reproducción

Se repitió la agregación en una raíz independiente, reutilizando los mismos
hijos. Las diez tablas científicas tuvieron SHA-256 idéntico bit a bit.

```text
canonical:
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_artifacts\
stage7h_final\2026-08-28_16-00-33-357

reproducción:
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_artifacts\
stage7h_repro\2026-08-28_16-01-51-758
```

## 6. Métricas y artefactos generados

### 6.1 Aceptación

| Métrica | Control `w_hold=0` | Candidato `w_hold=0.20` | Ratio candidato/control | Gate candidato |
|---|---:|---:|---:|---|
| trackingMSE | 0.012314755 | 0.099959014 | 8.117012 | FAIL |
| trackingMAE | 0.080405373 | 0.185827329 | 2.311131 | informativo |
| actionL2 | 0.247026334 | 0.367200528 | 1.486483 | FAIL |
| deltaActionL2 | 0.068113310 | 0.540505375 | 7.935386 | FAIL |
| saturationFraction | 0.020491803 | 0.178278689 | 8.700000 | PASS absoluto, FAIL relativo |
| flags Motor 2 | 25 | 50 | 2.000000 | FAIL |
| flags M1/M3/M4 | 100 | 100 | 1.000000 | FAIL |

La saturación candidata permanece bajo el límite absoluto `0.196043`, pero
empeora respecto del control. `deltaActionL2=0.540505` excede además el máximo
absoluto `0.257108`.

### 6.2 Reposo

| Métrica | Control | Candidato | Gate candidato |
|---|---:|---:|---|
| componentes con comando | 1.000000 | 1.000000 | FAIL |
| ventanas con algún PWM | 1.000000 | 1.000000 | FAIL |
| PWM absoluto medio | 115.733333 | 124.141667 | FAIL, aumenta 7.2653% |
| saturationFraction | 0.000000 | 0.125000 | FAIL |
| holdActiveFraction | 0.533333 | 0.533333 | FAIL, mínimo 0.90 |
| holdActionL2 medio | 0.109710 | 0.050459 | informativo |
| término hold medio | 0.000000 | 0.010092 | aplicado parcialmente |
| activación falsa del decodificador | 0.000000 | 0.000000 | PASS |

`saturationFraction=0.125` significa 12.5% de los componentes motor-paso de
reposo con `|u_eff|>=0.95`; no significa cuatro motores al máximo 12.5% del
tiempo.

### 6.3 Soporte del indicador

| Contexto | Control `I_hold` activo | Candidato `I_hold` activo | MSE de posición medio candidato | máximo candidato |
|---|---:|---:|---:|---:|
| aceptación | 0.105246 | 0.081967 | 0.097420 | 0.325300 |
| reposo | 0.533333 | 0.533333 | 0.112095 | 0.240240 |

El candidato redujo la acción cuadrática dentro de ventanas activas, pero la
condición no cubrió suficiente reposo y la trayectoria global empeoró. Es una
observación, no prueba de causalidad única.

### 6.4 Seguridad simulada

| Contexto | Control | Candidato |
|---|---:|---:|
| episodios con violación de posición | 0 | 0 |
| intervenciones durante training | 22462 | 26703 |
| intervenciones en aceptación | 5984 | 6770 |
| intervenciones en reposo | 720 | 1080 |

Los límites evitaron violaciones, pero el candidato requirió más
intervenciones en los tres contextos.

### 6.5 Checkpoints

```text
control Agent200:
010EF2D8A6278875C04E4B62C0CD444B84FA38542E2ECBDDB4913DBD7D0B4D4F

candidato Agent200:
F68065DDB018B0460BC999EBEAA5C7B2C089857E2AA438C5BE32D394BF9AD6C6
```

Ambos son agentes nuevos de ETAPA 7H; ninguno es Agent7250 ni un agente 7F.

### 6.6 Artefacto canónico

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_artifacts\
stage7h_final\2026-08-28_16-00-33-357
```

Hashes principales:

```text
manifest.json
8EFE955A4010F50A4028A939FC6265256BF7AB8D43A49B2A4671DF9C582FDFE8

stage7h_results.mat
EC62157C598107071C0B7CA4A9AD4B3E3EFC3F28156A2B784A1F144981EBBEF4
```

El directorio contiene resumen de variantes, comparación, gates, métricas por
motor, soporte de hold, inventario de checkpoints, auditorías de perfil,
inicialización, datasets y equivalencia, MAT, tests, reporte, comando y
manifiesto.

## 7. Riesgos, supuestos y cuestiones no resueltas

1. Solo se probó seed 11 y 200 episodios. No se generaliza a otras seeds o
   presupuestos.
2. El indicador global con `epsilon_q2=1e-4` cubrió 53.33% de reposo. Cambiar
   ese umbral después de ver resultados sería otra ablación y no se hizo.
3. Un indicador duro puede crear una discontinuidad de reward al cruzar el
   límite de error. ETAPA 7H no demuestra si esa discontinuidad contribuyó al
   deterioro.
4. El candidato puede abandonar la región elegible durante la trayectoria;
   la reward base continúa penalizando tracking, pero la exposición efectiva
   al término hold cae. Debe medirse offline antes de reformular.
5. `hold` es una condición mecánica causal, no reposo fisiológico. No valida la
   compuerta histórica de Myo.
6. La reducción de `holdActionL2` dentro de ventanas elegibles no compensó el
   peor desempeño global. No debe seleccionarse esa métrica aislada.
7. Los flags funcionales y las intervenciones de seguridad muestran una
   regresión importante, aunque no hubo violaciones de límites.
8. No se identifica la reward como causa raíz única de saturación. El
   resultado solo caracteriza esta formulación y parámetros.
9. Los PWM son comandos simulados, no corriente eléctrica medida.
10. No se comparó el MSE de intención directamente con el MSE histórico del
    guante como si fueran el mismo target.

## 8. Confirmación explícita de que no se usó hardware

No se activó hardware, Myo, guante, puerto COM, PWM físico ni conexión real.
Todos los episodios usaron `simMotors=true`, EMG pregrabada sintética y
`SimController`. No existe medición de corriente o temperatura. La capa de
seguridad de posición simulada permaneció activada e independiente de reward.

## 9. Commits de la etapa

```text
fcfd04f1fe5cfd2a4cc548cb1b70f97620f87fe2
Preregister Stage 7H hold reward ablation

071cf2e23d0c91c5e1812e0ba3e64e3b715fbe4e
Add Stage 7H causal hold reward ablation

6f4c202add52721a803227a811e38309efa4a429
Fix Stage 7H completed-run aggregation
```

El commit documental se registra al cierre. No se hizo push ni se abrió PR.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

Se propone **ETAPA 7I - diagnóstico offline del soporte y discontinuidad de
`I_hold`**. No se ejecuta como parte de 7H.

Objetivo: determinar por qué la exposición de reposo fue 53.33% antes de
cambiar otra vez la reward.

Acciones propuestas:

1. usar exclusivamente logs congelados 7H de control y candidato;
2. reconstruir por paso `q_decision`, `q_ref`, `v_ref`, MSE de decisión,
   `I_hold`, PWM, acción efectiva e intervención de seguridad;
3. medir tiempo hasta primera salida, reentradas y permanencia dentro de
   `epsilon_q2=1e-4` por episodio;
4. separar si la pérdida de soporte existe en el reset inicial, aparece tras
   la primera acción o coincide con intervención de seguridad;
5. construir una curva contrafactual offline sobre todos los valores críticos
   observados de `epsilon_q2`, sin modificar ni aplicar la reward;
6. reportar el umbral mínimo que alcanzaría 90% de exposición en reposo y qué
   distribución de error mecánico estaría perdonando;
7. medir cuántas ventanas `v_ref=0` fuera del objetivo quedarían penalizadas
   para detectar riesgo de bloquear corrección;
8. evaluar solo como diagnóstico la continuidad de una compuerta suave, sin
   seleccionar fórmula o peso post hoc;
9. verificar hashes de todos los episodios antes y después;
10. no entrenar, no simular, no cargar agentes, no cambiar reward/estado/target,
    no calcular DTW y no usar hardware.

Criterio para una ablación posterior: solo proponer una nueva reward si existe
un dominio causal con al menos 90% de cobertura de reposo que no etiquete como
hold una fracción material de correcciones lejos del objetivo. ETAPA 7I debe
detenerse con evidencia offline; no autoriza automáticamente otro smoke.
