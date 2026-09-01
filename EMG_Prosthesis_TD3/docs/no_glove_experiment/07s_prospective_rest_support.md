# ETAPA 7S — adquisición prospectiva de soporte en reposo declarado

Fecha de ejecución: 2026-08-31 (America/Guayaquil).

Este documento cierra exclusivamente ETAPA 7S. La etapa adquirió evidencia
causal nueva en simulación para intentar resolver el soporte insuficiente que
ETAPA 7R encontró al emparejar estados reales completos. No entrenó agentes ni
modificó estado, política, reward, cuantización, simulador, gate de reposo o
capa de seguridad.

## 1. Resultado de la etapa

**Resultado operativo: PASS. Resultado científico:
`prospectiveSupportFailed`.**

La adquisición preinscrita produjo 80 episodios y 1 600 estados finitos de
`intentMarkov60`, con el gate en reposo durante todas las ventanas, referencia
constante, simulador activo y límites de posición respetados. Las 18 pruebas de
preflight y las 212 pruebas de regresión no-glove pasaron.

El gate científico no pasó. Para cada motor se obtuvieron exactamente 80 pares
`steadyRest/crossEpisode`, mientras que el mínimo preinscrito era 100. Los
restantes requisitos de esos pares —20 episodios donor, 80 episodios query,
cinco folds y reutilización máxima del donor— sí pasaron. Por tanto:

- `steadyRestCrossSupportedMotorCount = 0`;
- `globalCrossSupportedMotorCount = 4`;
- `globalWithinSupportedMotorCount = 4`;
- `supportGatePassed = false`;
- no se cargaron Agent50/100/150 para inferencia posterior;
- no se ajustaron ni ejecutaron los modelos confirmatorios de 7R;
- no se relajó el umbral y no se agregaron episodios después de observar el
  resultado.

El resultado no contradice que haya pares globales suficientes. Los pares
globales combinan la aceptación congelada de 7N y la adquisición prospectiva;
el criterio decisivo exigía soporte propio del contexto prospectivo
`steadyRest` para no hacer depender la conclusión de la evidencia anterior.

### Interpretación científica

El diseño consiguió diversidad EMG alta bajo la definición actual de reposo,
pero sólo el primer paso de cada uno de los 80 episodios encontró un donor
cross-episode compatible. Tras aplicar la primera acción, `q`, `Deltaq` y
`u_eff,t-1` divergieron entre trayectorias, de modo que las ventanas posteriores
dejaron de satisfacer el límite mecánico/contextual congelado. El límite no fue
la diversidad EMG: el RMS mínimo entre ventanas con canales dominantes distintos
fue `0.95343578454186517`, superior al umbral `0.50`.

La conclusión de 7S se limita a soporte insuficiente bajo el matching
preinscrito. No identifica aún una familia EMG causal, no valida reposo humano y
no autoriza entrenamiento.

## 2. Rama y SHA base/actual

```text
Rama:     experiment/no-glove-intent-control
SHA base: 6b213ba5c624fffb3f1094585c67d9c8ac43b737 (main verificado en ETAPA 0)
SHA de la ejecución canónica: 30c4b5fba93076b0321d0e9a3c427e870c00c143
```

El SHA actual posterior al commit de este informe se registra en la sección 9.
La rama no se fusionó con `main` y no se hizo push en ETAPA 7S.

El benchmark canónico sigue intacto:

```text
matlab_code/checkpoints/canonical/Agent7250_valid_baseline/
    Agent7250_valid_baseline.mat
SHA-256 = 0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54
```

Agent7250 no fue cargado ni usado. Agent200 se cargó únicamente como controlador
congelado de la simulación.

## 3. Archivos creados y modificados

### Creados

- `docs/no_glove_experiment/07s_preregistration.md`: hipótesis, diseño,
  umbrales, orden de ejecución y política de fallo cerrado registrados antes de
  adquirir los episodios.
- `docs/no_glove_experiment/07s_prospective_rest_support.md`: este informe.
- `matlab_code/src/runtime/buildNoGloveStage7sRestSupportCorpus.m`: generador
  determinista de EMG cruda prospectiva.
- `matlab_code/src/runtime/validateNoGloveStage7sEvaluationProfile.m`: auditoría
  del perfil efectivo de simulación.
- `matlab_code/src/evaluation/classifyNoGloveStage7sSupportGate.m`: gate
  operativo/científico con fallo cerrado.
- `matlab_code/src/evaluation/loadNoGloveStage7sEvidence.m`: carga y validación
  por hashes de los padres y checkpoints congelados.
