# ETAPA 7T — preinscripción de consecuencias del estrés del gate

Fecha: 2026-08-31.

ETAPA 7T es una auditoría offline de la adquisición causal congelada por ETAPA
7S. Su objetivo es separar tres fenómenos que 7S sólo describió de forma
agregada:

1. la respuesta directa del actor a la EMG sintética en el primer estado, cuando
   el contexto mecánico es home y la demanda de control es cero;
2. las consecuencias cerradas posteriores, que ya incluyen movimiento previo,
   acción efectiva anterior y capa de seguridad;
3. el motivo por el cual el matching causal deja de encontrar pares después del
   primer paso.

La etapa no pretende validar reposo fisiológico ni demostrar que el gate sea la
causa única de los comandos. La evidencia 7S es un estrés sintético conocido del
agregador común por media.

## 1. Evidencia congelada

Se usará exclusivamente la corrida canónica:

```text
ETAPA 7S = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7s_artifacts\
           stage7s_final\2026-08-31_22-58-01-555
SHA256(manifest.json) = 6E8A9FE1244C885A8AE3F149AE946D5D1D662B541C554F675E308F540F7FB5CD
SHA256(stage7s_results.mat) = FEC0054E4BB364BBC3DF64CC1FEAF11C52C6A69DF3C2A32C82AD2E50390A8AB0
SHA256(acquisition_lock.mat) = 823A72918E6552038AC151E647E5D61E590D0F1E16EB45B93E51D15668FC33DD
SHA256(dataset) = 590791ACD221ABFC3BD5B5C7586E3716E54EEDCE0CDD67E358E005984835F956
```

También permanecen congelados:

- Agent200, SHA-256
  `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E`;
- `normValues.mat`, SHA-256
  `7DDA997F59E1327C8A4EF9CDDE07463506754FB73A52001E983B3A3877B017B2`;
- escalas EMG y contexto publicadas por 7R;
- `intentMarkov60`, `trackingIntentActionRateReward`, `baselineQuantized`,
  simulador y `simulationPositionSafety`;
- los 80 episodios, 1 600 estados, acciones crudas, acciones efectivas, PWM,
  encoders y diagnósticos de seguridad ya guardados.

No se cargará ningún actor. Las acciones se leerán de los logs bloqueados. No se
usará Agent7250.

## 2. Condición de conocimiento previo

La auditoría no es ciega: 7S ya publicó una fracción global de PWM no cero de
`0.98125`, saturación por componente de `0.2090625` y 4 072 intervenciones de
seguridad. Por ello 7T no tratará esas métricas agregadas como descubrimientos
confirmatorios. La nueva información será su estratificación causal por paso,
canal, lado lógico y motor, junto con la descomposición del fallo de matching.

Las reglas que siguen se fijan antes de ejecutar esa estratificación.

## 3. Cohortes y alineación temporal

La cohorte de consecuencias contiene las 1 600 filas `steadyRest`. Para cada
fila y motor se conservarán:

```text
episode, step, side, dominantChannel, dominantActivation,
q_t, Deltaq_t, u_eff,t-1, q_ref,t, v_ref,t,
u_raw,t, u_eff,t, PWM_t, saturation_t, safetyIntervention_t.
```

Los estratos temporales serán:

- `firstStep`: `step=1`;
- `postFirst`: `step=2..20`;
- cada paso individual `1..20` como análisis secundario.

La acción de `step=t` procede de `stateLog(t,:)`. Su EMG causal es:

- para `t=1`, la primera ventana cruda del fixture consumida durante reset;
- para `t>=2`, `emgLog{t-1}`, que generó `stateLog(t,:)` después de la
  transición anterior.

Se exigirá igualdad muestra a muestra con la ventana `t` del fixture. Además se
recalcularán las 40 features con la función/norm guardada en `00_configs.mat` y
se exigirá error máximo `<=1e-12` frente a `stateLog(t,1:40)`. El último
`emgLog{20}` genera un estado no accionado y no entra en la cohorte.

