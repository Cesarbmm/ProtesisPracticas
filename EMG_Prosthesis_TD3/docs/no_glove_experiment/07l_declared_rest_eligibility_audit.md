# ETAPA 7L — Auditoría offline de reposo declarado y elegibilidad causal

Fecha de ejecución: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
SHA de preinscripción: `2bea46282206dc2406d4aaf38268389a682a5450`  
SHA de implementación usado por la corrida: `1dda5b9bb942a56647eb32468e5a7ced1e9bcb48`

## 1. Resultado y alcance

Resultado de ingeniería: `PASS`.

Clasificación científica preinscrita:

`offlineDeclaredRestEligibilitySupported`

Contrato soportado offline: `true`.

ETAPA 7L evaluó una máquina causal nueva que solo puede mantener memoria durante
inicialización o reposo declarado por el decoder. El análisis fue estrictamente
offline sobre los 548 episodios y 31 220 estados de decisión congelados de
7H/7I/7K. No se cargó un agente, no se creó `Env`, no se invocó el simulador o
reward, no se entrenó, no se calculó DTW y no se usó hardware.

Este resultado no cambia retrospectivamente ETAPA 7J. Su clasificación permanece
`latchedHoldNotSeparableFromFarCorrection` y su
`contractSupported=false`. 7L responde una pregunta semántica distinta y no
autoriza todavía un estado nuevo ni una ablación conductual.

## 2. Motivación derivada de 7J y 7K

El latch 7J empleaba únicamente geometría y `v_ref=0`. Su cobertura de reposo fue
completa, pero su exposición lejana candidata fue 0.2080126754, superior al gate
preinscrito 0.05. Por ello 7J falló.

7K demostró después que `v_ref=0` mezcla causas:

- `episodeInitialization`: 548 ventanas;
- `decoderRest`: 16 172 ventanas;
- `activeCountdownZero`: 4 000 ventanas;
- `movingReference`: 10 500 ventanas;
- otras procedencias activas o sin resolver: 0.

En particular, `activeCountdownZero` todavía pertenece a un gate de intención
activo. Aunque la velocidad de referencia ya sea cero, no representa reposo
declarado. 7L separa esa semántica sin cambiar los datos ni el comportamiento de
las políticas congeladas.

## 3. Entradas congeladas e integridad

Padre 7K:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7k_artifacts\stage7k_final\2026-08-28_21-25-50-214`

Padre 7I:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_final\2026-08-28_17-54-13-526`

Padre 7J conservado:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7j_artifacts\stage7j_final\2026-08-28_21-02-19-544`

7K aportó la procedencia causal por paso y 7I aportó el error mecánico. Las
tablas se emparejaron exactamente mediante:

`variant, source, episode, repetitionId, step, windowIndex`.

No hubo claves duplicadas, faltantes o adicionales. Los 548 episodios se
recalcularon por SHA-256 antes y después del análisis y coincidieron con el
inventario 7I.

| Entrada | SHA-256 |
|---|---|
| manifiesto 7K | `27CDCD1518F0F2BB3781FDAD72FDAE7BC1CF3B0C9EA8A32A0006948C51412360` |
| resultados 7K | `A38A2AA417D4639D0D31A25CC16D99FB8DEEA98BF3D563CAE474AF1C0FB606BD` |
| decisiones 7K | `81C61A59DE14482B1B09D35839C937BA211AC1A7307E07794DC374B53814638E` |
| manifiesto 7I | `BA877BD451FCAA930C2F8471D469E38DDEA75846F41DD2B6567A621E177A4258` |
| resultados 7I | `4FA61C9F2319CCD343786F3B5F73A992846D7552AC2A6ADD5A2E038FE1EE7F34` |
| corpus de ventanas 7I | `61C51B2FF98B2D33103F63C75F806458687FB59E0DE7819AF069CBFD9DF3D175` |
| manifiesto 7J | `816D748E6EA1FDFFD5CC8022C3F3D857ADA37AAFD6333C83D209DA427F273D56` |

Agent7250 solo fue sometido a hash y permaneció intacto:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`

No se cargaron Agent7250 ni Agent200.

## 4. Definición matemática

Para cada estado de decisión se usó el error congelado:

\[
E_t=\operatorname{mean}\left((q_t-q_{ref,t})^2\right).
\]

La etiqueta de reposo declarado es:

\[
R_t=[p_t\in\{\texttt{episodeInitialization},
                  \texttt{decoderRest}\}],
\]

donde `p_t` es la procedencia causal validada en 7K. Se excluye expresamente
`activeCountdownZero`.

La entrada geométrica se conserva de 7J sin reajuste:

\[
N_t=[E_t\leq10^{-4}].
\]

El estado de memoria se reinicia a cero por episodio y obedece:

\[
L_t=\begin{cases}
0,&\neg R_t,\\
1,&R_t\land N_t,\\
L_{t-1},&R_t\land\neg N_t.
\end{cases}
\]

La condición instantánea sin memoria es:

\[
I_t=R_t\land N_t.
\]

Una ventana se recupera por memoria cuando:

\[
M_t=L_t\land\neg I_t.
\]

La liberación es inmediata: cualquier fila `R_t=false`, incluso un countdown
con `v_ref=0`, fuerza `L_t=false` en esa misma decisión.

## 5. Protección frente a correcciones iniciadas lejos

Se heredaron de 7K los segmentos detenidos y su etiqueta `segmentFarStarted`.
En un segmento que comenzó lejos, la fase preconvergencia contiene las filas
anteriores a la primera observación `N_t=true`. La condición prohibida fue:

\[
P_t=L_t\land\texttt{farStarted}_t
          \land\neg\left(\bigvee_{j\leq t}N_j\right).
\]

Resultados:

- segmentos detenidos totales: 2 548;
- segmentos `farStarted`: 1 997;
- ventanas preconvergencia `farStarted`: 13 979;
- segmentos `farStarted` que alcanzaron cercanía: 0;
- activaciones prematuras: 0;
- ventanas lejanas enclavadas en segmentos `farStarted`: 0.

Por tanto, en este corpus la máquina jamás activó memoria durante una corrección
que comenzó lejos. Los segmentos `farStarted` tampoco llegaron a la región de
entrada; el resultado no depende de perdonar una convergencia tardía.

## 6. Resultados por variante

| Métrica | Control | Candidata |
|---|---:|---:|
| ventanas | 15 610 | 15 610 |
| ventanas de reposo declarado | 8 360 | 8 360 |
| cobertura instantánea en `steadyRest` | 0.5333333333 | 0.5333333333 |
| cobertura con memoria en `steadyRest` | 1.0 | 1.0 |
| ventanas recuperadas por memoria | 1 825 | 2 133 |
| fugas no-rest | 0 | 0 |
| activaciones prematuras `farStarted` | 0 | 0 |
| ventanas geométricamente lejanas | 8 585 | 8 836 |
| exposición lejana enclavada, diagnóstico | 0.1891671520 | 0.2080126754 |
| ventanas lejanas enclavadas | 1 624 | 1 838 |
| diferencias contra latch 7J | 0 | 0 |
| entradas al latch | 274 | 274 |
| liberaciones | 250 | 250 |

Totales conjuntos:

- reposo declarado: 16 720 ventanas;
- memoria recuperada: 3 958 ventanas;
- ventanas lejanas enclavadas: 3 462;
- fugas no-rest: 0;
- activaciones prematuras: 0;
- diferencias contra 7J: 0;
- checks de prefijo: 548;
- mismatches de prefijo: 0.

Las 3 462 ventanas lejanas enclavadas pertenecen exclusivamente a segmentos que
comenzaron cerca. Se reportan porque la posición se alejó después de una entrada
válida, pero no son evidencia de activación durante una corrección iniciada
lejos. En 7L esta exposición es un diagnóstico, no un gate.

## 7. Gates y decisión científica

| Gate | Observado | Umbral | Resultado |
|---|---:|---:|---|
| episodios | 548 | 548 | PASS |
| ventanas | 31 220 | 31 220 | PASS |
| cobertura semántica de ventanas detenidas | 1.0 | 1.0 | PASS |
| mínima cobertura `steadyRest` por variante | 1.0 | >=0.90 | PASS |
| fugas no-rest | 0 | 0 | PASS |
| activaciones prematuras `farStarted` | 0 | 0 | PASS |
| ventanas recuperadas por memoria | 3 958 | >=1 | PASS |
| mismatches prefijo-completo | 0 | 0 | PASS |

Todos los gates preinscritos pasaron. La clasificación es por ello
`offlineDeclaredRestEligibilitySupported`.

La equivalencia causal por prefijos volvió a ejecutar la primera mitad de cada
episodio sin entregar filas futuras. Los bits `latch`, entrada y liberación
coincidieron exactamente con el prefijo de la ejecución completa.

## 8. Interpretación y límites de la conclusión

El contrato semántico queda respaldado offline porque:

1. recupera la cobertura perdida por el criterio instantáneo;
2. no conserva memoria en countdown o movimiento;
3. no se activa antes de cercanía en correcciones iniciadas lejos;
4. necesita memoria explícita para reproducir 3 958 decisiones.

Sin embargo, `stage7jLatchDifferenceCount=0`: en este corpus la máquina 7J ya se
había liberado antes de las filas `activeCountdownZero`. La nueva definición es
más explícita y verificable, pero no produjo una intervención contrafactual
diferente sobre las políticas congeladas. Por tanto:

- no se ha demostrado una mejora de tracking, acción o seguridad;
- no se ha demostrado reducción de saturación o `deltaActionL2`;
- la exposición lejana posterior a una entrada cercana sigue existiendo;
- no se identificó una causa raíz única de saturación;
- no se puede extrapolar desde seed 11 a una distribución multisemilla;
- no se autoriza entrenamiento ni hardware.

La observación candidata propuesta, pero no implementada, es:

\[
s_{62}=[s_{60},R_t,L_t].
\]

Ambos bits son necesarios para que la política distinga el estado semántico
actual de la memoria retenida. ETAPA 7L no modifica `intentMarkov60`.

## 9. Implementación, pruebas y reproducibilidad

Archivos creados:

- `docs/no_glove_experiment/07l_preregistration.md`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7lDeclaredRestEligibility.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7lDeclaredRestEligibility.m`;
- `matlab_code/workflows/published/run_no_glove_stage7l_declared_rest_eligibility_audit.m`;
- este informe.

Archivo modificado:

- `matlab_code/workflows/published/README.md`.

Pruebas específicas:

- 8/8 PASS, 0 failed, 0 incomplete;
- contrato soportado sintético;
- liberación inmediata en `activeCountdownZero`;
- espera hasta cercanía en un segmento `farStarted`;
- clasificación de cobertura insuficiente;
- clasificación de memoria sin soporte adicional;
- rechazo de claves faltantes o duplicadas;
- rechazo de pasos no contiguos;
- opciones del launcher cerradas por defecto.

Regresión completa `tests/no_glove`:

- 156/156 PASS;
- 0 failed;
- 0 incomplete;
- 31.661556 s.

`checkcode` reportó 0 mensajes en el analizador, launcher y prueba nuevos.

Comando canónico:

```matlab
cd('C:/Users/Cesarbmm/ProtesisPracticas_no_glove_intent_control/EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7l_declared_rest_eligibility_audit(struct( ...
    'resultsRoot','C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7l_artifacts/stage7l_final', ...
    'stage7kRunRoot','C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7k_artifacts/stage7k_final/2026-08-28_21-25-50-214'));
```

Artefacto canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7l_artifacts\stage7l_final\2026-08-28_21-44-35-302`

Reproducción independiente:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7l_artifacts\stage7l_repro\2026-08-28_21-45-52-595`

Diez CSV y `offline_report.md` fueron idénticos por SHA-256 entre ambas
corridas. Los MAT y manifiestos contienen fecha/ruta de ejecución y no se usaron
como criterio de identidad binaria.

Artefactos principales: `manifest.json`, `stage7l_results.mat`,
`declared_rest_window_audit.csv`, `episode_audit.csv`,
`stopped_segment_audit.csv`, `variant_summary.csv`,
`provenance_summary.csv`, `gate_checks.csv`, `source_decision.csv`,
`parent_audit.csv`, `episode_input_hashes.csv`, `source_hashes.csv`,
`test_results.mat`, `offline_report.md` y `reproducible_command.txt`.

## 10. Seguridad, riesgos y etapa posterior propuesta

Confirmaciones negativas:

- `simMotors=true` en los perfiles congelados;
- hardware usado: no;
- puertos COM o PWM físico: no;
- simulador invocado por el análisis: no;
- agentes cargados: no;
- entrenamiento: no;
- DTW: no;
- cambios de estado, reward, referencia, política, cuantización o seguridad: no;
- `intentDeclaredRestHoldMarkov62` implementado: no;
- ablación conductual autorizada: no;
- 7J reautorizado: no.

El archivo local ajeno `matlab_code.zip` permaneció sin seguimiento y no fue
modificado. El manifiesto registra por ello un árbol globalmente sucio, pero
`gitTrackedDirty=false`.

La siguiente etapa propuesta, no ejecutada, es **ETAPA 7M — observabilidad causal
`intentDeclaredRestHoldMarkov62` sin entrenamiento**:

1. preinscribir la alineación exacta de `R_t` y `L_t` con el estado de decisión;
2. añadir la variante 62 sin modificar `legacy44`, `markov52`,
   `intentMarkov60` o las rutas del guante;
3. reiniciar la memoria por episodio y liberarla en la primera decisión no-rest;
4. demostrar por tests sintéticos una divergencia frente al contrato puramente
   geométrico cuando `v_ref=0` pero el gate continúa activo;
5. comparar bit a bit el replay runtime contra el contrato 7L, sin fuga futura;
6. verificar 52/60/62 dimensiones y regresión completa;
7. detenerse antes de reward, entrenamiento, piloto, DTW o hardware.

No se ejecutó ETAPA 7M.
