# ETAPA 6B — diagnóstico offline de borde, comando y respuesta

Fecha de cierre: 2026-08-26

## 1. Resultado de la etapa

`PASS` para el objetivo diagnóstico.

Se analizaron offline las trazas ya publicadas por ETAPA 6A y se separaron
cuantitativamente los mecanismos observables de inmovilidad, dirección y reposo.
El resultado `PASS` significa que el diagnóstico fue reproducible y completo;
la política de Agent200 conserva su gate `FAIL` y no queda autorizada para piloto,
campaña, DTW o hardware.

ETAPA 7 no se ejecutó. No se declara una causa raíz única.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- ETAPA 6A analizada: `ae8b264e7555b0477e036db3c8238eb0c23fc10a`.
- Implementación de ETAPA 6B ejecutada:
  `b707e49f4c0df6ec81f06b5e211fb0a49fdcc39d`.
- `gitTrackedDirty=false` durante la ejecución final.
- El único estado no limpio fue el ZIP local ajeno y preservado
  `matlab_code.zip`, registrado por el manifiesto como archivo sin seguimiento.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/evaluation/analyzeNoGloveStage6BoundaryDiagnostics.m`
- `matlab_code/tests/no_glove/testNoGloveStage6BoundaryDiagnostic.m`
- `matlab_code/workflows/published/run_no_glove_stage6b_boundary_diagnostic.m`
- `docs/no_glove_experiment/06b_boundary_diagnostic.md`

### Modificado

- `matlab_code/workflows/published/README.md`

No se modificaron el entorno, agente, estado, decoder, target, reward,
cuantización, capa de seguridad, simulador, datasets, calibración, Agent7250 ni
los artefactos de ETAPA 6A.

## 4. Decisiones técnicas y justificación

### Contrato causal de cada fila

Cada componente motor-paso usa exclusivamente:

- `stateLog(t)`: encoder, `q_ref` y `v_ref` visibles antes de `action_t`;
- `actionPwmLog(t)`: PWM aplicado por esa acción;
- `trackingPredictionHistory(t)`: encoder leído después de la acción;
- `positionSafetyInterventionLog(t)`: intervención ocurrida durante el paso.

En los 274 episodios, el error máximo entre el encoder posterior y el encoder
del siguiente estado fue exactamente `0`. El error entre `referenceHistory` y
la referencia visible en `stateLog` también fue `0`.

### Umbrales y particiones

- posición: `[0,1]`, tolerancia `1e-9`;
- referencia activa: `abs(v_ref)>=0.005`;
- movimiento: `abs(deltaQ)>=1e-4`;
- error de posición activo: `abs(q_ref-q)>=1e-4`;
- saturación: `abs(effectiveAction)>=0.95`.

La inmovilidad con referencia activa se divide en tres clases mutuamente
exclusivas: borde/intervención, interior con PWM cero e interior con PWM no cero.

Se reportan por separado:

- signo PWM frente a `v_ref`, porque así se definieron los flags funcionales;
- signo PWM frente a `q_ref-q`, porque la reward usada fija `w_v=0`;
- signo del movimiento frente al PWM, para no confundir error de política con
  respuesta de planta;
- `v_ref=0` frente a demanda de control realmente nula, que exige además
  `q_ref-q` dentro de tolerancia.

Los rótulos de hipótesis significan “evidencia observada”, no causalidad probada.

## 5. Comandos/pruebas ejecutados y resultados exactos

Prueba específica:

```matlab
runtests('tests/no_glove/testNoGloveStage6BoundaryDiagnostic.m')
```

Resultado: `5/5 PASS`, 0 fallos y 0 incompletas. Los casos validan la partición
mutuamente exclusiva, la alineación causal y el rechazo de referencia futura,
encoder siguiente desalineado, seguridad desactivada y manifiesto incompatible.

Suite completa no-guante:

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado: `50/50 PASS`, 0 fallos y 0 incompletas.

`checkcode` sobre los tres archivos nuevos: `0` incidencias. `git diff --check`:
sin errores.

Ejecución final:

```matlab
run_no_glove_stage6b_boundary_diagnostic(struct( ...
    'stage6RunRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/' + ...
    'position_safety_smoke/2026-08-26_02-06-38-015', ...
    'resultsRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/' + ...
    'stage6b_final'))
