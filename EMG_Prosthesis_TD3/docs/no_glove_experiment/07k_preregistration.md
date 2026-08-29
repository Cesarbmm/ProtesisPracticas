# ETAPA 7K — Preinscripción de procedencia causal de intención cero

Fecha: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
Base `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
Padre canónico 7J: `C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7j_artifacts\stage7j_final\2026-08-28_21-02-19-544`

Esta preinscripción se compromete antes de calcular la procedencia de las 31 220
ventanas. La inspección estática previa estableció únicamente el contrato de
datos: los episodios congelados guardan `emgLog`, `stateLog`, historial de
referencia y estado final de histéresis, pero no una etiqueta causal por paso.

## 1. Alcance

ETAPA 7K tiene dos entregables separados:

1. replay estrictamente offline de la procedencia de `v_ref=0` en los 548
   episodios congelados de 7H usados por 7I/7J;
2. instrumentación aditiva de logging para que corridas futuras guarden esa
   procedencia directamente.

La instrumentación no entra en la observación ni en la recompensa y no puede
modificar target, referencia, acción, cuantización, seguridad o simulador. No se
carga Agent200 ni Agent7250, no se entrena, no se calcula DTW, no se ejecuta una
campaña y no se usa hardware. Las pruebas de `Env` permanecen con
`simMotors=true`.

## 2. Alineación causal congelada

En cada episodio de `c` pasos:

- `stateLog(1,:)` es el estado de decisión inicial producido por `reset`;
- `emgLog{i}` se lee después de aplicar la acción del paso `i`;
- esa EMG actualiza la referencia que aparece en el estado de decisión `i+1`;
- por tanto, para `i<c`, el replay de `emgLog{i}` se compara con
  `stateLog(i+1,:)`, nunca con `stateLog(i,:)`;
- el replay de `emgLog{c}` se compara con `intentTarget`, `intentVelocity` e
  `intentGateState` finales guardados.

El estado inicial de histéresis es exactamente:

```matlab
struct("isActive", false, "onCount", 0, "offCount", 0)
```

La posición inicial del generador es `q_ref` de `stateLog(1,:)` y su velocidad
inicial es cero.

## 3. Replay del decodificador y generador

Para cada transición se ejecutan las funciones publicadas, sin reimplementarlas:

```matlab
[desiredVelocity, intent, nextGateState, decoderDetails] = ...
    mapEmgToIntentVelocity(emgLog{i}, calibration, expected, gateState);
[qNext, vNext, ~, referenceDiagnostics] = ...
    updateIntentReference(qCurrent, desiredVelocity, calibration, ...
        decoderDetails.isRest, vCurrent);
```

Se verifican:

- `qNext` y `vNext` contra el estado `i+1` cuando existe;
- resultado final contra `intentTarget` e `intentVelocity`;
- `nextGateState` final contra `intentGateState`;
- `referenceHistory` contra `q_ref` usado en cada estado de decisión;
- checksum de calibración del episodio contra el perfil efectivo.

Tolerancia numérica fija: `1e-12`. Los campos lógicos y contadores deben
coincidir exactamente.

## 4. Etiquetas de procedencia

Para `stateLog(1,:)`, si `v_ref=0`, la etiqueta es
`episodeInitialization`.

Para `stateLog(t,:)`, `t>=2`, se etiqueta el resultado de la transición `t-1`.
Si `v_ref` no es cero: `movingReference`. Si es cero, el orden exclusivo es:

1. `decoderRest`: `decoderDetails.isRest=true`;
2. `activeCountdownZero`: gate activo y countdown de baja actividad;
3. `activeSynergyZero`: gate activo, sin countdown y velocidad deseada cero;
4. `mechanicalPositionLimitZero`: velocidad deseada no cero y limitación de
   posición registrada;
5. `mechanicalRateLimitZero`: limitación de aceleración o frenado registrada;
6. `unresolvedActiveZero`: ninguna explicación anterior.

El umbral para considerar una velocidad cero es `1e-12` en máximo absoluto.
No se fusionarán categorías después de observar resultados.

## 5. Relación con 7J

Las filas se emparejan exactamente con `window_latch_audit` de 7J mediante:

`variant, source, episode, repetitionId, step, windowIndex`.

Se reportará por separado la procedencia de:

- todas las ventanas detenidas;
- las ventanas recuperadas por memoria;
- las ventanas lejanas enclavadas;
- segmentos que comenzaron cerca y segmentos `farStarted`.

No se recalculará ni se cambiará el gate 7J. Aunque una procedencia aclare la
semántica, `contractSupported=false` permanece congelado.

## 6. Gates y clasificación

Gate de validez:

1. 548 episodios y 31 220 ventanas emparejados;
2. error máximo de replay de `q_ref` y `v_ref` <= `1e-12`;
3. cero mismatches del estado final de histéresis;
4. cero mismatches de `referenceHistory`;
5. 100% de ventanas con `v_ref=0` reciben una etiqueta;
6. cero `unresolvedActiveZero`;
7. la comparación causal desplazada `i -> i+1` pasa en todos los episodios;
8. hashes de inputs preservados;
9. cero NaN/Inf, agente, entrenamiento, DTW o hardware.

Clasificación, en este orden:

- si falla integridad o alineación: `intentProvenanceReplayInvalid`;
- si existe `unresolvedActiveZero`: `zeroReferenceProvenanceUnresolved`;
- si toda ventana detenida es `episodeInitialization` o `decoderRest`:
  `zeroReferenceFullyExplainedByRestGate`;
- si aparecen otras categorías resueltas:
  `zeroReferenceMixedCausalMechanisms`.

La clasificación describe procedencia, no causa raíz de acciones, saturación o
seguridad.

## 7. Logging aditivo para corridas futuras

Al faltar una etiqueta directa por paso, se añadirá
`intentProvenanceLog` exclusivamente al modo `emgIntent` con decoder activo.
Cada entrada corresponderá a la transición del mismo índice de `emgLog` y
guardará como mínimo:

- `schemaVersion`, `transitionStep`;
- gate antes y después, actividad, `gateActive`, `isRest`, countdown y
  contadores;
- intención decodificada y velocidad deseada;
- posición/velocidad de referencia antes y después;
- limitaciones de posición, aceleración y frenado;
- `zeroReferenceReason` usando el orden de etiquetas anterior.

El log se reinicia en `reset` y se guarda en `saveEpisode`. No se añade a
`intentMarkov60`, `rewardContext` ni `rewardInfo`. Las pruebas deben confirmar
que referencia y observación siguen siendo las calculadas por las funciones
existentes y que la ruta histórica del guante conserva un log vacío.

## 8. Decisión posterior

ETAPA 7K termina después del replay, logging, pruebas y documentación. No revive
el latch 7J ni autoriza `intentHoldMarkov61`. Una etapa posterior solo podrá
formularse si la procedencia queda completamente explicada y deberá separar la
semántica del target de cualquier cambio conductual.
