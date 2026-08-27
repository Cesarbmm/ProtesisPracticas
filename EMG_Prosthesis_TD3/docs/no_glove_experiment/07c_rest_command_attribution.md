# ETAPA 7C - atribucion offline de comandos durante reposo

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada despues de ETAPA 7B para diagnosticar por que el
checkpoint Agent200 emitia comandos antes de activar la referencia. La etapa
fue estrictamente diagnostica: reutilizo observaciones reales guardadas en 7B,
reprodujo el actor congelado y no modifico politica, estado, reward,
cuantizacion, simulador, seguridad, referencia o controlador convencional.

## 1. Resultado de la etapa: PASS

La ejecucion de ingenieria es **PASS**:

- se validaron los 16 episodios y sus hashes antes y despues del analisis;
- el actor congelado reprodujo `actionLog` con error maximo exactamente cero;
- se analizaron las ocho ventanas de reposo pre-registradas por episodio;
- se verificaron 128 estados y 512 componentes motor-ventana;
- se construyeron controles accion cero, P sobre estado Agent y P emparejado;
- se ejecutaron intervenciones locales de un solo bloque con donors observados
  del mismo episodio;
- se ejecutaron smoke, pruebas deterministas, regresion completa, manifiesto y
  hashes;
- no se creo `Env`, no se invoco simulador/reward, no se entreno y no se uso
  hardware.

El resultado cientifico es:

```text
classification=restCommandAtObservedEmgOnlyStateUnresolved
commandDuringCalibratedRestConfirmed=true
commandAtObservedEmgOnlyStateConfirmed=true
restEmgLocalSensitivityObserved=false
rootCauseIdentified=false
```

Agent200 solicita comandos durante todo el reposo y tambien en ocho estados
observados donde los 20 valores no-EMG son cero. Esto demuestra que error,
movimiento, accion previa y referencia no son condiciones necesarias para que
aparezca el comando inicial. Sin embargo, la evidencia no separa una respuesta
sistematica a las features EMG de reposo del sesgo interno del actor. No se
aplico una correccion conductual.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7C:
  `4d1910cbbd3b6e4a608f2ed4caf598d7eefd8260`;
- commit de codigo, pruebas, launcher y README:
  `e0b3c1487cba5a66db2059942e61baad93dde675`;
- SHA registrado por el artefacto canonico:
  `e0b3c1487cba5a66db2059942e61baad93dde675`.

El manifiesto canonico registra `gitTrackedDirty=false`. `gitDirty=true` se
debe solo al archivo local ajeno y no rastreado `matlab_code.zip`, preservado
sin cambios y excluido de los commits.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/evaluateFrozenActorStates.m`: replay offline del
  actor determinista.
- `matlab_code/src/evaluation/analyzeNoGloveStage7cRestCommands.m`: validacion
  temporal, anchors observados, controles e intervenciones locales.
- `matlab_code/tests/no_glove/testNoGloveStage7cRestAttribution.m`: ocho
  pruebas deterministas y fail-closed.
- `matlab_code/workflows/published/run_no_glove_stage7c_rest_attribution.m`:
  launcher reproducible, smoke, hashes y manifiesto.
- `docs/no_glove_experiment/07c_rest_command_attribution.md`: este informe.

### Modificado

- `matlab_code/workflows/published/README.md`: registro del launcher 7C.

No se modificaron `Env`, `calculateState`, `step`, `intentMarkov60`, la reward,
el decodificador, la referencia, la politica, Agent200, Agent7250,
`baselineQuantized`, `SimController`, `encoder2Flex`, la seguridad o el
controlador P.

## 4. Decisiones tecnicas y justificacion

### 4.1 Evidencia inmutable

La unica fuente temporal fue el artefacto canonico 7B:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7b_artifacts\stage7b_final\2026-08-27_01-18-31-833`

El launcher exige que 7B tenga:

```text
result=PASS
scientificGateResult=designedTemporalPatternUnresolved
causalCompensationGatePassed=false
compensationInterventionExecuted=false
filteredReferenceInterventionExecuted=false
dtwCalculated=false
stage8Authorized=false
agentFrozen=true
runTraining=false
agent7250Loaded=false
hardwareUsed=false
exactPairing=true
positionViolationCount=0
```