`side` sólo identifica la columna de la celda pregrabada; no se interpretará
como lateralidad fisiológica. `homeAtDecision` se define por motor como
`abs(q_t)<=1e-4`. Se verificará por separado que los 80 estados `firstStep`
comiencen en home, con `Deltaq=0`, `u_eff,t-1=0`, `q_ref=q` y `v_ref=0`.

## 4. Métricas de consecuencias

Para cada motor y para los grupos `(phase, dominantChannel, side)` se medirán:

- media y percentiles 50/95 de acción cruda y de su magnitud;
- media de `abs(u_eff)` y `abs(PWM)`;
- fracción `PWM!=0`;
- fracción `abs(PWM)==64` y mínimo PWM no nulo;
- fracción de saturación `abs(u_eff)>=0.95`;
- fracción y suma de intervenciones de seguridad;
- fracción de comandos positivos, negativos y cero;
- fracción `homeAtDecision` y fracción de demanda de control cero.

La discontinuidad `0 -> PWM 64` se cuantifica, no se corrige. Una intervención
de seguridad es un contador del simulador; no se equipara a corriente o daño
físico.

### 4.1 Respuesta directa

`firstStep` será el análisis causal primario porque el estado parte de home, sin
acción anterior y con demanda de control cero. Un PWM no nulo en esta cohorte es
un comando simulado no solicitado por la referencia. Esto no demuestra que la
EMG sea fisiológica ni que el mismo efecto ocurra con Myo.

### 4.2 Trayectoria posterior

`postFirst` será descriptivo: la acción puede responder simultáneamente a EMG,
error de posición, velocidad y acción anterior. Se reportará como consecuencia
cerrada, no como sensibilidad EMG aislada.

## 5. Distribución EMG

Para no confundir gate con OOD, se comparará cada fila prospectiva contra las
filas `acceptance` congeladas usando las 40 features y la escala EMG congelada:

```text
d_NN(x) = min_j sqrt(mean(((x_EMG-a_j,EMG)./sigma_EMG).^2)).
```

Se reportarán mediana, P95, máximo y fracciones con `d_NN>1` y `d_NN>3`, por
canal dominante y fase. Estos umbrales son diagnósticos de desplazamiento
relativo a `acceptance`; no convierten las features WMoos estandarizadas en
amplitudes físicas y no establecen OOD humano.

## 6. Auditoría de divergencia contextual

Se reproducirán exactamente los folds, escalas y umbrales de 7S:

```text
contextMaximum <= 0.25
emgRms >= 0.50
foldCount = 5
```

Para cada componente motor-query `steadyRest` con demanda de control cero, los
donors candidatos serán estados observados completos que tengan:

- la misma fuente, fold y `gateContext`;
- episodio diferente;
- `emgRms>=0.50`.

Entre ellos se seleccionará el de menor `contextMaximum`. El contexto se divide
sin cambiar el estado:

```text
q                    = dimensiones 41:44
Deltaq               = dimensiones 45:48
previousEffective    = dimensiones 49:52
q_ref                = dimensiones 53:56
v_ref                = dimensiones 57:60
```

Para cada bloque se guardarán máximo y RMS normalizados. Un bloque es
`exceeding` cuando su máximo supera `0.25`; el bloque dominante es el de mayor
máximo.

Como diagnóstico de distancia, se recalculará el mínimo posible omitiendo un
bloque cada vez:

```text
d_min,-b = min_donor max(abs(Delta context en los otros bloques)).
```

`restoredWithoutBlock` será verdadero si el matching completo falla pero
`d_min,-b<=0.25`. Esta operación no crea un estado para el actor, no evalúa una
acción contrafactual y no se usa para reclamar comportamiento de una política
híbrida.

Se reportarán por `firstStep`, `postFirst`, paso y motor:

- queries y queries con candidato EMG;
- match completo y tasa de match;
- mediana/P95 del mínimo `contextMaximum`;
- tasa de exceso por bloque;
- tasa de bloque dominante;
- tasa de restauración al omitir cada bloque.