- `matlab_code/src/evaluation/summarizeNoGloveStage7sAcquisition.m`: resumen de
  finitud, alineación, gate, referencia, seguridad y comandos.
- `matlab_code/tests/no_glove/testNoGloveStage7sProspectiveRestSupport.m`: nueve
  pruebas deterministas de la etapa.
- `matlab_code/workflows/published/run_no_glove_stage7s_prospective_rest_support.m`:
  launcher único reproducible.

### Modificados

- `matlab_code/src/evaluation/buildNoGloveStage7rRealPairs.m`: se añadieron
  overrides explícitos para reutilizar las escalas EMG/contexto congeladas, una
  tabla tipada segura cuando no hay pares y el conteo correcto de cinco folds
  por fuente representada.
- `matlab_code/workflows/published/README.md`: se publicó el contrato del
  launcher 7S.

No se modificaron `Env`, la reward, TD3, el actor, los críticos, la
cuantización, el simulador, el gate de reposo ni la seguridad.

## 4. Decisiones técnicas y justificación

### 4.1 Pregunta contrafactual abordada

ETAPA 7R no pudo concluir la atribución EMG bajo matching porque el reposo real
guardado no aportaba suficientes pares de estados completos que conservaran
contexto mecánico y cambiaran EMG. 7S preguntó si una adquisición nueva,
prospectiva y causal podía generar ese soporte sin fabricar estados híbridos.

La unidad de evidencia siguió siendo un estado completo observado:

```text
s_t = [phi_EMG,t(40), q_t(4), Deltaq_t(4), u_eff,t-1(4),
       q_ref,t(4), v_ref,t(4)] in R^60
```

No se intercambiaron features entre filas ni se construyeron estados que el
entorno no hubiera producido.

### 4.2 Diseño matemático de EMG cruda

Se congelaron semilla `7701`, 80 episodios, 21 ventanas por captura y 20 pasos
simulados. Para cada canal calibrado se eligió una activación física `a_c` y se
invirtió la normalización de intención:

```text
m_c = b_c + a_c (s_c - b_c + epsilon)
```

La señal bipolar se construyó para que su envolvente satisficiera exactamente:

```text
m_c(t) = (1/N) sum_n |x_c[n]|.
```

En cada ventana un canal tomó una activación dominante determinista en
`[0.84, 0.90]`. Los otros seis canales no planos se ajustaron para mantener:

```text
A_t = mean(a_c(activeChannels)) = 0.13 < theta_on = 0.14.
```

El canal plano permaneció plano. Una portadora bipolar y una modulación
determinista variaron la forma de onda sin alterar la media absoluta prescrita.
Esto produjo distintos vectores WMoos manteniendo el gate inactivo.

El diseño es deliberadamente un estrés sintético del agregador común por media:
una activación grande en un solo canal puede quedar oculta por el promedio. No
se interpreta como reposo fisiológico, amplitud humana ni correspondencia
canal-motor.

### 4.3 Variables congeladas

Se reutilizaron sin recalcular:

- estado `intentMarkov60`;
- Agent200 del control60, SHA-256
  `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E`;
- `normValues.mat`, SHA-256
  `7DDA997F59E1327C8A4EF9CDDE07463506754FB73A52001E983B3A3877B017B2`;
- perfil efectivo congelado, SHA-256
  `1E3853E96D93E656845A123E6C100B0037460A1A2D2EEC386C03C17DAE909A6E`;
- límites `contextMax <= 0.25` y `emgRms >= 0.50`;
- cinco folds, mínimo 100 pares, mínimo 20 episodios y reutilización donor
  máxima `0.10`;
- `trackingIntentActionRateReward`, `baselineQuantized`, simulador y
  `simulationPositionSafety`.

La configuración se aplicó mediante `setConfigurablesOverride`; no se cambiaron
defaults globales.

### 4.4 Orden de adquisición y análisis

El dataset se validó antes de construir `Env`. Luego Agent200 controló los 80
episodios. Después se combinaron únicamente:

1. 50 episodios `acceptance` congelados de Agent200/7N;
2. 80 episodios prospectivos nuevos etiquetados `steadyRest`.

Los episodios antiguos de `steadyRest` se excluyeron de la decisión. El corpus
se bloqueó por hash antes del gate. Como el gate falló, los checkpoints
50/100/150 no se cargaron y los modelos confirmatorios no se ejecutaron.

### 4.5 Corrección de la auditoría de folds

