# E2C — Caracterización causal de los bloqueadores de E2B

**E2C_RESULT = CHARACTERIZED. E2B_RESULT = FAIL. RL_AUTHORIZED = NO.**

Los dos ciclos P2 son órbitas de ida y vuelta del lazo cuantizado actual que
persisten con teacher fijo. La referencia móvil no es necesaria para que existan.
La etiqueta preregistrada es **QUANTIZATION_OVERSHOOT** en ambos casos: el comando
discreto y el desplazamiento de planta hacen cruzar el target en ambos sentidos.
No se ha aislado un porcentaje causal exclusivo de cuantización, Kp o Ts.

Las inversiones M3 tienen **LOW_REPEATABILITY**: existen descensos en columnas
individuales y en registros originales, pero no en una mayoría estricta. No son
exclusivamente un promedio de repeticiones sin descenso, ni se justifica llamarlas
ruido. P2 visita esas posiciones pero no ordena allí PWM de cierre que retrocedan.

Fecha: 2026-09-06. MATLAB R2023b Update 11. **81/81 tests: 59 anteriores +22 E2C**.
E0P y E2A conservan PASS; E1–E1D siguen cerradas; E2B conserva FAIL para siempre.

## Estado local y alcance

Worktree real: `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`. Rama
`experiment/no-glove-paired-reference-td3`. HEAD inicial y conservado:
`165be049eb41fc41254435181c9857fe0f22ed1c`. Árbol inicial limpio. La grafía anidada
de la solicitud no es una carpeta existente; se usó el worktree ya auditado.

La incidencia Git queda pospuesta. No se reparó historia, cambió rama, hizo commit,
fetch, pull ni push. No se usaron archivos, resultados o hipótesis de sandbox.
Los archivos históricos permanecen intactos y todos los nuevos archivos E2C se
dejan sin seguimiento local. MATEO/SANDRA no se abrieron ni compararon.

[PREREGISTRO_E2C.md](PREREGISTRO_E2C.md) se escribió antes del análisis nuevo,
SHA256 `bddb7f8f45b6e6e9cbceb45f3c082c2d1a1694b60ed2de3bb1ec3ca1a46d4013`.
La [nota de ejecución](NOTA_EJECUCION_E2C.md) declara una precisión de alcance:
el análisis nuevo no carga archivos de sujetos, pero las regresiones históricas
sí conservan sus pruebas BLANCA fila 1. También explica el aislamiento de path
para que sus llamadas genpath no incorporen directorios ajenos.

No se modifican Kp=2, Ts=.2, muestreo API=.14, niveles PWM, baselineQuantized,
planta canónica, límites, h(q), reward/pesos, markov52, TD3, WMoos, runtime E2A ni
semántica teacher/reset/done. No se implementa solución alguna.

## 1. Resultado positivo E2B, sin repetir selección

| Magnitud histórica congelada | Valor |
|---|---:|
| MSE cero | 0.09270421488254463 |
| Kp seleccionado | 2 |
| MSE P2 | 0.025400336373607925 |
| Reward P2 | -0.03272837710980499 |
| Mejora MSE | 72.600667 % |
| Coherencia de mejora | 10/10 sujetos, 2/2 direcciones, 4/4 motores |
| Ciclos P2 | 2 de 800 combinaciones episodio-motor |
| Retrocesos M3 P2 | 0 |

**TRACKING_CONTROLABILITY = SUPPORTED.** El bloqueo directo de P2 son los dos
ciclos. Las 125 inversiones P8 y 395 del checkpoint son una limitación adicional
de la planta y de la cobertura previa. No se atribuyen a P2.

El guante sigue siendo teacher privilegiado de reward, disponibilidad/reset y
done histórico. No entra a observación, actor ni transición de planta. La pérdida
histórica 344090/4107233 muestras EMG (8.37766 %) permanece documentada e intacta.

## 2. Reconstrucción exacta de los ciclos

Fuente: `e2b_results/trajectories.mat`, hash
`99f45aa6a5b2269235072e0559d7dc087ef8ade1cfc256ecb799484fbda37352`.
Se reconstruyen los episodios completos mediante el cuerpo intacto del remapeo
histórico en una fixture temporal y la API real del simulador. No se construye
un nuevo Env ni se consulta EMG/guante original para estos replays.