```

Resultado: `PASS`, 200 episodios de entrenamiento, 50 de aceptación, 24 de
reposo y 62440 componentes motor-paso analizados.

Durante el preflight, una primera llamada detectó que un struct de argumentos
name-value se estaba pasando como argumento posicional; se corrigió con
`namedargs2cell`. Una segunda llamada detectó orientación incompatible al
concatenar las líneas del reporte; se corrigió y la tercera, la suite completa y
la ejecución final pasaron. Ninguno de esos intentos invocó agente o simulador.

## 6. Métricas y artefactos generados

### Aceptación: inmovilidad y dirección por motor

| Motor | Pasos con `v_ref` activa | Sin movimiento | Borde/seguridad | Interior PWM=0 | Interior PWM distinto de 0 | PWM opuesto a `v_ref` | PWM opuesto a `q_ref-q` | Respuesta opuesta a PWM |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 650 | 625 | 325 | 0 | 300 | 325 | 2725/2725 | 300 |
| 2 | 1050 | 1025 | 225 | 0 | 800 | 625 | 875/2700 | 100 |
| 3 | 1050 | 925 | 700 | 50 | 175 | 475 | 1550/2725 | 242 |
| 4 | 1050 | 750 | 525 | 37 | 188 | 525 | 1725/2725 | 0 |

Agregado de aceptación:

- inmovilidad con referencia activa: `3325/3800 = 87.500%`;
- de esos casos sin movimiento:
  - borde o seguridad: `1775/3325 = 53.383%`;
  - interior con PWM cero: `87/3325 = 2.617%`;
  - interior con PWM no cero: `1463/3325 = 44.000%`;
- PWM opuesto a `v_ref`: `1950/3800 = 51.316%`;
- PWM opuesto a `q_ref-q`: `6875/10875 = 63.218%`;
- respuesta opuesta al PWM entre pasos con PWM y movimiento no nulos:
  `642/2592 = 24.769%`;
- los 642 casos de respuesta opuesta al PWM ocurrieron en interior y sin
  intervención de seguridad: M1/M2/M3/M4 = `[300,100,242,0]`;
- PWM hacia fuera estando el encoder en un límite:
  `5775/6150 = 93.902%` de los componentes en límite;
- `v_ref` apuntando fuera del límite de su propia referencia: `[0,0,0,0]`.

La última observación respalda la viabilidad geométrica de la referencia en
estas trazas, pero no demuestra por sí sola que el target sea óptimo.

### Estratificación por dirección de `v_ref`

| Motor | Dirección | Pasos | Sin movimiento | Movimiento en dirección incorrecta | PWM con signo opuesto |
|---:|---:|---:|---:|---:|---:|
| 1 | -1 | 200 | 200 | 0 | 100 |
| 1 | +1 | 450 | 425 | 0 | 225 |
| 2 | -1 | 400 | 400 | 0 | 400 |
| 2 | +1 | 650 | 625 | 0 | 225 |
| 3 | -1 | 400 | 350 | 50 | 50 |
| 3 | +1 | 650 | 575 | 50 | 425 |
| 4 | -1 | 400 | 275 | 125 | 200 |
| 4 | +1 | 650 | 475 | 0 | 325 |

`condition_summary.csv` conserva además posición interior/límite, intervención,
dirección PWM, PWM medio, `deltaQ` medio y sus magnitudes para cada estrato.

### Reposo calibrado

En los 1440 componentes de reposo, `v_ref=0`. En 780 componentes tampoco había
error de posición activo, es decir, la demanda conjunta `v_ref/q_ref-q` era cero:

- PWM no cero sin demanda: `780/780 = 100%`;
- por motor: `[192/192,204/204,192/192,192/192]`;
- saturación sin demanda: `[0,12,0,0]`;
- Motor 2: `12/204 = 5.882%` de sus componentes sin demanda;
- PWM hacia fuera en un límite durante reposo: `[180,180,180,324]`.

Esto separa la activación de política de un movimiento correctivo causado por
error de posición. No representa corriente eléctrica medida.

### Entrenamiento

Las intervenciones registradas por motor se reprodujeron exactamente:
`[7601,4049,11474,5771]`, total `28895` componentes de trayectoria interna.
El conteo de muestras internas no debe confundirse con número de pasos.

### Artefactos

Raíz final:

`C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/stage6b_final/2026-08-26_02-53-42-593`

- `manifest.json`:
  `A1FCF49EB176CCFF862CB55392BE79CE3005F80EEF7EE78B7E6C34E145B5AF4A`
- `stage6b_results.mat`:
  `C8E94291686D294F08D94B774D1807A31497A248B8545BE813D46CDC8C14E7FA`
- `component_diagnostics.csv`:
  `6BBC847A27D7B84E022E352D3D76A38280D04B25794F835521B78F0D4A1DB362`
- `motor_summary.csv`:
  `26FDC468BFB93B9D1A74B12E996C96322F263EFC38B8C2D5B6BF68B0BE5EDC23`
- `condition_summary.csv`:
  `841AFFFCFB2530759361ADBABA86CA21E7CCB6465A728E5E86ACC9356307F520`
- `hypothesis_evidence.csv`:
  `10037410BF05E3E2715983D76C6C931DDD46CDF6F560BB3F466556AC180C0D19`

## 7. Riesgos, supuestos y cuestiones no resueltas

- La evidencia procede de un único seed, Agent200 y corpus sintético.
- El límite explica aproximadamente la mitad de la inmovilidad activa, pero no
  la inmovilidad interior con PWM no cero.
- La zona muerta PWM cero representa solo `2.617%` de la inmovilidad de
  aceptación; no aparece como mecanismo dominante en estas trazas.
- La respuesta opuesta al PWM en interior muestra que no basta con atribuir los
  flags a la política. No demuestra que un simple flip fijo por motor sea válido.
- El signo respecto de `v_ref` y respecto de `q_ref-q` no es equivalente; ambos
  se conservaron porque el gate usa el primero y la reward con `w_v=0` prioriza
  el segundo.
- `v_ref=0` no se trató automáticamente como reposo sin demanda; también se
  comprobó el error de posición.
- Los datos no identifican retardo como mecanismo dominante y no justifican DTW.
- No se midieron corriente, temperatura, fuerza ni estado mecánico físico.

## 8. Confirmación explícita de que no se usó hardware

ETAPA 6B no cargó agente, no entrenó, no creó `Env`, no invocó `SimController`,
no ejecutó PWM y no calculó DTW. Solo leyó archivos `.mat` existentes. No se
abrieron puertos COM ni se conectó Myo, guante o prótesis real.

## 9. Commit de la etapa

- Implementación ejecutada: `b707e49f4c0df6ec81f06b5e211fb0a49fdcc39d`,
  `feat: add offline stage6 boundary diagnostics`.
- Este informe se registra en un commit documental separado para conservar el
  SHA exacto de ejecución.
- No se hizo push ni se abrió PR.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No se recomienda ETAPA 7. Se propone, solo con nueva autorización, una ETAPA 6C
de comparación cerrada y emparejada entre Agent200 y el controlador convencional
P/PD, usando exactamente el mismo corpus EMG, `q_ref`, seguridad, cuantización,
semillas y presupuesto de episodios.

Esta comparación cambiaría únicamente la fuente del comando y permitiría aislar:

- si la inmovilidad interior y el signo incorrecto pertenecen principalmente a
  la política TD3;
- si persisten con un controlador explícitamente alineado a `q_ref-q`, lo que
  trasladaría la prioridad al contrato signo/planta antes de otro entrenamiento.

No debe implementarse un flip fijo, watchdog adicional, nueva reward, DTW o
reentrenamiento hasta aprobar primero esa comparación emparejada.