La primera salida, preservada en:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7s_artifacts\stage7s_final\
2026-08-31_22-53-26-933
```

quedó supersedida. El resumen global comparaba diez celdas fuente-fold
observadas —cinco de `acceptance` más cinco de `steadyRest`— contra un esperado
fijo de cinco. La corrección cuenta cinco folds por cada fuente representada:

```text
expectedSourceFoldCount = foldCount * representedSourceCount.
```

Se añadió una regresión específica y se volvió a ejecutar todo desde un nuevo
directorio. No se cambió ningún umbral científico. La corrida corregida también
falló, exclusivamente porque `80 < 100`; la corrección no rescató el resultado.

## 5. Comandos y pruebas ejecutados

### 5.1 Launcher canónico

MATLAB R2023b Update 11 ejecutó el comando guardado en el artefacto:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_no_glove_intent_control\EMG_Prosthesis_TD3\matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7s_prospective_rest_support(struct( ...
    'resultsRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7s_artifacts\stage7s_final', ...
    'stage7rRunRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7r_artifacts\stage7r_final\2026-08-31_21-42-38-792', ...
    'stage7qRunRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7q_artifacts\stage7q_final\2026-08-30_16-44-30-296', ...
    'stage7pRunRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7p_artifacts\stage7p_final\2026-08-29_23-15-59-803', ...
    'stage7nRunRoot','C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7n_artifacts\stage7n_corrected_final\2026-08-29_07-34-46-814'));
```

Resultado exacto del preflight canónico:

```text
testNoGloveStage7sProspectiveRestSupport: 9/9 PASS
testNoGloveStage7rRealStateEmgAttribution: 9/9 PASS
TOTAL: 18 PASS, 0 FAIL
```

Antes de la corrección de folds se habían ejecutado ocho pruebas 7S. La nueva
prueba eleva el total 7S a nueve y confirma cobertura por fuente.

### 5.2 Análisis estático

`checkcode` se ejecutó sobre los ocho archivos MATLAB relevantes de 7S y el
constructor de pares modificado:

```text
Archivos auditados: 8
Diagnósticos: 0
```

### 5.3 Regresión completa no-glove

```text
FULL_NO_GLOVE_TESTS=212
PASS=212
FAIL=0
INCOMPLETE=0
```

El resultado se guardó como `full_no_glove_regression.mat`, SHA-256
`2783BA7E50535EF4DE6877EB3ABEDDEF488DDA87EE27803F1A70BCCE2371C4BA`.

### 5.4 Verificaciones operativas

El manifiesto registra 23 verificaciones operativas verdaderas: padres 7N/7P/
7Q/7R válidos, estado 60 seleccionado, estado 62 rechazado provisionalmente,
contratos de dataset y perfil válidos, aceptación invariante, adquisición
bloqueada antes de modelos y ausencia de cambios en reward, cuantización, TD3,
simulador, seguridad y gate. También confirma ausencia de entrenamiento,
hardware, Myo, guante, DTW, smoke, piloto y campaña.

## 6. Métricas y artefactos generados

### 6.1 Raíz canónica

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7s_artifacts\stage7s_final\
2026-08-31_22-58-01-555
```

Padre canónico 7R:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7r_artifacts\stage7r_final\
2026-08-31_21-42-38-792
SHA-256(manifest.json) = 5111367127942D80D97BA299F47872019548CFF2126B4D75B33F161C36F90847
SHA-256(stage7r_results.mat) = 7F07C0ACB45A339BB9C339E68F9689E3E5EE23103963354ACA568AB9AB2899F1
```

### 6.2 Contrato de adquisición

| Métrica | Resultado |
|---|---:|
| Episodios prospectivos | 80 |
| Estados prospectivos | 1 600 |
| Componentes primarios combinados | 4 105 |
| Pares totales combinados | 1 920 |
| Estados `initialRest` | 80 |
| Estados `declaredRest` | 1 520 |
| `gateActive` | 0 |
| `lowActivityCountdown` | 0 |
| `v_ref != 0` | 0 |
| Error máximo de hold de referencia | 0 |
| Error máximo de actividad declarada | `1.38777878078145e-16` |
| RMS EMG mínimo cross-dominante | `0.95343578454186517` |
| Intervenciones de seguridad | 4 072 |

Todas las muestras fueron finitas, todos los estados tuvieron 60 dimensiones y
no hubo violaciones de los límites de posición.

### 6.3 Soporte `steadyRest/crossEpisode`

