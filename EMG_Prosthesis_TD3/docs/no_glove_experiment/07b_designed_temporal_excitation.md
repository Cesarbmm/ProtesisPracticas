# ETAPA 7B - excitacion temporal disenada en simulacion

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada como continuacion de la propuesta emitida al cerrar
ETAPA 7A. No corresponde a ETAPA 8. Su objetivo fue sustituir, solo para la
evaluacion, las trayectorias poco identificables de la campana anterior por
perfiles EMG-intencion con fases temporales predefinidas, sin cambiar politica,
estado, reward, cuantizacion, simulador, seguridad o referencia mecanica.

## 1. Resultado de la etapa: PASS

La ejecucion de ingenieria es **PASS**:

- se construyeron 16 perfiles EMG-only sinteticos y deterministas;
- los 16 perfiles pasaron validacion de reposo, signo, dominancia de sinergia,
  finitud y limites;
- el smoke controlado de 2 episodios y la evaluacion completa de 16 episodios
  finalizaron en simulacion;
- Agent200 congelado y el controlador P recibieron exactamente las mismas
  referencias y posiciones iniciales;
- hubo cero violaciones de posicion y 23/23 hashes de artefactos coincidieron;
- `checkcode`, las pruebas especificas y la suite `no_glove` pasaron;
- no se entreno, no se cargo Agent7250 y no se uso hardware.

El gate cientifico es **NO APROBADO**:

```text
classification=designedTemporalPatternUnresolved
causalCandidateCount=0/8
unresolvedAtPreRegisteredBound=5/8
causalCompensationGatePassed=false
```

No se identifico un retardo positivo, interior y reproducible que autorice una
compensacion causal. Ademas, Agent200 emitio comandos antes de que la referencia
disenada se activara. Por ello no se aplico compensacion, filtrado, DTW ni ningun
cambio conductual.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7B:
  `cdd77d61876eeab33ae4a8c7ced7ca89f5ce455c`;
- commit de codigo, pruebas, launcher y README:
  `f96336e5350e6ed8c3b0e674652a3de3ac7c6caa`;
- SHA registrado por el artefacto canonico:
  `f96336e5350e6ed8c3b0e674652a3de3ac7c6caa`.

