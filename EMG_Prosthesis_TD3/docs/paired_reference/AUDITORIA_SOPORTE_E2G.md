# E2G — Alcance demostrado del soporte de planta

Auditoría de código y artefactos, 2026-09-07. La envolvente E2F es una propiedad
del simulador canónico, sus semillas y su contrato temporal. **No demuestra un
límite mecánico universal ni una calibración entre guante y prótesis.** Esta
auditoría no ejecuta controles, contrafactuales, hardware, sandbox ni datos EMG.
No cambia curvas, límites, h(q), periodos ni artefactos E0P–E2F.

## Qué demuestra el grafo

[e2fBuildGraphs.m](../../matlab_code/analysis/paired_reference/e2fBuildGraphs.m)
enumera las 15 acciones `0, ±64, ±96, ±128, ±160, ±192, ±224, ±255`. Sus semillas
son cero, los estados de los comparadores suministrados y `qBefore/qAfter` de
los casos fijos. Desde cada estado consulta la API canónica con duración 0.2 s
y muestreo 0.14 s; añade todos los nuevos destinos hasta cerrar. Las claves
conservan los bits del double. El límite de 10000 estados es una condición de
aborto, no una poda: los cuatro grafos cierran por debajo del límite.

Por inducción sobre la longitud de la secuencia de acciones, ninguna secuencia
finita bajo ese contrato puede salir del grafo si empieza en una de sus
semillas. Es una envolvente válida para ese conjunto de arranques, incluso a
horizontes mayores que H5. El cierre une semillas diferentes: no demuestra que
cada estado sea alcanzable desde cada semilla. Tampoco demuestra que todos los
números interiores entre el mínimo y máximo de h(q) sean alcanzables; el soporte
es un conjunto finito. Por ello, minimizar sobre todo el grafo o proyectar al
intervalo son cotas optimistas, no controles realizables por sí mismos.

El [simulador](../../matlab_code/src/@SimController/prosthesis_simulator.m)
cuantiza los demás PWM permitidos a los mismos niveles representados. El cierre
cubre ese cuantizador con el contrato temporal fijado; no cubre curvas físicas
nuevas a PWM intermedios. Cambiar duración o muestreo cambia los índices
consultados y exige otra auditoría. No se ha hecho ese cambio aquí.

La API acepta posiciones iniciales que no pertenecen a las semillas. PWM cero
devuelve la posición recibida, y el caso sin cruce de curva hace HOLD. Por tanto,
ni siquiera para la API completa puede tratarse la envolvente E2F como un límite
universal independiente de inicialización. Además, `min_lim/max_lim` saturan la
posición empleada en la búsqueda; **no son un clamp global de la salida**.

## Comparación de las cuatro fuentes de rango

El artefacto nuevo
[plant_support_audit.csv](../../matlab_code/analysis/paired_reference/e2g_results/plant_support_audit.csv)
contiene 56 filas motor/PWM/dirección: extremos del grafo, de `avg`, de `data`,
límites, número de muestras/repeticiones y extremos de los CSV originales
seleccionados por el filtro histórico. Incluye rutas y SHA256 de esos originales.
Los valores siguientes agregan las 14 combinaciones de cada motor.

| Motor | q del grafo E2F | q de todos los `avg` | q de `data` y límites | Máximo h del grafo | Máximo h de `avg` | h del máximo de `data` |
|---|---|---|---|---:|---:|---:|
| M1 | [-788.6667, 17246.5] | [-788.6667, 17246.5] | [-871, 17375] | 0.7272081340 | 0.7272081340 | 0.7309962957 |
| M2 | [-437.3333, 6665.1667] | [-437.3333, 6665.6667] | [-477, 6821] | 0.6550224455 | 0.6550581218 | 0.6661415470 |
| M3 | [-681.3333, 7661.2] | [-681.3333, 7672.2] | [-910, 7912] | 0.8682627566 | 0.8699903552 | 0.9076520039 |
| M4 | [-562.1667, 6280.8333] | [-562.1667, 6280.8333] | [-671, 6502] | 0.7205408629 | 0.7205408629 | 0.7432710054 |

Aplicar h a una posición registrada es una conversión computacional con el mapa
heredado; las tres últimas columnas no son nuevas mediciones físicas de flexión.
Los suelos de h son 0.4398826979 en M1/M2/M4 y 0.2932551320 en M3.

