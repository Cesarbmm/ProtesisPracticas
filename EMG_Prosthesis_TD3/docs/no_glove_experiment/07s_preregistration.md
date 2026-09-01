# ETAPA 7S — preinscripción de soporte prospectivo en reposo declarado

Fecha: 2026-08-31.

ETAPA 7S adquiere evidencia simulada nueva para resolver el fallo de soporte de
7R. No entrena, no modifica la política, referencia, estado, reward, TD3,
cuantización, simulador, gate o seguridad y no usa hardware. El único actor que
controla la adquisición es Agent200 congelado de `intentMarkov60`.

La adquisición es un desafío sintético del criterio actual de reposo declarado.
No representa reposo fisiológico, amplitud humana ni separabilidad clínica.

## 1. Padres y elementos congelados

Padre canónico:

```text
ETAPA 7R = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7r_artifacts\stage7r_final\2026-08-31_21-42-38-792
SHA256(manifest.json) = 5111367127942D80D97BA299F47872019548CFF2126B4D75B33F161C36F90847
SHA256(stage7r_results.mat) = 7F07C0ACB45A339BB9C339E68F9689E3E5EE23103963354ACA568AB9AB2899F1
scientificResult = insufficientMatchedSupport
```

También se validarán los padres 7Q/7P/7N que 7R congeló. Se mantienen:

- `intentMarkov60`, 60 entradas;
- Agent50/100/150/200 de la política `control60`;
- Agent200 como checkpoint primario;
- `trackingIntentActionRateReward`, con los mismos pesos;
- `baselineQuantized`;
- actor y críticos feedforward;
- misma calibración de intención y gate de reposo;
- misma capa `simulationPositionSafety`;
- `simMotors=true`, `connect_glove=false`;
- `normValues.mat` con SHA-256
  `7DDA997F59E1327C8A4EF9CDDE07463506754FB73A52001E983B3A3877B017B2`.

Checkpoints congelados:

| Episodio | SHA-256 |
|---:|---|
| 50 | `D697DA3BB6CE9672330A359DDE3DD43ACEECCB5E2F151EF6E13D3C8C2EC2D013` |
| 100 | `3B54D4C5122D7133E9472EE8ED641418A79E0FA7E57A6501AC1C5E611357AB3F` |
| 150 | `B760B7EE45F62D6B2E12C1B0A3281E119182CAF96653A293E07E9EFE567A7A66` |
| 200 | `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E` |

Agent7250 no se cargará. El estado 62 continuará rechazado provisionalmente.

## 2. Diseño prospectivo de EMG cruda

Se fija antes de simular:

```text
seed de diseño       = 7701
episodios             = 80
ventanas por episodio = 21
pasos simulados       = 20
actividad objetivo    = 0.13
thetaOn               = 0.14
thetaOff              = 0.06
nOn/nOff              = 2/3
```

La normalización física usa la calibración congelada. Para cada canal activo:

```text
m_c = b_c + a_c (s_c - b_c + epsilon)
```

Cada ventana tiene un canal dominante, elegido determinísticamente por episodio
y paso. Su activación pertenece a `[0.84,0.90]`; las activaciones de los otros
seis canales activos se fijan para que:

```text
mean(a_c(activeChannels)) = 0.13 < thetaOn
```

El canal plano permanece plano. Una portadora bipolar y una modulación positiva
determinista producen una señal cruda cuya media absoluta es exactamente `m_c`.
La modulación cambia por episodio, ventana y canal sin cambiar la envolvente.

Este diseño explota de forma deliberada que el gate agrega canales mediante la
media: puede haber actividad alta en un canal y aun declararse reposo. Es un
test de estrés causal del gate común, no una definición de reposo muscular.

Antes de construir `Env`, el dataset debe cumplir:

- todas las muestras finitas y ocho canales en el orden calibrado;
- 80 capturas distintas, almacenadas como una matriz `40 x 2` de celdas;
- 21 ventanas completas de 40 muestras por captura;
- actividad por ventana igual a `0.13` dentro de `1e-10`;
- cero activaciones del gate y `v_ref=0` en replay offline;
- las features WMoos se calculan con la normalización congelada y no se
  interpretan como amplitudes físicas;
