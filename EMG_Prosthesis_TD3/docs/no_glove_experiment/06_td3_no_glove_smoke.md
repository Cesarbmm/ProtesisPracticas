# ETAPA 6 — TD3 sin guante, sin DTW

Fecha de cierre: 2026-08-25

## 1. Resultado de la etapa

`PARTIAL`.

Se creó desde cero un TD3 feedforward de 60 entradas y se completó el smoke
autorizado de 200 episodios, seed 11. El agente, las evaluaciones y todos los
logs fueron finitos. Pasaron los gates de saturación, variación de acción y
reposo, pero fallaron los límites de posición y los flags funcionales por
motor. Por tanto no se ejecutaron el piloto 2k ni la campaña 12k.

El resultado valida la integración reproducible de la nueva política, no su
aceptación funcional. No demuestra separabilidad de EMG humana.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Padre de ETAPA 6 / commit de ETAPA 5:
  `9243989eff1eaf7a57b8c6ee16c53804c17a91e0`.
- El SHA actual será el commit que contiene este informe.

Agent7250 no fue cargado ni usado como inicialización. Su checkpoint se leyó
únicamente como archivo para registrar su checksum de inmutabilidad.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/agents/agentNoGloveIntentTd3.m`
- `matlab_code/src/runtime/buildNoGloveStage6SyntheticCorpus.m`
- `matlab_code/src/runtime/buildNoGloveStage6Override.m`
- `matlab_code/src/evaluation/analyzeNoGloveStage6Evaluation.m`
- `matlab_code/src/evaluation/classifyNoGloveStage6Gate.m`
- `matlab_code/tests/no_glove/testNoGloveStage6Training.m`
- `matlab_code/workflows/published/run_no_glove_stage6_training.m`
- `matlab_code/workflows/published/run_no_glove_stage6_smoke.m`
- `matlab_code/workflows/published/run_no_glove_stage6_pilot.m`
- `matlab_code/workflows/published/run_no_glove_stage6_campaign.m`
- `docs/no_glove_experiment/06_td3_no_glove_smoke.md`

### Modificados

- `matlab_code/agents/load_agent.m`
- `matlab_code/workflows/published/README.md`

No se modificaron `Env`, reward, estado, cuantizador, simulador,
`encoder2Flex`, datasets históricos o Agent7250.

## 4. Decisiones técnicas y justificación

### Agente nuevo y explícito

`td3_no_glove_intent` crea actor y dos críticos feedforward nuevos. El perfil
exige `newTraining=true`, `agentFile=""`, `intentMarkov60`, 60 entradas y
residual deshabilitado con ruta base vacía. El replay buffer comienza vacío.

Se mantuvieron `baselineQuantized` y los hiperparámetros TD3 feedforward
iniciales para no mezclar target, estado, reward y cuantización con otra
ablación.

### Corpus sintético de la misma sesión

El dataset Denis publicado carece de instrucciones de reposo y oposición de
pulgar compatibles con la calibración requerida. Aplicarle silenciosamente la
calibración sintética habría violado el contrato de sesión.

Por ello el smoke usa capturas sintéticas independientes declaradas dentro de
la misma sesión sintética de ETAPA 2:

- 12 capturas para entrenamiento, organizadas como 6x2 episodios;
- 12 capturas independientes para aceptación;
- 6 capturas de reposo estable;
- checksum de calibración
  `9c2ff4aba271c337df076874b5ff7ed08a4a07bcf7970f358c886e05e15e43a2`.

Esta decisión permite probar integración causal y entrenamiento, pero no debe
interpretarse como evidencia sobre Myo real, usuario humano o cuatro DoF
independientes.

### Escalado bloqueado por manifiestos

El smoke está fijado en 200 episodios y seed 11. El piloto requiere un
manifiesto smoke con gate aprobado; la campaña requiere un manifiesto piloto
aprobado. Ningún launcher avanza automáticamente.

## 5. Comandos/pruebas ejecutados y resultados exactos

Pruebas específicas finales:

```matlab
runtests('tests/no_glove/testNoGloveStage6Training.m')
```

Resultado: `6/6 PASS`, 0 fallos, 0 incompletas.

Regresión completa:

```matlab
runtests('tests/no_glove','IncludeSubfolders',true)
```

Resultado previo al smoke final: `38/38 PASS`; tras añadir el test que bloquea
un piloto con smoke fallido, la suite contiene 39 pruebas.

`checkcode` reportó 0 incidencias en los archivos MATLAB nuevos o modificados.
`git diff --check` no reportó errores.

Pre-smoke: un entrenamiento de 2 episodios completó y creó checkpoints nuevos.
Una primera invocación rechazó correctamente un nombre de dataset con extensión
usado como campo de metadata; se corrigió el contrato para usar el stem MATLAB
sin cambiar datos o algoritmo.

Smoke:

```matlab
run_no_glove_stage6_smoke(struct( ...
    'resultsRoot','<ruta-de-salida>'))
