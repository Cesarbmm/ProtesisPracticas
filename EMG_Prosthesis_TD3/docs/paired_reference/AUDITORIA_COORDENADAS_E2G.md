# E2G — Auditoría de las coordenadas teacher y planta

2026-09-07. Auditoría documental y de código de la línea
`experiment/no-glove-paired-reference-td3`, en el worktree existente
`C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`. Complementa el
[preregistro E2G](PREREGISTRO_E2G.md). No modifica código, datos, constantes,
reward, runtime ni resultados históricos. No se ejecutaron datasets, hardware
o comparaciones para producir este documento. MATEO y SANDRA siguen sellados.

## Conclusión y alcance

**No se encontró evidencia local de una calibración física independiente que
haga equivalentes `encoder2Flex(q)` y la señal reducida del guante.** Ambas
señales comparten divisores y orden de motores; eso acredita una escala numérica
compatible con el reward implementado. No acredita que valores iguales
representen la misma postura, ángulo articular o desplazamiento físico.

La transformación encoder–flexión es un modelo heredado, lineal por tramos,
con valor absoluto, holgura y saturación. Algunas constantes coinciden con
límites del firmware. Su coincidencia no demuestra cómo fueron medidas ni
valida las anclas contra una postura humana. Los límites de una representación
numérica o de la planta canónica no deben llamarse límites mecánicos universales.

Se distingue en este informe:

- **MEDIDO:** existe evidencia de una adquisición de la magnitud; no basta un
  comentario que declare un número como mínimo o máximo.
- **HEREDADO:** constante o correspondencia presente en la implementación
  histórica, con origen software identificable.
- **HEURÍSTICO:** elección de modelo o agregación cuya equivalencia física no
  está validada en los artefactos inspeccionados.
- **UNKNOWN:** falta trazabilidad suficiente del origen o de la validación
  física. No implica que el valor sea necesariamente incorrecto.

## Correspondencia de motores, sensores y constantes

El orden es M1–M4 = `little`, `idx`, `thumb`, `mid` en
[definitions.m](../../matlab_code/config/definitions.m), líneas 31–36.
El firmware declara el mismo orden en
[definitions.h](../../prosthesis_code/include/definitions.h), línea 21.

| Motor | Denominación histórica | Canales del guante sumados | `gap` | `breakLimit` | `flex_low_lim` | `flex_max_lim` y divisor |
|---|---|---|---:|---:|---:|---:|
| M1 | little | ringUp + ringDown + pinkyUp + pinkyDown | 7500 | 26500 | 1800 | 4092 |
| M2 | idx | indexUp + indexDown | 3650 | 11500 | 900 | 2046 |
| M3 | thumb | thumb | 4000 | 8500 | 300 | 1023 |
| M4 | mid | middleUp + middleDown | 3550 | 9000 | 900 | 2046 |

`gap` y `breakLimit` están expresados en las unidades de encoder que recibe
`encoder2Flex`. Las otras dos columnas pertenecen a la escala histórica de
señal flex acumulada; no son grados ni encoder counts.

| Elemento | Procedencia y clasificación | Evidencia exacta | Lo que no demuestra |
|---|---|---|---|
| Orden motor–dedo | HEREDADO, consistente con diseño declarado | `definitions.m:31–36`; `definitions.h:21` | Calibración geométrica de cada articulación. |
| `gap` | HEREDADO; procedencia medida UNKNOWN | `definitions.m:39–45` explica holgura por tensión floja y fija los números. | No hay registro identificado que mida cuándo empieza a flexionarse cada dedo ni su incertidumbre. |
| `breakLimit` | HEREDADO DEL FIRMWARE; origen experimental UNKNOWN | `definitions.m:47–52` dice que se basa en límites del software ESP32; `definitions.h:23` contiene exactamente `[26500,11500,8500,9000]`. | No demuestra posición física de flexión máxima ni correspondencia con saturación del guante. |
| `flex_low_lim` | HEREDADO; procedencia medida UNKNOWN | `definitions.m:54–64` declara modelo simplificado y describe mínimo del sensor en reposo. | No aparecen muestras de calibración, fecha, sujeto, postura o criterio de ajuste que produzcan esos números. |
| `flex_max_lim` | HEREDADO y convención de escala | `definitions.m:66–70` los describe como saturación del sensor. Son `1023 × [4,2,1,2]`. | No demuestra que todos los sensores o sujetos alcancen su máximo, ni que ese máximo equivalga a una postura protésica. |
| Suma de sensores | MODELO ESTRUCTURAL HEREDADO; equivalencia funcional no validada | `definitions.m:77–80`; `reduceFlexDimension.m:17–25`. | Una suma de articulaciones no identifica una postura anatómica única; M1 combina anular y meñique. |
| Recta encoder–flexión | HEURÍSTICO HEREDADO | `encoder2Flex.m:54–58` construye pendiente e intercepto desde dos anclas prefijadas. | No es un ajuste a observaciones emparejadas de guante y encoder. |
| Valor absoluto, holgura y saturación | HEURÍSTICO HEREDADO | `encoder2Flex.m:69,73–82`. | No acredita simetría física entre encoder positivo y negativo ni rango útil físico completo. |
| `flexJoined_scale` | NORMALIZACIÓN ALGEBRAICA HEREDADA | `configurables.m:280–284` divide ambas señales por `[4092,2046,1023,2046]`. | No resta reposo, no calibra por sujeto y no estima rangos de desarrollo. |