El manifiesto registra `gitTrackedDirty=false`. `gitDirty=true` se debe
exclusivamente al archivo local ajeno y no rastreado `matlab_code.zip`, que se
preservo sin cambios y no se incluyo en ningun commit.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/runtime/buildNoGloveStage7bTemporalCorpus.m`: constructor
  determinista del corpus temporal EMG-only.
- `matlab_code/src/evaluation/analyzeNoGloveStage7bDesignedResponse.m`:
  analisis held-out por sinergia, latencias de eventos y gate compuesto.
- `matlab_code/tests/no_glove/testNoGloveStage7bDesignedExcitation.m`: seis
  pruebas deterministas y fail-closed.
- `matlab_code/workflows/published/run_no_glove_stage7b_designed_excitation.m`:
  launcher reproducible, smoke, evaluacion pareada, manifiesto y hashes.
- `docs/no_glove_experiment/07b_designed_temporal_excitation.md`: este informe.

### Modificado

- `matlab_code/workflows/published/README.md`: registro del launcher 7B y sus
  restricciones.

No se modificaron `Env`, `intentMarkov60`, el decodificador, el generador de
referencia, la reward, la politica, Agent200, Agent7250, `baselineQuantized`, el
simulador, `encoder2Flex`, el controlador P o la capa de seguridad.

## 4. Decisiones tecnicas y justificacion

### 4.1 Entradas inmutables

El launcher exige y valida antes de simular:

- ETAPA 7A canonica en
  `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7a_artifacts\stage7a_final\2026-08-26_22-56-01-823`;
- ETAPA 6 con seguridad de posicion en
  `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage6_artifacts\position_safety_smoke\2026-08-26_02-06-38-015`;
- Agent200 exactamente identificado por el inventario de checkpoints;
- `referenceSource="emgIntent"`, `intentMarkov60`,
  `trackingIntentActionRateReward`, `baselineQuantized`, politica feedforward y
  seguridad de posicion activa;
- `simMotors=true`, `connect_glove=false`, `run_training=false` y
  `newTraining=false`.

Los hashes de ETAPA 7A, el manifiesto de ETAPA 6 y Agent200 se vuelven a medir
despues de la ejecucion. Cualquier cambio hace fallar la etapa.

### 4.2 Corpus temporal pre-registrado

Se reutilizo la calibracion sintetica de la misma sesion que produjo Agent200.
No se genero una calibracion compatible solo por forma: el SHA de contenido
debia ser exactamente:

`9c2ff4aba271c337df076874b5ff7ed08a4a07bcf7970f358c886e05e15e43a2`.

Cada ventana cruda se construyo de forma determinista a partir de capturas de
reposo y contraccion de esa sesion:

```text
x_w = x_rest,w + alpha_w * x_active,w
```

Esta ecuacion describe un fixture sintetico de identificacion; no se presenta
como modelo fisiologico de EMG humana. La envolvente y la intencion siguieron la
cadena de ETAPA 2, antes de WMoos:

```text
m_c(t) = mean_n |x_c[n]|
a_c(t) = clip((m_c(t)-b_c)/(s_c-b_c+epsilon), 0, 1)
z_t    = tanh(W*a_t+b)
v_ref  = v_max .* clip(B*z_t, -1, 1)
```

Las 52 ventanas se fijaron antes de observar la respuesta:

| Fase | Ventanas | Escala `alpha` |
|---|---:|---|
| reposo previo | 8 | 0 |
| rampa ascendente | 6 | 0.25, 0.40, 0.55, 0.70, 0.85, 1.00 |
| meseta | 12 | 1.00 |
| rampa descendente | 6 | 0.85 a 0.15 |
| hold final | 20 | 0 |

Se crearon cuatro repeticiones de sinergia primaria y cuatro de pulgar; cada
repeticion tiene direccion positiva y negativa. Total: 16 perfiles. La
histeresis produjo 24 ventanas activas por perfil, desde la ventana 11 hasta la
34. Los ultimos diez holds tuvieron `v_ref=0` y gate de reposo inactivo.

### 4.3 Referencia y comparacion pareada

La referencia mantuvo la integracion causal ya validada:

```text
q_ref,t = clip(q_ref,t-1 + DeltaT*v_ref,t, q_min, q_max)
```

Agent200 se evaluo, sin entrenamiento, dentro de `Env`. Luego el controlador P
validado en ETAPA 5 se simulo con las mismas series `q_ref`, `v_ref` y la misma
posicion inicial de cada episodio:

```text
u_P = clip(Kp*(q_ref-q), -64/255, +64/255)
Kp  = 1.5, Kd = 0
```

Ambos conservaron la cuantizacion `baselineQuantized`, el simulador y la misma
capa de seguridad. Los cuatro errores maximos de emparejamiento fueron cero:

```text
referenceMaxAbs=0
referenceVelocityMaxAbs=0
initialPositionMaxAbs=0
sourceTemporalAlignmentMaxAbs=0
```

### 4.4 Seleccion held-out del lag

El analisis se separo por fuente, sinergia, motor M2/M3 y direccion. En cada
sinergia hubo cuatro folds leave-one-repetition-out. Con `L=5` pasos y periodo
del entorno `DeltaT=0.2 s`, todos los lags usan el mismo soporte interior:

```text
I = {L+1, ..., T-L}
MSE_ell = mean_t in I (q(t+ell)-q_ref(t))^2
beneficio_ell = (MSE_0-MSE_ell)/MSE_0
ell in {-5,...,+5}
```

Un lag positivo es compatible con respuesta tardia. Un lag negativo no se
reinterpreta como tiempo muerto. El error de extremo sin desplazamiento se
conserva por separado.

El gate de lag exige simultaneamente:

```text
beneficio held-out >= 5%
folds con beneficio material >= 75%
consistencia de signo >= 75%
selecciones en el borde <= 25%
lag dominante positivo y no nulo
```

No se amplio `L` despues de ver los resultados.

### 4.5 Latencia independiente por evento

Para no aceptar una alineacion estadistica incompatible con la secuencia
causal, se midio tambien:

```text
referencia activa: |v_ref| >= 0.005
respuesta direccional: sign(v_ref)*v >= 0.001
delay_on = primer paso de respuesta - primer paso activo de referencia
delay_off = primer bloque de 2 pasos asentados - ultimo paso activo
```

Antes de `referenceOn` se midieron de forma separada:

- existencia de movimiento;
- fraccion de pasos con `|PWM|>0`;
- PWM absoluto medio;
- accion efectiva absoluta media;
- velocidad absoluta media.

El gate de evento exige onset finito en 100% de repeticiones, cero movimiento
previo, cero comandos previos y onset mediano entre 0 y 5 pasos. El candidato
final es la conjuncion:

```text
causalCandidate = lagGate && eventGate
```

Esta separacion evita llamar retardo de planta a una trayectoria que ya estaba
siendo comandada antes de activar el target.

### 4.6 Gate antes de cualquier intervencion

El launcher siempre termina despues de medir. El manifiesto fija:

```text
causalCompensationGatePassed=false
compensationInterventionExecuted=false
filteredReferenceInterventionExecuted=false
dtwCalculated=false
dtwRewardUsed=false
stage8Authorized=false
```

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Revision estatica

Se ejecuto `checkcode(...,"-id")` sobre los cuatro archivos MATLAB nuevos.
Resultado exacto: 4/4 archivos limpios, 0 incidencias.

### 5.2 Pruebas especificas

```matlab
runtests("tests/no_glove/testNoGloveStage7bDesignedExcitation.m")
```

Resultado exacto: 6 totales, 6 PASS, 0 FAIL, 0 incompletas. Se verifico:

1. corpus completo y determinista;
2. fases temporales y validaciones pre-registradas;
3. retardo sintetico interior `+2` aceptado;
4. comando previo a la referencia rechazado aunque el lag pase;
5. optimo en el borde `+5` no autorizado;
6. emparejamiento imperfecto o violacion de posicion rechazados.

### 5.3 Suite completa

```matlab
runtests("tests/no_glove", "IncludeSubfolders", true)
```

Resultado exacto: 72 totales, 72 PASS, 0 FAIL, 0 incompletas.

### 5.4 Launcher canonico

Semillas y parametros efectivos:

```text
calibrationSeed=11
profileSeed=7701
smokeSeed=7702
evaluationSeed=7703
repetitionsPerAxis=4
maxLagSteps=5
periodSec=0.2
simulatorSamplingPeriod=0.005
```

La llamada completa esta guardada en `reproducible_command.txt` dentro del
artefacto. Resultado final impreso:

```text
ETAPA 7B DESIGNED EXCITATION PASS
Output: ...\stage7b_final\2026-08-27_01-18-31-833
```

MATLAB: R2023b Update 11. El proceso termino con codigo 0.

Una ejecucion inmediatamente anterior completo el launcher y escribio un
artefacto PASS, pero una instruccion de presentacion posterior al launcher
intento leer `report.scientificGateResult` en vez de
`report.manifest.scientificGateResult`, por lo que el proceso envolvente termino
con codigo 1. No se uso como artefacto canonico. La repeticion limpia produjo 13
CSV de protocolo, emparejamiento y analisis con hashes identicos a esa primera
ejecucion.

## 6. Metricas y artefactos generados

### 6.1 Validacion del fixture

```text
perfiles validos=16/16
reposo inicial valido=16/16
hold final valido=16/16
signo valido=16/16
dominancia de eje valida=16/16
salida finita y acotada=16/16
```

Cada combinacion primaria/pulgar y positiva/negativa tuvo cuatro perfiles.

### 6.2 Gate temporal de Agent200

| Sinergia | Direccion | Motor | Reduccion MSE | Lag mediano | Borde | PWM previo medio | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| pulgar | negativa | M2 | 13.380% | +5 | 100% | 231.75 | no resuelto en borde |
| pulgar | positiva | M2 | 15.540% | 0 | 100% | 118.30 | no resuelto en borde |
| pulgar | negativa | M3 | 26.662% | -5 | 100% | 112.00 | no resuelto en borde |
| pulgar | positiva | M3 | 5.595% | +1 | 0% | 67.20 | falla gate de evento |
| primaria | negativa | M2 | 4.462% | +5 | 100% | 230.975 | no resuelto en borde |
| primaria | positiva | M2 | 24.980% | +2 | 0% | 112.00 | falla gate de evento |
| primaria | negativa | M3 | 20.090% | -5 | 100% | 103.20 | no resuelto en borde |
| primaria | positiva | M3 | 41.491% | -3 | 0% | 59.20 | falla gate temporal |

Los dos lags positivos interiores que superaron el gate de alineacion (`+1` y
`+2`) fallaron el gate de evento. En las 32 trazas Agent200 de M2/M3:

```text
preReferenceMotionFraction=0.75
meanPreReferenceCommandFraction=0.990625
maximumPreReferenceCommandFraction=1
meanPreReferenceAbsPwm=129.328125
meanPreReferenceAbsEffectiveAction=0.507169118
```

El P tuvo cero movimiento, comando, PWM y accion efectiva antes de la
referencia en sus 32 trazas. Esto es evidencia de actividad anticipada de la
politica en este corpus; no demuestra por si solo su causa raiz.

### 6.3 Metricas agregadas pareadas

| Fuente | MSE posicion | MAE | MSE velocidad | actionL2 | deltaActionL2 | Saturacion |
|---|---:|---:|---:|---:|---:|---:|
| Agent200 | 0.088358205 | 0.202591475 | 0.152755714 | 0.246969948 | 0.066799443 | 0.083639706 |
| P | 0.015747911 | 0.069094225 | 0.560236031 | 0.023370800 | 0.192437985 | 0 |

El P redujo el error de posicion pero tuvo mayor MSE de velocidad. Esta tabla
no autoriza afirmar superioridad general: Agent200 es un checkpoint de smoke y
el objetivo de 7B fue identificacion temporal, no seleccion de politica.
Tampoco se compara este MSE de intencion disenada con el MSE del target de
guante de Agent7250.

Por motor, Agent200 tuvo saturacion solo en M2:

```text
M1=0
M2=0.334558824
M3=0
M4=0
```

La definicion sigue siendo la fraccion de componentes motor-paso con
`abs(effectiveAction)>=0.95`; no significa que los cuatro motores permanecieran
al maximo esa fraccion del tiempo. Hubo 1,627 intervenciones deterministas de
seguridad para Agent200 y 204 para P, pero cero violaciones de posicion. Los
registros demuestran comandos simulados, no corriente electrica.

Flags funcionales Agent200:

```text
Motor 2=8
otros motores=10 (M3=4, M4=6, M1=0)
```

Por tanto, el gate funcional de ETAPA 6 tampoco se satisface en este conjunto
disenado.

### 6.4 Artefacto canonico y hashes

Ruta:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7b_artifacts\stage7b_final\2026-08-27_01-18-31-833`

