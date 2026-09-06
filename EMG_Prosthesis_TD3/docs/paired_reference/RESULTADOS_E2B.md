# E2B — contrato supervisado y factibilidad de control

**E2B_RESULT = FAIL. RL_AUTHORIZED = NO.** P con Kp=2 reduce el MSE un 72.60 % y
mejora reward frente a cero, pero incumple el gate preregistrado de ciclos
persistentes. Además aparecen retrocesos operativos de M3 bajo PWM positivo.
No se cambian curvas, periodo, cuantización, reward ni controlador para rescatar
el resultado. **E3 no preparada ni ejecutada. 59/59 tests pasan.**

Preregistro: 2026-09-05; cierre documental: 2026-09-06. Rama
`experiment/no-glove-paired-reference-td3`, inicio `fc2e15bb931b79f41be6ce1c3c822dd88a8e9c40`.
Origin consultado: `c08b784bf4759c70a9bc2d10f0b44f638a61526a`, distancia inicial `1 0`.
Se leyeron completos E2A, E1D, E0P, DECISIONES, BACKLOG y roadmap antes de implementar.
No existía trabajo E2B previo. Se preservó el residuo FUSE no rastreado; durante la
sesión aparecieron carpetas ajenas `Claude outputs/` y `matlab_code/sandbox_physics/`,
que se conservaron y excluyeron del commit y de las comparaciones E2B.

### Incidencia Git y aislamiento de la entrega

Al cerrar la auditoría, el worktree original estaba en
`experiment/physical-plant-sandbox`, HEAD `47e3925fb16e462659781117f18a7b88f16f2b81`.
El reflog registra un commit ajeno `583228aef27c026da8cfd2c376853916e0e6f47a`
sobre paired-reference y después el cambio de rama. Esas operaciones no pertenecen
a E2B. No se resetearon ramas ni se borró, movió o revirtió ese trabajo.

Se creó `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit` con la rama obligatoria
`experiment/no-glove-paired-reference-td3`, conservando `583228ae` como padre
preexistente. Allí se copiaron exclusivamente los archivos E2B, verificando sus
hashes. El diff de `fc2e15bb` a ambos commits ajenos es vacío en src, configuración,
agentes, dataset, checkpoints, tests paired-reference y documentación científica.
Por tanto esos commits no alteraron el código científico usado en E2B. Se volvió
a ejecutar la batería completa en el worktree aislado antes del commit local.

Los manifiestos de la medición conservan sus rutas originales: describen dónde se
obtuvieron los datos. El worktree original y sus modificaciones se conservan; la
entrega E2B está en el worktree aislado. El commit E2B no incluye archivos sandbox.

## 1. Contrato causal de entrenamiento

El mapa de [E2A](11_RESULTADOS_E2A.md) se conserva:

```text
EMG -> 40 WMoos -----------------------------------+
encoder -> normalización + delta ------------------+-> markov52 -> actor -> acción
acción efectiva anterior -------------------------+                        |
                                                         remapeo -> PWM -> planta

guante -> referencia -> reward / tracking -> targets de critic -> pesos futuros
guante -> disponibilidad / reset / done ------------^
```

El guante no es entrada de markov52, del actor, de los críticos, del estado de
acción previa ni de la transición de planta. Los críticos reciben observación y
acción. Sí modifica el aprendizaje futuro mediante reward y done. El controlador
P de esta auditoría **sí** accede al teacher ya leído: es un diagnóstico privilegiado
de controlabilidad, no una política desplegable sin guante.

Fuentes del repositorio relativas a `matlab_code/`:

| Relación | Evidencia |
|---|---|
| Estado y entradas de red | `src/@Env/calculateState.m:15–27`; `agents/agentTd3.m:39,45,67,73,95`. |
| Acción efectiva previa y estado antes de reward | `src/@Env/step.m:117–120`. |
| Guante → referencia/reward | `src/@Env/step.m:123–125`; `src/reward_functions/trackingMseActionRateReward.m:10–26`. |
| Disponibilidad de reset | `src/@Env/reset.m:101–104,120–121,148–149,162`: construye, lee y exige ambos lectores. |
| Estado inicial numérico sin valores de guante | `src/@Env/reset.m:186–191`. |
| Terminación histórica | `src/@Env/checkEndEpisode.m:14`: `myo.exhausted || glove.exhausted`. |

