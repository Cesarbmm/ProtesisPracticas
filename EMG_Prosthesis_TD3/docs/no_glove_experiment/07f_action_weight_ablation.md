# ETAPA 7F - ablación emparejada del peso de acción

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada para probar una hipótesis concreta derivada de la
auditoría observacional de ETAPA 7E: si incrementar únicamente el peso de
esfuerzo de la reward reduce los comandos de la política en reposo. Se comparó
`intentRewardActionWeight=0.01` contra `0.05`, con dos TD3 nuevos, seed 11 y
200 episodios por variante. No se cargaron Agent200 ni Agent7250 para entrenar.

## 1. Resultado de la etapa: PASS

La ejecución experimental es **PASS**, pero el gate científico es **FAIL**:

```text
scientificResult=effortReducedButRestGateFailed
gatePassed=false
rootCauseIdentified=false
pilotAuthorized=false
```

El candidato redujo de manera material `actionL2`, `deltaActionL2`, saturación
y error de tracking en la aceptación simulada. Sin embargo, ordenó PWM en 100%
de las ventanas de reposo, igual que el control. Su PWM absoluto medio de
reposo aumentó 1.8057%, aunque eliminó los componentes saturados. También
persistieron los 25 flags funcionales de Motor 2 y los 100 flags agregados de
M1, M3 y M4.

Por tanto, la hipótesis estrecha de que elevar globalmente `w_u` de 0.01 a 0.05
sea suficiente para resolver el problema de reposo queda rechazada bajo este
smoke y seed. El resultado no demuestra que la reward sea irrelevante ni que
otro peso produciría el mismo resultado. No se identifica una causa raíz.

No se inició piloto 2k ni campaña 12k.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7F:
  `e09c1c4f2d5030649d123a1f5c8574187235e827`;
- commit inicial de implementación:
  `5183a7bda9b243406094d42a8de0494c7bfbb085`;
- commit de corrección fail-closed y reanudación:
  `0da34b6d1ad9bc315ae1dc654f17eb5e9859ed84`;
- el commit documental se registra al cierre de este informe.

