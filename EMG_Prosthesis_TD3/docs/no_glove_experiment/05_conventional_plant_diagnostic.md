# ETAPA 5 — Baseline convencional y diagnóstico de planta

Fecha de cierre: 2026-08-25

## 1. Resultado de la etapa

`PASS` para el objetivo de medición: se obtuvo un baseline P cuantizado
reproducible y una tabla de planta por motor, posición inicial y dirección sin
modificar el simulador ni `encoder2Flex`.

El PASS significa que el diagnóstico es completo, finito, trazable y repetible;
no significa que la planta o el baseline hayan pasado un gate de control. Se
detectaron dos flags funcionales en Motor 2 y cuatro en Motor 3. Los hallazgos se
conservaron, no se corrigieron mediante calibraciones silenciosas.

No se entrenó ni cargó un agente y no se ejecutó hardware.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Padre de ETAPA 5 / commit de ETAPA 4:
  `5eb79c2924b434cd6dc45129e5832e55bba79aad`.
- El SHA actual de ETAPA 5 es el commit que contiene este documento. El launcher
  post-commit lo resuelve y registra mediante `git rev-parse HEAD`.

Agent7250 permanece congelado. No fue punto de partida del controlador
convencional y no se modificaron sus archivos.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/controllers/quantizeBaselineAction.m`
- `matlab_code/src/controllers/quantizedIntentPdController.m`
- `matlab_code/src/evaluation/evaluateNoGloveStage5Plant.m`
- `matlab_code/src/runtime/buildNoGloveStage5Override.m`
- `matlab_code/tests/no_glove/testConventionalPlantDiagnostic.m`
- `matlab_code/workflows/published/run_no_glove_stage5_plant_diagnostic.m`
- `docs/no_glove_experiment/05_conventional_plant_diagnostic.md`

### Modificado

- `matlab_code/workflows/published/README.md`

No se modificaron `SimController.m`, `prosthesis_simulator.m`, `fit_C2.mat`,
`pattern_curve.mat`, `encoder2Flex.m`, `Env`, reward, target, estado o interfaz
PWM histórica. El ZIP local ajeno se preservó fuera del commit.

## 4. Decisiones técnicas y justificación

### Baseline P/PD explícito

`quantizedIntentPdController` implementa:

```text
u_raw = Kp .* (q_ref-q) + Kd .* (v_ref-v)
```

seguido por tolerancia, límite de acción y `baselineQuantized`. El perfil inicial
es deliberadamente conservador:

| Parámetro | Valor |
|---|---:|
| tipo | `P` |
| `Kp` | 1.50 por motor |
| `Kd` | 0 |
| acción máxima | `64/255` |
| tolerancia de posición | 0.01 |
| tolerancia de velocidad | 0.03 |

La implementación admite un perfil PD posterior con `Kd>0`, pero esta etapa no
mezcla la medición inicial con una segunda sintonía. El cap hace que el baseline
use como máximo PWM 64 y evita confundir un diagnóstico de baja acción con una
saturación impuesta por el controlador.

### Cobertura de planta abierta

Se ejecutaron 112 barridos:

```text
2 posiciones × 4 motores × 2 direcciones × 7 niveles PWM
```

Posiciones: home e intermedia normalizada 0.5. Niveles absolutos: 64, 96, 128,
160, 192, 224 y 255. Cada escalón dura 2 s y usa la planta estática vigente con
periodo nominal 0.14 s.

Se midieron movimiento, tiempo hasta superar 0.005 normalizado, ganancia,
velocidad, saturación de comando, contacto/salida de límites, consistencia de
signo y movimiento cruzado.

El tiempo observado mínimo es `2/14 = 0.142857142857143 s`. Por ello el reporte
no afirma un tiempo muerto submuestra: la estimación está limitada por la
resolución del probe.

### Cobertura cerrada

Se ejecutaron 32 escenarios:

```text
2 posiciones × 4 motores × 2 perfiles × 2 direcciones
```

Los perfiles fueron escalón de 0.20 y rampa de 0.10 unidades normalizadas/s,
durante 3 s con periodo de control de 0.2 s. Los escalones son estímulos de
identificación, no referencias operativas procedentes del decoder. Las ocho
referencias negativas desde home se ejecutan pero quedan marcadas como
degeneradas por el límite inferior `q=0`; no se incluyen en medias de control.

### `encoder2Flex`

Se reportan dos cantidades diferentes:

1. Residuo de implementación contra una fórmula piecewise independiente con los
   mismos `gap`, `breakLimit` y límites flex: máximo `0`.
2. RMSE entre encoder normalizado y flex convertido/normalizado: cuantifica la
   diferencia entre dos rutas internas, no error contra una medición física.

No se seleccionó ni portó `encoder2FlexVariant` desde la rama diagnóstica.

### Rama `benchmark-motor2-diagnostic`

Se inspeccionaron únicamente los launchers de saneamiento por motor y por
posición inicial. No se portaron offsets, variantes de conversión, rewards,
postprocesado de acciones, calibraciones o agentes. La cobertura home/intermedia
y la revisión de signo se reimplementaron sobre la planta de la rama actual.

## 5. Comandos/pruebas ejecutados y resultados exactos

Pruebas específicas:

```matlab
runtests('tests/no_glove/testConventionalPlantDiagnostic.m')
```

Resultado final: `5/5 PASS`, 0 fallos, 0 incompletas. Una primera ejecución tuvo
4/5 y detectó una concatenación de trazas de distinta longitud dentro del test;
se corrigió la aserción sin cambiar el algoritmo.

Regresión consolidada:

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado: `33/33 PASS`, 0 fallos, 0 incompletas.

Launcher:

```matlab
run_no_glove_stage5_plant_diagnostic(struct( ...
    'seed',11,'resultsRoot','<ruta-de-salida>'))