Hashes principales:

- `manifest.json`:
  `EA377C42D7B30A3438B091938DD3D861CFD54982673B90B5DD421542DE265483`;
- `stage7b_results.mat`:
  `A5A4100123F6DE5AA44628877903906A33DBB2F1C594718FAA83AE9B24FCC64D`;
- `aggregate_summary.csv`:
  `8B5AC84C7F09D0AB2F968AD981D60532A1367D655BCCA9045F1A5856157CD0DC`;
- `designed_gate.csv`:
  `4CD9F3AC666A41BB5C093AF97F08F0A8CADA9E03849EA22936963F15D074A1A1`;
- `source_decision.csv`:
  `5F35AE0296D06E8D9BDD4D36B8594ECE9FF428978B014A22FDCE337FED087130`.

Los 23 archivos inventariados coincidieron con su SHA-256. Agent200 permanecio
inalterado:

`C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973`.

Agent7250 permanecio inalterado y no fue cargado:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- La causa de los comandos de Agent200 antes de `q_ref` activa no esta
  demostrada. Son hipotesis la dependencia de EMG/estado, sesgo del actor,
  distribucion fuera de entrenamiento o significado del error de posicion.
- La politica tambien observa las 40 features WMoos. Estas no se interpretaron
  como amplitudes fisicas `[0,1]`; la validacion de amplitud uso EMG cruda y la
  calibracion previa a WMoos.
