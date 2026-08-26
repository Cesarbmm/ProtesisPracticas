# ETAPA 7 - DTW y retardo como metricas offline

Fecha de cierre: 2026-08-26.

Este informe documenta exclusivamente la ETAPA 7. El historial tecnico
detallado de las ETAPAS 0 a 6C, incluida la matematica de calibracion,
decodificacion, referencia viable, estados, reward, controlador convencional y
el problema multifactorial observado en ETAPA 6, esta consolidado en
`technical_history_stages_00_to_06c.md`.

## 1. Resultado de la etapa: PASS

La implementacion, las pruebas y la ejecucion reproducible de las metricas
temporales offline finalizaron correctamente. El resultado de ingenieria de la
ETAPA 7 es **PASS**: se midieron MSE sin desplazamiento, MSE con retardos
discretos, correlacion, retardo por motor/regimen y DTW restringido con un unico
camino multivariable para los cuatro motores.

El gate cientifico para introducir DTW en la recompensa es, sin embargo,
**NO APROBADO**:

- Agent200 mejora `0.919703%` con su mejor lag fijo agregado;
- Agent200 mejora `1.066758%` con DTW restringido;
- ambos valores son menores que el umbral previo de beneficio material de `5%`;
- el controlador P tampoco alcanza el umbral: `4.741186%` con lag fijo y
  `3.497170%` con DTW;
- los lags por motor y regimen no forman un unico retardo causal comun: tienen
  signos diferentes y muchos optimos caen en los limites `-3` o `+3` de la
  busqueda.

Por ello, DTW permanece solo como metrica. Se cancela la ETAPA 8 de reward DTW
bajo esta evidencia y estos limites. Esto no demuestra que el sistema carezca
de dinamica temporal; demuestra que el alineamiento ensayado no explica una
fraccion material del error agregado ni justifica alterar la reward.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base verificado de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a la implementacion de ETAPA 7:
  `1656992bee32aed8ee8566f3c1d3cc3fcbcb0fc3`;
- commit de codigo, pruebas y launcher de ETAPA 7:
  `3430ec6f1a0b8001b43b86efe8ff442a1a08e59a`;
- SHA del codigo fuente registrado por el artefacto final:
  `3430ec6f1a0b8001b43b86efe8ff442a1a08e59a`.

El manifiesto final registra `gitTrackedDirty=false`. `gitDirty=true` se debe
unicamente al archivo local ajeno y no rastreado `matlab_code.zip`, que fue
preservado y no forma parte de ningun commit.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage7TemporalMetrics.m`:
  analizador reusable, estrictamente offline.
- `matlab_code/tests/no_glove/testNoGloveStage7TemporalMetrics.m`:
  cinco pruebas deterministas del contrato temporal y DTW.
- `matlab_code/workflows/published/run_no_glove_stage7_offline_temporal_analysis.m`:
  launcher reproducible, validacion de hashes, pruebas, exportacion y
  manifiesto.
- `docs/no_glove_experiment/07_offline_temporal_metrics.md`: este informe.

### Modificados

- `matlab_code/workflows/published/README.md`: registro del launcher de ETAPA 7
  y de sus limites offline.

No se modificaron `Env`, el estado, la reward, la politica, el generador de
referencia, la cuantizacion, `SimController`, `encoder2Flex`, la calibracion ni
los checkpoints.

## 4. Decisiones tecnicas y justificacion

### 4.1 Fuente inmutable y comparacion emparejada

La entrada es el resultado final de ETAPA 6C:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage6_artifacts\stage6c_final\2026-08-26_03-14-26-280`

Se verificaron antes y despues del analisis:

- `manifest.json` de 6C:
  `DCF6D777D23A89E3621B197E4F0D5FC32B4AD2C3E38E3C1418ACC13A15AFCEEE`;
- `stage6c_results.mat` de 6C:
  `E2A17C795AD388DAD924421CE1E1CD077325BACC63160AA3A9921EB695631329`.

