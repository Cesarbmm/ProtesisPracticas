# ETAPA 6A — ablación correctiva de límites de posición

Fecha de cierre: 2026-08-26

## 1. Resultado de la etapa

`PARTIAL`.

La recomendación eliminó las salidas de posición normalizada fuera de `[0,1]`
en entrenamiento, aceptación y reposo. Sin embargo, no pasó el gate completo de
ETAPA 6: persistieron flags funcionales en Motor 2 y en los demás motores, y la
política produjo saturación distinta de cero durante reposo calibrado. Por ello
la recomendación no se considera exitosa para avanzar y ETAPA 7 no se ejecutó.

Este resultado demuestra el efecto determinista del límite en simulación. No
demuestra que las órdenes de la política sean funcionales ni identifica una
causa raíz única.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- ETAPA 6 original: `62748112a064b5a0ad6ba6756d04c2d22b402753`.
- Implementación ejecutada en el smoke:
  `ae8b264e7555b0477e036db3c8238eb0c23fc10a`.
- El ZIP local ajeno `matlab_code.zip` permaneció sin seguimiento y sin cambios.
  Por ese archivo preservado, los manifiestos indican `gitDirty=true`, aunque
  `git diff --quiet` confirmó que el árbol de archivos rastreados estaba limpio.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/runtime/buildNoGloveSimulationPositionSafety.m`
- `matlab_code/src/safety/limitSimulationPosition.m`
- `matlab_code/tests/no_glove/testSimulationPositionSafety.m`
- `matlab_code/workflows/published/run_no_glove_stage6_position_safety_smoke.m`
- `docs/no_glove_experiment/06a_position_safety_ablation.md`

### Modificados

- `matlab_code/config/configurables.m`
- `matlab_code/src/@SimController/SimController.m`
- `matlab_code/src/@Env/Env.m`
- `matlab_code/src/@Env/reset.m`
- `matlab_code/src/@Env/step.m`
- `matlab_code/src/@Env/saveEpisode.m`
- `matlab_code/src/evaluation/analyzeNoGloveStage6Evaluation.m`
- `matlab_code/src/runtime/buildNoGloveStage6Override.m`
- `matlab_code/tests/no_glove/testNoGloveStage6Training.m`
- `matlab_code/workflows/published/run_no_glove_stage6_training.m`

No se modificaron `prosthesis_simulator.m`, `encoder2Flex.m`, el checkpoint o la
configuración canónica de Agent7250, el decoder, el target, `intentMarkov60`, la
reward, `baselineQuantized` ni la dinámica interna de la planta.

## 4. Decisiones técnicas y justificación

La única variable experimental fue una capa de posición posterior a la
trayectoria de `prosthesis_simulator` y anterior a la exposición del encoder por
`SimController`. Sus límites normalizados por motor son `[0,1]`, convertidos a
encoder mediante `[26500,11500,8500,9000]`.

La configuración global queda explícitamente desactivada. Solo el perfil
correctivo la activa mediante `setConfigurablesOverride`; además, se rechaza su
activación si `simMotors=false`. Una prueba compara ambos perfiles, después de
retirar este único campo, y confirma igualdad estructural.

La capa no depende de la reward. Los NaN e Inf no se convierten en números
válidos ni se ocultan: esta ablación solo limita posiciones finitas. Cada muestra
motor de trayectoria limitada se cuenta y se guarda por paso y por episodio.

La frecuencia de intervención fue alta, no excepcional: 28895 componentes en
entrenamiento, 6000 en aceptación y 876 en reposo. Por tanto el resultado debe
interpretarse como una planta observada con borde determinista, no como una
política que haya aprendido a respetar el límite por sí sola.

## 5. Comandos/pruebas ejecutados y resultados exactos

Pruebas específicas tras añadir la integración con `Env`:

```matlab
runtests('tests/no_glove/testNoGloveStage6Training.m')
```

Resultado: `8/8 PASS`, 0 fallos y 0 incompletas.

Suite completa ejecutada dentro del launcher final:

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado: `45/45 PASS`, 0 fallos y 0 incompletas. Incluye identidad exacta con
la capa desactivada, clipping/conteo por motor, preservación de NaN/Inf para el
detector existente, rechazo del perfil físico e integración/persistencia en
`Env`.

`checkcode` sobre los archivos tocados produjo dos avisos en líneas históricas
no modificadas (`IFBDUP` en `configurables.m:147` y `MANU` en `Env.m:397`) y cero
avisos en las líneas añadidas. `git diff --check` no reportó errores.

Smoke correctivo:

```matlab
run_no_glove_stage6_position_safety_smoke(struct( ...
    'resultsRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/position_safety_smoke'))
