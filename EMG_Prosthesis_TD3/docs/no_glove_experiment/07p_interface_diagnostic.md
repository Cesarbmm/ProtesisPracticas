# ETAPA 7P — decisión de estado y diagnóstico offline de interfaz

Fecha de cierre: 2026-08-29.

## 1. Resultado de la etapa

Resultado de ejecución: **PASS**. Resultado científico preinscrito:
**`noAblationSupported`**.

La decisión de estado queda explícita:

```text
estado de referencia      = intentMarkov60
estado 62                 = provisionallyRejected
checkpoint de diagnóstico = control60 Agent200, solo offline
```

La discontinuidad matemática `0 -> PWM 64` existe y fue reproducida, pero su
exposición observada cerca de `theta=0.05` fue 0.153959%, por debajo del 1%
preinscrito. La asociación del gate común también quedó bajo su mínimo:
9.523810% de componentes motor-paso durante gate activo tenían referencia del
motor inactiva, frente al 10% exigido. Por la regla fijada antes de leer las
acciones no se elige cuantización ni gate para una ablación inmediata.

`noAblationSupported` no significa que la política sea adecuada. Casi todas las
acciones observadas produjeron PWM no cero y hubo numerosas intervenciones de
seguridad. Significa únicamente que ninguna de las dos intervenciones candidatas
de 7P superó su gate causal/operativo preinscrito.

## 2. Rama y SHA base/actual

```text
rama                 = experiment/no-glove-intent-control
main/base             = 6b213ba5c624fffb3f1094585c67d9c8ac43b737
HEAD de ejecución 7P = 22df376f58f68562450da83c4d52b17f88271a9c
preinscripción        = c263a5ae
Agent200 state60      = 440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E
```

La única suciedad local fue el archivo ajeno no rastreado `matlab_code.zip`,
preservado sin abrir, modificar ni añadir. El árbol rastreado estaba limpio al
ejecutar el launcher final.

## 3. Archivos creados y modificados

Documentación:

- `docs/no_glove_experiment/07p_preregistration.md`;
- `docs/no_glove_experiment/07p_interface_diagnostic.md`.

Código offline:

- `matlab_code/src/evaluation/loadNoGloveStage7pInterfaceCorpus.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7pInterface.m`;
- `matlab_code/workflows/published/run_no_glove_stage7p_interface_diagnostic.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7pInterfaceDiagnostic.m`.

Se documentó el launcher en `matlab_code/workflows/published/README.md`. No se
modificaron `Env`, reward, cuantización, TD3, referencia, simulador, gate ni capa
de seguridad.

## 4. Decisiones técnicas y justificación

### 4.1 Corpus primario

Se cargaron exclusivamente:

```text
50 episodios acceptance de control60/Agent200 = 3 050 ventanas
24 episodios steadyRest de control60/Agent200 =   360 ventanas
total                                         = 3 410 ventanas
componentes motor-paso                        = 13 640
```

Los 200 episodios de entrenamiento quedaron excluidos porque mezclan
exploración y políticas en evolución. Los estados 62 y Agent7250 no se cargaron.
Cada uno de los 74 archivos fue inventariado con SHA-256.

### 4.2 Replay causal

Se verificó para cada episodio:

- estado N×60 y logs N×4 finitos;
- `referenceHistory(t)=q_ref,t` visible en `state_t`;
- encoder posterior de `t` igual al encoder de `state_(t+1)`;
- procedencia de intención `t-1 -> state_t`, sin fuga futura;
- cuantización guardada igual a `quantizeBaselineAction`;
- seguridad simulada habilitada y límites `[0,1]^4`.

Agent200 reprodujo 3 410 acciones seriales con error máximo `0`. La diferencia
batch-versus-serial fue `1.77323818206787e-6` y produjo cero discrepancias PWM.

### 4.3 Contrafactual aislado de interfaz

Para una acción observada `u` a distancia no mayor que 0.01 de `theta=0.05`:

```text
si abs(u)<theta:   abs(u_cf)=theta
si abs(u)>=theta:  abs(u_cf)=theta-1e-6
sign(u_cf)=sign(u)
```

No cambió el estado ni el actor. Los 21 casos fueron exclusivamente cruces
`0<->64`; el salto efectivo fue exactamente:

```text
64/255 = 0.250980392156863
```

La amplificación `abs(deltaEffective)/abs(deltaRaw)` tuvo media 68.1626,
mediana 64.6420 y máximo 107.9485. Esto caracteriza la discontinuidad, pero no
demuestra exposición suficiente para escogerla como siguiente intervención.

### 4.4 Gate y seguridad separados

El gate se analizó solo por asociación con la referencia causal registrada. No
se alteró ni se creó un gate por motor. La seguridad se clasificó aparte:

```text
outwardBoundary = encoder en límite y PWM apunta hacia fuera
boundaryOther   = encoder en límite, sin comando hacia fuera
interior        = intervención con encoder observado en interior
```

