# ETAPA 7D - soporte de entrenamiento y biases de Agent200

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada para continuar el diagnostico de los comandos que
Agent200 emite durante reposo. Se mantuvieron congelados Agent200, Agent7250,
el estado `intentMarkov60`, la referencia, la reward, la cuantizacion, el
simulador, la seguridad y el controlador convencional. La etapa fue
estrictamente offline: no creo `Env`, no ejecuto simulaciones, no entreno y no
uso hardware.

## 1. Resultado de la etapa: PASS

La ejecucion de ingenieria es **PASS**:

- se audito el contenido del checkpoint Agent200;
- se comprobo que su `ExperienceBuffer` existe, pero fue guardado con longitud
  exactamente cero y por tanto no sirve como fuente de soporte;
- se inventariaron y verificaron por SHA-256 los 200 episodios publicados de
  entrenamiento, sin mezclar aceptacion o steady-rest posteriores;
- se extrajeron 7800 estados reales visitados durante entrenamiento que
  satisfacen `v_ref=0` y hold causal de `q_ref`;
- se compararon los 128 estados de reposo observados en ETAPA 7B contra ese
  corpus mediante distancias por bloque y conjunta;
- se reprodujeron exactamente las acciones guardadas de 7B con Agent200;
- se evaluaron Agent200 y una copia diagnostica con todos sus biases puestos a
  cero, sin modificar el checkpoint;
- pasaron pruebas unitarias, smoke, regresion completa, hashes y una segunda
  ejecucion independiente;
- no se creo ningun estado hibrido y no se cambio la conducta del sistema.

El resultado cientifico principal es:

```text
classification=trainingRestAlsoCommands
restStateOutOfTrainingSupport=true
trainingRestAlsoCommands=true
actorBiasContribution=false
rootCauseIdentified=false
```

Los estados 7B estan fuera del soporte EMG medido del corpus de entrenamiento,
pero el problema no puede atribuirse solamente a ese desplazamiento: Agent200
tambien emite comandos sobre los estados reales de reposo inicial visitados
durante su propio entrenamiento. Por la prioridad pre-registrada, esta segunda
evidencia determina la clasificacion `trainingRestAlsoCommands`.

La ablacion de todos los biases no elimina los comandos. Se descarta la
hipotesis estrecha de que los biases, por si solos, sean suficientes para
explicar la actividad observada. No se identifica una causa raiz unica: esta
etapa no demuestra si el comportamiento procede de la reward, exploracion,
distribucion de datos, optimizacion, arquitectura o una interaccion entre ellas.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7D:
  `93b3a2879c3d86cef93ead7d3afffdd4c1ca5bb3`;
- commit de codigo, pruebas, launcher y README registrado por el artefacto:
  `72c742204b9f2fc912fd8f8b62e2cc644ebf2ad8`;
- el commit documental se registra en la seccion 9 despues de crear este
  informe.