El código instalado de MATLAB R2023b, `+rl/+agent/rlTD3Agent.m:418–428`, suprime
bootstrap cuando `IsDone==1`. La receta histórica usa N=1 y gamma=0.95. El término
esquemático es `r + gamma*(1-done)*min(Q_target1,Q_target2)`, con acción target
suavizada en TD3. Cambiar done altera el target aunque el actor no vea el guante.

**Decisión preregistrada y mantenida:** conservar disponibilidad teacher como
frontera del objetivo episódico supervisado. No afirmar que sea un terminal físico
de la prótesis. No inventar rewards posteriores mediante ceros, retención del último
valor o extrapolación. El reset histórico conserva su disponibilidad doble; la
ejecución E2A sigue terminando exclusivamente por EMG.

Un desacoplamiento correcto necesitaría definir truncación/bootstrap y el tratamiento
del reward desconocido. No se cambia silenciosamente done. La diferencia medida es
una limitación del protocolo; no se etiqueta automáticamente como data leakage.
markov52 tampoco contiene tiempo restante ni teacher: E2B no demuestra que ese
objetivo parcialmente observado sea plenamente Markov desde sus 52 componentes.

## 2. Disponibilidad de datos y efecto terminal

Se inventariaron **6160 episodios**, todas las filas/lados de los diez development.
No hubo filas inválidas. Se cargaron sólo sus variables `emgs` y `gloves`; los diez
archivos tienen hashes registrados. MATEO y SANDRA no se cargaron ni inspeccionaron.

Los lectores usan 200 Hz EMG / 10 Hz guante. Reset consume 40 / 2 muestras; cada
paso consume otras 40 / 2. Marcan agotamiento cuando `j>=n` después de incrementar
el índice, pudiendo dejar una muestra aislada. Para las longitudes ordinarias:

```text
h_EMG = ceil((n_EMG - 1)/40) - 1
h_teacher = ceil((n_teacher - 1)/2) - 1
h_histórico = min(h_EMG, h_teacher)
```

El helper y sus tests también cubren longitudes extremas, el agotamiento durante
reset y el primer step que Env fuerza después de reset. Esas condiciones no
afectan la muestra de control preregistrada. Los horizontes excluyen el bloque de
reset; las duraciones nominales `n/frecuencia` sí lo incluyen.

| Causa de terminación histórica | Episodios |
|---|---:|
| Sólo teacher agotado, EMG aún disponible | **6150 (99.8377 %)** |
| Ambos agotados | 9 |
| Sólo EMG agotada | 1: BLANCA, fila 122, cierre |

El teacher temprano deja sin consumir **344090 de 4107233 muestras EMG: 8.37766 %**.
La media de fracciones por episodio es 8.66121 %. Son denominadores distintos.
El residuo atribuible únicamente a la condición `j>=n` suma una muestra adicional.
El horizonte histórico va de 8 a 24 pasos y el EMG-only de 9 a 25. Ningún episodio
alcanza el límite histórico de training de 50 pasos, que por tanto no interviene aquí.

En la tabla, H/E son las medias de pasos históricos/EMG-only; los descartes son
muestras atribuibles al teacher divididas por todas las muestras EMG del grupo.
Longitudes mínimas/medianas/máximas y distribución completa están en los CSV.