## 7. Reglas de clasificación

Primero debe pasar el gate operativo: hashes, 1 600 filas, alineación temporal,
finitud, estado 60, 80 episodios, referencia congelada, cero uso de actor/
entorno/simulador/hardware y ninguna modificación de componentes.

Después se clasifica la consecuencia del estrés:

- `broadSyntheticGateStressConsequence`: en `firstStep`, al menos seis de los
  siete canales dominantes tienen `PWM!=0` en al menos 50% de sus componentes,
  al menos tres motores tienen `PWM!=0` en al menos 50% de sus filas y existe
  alguna intervención de seguridad;
- `channelSpecificSyntheticGateStressConsequence`: no pasa el criterio amplio,
  pero al menos un canal y un motor pasan 50%;
- `limitedSyntheticGateStressConsequence`: no se cumple lo anterior;
- `auditInvalid`: falla un invariante operativo.

Si la consecuencia es amplia, se recomendará preinscribir una ablación futura
de un solo factor sobre agregación/watchdog del gate, manteniendo todo lo demás
congelado. Si es específica, se recomendará primero revisar calibración/orden
del canal afectado. Si es limitada, se cerrará esta vía sintética y se remitirá
a shadow mode humano en una etapa autorizada.

Una distancia NN elevada se reportará junto a la clasificación, pero no podrá
por sí sola convertir el resultado en evidencia fisiológica ni descartar el
riesgo: el diseño sintético y el gate se evaluaron conjuntamente.

## 8. Pruebas y entregables

Se implementarán pruebas deterministas para:

- hashes y contrato de 7S;
- alineación raw -> feature -> estado;
- join exacto episodio/paso -> ventana/canal;
- estratificación `firstStep/postFirst`;
- métricas de comandos, cuantización, saturación y seguridad;
- nearest-neighbor EMG;
- descomposición de cinco bloques y restauración por omisión;
- clasificación amplia/específica/limitada y fallo cerrado;
- prohibición de actor, Env, simulador, entrenamiento y hardware.

Se generarán CSV/MAT/JSON, inventario de entradas, hashes, comando reproducible,
reporte offline e informe `07t_gate_stress_consequence_audit.md`.

ETAPA 7T se detendrá tras el informe y commits. No autoriza cambiar el gate,
completar retrospectivamente los 100 pares, entrenar, ejecutar smoke/piloto/
campaña, DTW, Myo, guante o hardware. No se hará push sin orden explícita.

## 9. Enmienda de contrato antes de la corrida canónica

Durante una ejecución exploratoria de integración posterior al commit de esta
preinscripción se comprobó que la frase «los 80 estados `firstStep` comienzan en
home» era demasiado restrictiva. `Env.reset` coloca en el límite inferior los
episodios que parten relajados, pero cierra la mano antes de los episodios de
apertura; esos episodios comienzan en el límite superior. Este comportamiento
ya estaba congelado en 7S y no fue introducido por 7T.

Antes de generar el artefacto canónico se reemplaza únicamente ese invariante
operativo por el contrato mecánicamente correcto:

```text
q_t pertenece al límite inferior o superior calibrado;
q_ref,t = q_t;
Deltaq_t = 0;
u_eff,t-1 = 0;
v_ref,t = 0;
zeroControlDemand = true.
```

`homeAtDecision` conserva su definición original `abs(q_t-q_min)<=1e-4` y se
reportará por separado de `upperEndpointAtDecision`. Se añade una
estratificación explícita `lowerEndpoint | upperEndpoint | interior`.

Esta enmienda no cambia la cohorte, los umbrales de PWM, el número de canales o
motores exigido, la regla de seguridad, el matching, las escalas ni las
clasificaciones científicas. Se registra después de observar la geometría
inicial, por lo que la proporción lower/upper será descriptiva y no se tratará
como resultado preinscrito ciego.

## 10. Enmienda 2 — el límite superior calibrado tampoco es el alcanzable (2026-09-02)

