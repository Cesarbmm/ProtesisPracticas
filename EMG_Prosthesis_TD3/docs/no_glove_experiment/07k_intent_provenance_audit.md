# ETAPA 7K — Auditoría de procedencia causal de intención cero

Fecha de ejecución: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
SHA de la corrida canónica: `9b192d37f0f436c5ef541ea2d765dfcfc32f706f`  
Preinscripción: `0467d7e2093a253f10d33b051da0c1bb6cb1e278`

## 1. Resultado y alcance

Resultado de ingeniería: `PASS`.

Resultado científico preinscrito:

`zeroReferenceMixedCausalMechanisms`

Gate de replay: `PASS`.

ETAPA 7K reconstruyó causalmente la procedencia de `v_ref=0` en los 548
episodios y 31 220 estados de decisión congelados de 7H/7I/7J. Todas las ventanas
detenidas recibieron una explicación y no hubo casos activos sin resolver.

La clasificación es mixta porque una parte de las velocidades cero ocurre
durante el countdown de baja actividad mientras el gate todavía está activo, no
solo en reposo declarado. Esto no identifica una causa raíz de acciones,
saturación o seguridad y no revierte el gate fallido de 7J.

También se añadió `intentProvenanceLog` para corridas futuras. Es logging aditivo:
no entra en observación o reward y no modifica referencia, acción, cuantización,
seguridad o simulador.

## 2. Entradas congeladas y hashes

Padre 7J:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7j_artifacts\stage7j_final\2026-08-28_21-02-19-544`

Padre 7I:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_final\2026-08-28_17-54-13-526`

| Entrada | SHA-256 |
|---|---|
| manifiesto 7J | `816D748E6EA1FDFFD5CC8022C3F3D857ADA37AAFD6333C83D209DA427F273D56` |
| resultados 7J | `C5D6345BAE544A949C6A60C8BB91C8581A31A435AEA8F8C72B007C5213B85610` |
| manifiesto 7I | `BA877BD451FCAA930C2F8471D469E38DDEA75846F41DD2B6567A621E177A4258` |
| resultados 7I | `4FA61C9F2319CCD343786F3B5F73A992846D7552AC2A6ADD5A2E038FE1EE7F34` |

Los 548 archivos de episodio se recalcularon por SHA-256 antes y después del
replay y fueron idénticos al inventario 7I. Ningún input fue modificado.

Agent7250 solo fue sometido a hash:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`

No se cargó Agent7250 ni Agent200.

## 3. Evidencia disponible y alineación

Los episodios congelados no contienen una etiqueta por paso como
`intentRestActive`. Sí contienen:

- `emgLog` con la ventana EMG cruda de cada transición;
- `stateLog` con `q_ref` y `v_ref` del estado de decisión;
- `referenceHistory` usado por el reward;
- `intentTarget`, `intentVelocity` e `intentGateState` finales;
- checksum de calibración;
- perfiles efectivos con calibración y contexto de sesión.

La secuencia causal publicada es:

\[
state_i \rightarrow action_i \rightarrow emgLog_i
\rightarrow decoder_i \rightarrow reference_{i+1}.
\]

Por ello, la salida producida con `emgLog{i}` se compara con `stateLog(i+1,:)`.
La última transición, que no tiene otro estado de decisión guardado, se compara
con `intentTarget`, `intentVelocity` e `intentGateState` finales.

`referenceHistory(i,:)` se compara con `q_ref` de `stateLog(i,:)`, porque es la
referencia causal contra la que se evaluó `action_i`.

## 4. Replay matemático y funcional

Cada episodio comienza con:

```matlab
gateState = struct("isActive", false, "onCount", 0, "offCount", 0);
qCurrent = stateLog(1, q_ref_indices);
vCurrent = zeros(1, 4);
```

Cada transición reutiliza las funciones productivas:

```matlab
[desiredVelocity, intent, nextGateState, details] = ...
    mapEmgToIntentVelocity(emgLog{i}, calibration, expected, gateState);
[qNext, vNext, ~, referenceDiagnostics] = ...
    updateIntentReference(qCurrent, desiredVelocity, calibration, ...
        details.isRest, vCurrent);