| Sujeto | Episodios cierre | Apertura | H/E cierre | H/E apertura | Descarte cierre % | Apertura % |
|---|---:|---:|---:|---:|---:|---:|
| BLANCA | 310 | 310 | 14.468 / 16.171 | 14.461 / 16.158 | 8.417 | 8.430 |
| CECILIA | 300 | 300 | 14.230 / 15.927 | 14.217 / 15.897 | 8.330 | 8.363 |
| DENIS | 300 | 300 | 14.210 / 15.873 | 14.220 / 15.887 | 8.443 | 8.429 |
| EMILIA | 300 | 300 | 14.207 / 15.920 | 14.227 / 15.840 | 8.517 | 8.298 |
| GABI | 310 | 310 | 14.197 / 15.829 | 14.171 / 15.826 | 8.271 | 8.390 |
| GABRIEL | 300 | 300 | 14.230 / 15.907 | 14.230 / 15.900 | 8.353 | 8.313 |
| IVANNA | 310 | 310 | 14.490 / 16.152 | 14.494 / 16.161 | 8.272 | 8.206 |
| JOE | 330 | 330 | 14.339 / 16.076 | 14.348 / 16.036 | 8.541 | 8.474 |
| JONATHAN | 300 | 300 | 14.227 / 15.880 | 14.203 / 15.900 | 8.340 | 8.480 |
| KHAROL | 320 | 320 | 14.147 / 15.753 | 14.122 / 15.762 | 8.264 | 8.410 |

En los 6150 episodios de teacher temprano, el factor de bootstrap en la transición
final pasa de 0 histórico a 0.95 si se usara done EMG-only. No se ejecutó ese cambio
en training. En los 200 episodios seleccionados se midió además
`0.95*min(Q1_online,Q2_online)` con críticos y actor congelados, sin smoothing:
media **−0.40360913**, rango **[−0.68861854, −0.17902550]**. Es sensibilidad instrumental
al enmascarado terminal; **no es el target real de training**, porque éste usa
críticos target privados y smoothing. No es una valoración de la calidad del critic.

## 3. Comparación de control preregistrada

[PREREGISTRO_E2B.md](PREREGISTRO_E2B.md) se guardó antes del inventario y comparaciones.
SHA256 congelado: `4883abc911701119f8312aede9accc9b697a6b4c450a1d8b5ff8ab8d85aa88f5`.

Se seleccionaron exactamente **200 episodios**: diez filas equiespaciadas por
sujeto, ambos lados, sin seleccionar por rendimiento. Se usó Env histórico real,
semilla 20260905, mismo q0 por controlador y planta canónica. Apertura se prepara
con dos resets consecutivos, como E2A; no representa una secuencia completa de
cierre y apertura ejecutada anteriormente.

P usa `clip(Kp*(r_before-h(q_before)),-1,1)`, donde
`h(q)=flexJoined_scale(encoder2Flex(q))`. La primera acción utiliza teacher 2 ya
leído; el primer reward utiliza teacher 4 tras el paso. No hay anticipación del
target futuro. La escala h(q) no es q normalizado de markov52: con q=0 tiene pisos
aproximados `[0.439883,0.439883,0.293255,0.439883]`. No se cambian esos pisos ni gaps.

Barrido fijo Kp=[0.5,1,2,4,8], un escalar común a los cuatro motores. Selección
única por menor MSE macro; todos los gates se aplican después a ese mismo Kp.
No se elige Kp=1 para evitar los fallos observados en Kp=2.

Macro significa: media temporal por episodio, media de episodios en cada
sujeto/lado, media de los 20 grupos. MSE/MAE incluyen cuatro motores por igual.
La selección usa development y la evaluación es descriptiva sobre development;
no es una estimación independiente de generalización.

| Controlador | MSE | MAE | Correlación media válida | Reward medio | actionL2 | deltaActionL2 |
|---|---:|---:|---:|---:|---:|---:|
| Cero | 0.09270421 | 0.24137937 | Indefinida | −0.09270421 | 0 | 0 |
| P 0.5 | 0.05588508 | 0.17049441 | 0.71727 | −0.05706577 | 0.03358430 | 0.01689688 |
| P 1 | 0.03347506 | 0.13565894 | 0.80115 | −0.03560771 | 0.05425776 | 0.03180136 |
| **P 2, seleccionado** | **0.02540034** | **0.11911571** | **0.81859** | **−0.03272838** | **0.11885135** | **0.12279054** |
| P 4 | 0.02670046 | 0.12154633 | 0.76126 | −0.05151582 | 0.31839407 | 0.43262838 |
| P 8 | 0.03125114 | 0.13406088 | 0.66540 | −0.08825855 | 0.59388971 | 1.02137025 |
| Agent7250, sólo diagnóstico | 0.04710527 | 0.16617158 | 0.50057 | −0.05901424 | 0.60367417 | 0.11744458 |