La corrida canónica ejecutada tras la Enmienda 1 falló su propio gate
operativo: `firstStepMechanicalInvariant=false`. La causa NO fue causal (los
80 estados `firstStep` cumplen exactamente `q_ref=q`, `Deltaq=0`,
`u_eff,t-1=0`, `v_ref=0`, `zeroControlDemand=true`), sino geométrica. Los 40
episodios `firstStep` de tipo Opening (`side=2`) no llegan al límite superior
calibrado `positionMax=1`; se estabilizan, de forma exactamente reproducible
(desviación estándar entre episodios `~2e-16`, es decir ruido de punto
flotante) en:

```text
q_openingPlateau = [0.421761006289, 0.579579710145, 0.883490196078, 0.69787037037]
```

Auditoría de causa raíz (código, no dato): `prosthesis_simulator.m`
(`predict_1dim`) no integra una física de posición; reproduce una curva
empírica ajustada (`fit_C2.mat` / `pattern_curve.mat`) e indexa esa curva con
`idx = max(1, min(idx, ws_len))`. Una vez agotada la longitud de la curva
grabada, la posición no puede avanzar más aunque `episodeTic.toc(10000)`
mantenga PWM=255 indefinidamente: es un punto fijo genuino de ESTE simulador,
no una foto de una trayectoria en curso. Además, `sat(pos, min_l, max_l)`
dentro de la misma función usa límites `min_l`/`max_l` propios de la curva
grabada (por motor), distintos de la convención idealizada
`positionMin=0/positionMax=1` usada para normalización y para el clip de
seguridad. `limitSimulationPosition` nunca interviene aquí porque la
trayectoria jamás excede `positionMax·encoderScale`; simplemente no llega.

Se evaluaron cuatro opciones:

- **(A) tratar el valor observado como el endpoint alcanzable real** — sin
  más, es una asunción no verificada por reproducibilidad;
- **(B) recalibrar `positionMax`/`simulationPositionSafety`/`encoderScale`
  globalmente** — se descarta: tocaría seguridad, reward y normalización de
  TODAS las etapas 00-7S ya congeladas, sin necesidad, porque `positionMax`
  nunca se excede en ningún otro punto del pipeline (el clip es inerte, no
  incorrecto);
- **(C) redefinir el invariante de 7T para que dependa de equilibrio
  mecánico/referencia nula, no de proximidad literal a 0 o 1** — elegida;
- (D) ninguna otra alternativa ofrece mejor trazabilidad.

Se adopta **(C) con anclaje empírico**: el límite superior usado por el
invariante y por la estratificación `lowerEndpoint|upperEndpoint|interior` ya
no es `positionMax` idealizado. Se deriva directamente del propio corpus
`firstStep` congelado (`deriveNoGloveStage7tReachableEndpoints.m`): las filas
`firstStep` no coincidentes con `positionMin` deben coincidir entre sí
(tolerancia `1e-4`, la misma de `homeTolerance`); si coinciden, ese valor
certificado es el `qUpper` reproducible de este simulador. Si NO coincidieran,
`upperEquilibriumConsistent=false` y el gate falla cerrado
(`auditInvalid`) — no se promedia sobre una anomalía real.

Esta enmienda:

- no modifica ningún dato de 7S (frozen), ni `Env.reset`, ni
  `prosthesis_simulator`, ni `positionMin/positionMax` globales, ni
  seguridad, ni reward, ni cuantización, ni el estado, ni el gate de
  intención;
- no cambia la cohorte, los umbrales de PWM, el número de canales/motores
  exigido, el matching ni las reglas de clasificación de la Sección 7;
- sí cambia, exclusivamente dentro del script de auditoría offline de 7T,
  qué valor cuenta como "límite superior" para `homeAtDecision`/
  `upperEndpointAtDecision`/`initialPose` y para el invariante `firstStep`;
- se registra ANTES de reintentar la corrida canónica, y el resultado de esa
  corrida (PASS/INVALID y, si aplica, la clasificación) se documentará en
  `07t_gate_stress_consequence_audit.md` sin alterar retroactivamente este
  texto.