```

Resultado: 200 episodios, seed 11, 12200 pasos, checkpoints 50/100/150/200,
50 simulaciones de aceptación, 24 de reposo y gate `PARTIAL`.

Regresión histórica, exclusivamente en simulación:

```matlab
runCheckpointTest(getAgent7250CheckpointPath(),50,false,struct( ...
    'resultsRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/agent7250_position_safety_regression'))
```

Resultado: 50/50 episodios completados, adaptador desactivado en 50/50 y cero
intervenciones. Las cinco métricas agregadas reproducen el benchmark canónico.
No se usa igualdad episodio-a-episodio entre ejecuciones históricas porque
`randomSeed=NaN` y el orden de episodios no queda fijado en ese launcher.

## 6. Métricas y artefactos generados

### Gate final

| Check | Resultado | Evidencia |
|---|---|---:|
| finitud | PASS | 0 NaN/Inf |
| límites de posición | PASS | 0 episodios en entrenamiento/aceptación/reposo |
| saturación de aceptación | PASS | 0.110656 <= 0.196043 |
| deltaActionL2 | PASS | 0.167321 <= 0.257108 |
| Motor 2 | FAIL | 25 flags, requerido 0 |
| M1/M3/M4 | FAIL | 100 flags, requerido 0 |
| saturación en reposo | FAIL | 0.008333, requerido 0 |
| activación falsa del decoder | PASS | 0/96 ventanas |

### Entrenamiento

| Métrica | Valor |
|---|---:|
| episodios / pasos | 200 / 12200 |
| reward medio | -9.871352 |
| reward final | -6.809279 |
| average reward final | -5.862774 |
| mejor reward | -1.535876, episodio 183 |
| trackingMSE | 0.151485 |
| trackingMAE | 0.240319 |
| velocityMSE | 0.335987 |
| actionL2 | 0.477798 |
| deltaActionL2 | 0.416392 |
| saturationFraction | 0.222459 |
| episodios con salida de posición | 0/200 |
| intervenciones de seguridad | 28895 |

Intervenciones por motor en entrenamiento: `[7601,4049,11474,5771]`.

### Aceptación de Agent200

| Métrica | Valor |
|---|---:|
| trackingMSE | 0.075152 |
| trackingMAE | 0.165273 |
| velocityMSE | 0.383399 |
| actionL2 | 0.306535 |
| deltaActionL2 | 0.167321 |
| saturationFraction | 0.110656 |
| episodios con salida de posición | 0/50 |
| intervenciones de seguridad | 6000 |

Por motor:

- intervenciones: `[1525,875,1750,1850]`;
- dirección incorrecta: `[0,0,25,0]`;
- ausencia de movimiento: `[25,25,25,25]`;
- flags funcionales, con solapamiento: `[25,25,50,25]`;
- trackingMSE: `[0.012670,0.036273,0.107179,0.144488]`;
- saturationFraction: `[0,0.442623,0,0]`.

La saturación indicada es la fracción de componentes motor-paso con
`abs(effectiveAction)>=0.95`; no significa que los cuatro motores estén al
máximo durante esa fracción del tiempo.

### Comparación controlada con el smoke original

| Métrica | ETAPA 6 original | Con límite |
|---|---:|---:|
| violaciones posición entrenamiento | 200 | 0 |
| violaciones posición aceptación | 50 | 0 |
| trackingMSE aceptación | 0.028423 | 0.075152 |
| deltaActionL2 aceptación | 0.130050 | 0.167321 |
| saturationFraction aceptación | 0.020492 | 0.110656 |
| flags Motor 2 | 25 | 25 |
| flags otros motores | 150 | 100 |
| saturación reposo | 0 | 0.008333 |

Solo cambió la capa de límites, pero el entrenamiento estocástico produjo otra
política; la tabla no atribuye todos los cambios métricos a una causa única.

### Artefactos

- Raíz del smoke:
  `C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/position_safety_smoke/2026-08-26_02-06-38-015`
- SHA256 de `manifest.json`:
  `F27105A62DE2F1EF02B3A0E419A126E0DA6EFD105C6E8ED649D3A3872B9AC0FE`
- SHA256 de `stage6_results.mat`:
  `540597BF9F2986B863983D1BB0F41941E46411035BFA3D9BB4A11F090DBF881F`
- SHA256 de Agent200:
  `C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973`
- Checkpoints 50/100/150/200:
  `B456E634D0AC0099EAF0D3DE6599E733E184EB67F3BD4D8B1FDF9BE6F04654BA`,
  `56AB5FD030C5D27E46C671E13D5FB2C8B921E6C5C8B4A36B2C6982FAD04061A3`,
  `93D32E725F6D1C0DA877928CB1CF4B5704F9C0DC9D23543DDA0572BDCB0DC814`
  y `C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973`.

### Agent7250 congelado

Las métricas reproducidas en 50 simulaciones fueron:

- trackingMSE `0.0430451756630602`;
- trackingMAE `0.160336436626161`;
- actionL2 `0.596444143502275`;
- saturationFraction `0.392086247086247`;
- deltaActionL2 `0.321385118610724`.

Checksums preservados:

- checkpoint: `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`;
- configuración: `F1DA3E89C22281DB8A256F5B18067EC4E2E9AD7119D283887C476C83F377C1B7`;
- `prosthesis_simulator.m`: `1BC97D0934C7DE9E53E9147DDFD8EF5748E4BC882CE61ACC7577AB149C221742`;
- `encoder2Flex.m`: `4078BA95DD42560B26F2C781A5326733417B7C05B0C47B5514526880D73D9715`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- El clipping impide exponer posiciones inválidas, pero no evita que la política
  ordene persistentemente hacia el límite; la alta intervención lo confirma.
- La política mantuvo 25 flags en Motor 2 y produjo flags en M1, M3 y M4. Los
  logs representan comandos y movimiento simulado, no corriente eléctrica.
- La saturación en reposo reapareció pese a cero activaciones falsas del decoder.
  Esto es evidencia de un fallo del gate, no prueba de una causa raíz única.
- Motor 2 tuvo `saturationFraction=0.442623` en aceptación aunque el agregado de
  cuatro motores pasó el umbral. Debe conservarse la vista por motor.
- La capa completa de seguridad aún no incluye en esta ablación límite PWM por
  fase, DeltaPWM, saturación consecutiva, watchdog, corriente o temperatura.
- El corpus sigue siendo sintético; no valida Myo real ni separabilidad humana.
- Los MSE de intención no son directamente comparables con el MSE del guante.
- El launcher histórico de Agent7250 no fija un orden episodio-a-episodio cuando
  `randomSeed=NaN`; su regresión se verificó por métricas canónicas agregadas.

## 8. Confirmación explícita de que no se usó hardware

No se abrió ningún puerto COM, no se conectó Myo o guante real y no se emitió
PWM físico. El smoke, sus evaluaciones y la regresión de Agent7250 utilizaron
`simMotors=true`, `usePrerecorded=true`, `connect_glove=false` y
`hardwareUsed=false`.

## 9. Commit de la etapa

- Implementación ejecutada: `ae8b264e7555b0477e036db3c8238eb0c23fc10a`,
  `feat: bound simulated positions for no-glove smoke`.
- Este informe se registra en un commit documental separado para mantener el
  SHA ejecutado trazable.
- No se hizo push ni se abrió PR.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

ETAPA 7 queda bloqueada porque la condición solicitada no se cumplió. Antes de
DTW se propone, solo con autorización nueva, una ETAPA 6B diagnóstica y offline
que estratifique las trazas ya generadas por motor, dirección de referencia,
posición en el límite, PWM aplicado y delta de encoder. El objetivo sería
separar tres hipótesis sin cambiar código conductual: orden que empuja contra el
límite, zona muerta/no movimiento y signo de respuesta incorrecto.

Solo después de esa evidencia debería autorizarse una única ablación adicional.
No se propone entrenar piloto 2k, campaña 12k ni ejecutar DTW con el gate actual.