| Motor | Queries elegibles | Pares | Cobertura | Episodios query | Episodios donor | Folds | Reuso donor máx. | Soportado |
|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| M1 | 840 | 80 | 0.095238 | 80 | 20 | 5 | 0.0875 | No |
| M2 | 519 | 80 | 0.154143 | 80 | 20 | 5 | 0.0875 | No |
| M3 | 610 | 80 | 0.131148 | 80 | 20 | 5 | 0.0875 | No |
| M4 | 840 | 80 | 0.095238 | 80 | 20 | 5 | 0.0875 | No |

El único criterio fallido en las cuatro filas fue `pairCount >= 100`. Los 320
pares prospectivos, 80 por motor, corresponden a `queryStep = 1`.

En el corpus global hubo 280 pares por motor, 105 episodios query, 30 episodios
donor, diez celdas fuente-fold y reutilización máxima
`0.0892857142857143`. Por ello el soporte global cross-episode pasó en los
cuatro motores. El soporte global within-episode también pasó en los cuatro,
pero procedió de la aceptación congelada; el nuevo `steadyRest` aportó cero
pares within-episode.

### 6.4 Comandos descriptivos de Agent200

Estas métricas describen comandos simulados ante el estrés sintético. No son
corriente eléctrica, no prueban movimiento físico y no son comparables de forma
directa con el MSE del target de guante de Agent7250.

| Motor | mean abs(raw) | mean abs(effective) | mean abs(PWM) | PWM no cero | Saturación por componente | Intervenciones seguridad |
|---:|---:|---:|---:|---:|---:|---:|
| M1 | 0.681570 | 0.697980 | 177.99 | 0.996875 | 0.214375 | 1 464 |
| M2 | 0.671300 | 0.672930 | 171.60 | 1.000000 | 0.143125 | 697 |
| M3 | 0.591860 | 0.605800 | 154.48 | 0.992500 | 0.121250 | 547 |
| M4 | 0.666190 | 0.674130 | 171.90 | 0.935625 | 0.357500 | 1 364 |

Resumen agregado:

```text
mean row rawActionL2       = 1.4171974438276718
mean row effectiveActionL2 = 1.4272195151966622
saturationFraction         = 0.2090625
nonzero PWM fraction       = 0.98125
max abs raw action         = 0.99956291913986206
safety interventions       = 4072
```

`saturationFraction` es la fracción de componentes motor-paso con
`abs(effectiveAction) >= 0.95`; no significa que los cuatro motores estuvieran
simultáneamente al máximo.

### 6.5 Hashes principales

| Artefacto | SHA-256 |
|---|---|
| `manifest.json` | `6E8A9FE1244C885A8AE3F149AE946D5D1D662B541C554F675E308F540F7FB5CD` |
| `stage7s_results.mat` | `FEC0054E4BB364BBC3DF64CC1FEAF11C52C6A69DF3C2A32C82AD2E50390A8AB0` |
| dataset prospectivo | `590791ACD221ABFC3BD5B5C7586E3716E54EEDCE0CDD67E358E005984835F956` |
| lock de adquisición | `823A72918E6552038AC151E647E5D61E590D0F1E16EB45B93E51D15668FC33DD` |
| `real_pairs.csv` | `28AEE12F640A314592AD95102D1249AAB90FB92E57A734621F4B21BAE3D0E8C1` |
| `pair_support_summary.csv` | `CA0930C53DB43E3D4523461F3D179826BBB119A83711C31EC0814C212A859CFE` |
| `support_gate_checks.csv` | `8E3AC279C7BBAF32BEC85EADF3C06674EA5D9E9F58A46FA3804E5812B559B209` |
| `prospective_emg_design.csv` | `AFCC5C4434EE21F4002E859C754076FEC2F34BF81F424A9065F356EA9649BA55` |
| `acquisition_summary.csv` | `E82DB78A972B2034662E57404396578C42B73B08E5BC61AE34606B06BED51B23` |
| `evaluation_profile_audit.csv` | `24E1578760F01A7DE8C4FA39A856118ED266B3BB53C0BAEFE00804AC3322E242` |
| `input_inventory.csv` | `DFC06584379E902CF88C1D0B6743E70AE2DE1F23C7E47EEA27DBEB99349E81F5` |
| `operational_checks.csv` | `647C5DB969368B00EB57E0B101390F5604E2FC904C5C9EB6BDA2B35DF067B488` |
| regresión no-glove | `2783BA7E50535EF4DE6877EB3ABEDDEF488DDA87EE27803F1A70BCCE2371C4BA` |

El manifiesto contiene además hashes individuales para los 80 episodios, el
perfil, las configuraciones y todos los CSV/MAT restantes.

## 7. Riesgos, supuestos y cuestiones no resueltas

