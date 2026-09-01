# ETAPA 7R — atribución EMG con pares de estados reales

Fecha de ejecución: 2026-08-31.

## 1. Resultado de la etapa: PASS

La implementación, la validación determinista y la ejecución canónica de ETAPA
7R finalizaron correctamente. El resultado operativo es `PASS`; el resultado
científico preinscrito es:

```text
insufficientMatchedSupport
```

Este resultado no significa que las features EMG hayan sido descartadas. Significa
que la evidencia congelada no cumple el soporte mínimo necesario para interpretar
los modelos de atribución. En particular:

- `withinEpisode` cumplió el gate de soporte en 4/4 motores;
- `crossEpisode` lo cumplió en 0/4 motores;
- `steadyRest` produjo 0 pares primarios en los cuatro motores;
- la reutilización máxima de un donor `crossEpisode` fue 0.125, por encima del
  máximo preinscrito de 0.10.

No se relajaron los umbrales después de observar el resultado. No se autoriza
entrenamiento, smoke de 200, piloto de 2 000 ni campaña.

## 2. Rama y SHA base/actual

```text
Rama: experiment/no-glove-intent-control
SHA base de main: 6b213ba5c624fffb3f1094585c67d9c8ac43b737
SHA al ejecutar el launcher canónico: daa65e4d96815b3e7b3359b008f7097bb425fab3
```

El launcher registró `gitTrackedDirty=false`. Registró `gitDirty=true` únicamente
por el archivo local ajeno y no seguido `EMG_Prosthesis_TD3/matlab_code.zip`, que
se preservó sin modificar, borrar ni incorporar a los commits.

Padres congelados y validados:

| Etapa | Resultado científico | SHA-256 de `manifest.json` |
|---|---|---|
| 7Q | `distributedOrUnresolved` | `4ECA54839AC8CF60A48B5F6E13ABDEB386BEDA9A851C7421EE782F50D6EDF57F` |
| 7P | `noAblationSupported` | `9B6BC4198AE8B36C4BE062E51D82BE7709870D2DBD3C74A5F7FE68AB015034D9` |
| 7N | `actionRegularityGateFailed` | `082DADB41DAA1DAB6AE2B5E02AE15191479410F10B5DF0398837814BFC53D480` |

Se mantuvo `intentMarkov60` como estado seleccionado y el estado 62 continuó
`provisionallyRejected`. Agent7250 no se cargó ni se utilizó. Su checkpoint
canónico permaneció intacto con SHA-256:

```text
0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

## 3. Archivos creados y modificados

Archivos creados:

- `docs/no_glove_experiment/07r_preregistration.md`;
- `docs/no_glove_experiment/07r_real_state_emg_attribution.md`;
- `matlab_code/src/evaluation/getNoGloveWmoosFeatureContract.m`;
- `matlab_code/src/evaluation/buildNoGloveStage7rRealPairs.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7rEmgAttribution.m`;
- `matlab_code/src/evaluation/classifyNoGloveStage7rEvidence.m`;
- `matlab_code/src/evaluation/loadNoGloveStage7rEvidence.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7rRealStateEmgAttribution.m`;
- `matlab_code/workflows/published/run_no_glove_stage7r_real_state_emg_attribution.m`.

Archivo modificado:

- `matlab_code/workflows/published/README.md`, únicamente para publicar el nuevo
  launcher y sus límites operativos.

No se modificaron reward, cuantización, TD3, simulador, `Env`, referencia, gate,
estado de observación ni capa de seguridad.

## 4. Decisiones técnicas, matemática y justificación

### 4.1 Evidencia primaria congelada

Se usaron exactamente los 3 410 estados completos observados de Agent200 que 7Q
había congelado. La cohorte primaria conserva los mismos 2 064 componentes
motor-paso de demanda cero:

```text
gateContext ∈ {initialRest, declaredRest}
abs(v_ref,m) < 0.005
abs(q_ref,m - q_m) <= 1e-4
```

Agent200 es el checkpoint primario. Agent50, Agent100 y Agent150 se usan solo
para estabilidad secundaria. Sus hashes fueron verificados antes del análisis:

| Checkpoint | SHA-256 |
|---:|---|
| 50 | `D697DA3BB6CE9672330A359DDE3DD43ACEECCB5E2F151EF6E13D3C8C2EC2D013` |
| 100 | `3B54D4C5122D7133E9472EE8ED641418A79E0FA7E57A6501AC1C5E611357AB3F` |
| 150 | `B760B7EE45F62D6B2E12C1B0A3281E119182CAF96653A293E07E9EFE567A7A66` |
| 200 | `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E` |

Los checkpoints no se cargaron durante 7R. Las acciones congeladas que 7Q ya
había validado se reutilizaron, evitando cualquier reevaluación silenciosa.

### 4.2 Contrato WMoos

Se verificó el orden publicado por `getWmoosFeatures`:

| Familia | Función | Índices |
|---|---|---|
| `standardDeviation` | `WMoos_F1` | 1:8 |
| `absoluteEnvelopeIntegral` | `WMoos_F2` | 9:16 |
| `meanAbsoluteValue` | `WMoos_F4` | 17:24 |
| `energy` | `WMoos_F5` | 25:32 |
| `rootMeanSquare` | `WMoos_F13` | 33:40 |

Para el canal `c`, el bloque correspondiente es
`c + [0, 8, 16, 24, 32]`. Una prueba determinista compara el contrato contra la
salida directa de las cinco funciones sobre la misma EMG sintética.

Las 40 features usadas aquí ya están estandarizadas con los parámetros `C/S` de
la sesión sintética. No se interpretan como amplitudes físicas, activaciones
`[0,1]` ni energía comparable entre sesiones.

### 4.3 Emparejamiento de estados completos

La partición de cada estado fue:

```text
EMG_i     = s_i(1:40)
context_i = s_i(41:60) = [q, deltaQ, u_eff,t-1, q_ref, v_ref]
```

Para cada dimensión se calculó una desviación estándar sobre los 3 410 estados,
con piso `1e-6`. Para un query `i` y donor `j`:

```text
deltaContext = (context_i - context_j) ./ sigma_context
contextRms   = sqrt(mean(deltaContext.^2))
contextMax   = max(abs(deltaContext))

deltaEmg = (EMG_i - EMG_j) ./ sigma_emg
emgRms   = sqrt(mean(deltaEmg.^2))
```

El par primario exige:

```text
contextMax <= 0.25
emgRms >= 0.50
```

Entre candidatos válidos se eligió el menor `contextRms`, con desempate estable
por índice de fila. Los pares son dirigidos y ambos extremos son filas completas
observadas. Nunca se copiaron features entre estados, no se crearon híbridos y
no se evaluaron contrafactuales sintéticos.

Los dos contrastes fueron:

1. `withinEpisode`: misma fuente, episodio y contexto de gate, distinto paso;
2. `crossEpisode`: misma fuente, contexto de gate y fold, distinto episodio.

Los episodios se distribuyeron en cinco folds por fuente mediante
`fold = 1 + mod(rank-1, 5)`. En el contraste cruzado, query y donor pertenecen al
mismo fold; el ajuste predictivo conserva después la separación episódica entre
entrenamiento y prueba.

La cuadrícula secundaria mantuvo fijos los pares primarios y solo midió soporte:

```text
contextMax ∈ [0.15, 0.25, 0.50]
emgRms     ∈ [0.25, 0.50, 0.75]
```

### 4.4 Modelos incrementales y control negativo

Para checkpoint `k`, motor `m` y par real `(i,j)`:

```text
y = pi_k,m(s_i) - pi_k,m(s_j)
X_context = deltaContext
X_family  = deltaEmg(indices_family)
X_channel = deltaEmg(indices_channel)
```

Se ajustaron modelos ridge con `lambda=1` y validación cruzada de cinco folds:

```text
M0: y = beta0 + X_context beta_context
M1: y = beta0 + [X_context, X_emg] beta_full

