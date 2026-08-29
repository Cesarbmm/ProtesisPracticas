# ETAPA 7M — Observabilidad causal `intentDeclaredRestHoldMarkov62`

Fecha de ejecución: 2026-08-29  
Rama: `experiment/no-glove-intent-control`  
SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
SHA de preinscripción: `155399a15ec9919e01b41bdb70fd0978a044aa0a`  
SHA de implementación usado por la corrida: `45aab09ba08a6a8d041c732c4fd8dbfde85c02d0`

## 1. Resultado y alcance

Resultado de ingeniería: `PASS`.

Clasificación preinscrita:

`intentDeclaredRestHoldMarkov62Implemented`

ETAPA 7M implementó como variante opt-in la observación causal:

\[
s_{62,t}=[s_{60,t},R_t,L_t].
\]

El estado histórico por defecto continúa siendo `markov52`. Las variantes
`legacy44`, `markov52`, `stackedEmg132` e `intentMarkov60` conservaron sus
dimensiones. No se creó ni cargó un agente de 62 entradas, no se entrenó, no se
calculó DTW y no se usó hardware.

Se ejecutaron dos trazas simuladas emparejadas de 20 pasos para comprobar que la
nueva variante no cambia los primeros 60 valores, reward, referencia, acción,
PWM o seguridad. Todas las diferencias observadas fueron exactamente cero.

## 2. Padre científico e integridad

Padre canónico 7L:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7l_artifacts\stage7l_final\2026-08-28_21-44-35-302`

| Entrada | SHA-256 |
|---|---|
| manifiesto 7L | `32F43B59C4D579649549FFD4ED030531A97C13BD94E1D24F1D3E6AA58F43466B` |
| resultados 7L | `FF780F276ACBAB58D650D4A9945344D4D6A7934706DE58E753F213D4AD1F8F21` |
| decisión 7L | `980CE52513B00A71B5446CC1A2876182B6C1DB1C20498677CED99309D0211CB8` |

El padre conserva:

- `scientificResult=offlineDeclaredRestEligibilitySupported`;
- `contractSupported=true`;
- 548 episodios y 31 220 ventanas preservadas;
- `stage7jContractReauthorized=false`;
- ningún estado 62 previamente implementado;
- ningún entrenamiento, agente, DTW o hardware.

Los tres artefactos padre fueron sometidos a hash antes y después del smoke y
permanecieron idénticos.

Agent7250 solo fue sometido a hash y permaneció intacto:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`

## 3. Definición exacta del estado

La variante implementada es:

\[
s_{62,t}=[\phi_{EMG,t}(40),q_t(4),\Delta q_t(4),u_{eff,t-1}(4),
q_{ref,t}(4),v_{ref,t}(4),R_t,L_t].
\]

| Campo | Índices MATLAB | Dimensión |
|---|---:|---:|
| WMoos EMG | 1:40 | 40 |
| encoder normalizado | 41:44 | 4 |
| delta de encoder | 45:48 | 4 |
| acción efectiva anterior | 49:52 | 4 |
| posición de referencia | 53:56 | 4 |
| velocidad de referencia | 57:60 | 4 |
| reposo declarado | 61 | 1 |
| memoria causal | 62 | 1 |

Los dos bits se publican como dobles exactos en `{0,1}`. Sus límites declarados
en `rlNumericSpec` son `[0,1]`. La versión de `Env` pasó de 2.5 a 2.6 para
registrar la ampliación opt-in del contrato de observación.

El layout auditado confirmó:

- `legacy44`: 44;
- `markov52`: 52;
- `intentMarkov60`: 60;
- `intentDeclaredRestHoldMarkov62`: 62;
- `stackedEmg132`: 132.

## 4. Matemática y configuración

Se añadió un parámetro propio de observación:

`intentDeclaredRestHoldPositionMseTolerance=1e-4`.

No se reutiliza silenciosamente `intentHoldPositionMseTolerance` del reward. El
error causal que acompaña a la misma observación es:

\[
E_t=\operatorname{mean}((q_t-q_{ref,t})^2),
\qquad N_t=[E_t\le10^{-4}].
\]

La recurrencia productiva se aisló en
`updateIntentDeclaredRestHoldState`:

\[
L_t=\begin{cases}
0,&\neg R_t,\\
1,&R_t\land N_t,\\
L_{t-1},&R_t\land\neg N_t.
\end{cases}
\]

En `reset`:

\[
q_{ref,0}=q_0,\quad R_0=1,\quad N_0=1,\quad L_0=1.
\]

Después del reset, `R_t` procede directamente de `decoderDetails.isRest` de la
transición que creó la referencia del mismo estado. Así,
`activeCountdownZero` no se confunde con reposo aunque `v_ref=0`.

La configuración falla de forma cerrada si la variante 62 se combina con
fuente de guante, decoder desactivado, longitud distinta de 62 o tolerancia
inválida. El perfil publicado repite explícitamente:

- `referenceSource="emgIntent"`;
- `simMotors=true`;
- `usePrerecorded=true`;
- `connect_glove=false`;
- `run_training=false`;
- `newTraining=false`;
- `actionInterfaceVariant="baselineQuantized"`;
- `rewardType="trackingIntentActionRateReward"`.

## 5. Alineación temporal

La implementación conserva la frontera causal:

\[
state_t\rightarrow action_t\rightarrow q_{t+1},EMG_t
\rightarrow reward_t(q_{ref,t},v_{ref,t})
\rightarrow decoder_t\rightarrow state_{t+1}.
\]

Concretamente:

1. `state_t` se registra antes de aplicar la acción;
2. `reward_t` utiliza la referencia visible en ese estado;
3. solo después del reward, la EMG recién leída actualiza la referencia;
4. `R_(t+1)` se obtiene de la procedencia del decoder;
5. `L_(t+1)` usa `q_(t+1)` y `q_ref,(t+1)`;
6. los nuevos bits aparecen por primera vez en `state_(t+1)`.

El replay independiente de las 21 decisiones del smoke produjo:

- mismatches de `R_t`: 0;
- mismatches de `L_t`: 0;
- inicialización `R_0=L_0=1`: confirmada;
- observaciones no finitas: 0;
- observaciones fuera de límites: 0.

La procedencia observada fue una inicialización, 11 decisiones `decoderRest` y
9 `movingReference`. El smoke no produjo `activeCountdownZero`; esa transición
se verificó de forma determinista en el test sintético preinscrito.

## 6. Divergencia semántica controlada

Se verificaron cuatro transiciones puras:

| Caso | L anterior | R | E | Cerca | L siguiente |
|---|---:|---:|---:|---:|---:|
| inicialización cercana | 0 | 1 | 0 | 1 | 1 |
| reposo lejano con memoria | 1 | 1 | 0.0004 | 0 | 1 |
| countdown cercano | 1 | 0 | 0 | 1 | 0 |
| reposo lejano sin memoria | 0 | 1 | 0.0004 | 0 | 0 |

El caso de countdown demuestra la diferencia requerida: un contrato puramente
geométrico activaría el hold porque `E=0`, pero la semántica causal obliga
`R=0,L=0` y libera la memoria inmediatamente.

## 7. Equivalencia emparejada 60 frente a 62

Se utilizaron la misma calibración sintética, seed 11, EMG, acciones, reward,
cuantización y simulador. Resultados máximos en 20 transiciones:

| Comparación | Diferencia máxima |
|---|---:|
| primeros 60 componentes | 0 |
| reward | 0 |
| posición/velocidad de referencia | 0 |
| acción cruda | 0 |
| acción efectiva | 0 |
| PWM simulado | 0 |
| intervención de seguridad | 0 |

La tolerancia preinscrita fue `1e-12`. Todos los valores observados fueron
exactamente cero, no solo inferiores a la tolerancia.

La ruta `intentMarkov60` conservó `intentProvenanceLog.schemaVersion=1` y no
recibió los campos semánticos nuevos. La ruta 62 usa versión 2 y registra:

- reposo, latch y MSE antes de la transición;
- reposo, latch, cercanía y MSE después;
- tolerancia efectiva y versión del contrato.

El archivo de episodio guarda además el estado semántico final y la tolerancia.
Estos datos no entran en `rewardContext`.

## 8. Gates, pruebas y correcciones de desarrollo

Los 15 gates preinscritos pasaron:

- dimensión candidata 62;
- bits en 61/62;
- default histórico `markov52` preservado;
- perfil solo simulado;
- prefijo 60, reward, referencia, actuador y seguridad sin diferencias;
- cero mismatches de ambos bits;
- inicialización correcta;
- cuatro transiciones semánticas correctas;
- divergencia de countdown demostrada;
- observaciones finitas y acotadas;
- pruebas específicas completas.

Pruebas del launcher:

- 23/23 PASS: 10 de 7M, 7 de `intentMarkov60` y 6 de fuentes de referencia;
- 0 failed;
- 0 incomplete.

Regresión completa `tests/no_glove`:

- 166/166 PASS;
- 0 failed;
- 0 incomplete;
- 59.695090 s.

`checkcode`: 0 mensajes en los trece archivos MATLAB nuevos o modificados
comprobados.

La primera ejecución de las pruebas 7M detectó dos defectos de ensamblaje:

- `rlNumericSpec` recibía primero límites de longitud 60 antes de añadir los dos
  bits;
- un mensaje de validación se construyó como arreglo de strings.

Ambos se corrigieron antes del commit de implementación y de la corrida
canónica. No se cambiaron recurrencia, umbral, alineación, gates o clasificación.

## 9. Reproducibilidad y artefactos

Comando canónico:

```matlab
cd('C:/Users/Cesarbmm/ProtesisPracticas_no_glove_intent_control/EMG_Prosthesis_TD3/matlab_code');
addpath(genpath(pwd));
run_no_glove_stage7m_observable_hold_state(struct( ...
    'resultsRoot','C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7m_artifacts/stage7m_final', ...
    'stage7lRunRoot','C:/Users/Cesarbmm/ProtesisPracticas_no_glove_stage7l_artifacts/stage7l_final/2026-08-28_21-44-35-302', ...
    'randomSeed',11,'smokeStepCount',20));
```

Artefacto canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7m_artifacts\stage7m_final\2026-08-29_00-58-24-394`

Reproducción independiente:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7m_artifacts\stage7m_repro\2026-08-29_00-58-50-646`

Nueve CSV y `offline_report.md` fueron idénticos por SHA-256 entre ambas
corridas. Los manifiestos, MAT y comandos reproducibles contienen fechas o rutas
de ejecución y no se usaron como criterio de identidad binaria.

Artefactos: `manifest.json`, `stage7m_results.mat`, `layout_audit.csv`,
`configuration_audit.csv`, `paired_equivalence_audit.csv`,
`runtime_alignment_audit.csv`, `semantic_transition_audit.csv`,
`gate_checks.csv`, `source_decision.csv`, `parent_audit.csv`,
`source_hashes.csv`, `test_results.mat`, `offline_report.md` y
`reproducible_command.txt`.

## 10. Seguridad, riesgos y siguiente etapa propuesta

Confirmaciones:

- hardware usado: no;
- COM o PWM físico: no;
- `simMotors=true` durante ambos smokes;
- agente cargado: no;
- entrenamiento: no;
- DTW: no;
- reward modificado: no;
- referencia, acción, cuantización, simulador o seguridad modificados: no;
- default global de observación modificado: no;
- 7J reautorizado: no;
- ablación conductual autorizada: no.

Riesgos y límites:

- el smoke contiene solo 20 pasos y datos sintéticos;
- el countdown se validó mediante transición sintética, no apareció en la
  trayectoria emparejada;
- la equivalencia exacta solo demuestra ausencia de regresión en las trayectorias
  ejecutadas;
- ningún agente ha aprendido a utilizar los bits 61/62;
- la política de 60 entradas no es dimensionalmente compatible con el estado 62;
- el corpus 7L provenía de seed 11 y el latch 7L coincidió con 7J en sus datos;
- no existe evidencia nueva de mejora de tracking, saturación o seguridad;
- no se identificó una causa raíz única de saturación.

El archivo local ajeno `matlab_code.zip` permaneció sin seguimiento y no fue
modificado. El manifiesto canónico registra `gitTrackedDirty=false`.

La siguiente etapa propuesta, no ejecutada, es **ETAPA 7N — smoke conductual
emparejado 60 frente a 62**:

1. preinscribir un único cambio de estado, manteniendo target, reward,
   cuantización, simulador y calibración;
2. crear desde cero dos TD3 feedforward, sin pesos de Agent7250/Agent200;
3. ejecutar como máximo 200 episodios con seed 11 por variante;
4. publicar todos los checkpoints y no seleccionar solo el mejor;
5. comparar tracking de intención, acción, `deltaActionL2`, saturación, reposo,
   `farStarted` y uso de los bits;
6. exigir cero NaN/Inf, cero violaciones y no inferioridad preinscrita antes de
   proponer cualquier piloto;
7. detenerse antes de multisemilla, campaña, DTW o hardware.

No se ejecutó ETAPA 7N.
