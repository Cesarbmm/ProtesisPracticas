# ETAPA 7O — auditoría contrafactual de `declaredRest` y `holdLatch`

Fecha de cierre: 2026-08-29. Resultado de ejecución: **PASS**. Resultado
científico: **`bitsContextDependent`**. La decisión preinscrita es detener el
entrenamiento y volver provisionalmente a `intentMarkov60`; no se autoriza un
smoke nuevo, un piloto de 2 000 episodios ni una campaña.

## 1. Resultado de la etapa

La red de 62 entradas no ignora los bits: hay gradientes no nulos, cambios de
acción cruda y cambios reales de PWM. Sin embargo, el signo del efecto depende
del motor y del contexto. En Agent200, el contraste de reposo tiene beneficio
PWM global negativo (`-0.0384615`), mientras el contraste del latch es positivo
en promedio (`+0.0639555`), pero ambos contienen celdas favorables y adversas.

La clasificación usa igual peso para cada celda no vacía
contexto×motor×contraste:

```text
rawSensitive      = true
pwmSensitive      = true
macroNetBenefit   = 0.00691731770833333
celdas >= +0.05   = 15
celdas <= -0.05   = 16
margen            = 0.05
clasificación     = bitsContextDependent
recomendación     = holdTrainingReturnProvisionallyToIntentMarkov60
```

No se puede declarar que los bits sean globalmente beneficiosos. Tampoco son
`bitsRawOnly`: el PWM cambia en 20.289% de los casos del contraste de reposo y
43.622% de los casos del latch.

## 2. Rama y SHA base/actual

```text
rama                    experiment/no-glove-intent-control
main/base                6b213ba5c624fffb3f1094585c67d9c8ac43b737
HEAD al ejecutar 7O      9b0ff1aa59bb7c593baa9f1a1b9f118093745065
preinscripción           09e04c779375bcb9ebc71c36debd0d47c294023e
padre 7N manifest SHA256 082DADB41DAA1DAB6AE2B5E02AE15191479410F10B5DF0398837814BFC53D480
```

La única suciedad local durante la ejecución fue el archivo ajeno no rastreado
`matlab_code.zip`; no se abrió, modificó ni añadió a Git. No había cambios
rastreados pendientes.

## 3. Archivos creados y modificados

Documentación:

- `docs/no_glove_experiment/07o_preregistration.md`;
- `docs/no_glove_experiment/07o_protocol_amendment.md`;
- `docs/no_glove_experiment/07o_bit_counterfactual_audit.md`.

Implementación exclusivamente offline:

- `matlab_code/src/evaluation/classifyNoGloveStage7oContexts.m`;
- `matlab_code/src/evaluation/loadNoGloveStage7oBitCorpus.m`;
- `matlab_code/src/evaluation/evaluateFrozenActor62States.m`;
- `matlab_code/src/evaluation/evaluateFrozenActorModel62.m`;
- `matlab_code/src/evaluation/evaluateFrozenActorBitGradients.m`;
- `matlab_code/src/evaluation/evaluateNoGloveStage7oCheckpoint.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7oBitEffects.m`;
- `matlab_code/workflows/published/run_no_glove_stage7o_bit_counterfactual_audit.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7oBitCounterfactual.m`.

No se modificaron reward, cuantización, agente TD3, simulador, `Env`, capa de
seguridad ni configuraciones conductuales.

## 4. Decisiones técnicas y justificación

### 4.1 Contrafactual causal

Para cada estado registrado se congeló exactamente el prefijo
`x=s(1:60)` y se construyeron:

```text
s00 = [x,0,0]
s10 = [x,1,0]
s11 = [x,1,1]
s01 = [x,0,1]
```

Los únicos contrastes usados para decidir son:

```text
efecto de reposo: s00 -> s10
efecto del latch: s10 -> s11
```

`s01` se procesó como `oodInvalid01`; es una prueba fuera de distribución y no
participa en clasificación ni recomendación. Se verificó por igualdad exacta
que ninguna intervención alterara las primeras 60 entradas.

### 4.2 Corpus y contextos

