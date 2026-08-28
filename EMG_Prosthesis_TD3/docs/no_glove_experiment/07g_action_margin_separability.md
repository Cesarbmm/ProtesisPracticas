# ETAPA 7G - separabilidad offline del margen de acción

Fecha de cierre: 2026-08-27.

Esta etapa fue autorizada para evaluar, sin cambiar el comportamiento del
entorno, una hipótesis derivada de ETAPA 7F: si los comandos de la política en
reposo son acciones apenas por encima del umbral de activación de
`baselineQuantized`, un umbral global más alto podría suprimirlos conservando
los comandos de movimiento. La hipótesis, los estratos y los gates se fijaron
antes de inspeccionar las distribuciones.

El análisis reutilizó exclusivamente los logs congelados del control
`w_u=0.01` y del candidato `w_u=0.05` de ETAPA 7F. No entrenó, no creó un
`Env`, no cargó un agente, no invocó simulador ni reward, no calculó DTW y no
aplicó ningún umbral al sistema.

## 1. Resultado de la etapa: PASS

La ejecución de ETAPA 7G es **PASS** y su conclusión científica es:

```text
scientificResult=restMovementNotSeparableBySingleThreshold
candidateFeasibleThresholdExists=false
rootCauseIdentified=false
behavioralInterventionExecuted=false
```

La reproducción exacta de `baselineQuantized` confirmó que el PWM de reposo
procede de acciones crudas grandes, no de valores marginales alrededor del
umbral actual `0.05`. En el candidato, eliminar comandos en al menos 99% de
las ventanas de reposo exigiría elevar el umbral a
`0.79200017452339988`. Ese contrafactual perdería `80.9210526%` de los
componentes de movimiento que actualmente generan comando y `80.9523810%`
de los comandos de Motor 2. Ambos exceden el máximo pre-registrado de 5%.

Por tanto, un único umbral global no separa reposo de movimiento en este
corpus. Esto rechaza la intervención estrecha, no identifica la causa raíz de
las acciones de reposo y no demuestra que toda forma de compuerta sea inútil.
No se aplicó el umbral contrafactual y no se autorizó un piloto.

## 2. Rama y SHA base/actual

- rama: `experiment/no-glove-intent-control`;
- SHA base de `main`:
  `6b213ba5c624fffb3f1094585c67d9c8ac43b737`;
- SHA anterior a ETAPA 7G:
  `0c356b73d6840aa2726df7f027b4beea8cc87bee`;
- commit de implementación y resultados de ETAPA 7G:
  `1a2095116927af4fa90d5cdb51fac1f7a2192513`;
- el commit documental de cierre se registra en el informe entregado al
  finalizar la etapa.

El manifiesto canónico registra `gitTrackedDirty=false`. El único elemento
local no rastreado es `matlab_code.zip`, preservado sin cambios. No se hizo
push ni se abrió PR.

Agent7250 permanece en:

```text
matlab_code/checkpoints/canonical/Agent7250_valid_baseline/
Agent7250_valid_baseline.mat
SHA-256=0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

El checkpoint no fue cargado ni modificado.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/loadNoGloveStage7gActionCorpus.m`: carga los
  logs 7F, valida el contrato `emgIntent`/`intentMarkov60` y asigna estratos
  causales por componente.
- `matlab_code/src/evaluation/analyzeNoGloveStage7gActionMargins.m`:
  reproduce la cuantización, resume distribuciones, construye la curva exacta
  de umbrales y aplica el gate pre-registrado.
- `matlab_code/tests/no_glove/testNoGloveStage7gActionMargins.m`: ocho pruebas
  deterministas de contrato, cuantización, clasificación y fallo cerrado.
- `matlab_code/workflows/published/run_no_glove_stage7g_action_margin_analysis.m`:
  launcher offline, auditorías, hashes, exportación y manifiesto reproducible.
- `docs/no_glove_experiment/07g_action_margin_separability.md`: este informe.

### Modificados

- `matlab_code/workflows/published/README.md`: documenta el launcher 7G y su
  carácter estrictamente offline.

No se modificaron `configurables.m`, `Env`, el decodificador, `q_ref`, los
estados, la reward, `baselineQuantized`, el simulador, `encoder2Flex`, la capa
de seguridad, los agentes ni los resultados de ETAPA 7F.