**Errores máximos contra el MAT E2B: q=0, raw=0, reward=0; PWM exactamente igual.**
La referencia previa determina la acción; la posterior determina tracking/reward.
`cycle_reconstruction.csv` conserva los cuatro motores, acción previa real y
todos los términos por motor y su media. `cycle_windows.csv` selecciona estas
ocho transiciones, sin confundir reward de un motor con reward del episodio.

| Caso/paso | Teacher antes → después | h(q) antes | Raw P2 | Efectiva | PWM | q antes → después |
|---|---|---:|---:|---:|---:|---|
| BLANCA 1 cierre M3 /5 | .739980 → .744868 | .293255 | .893451 | .878431 | +224 | 1541.6667 → 7532.5 |
| /6 | .744868 → .750733 | .848050 | -.206364 | -.250980 | -64 | 7532.5 → 1541.6667 |
| /7 | .750733 → .770283 | .293255 | .914956 | .878431 | +224 | 1541.6667 → 7532.5 |
| /8 | .770283 → .798631 | .848050 | -.155533 | -.250980 | -64 | 7532.5 → 1541.6667 |
| IVANNA 104 apertura M4 /19 | .645650 → .634409 | .696792 | -.102283 | -.250980 | -64 | 6049.75 → 2976.3333 |
| /20 | .634409 → .624633 | .439883 | .389052 | .376471 | +96 | 2976.3333 → 6049.75 |
| /21 | .624633 → .614370 | .696792 | -.144316 | -.250980 | -64 | 6049.75 → 2976.3333 |
| /22 | .614370 → .602151 | .439883 | .348974 | .376471 | +96 | 2976.3333 → 6049.75 |

Se preserva `rewardMotor = -(h(q_after)-r_after)^2 -.01*u_effective^2
-.05*(u_effective-u_previous)^2`; el reward total es la media de cuatro motores.
Los desplazamientos del par son ±5990.8333 encoder en M3 y ±3073.4167 en M4,
amplitudes de h(q) .55479472 y .25690885. Son salidas de la planta simulada;
no se les atribuye un bound de velocidad de hardware que E0P no validó.

## 3. Referencia fija y función efectiva del lazo

Por caso: cuatro referencias previas observadas y su media; cada una desde ambos
estados del par, 100 pasos. Total **20 replays /2000 transiciones**. El criterio
comprueba las últimas 20 transiciones, signos alternos y repetición en 1e-9 encoder.

| Caso | Referencia primaria | Persiste par original | Otras referencias fijas |
|---|---:|---|---|
| M3 | .739980449657869 | Sí, desde ambos estados | 4/5 valores conservan el par; .770283479960899 cambia el destino alto a 7584.5 y conserva alternancia. |
| M4 | .6456500488758553 | Sí, desde ambos estados | 5/5 valores conservan exactamente el par. |

Todos los 20 replays presentan un par alterno al final; 18 mantienen el par
original. Por tanto no es sólo seguimiento de target móvil. Además, el retorno
A→B→A es exacto con referencia constante en este mapa determinista; la conclusión
se limita a esas órbitas y sus condiciones, no a estabilidad global o hardware.

Los intervalos de referencia que conservan los dos comandos observados son:

- M3: **(.701098269219711, .762862975102064]**.
- M4: **(.596745443045253, .659490541084469]**.

Se obtienen intersectando los bins reales para ambos estados. El extremo inferior
abierto respeta que el empate entre niveles activos elige el menor. El cuarto
teacher M3 está fuera del primer intervalo: explica el cambio a otro par en su
contrafactual, sin necesidad de cambiar Kp.

El mapa local tiene 5832 pares q/reference (9 perturbaciones encoder ×81 teacher
×4 pasos ×2 casos), más 2002 puntos entre los estados. La función medida es:

```text
error = reference_before - h(q)
raw = clip(2*error,-1,1)
|raw| < .05 → PWM 0
|raw| >= .05 → nivel activo más cercano a 255*|raw|, con signo
effective = PWM/255
q_next = curva del PWM, primer cruce de q +200 índices, con clamp/HOLD históricos
```

