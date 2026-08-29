# ETAPA 7J — Auditoría offline del contrato causal de hold enclavado

Fecha de ejecución: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
SHA de la corrida canónica: `69f2ae5494bba2ad3cf567e7dd0c01e623d790e7`  
Preinscripción: `2de6cb380a97d7a34653a3774216816cc1ea7aa7`

## 1. Resultado y alcance

Resultado de ingeniería: `PASS`.

Resultado científico preinscrito:

`latchedHoldNotSeparableFromFarCorrection`

Contrato soportado: `false`.

ETAPA 7J evaluó si una memoria causal evita la autoextinción del término de hold
observada en 7I. La evaluación fue exclusivamente offline sobre las 31 220
ventanas ya validadas de 548 episodios congelados. No se implementó el latch en
`Env`, estado o reward; no se cargó una política, no se simuló, no se entrenó, no
se calculó DTW y no se utilizó hardware.

El latch recuperó toda la exposición de reposo y fue causal, pero excedió el
límite conservador de exposición lejana. Por la regla preinscrita, no se autoriza
`intentHoldMarkov61` ni una ablación conductual.

## 2. Entradas y trazabilidad

Padre 7I canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_final\2026-08-28_17-54-13-526`

Hashes principales:

| Entrada | SHA-256 |
|---|---|
| `manifest.json` 7I | `BA877BD451FCAA930C2F8471D469E38DDEA75846F41DD2B6567A621E177A4258` |
| `stage7i_results.mat` | `4FA61C9F2319CCD343786F3B5F73A992846D7552AC2A6ADD5A2E038FE1EE7F34` |
| `window_corpus.csv` | `61C51B2FF98B2D33103F63C75F806458687FB59E0DE7819AF069CBFD9DF3D175` |
| inventario de episodios | `55FBAFB354FB8E6F8CC9D82B0E9FD6D26CFF48296BFDEF11C34515B796B434DC` |

Los 548 episodios originales se recalcularon por SHA-256 antes y después del
replay. El inventario fue exactamente igual al publicado en 7I y permaneció sin
cambios.

Agent7250 permaneció congelado. Solo se verificó el SHA-256 de su archivo:

`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`

No se deserializó ni se utilizó como punto de partida.

## 3. Definición matemática

Desde cada fila congelada `intentMarkov60`:

\[
E_t=\operatorname{mean}_{m=1}^{4}(q_{m,t}-q_{ref,m,t})^2,
\qquad
V_t=\max_m|v_{ref,m,t}|.
\]

La preinscripción fijó, antes del replay real:

\[
\epsilon_v=10^{-12},\qquad
\epsilon_{entry}=10^{-4},\qquad
\epsilon_{far}=2.5\times10^{-3}.
\]

Se define referencia detenida y entrada cercana:

\[
S_t=\mathbb{1}[V_t\le\epsilon_v],
\qquad
N_t=\mathbb{1}[E_t\le\epsilon_{entry}].
\]

La condición instantánea de 7H era:

\[
H_t=S_tN_t.
\]

El latch 7J se reinicia en cada episodio y se actualiza en orden temporal:

\[
L_t=
\begin{cases}
0,&S_t=0,\\
1,&S_t=1\land N_t=1,\\
L_{t-1},&S_t=1\land N_t=0.
\end{cases}
\]

Por tanto, entra únicamente con referencia detenida y error pequeño, conserva
memoria aunque el error posterior crezca y se libera en el primer paso donde la
referencia vuelve a moverse. Se fijaron `n_on=1` y `n_off=1`; no se realizó
barrido de parámetros.

Una ventana es recuperada por memoria si:

\[
L_t=1\land H_t=0.
\]

## 4. Gate preinscrito

Se conservó sin redefinir el estrato conservador de 7I:

- reposo: todas las ventanas `steadyRest`;
- corrección lejana: `training` o `acceptance`, referencia detenida y
  `E_t>=2.5e-3`.

El contrato debía cumplir simultáneamente:

\[
C^{latch}_{rest}=\operatorname{mean}_{rest}(L_t)\ge0.90,
\]

\[
X^{latch}_{far}=\operatorname{mean}_{far}(L_t)\le0.05.
\]

También exigía cero activaciones antes de convergencia en segmentos que
comenzaron lejos, equivalencia causal por prefijos, integridad de inputs y al
menos una ventana recuperada por memoria.

## 5. Resultado por variante

| Métrica | control | candidate |
|---|---:|---:|
| ventanas | 15 610 | 15 610 |
| cobertura instantánea de reposo | 0.5333333333 | 0.5333333333 |
| cobertura de reposo con latch | 1 | 1 |
| ganancia absoluta | 0.4666666667 | 0.4666666667 |
| ventanas recuperadas | 1 825 | 2 133 |
| fracción recuperada total | 0.1169122357 | 0.1366431775 |
| exposición lejana con latch | 0.1891671520 | 0.2080126754 |
| ventanas del estrato lejano | 8 585 | 8 836 |
| activaciones prematuras | 0 | 0 |
| entradas | 274 | 274 |
| liberaciones | 250 | 250 |
| episodios de reposo con cobertura completa | 24/24 | 24/24 |
| cobertura mínima por episodio de reposo | 1 | 1 |

La candidata supera el gate de reposo, pero su exposición lejana es 20.8013%,
más de cuatro veces el límite del 5%. El orden de clasificación preinscrito obliga
a concluir `latchedHoldNotSeparableFromFarCorrection`.

## 6. Procedencia temporal de la exposición lejana

Cada segmento detenido se clasificó por el MSE de su primer paso. Un segmento
`farStarted` comienza con `E>=2.5e-3`. Antes de su primera convergencia a
`E<=1e-4`, cualquier latch habría sido prematuro.

En la candidata:

| Fuente | Segmentos que comienzan cerca | ventanas lejanas enclavadas | segmentos que comienzan lejos | ventanas lejanas en estos segmentos | ventanas enclavadas allí |
|---|---:|---:|---:|---:|---:|
| training | 200 | 1 513 | 800 | 5 598 | 0 |
| acceptance | 50 | 325 | 200 | 1 400 | 0 |

Las 1 838 ventanas lejanas enclavadas que producen
`1838/8836 = 0.2080126754` pertenecen a segmentos que comenzaron cerca y luego se
alejaron. Ninguno de los 1 000 segmentos `training/acceptance` que comenzaron
lejos activó el latch, y hubo cero activaciones antes de convergencia.

Este resultado revela que el estrato conservador de 7I mezcla dos procedencias:

1. una referencia que ya estaba detenida y cerca cuando se enclavó, pero luego
   acumuló error;
2. una referencia detenida cuya corrección comenzó lejos.

La máquina distingue causalmente ambas procedencias, pero el gate preinscrito no
permite reclasificarlas después de observar el resultado. Por ello el contrato
falla. La descomposición no es una excepción al gate ni una autorización para
entrenar; muestra una limitación semántica pendiente del etiquetado de intención
de reposo.

## 7. Exposición a acción y seguridad registrada

La métrica contrafactual fue:

\[
A_L=\operatorname{mean}_t\left[
L_t\operatorname{mean}_m(u_{eff,m,t}^2)\right].
\]

No se invocó el reward y no se calculó una recompensa nueva.

| Métrica | control | candidate |
|---|---:|---:|
| exposición instantánea media | 0.0233681130 | 0.0188341531 |
| exposición enclavada media | 0.0571109188 | 0.0843605421 |
| PWM absoluto medio en ventanas recuperadas | 123.7907 | 159.5601 |
| ventanas recuperadas con intervención de seguridad | 0.507397 | 0.909986 |

En `steadyRest`, la candidata recuperó 168 ventanas y todas tenían intervención
de seguridad registrada; su PWM absoluto medio fue 184.3214. Estos valores son
comandos y eventos del simulador congelado, no mediciones de corriente ni prueba
de causalidad física.

## 8. Causalidad, Markov y decisión de arquitectura

Se ejecutaron 548 comparaciones por prefijo, una por episodio. Cada episodio se
recalculó completo y truncado a mitad; las salidas anteriores al corte fueron
idénticas:

- verificaciones por prefijo: 548;
- mismatches: 0;
- activaciones prematuras: 0.

La candidata recupera 2 133 ventanas donde `L_t=1` pero la condición instantánea
`H_t=0`. Por tanto, la memoria es material y no debe ocultarse dentro del entorno.
Una implementación futura requeriría una observación explícita, por ejemplo:

\[
s_{61}=[s_{60},L_t].
\]

Sin embargo, `intentHoldMarkov61` no fue creado porque el gate global falló.
`intentMarkov60` permanece sin cambios y no se autorizó ninguna ablación.

## 9. Implementación, pruebas y reproducibilidad

Archivos creados:

- `docs/no_glove_experiment/07j_preregistration.md`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7jCausalLatch.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7jCausalLatch.m`;
- `matlab_code/workflows/published/run_no_glove_stage7j_causal_hold_latch_audit.m`.