## 4. Decisiones técnicas y justificación

### 4.1 Pregunta causal estrecha

La interfaz vigente activa un componente cuando:

```text
|u_raw,t,m| >= theta
```

y después aproxima su magnitud al nivel PWM permitido más próximo. ETAPA 7G
solo recalculó qué componentes habrían quedado activos para valores
contrafactuales de `theta`. El signo, los niveles PWM, la política y toda la
dinámica permanecieron congelados.

La hipótesis era separabilidad por magnitud:

```text
existe theta tal que
  P(algún comando en ventana de reposo | theta) <= 0.01
  pérdida de comandos de movimiento             <= 0.05
  pérdida de comandos de Motor 2                 <= 0.05
```

La palabra “pérdida” describe una comparación offline de comandos, no pérdida
de tracking ni de funcionalidad dinámica.

### 4.2 Corpus congelado y alineación

Por cada variante se cargaron:

```text
aceptación:  50 episodios x 61 pasos
reposo:      24 episodios x 15 pasos
total:       74 episodios y 3410 ventanas
```

El corpus conjunto contiene:

```text
episodios fuente  = 148
ventanas          = 6820
componentes       = 27280
componentes/variante = 13640
```

Cada fila conserva `variant`, fuente, episodio, paso, motor, índice de ventana,
fase, `u_raw`, acción efectiva, PWM y `v_ref`. Se exigieron cuatro motores
ordenados por ventana, arreglos finitos, dimensión de estado 60 y longitudes
temporales coincidentes.

Las referencias del control y candidato se compararon componente a componente:

```text
maximumReferenceVelocityDifference=0
referencesExactlyEqual=true
```

Los 148 MAT de entrada se inventariaron por SHA-256 antes y después. También se
hashearon manifiestos, perfiles y checkpoints 7F. No cambió ningún archivo.

### 4.3 Estratos causales pre-registrados

Se usó `|v_ref,t,m| >= 0.005` para definir actividad mecánica por motor:

- `steadyRest`: episodios dedicados con `v_ref=0` y `q_ref` constante;
- `preActivation`: pasos anteriores a la primera actividad global de
  referencia del episodio;
- `movement`: el motor tiene referencia de velocidad activa en ese paso;
- `postActivationHold`: el motor ya estuvo activo y ahora su `v_ref` está
  inactiva;
- `inactiveOther`: inactividad restante, conservada si aparece.

La clasificación usa solo información presente o pasada. No etiqueta como
reposo fisiológico una ventana solo porque `v_ref=0`: `steadyRest` es el
estrato de gate, mientras que `preActivation` y `postActivationHold` se
reportan separadamente.

### 4.4 Reproducción de `baselineQuantized`

Para cada ventana se volvió a ejecutar `quantizeBaselineAction` sobre el
`u_raw` registrado con el perfil efectivo de 7F:

```text
maxPwm             = 255
theta actual       = 0.05
niveles permitidos = [0 64 96 128 160 192 224 255]
```

Resultado:

```text
ventanas reproducidas                    = 6820
componentes reproducidos                 = 27280
error máximo de acción efectiva          = 0
error máximo de PWM                      = 0
exactamente reproducido                  = true
```

Esto valida la semántica del contrafactual sobre los logs. No equivale a
simular cómo cambiarían los estados futuros si el umbral se aplicara.

### 4.5 Curva exacta, sin aproximación de rejilla

La curva usa como candidatos:

```text
{0, 0.05, 1} U {|u_raw| observados} U {valor inmediatamente superior}
```

Así se incluyen todos los puntos donde cambia la decisión discreta
`|u_raw| >= theta`, sin depender de una rejilla arbitraria.

Para un umbral `theta`:

```text
restComponentActiveFraction(theta)
  = media(1[|u_raw| >= theta]) en componentes steadyRest

restWindowActiveFraction(theta)
  = media_t(any_m 1[|u_raw,t,m| >= theta]) en steadyRest

movementCommandLoss(theta)
  = sum(1[comando actual] y 1[|u_raw| < theta])
    / sum(1[comando actual]) en movement
```

La pérdida de Motor 2 se calcula con el mismo cociente restringido a ese motor.
El denominador son los comandos activos con `theta=0.05`; no todas las
muestras de movimiento.