Se validaron el manifiesto, `stage7b_results.mat`, el inventario de episodios,
el protocolo y el perfil efectivo. Cada uno de los 16 episodios se volvio a
hashear individualmente.

### 4.2 Contrato temporal observado

Para `intentMarkov60`, cada fila guardada conserva:

```text
s_t = [phi_EMG,t(40), q_t(4), Deltaq_t(4), u_eff,t-1(4),
       q_ref,t(4), v_ref,t(4)]
```

`stateLog(t,:)` es el estado visible antes de `action_t`. Se exigio:

```text
stateLog(t, previousEffectiveAction) = actionSatLog(t-1,:)
stateLog(t, deltaEncoder) = clip(q_t-q_t-1, -1, 1)
stateLog(t, q_ref) = referenceHistory(t,:)
v_ref,t = 0, t=1,...,8
q_ref,t = q_ref,1, t=1,...,8
```

La primera observacion de cada episodio debe cumplir:

```text
q_1-q_ref,1 = 0
Deltaq_1 = 0
u_eff,0 = 0
v_ref,1 = 0
```

Cualquier diferencia hace fallar el analisis antes de evaluar el actor.

### 4.3 Replay exacto del actor

Se cargo Agent200 solo para obtener su actor feedforward congelado:

```text
u_raw,t = actor(s_t)
```

Se comparo cada salida con el `actionLog` de 7B. Despues se aplico la funcion
pura del contrato historico:

```text
u_clip = clip(u_raw, -1, 1)
PWM = nearestLevel(255*abs(u_clip)) * sign(u_clip)
levels = [0,64,96,128,160,192,224,255]
activationThreshold = 0.05
u_eff = PWM/255
```

Tanto la accion continua como `u_eff` y PWM debian reproducir exactamente los
logs. No se construyo el entorno para realizar este replay.

### 4.4 Anchors observados, sin contrafactual artificial

Los 16 estados iniciales son anchors dinamicos con error cero. En ocho
episodios que empiezan en home se cumple ademas:

```text
q=0, Deltaq=0, u_prev=0, q_ref=0, v_ref=0
s=[phi_EMG_rest, zeros(1,20)]
```

Estos estados fueron realmente usados por Agent200 en 7B; no son una
observacion cero inventada. Como los cuatro PWM son no nulos en los ocho
anchors, los bloques mecanicos y de referencia no son necesarios para la
activacion inicial. La salida aun puede proceder de la ruta de features EMG,
de los biases de la red o de su interaccion.

Las 40 features WMoos estandarizadas no se interpretan como amplitudes fisicas
`[0,1]`. La condicion de reposo proviene del protocolo y del decodificador
calibrado sobre EMG cruda de 7B.

### 4.5 Intervenciones locales de un solo bloque

Los bloques auditados fueron:

```text
B1=phi_EMG(40)
B2=q(4)
B3=Deltaq(4)
B4=u_eff,t-1(4)
B5=q_ref(4)
B6=v_ref(4)
```

Para cada receptor `i`, bloque `B` y donor `j` de las ocho ventanas del mismo
episodio, se exigio que el bloque cambiara. Entre esos donors se eligio el de
complemento mas cercano:

```text
d_-B(i,j) = sqrt(mean_k notin B (((s_i,k-s_j,k)/sigma_k)^2))
j* = argmin_j d_-B(i,j)
```

`sigma_k` es la desviacion observada de la caracteristica en los 128 estados.
Las dimensiones invariantes se excluyen de la distancia. El contrafactual
local conserva el receptor y sustituye solo el bloque:

```text
s_i^(B<-j*) = [s_i,-B, s_j*,B]
Delta u_B = actor(s_i^(B<-j*)) - actor(s_i)
```

El donor es un bloque observado del mismo episodio. Ademas se exigio:

```text
d_-B <= 2.0
cada feature del hibrido dentro del rango observado
identifiableFraction >= 75%
localCoverageFraction >= 75%
median(|Delta u_B|) >= 0.05
quantizedCommandChangedFraction >= 25%
```