MATLAB R2023b verifica que **56/56** pares de límites coinciden con los extremos
de `data`. El script histórico
[generating_trajectory.m](../../matlab_code/development/archive/simulator_creation_assets/generating_trajectory.m)
calcula precisamente esos extremos. `data` ya está procesada:
[view_sim_dataset.m](../../matlab_code/development/archive/simulator_creation_assets/view_sim_dataset.m)
aplica [filter_prueba.m](../../matlab_code/development/archive/simulator_creation_assets/filter_prueba.m),
recorta desde `max(10,find_start_point)-1`, trunca cada grupo a la longitud mínima
y calcula media/desviación. No se ejecutaron esos scripts ni se reajustaron curvas.

Se leyeron con Python estándar los 76 CSV originales de adquisición de motores;
67 pasan el filtro histórico. Sus extremos globales por motor coinciden con los
de `data`, tanto conservando como excluyendo las repeticiones filtradas. Eso no
ocurre en todos los grupos: **53/56** grupos seleccionados conservan los mismos
extremos entre CSV completo y `data` recortada. Las tres diferencias de máximos son:

| Grupo | Máximo `data` | Máximo CSV completo seleccionado |
|---|---:|---:|
| M2 cierre, sp_3F | 5265 | 5550 |
| M3 cierre, sp_3F | 4677 | 6660 |
| M3 cierre, sp_5F | 6077 | 6171 |

Estos extremos no reconstruyen por sí solos todas las columnas de `data`; la
verificación completa de repeticiones M3 descrita en E2C mantiene su alcance
original. Aquí se contrastan soporte, selección y extremos, sin afirmar una
nueva reconstrucción completa de las repeticiones M1/M2/M4.

## Qué ocurre específicamente en M2

[definitions.m](../../matlab_code/config/definitions.m) asigna M2 al índice,
`gap=3650`, `breakLimit=11500`, flexión inferior 900 y superior 2046.
[encoder2Flex.m](../../matlab_code/src/preprocess/encoder2Flex.m) usa `abs(q)`:

```text
h2(q) = 900/2046                              si |q| < 3650
      = [900 + 1146*(|q|-3650)/7850] / 2046   si 3650 <= |q| <= 11500
      = 1                                    si |q| > 11500
```

El suelo 0.4398826979 procede del propio mapa, antes de imponer ningún rango de
planta. Dentro de la holgura puede cambiar el encoder sin cambiar h. El máximo
de todos los promedios, 6665.6667, difiere del máximo del grafo en sólo **0.5
encoder**, equivalente a **0.0000356763** en h. Por tanto, la diferencia de techo
entre ese grafo y los promedios completos es pequeña; no sustenta atribuir el
gran desajuste M2 exclusivamente a los estados omitidos por el cierre o por el
muestreo de 0.2 s. Esto no evalúa otros efectos dinámicos del periodo.

Las repeticiones originales llegan a 6821, todavía por debajo del ancla 11500.
El máximo aparece en `FF/Prueba1_2024_02_07.csv` y su archivo `Regreso`; es 6821
tanto en el CSV completo como en `data`. Incluso h aplicado a ese máximo da
0.6661415470, sólo 0.0111191014 por encima del techo del grafo. El promedio reduce
el rango, pero el recorrido registrado más amplio tampoco llega al ancla de h.
No se deduce de ello que el hardware sea incapaz de alcanzar 11500.

La curva media M2 de cierre sp_3F alcanza sólo 3598, por debajo de `gap=3650`:
toda esa curva se convierte en el suelo de h aunque sus encoders se muevan.
Es una explicación computacional concreta de respuesta plana en h; no demuestra
que el dedo real no se mueva, ni que toda política que use PWM64 sea plana,
porque una posición inicial alta puede conservarse por HOLD.

## Evidencia que falta para una interpretación física

Los límites `[26500,11500,8500,9000]` coinciden con
[definitions.h del firmware](../../prosthesis_code/include/definitions.h), pero
la coincidencia de constantes prueba coherencia de código, no el recorrido de
la unidad usada en las adquisiciones. `definitions.m` describe las flexiones
como un modelo simplificado ligado al guante; no contiene observaciones de
posturas emparejadas que identifiquen sus anclas.