- Cinco minimos en el borde no prueban un retardo de exactamente un segundo.
  Solo indican que el minimo no quedo localizado en el intervalo permitido.
- No se debe ampliar `maxLagSteps` post-hoc: eso podria alinear fases diferentes
  de la trayectoria y ocultar error de extremo.
- Los perfiles son sinteticos. No validan Myo real, rotacion de brazalete,
  recolocacion, canales planos reales ni OOD.
- El controlador P es un comparador mecanico, no una politica optimizada para
  el fixture. Su alto MSE de velocidad requiere diagnostico separado.
- Las intervenciones de seguridad impiden violaciones, pero su numero alto
  muestra que no deben ocultarse al evaluar control.
- No se midio corriente, temperatura o fuerza; solo comandos y posiciones de
  simulacion.
- `matlab_code.zip` sigue siendo ajeno, no rastreado y sin modificar.

## 8. Confirmacion explicita de que no se uso hardware

No se uso hardware, Myo, guante, puertos COM, PWM fisico ni conexiones reales.
Toda la ejecucion uso `simMotors=true`, `connect_glove=false` y datos EMG
pregrabados sinteticos. Se creo `Env` y se invoco el simulador exclusivamente
para evaluar Agent200 congelado y el P.

No hubo entrenamiento RL. `reinforcementLearningInvoked=true` significa que se
ejecuto una politica RL ya congelada; el manifiesto distingue
`reinforcementLearningTrainingInvoked=false` y `agentEvaluationOnly=true`.
Agent7250 no fue cargado.