### 4.6 Gate y clasificación

Se fijó antes de observar distribuciones:

```text
maximumRestWindowActiveFraction = 0.01
maximumMovementCommandLoss      = 0.05
maximumMotor2CommandLoss        = 0.05
```

Clasificación:

- `offlineThresholdSeparationExists`: existe un umbral que pasa los tres
  límites;
- `restMovementNotSeparableBySingleThreshold`: un umbral puede pasar reposo,
  pero ninguno conserva movimiento dentro de los límites;
- `restSuppressionUnresolved`: ni siquiera se encuentra un umbral de reposo
  en el dominio evaluado.

El candidato y el control quedaron en la segunda clase.

## 5. Comandos y pruebas ejecutados y resultados exactos

### 5.1 Estado y análisis estático

Se verificaron rama, historial y cambios locales mediante `git status` y
`git log`. `checkcode(...,'-id')` informó:

```text
loadNoGloveStage7gActionCorpus.m       0 issues
analyzeNoGloveStage7gActionMargins.m  0 issues
testNoGloveStage7gActionMargins.m     0 issues
run_no_glove_stage7g_action_margin_analysis.m  0 issues
```

### 5.2 Pruebas específicas

```matlab
runtests('tests/no_glove/testNoGloveStage7gActionMargins.m')
```

Resultado:

```text
Total=8, Passed=8, Failed=0, Incomplete=0
```

Las pruebas cubren corpus válido, fases, reproducción exacta de cuantización,
umbral separable, no separable, reposo no suprimible y entradas inválidas.

### 5.3 Regresión completa no-glove

Se ejecutó la suite completa `matlab_code/tests/no_glove` después del commit de
implementación:

```text
Total=114, Passed=114, Failed=0, Incomplete=0
```

El resultado se guardó como `full_no_glove_test_results.mat` con:

```text
SHA-256=66692E5773EEE95AFC070BC7CDCEBB2BB5D3E5334CEB14D6E88B172A24A04F23
```

### 5.4 Ejecución canónica

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_no_glove_intent_control\EMG_Prosthesis_TD3\matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7g_action_margin_analysis(struct( ...
  'resultsRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7g_artifacts\stage7g_final', ...
  'stage7fRunRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7f_artifacts\stage7f_final\2026-08-27_21-23-09-959'))