La activación salta entre 0 y 64 con una variación raw arbitrariamente pequeña
alrededor de .05; entre niveles activos salta 32 (31 en el último intervalo).
**El mayor salto en una única frontera es 64 PWM, no 288 ni 160.** Los saltos
observados +224↔-64 y -64↔+96 ocurren tras grandes cambios de q y de error: máximo
|delta raw| de 1.1213196481 y .5333680397, respectivamente. No corresponden a una
única discontinuidad infinitesimal del cuantizador.

Fronteras ilustrativas verificadas con raw±1e-10:

| Estado | Frontera raw | Cambio PWM | Cambio q_next | Consecuencia |
|---|---:|---|---:|---|
| M3 q=7532.5 | -.05 | -64 → 0 | +5990.8333 | Un comando mínimo activo recorre todo el salto de apertura observado. |
| M4 q=6049.75 | -.05 | -64 → 0 | +3073.4167 | Mismo mecanismo en el estado alto M4. |
| M4 q=2976.3333 | 80/255 | +64 → +96 | +1434.0833 | La frontera de nivel cambia el destino respecto del teacher. |

**CYCLE1_CAUSE=CYCLE2_CAUSE=CYCLE_CAUSE_GLOBAL=QUANTIZATION_OVERSHOOT.** La etiqueta
es operacional: lazo P2 cuantizado, ganancia y periodo congelados, con pasos de
planta que sobrepasan el target. No se dispone de planta continua validada para
simular raw sin cuantizar; pasar raw*255 al simulador volvería a cuantizarlo.
Por ello no se afirma que eliminar cuantización baste, ni se separa causalmente
el predominio de Kp, Ts o tamaño del paso. La referencia móvil modula el par, pero
no es necesaria para su existencia.

## 4. Mapa denso y exacto M3

Envolvente **[-910,7912] encoder**, obtenida de todas las posiciones M3 observadas
E2B y de avg/data de ambas direcciones y siete PWM. Se incluyen los valores
almacenados, todas las posiciones before/after, una rejilla de un encoder y
vecinos de fronteras: **86665 pares q-PWM**. No se usaron posiciones [0,1].

El primer cruce sólo cambia al superar un récord creciente del prefijo de avg.
En cada celda el endpoint es constante; reversal exige q>endpoint. La intersección
produce los siguientes intervalos, abiertos a izquierda y cerrados a derecha:

| PWM positivo | Intervalo exacto de inversión | Celdas internas | Mínimo delta_q en mapa |
|---:|---|---:|---:|
| 64, 96, 128, 160 | Ninguno en la envolvente | 0 | No hay inversión |
| 192 | **(7647, 7648 +1/3]** | 1 | -1.3333333 |
| 224 | **(7513 +2/3, 7567 +1/2]** | 15 | -53.8333333 |
| 255 | **(7577 +5/6, 7604 +1/2]** | 31 | -65.8333333 |

Las fracciones describen los valores promedio; el MAT conserva los doubles exactos.
CSV puede redondear los últimos dígitos. Los máximos del mapa no sustituyen al
máximo observado E2B de 65 encoder. Reversal se define estrictamente delta_q<0.

Se contrastan **2511 casos con la API canónica**, incluidos todos los estados
observados a cada PWM, extremos, vecinos e interiores de cada celda: **error 0**.
El evaluador acelerado se usa sólo para diagnóstico; no reemplaza la planta.
Se conserva clamp de límites y HOLD cuando no existe cruce. En estas inversiones
sí existe cruce: no es una regresión del fix HOLD.

Cobertura E0P: **0/147** puntos positivos M3 de la rejilla global, **0/147** de la
rejilla por combinación y **0/49** del oráculo operativo caen en intervalos de
inversión del PWM correspondiente. Regiones cubiertas: **0/3 en cada rejilla**.
E0P demostró monotonicidad en su rejilla operacional, no monotonicidad universal.
Su PASS y las 784 regresiones siguen intactos.

## 5. Repeticiones y soporte