El hash de `stage6c_results.mat` fue identico antes y despues. Se analizaron las
dos fuentes emparejadas de comandos, `Agent200` y `conventionalP`, sobre las
mismas referencias e inicios de episodio: 50 episodios de aceptacion y 24 de
reposo por fuente.

### 4.2 Convencion y MSE con lag discreto

Sea `ell` un lag entero. Un lag positivo significa respuesta retrasada:

```text
q(t + ell) se compara con q_ref(t), ell > 0
```

Para el conjunto de indices validos `I_ell`, se calcula:

```text
MSE_ell = (1 / N_ell) * sum_(e,c,t en I_ell)
          (q_e,c(t + ell) - q_ref,e,c(t))^2
```

Para `ell < 0` se desplaza la referencia en sentido equivalente sin cruzar
episodios. Cada episodio debe tener pasos contiguos y exactamente una muestra
por motor-paso.

Una comparacion ingenua de `MSE_ell` con el MSE de toda la serie favoreceria
lags grandes al eliminar extremos. Para evitar ese sesgo, el launcher vuelve a
calcular cero lag sobre exactamente el mismo soporte `I_ell`:

```text
MSE_0|I_ell = (1 / N_ell) * sum_(e,c,t en I_ell)
              (q_e,c(t) - q_ref,e,c(t))^2

beneficio_ell = (MSE_0|I_ell - MSE_ell) / MSE_0|I_ell
```

Se busca `ell` en `[-3,+3]`, equivalente a `[-0.6,+0.6] s` para
`DeltaT=0.2 s`. El mejor lag maximiza el beneficio relativo; los empates se
resuelven con el menor valor absoluto. La correlacion se calcula sobre las
mismas parejas alineadas y se reporta separadamente del MSE.

### 4.3 Regimenes de movimiento

El analisis por motor usa la velocidad de referencia causal de ETAPA 6C y el
umbral `v_thr=0.005`:

```text
opening: v_ref <= -v_thr
hold:    |v_ref| < v_thr
closing: v_ref >= +v_thr
```

Solo se resume un regimen cuando hay al menos 10 muestras. Esta
estratificacion localiza patrones temporales, pero no sustituye la metrica
agregada ni autoriza seleccionar un lag diferente durante la evaluacion segun
informacion futura.

### 4.4 DTW multivariable restringido

Para cada episodio se forman matrices `Q,Qref` de dimension `4 x T` y se hace
una sola llamada:

```matlab
[rawDistance, ix, iy] = dtw(Q, Qref, 1, "squared");
E = Q(:, ix) - Qref(:, iy);
D_DTW = mean(E.^2, "all");
L_warp = mean(abs(ix - iy)) / max(1, maxLagSteps);
```

No se calculan cuatro caminos independientes. La distancia se normaliza por el
numero real de componentes del camino, `4*length(ix)`, no por una ventana `K`.
Se verifican dos invariantes:

```text
rawDistance = sum(E.^2, "all")
abs(ix - iy) <= 1
```

El error de extremo actual se conserva siempre:

```text
MSE_endpoint = mean((Q - Qref).^2, "all")
beneficio_DTW = (MSE_endpoint - D_DTW) / MSE_endpoint
```

Tambien se registran lag absoluto medio, lag firmado medio, penalizacion de
camino, longitud real y maxima discrepancia numerica entre distancia y camino.

### 4.5 Regla de evidencia

Con `beta_min=0.05` y dominancia fija `rho=0.80`:

```text
fixedLagPreferred:
  lag != 0, beneficio_lag >= beta_min y
  beneficio_lag >= rho * beneficio_DTW

dtwMetricCandidate:
  beneficio_DTW >= beta_min y no domina el lag fijo

noMaterialTemporalBenefit:
  ninguno alcanza beta_min
```

Esta regla no afirma causalidad a partir de correlacion. Solo determina si la
alineacion explica suficiente error como para justificar otra ablacion.