El manifiesto canónico registra `gitTrackedDirty=false`. El único elemento
local no rastreado es `matlab_code.zip`, preservado sin cambios. No se hizo push
ni se abrió PR.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage7fActionWeightAblation.m`:
  gate pre-registrado, comparación final y clasificación científica.
- `matlab_code/src/evaluation/summarizeNoGloveStage7fRestCommands.m`:
  actividad por componente, ventana y motor en episodios de reposo.
- `matlab_code/tests/no_glove/testNoGloveStage7fActionWeightAblation.m`:
  diez pruebas deterministas, incluidos fallos cerrados y clasificaciones.
- `matlab_code/workflows/published/run_no_glove_stage7f_action_weight_ablation.m`:
  launcher emparejado, auditorías de configuración/dataset/inicialización,
  ejecución de los dos smokes, hashes y manifiesto.
- `docs/no_glove_experiment/07f_action_weight_ablation.md`: este informe.

### Modificados

- `matlab_code/workflows/published/run_no_glove_stage6_training.m`: acepta
  `intentRewardActionWeight` mediante opción, conserva `0.01` como default,
  comprueba el valor en el perfil efectivo y lo registra en manifiesto y
  comando reproducible.
- `matlab_code/workflows/published/README.md`: documenta el launcher 7F.

No se modificaron `configurables.m`, `Env`, el decodificador, `q_ref`, el
estado, la fórmula de reward, `baselineQuantized`, el simulador,
`encoder2Flex`, la seguridad, Agent7250 ni los checkpoints históricos.

## 4. Decisiones técnicas y justificación

### 4.1 Factor experimental único

La reward causal conserva:

```text
r_t = -[
    w_q   mean(e_q,t^2)
  + w_v   mean(e_v,t^2)
  + w_u   mean(u_eff,t^2)
  + w_du  mean(Delta u_t^2)
  + w_sat mean(max(0, |u_eff,t|-u_soft)^2)
]
```

Valores compartidos:

```text
w_q=1, w_v=0, w_du=0.05, w_sat=0.02, u_soft=0.90
```

Única diferencia:

```text
control:   w_u=0.01
candidato: w_u=0.05
```

No se introdujo una penalización condicionada a reposo, watchdog o cambio de
cuantización. La capa de seguridad siguió siendo independiente de la reward.

### 4.2 Protocolo emparejado

Ambas variantes usaron:

```text
seed de entrenamiento       = 11
episodios                    = 200
checkpoints                  = 50, 100, 150, 200
seed de evaluación           = 7601
simulaciones de aceptación   = 50
simulaciones de reposo       = 24
estado                       = intentMarkov60
referencia                   = emgIntent
interfaz                     = baselineQuantized
arquitectura                 = TD3 feedforward 60 -> 64 -> 64 -> 4
seguridad de posición        = clipTrajectoryOutput, activada
simMotors                    = true
```

Los perfiles efectivos fueron iguales salvo `w_u` y las rutas necesarias de
dataset/salida. Los contenidos cargados de los tres datasets fueron idénticos:

```text
trainingDatasetContentEqual   = true
evaluationDatasetContentEqual = true
restDatasetContentEqual       = true
calibration SHA equal         = true
```

### 4.3 Inicialización desde cero

Antes de aceptar el emparejamiento, el launcher recreó ambos actores con
`rng(11,'twister')` y comparó todos los parámetros aprendibles:

```text
arreglos aprendibles del actor = 6
parámetros                     = 8324
error máximo de inicialización = 0
exactamente iguales            = true
```

Cada entrenamiento configuró:

```text
newTraining=true
agentFile=""
resetExperienceBufferBeforeTraining=true
td3Residual.enabled=false
```

Ningún checkpoint se usó como punto de partida.

### 4.4 Gate pre-registrado

Antes de entrenar se fijaron:

```text
reducción mínima de actionL2                 = 10%
ratio máximo de trackingMSE candidato/control = 1.05
deltaActionL2 máximo absoluto                = 0.257108
saturación máxima de aceptación              = 0.196043
ventanas de reposo con PWM máximo             = 1%
saturación de reposo máxima                   = 0
activación falsa del decodificador máxima     = 1%
```

También se exigieron cero NaN/Inf, cero violaciones de posición, cero flags
funcionales y que saturación, `deltaActionL2` e intervenciones de seguridad no
empeoraran respecto del control.

Para una métrica de esfuerzo `J_u`:

```text
reducción relativa = (J_u,control - J_u,candidato) / J_u,control
```

La actividad de reposo de política se midió directamente en PWM:

```text
active_t,m = 1[|PWM_t,m|>0]
componentActiveFraction = mean_t,m(active_t,m)
windowAnyCommandFraction = mean_t(any_m(active_t,m))
```

Esto se mantuvo separado de la activación falsa del decodificador EMG. En las
dos variantes el decodificador produjo 0% de activación falsa, pero las
políticas emitieron comandos en 100% de las ventanas.

### 4.5 Clasificación

El candidato pasó las condiciones de finitud, límites, esfuerzo, tracking,
regularidad, saturación y activación del decodificador. Falló:

```text
motor2Functional=false
otherMotorsFunctional=false
policyRestWindows=false
```

Como la reducción de esfuerzo fue material pero el reposo no pasó, la
clasificación es `effortReducedButRestGateFailed`.

### 4.6 Reproducción del control histórico

El control 7F fue un entrenamiento nuevo. Para verificar determinismo se
comparó con el Agent200 histórico de 6A, sin usarlo para entrenar, sobre 360
estados de reposo registrados:

```text
Agent200 histórico SHA-256 = C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973
estados                     = 360
error máximo de acción      = 0
acciones exactamente iguales = true
```

Los archivos MAT nuevos tienen hashes diferentes por serialización, pero el
actor reproducido entrega exactamente las mismas acciones y las métricas de
aceptación coinciden con 6A.

### 4.7 Primer cierre fail-closed

La primera ejecución padre completó ambos entrenamientos y todas sus
evaluaciones, pero se detuvo después durante la auditoría de inicialización:

```text
Incorrect number or types of inputs or outputs for function extractdata.
```

`getLearnableParameters` podía devolver valores numéricos además de `dlarray`.
No se relajó la auditoría ni se declaró un resultado parcial como canónico. Se
añadió una conversión explícita para ambos tipos y una ruta de reanudación que:

1. exige los dos resultados hijos completos;
2. vuelve a comprobar sus manifiestos e invariantes;
3. reutiliza exactamente sus checkpoints y logs;
4. no reentrena ni vuelve a simular.

El resultado canónico registra `reusedCompletedChildRuns=true` y el commit de
la corrección.

## 5. Comandos y pruebas ejecutados

### 5.1 Análisis estático y pruebas previas

`checkcode(...,'-id')`:

```text
analyzeNoGloveStage7fActionWeightAblation.m  0 issues
summarizeNoGloveStage7fRestCommands.m        0 issues
run_no_glove_stage7f_action_weight_ablation.m 0 issues
run_no_glove_stage6_training.m               0 issues
testNoGloveStage7fActionWeightAblation.m     0 issues
```

Pruebas específicas finales:

```matlab
r = runtests('tests/no_glove/testNoGloveStage7fActionWeightAblation.m');
```

```text
10 passed, 0 failed, 0 incomplete
```

### 5.2 Entrenamiento y evaluación

La ejecución completa se inició mediante:

```matlab
run_no_glove_stage7f_action_weight_ablation(struct( ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7f_artifacts\stage7f_final', ...
  'historicalControlCheckpoint', '<Agent200 histórico 6A>'));