`pattern_curve.avgs.<PWM>.closing.m_3` contiene avg/std/data. El script histórico
`development/archive/simulator_creation_assets/view_sim_dataset.m` selecciona
repeticiones con `filter_prueba`, recorta desde `max(10,find_start_point)-1` y
trunca a la longitud mínima antes de calcular mean/std. **data ya está recortada;
no se presenta como adquisición sin procesar.**

Se aplican literalmente esos índices y filtros a los CSV originales de motor,
sin buscar un desplazamiento óptimo nuevo ni ejecutar el script de gráficas.
**33/33 columnas de cierre M3 coinciden exactamente**, y avg/std se reconstruyen
dentro de 1e-10. Los archivos y offsets originales quedan identificados por SHA256.

Se contrastan dos preguntas diferentes para las 47 celdas de inversión:

1. ¿Cada repetición disminuye entre los mismos índices i e i+200 usados por el
   promedio? Se conserva el clamp final histórico y se reporta por separado.
2. ¿Desde el mismo q representativo de la celda, el primer cruce propio de cada
   repetición produce endpoint<q? Se excluyen del denominador las que no alcanzan q.

| PWM | Negativas a índices comunes /N | Media de delta entre índices | Desviación muestral de deltas | Desde el mismo q, negativas/con cruce |
|---:|---|---|---|---|
| 192 | **1/3** | -1.3333 | 2.3094 | **0/1**; dos sin cruce |
| 224 | **2/6 a 3/6**, según celda | -53.8333 a -8.6667 | 27.9046 a 83.4468 | **1/4, 0/3 o 0/2** |
| 255 | **1/6** | -65.8333 a -2.6667 | 45.7238 a 161.2581 | **0/3**; tres sin cruce |

Los negativos se encuentran en la columna 2 de PWM192, columnas 4/5/6 de PWM224
según celda, y columna 5 de PWM255. Por ejemplo, PWM192 produce deltas [0,-4,0]
entre índices 222 y 422: descenso minoritario verificable, no inventado al promediar.

En cinco celdas PWM255, i+200 excede el final almacenado; se usa ese final como la
API. Los registros originales confirman los deltas hasta ese índice. Para la
primera de esas cinco, el negativo sigue siendo visible a horizonte completo en
el original; en las cuatro restantes falta longitud del registro negativo para
afirmar ese contrafactual completo. No se rellena ni extrapola. Las otras 26
celdas PWM255 no requieren ese clamp final.

**REVERSAL_IN_AVERAGE=YES. M3_REVERSAL_CAUSE=LOW_REPEATABILITY.** No hay mayoría
estricta de descensos en los índices comunes; tampoco se reproduce universalmente
al fijar el mismo estado q. El promedio transporta irregularidades minoritarias
a su mapa de primer cruce. No se demuestra un artefacto puramente creado al
promediar curvas individuales monótonas, ni una dinámica física común a todas.
La clasificación se refiere a estas repeticiones y su soporte, no a ruido,
probabilidad poblacional o fiabilidad validada de hardware.

## 6. Visitación y explicación de P2

Denominador principal: **2938 estados q_before por controlador**; no se añaden los
200 estados finales al denominador. Los CSV incluyen también estados únicos con
y sin el final. Una región significa aquí la unión de los tres intervalos, con
independencia del comando actual; se registra además pertenencia según PWM real.

| Controlador | Estados únicos before | Visitas a cualquier región | Fracción | Retrocesos ejecutados |
|---|---:|---:|---:|---:|
| Cero | 2 | 0 | 0 % | 0 |
| P0.5 | 30 | 0 | 0 % | 0 |
| P1 | 72 | 4 | .1361 % | 0 |
| P2 | 85 | **300** | **10.2110 %** | **0** |
| P4 | 79 | 281 | 9.5643 % | 0 |
| P8 | 89 | 454 | 15.4527 % | **125** |
| Agent7250 diagnóstico | 56 | 867 | 29.5099 % | **395** |

En las 300 visitas P2: **174 comandos +64, 44 ceros y 82 negativos**. Ninguno es
un comando positivo en su intervalo de inversión. Esto explica causalmente
P2_VISITS_REVERSAL_REGION=YES y P2_EXECUTES_REVERSAL=NO, sin elegir otro Kp.