Solo el cumplimiento conjunto puede clasificar un bloque como
`locallySensitive`. Una fraccion identificable de 50% se marca
`insufficientIdentifiability`, incluso si el efecto local en ese subconjunto es
grande. Estas intervenciones miden sensibilidad local del actor; no prueban una
causa raiz ni una dinamica de planta.

### 4.6 Controles

Se calcularon cuatro fuentes sin simular:

1. Agent200 observado: accion guardada y reproducida.
2. `zeroAction`: control nulo sobre las mismas filas.
3. P sobre estado Agent: accion contrafactual del P usando el estado que
   Agent200 ya habia desplazado.
4. P emparejado: comando observado en la trayectoria propia del P de 7B.

El P sobre estado Agent no representa lo que el P habria hecho desde reposo;
esa evidencia pertenece al P emparejado. La distincion evita atribuir al P la
correccion de un desplazamiento creado previamente por Agent200.

### 4.7 Seguridad y significado del PWM

`actionPwmLog` registra el comando cuantizado solicitado antes de que la
seguridad de posicion limite la trayectoria simulada. Por eso se reportan por
separado los contadores de intervencion. Un comando registrado no demuestra
movimiento, corriente electrica ni PWM fisico aplicado.

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Revision estatica

`checkcode(...,"-id")` sobre analizador, replay, pruebas y launcher:

```text
4/4 archivos limpios
0 incidencias
```

### 5.2 Pruebas especificas

```matlab
runtests("tests/no_glove/testNoGloveStage7cRestAttribution.m")
```

Resultado exacto: 8 totales, 8 PASS, 0 FAIL, 0 incompletas.

Casos cubiertos:

1. replay, anchors y controles;
2. sensibilidad conocida e invariancia de referencia;
3. donors del mismo episodio y dentro de rango;
4. variacion parcial no puede llamarse sensibilidad;
5. mismatch de actor rechazado;
6. referencia activa durante pre-rest rechazada;
7. accion/encoder temporalmente desalineados rechazados;
8. cobertura incompleta del P rechazada.

### 5.3 Suite completa sin guante

```matlab
runtests("tests/no_glove", "IncludeSubfolders", true)
```

Resultado exacto: 80 totales, 80 PASS, 0 FAIL, 0 incompletas.

### 5.4 Launcher canonico

Parametros efectivos:

```text
preRestWindows=8
periodSec=0.2
replayTolerance=1e-12
stateTolerance=1e-12
minimumDonorBlockDistance=1e-12
maximumComplementDistance=2.0
materialRawActionDelta=0.05
minimumMaterialFraction=0.25
minimumLocalCoverage=0.75
minimumIdentifiableFraction=0.75
falseActivationLimit=0.01
saturationThreshold=0.95
```

Resultado impreso:

```text
ETAPA 7C REST ATTRIBUTION PASS
Output: ...\stage7c_final\2026-08-27_01-57-15-165
```

MATLAB: R2023b Update 11. El proceso termino con codigo 0. Una segunda
ejecucion canonica consecutiva produjo hashes identicos en los 12 CSV de
entrada, protocolo, atribucion y decision.

## 6. Metricas y artefactos generados

### 6.1 Replay e invariantes

```text
episodios=16
estados de reposo=128
componentes motor-estado=512
replayMaximumAbsoluteError=0
referenceVelocityPreRestMaxAbs=0
referenceDriftPreRestMaxAbs=0
initialPositionErrorMaxAbs=0
initialDynamicStateMaxAbs=0
```

### 6.2 Activacion durante reposo

| Motor | Componentes activos | `mean(abs(rawAction))` | `mean(abs(PWM))` | Saturacion |
|---:|---:|---:|---:|---:|
| M1 | 128/128 | 0.403041 | 98.750 | 0 |
| M2 | 128/128 | 0.663994 | 160.727 | 0.023438 |
| M3 | 128/128 | 0.351675 | 86.000 | 0 |
| M4 | 128/128 | 0.385746 | 114.000 | 0 |
| total | 512/512 | 0.451114 | 114.869 | 0.005859 |