El corpus une 200 episodios registrados durante el smoke del candidato 62, 50
episodios de aceptación de Agent200 y 24 episodios de reposo de Agent200. Cada
episodio validó estado N×62, bits binarios, `referenceSource="emgIntent"`,
procedencia schema 2 y replay causal de los bits. De 15 610 filas disponibles se
seleccionaron 2 834 de forma determinista, con máximo 512 por contexto:

| Contexto | Disponibles | Seleccionadas |
|---|---:|---:|
| reposo inicial | 274 | 274 |
| reposo declarado lejos | 5 000 | 512 |
| cerca del objetivo antes del latch | 0 | 0 |
| latch activo | 927 | 512 |
| deriva después del latch | 2 159 | 512 |
| movimiento intencional | 5 250 | 512 |
| countdown de baja actividad | 2 000 | 512 |
| sin clasificar | 0 | 0 |

La ausencia de `nearBeforeLatch` es un resultado de cobertura del log: no se
fabricaron estados y no puede inferirse un efecto específico para ese contexto.

### 4.3 Métricas

Para salida cruda `u`, acción efectiva `u_eff` y PWM firmado `p`:

```text
deltaRaw     = u_on-u_off
deltaAbsRaw  = abs(u_on)-abs(u_off)
deltaAbsPwm  = abs(p_on)-abs(p_off)
netBenefit   = P(deltaAbsPwm<0)-P(deltaAbsPwm>0)
```

También se midieron cambios de nivel, cruces `0<->64`, entradas/salidas de
`abs(u_eff)>=0.95` y gradientes
`G(m,b)=d actor_m/d state_b`. La cuantización fue la publicada
`baselineQuantized`: umbral 0.05 y niveles
`[0,64,96,128,160,192,224,255]`.

### 4.4 Validación numérica enmendada

Dos intentos se detuvieron antes de mostrar o escribir efectos científicos. El
primero detectó cancelación en diferencias finitas con `h=1e-4`; el segundo
detectó redondeo batch-versus-serial de `1.5050173e-6`, aunque el replay serial
contra `actionLog` fue exacto y hubo cero diferencias PWM. La enmienda, registrada
antes de observar la clasificación, dejó:

```text
gradiente: h=1e-2; tolerancia=max(1e-4,0.05*abs(G))
serial vs actionLog <= 1e-12
batch vs serial    <= 1e-5
diferencias PWM    = 0
```

No cambió ningún contraste, dato, umbral de clasificación ni resultado PWM.

## 5. Comandos/pruebas ejecutados y resultados exactos

Comandos representativos desde `matlab_code`:

```matlab
% Checkcode de los nueve archivos MATLAB de 7O
m = checkcode(file,'-id');

% Pruebas deterministas específicas
runtests('tests/no_glove/testNoGloveStage7oBitCounterfactual.m')

% Regresión completa
runtests('tests/no_glove','IncludeSubfolders',true)

% Auditoría final
run_no_glove_stage7o_bit_counterfactual_audit(struct( ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7o_artifacts\stage7o_final'))
```

Resultados exactos:

```text
checkcode:                    9 archivos, 0 diagnósticos
testNoGloveStage7o...:        6/6 PASS
preflight final 7O:           16/16 PASS
regresión completa no-glove: 177/177 PASS, 0 FAIL, 0 INCOMPLETE
launcher final:               PASS / bitsContextDependent
```

El replay primario evaluó 725 filas: error serial-versus-log `0`, error máximo
batch-versus-serial `1.50501728057861e-6` y cero cambios PWM. Los cuatro
checkpoints aprobaron el contraste analítico/diferencia finita; el máximo error
fue `3.32646071910858e-4` (Agent150), dentro de su tolerancia.

## 6. Métricas y artefactos generados

### 6.1 Agent200: efecto global

| Contraste | mean(abs(deltaRaw)) | mean(deltaAbsRaw) | mean(deltaAbsPwm) | reduce raw | cambia PWM | cambia nivel | beneficio PWM | adverso PWM | netBenefit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| reposo `00->10` | 0.028164 | +0.003118 | +1.3763 | 51.182% | 20.289% | 20.201% | 8.177% | 12.024% | -0.038462 |
| latch `10->11` | 0.070960 | -0.016214 | -2.5992 | 51.800% | 43.622% | 42.493% | 24.444% | 18.049% | +0.063956 |

