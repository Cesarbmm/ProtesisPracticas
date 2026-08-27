# ETAPA 7A - confirmacion held-out de retardos

Fecha de cierre: 2026-08-26.

Esta etapa fue autorizada como continuacion de la recomendacion emitida al
cerrar ETAPA 7. No corresponde a ETAPA 8: DTW sigue cancelado como reward. El
objetivo fue determinar si los lags locales observados en M2/M3 eran
reproducibles fuera de la muestra usada para seleccionarlos y si se podia
autorizar, con evidencia causal suficiente, una intervencion posterior de
compensacion o filtrado.

## 1. Resultado de la etapa: PASS

La ejecucion de ingenieria es **PASS**:

- se implemento seleccion de lag con validacion held-out por `repetitionId`;
- todos los lags usan exactamente el mismo soporte temporal interior;
- se conserva y reporta por separado el MSE de extremo completo;
- se ejecutaron pruebas sinteticas deterministas y la suite completa;
- se generaron launcher, semilla, manifiesto, hashes y artefactos;
- no se uso DTW, agente, simulador, reward, entrenamiento ni hardware.

El gate cientifico de compensacion causal para Agent200 es **NO APROBADO** y su
clasificacion es `temporalPatternUnresolved`:

- 0 de 4 combinaciones motor-regimen confirmaron un lag fijo interior;
- 0 combinaciones fueron candidatas a compensacion causal;
- las 4 combinaciones seleccionaron el borde de la ventana en los 6 folds;
- M3-apertura selecciono un lag negativo, incompatible con interpretarlo como
  un tiempo muerto positivo comun;
- no se ejecuto compensacion ni filtrado porque esta etapa termina en el gate.

Una reduccion de MSE grande despues de desplazar curvas no basta para declarar
retardo causal cuando el minimo no esta localizado dentro de la ventana. El
resultado protege la causalidad experimental y evita una intervencion basada
en un artefacto de forma, fase o segmentacion.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7A:
  `7d8c3b0c4fe2e9b5297323d3ab7421e768a5e7cf`;
- commit de codigo, pruebas y launcher:
  `84472fc64444cd30cfa710021598bd283cc3b16f`;
- SHA registrado por el artefacto canonico:
  `84472fc64444cd30cfa710021598bd283cc3b16f`.

El manifiesto registra `gitTrackedDirty=false`. `gitDirty=true` se explica solo
por el archivo local ajeno y no rastreado `matlab_code.zip`, preservado sin
cambios y excluido del commit.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage7aLagConfirmation.m`:
  seleccion y evaluacion held-out con soporte comun.
- `matlab_code/tests/no_glove/testNoGloveStage7aLagConfirmation.m`:
  seis pruebas deterministas.
- `matlab_code/workflows/published/run_no_glove_stage7a_lag_confirmation.m`:
  launcher reproducible y contrato de hashes.
- `docs/no_glove_experiment/07a_held_out_lag_confirmation.md`:
  este informe.

### Modificado

- `matlab_code/workflows/published/README.md`: registro del launcher y sus
  restricciones.

No se modificaron `Env`, el estado `intentMarkov60`, la reward, la politica, el
decodificador, la referencia, la cuantizacion, `SimController`,
`encoder2Flex`, la capa de seguridad ni los checkpoints.

## 4. Decisiones tecnicas y justificacion

### 4.1 Cadena de evidencia inmutable

ETAPA 7A parte del artefacto canonico de ETAPA 7:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7_artifacts\stage7_final\2026-08-26_09-44-49-329`

El launcher exige que ETAPA 7 tenga:

```text
result=PASS
temporalBenefitGatePassed=false
cancelDtwRewardStages=true
stage8Authorized=false
hardwareUsed=false
```

Desde ese manifiesto resuelve el `stage6c_results.mat` emparejado y vuelve a
validar ambos hashes antes y despues del analisis. No se aceptan rutas de datos
arbitrarias ni una salida 7 que hubiese autorizado DTW.

### 4.2 Folds sin fuga entre seleccion y evaluacion