1. **Soporte insuficiente.** No se puede ejecutar el análisis confirmatorio de
   atribución sin violar el gate. Obtener retrospectivamente 20 episodios o
   pares más después de ver el resultado constituiría un cambio de diseño, no
   una continuación neutral de 7S.
2. **Diversidad temporal limitada.** Todos los pares prospectivos válidos
   aparecen en el primer paso. La evolución de la planta y `u_eff,t-1` elimina
   comparabilidad posterior. Aún no se ha cuantificado cuál bloque mecánico
   explica principalmente esa divergencia.
3. **Estrés sintético, no reposo fisiológico.** El dataset demuestra una
   propiedad del promedio del gate con calibración congelada; no estima falsas
   activaciones en personas ni autoriza Myo/hardware.
4. **Comandos altos en reposo declarado.** La política produce PWM no cero en
   98.125% de los componentes y activa 4 072 intervenciones de seguridad. Esto
   es evidencia descriptiva importante, pero el diseño 7S no permite atribuir
   por sí solo la causa al gate, a WMoos, a OOD, a la política o a la planta.
5. **Gate común por media.** Una activación dominante puede diluirse entre
   canales. Es un problema candidato para una ablación futura de un único
   factor; 7S no cambia el gate.
6. **Discontinuidad de cuantización.** El salto `0 -> PWM 64` permanece abierto.
   No se modificó para conservar causalidad experimental.
7. **Penalización de saturación.** Sigue siendo pequeña y específica respecto a
   la magnitud observada; se registra como hipótesis, no como causa raíz única.
8. **Seguridad.** La frecuencia de intervenciones confirma que la capa
   determinista sigue siendo necesaria. La reward no puede sustituirla.
9. **Estado 62.** Continúa rechazado provisionalmente según 7O; no se reabrió la
   decisión.
10. **Benchmark.** Las métricas de intención y este estrés de reposo no deben
    equipararse al tracking de guante de Agent7250.
11. **Archivo local ajeno.** `matlab_code.zip` permanece sin seguimiento y no se
    modificó.

No se afirma que el MSE sea la causa raíz de saturación. Tampoco se afirma que
Motor 2 reciba corriente: los registros contienen comandos, no corriente
eléctrica medida.

## 8. Confirmación de ausencia de hardware

**No se usó hardware.** La adquisición fue exclusivamente simulada con
`simMotors=true` y `connect_glove=false`. No se abrieron puertos COM, no se usó
Myo, guante, PWM físico, motores reales, sensores de corriente o temperatura.

Tampoco se calculó DTW, se entrenó, ejecutó smoke de entrenamiento, piloto de
2 000 episodios o campaña. Agent200 sólo realizó inferencia y control dentro del
simulador.

## 9. Commits de la etapa

```text
32bd9129 Preregister Stage 7S prospective rest support
dcac05f0 Add Stage 7S prospective rest support
30c4b5fb Count Stage 7S folds per source
```

El commit final de documentación se registra al terminar este informe. No se
hizo push porque la orden de ETAPA 7S no lo autorizó.

## 10. Propuesta precisa de la siguiente etapa — no ejecutada

Se propone **ETAPA 7T: auditoría offline de consecuencias del estrés del gate y
de divergencia contextual**, usando exclusivamente el corpus canónico bloqueado
de 7S.

Alcance propuesto:

1. preinscribir métricas y congelar el lock/hash de 7S;
2. no adquirir nuevos episodios, no entrenar y no modificar componentes;
3. estratificar acciones crudas, acciones efectivas, PWM, saturación e
   intervenciones de seguridad por canal dominante, condición inicial/home,
   paso y motor;
4. separar `step=1`, donde existe matching, de la trayectoria posterior;
5. medir la contribución normalizada de `q`, `Deltaq`, `u_eff,t-1`, `q_ref` y
   `v_ref` al fallo del límite de contexto desde `step=2`;
6. distinguir sensibilidad de la red, cambio real de PWM y efecto de seguridad;
7. decidir entre dos salidas: evidencia consistente de riesgo del agregador
   común que justifique una ablación posterior de un único factor, o evidencia
   limitada a un artefacto OOD sintético que cierre esta vía y posponga la
   validación a shadow mode humano autorizado;
8. mantener Agent7250, estado 60, reward, cuantización, TD3, simulador, gate y
   seguridad congelados.

ETAPA 7T no se ejecuta en este cierre. En particular, no se autoriza completar
el umbral de 100 de manera retrospectiva ni iniciar entrenamiento, smoke,
piloto, campaña, DTW, Myo o hardware.