incrementalR2 = R2(M1) - R2(M0)
```

Además se midieron correlación, MAE y exactitud del signo para
`abs(y)>=1e-3`. El control negativo rota una fila de `deltaEmg` dentro de cada
grupo fuente/motor/modo/fold y vuelve a ajustar `M1`:

```text
permutationMargin = incrementalR2 - permutedIncrementalR2
```

Esto separa la mejora atribuible a la asociación ordenada de EMG de una mejora
obtenible con features desalineadas. Sigue siendo una asociación de red, no una
demostración de intención muscular física.

### 4.5 Gates preinscritos

Un motor/modo debía tener simultáneamente:

- al menos 100 pares;
- al menos 20 episodios query únicos;
- los cinco folds presentes;
- reutilización máxima de un donor `<=0.10`.

El resultado global requería soporte en al menos tres motores para ambos modos.
Como `crossEpisode` obtuvo 0 motores soportados, la preinscripción obliga a
clasificar `insufficientMatchedSupport` y prohíbe interpretar los modelos como
resultado confirmatorio.

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Estado Git y limpieza textual

```powershell
git status --short --branch
git diff --check
git log -3 --oneline
```

Resultado: rama correcta; ningún error de whitespace; solo permaneció el ZIP
ajeno no seguido.

### 5.2 `checkcode`

Se ejecutó `checkcode(..., '-id')` sobre los siete archivos MATLAB nuevos:

```text
getNoGloveWmoosFeatureContract.m: 0 diagnósticos
buildNoGloveStage7rRealPairs.m: 0 diagnósticos
classifyNoGloveStage7rEvidence.m: 0 diagnósticos
analyzeNoGloveStage7rEmgAttribution.m: 0 diagnósticos
loadNoGloveStage7rEvidence.m: 0 diagnósticos
testNoGloveStage7rRealStateEmgAttribution.m: 0 diagnósticos
run_no_glove_stage7r_real_state_emg_attribution.m: 0 diagnósticos
TOTAL_CHECKCODE_DIAGNOSTICS=0
```

### 5.3 Pruebas deterministas específicas

```matlab
results = runtests( ...
    'tests/no_glove/testNoGloveStage7rRealStateEmgAttribution.m');