Los 50 episodios de aceptacion contienen seis valores de `repetitionId`. Para
cada fuente, motor y regimen se ejecuta leave-one-repetition-out:

```text
fold k:
    calibracion = todos los episodios con repetitionId != k
    evaluacion  = todos los episodios con repetitionId == k
```

El lag se selecciona exclusivamente en calibracion. El fold retenido no puede
influir en la seleccion. Las seis evaluaciones se agregan usando sumas de error
cuadratico y numero real de muestras, no una media no ponderada de MSE por fold.

### 4.3 Soporte comun para todos los lags

Con `L=5` pasos y un episodio de longitud `T`, se fija una sola vez:

```text
I = {L+1, ..., T-L}
```

Para cada `ell` en `[-L,+L]`:

```text
q_ell(t) = q(t + ell), t en I
MSE_ell  = mean((q_ell(t) - q_ref(t))^2)
MSE_0    = mean((q(t)     - q_ref(t))^2), t en I

beneficio_ell = (MSE_0 - MSE_ell) / MSE_0
```

El conjunto `I`, las etiquetas de regimen y el numero de muestras son
identicos para los once candidatos. Asi se elimina el sesgo de comparar
ventanas recortadas de manera diferente. Un lag positivo conserva la
convencion de ETAPA 7:

```text
q(t + ell) frente a q_ref(t), ell > 0
```

Por tanto, `ell>0` es compatible con respuesta retrasada. `ell<0` no se puede
reinterpretar como tiempo muerto positivo.

### 4.4 Regimenes y error de extremo

Se analizaron M2 y M3, en apertura y cierre:

```text
opening: referenceVelocity <= -0.005
closing: referenceVelocity >= +0.005
```

El MSE completo de cada regimen se calcula adicionalmente sin desplazamiento y
sin ocultarlo tras la ventana interior. En este corpus las muestras activas
quedan dentro del soporte comun, por lo que el MSE completo y `MSE_0` coinciden;
esto permite comprobar que la mejora no procede de excluir extremos activos.

### 4.5 Gate de confirmacion

Una combinacion motor-regimen solo confirma un lag fijo si cumple todos los
puntos:

```text
beneficio held-out ponderado >= 5%
fraccion de folds con beneficio >= 5% >= 2/3
consistencia del signo dominante >= 80%
fraccion de selecciones en el borde <= 50%
signo dominante != 0
```

Ademas, solo un signo dominante positivo puede producir
`causalCompensationCandidate=true`. Un patron negativo puede ser reproducible,
pero no se denomina retardo de planta ni autoriza anticipar usando informacion
futura.

### 4.6 Separacion entre fuentes

Agent200 y `conventionalP` se analizan por separado. Un candidato causal del P
no se transfiere a Agent200 porque las fuentes de comando y sus leyes de control
son distintas. La decision primaria se toma unicamente con `Agent200`.

### 4.7 Gate antes de intervencion

La etapa se detiene despues de medir. Incluso si el gate hubiera pasado, el
launcher no habria aplicado automaticamente un filtro o compensacion; habria
exigido una etapa separada. El manifiesto fija:

```text
compensationInterventionExecuted=false
filteredReferenceInterventionExecuted=false
dtwCalculated=false
dtwRewardUsed=false
stage8Authorized=false
```

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Revision estatica

`checkcode(...,"-id")`:

- analizador: 0 incidencias;
- pruebas: 0 incidencias;
- launcher: 0 incidencias.

### 5.2 Pruebas especificas

```matlab
runtests("tests/no_glove/testNoGloveStage7aLagConfirmation.m")
```

Resultado: 6 totales, 6 PASS, 0 FAIL, 0 incompletas.

Casos verificados:

1. un retardo sintetico conocido de `+2` se recupera en folds held-out y pasa
   el gate;
2. modificar el fold retenido no cambia el lag seleccionado para ese fold;
3. retardos alternados `+2/-2` fallan por inconsistencia de signo;
4. un optimo sintetico en `+5` se clasifica `boundaryUnresolved`;
5. todos los lags usan el mismo numero de muestras y el mismo `MSE_0`;
6. se rechazan pasos no contiguos y datos no finitos.