```

Cada hijo ejecutó primero la suite completa y después un smoke de 200
episodios, 50 simulaciones de aceptación y 24 de reposo.

### 5.3 Reanudación canónica

Tras corregir la auditoría de tipos, se reanudó exclusivamente el análisis con
los dos `stage6_results.mat` completos. No se ejecutó entrenamiento ni
simulación adicional.

Resultado:

```text
ETAPA 7F ACTION WEIGHT ABLATION PASS
Scientific result: effortReducedButRestGateFailed
Gate passed: 0
```

### 5.4 Regresión completa

```matlab
r = runtests('tests/no_glove','IncludeSubfolders',true);
```

```text
TOTAL=106 PASS=106 FAIL=0 INCOMPLETE=0
```

`full_no_glove_test_results.mat` SHA-256:

```text
DDC8B9C75EF83364599918AC70129726A7106B6C24DF0042A48F04D648AC89E5
```

### 5.5 Reproducción independiente del análisis

Se ejecutó el launcher sobre los mismos hijos en otra raíz:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7f_artifacts\stage7f_repro\2026-08-27_21-24-12-180
```

Resultado:

```text
PASS
scientificResult=effortReducedButRestGateFailed
CSV científicos idénticos por SHA-256=9/9
```

## 6. Métricas y artefactos generados

### 6.1 Aceptación final Agent200

| Métrica | Control `w_u=.01` | Candidato `w_u=.05` | Candidato/control o cambio |
|---|---:|---:|---:|
| trackingMSE | 0.075152412 | 0.012314755 | ratio 0.163864 |
| trackingMAE | 0.165273319 | 0.080405373 | reducción 51.35% |
| velocityMSE | 0.383398803 | 0.053809443 | reducción 85.97% |
| actionL2 | 0.306535002 | 0.247026334 | reducción 19.413% |
| deltaActionL2 | 0.167320743 | 0.068113310 | ratio 0.407082 |
| saturación | 0.110655738 | 0.020491803 | ratio 0.185185 |
| violaciones de posición | 0 | 0 | sin cambio |
| flags Motor 2 | 25 | 25 | sin mejora |
| flags M1+M3+M4 | 100 | 100 | sin mejora |