### 4.6 Separacion experimental

El launcher no carga agente, no crea `Env`, no invoca simulador ni reward y no
entrena. DTW se usa solamente como metrica de evaluacion. El manifiesto fija:

```text
stateChanged=false
rewardChanged=false
policyChanged=false
referenceChanged=false
quantizationChanged=false
simulatorChanged=false
dtwRewardUsed=false
stage8Authorized=false
```

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Revision estatica

Se ejecuto `checkcode(...,"-id")` sobre:

- `analyzeNoGloveStage7TemporalMetrics.m`: 0 incidencias;
- `testNoGloveStage7TemporalMetrics.m`: 0 incidencias;
- `run_no_glove_stage7_offline_temporal_analysis.m`: 0 incidencias.

### 5.2 Pruebas especificas de ETAPA 7

El launcher ejecuto:

```matlab
runtests("tests/no_glove/testNoGloveStage7TemporalMetrics.m")
```

Resultado exacto: 5 totales, 5 PASS, 0 FAIL, 0 incompletas.

Casos cubiertos:

1. una respuesta sintetica retrasada un paso recupera exactamente `+1` y
   `0.2 s`;
2. DTW usa un camino compartido, metrica `squared`, restriccion de lag y
   normalizacion por longitud real;
3. regimenes, regla de evidencia y flags offline;
4. rechazo de pasos no contiguos;
5. rechazo de datos no finitos y limites de lag incompatibles.

### 5.3 Suite completa sin guante

```matlab
results = runtests("tests/no_glove");
```

Resultado exacto: 60 totales, 60 PASS, 0 FAIL, 0 incompletas. Incluye las
pruebas de ETAPAS 1 a 7 y no ejecuto entrenamiento ni hardware.

### 5.4 Launcher final reproducible

La orden exacta esta guardada en `reproducible_command.txt`. En forma resumida:

```matlab
run_no_glove_stage7_offline_temporal_analysis(struct( ...
    "stage6cRunRoot", stage6cRunRoot, ...
    "resultsRoot", resultsRoot, ...
    "maxDiscreteLagSteps", 3, ...
    "dtwMaxLagSteps", 1, ...
    "activeVelocityThreshold", 0.005, ...
    "minimumRegimeSamples", 10, ...
    "minimumBenefitFraction", 0.05, ...
    "fixedLagDominanceFraction", 0.80, ...
    "periodSec", 0.2));
```

Resultado exacto impreso: `ETAPA 7 OFFLINE TEMPORAL PASS`.

MATLAB: `23.2.0.3097123 (R2023b) Update 11`.

## 6. Metricas y artefactos generados

### 6.1 Aceptacion agregada

| Fuente | MSE extremo | Mejor lag | MSE en lag | MSE cero, mismo soporte | Beneficio lag | Mejor lag correlacion | Correlacion |
|---|---:|---:|---:|---:|---:|---:|---:|
| Agent200 | 0.075152412 | -2 (-0.4 s) | 0.075650082 | 0.076352296 | 0.919703% | 0 | 0.705227 |
| conventionalP | 0.033790824 | -3 (-0.6 s) | 0.033853673 | 0.035538625 | 4.741186% | -2 (-0.4 s) | 0.874259 |

El MSE del mejor lag puede ser numericamente mayor que el MSE extremo completo,
porque su comparador correcto es el MSE cero sobre el mismo soporte recortado.
La columna de beneficio usa ese comparador justo.

### 6.2 DTW compartido en aceptacion

| Fuente | Episodios | MSE extremo | D_DTW | Beneficio | Lag abs. medio | Lag firmado medio | Camino medio |
|---|---:|---:|---:|---:|---:|---:|---:|
| Agent200 | 50 | 0.075152412 | 0.074350717 | 1.066758% | 0.268293 pasos / 0.053659 s | +0.268293 / +0.053659 s | 61.5 |
| conventionalP | 50 | 0.033790824 | 0.032609101 | 3.497170% | 0.365079 pasos / 0.073016 s | -0.126984 / -0.025397 s | 63.0 |