No se interpretó una intervención como fallo de seguridad: la mayor parte
coincidió con el comportamiento protector esperado.

## 5. Comandos/pruebas y resultados exactos

```matlab
checkcode(file,'-id')
runtests('tests/no_glove/testNoGloveStage7pInterfaceDiagnostic.m')
runtests('tests/no_glove','IncludeSubfolders',true)
run_no_glove_stage7p_interface_diagnostic(struct( ...
  'resultsRoot', ...
  'C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7p_artifacts\stage7p_final'))
```

Resultados:

```text
checkcode 7P                  = 4 archivos, 0 diagnósticos
pruebas deterministas 7P      = 8/8 PASS
preflight del launcher        = 14/14 PASS
regresión completa no-glove   = 185/185 PASS
fallos/incompletas            = 0/0
launcher final                = PASS
resultado científico          = noAblationSupported
```

Hubo dos detenciones antes de cargar acciones: una por el nombre del campo
`runTraining` del manifiesto 7O y otra por la ubicación estructurada de
`simulationPositionSafety`. Se corrigieron sin modificar criterios científicos.
El directorio parcial `2026-08-29_23-09-03-629` no es evidencia canónica. Las
ejecuciones anteriores a la estratificación final quedaron sustituidas por el
directorio final indicado abajo.

## 6. Métricas y artefactos generados

### 6.1 Exposición de la interfaz

De 13 640 componentes motor-paso:

| Región | Conteo | Fracción |
|---|---:|---:|
| `abs(u)<0.05`, PWM 0 | 12 | 0.087977% |
| nivel mínimo `abs(PWM)=64` | 4 258 | 31.217009% |
| niveles mayores que 64 | 9 370 | 68.695015% |
| saturación `abs(u_eff)>=0.95` | 250 | 1.832845% |
| distancia a `theta<=0.01` | 21 | 0.153959% |

Por motor:

| Motor | PWM 0 | PWM 64 | niveles >64 | saturación | cerca de `theta` | distorsión media `abs(u_eff-u)` |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0% | 21.7595% | 78.2405% | 0% | 0% | 0.036199 |
| 2 | 0.3519% | 15.3079% | 84.3402% | 7.3314% | 0.6158% | 0.036237 |
| 3 | 0% | 30.9384% | 69.0616% | 0% | 0% | 0.036677 |
| 4 | 0% | 56.8622% | 43.1378% | 0% | 0% | 0.053809 |

Los 21 casos cercanos pertenecieron a M2 en aceptación: 8 cruces `0->64` y 13
cruces `64->0`. En `steadyRest` no hubo acciones cerca del umbral ni PWM cero;
por tanto, corregir solo la discontinuidad de activación no explica los comandos
altos de reposo de este actor.

### 6.2 Gate común

Contextos observados:

| Contexto | Ventanas |
|---|---:|
| reposo inicial | 74 |
| reposo declarado | 1 686 |
| gate activo | 1 050 |
| countdown de baja actividad | 600 |

Durante las 1 050 ventanas de gate activo:

- 650 tenían referencia operativamente activa en los cuatro motores;
- 400 tenían tres motores activos y M1 inactivo;
- 400/4 200 componentes gate-activo = 9.523810%, menor que el 10% requerido;
- todos esos 400 componentes tenían PWM no cero;
- ninguno cumplía `zeroControlDemand`, porque persistía error de posición.

Por ello la asociación no demuestra que un gate por motor deba anular esas
acciones: pueden ser corrección de posición.

Fuera de gate activo sí permanece un problema del actor:

| Contexto | Componentes | PWM no cero | demanda de control cero | PWM no cero dentro de demanda cero |
|---|---:|---:|---:|---:|
| reposo inicial | 296 | 100% | 100% | 100% |
| reposo declarado | 6 744 | 99.8221% | 26.2159% | 100% |
| countdown | 2 400 | 100% | 0% | no aplicable |

Esto no se atribuye a la discontinuidad `0->64`: la mayoría de las acciones
está lejos de `theta`.

### 6.3 Seguridad

Se registraron 6 704 componentes motor-paso con intervención; cada contador
valió uno, por lo que también suman 6 704 muestras de intervención. No son 6 704
pasos temporales independientes.

| Motor | Total | `outwardBoundary` | interior | fracción outward |
|---:|---:|---:|---:|---:|
| 1 | 1 755 | 1 730 | 25 | 98.5755% |
| 2 | 1 543 | 1 518 | 25 | 98.3798% |
| 3 | 1 701 | 1 697 | 4 | 99.7648% |
| 4 | 1 705 | 1 705 | 0 | 100% |
| total | 6 704 | 6 650 | 54 | 99.1945% |

No hubo casos `boundaryOther`. Las 54 muestras interiores representan 0.8055%.
En los 24 episodios `steadyRest`, las 720 intervenciones fueron
`outwardBoundary` y coincidieron con demanda de control cero. La evidencia
apunta a comandos del actor que la seguridad está bloqueando correctamente; no
justifica debilitar la protección.