```

Resultado: `PASS`, 112 trials abiertos, 16 condiciones agregadas, 32 escenarios
cerrados y 24 escenarios cerrados no degenerados.

`checkcode` emitió 0 mensajes para los seis archivos MATLAB nuevos.
`git diff --check` terminó sin errores.

## 6. Métricas y artefactos generados

### Planta abierta por motor

| Motor | zona muerta + home | zona muerta − home | zona muerta + intermedia | zona muerta − intermedia | ganancia + intermedia | ganancia − intermedia | velocidad máx. norm/s |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 64 | 64 | 64 | 64 | 0.224841 | 1.009501 | 2.410157 |
| 2 | 64 | 96 | 64 | 64 | -0.057307 | 1.011379 | 3.979652 |
| 3 | 64 | 96 | 64 | 64 | 0.438009 | 1.050937 | 5.598216 |
| 4 | 64 | 64 | 64 | 64 | 0.353057 | 1.034982 | 4.885093 |

Motor 2 es el único con ganancia media positiva-intermedia de signo negativo. En
total hubo 2 inconsistencias de dirección abiertas y 56/112 trials tocaron o
salieron del rango normalizado `[0,1]`. Esto describe la planta actual; no se
interpreta como corriente física ni se corrigió en esta etapa.

La fracción de trials con comando máximo fue `0.142857`: uno de siete niveles
era PWM 255. No es la métrica componente-paso usada para Agent7250.

### Baseline cerrado por motor

| Motor | MSE | MAE | error final | actionL2 | deltaActionL2 | saturación | flags |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.008076 | 0.068014 | 0.068878 | 0.007874 | 0.009099 | 0 | 0 |
| 2 | 0.048050 | 0.159832 | 0.159140 | 0.011723 | 0.006649 | 0 | 2 |
| 3 | 0.036842 | 0.170896 | 0.218961 | 0.015048 | 0.037795 | 0 | 4 |
| 4 | 0.025337 | 0.131419 | 0.136111 | 0.014523 | 0.038845 | 0 | 0 |

Motor 2 falló los dos cierres positivos desde posición intermedia por dirección
incorrecta. Motor 3 produjo un flag de dirección y cuatro escenarios con salida
de posición; algunos escenarios comparten ambos flags, por eso el conteo
funcional total de Motor 3 es cuatro. M1 y M4 tuvieron cero flags.

El movimiento cruzado máximo fue `0` y el baseline tuvo saturación componente-
paso `0`. No se ocultan regresiones de M1/M3/M4: el problema de M3 queda
registrado explícitamente.

El launcher guarda tablas CSV abiertas/cerradas, tabla específica de Motor 2,
flags, trazas MAT, dos figuras, perfil efectivo, calibración, pruebas, hashes de
fuentes, hashes de artefactos, manifiesto y comando reproducible.

## 7. Riesgos, supuestos y cuestiones no resueltas

- La planta simulada muestra saltos y salidas de `[0,1]`; no debe extrapolarse a
  movimiento físico sin validación separada.
- El retardo solo se resuelve a aproximadamente 0.143 s. No demuestra ausencia de
  una dinámica más rápida o tiempo muerto submuestra.
- El baseline P es deliberadamente conservador y no está sintonizado por motor.
- Motor 2 invierte el cierre desde posición intermedia a PWM 64. Es un hallazgo,
  no una calibración aprobada.
- Motor 3 presenta flags de posición y dirección; una corrección exclusiva de
  Motor 2 ocultaría esta regresión cruzada.
- El RMSE de `encoder2Flex` no tiene ground truth físico.
- La referencia escalón sirve para identificación y no reemplaza la referencia
  mecánicamente viable del decoder.
- No se implementó todavía la capa de seguridad determinista completa.
- No se midió corriente, temperatura o fuerza.
- No se entrenó TD3, no se usó DTW y no se cambiaron rewards.

## 8. Confirmación explícita de que no se usó hardware

Confirmación: no se abrió ningún puerto COM, no se conectó Myo o guante real, no
se emitió PWM físico y no se midió corriente. Todos los comandos se entregaron a
`SimController.prosthesis_simulator` como datos de software. El manifiesto fija
`simMotors=true`, `connectGlove=false`, `hardwareUsed=false`,
`simulatorUsed=true` y `reinforcementLearningUsed=false`.

## 9. Commit de la etapa

Commit autorizado por `continuar etapa 5`.

Mensaje previsto: `feat: add conventional plant diagnostic`.

No se hizo push ni se abrió PR. Después del commit se repiten launcher, suite sin
guante y regresión congelada de Agent7250. El ZIP ajeno no se añadirá al índice.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

ETAPA 6 debe crear un agente TD3 nuevo de 60 entradas sin cargar pesos de
Agent7250. Antes de un piloto de 2000 episodios, debe ejecutar únicamente el
smoke de hasta 200 episodios, seed 11, con `intentMarkov60`, referencia causal,
reward de ETAPA 4 y `baselineQuantized`. Debe conservar y reportar por separado
el baseline P de esta etapa y los flags de planta M2/M3 para no atribuirlos
automáticamente a TD3.

No se ejecutó ninguna parte de ETAPA 6.