- para ventanas con distinto canal dominante, `emgRms>=0.50` usando la escala
  EMG congelada de 7R.

Si este contrato falla, no se simula.

## 3. Adquisición causal

Se ejecutan exactamente 80 episodios con Agent200:

```text
run_training=false
newTraining=false
agentFile=Agent200.mat
referenceSource=emgIntent
observationVariant=intentMarkov60
simMotors=true
connect_glove=false
NumSimulations=80
MaxSteps=20
UseParallel=false
StopOnError=on
```

Se conserva una copia inmutable del dataset y del perfil efectivo. Cada estado,
acción y siguiente encoder procede del `Env` y simulador sin reemplazar bloques.
No se crean estados híbridos ni contrafactuales.

La aceptación de Agent200 de 7N permanece congelada. El corpus 7S combina:

1. los 50 episodios originales de `acceptance` de Agent200;
2. los 80 episodios nuevos de `steadyRest` prospectivo.

Los episodios antiguos `steadyRest` no participan en la decisión 7S.

## 4. Gate de adquisición, evaluado antes de los modelos

El corpus se bloquea por hash antes de cargar Agent50/100/150 o ajustar modelos.
Se mantienen las escalas de contexto y EMG publicadas por 7R; no se recalculan
con los nuevos datos. También se mantienen exactamente:

```text
contextMax <= 0.25
emgRms >= 0.50
foldCount = 5
minimumPairCount = 100
minimumUniqueEpisodes = 20
maximumDonorReuseFraction = 0.10
```

El gate prospectivo exige:

- 80 episodios y 1 600 estados nuevos completos;
- estado 60, referencia EMG-only y seguridad simulada habilitada;
- cero NaN/Inf y cero violaciones de límites de posición;
- cero ventanas `gateActive`, `lowActivityCountdown` o con `v_ref` no nula;
- referencia mantenida desde el encoder inicial;
- soporte `steadyRest/crossEpisode` en al menos tres motores;
- soporte global `withinEpisode` y `crossEpisode` en al menos tres motores;
- cinco folds, al menos 20 episodios query y reutilización donor `<=0.10`.

Si falla cualquier punto, el resultado será `prospectiveSupportFailed`. En ese
caso no se cargarán los otros checkpoints, no se ajustarán modelos y no se
relajará ningún umbral.

## 5. Análisis confirmatorio condicionado al soporte

Solo si el gate anterior pasa:

1. se cargan Agent50/100/150/200 exclusivamente para inferencia offline;
2. se evalúan los cuatro actores sobre las mismas filas completas bloqueadas;
3. Agent200 debe reproducir sus acciones guardadas con error máximo `<=1e-5` y
   PWM idéntico;
4. las filas `acceptance` deben reproducir la evidencia congelada de 7Q;
5. se ejecutan sin cambios los modelos, control permutado y clasificador 7R.

Se mantienen ridge `lambda=1`, cinco folds episódicos, exactitud de signo para
`abs(y)>=1e-3` y las reglas de familia/canal publicadas en 7R.

Clasificaciones permitidas después de pasar soporte:

- `singleFamilySupported:<family>`;
- `multiFamilyEmgAssociation`;
- `distributedEmgAssociation`;
- `emgNotIdentifiedUnderMatching`.

Una asociación identifica sensibilidad de la red a features estandarizadas bajo
el gate actual. No demuestra intención muscular física ni valida el gate para
hardware.

## 6. Pruebas y entregables

Se crearán pruebas deterministas para:

- envolvente física y actividad agregada exactas;
- gate siempre en reposo;
- orden de canales, canal plano y unicidad de capturas;
- separación WMoos con escala 7R;
- perfil de simulación sin entrenamiento ni hardware;
- gate de soporte y fallo cerrado antes de modelos;
- escalas 7R congeladas;
- replay de actor y cuantización;
- invariancia del corpus de aceptación.

Entregables: CSV de diseño, dataset, inventario y hashes de episodios, soporte,
modelos condicionados, MAT, JSON, manifiesto, comando reproducible e informe
`07s_prospective_rest_support.md`.

ETAPA 7S se detiene tras el informe y commits. No autoriza smoke, piloto,
campaña, DTW, Myo, guante ni hardware. No se hará push sin orden explícita.
