# ETAPA 6C — comparación emparejada Agent200/control P

Fecha de ejecución: 2026-08-26.

## 1. Resultado de la etapa

**PASS** para el objetivo diagnóstico de ETAPA 6C. El resultado no cambia el
estado experimental de la política: el gate de ETAPA 6 continúa fallido y no se
autoriza piloto, campaña, DTW ni hardware.

Se compararon 50 episodios de aceptación y 24 de reposo. Agent200 se trató como
evidencia inmutable: el launcher solo leyó sus episodios guardados; no cargó el
checkpoint ni invocó inferencia o entrenamiento. El controlador convencional P
se simuló desde la misma posición inicial de cada episodio usando exactamente
las referencias `q_ref` y `v_ref` visibles para Agent200.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- SHA de entrada de ETAPA 6C: `b938e676c007f6e67a6ddd250ae0782184c7a71a`.
- SHA de código usado por la corrida definitiva:
  `c0398c89c941578e8925a7b172d8b6add242b1b5`.
- `main` no fue modificado.
- La corrida registró `gitTrackedDirty=false`. El único estado ajeno fue el
  archivo no rastreado preexistente `matlab_code.zip`; se preservó y excluyó de
  los commits.

## 3. Archivos creados y modificados

Creados:

- `matlab_code/src/evaluation/evaluateNoGloveStage6cMatchedController.m`
- `matlab_code/tests/no_glove/testNoGloveStage6cMatchedController.m`
- `matlab_code/workflows/published/run_no_glove_stage6c_matched_controller.m`
- `docs/no_glove_experiment/06c_matched_controller_comparison.md`

Modificado:

- `matlab_code/workflows/published/README.md`

No se modificaron `Env`, reward, decodificador, cuantizador, simulador,
`encoder2Flex`, WMoos, configuración global ni checkpoints.

## 4. Decisiones técnicas y justificación

1. Se reutilizó el controlador P validado en ETAPA 5: `kp=1.5`, `kd=0`,
   tolerancias de posición/velocidad `0.01/0.03` y `maxAction=64/255`. Se mantuvo
   `baselineQuantized`. El límite conservador forma parte explícita de la fuente
   convencional; por ello esta prueba no equivale a comparar dos controladores
   con igual autoridad máxima.
2. No se volvieron a ejecutar `Env` ni el decodificador para construir las
   referencias. La dinámica de cada controlador podría cambiar el estado final
   de un episodio y, por la inicialización desde encoder, alterar el `q_ref` del
   siguiente. Reproducir las referencias publicadas elimina esa confusión.
3. Para cada episodio, ambos brazos comparten `q_ref(t)`, `v_ref(t)` y posición
   inicial exactamente. Solo el brazo P invoca el simulador; la traza Agent200
   existente constituye el brazo observado.
4. El replay conserva periodo `0.2 s`, muestreo interno `0.14 s`, cuantización,
   límites de posición `[0,1]^4` y `clipTrajectoryOutput`.
5. Las métricas se calcularon con la convención publicada. En particular,
   `deltaActionL2` es la media por episodio de la suma por motor de
   `diff(u_eff).^2`, sin introducir el salto ficticio desde cero. Esto reprodujo
   exactamente `0.167320743303857` para Agent200.
6. El evaluador falla cerrado ante hardware habilitado, campos ausentes,
   seguridad distinta, datos no finitos o desalineación temporal/referencial.
7. Los SHA-256 de los 74 episodios fuente se calcularon antes y después y fueron
   idénticos. No se afirma una causa raíz única a partir de las diferencias.

## 5. Comandos/pruebas ejecutados y resultados exactos

Análisis estático y suite completa:

```matlab
cd('C:/Users/Cesarbmm/ProtesisPracticas_no_glove_intent_control/EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
a = checkcode('src/evaluation/evaluateNoGloveStage6cMatchedController.m','-id');
b = checkcode('workflows/published/run_no_glove_stage6c_matched_controller.m','-id');
assert(isempty(a));
assert(isempty(b));
results = runtests('tests/no_glove','IncludeSubfolders',true);
assert(all([results.Passed]));
```

