# ETAPA 2 — Calibración EMG e intención offline

Fecha de ejecución: 2026-08-18

## 1. Resultado de la etapa

`PASS` en el fixture sintético determinista y en las pruebas de contrato.

Se implementó, sin conectarla todavía a `Env`, la cadena causal:

```text
EMG cruda -> envolvente por canal -> calibración de la misma sesión
          -> reposo con histéresis -> intención firmada r=2
          -> B explícita 4x2 -> velocidad y referencia mecánicamente limitadas
```

El resultado valida fórmulas, compatibilidad, causalidad e invariantes de software.
No constituye evidencia de separabilidad sobre EMG humana, calibración clínica ni
límites físicos de la prótesis. No se ejecutó RL.

## 2. Rama y SHA base/actual

- Rama: `experiment/no-glove-intent-control`.
- SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`.
- Padre de ETAPA 2 / commit de ETAPA 1:
  `7fa62f85c424dda7bf3dedc65455c3045b3c63ec`.
- El SHA actual de ETAPA 2 es el commit que contiene este documento; se resuelve
  con `git rev-parse HEAD` y queda registrado sin estado dirty en el manifiesto
  post-commit. No se inserta el SHA del propio commit dentro de su contenido.

Agent7250 no se modificó ni se cargó. Su checkpoint canónico sigue en
`matlab_code/checkpoints/canonical/Agent7250_valid_baseline/`.

## 3. Archivos creados y modificados

### Creados

- `matlab_code/src/intent/computeEmgEnvelope.m`
- `matlab_code/src/intent/calibrateEmgIntent.m`
- `matlab_code/src/intent/validateIntentCalibration.m`
- `matlab_code/src/intent/computeIntentCalibrationChecksum.m`
- `matlab_code/src/intent/mapEmgToIntentVelocity.m`
- `matlab_code/src/intent/updateIntentReference.m`
- `matlab_code/src/intent/buildSyntheticEmgIntentDataset.m`
- `matlab_code/src/runtime/buildNoGloveStage2OfflineConfig.m`
- `matlab_code/tests/no_glove/testEmgIntentOffline.m`
- `matlab_code/workflows/published/run_no_glove_stage2_offline_validation.m`
- `docs/no_glove_experiment/02_intent_calibration_offline.md`

### Modificado

- `matlab_code/workflows/published/README.md`

No se modificaron `Env`, estados, rewards, simulador, convertidores, defaults
globales, checkpoints ni la ruta histórica de guante.

## 4. Decisiones técnicas y justificación

### Datos y dominio

Los 12 MAT publicados en `data/datasets/Denis Dataset/` contienen matrices EMG
`N x 8` emparejadas solamente como cierre/apertura. No incluyen reposo etiquetado,
MVC/P95 de una sesión ni instrucciones de oposición/liberación del pulgar. Su
metadata tampoco fija colocación, rotación u orden anatómico compatible; algunos
archivos agrupan adquisiciones de fechas distintas. La ruta `RecordedMyo` los
reproduce suponiendo 200 Hz, pero esa tasa no está embebida en los MAT.

Por ello no se usa DENIS para fabricar una calibración `r=2`. El launcher utiliza
un fixture con `dataProvenance="synthetic"`, semilla fija, reposo, cuatro
instrucciones firmadas, intensidades moderada/máxima, ruido y un canal plano. En
el repositorio, “EMG cruda” es la muestra Myo ya escalada por la librería
(`data.emg/128`), no voltios medidos.

### Envolvente y calibración

Para cada ventana completa de muestras por canales:

```text
m_c(t) = mean(abs(x_c))
a_c(t) = clip((m_c(t)-baselineMedian_c) /
              (signalLevel_c-baselineMedian_c+epsilon), 0, 1)