Todas las 128 ventanas tuvieron al menos un comando; en realidad tuvieron los
cuatro. El limite requerido por la linea era activacion falsa no mayor a 1% de
ventanas. El valor observado fue 100%, por lo que el problema de reposo queda
reproducido de forma determinista.

### 6.3 Anchors EMG-only observados

Los ocho anchors home tuvieron todos los bloques no-EMG en cero. Promedios
firmados:

| Motor | `rawAction` | PWM solicitado | Fraccion negativa |
|---:|---:|---:|---:|
| M1 | -0.496271 | -128 | 1.0 |
| M2 | -0.318496 | -96 | 1.0 |
| M3 | -0.140739 | -64 | 1.0 |
| M4 | -0.720643 | -192 | 1.0 |

Los 32 componentes de esos ocho anchors estuvieron activos. No se necesita
error de posicion, velocidad, accion anterior o referencia activa para obtener
estos comandos.

### 6.4 Sensibilidad local por bloque

| Bloque | Identificabilidad | Mayor mediana `abs(Delta u)` | Mayor cambio PWM | Decision |
|---|---:|---:|---:|---|
| features EMG | 100% | 0.001681 | 3.906% | localmente estable |
| encoder | 50% | 0.120923 | 70.313% | identificabilidad limitada |
| delta encoder | 50% | 0.008013 | 10.938% | identificabilidad limitada |
| accion previa | 100% | 0.020916 | 35.938% | localmente estable |
| `q_ref` | 0% | no estimable | no estimable | invariante en reposo |
| `v_ref` | 0% | no estimable | no estimable | invariante en reposo |

Las features EMG variaron entre ventanas reales de reposo, pero cambiar el
bloque completo produjo efectos muy pequenos. Esto no demuestra que la ruta
EMG sea irrelevante: el rango de reposo de una sola sesion es estrecho y todas
las features conservan un nivel sistematico estandarizado.

Encoder y delta encoder solo variaron en la mitad de estados. La otra mitad
corresponde a episodios home en los que comandos negativos fueron detenidos por
la seguridad. Por el gate de 75%, no se declara sensibilidad confirmada.

### 6.5 Controles

| Control | Fraccion activa | `mean(abs(rawAction))` | `mean(abs(PWM))` |
|---|---:|---:|---:|
| Agent200 observado | 1.000000 | 0.451114 | 114.869 |
| accion cero | 0 | 0 | 0 |
| P sobre estado Agent | 0.296875 | 0.068304 | 19.000 |
| P en trayectoria emparejada | 0 | 0 | 0 |

El P emparejado mantuvo el reposo sin comandos. El P sobre estados de Agent
solo actua despues de que la trayectoria de Agent ya presenta error o
velocidad; no es evidencia de activacion espontanea del P.

### 6.6 Intervenciones de seguridad

Durante las ocho ventanas se registraron 304 intervenciones:

```text
M1=64
M2=64
M3=64
M4=112
componentes con intervencion=0.59375
```

En los ocho episodios home hubo 256 intervenciones, es decir, todos los cuatro
motores en las ocho ventanas. La seguridad impidio que esos comandos negativos
cruzaran el limite inferior. Esto explica por que ausencia de movimiento no
equivale a ausencia de comando.

### 6.7 Artefacto canonico y hashes