Se actualizó `matlab_code/workflows/published/README.md`.

Pruebas finales:

- específicas 7J: 8/8 PASS, 0 failed, 0 incomplete;
- regresión completa `tests/no_glove`: 144/144 PASS, 0 failed,
  0 incomplete, 24.9102 s;
- `checkcode`: 0 mensajes en los tres archivos MATLAB nuevos.

La primera ejecución de pruebas sintéticas obtuvo 7 PASS y 1 FAIL porque el
fixture etiquetado como soportado incluía por error una ventana `E=0.01` después
de enclavarse, que correctamente pertenecía al estrato lejano. Solo se corrigió
el fixture a `E=0.001`; no se cambió algoritmo, umbral, gate ni orden de
clasificación. La suite final pasó íntegramente antes del corpus canónico.

Artefacto canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7j_artifacts\stage7j_final\2026-08-28_21-02-19-544`

Reproducción independiente:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7j_artifacts\stage7j_repro\2026-08-28_21-03-35-876`

Diez CSV y `offline_report.md` fueron idénticos por SHA-256 entre ambas corridas.
Los MAT y manifiestos contienen rutas/fechas y no se usaron como criterio de
identidad binaria.

Artefactos principales: `manifest.json`, `stage7j_results.mat`,
`window_latch_audit.csv`, `stopped_segment_audit.csv`,
`rest_episode_audit.csv`, `source_summary.csv`, `variant_summary.csv`,
`gate_checks.csv`, `source_decision.csv`, `source_hashes.csv`,
`episode_input_hashes.csv`, `parent_audit.csv`, `test_results.mat`,
`offline_report.md` y `reproducible_command.txt`.