### 5.3 Suite completa sin guante

```matlab
runtests("tests/no_glove")
```

Resultado exacto: 66 totales, 66 PASS, 0 FAIL, 0 incompletas.

### 5.4 Launcher final

```matlab
run_no_glove_stage7a_lag_confirmation(struct( ...
    "stage7RunRoot", stage7RunRoot, ...
    "resultsRoot", resultsRoot, ...
    "seed", 7171, ...
    "targetMotors", [2 3], ...
    "targetRegimes", ["opening" "closing"], ...
    "maxLagSteps", 5, ...
    "activeVelocityThreshold", 0.005, ...
    "minimumSamplesPerFold", 10, ...
    "minimumBenefitFraction", 0.05, ...
    "minimumMaterialFoldFraction", 2/3, ...
    "minimumSignConsistency", 0.80, ...
    "maximumBoundaryFraction", 0.50, ...
    "periodSec", 0.2));
```

Resultado impreso: `ETAPA 7A HELD-OUT LAG CONFIRMATION PASS`.

MATLAB: R2023b Update 11.

## 6. Metricas y artefactos generados

### 6.1 Agent200, decision primaria

| Motor | Regimen | MSE extremo | MSE lag held-out | Reduccion | Lag en 6 folds | Borde | Clasificacion |
|---:|---|---:|---:|---:|---:|---:|---|
| M2 | opening | 0.127839654 | 0.005983721 | 95.319% | +5 | 100% | `boundaryUnresolved` |
| M2 | closing | 0.045427550 | 0.006034289 | 86.717% | +5 | 100% | `boundaryUnresolved` |
| M3 | opening | 0.314700798 | 0.003150737 | 98.999% | -5 | 100% | `boundaryUnresolved` |
| M3 | closing | 0.187054837 | 0.023228798 | 87.582% | +5 | 100% | `boundaryUnresolved` |

Las reducciones son grandes pero no localizan un minimo interior. Los seis folds
seleccionan exactamente el mismo borde en cada caso. Ampliar indefinidamente la
ventana despues de ver el resultado permitiria alinear fases diferentes de la
trayectoria y perdonar retardos excesivos; no se hizo esa modificacion
post-hoc.

Resumen Agent200:

```text
confirmedFixedLagCount=0
causalCandidateCount=0
unresolvedCount=4
causalCompensationGatePassed=false
classification=temporalPatternUnresolved
```

### 6.2 Controlador P, comparador

| Motor | Regimen | Reduccion | Lag | Borde | Clasificacion |
|---:|---|---:|---:|---:|---|
| M2 | opening | 0.488% | +1 | 0% | `noHeldOutMaterialBenefit` |
| M2 | closing | 38.722% | -5 | 100% | `boundaryUnresolved` |
| M3 | opening | 8.053% | +3 | 0% | `positiveDelayConfirmed` |
| M3 | closing | 57.481% | -4 | 0% | `negativeLagPattern` |

M3-apertura del P es un candidato causal interior para una intervencion futura
especifica del P. No autoriza modificar Agent200. M3-cierre presenta signo
negativo y no se llama tiempo muerto.

### 6.3 Ruta y hashes