Ruta:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7c_artifacts\stage7c_final\2026-08-27_01-57-15-165`

Hashes principales:

- `manifest.json`:
  `0D146018296ADA79A2824E0766C58228C4C2E5628E98719BA7BF0E07534C9B0B`;
- `stage7c_results.mat`:
  `B73B27B6C5D986A89B1E34435A21C5B119144DCFFD4DAC99833D8B74BD57AF5E`;
- `source_decision.csv`:
  `4A26439F9FC85513D41FCD5EBCFD3C4AA098CED84BA3E9F9E2A63D1BF44CF6A6`;
- `block_summary.csv`:
  `F475CB5C9CD1D5EB8DFFC5F818380BBE58CDF517F11B1F9451907C56BD39155E`;
- `control_summary.csv`:
  `8FFF945FEF134899551B68A4A81EB05413C18140B20FA6AEB88524B600D8E869`;
- `local_block_interventions.csv`:
  `AF736DE01F39DEACB2DE9EF9C3F10A531E8362FDD6D45A406D65890A8A0470B2`.

Los 16 artefactos inventariados coincidieron con su SHA-256. Los 16 episodios,
el manifiesto 7B, `stage7b_results.mat` y Agent200 conservaron sus hashes antes
y despues.

Agent200:

`C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973`.

Agent7250:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- La causa raiz sigue sin identificarse. La salida puede proceder de la
  respuesta aprendida a un vector de reposo sistematicamente no nulo, de los
  biases de la red o de su interaccion.
- `locallyStable` solo describe el pequeno vecindario de reposo de esta sesion
  sintetica; no demuestra insensibilidad global a EMG.
- No se uso una observacion completamente cero porque no es un estado EMG real
  del corpus y violaria el contrato de soporte de esta etapa.
- Los hibridos usan bloques reales del mismo episodio y permanecen dentro de
  rangos marginales observados, pero la combinacion completa no necesariamente
  fue visitada por la planta. Por eso se habla de sensibilidad, no causalidad
  fisiologica.
- `q_ref` y `v_ref` fueron invariantes durante reposo. Su efecto local no es
  cero: es no identificable con este protocolo.
- La seguridad bloqueo muchos comandos. Analizar solo movimiento habria
  ocultado el problema de la politica.
- La cuantizacion puede convertir cambios continuos pequenos en el mismo PWM o
  cambios cerca de un umbral en saltos discretos.
- El corpus y la calibracion siguen siendo sinteticos; no hay evidencia Myo ni
  OOD real.
- No se midio corriente, temperatura, fuerza o PWM fisico.
- `matlab_code.zip` permanece ajeno, no rastreado y sin modificar.

## 8. Confirmacion explicita de que no se uso hardware

No se uso hardware, Myo, guante, puertos COM, PWM fisico ni conexiones reales.
ETAPA 7C fue completamente offline sobre archivos 7B.

```text
runTraining=false
agentEvaluationOnly=true
offlineActorReplay=true
envCreated=false
simulatorInvoked=false
rewardInvoked=false
dtwCalculated=false
agent7250Loaded=false
hardwareUsed=false
```

`reinforcementLearningInvoked=true` significa unicamente que se evaluo el actor
de una politica RL congelada. `reinforcementLearningTrainingInvoked=false`.

## 9. Commit de la etapa

- codigo, pruebas, launcher y README:
  `e0b3c1487cba5a66db2059942e61baad93dde675`
  (`feat: attribute stage7c rest commands offline`);
- el commit documental se registra al cerrar este informe.

No se hizo push ni se abrio PR porque la autorizacion actual cubre la etapa,
pero no una nueva publicacion remota.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8, entrenar, introducir un gate conductual o usar un vector
EMG cero arbitrario.

La siguiente propuesta es **ETAPA 7D - soporte de entrenamiento y sesgo del
actor**, sujeta a autorizacion explicita:

1. congelar Agent200 y no modificar sus parametros;
2. auditar si `Agent200.mat` conserva replay buffer o estados de entrenamiento;
3. si existe, extraer unicamente estados reales con `v_ref=0` y referencia en
   hold; si no existe, usar solo episodios de entrenamiento publicados y
   documentar la cobertura faltante;
4. medir distancia de los 128 estados 7B a sus vecinos reales de entrenamiento
   por cada bloque de `intentMarkov60`;
5. comparar acciones del actor en vecinos reales de reposo, sin construir
   hibridos ni simular;
6. auditar por separado la contribucion de biases de la red como propiedad
   matematica del actor; cualquier evaluacion a entrada cero debe etiquetarse
   como probe fuera de soporte, nunca como amplitud EMG fisica;
7. decidir entre `restStateOutOfTrainingSupport`,
   `trainingRestAlsoCommands`, `actorBiasContribution` o
   `causeStillUnresolved`;
8. detenerse antes de proponer reentrenamiento o watchdog conductual.

ETAPA 7D no fue ejecutada. No se autoriza hardware, ETAPA 8 ni DTW reward.