Las correlaciones se calculan por episodio/motor; si señal o referencia es constante,
son NaN y se conserva su contador de validez. No se reemplazan por cero o uno.
Agent7250 no decide el gate de rendimiento y no se compara con MSE de campañas
históricas: su fuente de planta de entrenamiento sigue desconocida.

### Descomposición del reward preservado

`reward = −MSE − 0.01*actionL2 − 0.05*deltaActionL2`, con acciones **efectivas** y
delta que incluye el primer salto desde acción previa cero. Se verificó contra
el reward real de Env en todos los pasos. El helper histórico
`summarizeEpisodeDirectory` excluye ese primer salto en su métrica de delta y suma
motores; por ello E2B calcula explícitamente la métrica coherente con reward, sin
modificar ese helper histórico.

| Controlador | Tracking term | Action penalty | Delta-action penalty | Reward medio |
|---|---:|---:|---:|---:|
| Cero | −0.0927042149 | 0 | 0 | −0.0927042149 |
| P 2 | −0.0254003364 | 0.0011885135 | 0.0061395272 | −0.0327283771 |
| Agent7250 diagnóstico | −0.0471052724 | 0.0060367417 | 0.0058722291 | −0.0590142433 |

Se guarda también la suma de reward por episodio; no sustituye al promedio principal
cuando las duraciones difieren.

### Coherencia por motor y gesto

| Motor | MSE cero | MSE P2 | MAE P2 | Correlación P2 | responseRange P2 | flat_response P2 | action_no_motion P2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.05291117 | 0.01265671 | 0.08666018 | 0.87949 | 0.24573 | 1.0 % | 34.98 % |
| 2 | 0.08657336 | 0.04249973 | 0.17227304 | 0.82578 | 0.19811 | 3.5 % | 63.73 % |
| 3 | 0.17166392 | 0.03198159 | 0.12574184 | 0.74908 | 0.54073 | 2.0 % | 34.21 % |
| 4 | 0.05966842 | 0.01446331 | 0.09178777 | 0.81962 | 0.26693 | 0.0 % | 46.17 % |

responseRange mide max(h(q))−min(h(q)), incluido reset. flat_response indica
rango <=1e-9; el porcentaje resume episodios. action_no_motion usa encoder crudo,
comando no nulo y |delta_q|<=1e-9, dividido por comandos activos del episodio y
agregado después por el esquema macro. Una flexión plana dentro del gap puede
coexistir con movimiento del encoder; no se confunden esos dos diagnósticos.

| Gesto | MSE cero | MSE P2 | Reward cero | Reward P2 |
|---|---:|---:|---:|---:|
| Cierre | 0.11979612 | 0.03194645 | −0.11979612 | −0.03783428 |
| Apertura | 0.06561230 | 0.01885423 | −0.06561230 | −0.02762247 |

P2 mejora MSE y reward en **10/10 sujetos**, con mejoras MSE de 67.00–80.16 %,
en ambas direcciones y los cuatro motores. Pasa los criterios de tracking/reward
preregistrados. Su éxito privilegiado no demuestra que las EMG permitan a TD3
aprender el mismo comportamiento; no reabre la hipótesis refutada E1–E1D.

### PWM y resolución: sólo los diagnósticos medidos

P2 tiene saturationFraction macro **0.76921 %**, definida como |effective|>=0.95
(PWM255 con los niveles actuales). La frecuencia macro |PWM|>=128 es **18.00853 %**;
agrupando comandos reales es **2004/11752 = 17.05242 %**. Son agregaciones distintas.
Para Agent7250, el valor agrupado aquí es **8705/11752 = 74.07250 %**. El dato E2A
**76.578947 %** sigue intacto: otra muestra y el horizonte completo EMG-only.
No se utiliza ninguno para cambiar actionCommandLevels, periodo, reward o TD3.
La distribución firmada completa por episodio/motor está en `pwm_distribution.csv`.

## 4. Fallos que bloquean E2B

### Dos ciclos del P seleccionado