La reward media final de entrenamiento no se usa para comparar calidad porque
las dos variantes tienen rewards numéricamente distintas por diseño.

### 6.2 Reposo calibrado

| Métrica | Control | Candidato |
|---|---:|---:|
| componentes con PWM | 1.000000 | 1.000000 |
| ventanas con algún PWM | 1.000000 | 1.000000 |
| PWM absoluto medio | 113.680556 | 115.733333 |
| saturación | 0.008333 | 0 |
| activación falsa del decodificador | 0 | 0 |
| intervenciones de seguridad | 876 | 720 |

El candidato elimina saturación de reposo, pero no actividad. El PWM medio
aumenta 1.8057%, de modo que la salida no quedó meramente por encima del umbral
en menos ventanas: siguió activa en todas.

Por motor:

| Variante | Motor | Actividad | PWM abs. medio | Saturación |
|---|---:|---:|---:|---:|
| control | M1 | 1 | 97.422222 | 0 |
| control | M2 | 1 | 161.033333 | 0.033333 |
| control | M3 | 1 | 83.200000 | 0 |
| control | M4 | 1 | 113.066667 | 0 |
| candidato | M1 | 1 | 142.933333 | 0 |
| candidato | M2 | 1 | 96.000000 | 0 |
| candidato | M3 | 1 | 144.000000 | 0 |
| candidato | M4 | 1 | 80.000000 | 0 |

La regularización redistribuye comandos entre motores. No se interpreta como
independencia de cuatro DoF ni como corriente medida.

### 6.3 Intervenciones de seguridad

| Fase | Control | Candidato | No peor |
|---|---:|---:|---|
| entrenamiento | 28895 | 22462 | sí |
| aceptación | 6000 | 5984 | sí |
| reposo | 876 | 720 | sí |

Las intervenciones evitan salidas fuera de límites del simulador; una cantidad
no nula indica que la política sigue dependiendo ampliamente de la capa de
seguridad.

### 6.4 Checkpoints preservados

| Variante | Agent50 | Agent100 | Agent150 | Agent200 |
|---|---|---|---|---|
| control | `4B7FF8ED...921A1` | `D8463617...F3176` | `9A13747E...367C` | `9095FC6D...C47C` |
| candidato | `71C95E9C...546D` | `5236FF44...9247` | `B04826B3...82CF` | `FD860C6A...FE1C` |

La tabla completa con rutas, tamaños y SHA-256 está en
`checkpoint_inventory.csv`. No se seleccionó un checkpoint intermedio ganador;
el gate usa el Agent200 final pre-registrado.

### 6.5 Artefacto canónico

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7f_artifacts\stage7f_final\2026-08-27_21-23-09-959
```

Hashes principales:

```text
manifest.json SHA-256       = CD8D15ABE81A08BDDBA8B67F45CEE12BA030011D5604D439E7AA304AF1E3CC9D
stage7f_results.mat SHA-256 = ECEE07BA89D0FABE4350AE0A11B2AA0F348DEE51D302476E9ECA03DFA72DD2A0
control manifest SHA-256    = 1806BC5CC61E74AB1D651A9C5640522B87033F2A8B66FFC1DC69BF1A616477DF
candidate manifest SHA-256  = 6A7E026B465C211025ED8CDABA42A153CAB19636D102F0134B52A3B8EDA4B136
artefactos primarios        = 13/13 con hash
```

Tablas principales:

- `variant_summary.csv` y `comparison.csv`;
- `gate_checks.csv` y `rest_motor_summary.csv`;
- `checkpoint_inventory.csv`;
- `profile_audit.csv`, `initialization_audit.csv` y `dataset_audit.csv`;
- `historical_control_reproduction.csv`;
- `stage7f_results.mat`, `manifest.json`, `offline_report.md` y
  `reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