El maximo lag observado fue 1 paso en ambos casos. La discrepancia maxima entre
`rawDistance` y la suma cuadratica sobre el camino fue `1.0658e-14` para
Agent200 y `8.8818e-15` para P.

### 6.3 Lags por motor y regimen

| Fuente | Motor | opening | hold | closing |
|---|---:|---:|---:|---:|
| Agent200 | M1 | +3 / 30.834% | -1 / 1.780% | -3 / 22.465% |
| Agent200 | M2 | +3 / 72.496% | 0 / 0% | +3 / 63.650% |
| Agent200 | M3 | +3 / 77.356% | -1 / 1.477% | +3 / 64.615% |
| Agent200 | M4 | 0 / 0% | -3 / 31.938% | 0 / 0% |
| conventionalP | M1 | -2 / 58.674% | +1 / 1.438% | 0 / 0% |
| conventionalP | M2 | +1 / 0.488% | +2 / 0.002% | -3 / 21.384% |
| conventionalP | M3 | +3 / 8.053% | -1 / 0.815% | -3 / 39.247% |
| conventionalP | M4 | +2 / 52.599% | +3 / 11.418% | -3 / 36.950% |

Cada celda muestra `lag en pasos / beneficio sobre igual soporte`. Los valores
altos locales no constituyen un retardo global: cambian de signo entre motores
y regimenes, y varios alcanzan el borde de busqueda. Son evidencia para una
prueba causal dirigida por regimen, no para perdonar el error con DTW en la
reward.

### 6.4 Reposo

| Fuente | MSE extremo | D_DTW | Beneficio DTW | Lag DTW abs. medio |
|---|---:|---:|---:|---:|
| Agent200 | 0.069452113 | 0.069452113 | ~0% | 0 |
| conventionalP | 0 | 0 | 0% | 0 |

En Agent200, el barrido discreto selecciona `-3` con `7.715%` sobre el soporte
recortado, pero `q_ref` esta en hold y DTW elige camino diagonal sin beneficio.
Por tanto, ese valor se interpreta como efecto de seleccionar otra porcion de
una deriva/actividad no estacionaria, no como evidencia de que un retardo de
reposo deba compensarse.

### 6.5 Decision

| Fuente | Clasificacion | Beneficio lag | Beneficio DTW | Decision |
|---|---|---:|---:|---|
| Agent200 | `noMaterialTemporalBenefit` | 0.919703% | 1.066758% | cancelar reward DTW bajo el limite ensayado |
| conventionalP | `noMaterialTemporalBenefit` | 4.741186% | 3.497170% | cancelar reward DTW bajo el limite ensayado |

### 6.6 Ruta y hashes