El manifiesto canonico registra `gitTrackedDirty=false`. El estado Git aparece
como dirty solo por `matlab_code.zip`, archivo local ajeno, no rastreado y
preservado sin cambios. No se hizo push ni se abrio PR.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage7dTrainingSupport.m`:
  validacion del corpus, escalado robusto, soporte por bloques, vecinos reales,
  comparacion de acciones, ablacion de biases y clasificacion.
- `matlab_code/src/evaluation/evaluateFrozenActorModelStates.m`: evaluacion
  vectorizada usada solamente como cross-check numerico; las metricas
  cientificas finales usan `getAction` por estado.
- `matlab_code/tests/no_glove/testNoGloveStage7dTrainingSupport.m`: ocho
  pruebas deterministas, incluidas las cuatro clasificaciones posibles y
  validaciones fail-closed.
- `matlab_code/workflows/published/run_no_glove_stage7d_training_support.m`:
  launcher reproducible, hashes, smoke, manifiesto y artefactos.
- `docs/no_glove_experiment/07d_training_support_and_actor_bias.md`: este
  informe.

### Modificado

- `matlab_code/workflows/published/README.md`: registro del launcher 7D.

No se modificaron `Env`, `reset`, `step`, `calculateState`, el decodificador,
la referencia, la reward, `baselineQuantized`, `SimController`,
`encoder2Flex`, la capa de seguridad, Agent200 o Agent7250.

## 4. Decisiones tecnicas y justificacion

### 4.1 Pregunta experimental

ETAPA 7C demostro que Agent200 ordena PWM en las 128 ventanas de reposo y en
ocho anchors observados donde los 20 valores no-EMG son cero. No pudo separar
tres explicaciones:

1. los estados 7B podrian estar fuera de la distribucion observada al entrenar;
2. Agent200 podria ordenar tambien dentro de estados reales de reposo de
   entrenamiento;
3. los biases internos del actor podrian aportar una salida sistematica.

ETAPA 7D midio las tres sin entrenar ni construir estados sinteticos mezclados.

### 4.2 Auditoria del checkpoint y fallback explicito

`Agent200.mat` contiene dos variables de nivel superior:

```text
saved_agent        rl.agent.rlTD3Agent
savedAgentResult   rl.train.rlTrainingResult
```

El agente expone:

```text
ExperienceBuffer class = rl.replay.rlReplayMemory
ExperienceBuffer.Length = 0
ExperienceBuffer.MaxLength = 100000
```

No existe una matriz directa `N x 60` de estados en el checkpoint. En
consecuencia, no se afirmo que el replay buffer conservase experiencia ni se
intento reconstruirla. El fallback registrado es:

```text
supportCorpusSource=publishedTrainingEpisodeLogs
```

Los 200 `episodeNNNNN.mat` se encuentran en el mismo directorio de entrenamiento
que los checkpoints Agent50/100/150/200. Son observaciones realmente visitadas
durante entrenamiento, pero el log no demuestra que cada transicion haya sido
muestreada en un minibatch. Tampoco conserva la multiplicidad de muestreo del
replay buffer. Esa diferencia limita cualquier conclusion sobre la distribucion
efectiva de actualizaciones de gradiente.

No se usaron `seed_11/acceptance` ni `seed_11/steady_rest`, porque se generaron
despues del entrenamiento y no definen soporte de entrenamiento.

### 4.3 Contrato causal de seleccion de estados

Para episodio `e` y paso `t>=2`, un estado de entrenamiento es elegible si:

```text
H_e,t = 1[ ||v_ref,e,t||_inf <= epsilon ]
        * 1[ ||q_ref,e,t - q_ref,e,t-1||_inf <= epsilon ]