## 10. Riesgos y propuesta posterior

- El resultado usa una sola seed y políticas smoke de 200 episodios.
- El latch satisface causalidad y cobertura, pero falla el gate conservador de
  exposición; no debe aplicarse selectivamente tras observar la procedencia.
- `v_ref=0` no conserva en los logs 7I la razón explícita de reposo: salida de la
  histéresis del decodificador, cancelación de sinergias u otra causa.
- No se identificó causa raíz única de saturación o comandos altos.
- El latch `S/E` de esta etapa queda cancelado como cambio conductual.
- No hay autorización de piloto, campaña, DTW ni hardware.

La siguiente etapa propuesta, no ejecutada, es **ETAPA 7K — auditoría de
procedencia causal de intención cero**. Debe primero buscar en los datasets y
logs existentes una etiqueta causal del estado de reposo/histéresis. Si no
existe, puede proponer instrumentación exclusivamente de logging que registre
`intentRestActive`, activación agregada, motivo de `v_ref=0` y límites del
generador, sin cambiar target, acción, reward, estado o seguridad. Con Agent200
congelado y sin entrenamiento, deberá distinguir segmentos detenidos por reposo
decodificado de correcciones o cancelaciones, demostrar alineación temporal y
reproducibilidad y detenerse antes de reconsiderar cualquier latch. Si no puede
obtenerse una etiqueta causal auditable, se abandona esta familia de hold
condicionado.

No se ejecutó ETAPA 7K.