Artefacto final:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7_artifacts\stage7_final\2026-08-26_09-44-49-329`

Hashes principales:

- `manifest.json`:
  `B2DAE36AEC2178A702688CDDD2C131711CD3384BCFE0344F68DE7935F1D64F5D`;
- `stage7_results.mat`:
  `BACD23C33683DB7DED8B1C97D5085D3BAAC3E371F30E10888B68B5A22ADBAC4F`;
- `offline_report.md`:
  `651C5E671ED9792622A2A8BC4D0B854E0ED7499287EB3FE66BFC056A89D5155F`;
- `acceptance_evidence_decision.csv`:
  `5BC9F62AE385D7F963484325A90019670439A83EDD8499538844ECC593988709`;
- `acceptance_regime_summary.csv`:
  `5E3EDF7D61E1B62DDB94CC0AD27C86D8528E9E7D8EEE77BBB88661B99F3C8D3C`.

El directorio contiene 14 CSV de resultados, MAT de resultados/pruebas,
reporte offline, comando reproducible, hashes y manifiestos MAT/JSON.

## 7. Riesgos, supuestos y cuestiones no resueltas

- Las referencias y EMG de estas pruebas son sinteticas. Los resultados no se
  extrapolan a Myo real ni a fisiologia real.
- El analisis reutiliza trazas de 6C; no excita la planta con un protocolo nuevo
  diseñado especificamente para identificacion temporal.
- Un optimo en `+3` o `-3` indica que el minimo local puede estar fuera del
  intervalo explorado. Ampliar la ventana tambien aumenta efectos de borde y no
  debe hacerse dentro de una reward sin una prueba causal separada.
- Los lags por regimen se estiman offline usando la etiqueta de regimen de
  `v_ref`. No son una politica causal ni pueden seleccionarse retrospectivamente
  durante control.
- Correlacion alta no implica retardo causal. Puede provenir de la forma comun
  de la trayectoria o de una referencia integrada y suave.
- DTW con `maxLagSteps=1` perdona como maximo `0.2 s`. Este limite fue fijado por
  el plan experimental y no se reinterpretara despues de observar resultados.
- El beneficio agregado menor que 5% no resuelve las regresiones funcionales de
  M2/M3/M4 encontradas en 6C. Solo descarta DTW como siguiente cambio de reward.
- No se midio corriente electrica. Las trazas contienen comandos y encoders
  simulados, no corriente.
- El primer intento del launcher genero un directorio parcial fuera del repo,
  `offline_temporal/2026-08-26_09-42-13-229`, antes de corregir una concatenacion
  de texto del reporte. No contiene manifiesto PASS y no es un resultado valido.
  El artefacto canonico es exclusivamente `stage7_final/2026-08-26_09-44-49-329`.
- `matlab_code.zip` sigue ajeno, sin rastrear y sin modificar.

## 8. Confirmacion explicita de que no se uso hardware

No se activo hardware, Myo, guante, puertos COM, PWM fisico ni conexiones
reales. Tampoco se creo `Env`, se invoco `SimController`, se cargo Agent200 o
Agent7250, se entreno RL ni se evaluo una reward. Todo el calculo fue offline
sobre tablas ya publicadas por ETAPA 6C.

El manifiesto registra:

```text
hardwareUsed=false
agentLoaded=false
agent7250Loaded=false
reinforcementLearningInvoked=false
envCreated=false
simulatorInvoked=false
rewardInvoked=false
```

El checkpoint canonico Agent7250 permanecio intacto con SHA-256:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 9. Commits de la etapa

- codigo, pruebas, launcher y registro del workflow:
  `3430ec6f1a0b8001b43b86efe8ff442a1a08e59a`
  (`feat: add offline stage7 temporal analysis`);
- el commit documental se registra al cerrar este informe.

La rama se publicara en `origin/experiment/no-glove-intent-control`. No se abre
PR porque no fue autorizado.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8: el gate DTW fallo y el manifiesto fija
`stage8Authorized=false` y `cancelDtwRewardStages=true`.

La siguiente actividad propuesta, sujeta a autorizacion explicita, es una
ablacion causal de diagnostico temporal **sin DTW y sin cambiar simultaneamente
estado, reward, cuantizacion o simulador**:

1. diseñar excitaciones reproducibles separadas para M2 y M3 en apertura y
   cierre, porque sus optimos locales de Agent200 caen en `+3`;
2. ampliar solo la medicion offline del lag hasta localizar o refutar el minimo,
   manteniendo un conjunto de evaluacion con extremos no recortados;
3. probar como intervenciones separadas una referencia causal filtrada y una
   compensacion fija previamente identificada;
4. comparar contra Agent200 y P con las mismas semillas, referencias, inicios y
   presupuesto;
5. conservar MSE de extremo, saturacion, `deltaActionL2`, flags por motor y costo
   computacional;
6. si no aparece una mejora causal material, cerrar la hipotesis temporal y
   volver al diagnostico de ley de control/seguridad de ETAPA 6.

Esta propuesta no fue ejecutada. No se autoriza hardware ni ETAPA 8.