```

No se duplicaron las ecuaciones del decoder o integrador en el evaluador. La
tolerancia preinscrita fue `1e-12`, aunque los errores observados fueron
exactamente cero:

| Verificación | Resultado |
|---|---:|
| error máximo de `q_ref` | 0 |
| error máximo de `v_ref` | 0 |
| error máximo de `referenceHistory` | 0 |
| mismatches del gate final | 0/548 |
| mismatches de checksum | 0/548 |
| fallos de alineación desplazada | 0/31 220 |
| cobertura de etiquetas detenidas | 1.0 |
| casos activos sin resolver | 0 |

## 5. Taxonomía causal observada

Las categorías se aplicaron en el orden preinscrito. El total de estados de
decisión fue:

| Procedencia | Ventanas | `v_ref=0` |
|---|---:|---:|
| `episodeInitialization` | 548 | 548 |
| `decoderRest` | 16 172 | 16 172 |
| `activeCountdownZero` | 4 000 | 4 000 |
| `movingReference` | 10 500 | 0 |
| `activeSynergyZero` | 0 | 0 |
| `mechanicalPositionLimitZero` | 0 | 0 |
| `mechanicalRateLimitZero` | 0 | 0 |
| `unresolvedActiveZero` | 0 | 0 |

Total detenido: 20 720 ventanas.

Entre las ventanas detenidas:

- 78.05% son reposo declarado por la histéresis;
- 19.31% son countdown con gate todavía activo y velocidad de salida ya cero;
- 2.64% son el estado inicial explícito de cada episodio.

Por tanto, `v_ref=0` no equivale siempre a `decoderRest`. Usarlo como etiqueta de
reposo pierde la diferencia causal entre reposo declarado y frenado previo al
cierre del gate.

## 6. Distribución por fuente

Por variante, las secuencias del decoder fueron idénticas porque control y
candidata compartieron EMG, calibración y referencia:

| Fuente, por variante | Inicialización | Reposo decoder | Countdown cero | Movimiento |
|---|---:|---:|---:|---:|
| training | 200 | 6 200 | 1 600 | 4 200 |
| acceptance | 50 | 1 550 | 400 | 1 050 |
| steady rest | 24 | 336 | 0 | 0 |

Los 24 episodios `steadyRest` por variante constan únicamente de inicialización y
reposo declarado. No contienen countdown, movimiento o mecanismos sin resolver.

Los segmentos detenidos que comenzaron lejos se inician durante
`activeCountdownZero`:

- candidata: 800 training + 200 acceptance;
- control: 797 training + 200 acceptance;
- tres segmentos adicionales del control comenzaron durante countdown, pero su
  MSE inicial quedó por debajo del umbral `farStarted`.

## 7. Relación con el latch 7J

Las filas 7K se emparejaron exactamente con 7J mediante variante, fuente,
episodio, repetición, paso e índice global.

| Subconjunto conjunto control+candidata | Ventanas | Procedencia |
|---|---:|---|
| recuperadas por memoria | 3 958 | 100% `decoderRest` |
| lejanas enclavadas | 3 462 | 100% `decoderRest` |
| lejanas enclavadas en segmento `farStarted` | 0 | ninguna |
| lejanas enclavadas en segmento que comenzó cerca | 3 462 | 100% |

Esto confirma que el latch 7J no se activó durante las correcciones que comenzaron
lejos. Sus ventanas lejanas aparecen después de una entrada cercana dentro de
reposo declarado y acumulación posterior de error.

La evidencia aclara por qué el estrato puramente geométrico de 7I/7J mezcla dos
historias causales. No modifica retroactivamente el gate: 7J permanece con
`contractSupported=false`, no se implementa `intentHoldMarkov61` y no se autoriza
entrenamiento.

## 8. Logging aditivo futuro

Se añadió `intentProvenanceLog`, indexado igual que `emgLog`. Cada transición con
decoder activo guarda:

- versión de esquema y número de transición;
- gate antes y después;
- actividad, gate activo, reposo, countdown y contadores;
- intención decodificada y velocidad deseada;
- referencia antes y después;
- limitaciones de posición, frenado y aceleración;
- `zeroReferenceReason` calculado con la misma función que usa el replay.

El log:

- se reinicia en `reset`;
- se guarda en `saveEpisode`;
- no entra en `calculateState`;
- no entra en `rewardContext` o `rewardInfo`;
- no modifica la referencia producida;
- no modifica acción, PWM o seguridad;
- queda vacío en la ruta del guante y en `emgIntent` con decoder desactivado.

Las pruebas comparan posición y velocidad guardadas en el log con la observación
devuelta. La referencia sigue siendo la salida de `mapEmgToIntentVelocity` y
`updateIntentReference`; el logger no recalcula una ruta conductual alternativa.

## 9. Implementación, pruebas y reproducibilidad

Archivos principales creados:

- `docs/no_glove_experiment/07k_preregistration.md`;
- `matlab_code/src/intent/classifyIntentZeroReferenceReason.m`;
- `matlab_code/src/evaluation/replayNoGloveStage7kIntentProvenance.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7kIntentProvenance.m`;
- `matlab_code/workflows/published/run_no_glove_stage7k_intent_provenance_audit.m`.

Instrumentación modificada:

- `src/@Env/Env.m`;
- `src/@Env/advanceIntentReference.m`;
- `src/@Env/reset.m`;
- `src/@Env/step.m`;
- `src/@Env/saveEpisode.m`.

Se extendieron `testIntentMarkov60.m`, `testReferenceSources.m` y el README de
workflows.

Resultados finales:

- suite específica de replay + alineación + rutas Env: 17/17 PASS;
- regresión completa `tests/no_glove`: 148/148 PASS, 0 failed,
  0 incomplete, 23.1445 s;
- `checkcode`: 0 mensajes en los diez archivos nuevos/modificados comprobados.

Durante el desarrollo, la primera suite cerró con 11 PASS y 6 errores por una
declaración de salida desactualizada del método de clase y un contrato de fixture.
Después, una prueba detectó que `emgIntent` con decoder desactivado debe conservar
el log vacío. Se corrigieron esos contratos antes de la corrida canónica; no se
cambiaron categorías, umbrales ni clasificación.

Artefacto canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7k_artifacts\stage7k_final\2026-08-28_21-25-50-214`

