# S0 — Auditoría del sandbox antes de escribir código

> **Estado: auditoría de lectura completada. Nada del worktree `paired_reference` fue
> modificado.** Todo lo que sigue se obtuvo leyendo archivos y ejecutando comprobaciones
> numéricas *fuera* de MATLAB sobre copias en memoria. No se ejecutó MATLAB, no se corrió
> ningún test del repositorio y no se creó ninguna rama.

## 0. Qué se auditó y qué NO se pudo verificar aquí

| Elemento | Estado | Nota |
|---|---|---|
| Código de la ruta histórica y de E2A | **Leído** | Referencias archivo:línea abajo |
| `pattern_curve.mat`, `plant_limits_canonical.csv` | **Leídos y analizados** | 56 curvas, tabla de 56 filas |
| `e2a_results/execution_traces.csv` | **Leído y reproducido** | 190 pasos, ver §4 |
| Geometría CAD/STL | **Inventariada** | 5 dedos + palma + base + antebrazo |
| `BASE_SHA`, rama, worktree, sincronización | **NO verificado** | `git` no es accesible desde esta sesión: el `.git` del worktree apunta a `C:/Users/Cesarbmm/ProtesisPracticas/.git/...`, ruta de Windows fuera del alcance. **Debe comprobarlo el usuario** con los comandos de `COMO_EMPEZAR.md` |
| Tests E0P/E2A | **NO ejecutados** | Requieren MATLAB R2023b; el gate G0 los exige antes de tocar nada |

Distinción usada en todo el documento: **medido** (se calculó sobre los datos),
**leído** (está escrito en el repositorio), **supuesto** (convención de este sandbox).

## 1. Mapa de reutilización — qué existe ya y no debe reescribirse

| Pieza | Ruta | Rol en el sandbox |
|---|---|---|
| Observación markov52 | `src/@Env/calculateState.m:15-27` | Contrato de estado. **No se reconstruye a mano.** |
| Ejecución sin guante | `src/runtime/GloveFreePolicyRuntime.m` | Motor del replay S1, tal cual |
| Remapeo de acción | `src/@Env/remapActionForActuator.m:14-34` y su copia auditada en `GloveFreePolicyRuntime.m:112-124` | Acción continua → nivel PWM |
| Planta canónica | `src/@SimController/prosthesis_simulator.m:81-167` | Única fuente de dinámica en S1-S3 |
| Controlador simulado | `src/@SimController/SimController.m:150-176` | Buffer y avance temporal |
| Carga selectiva EMG | `src/runtime/loadE2ADevelopmentEpisode.m` | Sólo `emgs`; rechaza MATEO/SANDRA antes de I/O |
| Actor congelado | `src/runtime/loadE2AFrozenActor.m` | Agent7250 como instrumento, sin exploración |
| Manifiesto de planta | `src/runtime/pairedReferencePlantManifest.m` | Hashes de curva y límites |
| Trazas de referencia | `analysis/paired_reference/e2a_results/` | Verdad de integración del gate G1 |

## 2. Registro de unidades — prohibido mezclarlas

| Magnitud | Unidad | Rango observado | Definición |
|---|---|---|---|
| Encoder real `q` | cuentas | motor 1 `[-788.7, 17246.5]`, m2 `[-437.3, 6665.7]`, m3 `[-681.3, 7672.2]`, m4 `[-562.2, 6280.8]` (**medido** sobre las 56 curvas) | salida de `SimController.read()` |
| `q` normalizada (estado 41-44) | adimensional | `q ./ [26500 11500 8500 9000]` | `config/configurables.m:277` |
| Δ encoder (estado 45-48) | adimensional | recortado a `[-1, 1]` | `src/@Env/calculateState.m:24-25` |
| Acción efectiva (estado 49-52) | adimensional | `PWM/255` ∈ {0, ±0.2510, ±0.3765, ±0.5020, ±0.6275, ±0.7529, ±0.8784, ±1} | `remapActionForActuator.m:32-33` |
| PWM | cuenta de mando | niveles `[0 64 96 128 160 192 224 255]` con signo; zona muerta `|a| < 0.05` | `config/configurables.m:223-224` |
| Índice de `pattern_curve` | **milisegundos** | `sampling_period_ms = 1` (**medido** en el MAT) | `pattern_curve.mat` |
| Flex del guante | cuentas de sensor | `reduceFlexDimension` + `flexJoined_scaler` | `src/@Env/step.m:123-124` |