1. Solo se probó seed 11 y un corpus sintético. No hay evidencia multisemilla,
   por usuario o con Myo real.
2. Solo se compararon dos pesos. El resultado rechaza suficiencia de 0.05, no
   toda forma posible de regularización.
3. `w_u` se aplica globalmente; no distingue reposo de movimiento intencional.
4. Aunque el candidato mejora métricas agregadas, falla el requisito esencial
   de PWM cero en reposo y no puede promoverse.
5. Los flags funcionales permanecen idénticos; la mejora de MSE no demuestra
   funcionalidad por motor.
6. Las intervenciones de seguridad son numerosas en ambas variantes. Cero
   violaciones se logra con una capa activa que recorta la planta simulada.
7. La evaluación dinámica principal corresponde al checkpoint final. Todos los
   checkpoints intermedios fueron guardados y hasheados, pero no se eligieron
   ni promovieron retrospectivamente.
8. El control reproduce acciones históricas en 360 estados; esto respalda
   determinismo de seed 11, no reproducibilidad en todas las plataformas.
9. No se midió corriente, temperatura, fuerza ni PWM físico.
10. No se introdujo watchdog. La seguridad no puede depender de la reward.
11. El gate DTW continúa rechazado y esta etapa no calculó DTW.
12. `rootCauseIdentified=false`: no puede afirmarse que MSE, `w_u`,
    cuantización, arquitectura o datos sean por sí solos la causa raíz.

## 8. Confirmación explícita de que no se usó hardware

No se usó hardware. No se abrieron puertos COM, no se conectó Myo ni guante,
no se emitió PWM físico y no se movieron motores reales. Las dos variantes
usaron exclusivamente `SimController` con `simMotors=true` y seguridad de
posición activada. Los valores PWM reportados son comandos simulados, no
corriente eléctrica medida.

## 9. Commits de la etapa

```text
5183a7bda9b243406094d42a8de0494c7bfbb085
Add Stage 7F action weight ablation

0da34b6d1ad9bc315ae1dc654f17eb5e9859ed84
Fix Stage 7F completed-run audit
```

El commit que incorpora este informe se crea al cierre. No se hizo push ni se
abrió PR. `matlab_code.zip` no fue incluido.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar piloto 2k, campaña 12k, ETAPA 8 ni hardware. Tampoco iniciar un
barrido de pesos: mezclaría selección retrospectiva con presupuesto adicional
sin explicar por qué las salidas de reposo permanecen activas.

La propuesta es **ETAPA 7G - margen de acción y separabilidad reposo/movimiento
offline**, sujeta a autorización explícita:

1. congelar los Agent200 control y candidato 7F;
2. usar los logs ya publicados de aceptación y reposo, sin simulación ni
   entrenamiento;
3. medir por motor las distribuciones de `|u_raw|`, `|u_eff|` y PWM en reposo,
   inicio, movimiento y hold posterior;
4. medir el margen de `|u_raw|` respecto del umbral actual 0.05 y de cada nivel
   de `baselineQuantized`;
5. construir una curva offline de umbral: fracción de ventanas de reposo
   suprimidas frente a fracción de comandos activos de movimiento eliminados;
6. pre-registrar éxito solo si existe un umbral único que logre reposo activo
   `<=1%` sin eliminar más de 5% de componentes activos durante intención ni
   introducir una regresión específica de Motor 2;
7. no aplicar el umbral al entorno en esta etapa: si no hay separación, cerrar
   la hipótesis de cuantización y proponer después una intervención explícita
   de reposo o seguridad en una ablación distinta;
8. detenerse con métricas y artefactos antes de cambiar conducta.

ETAPA 7G distinguiría si el problema es una salida pequeña cercana al umbral o
una política que ordena comandos fuertes en reposo. No se ejecuta
automáticamente.