```

Resultado exacto:

```text
ETAPA 7G ACTION MARGIN ANALYSIS PASS
Scientific result: restMovementNotSeparableBySingleThreshold
tests: 8/8
training/simulation/hardware: no/no/no
```

MATLAB:

```text
23.2.0.3097123 (R2023b) Update 11
```

### 5.5 Reproducción independiente

Se repitió el launcher en una raíz nueva. Las diez tablas científicas
(`episode_input_hashes`, auditorías, distribuciones, curva, decisiones y
componentes) tuvieron SHA-256 idénticos bit a bit entre ejecución canónica y
reproducción. La clasificación y todas las métricas decisorias coincidieron.

## 6. Métricas y artefactos generados

### 6.1 Decisión principal

| Variante | Ventanas de reposo activas con `theta=0.05` | PWM absoluto medio en reposo | Umbral mínimo que pasa reposo | Pérdida movimiento | Pérdida Motor 2 | Umbral factible |
|---|---:|---:|---:|---:|---:|---|
| control `w_u=0.01` | 1.000000 | 113.680556 | 0.939252674581 | 0.791273903 | 0.261904762 | no |
| candidato `w_u=0.05` | 1.000000 | 115.733333 | 0.792000174523 | 0.809210526 | 0.809523810 | no |

En ambos casos el umbral de reposo reduce el PWM medio de ese estrato a cero,
pero destruye demasiados comandos de movimiento. En el control, Motor 2
conserva más comandos que el agregado, pero el gate global igualmente falla.

### 6.2 Distribuciones agregadas de `|u_raw|`

| Variante/fase | n componentes | activos actuales | media | p05 | mediana | p95 | máximo | PWM absoluto medio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| control/steadyRest | 1440 | 1.000000 | 0.449371 | 0.081127 | 0.419701 | 0.917759 | 0.939253 | 113.680556 |
| control/preActivation | 2400 | 1.000000 | 0.455544 | 0.080576 | 0.418792 | 0.923066 | 0.939256 | 116.776250 |
| control/movement | 3800 | 0.977105 | 0.531962 | 0.078272 | 0.486855 | 1.000000 | 1.000000 | 139.947632 |
| control/postActivationHold | 6000 | 0.929167 | 0.436294 | 0.046495 | 0.426605 | 0.959755 | 1.000000 | 115.908333 |
| candidato/steadyRest | 1440 | 1.000000 | 0.450100 | 0.149626 | 0.420757 | 0.774429 | 0.792000 | 115.733333 |
| candidato/preActivation | 2400 | 1.000000 | 0.444368 | 0.149542 | 0.419482 | 0.774559 | 0.891728 | 114.293333 |
| candidato/movement | 3800 | 1.000000 | 0.459402 | 0.140085 | 0.368304 | 0.999922 | 0.999989 | 120.006316 |
| candidato/postActivationHold | 6000 | 0.998000 | 0.423371 | 0.167961 | 0.337940 | 0.836342 | 0.999986 | 112.397000 |

En el candidato, `steadyRest` llega hasta `0.792000`, mientras que movimiento
tiene p05 `0.140085` y mediana `0.368304`. El solapamiento es amplio; no es un
caso de dos poblaciones separadas cerca de `0.05`.

### 6.3 Reposo por motor del candidato

| Motor | media `|u_raw|` | p05 | mediana | p95 | máximo | PWM absoluto medio |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.528663 | 0.475630 | 0.517078 | 0.575431 | 0.575718 | 142.933333 |
| 2 | 0.421924 | 0.415032 | 0.420757 | 0.427963 | 0.428498 | 96.000000 |
| 3 | 0.586995 | 0.396765 | 0.595468 | 0.774648 | 0.792000 | 144.000000 |
| 4 | 0.262816 | 0.148834 | 0.262918 | 0.375668 | 0.400651 | 80.000000 |

Motor 3 fija el umbral de reposo del candidato. Esto describe comandos de la
política; no demuestra corriente eléctrica en ningún motor.

### 6.4 Movimiento por motor del candidato

| Motor | n | media `|u_raw|` | p05 | mediana | p95 | máximo | PWM absoluto medio |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 650 | 0.331416 | 0.168933 | 0.305668 | 0.580281 | 0.603248 | 87.975385 |
| 2 | 1050 | 0.537640 | 0.126301 | 0.553198 | 0.999986 | 0.999989 | 138.598095 |
| 3 | 1050 | 0.566104 | 0.229673 | 0.585294 | 0.894333 | 0.914143 | 143.725714 |
| 4 | 1050 | 0.353693 | 0.102158 | 0.346007 | 0.579642 | 0.618584 | 97.523810 |

### 6.5 Artefacto canónico

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7g_artifacts\
stage7g_final\2026-08-27_22-40-50-290
```

Hashes principales:

```text
manifest.json
  B3C407247CB2DD49CBF683D755821B501C176819EFD28EB7662F14BB1EED9868
stage7g_results.mat
  514DAB394EFB13E915A088615ED31677FE2E28FD18210CDD7A7CD080A989898D
```

El directorio contiene el corpus tabular, inventario y auditoría de episodios,
auditoría de referencia/perfiles/cuantización, resumen de distribuciones,
curva completa de umbrales, decisiones, MAT de resultados, pruebas, reporte,
comando reproducible y manifiesto.