Fuentes de la tabla: [definitions.m](../../matlab_code/config/definitions.m),
[definitions.h](../../prosthesis_code/include/definitions.h),
[encoder2Flex.m](../../matlab_code/src/preprocess/encoder2Flex.m),
[reduceFlexDimension.m](../../matlab_code/src/preprocess/reduceFlexDimension.m)
y [configurables.m](../../matlab_code/config/configurables.m).

No se clasifica ninguna de las anclas numéricas de esta tabla como MEDIDA con
trazabilidad independiente. Que un comentario la llame mínimo, saturación o
límite de rotura no suple el registro de medición.

## Transformaciones realmente implementadas

Para el motor i, sean g el `gap`, b el `breakLimit`, L el `flex_low_lim` y U
el `flex_max_lim`, que también se usa como divisor. La combinación exacta de
`encoder2Flex` y `flexJoined_scale` es:

```text
x = abs(q)

h_i(q) = L_i/U_i                                      si x < g_i
         L_i/U_i + (1-L_i/U_i)*(x-g_i)/(b_i-g_i)       si g_i <= x <= b_i
         1                                            si x > b_i
```

La pendiente y el intercepto se calculan en `encoder2Flex.m:54–58`.
La función usa el valor absoluto en línea 69 y evalúa los tres tramos en
líneas 73–82. No carga datos de calibración ni estima parámetros.

Como consecuencia algebraica de esas constantes, ya identificada en la
auditoría estática, el rango global del mapa —antes de considerar qué estados
alcanza la planta— es:

| Motor | `h(0)` y suelo del mapa | Techo del mapa |
|---|---:|---:|
| M1 | 0.4398826979472141 | 1 |
| M2 | 0.4398826979472141 | 1 |
| M3 | 0.2932551319648094 | 1 |
| M4 | 0.4398826979472141 | 1 |

Por tanto, encoder cero no equivale a teacher normalizado cero. Un target por
debajo del suelo no puede ser reproducido por **este mapa**, cualquiera que sea
la acción. Esto no cuantifica cuántos targets del dataset están debajo del suelo;
esa distribución corresponde al análisis preregistrado E2G. Tampoco demuestra
una imposibilidad mecánica real.

`h(q)` es monótono respecto a `abs(q)` dentro del tramo lineal, no universalmente
respecto al encoder firmado. En la zona de holgura o saturación, diferentes
encoders se convierten al mismo valor. El conjunto de estados alcanzables de
la planta canónica puede tener una envolvente todavía menor que este rango
algebraico. Son tres objetos distintos: rango del mapa, soporte del simulador
y rango físico de la prótesis.

El teacher reducido se calcula, en cambio, como:

```text
y_i(t) = suma de los canales asignados al motor i en t / U_i
```

[reduceFlexDimension.m](../../matlab_code/src/preprocess/reduceFlexDimension.m),
líneas 17–25, realiza sólo la suma; no resta mínimos, no convierte a ángulos
y no interpola posturas. La división constante está en `configurables.m:284`.
La coincidencia del divisor U no convierte una medición de sensor resistivo
agregada en una medición mecánica equivalente al encoder.

## Cadena de procedencia del guante y del dataset

