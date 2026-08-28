# ETAPA 7I — Auditoría offline del soporte de la condición de hold

Fecha de ejecución: 2026-08-28  
Rama: `experiment/no-glove-intent-control`  
SHA base de `main`: `6b213ba5c624fffb3f1094585c67d9c8ac43b737`  
SHA de la corrida canónica: `68232df0893c95ae8a0b606cd6f3f4259e857848`  
Preinscripción: `52c454758a9a3c942fcf7148e65d5ed9c16a5bd3`

## 1. Pregunta y alcance

ETAPA 7H comparó dos TD3 nuevos de 200 episodios, seed 11, que diferían
únicamente en `intentHoldActionWeight`: control `0` y candidata `0.20`. Su gate
no pasó porque la condición de hold quedó activa solo en una fracción insuficiente
del reposo. ETAPA 7I pregunta, sin cambiar la conducta, si ese problema puede
resolverse con otra tolerancia de posición que preserve la separación respecto a
correcciones mecánicas lejanas.

Esta etapa es estrictamente diagnóstica y offline. No carga los objetos Agent200,
no carga Agent7250, no crea `Env`, no llama al simulador, no evalúa ninguna función
de reward, no entrena, no calcula DTW y no cambia target, estado, reward,
cuantización, seguridad o simulador. Los checkpoints solo se someten a SHA-256.

La salida de ingeniería es `PASS`: se pudo reconstruir y auditar íntegramente el
corpus. La salida científica es:

`holdSupportNotSeparableFromFarCorrection`

La clasificación no identifica una causa raíz. Demuestra que un aumento escalar
de la tolerancia actual no satisface simultáneamente los dos criterios
preinscritos en los datos congelados.

## 2. Entradas congeladas y trazabilidad