El criterio se fijó antes de medir: dos destinos alternos durante las cuatro
transiciones finales, repetición dentro de 1e-9 encoder, signos PWM alternos y
amplitud >0.05 en espacio reward. Se observan **dos casos en 200 episodios / 800
combinaciones episodio-motor**:

| Episodio | Motor | Cinco posiciones sucesivas | Cuatro PWM | Amplitud h(q) |
|---|---:|---|---|---:|
| BLANCA, fila 1, cierre | 3 | 1541.6667 → 7532.5 → 1541.6667 → 7532.5 → 1541.6667 | +224, −64, +224, −64 | **0.554795** |
| IVANNA, fila 104, apertura | 4 | 6049.75 → 2976.3333 → 6049.75 → 2976.3333 → 6049.75 | −64, +96, −64, +96 | **0.256909** |

La referencia continúa variando: esto demuestra alternancia persistente en esa
ventana finita, no un teorema de ciclo límite indefinido con referencia constante.
Es suficiente para incumplir el criterio preregistrado. P4 presenta cuatro casos
y P8 diecinueve, registrados sin cambiar la selección Kp=2.

### Retrocesos operativos M3 y alcance real de E0P

Hay **520 transiciones con delta_q de signo opuesto al PWM**, todas en M3 y todas
con comando de cierre: **125 en P8** (52 cierre, 73 apertura del gesto) y **395 en
Agent7250 diagnóstico** (155 cierre, 240 apertura). P2 y cero tienen cero. El
máximo retroceso es **65 encoder**: CECILIA, fila 167, cierre, P8, paso 21,
PWM=+255, q=7603.666666666667 → 7538.666666666667.

Una regresión mínima independiente reproduce q=7584.5, PWM=+255, duración=0.2 s
→ 7566.666666666667. La búsqueda encuentra un punto y la lectura de la curva
200 índices después devuelve un valor menor: no es pérdida del fix HOLD.
Los comandos precedentes alcanzan posiciones que las rejillas uniformes E0P
no habían ensayado. La irregularidad de M3 conocida en estrés también puede
manifestarse en un paso operativo desde esas posiciones.

**Todas las 20566 trayectorias devueltas por el simulador coinciden exactamente
con el oráculo E0**, incluidos estos retrocesos. La fuente es canónica, las curvas
y límites conservan sus hashes y los 24 tests E0P pasan. Eso demuestra reproducción
del comportamiento histórico, no monotonicidad universal desde cualquier estado.
E2B amplía la cobertura y encuentra un límite real de esa afirmación.

Las 395 reversiones del checkpoint se usan como evidencia adicional de planta,
no como criterio de calidad de Agent7250. Incluso excluyéndolas, los dos ciclos
del P elegido y las 125 reversiones de P8 mantienen E2B FAIL.

No hay movimiento con PWM cero. Se registran 1081 excesos del bound heurístico
de salto, todos explicados por entrada a curva desde una posición anterior al
recorrido, como la caracterización E0P; cero excesos no explicados. Ese bound
no es un límite físico de velocidad validado. La comparación cubre la trayectoria
que devuelve la API, un punto por paso 0.2/0.14 s; no una auditoría continua a 1 ms.

## 5. Regresiones, archivos y reproducibilidad

A/B con Agent7250 se amplía a los **200 episodios** seleccionados: 2938 pasos
teacher y comunes frente a 3290 EMG-only. En los n+1 estados/posiciones y n acciones
raw/efectivas/PWM del horizonte común, las cinco diferencias máximas son **cero**.
Se verificó también el MAT completo; B no contiene campo reward. Actor y ambos
críticos conservaron exactamente sus parámetros. No se ejecutó train.

Primera batería completa: 56/56. Después del FAIL se añadieron **tres tests de
caracterización** que reproducen el retroceso M3 y los dos ciclos medidos. No son
una enmienda del gate ni convierten esos defectos en aceptación. La batería final
da **59/59 = 13 E2A + 24 E0P + 22 E2B**, sin fallos ni incompletos. Se verificaron
explícitamente las cardinalidades 13 y 24. El error del oráculo CSV E0 sigue siendo
`1.1641532182693481e-10` sobre 784 casos.