Los CSV de motor tienen columnas tiempo, cuatro encoders, PWM, voltaje y trama;
no contienen sensores de guante o posturas mecánicas emparejadas. En las fuentes
auditadas no se encontró evidencia independiente que establezca:

- que las unidades de guante y h del encoder representan la misma postura o
  magnitud funcional, con correspondencia de canales y grados de libertad;
- el origen medido de las anclas inferiores/superiores, el cero de encoder,
  la holgura y la validez de `abs(q)` para esa unidad/configuración;
- que las adquisiciones de curvas alcanzaran el límite mecánico, con duración,
  carga, tensión de tendones y alimentación conocidas, y la misma versión de
  mecanismo/firmware que los límites heredados;
- al menos dos posturas independientes emparejadas por motor en la región no
  saturada, más evidencia intermedia para justificar un mapa afín entre ellas
  y caracterizar repetibilidad e histéresis.

La proyección al intervalo del grafo puede utilizarse como diagnóstico de
incompatibilidad con la representación actual. No aporta esas mediciones y no
convierte el intervalo en un límite físico calibrado. No hay fundamento en esta
auditoría para ensayar alineación afín ni para dar por satisfecho el gate de
equivalencia de coordenadas.

## Verificación y alcance de los artefactos

La tabla se obtuvo leyendo `pattern_curve.mat` (`avgs`), el CSV de límites y
`graph_edges.csv`, aplicando la función histórica `encoder2Flex` a sus valores,
y leyendo únicamente los CSV de caracterización de motores. Los grupos se
identifican por campo PWM y dirección, respetando que sp_FF se etiqueta 256
internamente y el comando permitido es 255. No se invocó el simulador para
generar estados ni el runner E2F. Se conservan como archivos nuevos E2G los
scripts de lectura que produjeron el CSV y los resultados de integridad raw.
La integridad histórica global y los gates completos E2G son responsabilidad
del runner/verificador de la etapa, no de estas estadísticas.

## Reproducción y cobertura del manifiesto histórico

Los comandos originales de lectura MATLAB/Python quedaron conservados en
[e2gAuditPlantSupport.m](../../matlab_code/analysis/paired_reference/e2gAuditPlantSupport.m)
y [e2gAuditPlantSupportRaw.py](../../matlab_code/analysis/paired_reference/e2gAuditPlantSupportRaw.py),
con las mismas operaciones y selección de archivos. El primero reproduce las
columnas de grafo, promedio y `data`; el segundo añade las columnas raw y sus
hashes, y resume por separado los extremos de todos los originales. Escriben
únicamente dentro de `e2g_results`; no recalculan políticas ni artefactos E2F.

Desde `EMG_Prosthesis_TD3/matlab_code`:

```powershell
matlab -batch "addpath('analysis/paired_reference');e2gAuditPlantSupport();"
python analysis/paired_reference/e2gAuditPlantSupportRaw.py
```

Para comprobar sólo integridad sin regenerar soporte ni releer sus valores:

```powershell
python analysis/paired_reference/e2gAuditPlantSupportRaw.py --verify-only
```

Se ejecutó esta última comprobación al conservar los scripts, sin repetir las
mediciones. El manifiesto histórico E2G tiene **740 entradas**, de las cuales
**33 corresponden a los 76 CSV raw inspeccionados**. Esos **33/33 hashes
coinciden**; no hay discrepancias. Los 33 pertenecen a los 67 archivos
seleccionados para soporte. Quedan **43 sin baseline histórico**: 34 seleccionados
y nueve excluidos. No se amplió ni se recapturó el manifiesto.

Separadamente, **67/67 hashes** de los archivos seleccionados coinciden con
los guardados al producir `plant_support_audit.csv`. Esta segunda comprobación
conserva la procedencia de la auditoría, pero no sustituye un baseline anterior
a E2G para los 34 seleccionados que carecen de él. Tampoco el hash actual de los
nueve excluidos demuestra invariancia histórica. La cobertura por archivo queda
explícita como `NO_HISTORICAL_BASELINE` cuando corresponde en
[raw_support_integrity.csv](../../matlab_code/analysis/paired_reference/e2g_results/raw_support_integrity.csv),
con resumen en
[raw_support_integrity.json](../../matlab_code/analysis/paired_reference/e2g_results/raw_support_integrity.json).