**Regla del sandbox:** el visor declara sus unidades de entrada explícitamente y rechaza
un overlay de guante en cuentas de encoder. El guante nunca inicializa `q`.

## 3. Hallazgos nuevos de esta auditoría

### F1 — `toc(10000)` no cierra la mano durante 10000 periodos

`src/@Env/reset.m:127-131` hace `closeHand(); episodeTic.toc(10000); read(); stop()`.
`Timing.toc(counter)` fija `elapsed_time = counter*period` **pero incrementa `c` en 1**
(`src/@Timing/Timing.m:83-90`), y `SimController.updatePos` avanza por **contador**, no por
`elapsed_time` (`src/@SimController/SimController.m:155-156`).

Consecuencia **medida**: el cierre previo de un episodio de apertura dura **un** periodo de
0.2 s a PWM 255. La posición inicial de apertura es, por tanto,

```
q0 = [11176.666667  6665.166667  7509.666667  6280.833333]   (cuentas)
   = [ 0.42176101   0.57957971   0.88349020   0.69787037]    (normalizada)
```

que coincide **exactamente** con `state_41..44` de los episodios de apertura en
`e2a_results/execution_traces.csv`. La mano de partida está **parcialmente** cerrada.
No se corrige nada: se reproduce y se documenta. Para el visor esto importa porque una
animación de apertura que arranque de una mano totalmente cerrada sería falsa.

### F2 — La planta canónica nunca alcanza los límites de encoder del firmware

**Medido** recorriendo las 56 curvas:

| Motor | Dedo | Máx. curva | Límite firmware | Fracción alcanzada |
|---|---|---:|---:|---:|
| 1 | little (+ ring) | 17246.5 | 26500 | **65.1 %** |
| 2 | idx | 6665.7 | 11500 | **58.0 %** |
| 3 | thumb | 7672.2 | 8500 | **90.3 %** |
| 4 | mid | 6280.8 | 9000 | **69.8 %** |

La observación normaliza con los límites del firmware, de modo que **`q` normalizada nunca
llega a 1**. Un visor que asuma el recorrido `[0,1]` dibuja una mano que jamás se cierra.
Por eso `handKinematicModel` normaliza por defecto contra el recorrido real de la planta
(`rangeMode="plantReachable"`) y ofrece `"encoderLimit"` como alternativa explícita.
Esto es **normalización de dibujo**, no un cambio de la planta.

### F3 — El paso de control avanza 200 muestras de curva

`n_points = round(0.2/0.14) = 1` y `delta_ms = 200` (`prosthesis_simulator.m:55-56`): cada
paso de control produce **un** punto y salta 200 ms de curva. Longitudes de curva
**medidas**: cierre 1576 ms a PWM 64 y 455 ms a PWM 255. De ahí que un paso cubra del
12.7 % al 44 % del *tiempo de curva* — que es lo que E0P corrigió: era tiempo de curva, no
fracción de carrera.

### F4 — Sub-muestrear la curva no cambia el resultado del paso

**Medido** en 2240 casos (4 motores × 14 comandos × 40 posiciones): evaluar el mismo paso
con `sampling_period = 0.02 s` en vez de `0.14 s` da un punto final **idéntico**
(diferencia máxima 0). Es decir: la animación puede mostrar 10 sub-muestras por paso
tomadas de la **misma curva empírica**, sin inventar interpolación y sin alterar la
trayectoria de control. `testSandboxCanonicalAdapterRegression` vuelve a comprobarlo en
MATLAB.

### F5 — El mapa motor → dedo está documentado dos veces, con una advertencia

- `config/definitions.m:31-36`: `motorIdx.little=1, idx=2, thumb=3, mid=4`; `fingers = {'little','idx','thumb','mid'}` con el comentario *"names in order!"*.
- `prosthesis_code/include/definitions.h:21`: `// Motor order: little, idx, thumb, mid. Always check the hardware!`
- `config/definitions.m:80`: `flexMapping.little = {ringUp, ringDown, pinkyUp, pinkyDown}` → el canal del motor 1 agrega **anular y meñique**.