```

Resultado reproducido dos veces con métricas agregadas idénticas:
`PARTIAL`, 200 episodios, 12200 pasos, 4 checkpoints y gate falso.

## 6. Métricas y artefactos generados

### Entrenamiento

| Métrica | Valor |
|---|---:|
| episodios / pasos | 200 / 12200 |
| reward medio | -5.7199 |
| reward final | -3.1615 |
| average reward final | -2.4417 |
| mejor reward | -1.0068, episodio 187 |
| trackingMSE | 0.083552 |
| trackingMAE | 0.183890 |
| actionL2 | 0.394485 |
| deltaActionL2 | 0.482923 |
| saturationFraction | 0.127766 |
| episodios con salida de posición | 200/200 |

Salidas de posición por motor durante entrenamiento: `[200,107,129,128]`.
Todos los valores críticos fueron finitos.

### Aceptación del checkpoint final

| Métrica | Valor | Gate |
|---|---:|---|
| trackingMSE | 0.028423 | informativa, target no comparable con guante |
| trackingMAE | 0.110250 | informativa |
| velocityMSE | 0.104950 | informativa |
| actionL2 | 0.281160 | informativa |
| deltaActionL2 | 0.130050 | PASS, máximo 0.257108 |
| saturationFraction | 0.020492 | PASS, máximo 0.196043 |
| episodios con salida de posición | 50/50 | FAIL, requerido 0 |
| flags funcionales Motor 2 | 25 | FAIL, requerido 0 |
| flags funcionales otros motores | 150 | FAIL, requerido 0 |

Por motor en aceptación:

- salida de posición: `[50,25,25,25]`;
- dirección incorrecta: `[33,0,25,50]`;
- flags funcionales con solapamiento: `[50,25,50,50]`;
- trackingMSE: `[0.083736,0.020327,0.002624,0.007005]`;
- saturación: `[0,0.081967,0,0]`.

Los flags funcionales son episode-motor y pueden solaparse; no representan
corriente eléctrica ni fallos físicos medidos.

### Reposo estable

- ventanas offline: 96;
- activación falsa del decoder: `0`;
- saturationFraction de la política: `0`;
- episodios de reposo con salida de posición: `24/24`.

El reposo pasa los gates de activación y saturación, pero no el límite de
posición de la planta simulada.

### Checkpoints reportados, sin selección por mejor resultado

| Episodio | SHA256 del artefacto final smoke |
|---:|---|
| 50 | `FA9304301F3EB90ACE9943F24CBC3A2E14BE77E159D6C076BBE09575540DFA60` |
| 100 | `70D0E00C197E3C914723CBE21AD13138F0A866F773FDA588F4DFFA900A00961A` |
| 150 | `02D9A638152F91C63406B243F35EADCF8DB5F02B84765E8BE21D3C18F3DB906B` |
| 200 | `1E79999F70F9ACC537A063415148ED5E2F08D12E87339D1A690EE53C706C1123` |

El gate usa `Agent200`; no se eligió retrospectivamente el mejor checkpoint.
Los `.mat` incluyen cabeceras de archivo, por lo que el checksum de dos
ejecuciones puede diferir aunque sus métricas y trazas agregadas coincidan.

El launcher guarda corpus, calibración, perfiles, 200 episodios, checkpoints,
evaluaciones de aceptación/reposo, inventario SHA256, distribución, figura de
entrenamiento, manifiesto y comando reproducible fuera del repositorio.

## 7. Riesgos, supuestos y cuestiones no resueltas

- El gate de posición falla antes y después del entrenamiento, coherente con
  las salidas de rango diagnosticadas en ETAPA 5; no se declara una causa raíz
  única.
- La política también produce flags de dirección en M1, M3 y M4. No deben
  ocultarse enfocándose únicamente en Motor 2.
- No existe todavía una capa de seguridad determinista que limite posición y
  DeltaPWM independientemente de la reward.
- El corpus es sintético y no valida distribución Myo, recolocación, OOD o
  separabilidad humana.
- Los MSE de intención no son comparables directamente con el MSE histórico
  del target del guante.
- No se midieron corriente, temperatura, fuerza o límites mecánicos físicos.
- El piloto y la campaña quedan bloqueados; ejecutar más episodios no corrige
  por sí mismo una violación determinista de posición.

## 8. Confirmación explícita de que no se usó hardware

No se abrió ningún puerto COM, no se conectó Myo o guante real y no se emitió
PWM físico. Todos los comandos fueron datos entregados a la planta simulada.
Los perfiles y manifiestos fijan `simMotors=true`, `connect_glove=false`,
`usePrerecorded=true` y `hardwareUsed=false`.

## 9. Commit de la etapa

Commit autorizado por `Continuar etapa 6`.

Mensaje previsto: `feat: add no-glove TD3 smoke protocol`.

No se hará push ni se abrirá PR. El ZIP local ajeno permanecerá fuera del
índice.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

No se recomienda avanzar a ETAPA 7 ni ejecutar el piloto 2k. Primero se requiere
una autorización explícita para una ablación correctiva única que incorpore o
valide límites deterministas de posición en simulación, manteniendo sin cambios
target, estado, reward, cuantización y decodificador. Después debe repetirse el
mismo smoke de 200 episodios y seed 11 contra exactamente el mismo corpus.

Solo si ese smoke produce cero violaciones y cero flags funcionales podrá
habilitarse el piloto `[11,22,33]`. No se ejecutó esa corrección.