La clase [Glove.m](../../matlab_code/src/@Glove/Glove.m), líneas 2–4, describe
nueve sensores flex y una IMU. Su
[decodingSerialData.m](../../matlab_code/src/@Glove/decodingSerialData.m),
líneas 5–22, separa el mensaje, convierte texto a números y asigna los nueve
canales. No contiene calibración angular ni conversión encoder–guante.
[read.m](../../matlab_code/src/@Glove/read.m), líneas 20–30, entrega esos datos
decodificados. Esto documenta una arquitectura de adquisición de mediciones;
no demuestra por sí mismo la unidad física ni la calibración del firmware de
guante que produjo cada archivo histórico.

El script histórico
[saving_dataset.m](../../matlab_code/development/archive/adapt_dataset_denis_raw/saving_dataset.m),
líneas 58–71, carga archivos y copia `vars.myo` y `vars.glove`; líneas 77–80
reorganizan repeticiones y direcciones y línea 97 guarda `gloves`, `emgs` y
metadatos. No ajusta escalas del guante. Se leyó únicamente el código: **no se
ejecutó el script ni se abrieron sus archivos de sujetos**, incluidos los sellados.

[getDataset.m](../../matlab_code/src/runtime/getDataset.m), líneas 53–57, carga
y concatena `vars.gloves` sin normalizarlo. La clase
[RecordedGlove.m](../../matlab_code/src/@RecordedGlove/RecordedGlove.m),
líneas 42–46, conserva el registro recibido. Su lector, líneas 50–60, selecciona
un bloque con `floor(time_elapsed*samplingRate)`, avanza el índice y marca
agotamiento; la frecuencia declarada es 10 Hz, línea 19. No calibra ni transforma
la magnitud de los sensores.

Esta cadena permite localizar dónde se conserva la medición y dónde se aplica
la transformación. No equivale a una verificación física retrospectiva de todos
los instrumentos o firmware utilizados durante la adquisición.

## Uso causal en reset, step, reward y observación

El guante sigue siendo información privilegiada del protocolo histórico.
Esta auditoría no modifica su semántica.

| Ruta | Evidencia | Consecuencia |
|---|---|---|
| Selección de datos en reset | [reset.m](../../matlab_code/src/@Env/reset.m), líneas 100–104 | Se seleccionan EMG y guante de la misma repetición/lado y se construye `RecordedGlove`. |
| Disponibilidad inicial | `reset.m:119–122,146–163` | Se reinician buffers, se leen EMG/guante y se espera hasta tener ambos. |
| Estado inicial | `reset.m:186–192` | Se normaliza el último encoder, se ponen acciones efectivas anteriores a cero y se calcula la observación desde EMG y motorData. |
| Lectura posterior al paso | [step.m](../../matlab_code/src/@Env/step.m), líneas 67–81 | Tras aplicar la acción y avanzar el tiempo se leen EMG, guante y planta. |
| Conversión para reward | `step.m:122–125` | `flexJoined_scale(reduceFlexDimension(flexData))` se compara con `flexJoined_scale(encoder2Flex(motorData))`. |
| Target y predicción efectivos | [trackingMseActionRateReward.m](../../matlab_code/src/reward_functions/trackingMseActionRateReward.m), líneas 9–11 | Se utiliza la **última fila** de cada bloque convertido. El reward no promedia toda la ventana temporal del guante. |
| Acción penalizada | `step.m:125,146`; `trackingMseActionRateReward.m:18–26` | Se usa la acción efectiva aplicada y su diferencia con la efectiva anterior. |
| Terminación | [checkEndEpisode.m](../../matlab_code/src/@Env/checkEndEpisode.m), líneas 12–16 | En prerecorded termina por agotamiento EMG **o** guante; el horizonte es parte del protocolo teacher. |
| Observación markov52 | [calculateState.m](../../matlab_code/src/@Env/calculateState.m), líneas 15–27 | Concatena features EMG, encoder normalizado, delta encoder y acción efectiva anterior. No consulta el guante ni `h(q)`. |

La normalización de encoder que usa la observación es **otra transformación**:
`q ./ [26500,11500,8500,9000]`, en `configurables.m:276–278`. La propiedad
`encoderNormCalculator` se conecta a ella en
[Env.m](../../matlab_code/src/@Env/Env.m), línea 60; `flexJoined_scaler` es una
propiedad distinta, línea 63. Confundir encoder normalizado de markov52 con
`h(q)` del reward ocultaría la holgura, el valor absoluto y las saturaciones
del segundo mapa.