Es **evidencia del repositorio**, no una suposición del sandbox; pero el propio firmware
pide verificar contra el hardware. El visor usa este mapa y lo declara; los **ángulos** de
cada falange siguen siendo `VISUALIZATION_ONLY`.

### F6 — La planta canónica queda completamente especificada por curva + límites + HOLD

Se reimplementó `predict_1dim_canonical` fuera de MATLAB y se reprodujeron los **190 pasos
sin guante** de E2A partiendo sólo de `state_41..44` iniciales y de la secuencia PWM:
error máximo **3.46e-11** cuentas (redondeo del CSV). No hace falta ninguna otra
información para replicar la planta. Esa reimplementación generó
`tests/fixtures/canonical_step_reference.csv` (1176 casos) como **contraste cruzado**; la
fuente de verdad sigue siendo MATLAB.

### F7 — Trampas latentes para quien construya otra ruta de planta

- `speeds_txt` incluye `sp_zeroF` (`prosthesis_simulator.m:107`) pero `avgs` **no tiene ese
  campo**: sólo `sp_3F … sp_FF`. Nunca se indexa porque `speed == 0` retorna antes. Un
  modelo nuevo que itere sobre `speeds_txt` fallará.
- El *snapping* de velocidad usa `SIM_SPEEDS = [0 64 96 128 160 192 224 **256**]`
  (`:106`), con 256 y no 255, mientras que `actionCommandLevels` termina en 255. PWM 255
  cae en el intervalo `[224, 256]` con `r = 0.97 ≥ 0.5` → `sp = 256` → campo `sp_FF`.
  Funciona, pero el 256 es deliberado y no debe "corregirse" a 255 sin rehacer el análisis.
- Los límites de `plant_limits_canonical.csv` **no** coinciden con el rango de las curvas
  (ya registrado en `DECISIONES.md`, diferencia máxima 2700 cuentas). `sat()` se aplica con
  esos límites antes de buscar el punto de partida.

### F8 — Hay repeticiones crudas para separar ajuste y validación en S4

Cada curva guarda `avg`, `std` y **`data` con 3 a 6 repeticiones** (`data` es
`longitud × repeticiones`). S4 puede ajustar con un subconjunto de repeticiones y validar
con el resto **sin inventar datos** y sin validar sobre los mismos puntos del ajuste, que
es exactamente lo que el plan exige.

### F9 — Muchas curvas promedio no son monótonas

**Medido**: de las 56 curvas promedio, sólo 18 son monótonas en el sentido del movimiento. Un modelo
reducido de primer o segundo orden **no** podrá reproducir esas ondulaciones. Conviene
escribirlo en el preregistro de S4 antes de ver el error de ajuste, para no interpretar
como "el modelo suaviza el ruido" lo que también puede ser "el modelo no representa el
dato".

## 4. Geometría disponible para el visor

`EMG_Prosthesis_TD3/STLS/` contiene `Fingers/Right_Hand_{Index,Middle,Ring,Little,Thumb}.stl`,
`Palm/palma-completa-v5.stl`, `Base/`, `Forearm/`, y `CAD/` los `.ipt`/`.iam` de Inventor.

**Medido** (caja envolvente, extensión mayor, mm): middle 101.21, index 94.92, ring 88.44,
little 75.13, thumb 81.01. **Las piezas están modeladas en pose curvada y con base de
montaje**, así que la caja envolvente **no** da longitudes de falange. El sandbox usa sólo
la **proporción relativa** entre dedos y marca la escala absoluta como `VISUALIZATION_ONLY`.
Montar las mallas reales exige conocer los ejes de articulación, que el repositorio no
documenta: queda para S7, no para S2.

## 5. Lo que esta auditoría NO autoriza

- No autoriza entrenar TD3 ni abrir E2B.
- No autoriza declarar que una EDO nueva "es la física real".
- No autoriza tocar `src/@Env`, `pattern_curve.mat`, reward, periodo ni niveles PWM.
- No autoriza usar MATEO/SANDRA.
- No demuestra calidad de control: E2A ya dejó dicho que valida arquitectura, no control.