“Reduce raw” no equivale a beneficio PWM: la discontinuidad y los niveles de
cuantización pueden conservar, aumentar o invertir el efecto discreto.

### 6.2 Agent200 por motor

| Contraste | Motor | mean(deltaRaw) | max(abs(deltaRaw)) | mean(deltaAbsPwm) | reduce raw | cambia PWM | beneficio/adverso PWM |
|---|---:|---:|---:|---:|---:|---:|---:|
| reposo | 1 | -0.009374 | 0.061127 | +0.282 | 33.522% | 8.680% | 3.917% / 4.764% |
| reposo | 2 | -0.013952 | 0.150669 | +2.547 | 43.155% | 13.162% | 3.564% / 9.245% |
| reposo | 3 | -0.025498 | 0.113196 | +6.018 | 44.672% | 39.132% | 9.986% / 29.146% |
| reposo | 4 | -0.003202 | 0.077852 | -3.342 | 83.380% | 20.183% | 15.243% / 4.940% |
| latch | 1 | +0.079266 | 0.124229 | +4.076 | 52.964% | 41.884% | 14.291% / 27.594% |
| latch | 2 | +0.077419 | 0.192466 | -8.823 | 45.272% | 36.803% | 27.770% / 5.187% |
| latch | 3 | +0.090393 | 0.248335 | -6.915 | 54.234% | 73.465% | 46.507% / 26.288% |
| latch | 4 | +0.033717 | 0.104252 | +1.265 | 54.728% | 22.336% | 9.210% / 13.126% |

Cruces y saturación por motor:

| Contraste | Motor | `0->64` | `64->0` | entrada saturación | salida saturación |
|---|---:|---:|---:|---:|---:|
| reposo | 1 | 0.423% | 0.388% | 0% | 0% |
| reposo | 2 | 4.517% | 2.223% | 1.129% | 0.635% |
| reposo | 3 | 0.035% | 0.388% | 0% | 0% |
| reposo | 4 | 0% | 0.141% | 0% | 0% |
| latch | 1 | 0.988% | 1.553% | 0% | 0% |
| latch | 2 | 1.941% | 6.845% | 1.553% | 0% |
| latch | 3 | 0.565% | 1.129% | 0.459% | 0% |
| latch | 4 | 0.035% | 0% | 0% | 0% |

### 6.3 Sensibilidad local por bit

| Bit | Motor | mean(abs(gradiente)) | max(abs(gradiente)) |
|---|---:|---:|---:|
| `declaredRest` | 1 | 0.032992 | 0.086760 |
| `declaredRest` | 2 | 0.035061 | 0.150950 |
| `declaredRest` | 3 | 0.038101 | 0.111099 |
| `declaredRest` | 4 | 0.024601 | 0.083030 |
| `holdLatch` | 1 | 0.077033 | 0.125466 |
| `holdLatch` | 2 | 0.079978 | 0.191586 |
| `holdLatch` | 3 | 0.092313 | 0.239780 |
| `holdLatch` | 4 | 0.038565 | 0.109225 |

Esto demuestra sensibilidad de red, no beneficio. El efecto discreto confirma
la dependencia contextual: durante `latchActive`, activar el latch tuvo
`netBenefit` de +0.9512 en M2 y +0.9473 en M3; durante
`driftAfterLatch` fue -0.4063 en M1, -0.3770 en M3 y -0.1602 en M4. Activar
`declaredRest` mientras el latch ya estaba activo fue especialmente adverso en
M3 (`netBenefit=-0.8496`).

### 6.4 Evolución secundaria 50/100/150

| Checkpoint | reposo netBenefit | latch netBenefit |
|---:|---:|---:|
| 50 | -0.001059 | -0.058663 |
| 100 | -0.054781 | +0.101535 |
| 150 | +0.022848 | -0.080275 |
| 200, primario | -0.038462 | +0.063956 |

El cambio de signo entre checkpoints es secundario y no reemplaza Agent200; sí
refuerza que no hay una función estable y uniforme de los bits.

### 6.5 Prueba OOD separada

`(0,0)->(0,1)` produjo `pwmChangedFraction=0.508292` y
`netBenefit=0.112209`, pero `causalValid=false`. No se utilizó para escoger la
clase ni la recomendación.