El reward es la media por motor de error cuadrático en esta escala histórica,
penalización de acción y penalización de cambio de acción. Que esté bien definido
computacionalmente y no filtre el guante al actor no valida sus unidades físicas.
La ausencia causal del guante durante ejecución permanece demostrada por
[E2A](11_RESULTADOS_E2A.md); el problema de coordenadas es una pregunta diferente.

## Documentación y scripts de calibración buscados

Se inspeccionaron los preprocessors, configuración, firmware de prótesis,
lectores del guante, scripts de adaptación del dataset, ejemplos de unificación
guante/prótesis, inventario de desarrollo y documentación local relevante.
No se encontró una tabla de al menos dos posturas emparejadas por motor que
identifique simultáneamente encoder y guante y justifique la recta utilizada.

El ejemplo
[view_glove.m](../../matlab_code/examples/04%20unify%20glove%20and%20prosthesis/view_glove.m)
se presenta en línea 1 como inspección de límites y rangos. Líneas 23–26
configuran `jona_2022`; línea 76 reduce los registros y líneas 115–125 grafican
con límites verticales fijados manualmente. No estima ni guarda `gap`,
`breakLimit`, mínimos o una calibración conjunta. Sólo se leyó el script.
Su existencia demuestra una herramienta de inspección histórica, no el origen
medido de las constantes actuales.

El [manual de ensamblaje](../../Assembly%20manual%20-%20prosthesis%20EPN%20v2.pdf),
páginas 9–12, describe tendones, carretes, motores y encoders; página 12 declara
12 counts por revolución del encoder. No proporciona una correspondencia
encoder–ángulo–guante ni un protocolo que produzca las anclas del mapa actual.
La descripción del mecanismo no basta para deducir esa correspondencia.

[00_LINEA_RECOMENDADA.md](00_LINEA_RECOMENDADA.md), línea 131, menciona ajustar
escaladores sólo con train como propuesta metodológica. No se utiliza esa frase
como prueba de procedencia: la implementación actual `configurables.m:284` es
una división constante. Tampoco se reabre el roadmap decoder supersedido.

## Implicación para el contrato E2G

El gate A del [preregistro E2G](PREREGISTRO_E2G.md) exige evidencia independiente
de equivalencia teacher/h(q) en una postura o magnitud funcional por motor.
La fórmula heredada, la coincidencia con límites del firmware y el divisor
compartido no cumplen esa exigencia. Con la evidencia local disponible, la
calibración sigue **UNKNOWN** y ese gate no puede declararse satisfecho.

La proyección diagnóstica sobre la envolvente del grafo puede separar qué
solicitudes son incompatibles con **esa representación canónica**. No aporta
la calibración física ausente, no garantiza alcanzabilidad de todos los puntos
interiores y no valida automáticamente una transformación afín. Tampoco convierte
un MSE menor frente a un teacher transformado en mejora del control del teacher
original. No se propone ni implementa una nueva calibración en este informe.

La evidencia faltante es una correspondencia independiente, por motor, entre
posturas o magnitudes funcionales identificadas, encoder y sensores de guante,
con procedencia de las anclas y justificación del modelo entre ellas. Hasta
entonces, no debe sustituirse UNKNOWN por una supuesta limitación mecánica real.

```text
ENCODER_TO_GLOVE_PHYSICAL_CALIBRATION_DEMONSTRATED = NO
TEACHER_HQ_NUMERICAL_SCALE_SHARED = YES
TEACHER_HQ_PHYSICAL_EQUIVALENCE_DEMONSTRATED = NO
CONSTANTS_PRIMARY_PROVENANCE = HEREDADO
CONSTANTS_MEASUREMENT_TRACEABILITY = UNKNOWN
ENCODER2FLEX_MODEL = LINEAL POR TRAMOS + ABS + SATURACIÓN; HEURÍSTICO HEREDADO
AFFINE_ALIGNMENT_JUSTIFIED_BY_THIS_AUDIT = NO
PROJECTION_INTERPRETATION = DIAGNÓSTICO DEL SOPORTE DEL SIMULADOR
MATEO_SANDRA_SEALED = YES
HISTORICAL_FILES_EDITED = NO
```