## 9. Commit de la etapa

- codigo, pruebas, launcher y README:
  `f96336e5350e6ed8c3b0e674652a3de3ac7c6caa`
  (`feat: add designed stage7b temporal excitation`);
- el commit documental se registra al cerrar este informe.

No se hizo push ni se abrio PR: la orden actual autorizo continuar la etapa,
pero no emitio una nueva autorizacion explicita para publicar cambios remotos.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8, compensacion, filtrado o ampliacion post-hoc del lag.

La siguiente propuesta es **ETAPA 7C - diagnostico causal de comandos en reposo
de Agent200**, sujeta a autorizacion explicita:

1. congelar Agent200, el corpus 7B, estado, reward, cuantizacion, simulador y
   seguridad;
2. evaluar offline la salida continua del actor y la salida cuantizada en cada
   una de las ocho ventanas de reposo previo;
3. descomponer, sin entrenar, la sensibilidad a bloques observables mediante
   intervenciones de una sola variable: EMG/features, `q`, `Deltaq`, accion
   anterior, `q_ref` y `v_ref`;
4. usar reemplazos provenientes de estados reales del mismo episodio, no
   combinaciones arbitrarias fuera de soporte;
5. medir por motor sesgo de accion, signo frente al error, PWM, saturacion y
   activacion falsa durante reposo;
6. comparar con accion cero y P solo como controles, manteniendo la misma
   planta;
7. terminar con una atribucion respaldada o clasificar la causa como no
   identificada; no modificar la politica en la misma ablacion.

ETAPA 7C no fue ejecutada. No se autoriza hardware, ETAPA 8 ni DTW reward.