Una revisión independiente con Python estándar recalculó los 20566 pasos, 82264
comandos motor, escalas, P causal, remapeo, reward, métricas, correlaciones, selección
y todos los hashes development. Error máximo de reconstrucción reward desde CSV:
9.99e-16; correlación 3.35e-14; diferencias de encoder hasta 7.10e-11 por serialización
CSV, sin discontinuidad entre filas. Confirmó los ciclos, reversiones y gate FAIL.

Archivos en `matlab_code/analysis/paired_reference/e2b_results/`:

| Artefactos | Contenido |
|---|---|
| `teacher_availability.csv`, `availability_by_subject_side.csv` | Inventario completo, longitudes, horizontes, causas y descartes. |
| `selected_episodes.csv`, `dataset_provenance.json` | 200 selecciones y hashes de los diez archivos development. |
| `execution_contract.json`, `plant_manifest.json`, `policy_manifest.json` | Preregistro/hash, configuración efectiva, fuente canónica e instrumento congelado. |
| `trajectories.mat`, `step_traces.csv` | Trayectorias completas, q inicial, estados, referencias previas/posteriores, acciones, PWM y reward descompuesto. El MAT contiene además la rama EMG-only. |
| `episode_metrics.csv`, `episode_motor_metrics.csv` | Métricas por episodio, controlador y motor. |
| `controller_summary.csv`, `subject_side_summary.csv`, `motor_summary.csv` | Agregaciones macro y subgrupos. |
| `pwm_distribution.csv`, `transition_audit.csv` | Niveles firmados, contraste con E0 y caracterización de saltos. |
| `causal_ab.csv`, `done_online_sensitivity.csv` | Igualdad en horizonte común y sensibilidad instrumental al enmascarado terminal. |
| `test_results.csv`, `e2b_summary.json` | 59 tests finales y gate medido. |

Reproducción **sin RL**, desde `EMG_Prosthesis_TD3/matlab_code`, MATLAB nuevo:

```powershell
matlab -batch "addpath(genpath('src')); addpath('config'); addpath(genpath('lib')); addpath('analysis/paired_reference'); summary=runPairedReferenceE2B();"
```

El runner regenera su carpeta de resultados por defecto; permite `outputDir` alternativo.
El oráculo usa la función E0 congelada en una fixture temporal con ws numéricos vacíos
y límites ya validados. No reconstruye ni modifica el fit real ni ajusta curvas.
La ruta principal nunca usa legacyAuto. No se alteraron archivos históricos de
Env, reward, actor/críticos, configuración, runtime E2A, planta ni dataset.

## 6. Gate final y cierre

| Criterio preregistrado | Resultado |
|---|---|
| Guante ausente de observación/actor/planta y contrato teacher documentado | PASS |
| Semántica exacta de disponibilidad/reward/done probada | PASS |
| E2A intacta, A/B exacto | PASS |
| Regresiones E0P y hashes preservados | PASS |
| P reduce MSE >=10 % y mejora reward | PASS: 72.60 % |
| Ambas direcciones, >=8/10 sujetos, >=3/4 motores sin daño >5 % | PASS: 2/2, 10/10, 4/4 |
| Cero errores de dirección | **FAIL** en estados operativos alcanzados por comandos altos |
| Ausencia de ciclos persistentes en P elegido | **FAIL**, dos casos |
| Tests y sujetos sellados | PASS: 59/59, MATEO/SANDRA intactos |

La señal de tracking/reward responde favorablemente a un controlador P privilegiado;
el problema no queda autorizado para RL por los límites de dinámica/cuantización
medidos. La viabilidad de aprender a partir de EMG no se ha demostrado aquí.
E1–E1D siguen cerradas. No se intenta rescatar el resultado cambiando Kp seleccionado,
reward, TD3, niveles PWM, periodo ni planta, y no se abre otra subetapa.

**E2B_RESULT=FAIL. RL_AUTHORIZED=NO. E3_PREPARED=NO. E3_EXECUTED=NO.**
**MANUAL_COMMAND (E3)=NOT_PREPARED_E2B_FAIL. PUSH=NO.**