### 6.4 Regla de selección

```text
salto canónico confirmado                    = true
contrafactuales cercanos solo 0<->64         = true
exposición cercana observada                 = 0.0015395894
mínimo para quantizerPriority                = 0.01
referencia inactiva durante gate activo      = 0.0952380952
mínimo para gatePriority                     = 0.10
PWM no cero condicionado a lo anterior       = 1.0
resultado                                    = noAblationSupported
```

No se redondeó 9.5238% a 10% ni se relajó el gate después de observarlo.

### 6.5 Rutas y hashes

Directorio canónico:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7p_artifacts\stage7p_final\2026-08-29_23-15-59-803
```

| Artefacto | SHA-256 |
|---|---|
| `manifest.json` | `9B6BC4198AE8B36C4BE062E51D82BE7709870D2DBD3C74A5F7FE68AB015034D9` |
| `stage7p_results.mat` | `58E7E74A460322CAEB0B5E7F57449CB816644E5FEA3E816BC458AED15D7DA1B5` |
| `interface_components.csv` | `E8030B6B2C9BC5577FEBA3441D3EF99B1794C7ABAE8AB926B68D90326B683CBF` |
| `canonical_sweep.csv` | `E330FCE1F16E1E2647C14353A3F3F990BF78FE8AB0C3AA68DD18B602DFC3AEB1` |
| `gate_motor_summary.csv` | `E57E788B898C119040D8741319077AD90BB29A8CF65E2D02800D4A1A412F67CC` |
| `safety_context_summary.csv` | `91A06640DFA8D24023A2E6405684DDB54E2EC37F44D4BE4583B4A082549AC78D` |
| `decision_audit.csv` | `15B6E2CF2684511BA2CF7C2E51F8F3BC193F22BAC8BBA710CD3B9BFA8E2CDF49` |
| `input_inventory.csv` | `76954B1AC789C9948148B07716806DA6D0259E72D6A8C73F8C9604D0ECBCE9A6` |

El manifiesto contiene hashes de los 18 artefactos. El comando completo está en
`reproducible_command.txt`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- El 1% y 10% son gates de selección preinscritos, no umbrales clínicos.
- `noAblationSupported` no valida `baselineQuantized`; solo rechaza priorizar su
  discontinuidad de activación con este corpus.
- El 31.2170% de componentes en PWM 64 muestra ocupación del nivel mínimo, pero
  casi toda está lejos de `theta`; cambiar niveles sería una hipótesis distinta.
- La referencia de velocidad cero no implica demanda de control cero. Se exigió
  además error de posición `<=1e-4`.
- Las intervenciones interiores están clasificadas respecto del encoder visible
  antes de la acción; no prueban por sí solas un defecto de seguridad.
- La política state60 todavía produce PWM no cero en reposo y demanda cero. La
  causa no queda resuelta por 7P.
- Agent7250 quedó intacto con SHA-256
  `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.

## 8. Confirmación de hardware

No se usó hardware, Myo, guante, puertos COM ni PWM físico. No se construyó
`Env`, no se ejecutó simulador, planta, DTW o entrenamiento. `simMotors=true`
solo describe la configuración congelada de los episodios leídos.

## 9. Commits de la etapa

```text
c263a5ae Preregister Stage 7P interface diagnostic
1f7a9249 Add Stage 7P offline interface diagnostic
812b3cf1 Align Stage 7P with Stage 7O manifest schema
376db956 Validate frozen Stage 7P safety contract
d31ad04f Stratify Stage 7P safety evidence by gate context
22df376f Clarify Stage 7P safety component counts
```

El informe final se añadirá en un commit separado. No se hizo push: la orden de
esta etapa no lo autorizó.

## 10. Propuesta precisa para la siguiente etapa — no ejecutada

Proponer **ETAPA 7Q: atribución offline de comandos outward-boundary y demanda
cero**, sin cambiar conducta:

1. mantener `intentMarkov60` y congelar Agent200;
2. usar las 2 064 componentes de reposo inicial/declarado con
   `zeroControlDemand`, todas con PWM no cero, como conjunto primario;
3. separar por bloques observables del estado —EMG, posición, delta de encoder,
   acción efectiva previa, `q_ref` y `v_ref`— mediante gradientes del actor y
   comparaciones entre estados reales, sin crear híbridos no causales;
4. confirmar en Agent50/100/150/200 si los comandos hacia fuera y su asociación
   con `u_eff,t-1` son estables o aparecen tarde en el entrenamiento;
5. no modificar la seguridad; solo si la evidencia identifica una causa única,
   preinscribir después una ablación offline aguas arriba.

No se autoriza smoke de 200 episodios, piloto de 2 000 ni campaña. ETAPA 7Q no se
ejecutó durante 7P.