epsilon = 1e-12
```

El paso 1 se excluye porque no tiene una referencia previa observada dentro del
episodio. El criterio usa solamente presente y pasado; no hay fuga futura.

En cada uno de los 200 episodios:

```text
pasos totales                         = 61
primer paso con referencia activa     = 13
estados elegibles                     = 39
hold previo a primera activacion      = 11
hold posterior a primera activacion   = 28
error temporal maximo de u_prev       = 0
```

Totales:

```text
estados elegibles                     = 7800
preActivationHold                     = 2200
postActivationHold                    = 5600
```

La clasificacion `trainingRestAlsoCommands` usa solo los 2200 estados previos a
la primera activacion. Los estados posteriores se reportan por separado para no
equiparar automaticamente todo `v_ref=0` con reposo fisiologico.

### 4.4 Estado observado y significado de las features

Se conserva el orden causal de `intentMarkov60`:

```text
s = [phi_EMG(40), q(4), Deltaq(4), u_eff,t-1(4), q_ref(4), v_ref(4)]
```

Las 40 `phi_EMG` son features WMoos estandarizadas. La distancia se calcula en
el espacio numerico observado por el actor; no se interpretan como amplitudes
fisicas, envolventes en `[0,1]` o MVC.

### 4.5 Escalado robusto

Para cada componente `j` del corpus elegible:

```text
c_j = median_i x_i,j
s_j = 1.482602218505602 * median_i |x_i,j - c_j|
```

Si el MAD robusto es menor o igual a `1e-12`, se usa la desviacion estandar
solo si hay variacion real. Si ambos son nulos, la dimension se declara
invariante y se excluye de la distancia. No se fuerza una escala artificial.

De las 60 dimensiones:

- 36/40 features EMG variaron;
- los cuatro encoders, deltas, acciones previas y referencias de posicion
  variaron;
- las cuatro velocidades de referencia fueron invariantes en cero;
- la distancia conjunta uso 52 dimensiones variables.

### 4.6 Distancia por bloque y umbral sin mirar las consultas

Sea `J_B` el conjunto de dimensiones variables del bloque `B`. La distancia
robusta diagonal es:

```text
d_B(x,y) = sqrt( (1/|J_B|) * sum_j in J_B ((x_j-y_j)/s_j)^2 )
```

Para cada estado de entrenamiento `x_i`, el vecino de calibracion debe
pertenecer a otro episodio:

```text
delta_i,B = min_{k: episode(k) != episode(i)} d_B(x_i,x_k)
tau_B     = quantile_0.95(delta_i,B)
```

El umbral de soporte `tau_B` se calcula exclusivamente con entrenamiento. Una
consulta `r` esta soportada cuando:

```text
min_k d_B(r,x_k) <= tau_B + 1e-12
```

El bloque se clasifica soportado si al menos 75% de las 128 consultas pasan.
El vecino de una consulta siempre es una fila real registrada; no se crearon
hibridos ni promedios de estados.

### 4.7 Reproduccion del actor y cuantizacion

Las 128 consultas se evaluaron con `getAction` una por una. El error maximo
contra `actionLog` de 7B fue exactamente cero.

Un primer intento vectorizado se detuvo fail-closed porque el orden numerico en
precision simple produjo diferencia maxima `4.1723251342773438e-07` frente a
`actionLog`. La version final usa `getAction` tambien para los 7800 estados de
entrenamiento y para la copia sin biases. La evaluacion vectorizada queda solo
como auditoria sobre las 128 consultas:

```text
max |getAction - predict batch| = 4.76837158203125e-07
decisiones de cuantizacion distintas = 0
```

La cuantizacion se mantuvo en `baselineQuantized` con el perfil efectivo de 7B.
La actividad significa `abs(effectiveAction)>0`. Saturacion significa la
fraccion de componentes motor-paso con `abs(effectiveAction)>=0.95`; no implica
que los cuatro motores esten simultaneamente al maximo.

### 4.8 Decision pre-registrada

Los indicadores se evaluan en este orden:

1. `trainingRestAlsoCommands` si mas de 1% de ventanas
   `preActivationHold` tiene algun comando;
2. en otro caso, `restStateOutOfTrainingSupport` si el soporte conjunto o EMG
   es menor a 75%;
3. en otro caso, `actorBiasContribution` si quitar biases elimina la actividad
   y produce una variacion material suficiente;
4. de lo contrario, `causeStillUnresolved`.

El primer criterio tiene prioridad porque demuestra que el comportamiento
tambien existe sobre estados realmente visitados al entrenar y evita atribuirlo
unicamente a OOD.

### 4.9 Auditoria matematica de biases

El actor congelado es feedforward:

```text
60 -> FC(64) -> ReLU -> FC(64) -> ReLU -> FC(4) -> tanh
```

Se auditaron 132 parametros de bias:

| Capa | Cantidad | Norma L1 | Norma L2 | Maximo absoluto |
|---|---:|---:|---:|---:|
| `fc1` | 64 | 0.488782434 | 0.076293671 | 0.022294069 |
| `fc2` | 64 | 0.521910723 | 0.098522985 | 0.054873314 |
| `action` | 4 | 0.053871789 | 0.034976010 | 0.032628734 |

Se creo en memoria una copia del actor y se pusieron a cero los tres vectores
de bias. Esto es una ablacion matematica de red, no una politica propuesta ni
una intervencion del sistema. Debido a las ReLU, la diferencia entre ambas
redes mide sensibilidad al conjunto de biases; no es una descomposicion aditiva
o Shapley de causa.

Para consultas 7B:

```text
media |pi(s)-pi_sin_bias(s)|          = 0.026995907
maximo |pi(s)-pi_sin_bias(s)|         = 0.078432858
fraccion con cambio >= 0.05           = 0.125
actividad original                    = 1.000000
actividad sin biases                  = 1.000000
reduccion de actividad                 = 0
```

Por tanto, no pasa los umbrales de cambio material `>=0.25`, reduccion de
actividad `>=0.50` ni actividad final `<=0.01`.

### 4.10 Probe de entrada cero

La entrada `zeros(60,1)` se evaluo solo como diagnostico OOD. No representa
amplitud EMG fisica cero ni una captura valida de reposo, porque las primeras 40
entradas del actor son features estandarizadas.

```text
accion cruda original = [0.0451861024, 0.1008172110,
                         0.0120164948, 0.0084264111]