Reproducción independiente:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7k_artifacts\stage7k_repro\2026-08-28_21-28-14-519`

Once CSV y `offline_report.md` fueron idénticos por SHA-256 entre ambas corridas.
Los MAT y manifiestos contienen fecha/ruta y no se usaron como criterio de
identidad binaria.

Artefactos: `manifest.json`, `stage7k_results.mat`,
`decision_provenance.csv`, `transition_replay.csv`,
`episode_replay_audit.csv`, `provenance_summary.csv`,
`segment_provenance.csv`, `gate_checks.csv`, `source_decision.csv`,
`logging_contract_audit.csv`, `episode_input_hashes.csv`, `source_hashes.csv`,
`parent_audit.csv`, `test_results.mat`, `offline_report.md` y
`reproducible_command.txt`.

## 10. Riesgos y propuesta posterior

- El corpus sigue limitado a seed 11 y políticas smoke de 200 episodios.
- La procedencia se reconstruyó exactamente, pero las políticas congeladas no
  permiten inferir el efecto conductual de una etiqueta explícita.
- `activeCountdownZero` demuestra que velocidad cero no es sinónimo universal de
  reposo declarado.
- La relación entre latch, comandos y seguridad sigue siendo observacional.
- No se identificó causa raíz única de saturación.
- No se autoriza estado 61/62, reward nuevo, piloto, campaña, DTW o hardware.

La siguiente etapa propuesta, no ejecutada, es **ETAPA 7L — contrato offline de
reposo declarado y elegibilidad causal**. Debe preinscribir una condición que use
`episodeInitialization` o `decoderRest`, excluya `activeCountdownZero`, active
solo cerca del target y se libere en el primer estado no-rest aunque `v_ref` aún
sea cero. Debe conservar el resultado fallido de 7J y evaluarse como contrato
nuevo, no como reinterpretación retroactiva. El gate debe exigir cobertura de
`steadyRest >=90%`, cero activación en segmentos `farStarted`, cero fuga futura y
memoria explícita antes de proponer cualquier cambio de estado o reward.

No se ejecutó ETAPA 7L.