assertSuccess(results);
```

Resultado exacto:

```text
STAGE7R_TESTS=9 PASS=9 FAIL=0 INCOMPLETE=0
```

Las pruebas cubren orden WMoos, filas observadas completas, exclusión mutua de
modos, folds sin fuga, control permutado, invariancia del conjunto primario,
modelos incrementales, cinco clasificaciones y fallos cerrados.

### 5.4 Launcher canónico

```matlab
cd('C:/Users/Cesarbmm/ProtesisPracticas_no_glove_intent_control/EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
report = run_no_glove_stage7r_real_state_emg_attribution(struct( ...
    'resultsRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7r_artifacts/stage7r_final'));
```

Resultado exacto del preflight del launcher:

```text
testsTotal=18
testsPassed=18
testsFailed=0
```

Salida final:

```text
ETAPA 7R REAL-STATE EMG ATTRIBUTION PASS
Scientific result: insufficientMatchedSupport
Matched pairs: 1600
```

### 5.5 Regresión no-glove completa

```matlab
results = runtests('tests/no_glove', 'IncludeSubfolders', true);
assertSuccess(results);
```

Resultado exacto:

```text
FULL_NO_GLOVE_TESTS=203 PASS=203 FAIL=0 INCOMPLETE=0
```

MATLAB utilizado:

```text
23.2.0.3097123 (R2023b) Update 11
```

## 6. Métricas y artefactos generados

Directorio canónico:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7r_artifacts\stage7r_final\2026-08-31_21-42-38-792
```

Hash del manifiesto:

```text
SHA256(manifest.json) = 5111367127942D80D97BA299F47872019548CFF2126B4D75B33F161C36F90847
```

Inventario de entrada: 306 archivos, distribuidos en 6 archivos padre, 4
checkpoints congelados y 296 archivos de episodio. Cada ruta, tamaño y SHA-256
está en `input_inventory.csv`.

### 6.1 Soporte primario

Se obtuvieron 1 600 pares: 200 por motor y por modo.

| Motor | Modo | Pares | Episodios query | Episodios donor | Folds | Reutilización donor máxima | Gate |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | `withinEpisode` | 200 | 25 | 25 | 5 | 0.035 | PASS |
| 2 | `withinEpisode` | 200 | 25 | 25 | 5 | 0.035 | PASS |
| 3 | `withinEpisode` | 200 | 25 | 25 | 5 | 0.035 | PASS |
| 4 | `withinEpisode` | 200 | 25 | 25 | 5 | 0.035 | PASS |
| 1 | `crossEpisode` | 200 | 25 | 10 | 5 | 0.125 | FAIL |
| 2 | `crossEpisode` | 200 | 25 | 10 | 5 | 0.125 | FAIL |
| 3 | `crossEpisode` | 200 | 25 | 10 | 5 | 0.125 | FAIL |
| 4 | `crossEpisode` | 200 | 25 | 10 | 5 | 0.125 | FAIL |

Todos los pares procedieron de `acceptance`. En `steadyRest` había 360 estados y
90 filas EMG únicas, pero su variación fue insuficiente para el umbral primario:
el máximo de las desviaciones estándar por feature fue
`0.0084677551703322956` en unidades estandarizadas del estado. Por ello se
obtuvieron 0 pares `steadyRest` en los cuatro motores. Esta cifra no representa
amplitud EMG física.

La cuadrícula secundaria tampoco cambia la decisión primaria. Para
`contextMax<=0.50` aumentó el máximo a 250 pares por motor/modo, pero es un
análisis de soporte secundario: no modifica la ausencia `steadyRest` del conjunto
primario ni autoriza cambiar retrospectivamente los umbrales.

### 6.2 Modelos descriptivos, no confirmatorios

Debido al fallo del gate, estos valores se reportan solo para trazabilidad. En
Agent200/`ALL`, el modelo `allEmg` produjo:

| Motor | Modo | `incrementalR2` | Ganancia de signo | Margen vs. permutado |
|---:|---|---:|---:|---:|
| 1 | `withinEpisode` | 1.00638204359651 | 0.25 | 0.899512196091465 |
| 2 | `withinEpisode` | 1.02487968910490 | 0.25 | 0.923413936029971 |
| 3 | `withinEpisode` | 1.00626950093586 | 0.25 | 0.906679081993792 |
| 4 | `withinEpisode` | 1.03111360257087 | 0.55 | 0.938392137373077 |
| 1 | `crossEpisode` | 1.02799711299637 | 0.25 | 0.841746293942256 |
| 2 | `crossEpisode` | 1.03798873191946 | 0.25 | 0.907772082956588 |
| 3 | `crossEpisode` | 1.03640572810380 | 0.25 | 0.884788686548019 |
| 4 | `crossEpisode` | 1.06862139947136 | 0.605 | 0.760380582668013 |

Un `incrementalR2` mayor que uno es matemáticamente posible aquí porque el
modelo de solo contexto obtuvo `R2` negativo fuera de muestra, mientras el
modelo aumentado se aproximó a uno. No debe leerse como “más de 100% de varianza
física explicada”.

Las cinco familias superaron los gates descriptivos principales en al menos
tres motores y fueron estables por checkpoint; ninguna superó el requisito por
fuente porque `steadyRestPositiveMotorCount=0`. El bloque `allEmg` superó las
condiciones descriptivas 1–4, pero el fallo previo de soporte prevalece. La
clasificación final permanece `insufficientMatchedSupport`, no
`distributedEmgAssociation`.

### 6.3 Artefactos y hashes principales

| Artefacto | SHA-256 |
|---|---|
| `stage7r_results.mat` | `7F07C0ACB45A339BB9C339E68F9689E3E5EE23103963354ACA568AB9AB2899F1` |
| `real_pairs.csv` | `74228E9E98816313CBB27DA202611C34BA28D10E6C806F6E09C12038457A5740` |
| `pair_actions.csv` | `186E220E70CF6B0A385CC5AB285CA2D44F22928D4C893E0F1A9AE5A4F4654351` |
| `pair_support_summary.csv` | `C475CF02646BBB5AADA65A52C0BBDF1C5876745FDFCA8775C43629C23732EC29` |
| `matching_grid_summary.csv` | `28B53534142BADBC60380DFC63A23FCF698E96D874B69C3B1B12818D5F811264` |
| `family_model_summary.csv` | `A59FBFDB53492F6AB76A9E33B34A1F40947C10FE3E0EEBAE422C6359AEF54E86` |
| `channel_model_summary.csv` | `967A822660CFB9A3C34B9CDF8CB6E10E13F82BD3B693D6DCD8A1E1FEEB026F7C` |
| `family_decision_audit.csv` | `DB7E4077E05E6C4C91CB8842826AEEC6ADF84C199188935DD367CCA16C86F888` |
| `support_decision_audit.csv` | `68C6E604953A3F3B61E93CDE0F6BA1B8190D06641833B351071A36B7B5C5A379` |
| `input_inventory.csv` | `7556E8B5A4CD40C3EBCB774DE2F80FF388E990EA188B827AFAE66AAFD0887200` |
| `operational_checks.csv` | `27BF95DBD8AA6004DD3BA2C68834C638933F6FC4DA6779D325FAE3D29DC29C4A` |
| `full_no_glove_regression.mat` | `CD3B674420A148F2AAC3A8609005BA4762B27EBF466457D84258537F4DE4E5A7` |

El manifiesto incluye los hashes de 17 artefactos canónicos. El MAT de regresión
completa se generó después de cerrar el manifiesto y se registra por separado en
este informe para no reescribir evidencia canónica.

## 7. Riesgos, supuestos y cuestiones no resueltas

- No existe soporte confirmatorio `steadyRest`. La asociación descriptiva
  observada pertenece a `acceptance` y no puede generalizarse a reposo estable.
- `crossEpisode` tiene 10 episodios donor y reutilización máxima 12.5%; esto puede
  concentrar el resultado en pocos episodios.
- Los pares son observacionales. Aun con matching mecánico y control permutado,
  no demuestran que una familia WMoos represente intención muscular causal.
- Las features están estandarizadas; sus escalas no son magnitudes físicas.
- La política feedforward es determinista respecto del estado completo. Una
  reconstrucción predictiva de su acción identifica dependencia de red, no
  corrección clínica ni beneficio de control.
- El umbral `emgRms>=0.50` separa bien `acceptance`, pero la variación disponible
  en `steadyRest` es demasiado pequeña. Relajarlo ahora sería una decisión
  retrospectiva y no está permitido.
- Continúan abiertos los problemas heredados: discontinuidad `0 -> PWM 64`,
  penalización específica de saturación pequeña, gate común de reposo y numerosas
  intervenciones de seguridad. No se corrigieron en 7R.
- La política continúa produciendo acciones altas en reposo. ETAPA 7R no resuelve
  la causa ni autoriza entrenamiento adicional.
- No se interpreta `saturationFraction=0.392086` como cuatro motores al máximo;
  sigue siendo la fracción de componentes motor-paso con
  `abs(effectiveAction)>=0.95`.
- Los logs demuestran comandos, no corriente eléctrica medida en Motor 2.

## 8. Confirmación explícita de que no se usó hardware

No se usó hardware, Myo, guante, puertos COM, PWM físico ni conexiones reales.
No se construyó `Env`, no se ejecutó planta ni simulador y no se calculó DTW.
No hubo entrenamiento. `simMotors=true` permanece como restricción de la línea,
aunque 7R solo leyó evidencia offline congelada.

## 9. Commits de la etapa

```text
64eceb8f Preregister Stage 7R real-state EMG attribution
daa65e4d Add Stage 7R real-state EMG attribution
```

Este informe se incorpora en un commit documental separado, cuyo SHA se registra
en el handoff final. No se hizo push: la orden de ETAPA 7R no lo autorizó.

## 10. Propuesta precisa para la siguiente etapa — no ejecutada

Proponer **ETAPA 7S: adquisición prospectiva de soporte emparejado en reposo**,
sin entrenamiento:

1. preinscribir y mantener sin cambios los umbrales de 7R;
2. congelar Agent200, `intentMarkov60`, reward, cuantización, TD3, simulador,
   gate y seguridad;
3. generar con `simMotors=true` episodios adicionales independientes de reposo
   causal, con suficiente variación EMG calibrada dentro de reposo declarado y
   sin crear estados híbridos;
4. balancear de forma prospectiva al menos cinco folds, 20 episodios query y
   suficientes donors por fuente para que la reutilización máxima sea `<=0.10`;
5. comprobar primero soporte, hashes y ausencia de fuga, sin mirar los modelos;
6. solo si el gate prospectivo pasa, volver a ejecutar exactamente el análisis
   confirmatorio de 7R sobre el nuevo conjunto bloqueado;
7. si no puede obtenerse separación EMG causalmente válida en `steadyRest`,
   cerrar esta vía como no identificable con el diseño actual.

ETAPA 7S no se ejecutó. No se autoriza smoke, piloto, campaña, DTW ni hardware.