Padre 7H canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7h_artifacts\stage7h_final\2026-08-28_16-00-33-357`

SHA-256 de su manifiesto:

`8EFE955A4010F50A4028A939FC6265256BF7AB8D43A49B2A4671DF9C582FDFE8`

Hijos congelados:

| Variante | `w_hold` | Episodios training | acceptance | steady rest | SHA-256 Agent200 |
|---|---:|---:|---:|---:|---|
| control | 0 | 200 | 50 | 24 | `010EF2D8A6278875C04E4B62C0CD444B84FA38542E2ECBDDB4913DBD7D0B4D4F` |
| candidate | 0.20 | 200 | 50 | 24 | `F68065DDB018B0460BC999EBEAA5C7B2C089857E2AA438C5BE32D394BF9AD6C6` |

En total se inventariaron y verificaron por SHA-256 548 archivos
`episode*.mat`. Se cargaron 31 220 ventanas:

| Fuente | Ventanas por variante | Episodios por variante |
|---|---:|---:|
| training | 12 200 | 200 |
| acceptance | 3 050 | 50 |
| steady rest | 360 | 24 |

Los hashes se calcularon antes y después del análisis. Las tablas completas son
idénticas y los inputs permanecieron sin cambios.

Agent7250 permaneció congelado en
`matlab_code/checkpoints/canonical/Agent7250_valid_baseline/Agent7250_valid_baseline.mat`.
Su SHA-256 observado fue
`0E6B986B76FCAA63B067EA023809864D5DA9DB038B756C4726E02A59C106FD54`.
No fue cargado ni usado como punto de partida.

## 3. Reconstrucción causal

Para cada fila de `stateLog`, el layout `intentMarkov60` se interpreta como:

\[
s_t=[\phi_{EMG,t}(40),q_t(4),\Delta q_t(4),u_{eff,t-1}(4),
q_{ref,t}(4),v_{ref,t}(4)].
\]

La auditoría extrae `q_t`, `q_ref,t` y `v_ref,t` de esa misma fila. Para cada
ventana calcula:

\[
E_t=\operatorname{mean}_{m=1}^{4}(q_{m,t}-q_{ref,m,t})^2,
\qquad
V_t=\max_m |v_{ref,m,t}|.
\]

Con la tolerancia de velocidad congelada
`epsilon_v = 1e-12`, la referencia está detenida si:

\[
S_t=\mathbb{1}[V_t\le\epsilon_v].
\]

Para una tolerancia de posición candidata `epsilon_q2`, la condición exacta es:

\[
H_t(\epsilon_{q^2}) =
S_t\,\mathbb{1}[E_t\le\epsilon_{q^2}].
\]

La configuración 7H usaba `epsilon_q2 = 1e-4`. La auditoría reproduce además
los cinco campos registrados por el reward:

\[
\begin{aligned}
\texttt{holdActive}_t &= H_t(10^{-4}),\\
\texttt{holdPositionMse}_t &= E_t,\\
\texttt{holdVelocityMaxAbs}_t &= V_t,\\
\texttt{holdActionL2}_t &= H_t(10^{-4})
\operatorname{mean}(u_{eff,t}^2),\\
\texttt{holdActionPenalty}_t &=w_{hold}\,
\texttt{holdActionL2}_t.
\end{aligned}
\]

El error absoluto máximo de replay en las 548 trazas fue
`2.77555756156289e-17`, compatible con redondeo de punto flotante y muy por debajo
de la tolerancia `1e-12`. No se encontraron NaN, Inf, dimensiones inválidas,
logs desalineados ni referencias variables dentro de `steadyRest`.

## 4. Estratos y gate preinscrito

El estrato de reposo es toda ventana de `steadyRest`. El estrato de corrección
lejana usa únicamente `training` y `acceptance`, exige referencia detenida y:

\[
E_t\ge 2.5\times10^{-3},
\]

equivalente a un RMS normalizado de posición de al menos 5%. Esto evita tratar
como peligrosa una corrección ya prácticamente finalizada.

Para cada tolerancia:

\[
C_{rest}(\epsilon)=
\frac{\#\{t\in rest:E_t\le\epsilon\}}{\#rest},
\]

\[
X_{far}(\epsilon)=
\frac{\#\{t\in far:E_t\le\epsilon\}}{\#far}.
\]

El gate exige simultáneamente:

\[
C_{rest}\ge0.90,
\qquad
X_{far}\le0.05.
\]

Antes de inspeccionar los valores se fijó el barrido exacto como la unión de
`{0, 1e-4, 2.5e-3, 1}`, todos los MSE detenidos observados y el punto de máquina
inmediatamente superior a cada valor. Así se evalúan todos los cambios posibles
de clasificación de una desigualdad `<=` sin una malla arbitraria.

## 5. Resultados del barrido exacto

| Variante | Cobertura de reposo con `1e-4` | Exposición lejana con `1e-4` | epsilon mínima para 90% de reposo | Exposición lejana en esa epsilon | Existe epsilon factible |
|---|---:|---:|---:|---:|---|
| control | 0.5333333333 | 0 | 0.0156202761961762 | 0.417705299941759 | no |
| candidate | 0.5333333333 | 0 | 0.240239761888969 | 0.592802172928927 | no |

El umbral actual evita por completo el estrato lejano, pero cubre solo 53.33% de
las ventanas de reposo. En la candidata, ampliar la tolerancia hasta obtener al
menos 90% de cobertura expone 59.28% de las ventanas detenidas de corrección
lejana. No existe ningún umbral exacto que cumpla 90%/5% en ninguna variante.

Por tanto, el cambio aislado `epsilon_q2` no es un candidato válido para otra
ablación de entrenamiento. Esto evita una campaña que mezclaría un aparente
aumento de exposición al hold con una penalización fuerte durante correcciones
que aún requieren acción.

## 6. Dinámica temporal de steady rest

La preinscripción distingue:

- elegibilidad inicial;
- mismatch inicial;
- primera transición elegible a no elegible;
- reentradas;
- corrida elegible más larga;
- fracción elegible del episodio.

Si la primera salida ocurre en el paso `t`, el comando y la intervención de
seguridad asociados causalmente se toman del paso precedente `t-1`.

| Métrica | control | candidate |
|---|---:|---:|
| episodios | 24 | 24 |
| mismatch inicial | 0 | 0 |
| episodios que salen de la región | 0.5 | 0.5 |
| paso medio/mediano de primera salida | 2 / 2 | 2 / 2 |
| reentradas medias | 0 | 0 |
| corrida elegible media más larga | 8 | 8 |
| fracción elegible media | 0.5333333333 | 0.5333333333 |
| `mean(abs(PWM_{t-1}))` al salir | 120 | 183.75 |
| `mean(u_eff,t-1^2)` al salir | 0.2559015763 | 0.5688927336 |
| salida precedida por intervención de seguridad | 0 | 1 |
| salto medio de MSE al salir | 0.01492304788 | 0.2402397619 |

Los 24 episodios comienzan elegibles. En 12 episodios por variante la condición
se desactiva ya en el paso 2 y no reentra; los otros 12 permanecen elegibles.
La evidencia muestra una condición que puede autoextinguirse después del primer
comando. En la candidata, todas las salidas observadas estuvieron precedidas por
una intervención de seguridad registrada. Esto es asociación temporal en el
simulador, no prueba de causa raíz, corriente eléctrica ni comportamiento de
hardware.

## 7. Diagnóstico suave fijo

Como análisis secundario no usado para selección ni gate, se calculó:

\[
g_\tau(t)=S_t\exp(-E_t/\tau),
\quad
\tau\in\{10^{-4},5\cdot10^{-4},10^{-3},2.5\cdot10^{-3}\}.
\]

Para la candidata, el peso medio en reposo fue `0.5333333333` con los cuatro
valores de `tau`; la mitad de las trazas conserva MSE cero y la otra mitad queda
tan lejos que el término exponencial es prácticamente cero. Los pesos medios en
corrección lejana fueron respectivamente
`1.7972e-14`, `1.6839e-4`, `0.00442246` y `0.04002716`.
Este diagnóstico respalda que suavizar localmente la frontera no recupera las
ventanas de reposo que ya se alejaron mucho, pero no autoriza cambiar el reward.

## 8. Implementación y artefactos

Archivos de código:

- `matlab_code/src/evaluation/loadNoGloveStage7iHoldSupportCorpus.m`;
- `matlab_code/src/evaluation/analyzeNoGloveStage7iHoldSupport.m`;
- `matlab_code/tests/no_glove/testNoGloveStage7iHoldSupport.m`;
- `matlab_code/workflows/published/run_no_glove_stage7i_hold_support_audit.m`;
- entrada añadida a `matlab_code/workflows/published/README.md`.

Artefacto canónico:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_final\2026-08-28_17-54-13-526`