Los 520 retrocesos históricos corresponden a PWM255:468, PWM224:50, PWM192:2.
La pertenencia al intervalo del PWM real coincide exactamente con cada retroceso
ejecutado. Agent7250 sigue siendo un instrumento diagnóstico, no un gate de calidad.

## 7. Evidencia exportada y reproducción

Carpeta `matlab_code/analysis/paired_reference/e2c_results/`:

- `cycle_reconstruction.csv`, `cycle_windows.csv`: reconstrucción y reward descompuesto.
- `cycle_local_map.csv`, `cycle_between_states.csv`, `cycle_quantization_boundaries.csv`:
  función efectiva local, errores de cuantización y saltos entre bins.
- `cycle_fixed_reference_replay.csv`, `cycle_fixed_reference_summary.csv`,
  `cycle_orbit_reference_intervals.csv`: contrafactuales y rangos del par original.
- `m3_dense_map.csv`, `m3_intervals.csv`, `m3_cells.csv`, `m3_api_validation.csv`:
  mapa, intervalos, celdas constantes y contraste independiente con API.
- `m3_repeatability.csv`, `m3_individual_repeats.csv`, `m3_raw_provenance.csv`,
  `m3_curve_checks.csv`: repetibilidad, dispersión, soporte y procedencia original.
- `m3_controller_visitation.csv`, `m3_visitation_traces.csv`, `m3_e0p_coverage.csv`:
  cobertura de controladores y rejillas anteriores.
- `cycle_artifacts.mat`, `m3_artifacts.mat`: precisión completa de las tablas.
- `plant_manifest.json`, resúmenes JSON, manifiesto SHA256 de artefactos,
  inventario de 453 archivos históricos y comprobación de integridad, tests.
- `e2c_diagnostics.png` y `.svg`: figura exportable de ciclos, intervalos y visitación.

![Diagnósticos E2C](../../matlab_code/analysis/paired_reference/e2c_results/e2c_diagnostics.png)

Desde `EMG_Prosthesis_TD3/matlab_code`, en un proceso MATLAB nuevo:

```powershell
matlab -batch "addpath(genpath('src'));addpath('config');addpath(genpath('lib'));addpath('analysis/paired_reference');summary=runPairedReferenceE2C();"
python analysis/paired_reference/verifyE2CArtifacts.py
```

El comando sólo reproduce E2C y regenera sus archivos nuevos; no es un comando de
training ni de E2D/E3. La comprobación Python estándar verifica hashes, 86665
filas del mapa, replays, reward, deltas, conteos individuales y visitación.
El error máximo de reconstrucción de delta desde CSV es 1.046e-11 encoder por
serialización; no hay error contra la API en los doubles MATLAB.

Los **22 tests nuevos** cubren P2 en lazo cerrado con teacher fijo, cambio de par,
fronteras reales y empate, clasificación, tres intervalos M3, clamp/HOLD, cruce
prefijo, extremos, caso unitario, repetición original, visitación e inmutabilidad.
Resultado **81/81**, ninguno fallido o incompleto. Los **453 archivos históricos
protegidos conservan exactamente sus hashes**, igual que las 33 fuentes de motor.
La planta conserva SHA256 `a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590`.

## 8. Una sola hipótesis futura, sin implementar

**Un mecanismo mínimo anti-chattering puede romper las órbitas P2 sin cambiar
reward ni representación EMG.** Esta hipótesis requiere una futura prueba E2D;
no se implementa ni autoriza aquí. No afirma resolver la baja repetibilidad M3,
que permanece visible como límite adicional de planta.

No se cambia E2B, no se elige otro Kp y no se corrigen curvas. No se ha demostrado
que EMG permita aprender el comportamiento del P privilegiado ni que TD3 controle
bien. E2C queda caracterizada, no resuelta mediante una intervención.

**RL_AUTHORIZED=NO. E3_PREPARED=NO. E3_EXECUTED=NO. MATEO_SANDRA_SEALED=YES.**
**GIT_REPAIR_ATTEMPTED=NO. COMMIT=NO. PUSH=NO.**