PWM cuantizado         = [0, 64, 0, 0]
accion sin biases      = [0, 0, 0, 0]
PWM sin biases         = [0, 0, 0, 0]
distancia conjunta al vecino = 136520.663228019
umbral conjunto              = 0.460198438
dentro de soporte            = false
```

Este probe confirma que los biases producen una interseccion no nula en una
entrada matematica OOD, pero no explica los cuatro comandos observados en
reposo real. Tampoco demuestra corriente electrica; solo se evaluaron comandos.

## 5. Comandos/pruebas ejecutados y resultados exactos

### 5.1 Auditoria inicial

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse main
```

Resultado inicial:

```text
branch=experiment/no-glove-intent-control
HEAD=93b3a2879c3d86cef93ead7d3afffdd4c1ca5bb3
main=6b213ba5c624fffb3f1094585c67d9c8ac43b737
untracked=matlab_code.zip
```

Se inspeccionaron `whos -file`, propiedades y metodos de Agent200. Resultado:

```text
agent class=rl.agent.rlTD3Agent
actor class=rl.function.rlContinuousDeterministicActor
ExperienceBuffer.Length=0
ExperienceBuffer.MaxLength=100000
```

### 5.2 Pruebas 7D y checkcode

```matlab
r = runtests('tests/no_glove/testNoGloveStage7dTrainingSupport.m');
```

Resultado final:

```text
8 passed, 0 failed, 0 incomplete
```

`checkcode(...,'-id')` sobre los cuatro archivos MATLAB creados:

```text
analyzeNoGloveStage7dTrainingSupport.m  0 issues
evaluateFrozenActorModelStates.m        0 issues
run_no_glove_stage7d_training_support.m 0 issues
testNoGloveStage7dTrainingSupport.m     0 issues
```

### 5.3 Primer intento fail-closed

La primera ejecucion no produjo resultado cientifico. Se detuvo durante smoke:

```text
Agent200 does not reproduce the ETAPA 7B query actions
max error=4.1723251342773438e-07
```

La causa fue una diferencia numerica entre batch y evaluacion individual. No se
relajo silenciosamente `replayTolerance=1e-12`; se cambio la ruta cientifica a
`getAction` por estado.