Resultado: `checkcode` 0 observaciones en ambos archivos; `55/55` pruebas
pasaron, `0` fallaron y `0` quedaron incompletas. Las cinco pruebas nuevas
cubren emparejamiento exacto, replay determinista, rechazo de seguridad
incompatible, rechazo de perfil de hardware y esquema fuente incompleto.

Corrida definitiva:

```matlab
cd('C:\Users\Cesarbmm\ProtesisPracticas_no_glove_intent_control\EMG_Prosthesis_TD3\matlab_code');
addpath(genpath(pwd));
run_no_glove_stage6c_matched_controller(struct( ...
    'stage6RunRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/position_safety_smoke/2026-08-26_02-06-38-015', ...
    'resultsRoot', ...
    'C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage6_artifacts/stage6c_final'));
```

Resultado: `ETAPA 6C MATCHED CONTROLLER PASS`. Pruebas de entrada del launcher:
`5/5`. MATLAB: `R2023b Update 11`.

Verificaciones adicionales:

- `git diff --check`: sin errores.
- Checkpoint Agent200: SHA-256
  `C26C468B146FA93776A336A61F90979367C258A0B906633E40CD81B9045CC973`,
  sin cambios.
- Agent7250 canónico: SHA-256
  `0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`,
  sin carga ni modificación.
- Simulador interno: SHA-256
  `1BC97D0934C7DE9E53E9147DDFD8EF5748E4BC882CE61ACC7577AB149C221742`,
  sin modificación.

## 6. Métricas y artefactos generados

### Aceptación, 50 episodios

| Métrica | Agent200 | P emparejado | Cambio P vs Agent200 |
|---|---:|---:|---:|
| `trackingMse` | 0.075152412 | 0.033790824 | -55.04% |
| `trackingMae` | 0.165273319 | 0.112553904 | -31.90% |
| `velocityMse` | 0.383398803 | 0.420108440 | +9.57% |
| `actionL2` | 0.306535002 | 0.033044542 | -89.22% |
| `deltaActionL2` | 0.167320743 | 0.215744714 | +28.94% |
| `saturationFraction` | 0.110655738 | 0 | -100% |
| intervenciones de seguridad | 6000 | 450 | -92.50% |
| flags funcionales M2 | 25 | 25 | sin cambio |
| flags funcionales M1/M3/M4 | 100 | 50 | -50% |
| violaciones de posición | 0 | 0 | sin cambio |

Por motor, el P obtuvo MSE `[0.002601591, 0.048371707, 0.075136264,
0.009053735]`. Los flags funcionales por motor fueron `[0,25,25,25]`; en P
son flags de dirección, no de inmovilidad. Sus comandos nunca se opusieron al
error `q_ref-q`, aunque se opusieron a `v_ref` en parte de la trayectoria. Esta
diferencia confirma que posición, velocidad y régimen de movimiento deben
analizarse por separado.

### Reposo, 24 episodios

| Métrica | Agent200 | P emparejado |
|---|---:|---:|
| `trackingMse` | 0.069452113 | 0 |
| `trackingMae` | 0.133157424 | 0 |
| `actionL2` | 0.243631552 | 0 |
| `deltaActionL2` | 0.003152451 | 0 |
| `saturationFraction` | 0.008333333 | 0 |
| intervenciones de seguridad | 876 | 0 |

En este corpus sintético de reposo, `q_ref` se mantiene en la posición inicial.
El P produce cero demanda y cero movimiento; esto demuestra que la actividad de
Agent200 en esas trazas no es necesaria para mantener esa referencia. No valida
por sí solo reposo con Myo real.

Emparejamiento y trazabilidad:

- episodios: 50 aceptación + 24 reposo;
- componentes motor-paso por brazo: 12 200 aceptación + 1 440 reposo;
- error máximo en `q_ref`: `0`;
- error máximo en `v_ref`: `0`;
- error máximo de posición inicial: `0`;
- error máximo temporal de la fuente: `0`;
- hashes fuente preservados: `true`.