```

Solo se procesan ventanas completas; una cola parcial se descarta y reporta.
`baselineMedian` es la mediana de reposo. `signalLevel` es el máximo, por canal,
de los P95 calculados dentro de cada instrucción, evitando diluir un canal que
participe solo en una sinergia. Un canal por debajo de
`max(minCalibrationRange, 6*1.4826*MAD_rest)` se marca plano; `a_c=0` y la
columna correspondiente de `W` queda exactamente en cero.

Cada captura de reposo/instrucción debe declarar y coincidir en usuario, sesión,
orden de canales, tasa, unidades y procedencia. Se exigen al menos ocho ventanas
de reposo y cinco por instrucción en este perfil. No se reordenan canales ni se
rellenan metadatos silenciosamente.

### Decoder de dos sinergias

El protocolo categórico admite exclusivamente:

```text
close=[+1,0]       open=[-1,0]
oppose=[0,+1]      releaseOppose=[0,-1]
```

Se exige cobertura positiva y negativa de ambos ejes. Un ridge ponderado por
instrucción ajusta `atanh(target)` con bias no regularizado; la magnitud del
target procede de la activación EMG media, nunca de guante. La calibración falla
si el diseño no identifica dos direcciones, si `W` sobre canales activos no tiene
rango 2, si el RMSE global o por clase supera el umbral versionado, o si aparecen
NaN/Inf.

```text
z_t = tanh(W*a_t + decoderBias), z_t in [-1,1]^2
v_des = v_max .* clip(B*z_t, -1, 1)
```

`B` es explícita, acotada, `4x2`, de rango 2 y versionada como
`synthetic-unvalidated-mechanics-v1`. Sus filas usan el orden exacto del
repositorio `[little,idx,thumb,mid]`. No se afirma independencia de cuatro DoF ni
validez mecánica de esa matriz.

La calibración guarda protocolo, direcciones, conteos, procedencia, parámetros,
unidades, `W`, bias, `B`, límites y métricas por clase. Su SHA-256 canonicaliza
recursivamente el orden de campos antes de codificar JSON; una mutación invalida
el checksum.

### Reposo y referencia viable

La actividad de compuerta es la media de `a_c` en canales válidos. Las
comparaciones son inclusivas: activa en la ventana `nOn` consecutiva con
`A>=thetaOn` y vuelve a reposo en la `nOff` consecutiva con `A<=thetaOff`. Un
pulso aislado no activa. Durante el conteo de apagado se ordena velocidad cero y
el perfil exige:

```text
(nOff-1)*aMax*DeltaT >= vMax
```

Esto permite frenar antes del hold exacto. Una transición abrupta incompatible
se rechaza en lugar de violar aceleración silenciosamente.

`q_ref` comienza exactamente en el encoder suministrado; un encoder fuera de
rango da error y no se recorta creando un salto. En movimiento, la velocidad se
proyecta sobre la intersección de límites de velocidad, aceleración, posición y
margen de frenado. Tras el clip numérico final de posición se recalcula la
velocidad realmente aplicada. En reposo: `v_ref=0` y `q_ref` no deriva.

### WMoos separado

Las 40 features históricas se calculan y guardan por una rama independiente.
Nunca alimentan baseline, P95, activación, compuerta o decoder. Su rango sintético
observado, aproximadamente `[-2.0389,29.447]`, confirma que no son amplitudes
físicas `[0,1]`.

## 5. Comandos/pruebas ejecutados y resultados exactos

Suite específica offline:

```matlab
root = fullfile(pwd,'EMG_Prosthesis_TD3','matlab_code');
addpath(genpath(root));
r = runtests(fullfile(root,'tests','no_glove','testEmgIntentOffline.m'));
assert(all([r.Passed]));
```

Resultado: `8/8 Passed`, `0 Failed`, `0 Incomplete`.

La suite cubre fórmula exacta, solapamiento/cola parcial, repetibilidad y
save/load, checksum canonical, canal plano, datos totalmente planos, falta de
polaridad, dirección diagonal, ventanas insuficientes, EMG no separable, cambio
de usuario/sesión/canales/unidades/motores/timing, contexto omitido o con typo,
umbrales/límites/NaN, reposo, moderada, máxima, ruido, histéresis exacta,
causalidad futura, equivalencia batch/stream y límites de referencia.

Regresión completa no-glove:

```matlab
r = runtests(fullfile(root,'tests','no_glove'),'IncludeSubfolders',true);
assert(all([r.Passed]));
```

Resultado previo al commit: `14/14 Passed`, `0 Failed`, `0 Incomplete`.
Las seis pruebas heredadas de ETAPA 1 sí construyen `SimController` con
`simMotors=true`; no cargan agente, no entrenan y no usan hardware. El launcher y
las ocho pruebas específicas de ETAPA 2 no construyen `Env` ni simulador.

Análisis estático:

```matlab
m = checkcode(<cada uno de los 10 archivos MATLAB de ETAPA 2>,'-id');
```

Resultado: `0` mensajes en los diez archivos. `git diff --check` terminó sin
errores después de retirar espacios finales.

Launcher reproducible:

```matlab
cd('<clon>/EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
run_no_glove_stage2_offline_validation(struct( ...
    'seed',11, ...
    'resultsRoot','<ruta-de-salida>'));
```

## 6. Métricas y artefactos generados

Corrida determinista seed 11 (62 ventanas):

| Métrica sintética/offline | Valor |
|---|---:|
| finitud | 1.000000 |
| canales activos / planos | 7 / 1 |
| RMSE de ajuste | 0.008217491 |
| rango de `W` activa / rango de `B` | 2 / 2 |
| precisión de signo en instrucciones | 1.000000 |
| activación falsa en reposo+ruido aislado | 0.000000 |
| deriva máxima con gate inactivo | 0 |
| error de inicialización desde encoder | 0 |
| máximo `abs(v_ref)` | 0.125697688 |
| máximo `abs(a_ref)` | 0.628488439 |
| violaciones de activación/intención | 0 / 0 |
| violaciones de posición/velocidad/aceleración | 0 / 0 / 0 |

Estas cifras describen el fixture, no desempeño humano ni una comparación de MSE
con Agent7250.

Cada corrida guarda:

- `manifest.json/.mat`, configuración efectiva, tests, seed, SHA Git, checksum y
  flags de seguridad;
- dataset sintético y calibración MAT/JSON;
- CSV por canal, `W`, `B`, escenarios, traza causal y features WMoos;
- `offline_results.mat`, `test_results.mat`, reporte Markdown y hashes SHA-256;
- `intent_offline_report.png` con `a_t`, `z_t`, `v_ref` y `q_ref`;
- `reproducible_command.txt`.

La ruta exacta del artefacto post-commit se reporta al cerrar la etapa. El
manifiesto debe mostrar el SHA de ETAPA 2 y `gitDirty=false`.

## 7. Riesgos, supuestos y cuestiones no resueltas

- No existe aún una calibración real por usuario/sesión. El fixture valida el
  contrato, no la fisiología.
- `B`, `qMin/qMax`, `vMax`, `aMax`, `thetaOn/thetaOff` y `nOn/nOff` son parámetros
  sintéticos no validados. La compuerta no se presenta como solución reproducible
  para Myo real. Los límites de planta se medirán en ETAPA 5.
- No se demostró separabilidad real de dos sinergias ni independencia de cuatro
  DoF.
- No se midió retardo y no se introdujo DTW en estado o reward.
- `RecordedMyo` conserva su manejo histórico de la última lectura para no alterar
  el benchmark; la nueva ruta offline solo acepta ventanas completas.
- La compatibilidad falla cerrada según metadata declarada, pero el software no
  puede detectar una recolocación física mal etiquetada; eso requiere el shadow
  mode de ETAPA 9.
- Integrar el decoder en `Env`, resolver la alineación temporal y exponer `q_ref`
  en el estado pertenece a ETAPA 3.

## 8. Confirmación de que no se usó hardware

Confirmación explícita: no se abrió ningún puerto COM, no se construyó un
controlador físico, no se conectó Myo o guante real, no se emitió PWM físico y no
se midió corriente. El launcher de ETAPA 2 no usa siquiera el simulador; conserva
`simMotors=true` como invariante de la línea. La regresión de ETAPA 1 usó solo
`SimController` y `RecordedMyo`.

## 9. Commit de la etapa

Commit autorizado por la orden `continuar etapa2`.

Mensaje previsto: `feat: add offline EMG intent calibration`.

No se hizo push ni se abrió PR. El SHA exacto se informa tras crear el commit y
repetir el launcher desde el árbol limpio.

## 10. Propuesta precisa de la siguiente etapa, sin ejecutarla

ETAPA 3 debe integrar esta calibración ya validada en `referenceSource="emgIntent"`,
inicializar `q_ref` desde encoder durante `reset`, añadir `intentMarkov60` con el
orden exacto `[phi_EMG(40),q(4),Deltaq(4),u_eff,t-1(4),q_ref(4),v_ref(4)]` y crear
pruebas de dimensión, índices y alineación causal. Debe conservar sin regresión
`legacy44`, `markov52` y `stackedEmg132`. No se ejecutó ninguna parte de ETAPA 3.