La reproducción independiente está en:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7g_artifacts\
stage7g_repro\2026-08-27_22-43-21-328
```

## 7. Riesgos, supuestos y cuestiones no resueltas

1. El resultado corresponde a los dos agentes de 200 episodios y seed 11 de
   ETAPA 7F. No demuestra separabilidad o inseparabilidad universal entre
   seeds, presupuestos o políticas futuras.
2. La evaluación del umbral es contrafactual estática sobre acciones
   registradas. Aplicar un umbral alteraría estados y acciones posteriores;
   por seguridad no se hizo esa intervención al observar que el gate offline
   ya fallaba ampliamente.
3. Conservar 95% de comandos no garantiza conservar tracking, y perder 81% no
   cuantifica directamente el deterioro de tracking. La métrica sirve como
   filtro de viabilidad, no como evaluación dinámica.
4. `steadyRest` significa referencia mecánica constante en un dataset de
   reposo. No es una medición fisiológica independiente ni una nueva
   validación de la compuerta EMG histórica.
5. Las acciones altas pueden deberse a sesgo funcional aprendido, soporte de
   entrenamiento, dinámica de la planta, estructura de reward u otros
   factores. ETAPA 7G no distingue entre esas causas.
6. La similitud de distribuciones entre reposo y movimiento impide usar una
   magnitud global única con el gate fijado. No excluye decisiones causales
   condicionadas por intención y error mecánico, que requerirían otra
   ablación.
7. No se trató `saturationFraction` como porcentaje de tiempo con cuatro
   motores al máximo. Esa métrica sigue siendo la fracción de componentes
   motor-paso con `|u_eff|>=0.95`.
8. No se interpretaron las 40 features WMoos estandarizadas como amplitudes
   físicas `[0,1]` y no se usaron para fijar este umbral de acción.
9. No se evaluó DTW porque la pregunta de ETAPA 7G no es temporal y los
   resultados anteriores no justificaron convertirlo en reward dominante.
10. La causa raíz continúa clasificada como hipótesis no resuelta.

## 8. Confirmación explícita de que no se usó hardware

No se activó hardware, Myo, guante, puerto COM, PWM físico ni conexión real.
No se creó el entorno ni se invocó el simulador. Todo el trabajo fue lectura y
análisis offline de logs existentes generados con `simMotors=true`. Los valores
PWM informados son comandos simulados registrados, no mediciones de corriente.

## 9. Commit de la etapa

Implementación:

```text
1a2095116927af4fa90d5cdb51fac1f7a2192513
Add Stage 7G offline action margin analysis
```

El commit documental de cierre se informa tras crearlo. No se hizo push ni se
abrió PR. `matlab_code.zip` permanece fuera del versionado y sin cambios.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

Se propone **ETAPA 7H - ablación causal de penalización de acción durante
hold en objetivo**. No se ejecuta como parte de 7G.

Hipótesis: como un aumento global de `w_u` redujo esfuerzo pero no el reposo, y
un umbral global no separa los regímenes, penalizar específicamente comandos
cuando la referencia está detenida y la posición ya está cerca del objetivo
puede reducir PWM innecesario sin castigar el esfuerzo requerido durante
movimiento.

El término propuesto usa solo variables ya observables en `intentMarkov60`:

```text
e_q,t = q_t - q_ref,t

I_hold,t = 1[ max_m |v_ref,t,m| <= epsilon_v ]
           * 1[ mean_m(e_q,t,m^2) <= epsilon_q2 ]

r_7H,t = r_7F,t - w_hold * I_hold,t * mean_m(u_eff,t,m^2)
```

Plan controlado:

1. pre-registrar `epsilon_v`, `epsilon_q2`, `w_hold` y los gates antes de
   entrenar;
2. verificar numéricamente casos de movimiento, hold fuera del objetivo,
   hold en objetivo, saturación y cada motor;
3. confirmar que el indicador es causal, finito y calculado con variables de
   la misma transición que la acción penalizada;
4. mantener congelados target, estado 60, cuantización, simulador, seguridad,
   datasets, arquitectura, seed 11 y todos los pesos restantes;
5. crear desde cero un control `w_u=0.05` y un candidato que difiera solo por
   el término `w_hold`, con 200 episodios cada uno; no cargar Agent7250 ni los
   agentes 7F;
6. ejecutar pruebas unitarias y smoke antes de cualquier entrenamiento; si
   fallan, detenerse;
7. evaluar ambos sobre idénticas simulaciones de aceptación y reposo;
8. exigir `windowAnyCommandFraction<=0.01` y saturación de reposo cero, además
   de trackingMSE candidato/control `<=1.05`, cero NaN/Inf, cero violaciones de
   límites y ninguna regresión en Motor 2 ni en M1/M3/M4;
9. detenerse después del smoke, mostrar ambos resultados y no iniciar piloto
   2k ni campaña.

La capa de seguridad seguirá siendo determinista e independiente de la reward.
Esta propuesta no se presenta como solución validada hasta superar sus pruebas
y el smoke emparejado.