### 5.4 Launcher canonico final

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_no_glove_intent_control\EMG_Prosthesis_TD3\matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7d_training_support(struct( ...
  'stage7cRunRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7c_artifacts\stage7c_final\2026-08-27_01-57-15-165', ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7d_artifacts\stage7d_final'));
```

Resultado:

```text
ETAPA 7D TRAINING SUPPORT PASS
tests=8/8
analysisElapsedSec=3.897802
output=C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7d_artifacts\stage7d_final\2026-08-27_03-58-12-630
```

### 5.5 Regresion completa

```matlab
r = runtests('tests/no_glove');
```

Resultado:

```text
88 passed, 0 failed, 0 incomplete
```

Resultado guardado en `full_no_glove_test_results.mat`, SHA-256:

```text
5F00C02D9661399BBDCC5D049BB1634671D62BBF2F773E3E677AB39FD29459F7
```

### 5.6 Reproduccion independiente

Se ejecuto el mismo launcher con otra raiz de salida:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7d_artifacts\stage7d_repro_exact\2026-08-27_04-01-09-802
```

Resultado:

```text
PASS
tests=8/8
CSV cientificos identicos por SHA-256=18/18
```

Los archivos con timestamp, ruta de salida o serializacion MAT no se exigieron
byte-identicos. Las 18 tablas de inventario, soporte, acciones, biases y decision
si lo fueron.

## 6. Metricas y artefactos generados

### 6.1 Soporte por bloque

| Bloque | Dim. variables | Umbral P95 | Mediana consulta | P95 consulta | Soporte | Decision |
|---|---:|---:|---:|---:|---:|---|
| EMG | 36/40 | 0.003682848 | 3.145768660 | 4.884455973 | 0% | fuera |
| encoder | 4/4 | 0.009041265 | 0 | 0.310900538 | 93.75% | soportado |
| delta encoder | 4/4 | 0.052978843 | 0 | 0.218262905 | 87.50% | soportado |
| accion previa | 4/4 | 0.113003518 | 0 | 0.231762968 | 87.50% | soportado |
| `q_ref` | 4/4 | 2.63418e-9 | 0 | 0 | 100% | soportado |
| `v_ref` | 0/4 | no estimable | no estimable | no estimable | no estimable | invariante |
| conjunto | 52/60 | 0.460198438 | 2.751550993 | 4.077437837 | 14.84375% | fuera |

En valores enteros, 19/128 consultas pasan soporte conjunto y 0/128 pasan
soporte EMG. Esto demuestra desplazamiento en el espacio de features, no una
distancia fisica de amplitud.

### 6.2 Actividad agregada del actor

| Fuente de estado | Estados | Actividad componentes | Ventanas con algun comando | PWM abs. medio | Saturacion |
|---|---:|---:|---:|---:|---:|
| consultas 7B | 128 | 1.000000 | 1.000000 | 114.869141 | 0.005859 |
| vecino real de entrenamiento | 128 | 0.916016 | 1.000000 | 113.708984 | 0.103516 |
| todos los holds de entrenamiento | 7800 | 0.976987 | 1.000000 | 131.532051 | 0.131538 |
| reposo previo de entrenamiento | 2200 | 0.983182 | 1.000000 | 134.874205 | 0.118523 |
| holds posteriores | 5600 | 0.974554 | 1.000000 | 130.219063 | 0.136652 |
| consultas 7B sin biases | 128 | 1.000000 | 1.000000 | 121.125000 | 0 |

La accion en los estados de entrenamiento es la salida del Agent200 final sobre
estados guardados. No es el `actionLog` historico, que fue producido por
politicas en evolucion y exploracion durante el entrenamiento.

### 6.3 Reposo previo de entrenamiento por motor

| Motor | Actividad | Accion cruda abs. media | PWM abs. medio | Saturacion |
|---|---:|---:|---:|---:|
| M1 | 1.000000 | 0.494305017 | 125.760000 | 0 |
| M2 | 1.000000 | 0.698284050 | 181.853182 | 0.474091 |
| M3 | 0.994545 | 0.471593056 | 120.974545 | 0 |
| M4 | 0.938182 | 0.434298890 | 110.909091 | 0 |

La saturacion de M2 significa que 47.4091% de sus componentes-paso cumplen
`abs(effectiveAction)>=0.95`; no demuestra corriente medida ni que todos los
motores esten al maximo simultaneamente.

### 6.4 Integridad

Entradas preservadas:

```text
Stage7C manifest SHA-256 = 0D146018296ADA79A2824E0766C58228C4C2E5628E98719BA7BF0E07534C9B0B
Stage7C results SHA-256  = B73B27B6C5D986A89B1E34435A21C5B119144DCFFD4DAC99833D8B74BD57AF5E
Agent200 SHA-256         = C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973
Agent7250 SHA-256        = 0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
episodios consulta       = 16/16 hashes preservados
episodios entrenamiento  = 200/200 hashes preservados
```

Artefacto canonico:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7d_artifacts\stage7d_final\2026-08-27_03-58-12-630
manifest.json SHA-256       = AE782015540903E393A5F2D70E607A739CA3BBBE60634CF97E9EF6CFE00E5957
stage7d_results.mat SHA-256 = B261E7504A74C0A9ECEE64D5A195DCD530207EAEE044337FC87302AAE02C6D92
artefactos primarios        = 22/22 con hash
```

Tablas principales:

- `training_episode_input_hashes.csv` y `query_episode_input_hashes.csv`;
- `checkpoint_audit.csv` y `checkpoint_contents.csv`;
- `actor_evaluation_route_audit.csv`;
- `training_episode_audit.csv`;
- `feature_scales.csv` y `block_support.csv`;
- `nearest_training_state_by_block.csv`;
- `joint_nearest_training_state.csv`;
- `nearest_state_action_comparison.csv`;
- `action_summary.csv` y `motor_action_summary.csv`;
- `bias_parameter_summary.csv`, `bias_effect_summary.csv` y
  `zero_input_ood_probe.csv`;
- `source_decision.csv`, `stage7d_results.mat`, `manifest.json` y
  `reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

1. Solo se estudio Agent200, seed 11 y un corpus sintetico de una sesion. No se
   generaliza a otras semillas, usuarios o Myo real.
2. El checkpoint no conserva replay. Los episodios describen estados visitados,
   no frecuencia de muestreo ni minibatches efectivos.
3. `trainingRestAlsoCommands` demuestra comportamiento dentro del corpus, pero
   no prueba que ese comportamiento haya sido causado por ejemplos de reposo.
4. Los estados 7B tienen 0% de soporte EMG con el criterio medido. Esto puede
   amplificar comandos, aunque no sea explicacion suficiente.
5. El umbral P95 entre episodios es estricto porque el corpus sintetico repite
   trayectorias. Se reportan distancias y fracciones completas para no ocultar
   esa geometria discreta.
6. Cuatro features EMG y las cuatro `v_ref` fueron invariantes; su efecto no es
   identificable mediante esta distancia.
7. Poner todos los biases a cero cambia la red completa. La ablacion descarta
   suficiencia de los biases bajo los umbrales, pero no separa interacciones
   bias-peso-ReLU.
8. El probe cero esta radicalmente fuera de soporte y no representa EMG fisica.
9. No se midio corriente ni temperatura. Los datos contienen comandos PWM, no
   corriente electrica.
10. No se evaluo una correccion conductual, watchdog, nueva reward o nuevo
    entrenamiento. El gate de ETAPA 6 sigue fallido.
11. No se reabre el gate DTW: ETAPA 7 demostro beneficio temporal insuficiente y
    ETAPA 7D no calcula DTW.
12. `rootCauseIdentified=false`: cualquier atribucion unica a MSE, reward,
    biases o OOD continua siendo hipotesis.

## 8. Confirmacion explicita de que no se uso hardware

No se uso hardware. No se abrieron puertos COM, no se conecto Myo o guante, no
se genero PWM fisico y no se movieron motores reales. Tampoco se creo `Env` ni
se invoco `SimController`. La etapa fue evaluacion matematica offline de logs y
del actor congelado. La linea conserva `simMotors=true` en sus perfiles; en 7D
ni siquiera se ejecuto el simulador.

## 9. Commit de la etapa

Commit de implementacion registrado por el artefacto canonico:

```text
72c742204b9f2fc912fd8f8b62e2cc644ebf2ad8
Add Stage 7D training support audit
```

El commit documental que incorpora este informe se crea al cierre y debe
consultarse con:

```powershell
git log -1 --oneline
```

No se hizo push ni se abrio PR. `matlab_code.zip` no fue incluido.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No ejecutar ETAPA 8: el gate DTW continua no aprobado. Tampoco iniciar piloto
2k, campana 12k, hardware o un watchdog conductual sin una nueva autorizacion.

La propuesta es **ETAPA 7E - evolucion offline del comando de reposo por
checkpoint y auditoria de la senal de aprendizaje**, sujeta a autorizacion
explicita:

1. congelar y hashear Agent50, Agent100, Agent150 y Agent200;
2. evaluar los cuatro checkpoints sobre exactamente los mismos 2200 estados
   reales `preActivationHold`, con `getAction` y `baselineQuantized`;
3. medir por episodio y motor cuando aparece, crece o disminuye la actividad de
   reposo, sin seleccionar retrospectivamente un checkpoint ganador;
4. separar salida determinista del actor de los `actionLog` historicos con
   exploracion;
5. auditar offline los terminos de reward registrados en esos pasos, sin usar
   contrafactuales dinamicamente inconsistentes ni afirmar causalidad;
6. decidir entre `presentFromEarlyCheckpoint`,
   `emergesDuringTraining`, `attenuatesButPersists` o
   `checkpointEvolutionUnresolved`;
7. detenerse antes de reentrenar, cambiar reward, introducir watchdog o ejecutar
   simulador/hardware.

Esta etapa propuesta determinaria si la actividad ya existe temprano o emerge
con la optimizacion. No se ejecuta automaticamente.