Reproducción independiente:

`C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7i_artifacts\stage7i_repro\2026-08-28_17-55-28-441`

Las 12 tablas CSV y `offline_report.md` comparadas entre ambas corridas tienen
SHA-256 idéntico. `episode_input_hashes.csv` también es idéntico. Los archivos
MAT y el manifiesto contienen metadatos de creación/ruta y no se usan como
criterio de identidad binaria.

Artefactos principales: `manifest.json`, `stage7i_results.mat`,
`window_corpus.csv`, `epsilon_curve.csv`, `support_decision.csv`,
`rest_episode_timeline.csv`, `rest_exit_audit.csv`, `timeline_summary.csv`,
`stratum_summary.csv`, `soft_gate_summary.csv`, `source_decision.csv`,
`episode_audit.csv`, `episode_input_hashes.csv`, `profile_audit.csv`,
`test_results.mat`, `offline_report.md` y `reproducible_command.txt`.

## 9. Pruebas y controles de ejecución

Pruebas específicas 7I: 7/7 PASS. Cubren los casos separable y no separable,
índices temporales `t-1`, taus suaves fijos, corpus inválido, replay de un fixture
MAT y opciones del launcher que cierran ante error.

Regresión completa `matlab_code/tests/no_glove`: 136/136 PASS, 0 failed,
0 incomplete. `checkcode` en los cuatro archivos MATLAB nuevos: 0 mensajes.

La primera tentativa canónica se detuvo antes de cargar episodios porque el
presupuesto está en `manifest.protocol.episodes`, no en un campo raíz. La segunda
se detuvo también antes del corpus porque `intentHoldRewardEnabled` pertenece al
manifiesto y no al perfil MAT. Ambos contratos se corrigieron de forma fail-closed
y se registraron en commits separados. Las carpetas incompletas se conservaron:

- `stage7i_final/2026-08-28_17-52-21-597`;
- `stage7i_final/2026-08-28_17-53-19-083`.

No contienen resultados científicos válidos y no se mezclaron con la corrida
canónica.

## 10. Riesgos, límites y propuesta posterior

- El corpus procede de una sola semilla y un presupuesto smoke de 200 episodios;
  la clasificación es válida para estas trazas congeladas, no una garantía
  universal.
- El estrato lejano es una definición diagnóstica preinscrita. No prueba que toda
  ventana incluida requiera el mismo controlador ni que la saturación tenga una
  causa única.
- Las intervenciones de seguridad y PWM son comandos simulados; no son mediciones
  de corriente.
- Un gate suave con los cuatro taus fijados fue solo una métrica. No se optimizó
  ni se aplicó.
- No se autoriza piloto, campaña larga, DTW ni hardware.

La siguiente etapa propuesta, aún no ejecutada, es **ETAPA 7J — contrato causal
de hold enclavado, únicamente offline**. Debe preinscribir y reejecutar sobre las
mismas trazas una máquina de estados causal que active hold solo tras referencia
detenida y error pequeño, lo mantenga enclavado mientras continúe la intención de
reposo y lo libere ante movimiento de referencia. El objetivo es impedir que el
propio error creado tras un comando desactive inmediatamente la regularización,
sin penalizar una corrección que ya comenzó lejos del target. Antes de cualquier
entrenamiento deberá demostrar cobertura de reposo >=90%, exposición lejana <=5%,
ausencia de fuga futura y especificar cómo hacer visible la memoria del latch
para preservar Markov (por ejemplo, una variante explícita de estado). Si falla,
se cancela esta familia de rewards condicionadas; si pasa, una etapa posterior
podrá proponer una ablación de un solo factor.

No se ejecutó ETAPA 7J.