### 6.6 Rutas y hashes

Directorio final:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7o_artifacts\stage7o_final\2026-08-29_22-22-07-025
```

Artefactos principales:

| Archivo | SHA-256 |
|---|---|
| `manifest.json` | `8173E7ABB11B0FAA7A7CB7AADE74502071E804BBD5F5E4E6145448FCA53254D9` |
| `stage7o_results.mat` | `4BF2687314C981F8E7DB5FD3B8FBC461FF97AEC15D0093B0CB9B5CDEA305067A` |
| `counterfactual_effects.csv` | `AFAAF1AD1638604CA1260A28E7C8A334F9A2AEC97C1B11770EDE5AE1A1F90B32` |
| `bit_gradients.csv` | `6C9E0F2D6A33E69CACAB83A07554380392F9BDA1D628F98E30674E32BAF5AA4C` |
| `causal_effect_summary.csv` | `DE69FF7958533557FEA9111E41617203BF672BF4FE41BADBCABC36B7D827478C` |
| `ood_01_summary.csv` | `25B2821A428928B4AD7D997F1728F85C3875303CF95DF1492C2B4C66189419BF` |
| `classification.csv` | `89247CF39BE636EFC79BF0E3759EB638C35287F440AAF7D945BE5FECC8FF42BB` |
| `input_inventory.csv` | `C16520A93529F41CB4141520EFAF8508037F48A8D94F8367AEFC181DFB7EABB1` |

El manifiesto contiene hashes de los 20 artefactos y el inventario contiene los
hashes de todos los episodios de entrada. El comando exacto está en
`reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- No hubo filas `nearBeforeLatch`; ese contexto queda sin soporte observacional.
- El beneficio es definido como reducción de magnitud PWM en una intervención de
  reposo/latch; no demuestra mejor tracking ni seguridad clínica.
- Un gradiente es sensibilidad local; no predice por sí solo un cruce de nivel.
- Se mantienen como problemas para la siguiente etapa, sin corregir aquí: la
  discontinuidad `0 -> PWM 64`, la pequeña penalización específica de
  saturación, el gate común de reposo y las numerosas intervenciones de seguridad
  observadas en 7N.
- Agent7250 no se cargó ni utilizó. Su checkpoint permaneció con SHA-256
  `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.
- `bitsContextDependent` no autoriza conservar el estado 62 para entrenamientos
  más largos.

## 8. Confirmación de hardware

No se usó hardware, Myo, guante, puerto COM ni PWM físico. No se instanció `Env`,
no se ejecutó simulador ni DTW y no hubo entrenamiento. `simMotors=true` se
conservó en la configuración congelada, pero la planta no se ejecutó.

## 9. Commits de la etapa

```text
09e04c77 Preregister Stage 7O bit counterfactual audit
55813622 Add Stage 7O frozen actor bit audit
30d2d6ab Document Stage 7O gradient validation amendment
7bfaa9c4 Harden Stage 7O frozen actor replay audit
9b0ff1aa Name Stage 7O classification fields explicitly
```

El informe de cierre se añadirá en un commit final de documentación y todos los
commits se subirán únicamente a `experiment/no-glove-intent-control`.

## 10. Propuesta precisa para la siguiente etapa — no ejecutada

Proponer **ETAPA 7P: decisión de estado y diagnóstico aislado de interfaz**, sin
entrenamiento:

1. congelar `intentDeclaredRestHoldMarkov62` como variante rechazada
   provisionalmente y seleccionar `intentMarkov60` como estado de referencia;
2. auditar con el actor 60 congelado la vecindad de `±0.05` y cuantificar por
   motor el salto `0<->64`, sin cambiar todavía la cuantización;
3. atribuir por separado las intervenciones de seguridad y el gate común de
   reposo; no mezclar esas dos hipótesis con la cuantización;
4. elegir una sola intervención para una futura ablación, escribir pruebas y una
   nueva preinscripción;
5. solo si esa ablación offline y sus pruebas pasan, solicitar autorización para
   un smoke cerrado de 200 episodios. No autorizar piloto de 2 000 episodios.

ETAPA 7P no se ejecutó durante 7O.