Ruta de artefactos:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage6_artifacts\stage6c_final\2026-08-26_03-14-26-280`

Artefactos principales:

- `manifest.json`: SHA-256
  `DCF6D777D23A89E3621B197E4F0D5FC32B4AD2C3E38E3C1418ACC13A15AFCEEE`.
- `stage6c_results.mat`: SHA-256
  `E2A17C795AD388DAD924421CE1E1CD077325BACC63160AA3A9921EB695631329`.
- `comparison_summary.csv`: SHA-256
  `2433A14CEA9849768F311A97C9632FD4D723E3930160CEEE84006DD2EB169A1D`.
- `motor_summary.csv`: SHA-256
  `F6AD1761B92BD7D70CF2A182DA71431E8D7DF9FDD3D83A7160A147AA11B90050`.
- `source_episode_hashes.csv`: SHA-256
  `34A73B5B58FE6DC54DEA7E2A3251966568355D96F066CAAFD2E431B2D39FB78B`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- El P usa un tope de 64 PWM y Agent200 puede ordenar hasta 255. La menor
  saturación/esfuerzo no debe atribuirse solo a la ley P; el límite forma parte
  de la intervención documentada.
- `velocityMse` y `deltaActionL2` empeoraron con P. No hay una mejora uniforme.
- Los 25 flags de Motor 2 persisten; bajo P cambian de inmovilidad a dirección
  respecto de `v_ref`. Motor 3 conserva 25 flags y concentra las 450
  intervenciones de seguridad del P. No se autoriza declarar resuelta la
  regresión funcional.
- Una orden P coherente con `q_ref-q` puede oponerse temporalmente a `v_ref` para
  corregir error acumulado. El flag de dirección respecto de velocidad no es
  equivalente a error de posición ni establece por sí solo un fallo de signo.
- El replay comienza cada brazo desde la misma posición, pero no reconstruye una
  secuencia acoplada de resets entre episodios. Esa decisión es necesaria para
  el emparejamiento exacto y queda limitada a este diagnóstico.
- El corpus y la calibración son sintéticos. No se extrapola a Myo real.
- No se midió corriente eléctrica. Los datos son comandos y posiciones
  simuladas.
- No se calculó DTW ni se midió aún el retardo por régimen según ETAPA 7.

Conclusión acotada: Agent200 explica la actividad innecesaria de reposo y una
parte sustancial del esfuerzo/saturación observados bajo este replay. Sin
embargo, los flags de Motor 2, los flags direccionales M2/M3/M4 y el aumento de
`velocityMse`/`deltaActionL2` demuestran que no existe evidencia para una causa
raíz única.

## 8. Confirmación explícita de hardware

No se activó hardware, Myo, guante, puertos COM, PWM físico ni conexiones reales.
`simMotors=true`. Solo el brazo convencional invocó `SimController`; Agent200 no
fue cargado. El manifiesto registra `hardwareUsed=false`.

## 9. Commits de la etapa

- Código, pruebas y launcher:
  `c0398c89c941578e8925a7b172d8b6add242b1b5`
  (`feat: add matched stage6 controller comparison`).
- El commit documental se registra al cerrar este informe.

No se hizo push ni se abrió PR.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

La siguiente orden propuesta es `CONTINUAR ETAPA 7`, exclusivamente offline y
sin cambiar estado, reward, política, referencia, cuantización o simulador:

1. estratificar las trazas emparejadas por motor, apertura/cierre,
   interior/borde y signo de `q_ref-q` frente a signo de `v_ref`;
2. medir MSE sin desplazamiento, MSE con retardos discretos y correlación por
   régimen, conservando el error del extremo actual;
3. calcular DTW restringido solo como métrica, con una ruta multivariable
   compartida para los cuatro motores, métrica `squared` y normalización por la
   longitud real del camino;
4. cuantificar por separado reducción por alineación y lag perdonado;
5. decidir si los flags M2/M3/M4 corresponden a retardo fijo, conflicto entre
   posición y velocidad, límite o respuesta de planta;
6. si domina un lag fijo, recomendar primero compensación causal o referencia
   filtrada; no autorizar ETAPA 8 ni introducir DTW en reward sin pasar el gate
   offline.

ETAPA 7 no se ejecutó.