Artefacto canonico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7a_artifacts\stage7a_final\2026-08-26_22-56-01-823`

Hashes principales:

- `manifest.json`:
  `BA318AC40C3571C15D8E07D589DB09F9FD2C4D4EE1C4242C2F91E0F7182B6492`;
- `stage7a_results.mat`:
  `80530B365D1DD290D09521DAE4AEE83C928AB1AF0DDF46D365220D8C99076309`;
- `offline_report.md`:
  `790F41E83B577520F9E5E553B32B100F799AF5ADB71837C7514282B19641C90D`;
- `lag_confirmation_summary.csv`:
  `2D27575FE08113601D142754A1D0EE9BF7DE19A41EEDC13E97D86167BD02A580`;
- `source_decision.csv`:
  `CDBDF2DB0997E745909CE8F974D097A6FE65BDB3D73187733C2F87EE06B3B45F`.

Los hashes de entrada fueron identicos antes y despues:

- ETAPA 7: `BACD23C33683DB7DED8B1C97D5085D3BAAC3E371F30E10888B68B5A22ADBAC4F`;
- ETAPA 6C: `E2A17C795AD388DAD924421CE1E1CD077325BACC63160AA3A9921EB695631329`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- Agent200 conserva cuatro patrones no localizados. No se ha demostrado si
  provienen de tiempo muerto, forma de trayectoria, integracion de referencia,
  limites, politica o segmentacion por regimen.
- Una seleccion en el borde no significa que el retardo real sea exactamente
  `1 s`; significa que el minimo no se localizo dentro de la ventana permitida.
- M3-apertura cambia de `+3` en ETAPA 7 a `-5` con la ventana ampliada. Esta
  inestabilidad contradice la hipotesis de un retardo positivo simple.
- Los episodios no fueron diseñados originalmente como identificacion de
  tiempo muerto. Comparten formas de referencia integradas y periodos hold.
- Ampliar la ventana post-hoc puede alinear apertura con cierre u otras fases y
  crear mejoras sin interpretacion causal.
- La evidencia positiva de P M3-apertura pertenece al controlador P. No se
  reutiliza como calibracion de Agent200.
- No se probo referencia filtrada ni compensacion. Hacerlo ahora violaria el
  gate-first documentado.
- El corpus EMG y la calibracion siguen siendo sinteticos.
- No se midio corriente electrica; solo existen comandos y posiciones
  simuladas previamente publicadas.
- `matlab_code.zip` permanece ajeno, no rastreado y sin modificar.

## 8. Confirmacion explicita de que no se uso hardware

No se uso hardware, Myo, guante, puertos COM, PWM fisico ni conexiones reales.
No se cargo Agent200 o Agent7250, no se creo `Env`, no se invoco simulador o
reward, no se calculo DTW y no se entreno RL. El analisis fue exclusivamente
offline sobre las tablas inmutables de ETAPA 6C.

El manifiesto fija `simMotors=true` como requisito de la linea, aunque el
simulador no fue invocado, y registra `hardwareUsed=false`.

Agent7250 permanecio intacto con SHA-256:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 9. Commit de la etapa

- codigo, pruebas, launcher y README:
  `84472fc64444cd30cfa710021598bd283cc3b16f`
  (`feat: confirm stage7a lags on held-out folds`);
- el commit documental se registra al cerrar este informe.

No se hace push ni se abre PR en esta etapa porque la orden actual autorizo
continuar la etapa, pero no emitio una nueva autorizacion explicita de push.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8 ni una compensacion sobre las trazas actuales.

La siguiente propuesta es **ETAPA 7B - excitacion temporal diseñada en
simulacion**, sujeta a autorizacion explicita:

1. congelar Agent200 y el P; no entrenar ni cargar Agent7250;
2. construir perfiles EMG-intencion pregrabados con rampas separadas, mesetas
   largas y retornos a hold que permitan distinguir tiempo muerto de forma;
3. usar la misma calibracion sintetica, `B`, limites y posiciones iniciales para
   ambas fuentes;
4. evaluar Agent200 y P por separado en `SimController`, siempre
   `simMotors=true`, con semillas y perfiles identicos;
5. medir respuesta al inicio y fin de cada rampa, tiempo muerto, velocidad,
   signo, saturacion, seguridad y error de extremo sin DTW;
6. predefinir la ventana maxima antes de observar resultados y exigir un minimo
   interior reproducible en folds held-out;
7. solo si Agent200 confirma un retardo positivo interior, proponer en otra
   etapa una unica intervencion target-only causal; no mezclar filtro,
   compensacion, reward, cuantizacion o simulador.

ETAPA 7B no fue ejecutada. No se autoriza hardware, DTW reward ni ETAPA 8.
