# 10 — Resultados E0P: planta reproducible y límites caracterizados

- Fecha: 2026-09-05. MATLAB R2023b Update 11, Windows, Curve Fitting Toolbox presente.
- Rama: `experiment/no-glove-paired-reference-td3`.
- Arranque y remoto consultado: `f59798acb972f95815e2499dd828c3f8725d70d7`, sincronización inicial `0 0`.
- **E0P_RESULT = PASS**. Batería final: **24/24 tests**, cero fallidos o incompletos.
- Alcance: canonicalización de planta. E1/E1B/E1C/E1D permanecen cerrados; E2 y RL no autorizados.

## 1. Qué se recibió y qué se corrigió

La ruta solicitada `C:\Users\Cesarbmm\ProtesisPracticas\_paired\_reference` no existe.
Git registra esta rama en `C:\Users\Cesarbmm\ProtesisPracticas_paired_reference`, donde se trabajó.
Había once archivos preparados en el índice y un `.fuse_hidden0000000900000001` sin seguimiento.
No había cambios adicionales fuera del índice. No se borró, movió ni guardó en stash el trabajo
recibido. El residuo FUSE es una copia del simulador pre-HOLD y se conserva fuera del commit.
El detalle está en [AUDITORIA_RECEPCION_E0P.md](AUDITORIA_RECEPCION_E0P.md).

La arquitectura canónica recibida, la tabla de límites, los hashes, el CSV de regresión y el HOLD
eran correctos. La batería recibida dio 8/9: HOLD falló por `Diagnostic=` no admitido por esta API
MATLAB, no por un resultado incorrecto del simulador. Se corrigió ese argumento en ambos tests
que lo usaban. La regresión inicial ya daba error máximo 1.1641532182693481e-10.

Se completaron las pruebas de CFT, legado, integridad del oráculo, trayectorias largas y guardado
del manifiesto. Se corrigió el selector: ya no conserva una fuente obsoleta en caché ni convierte
silenciosamente errores de configuración en `legacyAuto`. Una fuente inválida produce error.
Las rutas relativas se resuelven contra `pwd` de MATLAB antes de usar cachés y hashes; se probó
el cambio de directorio entre dos fixtures con el mismo nombre de archivo y datos diferentes.
Los MAT reales permanecen idénticos, byte a byte, a `f59798ac`.

## 2. Selección de planta y prescindencia de fit_C2

```matlab
params.simPlantSource = "patternCurveCanonical";
```

| Fuente | Comportamiento |
|---|---|
| `patternCurveCanonical` | Carga únicamente `pattern_curve.mat` y `plant_limits_canonical.csv`. No carga fit, no inspecciona cfit ni selecciona según toolboxes. |
| `legacyAuto` | Conserva el despacho histórico `numel(ws)==0`: fallback de curvas si ws está vacío; ruta ws si está disponible. Incluye el HOLD de E0. |

Una llamada puede pedir `plantSource` explícitamente. Sin ese argumento se consulta la
configuración vigente; esta rama fija la fuente canónica. La compatibilidad con configuraciones
antiguas sin el campo conserva `legacyAuto`, pero no se activa por presencia o ausencia de CFT.
Las rutas de archivos se derivan del archivo del simulador, por lo que la física histórica ya no
requiere arrancar desde un directorio de trabajo concreto.

Los límites se extrajeron literalmente de campos numéricos; no se ajustaron ni reconstruyeron
curvas. MATLAB confirmó **56/56 pares exactamente iguales** a los históricos, error cero.
Esos pares **coinciden con el rango de sus curvas en 0/56**. La máxima diferencia es 2700 encoder
(M1 cierre, PWM64: max_lim 17016 frente a máximo de curva 14316). Derivar nuevos límites del
rango de la curva eliminaría casos HOLD o alteraría el inicio. Por eso se conserva el CSV numérico.
La ruta canónica prescinde completamente de fit_C2 en ejecución, aunque la tabla documenta su
procedencia histórica.

## 3. Oráculo y pruebas independientes

El usuario proporciona `plant_e0_regression_cases.csv` como oráculo congelado. El borrador anterior
atribuía su generación a una réplica Python, sin adjuntar el generador. No se puede certificar esa
cronología sólo con el archivo. Sí se confirmó ahora su **equivalencia de comportamiento con E0**:

- 784 claves únicas: 4 motores × 14 PWM firmados × 7 posiciones reales × 2 duraciones.
- 392 casos de 0.2 s y 392 de 3 s; siete posiciones entre min_lim/max_lim por combinación.
- Hash del oráculo intacto y validado en tests. No se regeneró a partir de la ruta canónica.
- Referencia independiente: código MATLAB de `f59798ac` congelado en
  `tests/paired_reference/fixtures/plantE0HistoricalReference.m`. Sólo cambian nombre de función
  y resolución de las dos rutas MAT. La igualdad del resto se contrastó con Git.
- En una fixture temporal, ws se sustituye por valores numéricos vacíos para materializar la
  condición E0 sin CFT. **784 trayectorias completas** canónicas coinciden exactamente con esa
  referencia. Esta fixture no modifica ni reconstruye ningún MAT real ni ajusta curvas.
- `legacyAuto` coincide exactamente con la referencia en **1568 trayectorias completas**:
  784 con el fit real y 784 con la fixture ws vacía. También se verificaron seis casos adicionales
  de exceso del bound heurístico contra la referencia E0, con igualdad exacta.

La comparación con el CSV exige n_points exacto y **error absoluto máximo < 1e-9** en first, last y
sum, sin tolerancia relativa. Resultado: **1.1641532182693481e-10**, cero casos fallidos. Esa pequeña
diferencia corresponde a representación/redondeo de los resúmenes congelados; la comparación
MATLAB contra la referencia completa es exacta.

La independencia de CFT se probó copiando el simulador a una fixture con **sólo curvas y límites,
sin fit_C2**. Se retiraron cuatro entradas CFT del path temporal de prueba, `which("cfit")` quedó
vacío y el perfil registró **cero llamadas cfit y cero llamadas a la ruta legacy**. Las 784
trayectorias completas coincidieron exactamente con las obtenidas con CFT en el path. También
pasaron las pruebas de fitC2Path inexistente y carga previa de cfit. Se restauró el path con
cleanup; no se desinstaló CFT ni se renombró, movió o borró ningún archivo real.

## 4. Gate operativo, HOLD y estrés

Se usa `duration=0.2`, `sampling_period=0.14`, tal como E0: una muestra de salida por paso.
Las entradas son unidades de encoder reales, nunca posiciones normalizadas [0,1].

| Barrido | Operativos | Fallos operativos | Casos HOLD (ambas duraciones) | Fallos HOLD | Estrés 3 s |
|---|---:|---:|---:|---:|---|
| Global por motor, 21 posiciones | 1176 | **0** | 194 | **0** | 27 M3 cierre + 1 M3 apertura |
| Por combinación, 21 posiciones, rejilla histórica E0 | 1176 | **0** | 146 | **0** | **28 M3 cierre**, ningún otro |
| Oráculo, 7 posiciones por combinación | 392 | **0** | — | — | 8 M3 cierre en 392 casos largos |

Se inspecciona `diff([q_initial; trajectory])` completo. El CSV del oráculo por sí solo no basta
para comprobar monotonicidad interna. Se guardan las trayectorias de todas estas rejillas,
incluida la posición inicial; los CSV exportados se volvieron a leer con Python y reprodujeron
los mismos recuentos de fallos internos.

**MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION** permanece visible y fuera del gate operativo.
`M3_LONG_HORIZON_FAILURES=28` se refiere explícitamente a la rejilla histórica por combinación.
El caso adicional de apertura de la rejilla global es M3, PWM=-192, q_initial=1295.5, duración=3 s:
hay un retroceso interno de 0.25 encoder. Es otra muestra del dato congelado, no una regresión E0P.
No se modificó `pattern_curve.mat` para corregir ninguno de ellos.

El test antiguo de bound exigía salto <=1.5×máximo avance de la curva en 200 índices. Esa fórmula
omite la distancia desde una posición inicial anterior al recorrido empírico hasta su primer
punto. Sus fallos heredados se conservan como diagnóstico explícito, sin cambiar el factor 1.5:

| Rejilla | M | PWM | Posición inicial |
|---|---:|---:|---:|
| Global de 11 puntos | 2 | -64 | 5361.4 |
| Global de 11 puntos | 2 | -64 | 6091.2 |
| Global de 11 puntos | 2 | -64 | 6821 |
| Global de 11 puntos | 3 | -64 | 7912 |
| Por combinación de 21 puntos | 2 | -64 | 5271.3 |
| Por combinación de 21 puntos | 2 | -64 | 5550 |

Todos están antes del inicio de sus curvas en la dirección solicitada; algunos están dentro de
min_lim/max_lim. El HOLD vigente corresponde al caso distinto en que la búsqueda no encuentra
ningún punto en la dirección pedida. La primera suposición de auditoría de que bastaba usar
límites por combinación fue refutada por los dos últimos casos. Se documenta la corrección de
esa interpretación: **no se ha demostrado un bound físico general**, y no se inventa uno para
esta etapa. Los seis resultados son idénticos a E0 y mantienen la monotonicidad operativa.
El gate solicitado por Cesar conserva su criterio cero fallos de monotonicidad en 0.2 s.

## 5. Qué significa PWM64 / PWM96 / PWM alto

Se publican todas las métricas solicitadas, para cada motor/dirección/PWM, en
[E0P_PWM_DIAGNOSTICS.md](E0P_PWM_DIAGNOSTICS.md): **112 filas**, 56 por rejilla, además de los CSV.
La carrera usada como denominador es la envolvente de límites globales por motor:
M1 18246, M2 7298, M3 8822 y M4 7173 encoder. Es una referencia de la planta simulada,
no una medición nueva de hardware.

| PWM | Destinos mín./mediana/máx. — global | Media de carrera por grupo — global | Destinos mín./mediana/máx. — por combinación |
|---|---|---|---|
| 64 | 11 / **18** / 21 | 7.84–33.48 % | 12 / 18.5 / 21 |
| 96 | 5 / **12.5** / 21 | 14.08–43.42 % | 3 / 12 / 21 |
| >=128 | 2 / **3.5** / 20 | 32.51–49.48 % | 2 / **2.5** / 21 |

Cada fracción es `abs(q_final-q_initial)/carrera`. Los intervalos son el mínimo/máximo de la
**media de cada grupo**, no un desplazamiento garantizado desde cualquier estado. Los CSV
incluyen también el rango individual, el desplazamiento firmado y q_final mínimo/máximo.
El porcentaje histórico 12.7–47.2 % era `200/numel(curve)`: fracción temporal, no de carrera.

La frase «a PWM >=128 sólo hay dos destinos de 21» queda corregida:

- Rejilla global: ocurre en **18/40 grupos**, no en todos. Ningún grupo M1 tiene sólo dos destinos.
- M2 cierre: PWM192/224/255; M2 apertura: PWM160/192/224/255.
- M3: sólo apertura PWM224/255.
- M4 cierre: todos los PWM >=128; M4 apertura: PWM160/192/224/255.
- En cada uno de esos 18 grupos, **20 de 21 estados (95.24 %) terminan en el mismo endpoint** y
  el estado restante mantiene su posición. El segundo destino refleja HOLD, no resolución útil
  adicional a lo largo de toda la carrera.
- Por combinación aparecen dos destinos en 20/40 grupos; la mediana exacta es 2.5, no 2.
  Se añaden M3 apertura PWM192 y M4 apertura PWM128 respecto de la rejilla global.

Físicamente, dentro del simulador, PWM64 conserva más dependencia de la posición inicial;
PWM96 concentra más endpoints, especialmente en apertura; PWM alto lleva muchos estados al
mismo extremo en 0.2 s. M1 y varios cierres M2/M3 conservan bastantes destinos. Este barrido
varía la posición inicial con PWM fijo: **no mide el número de acciones distinguibles desde un
mismo estado**, ni prueba desempeño de control, proporcionalidad, RL o hardware. No se cambian
periodo, niveles PWM, action space, TD3 ni reward a partir de este diagnóstico.

## 6. Manifiesto, archivos y reproducción

`pairedReferencePlantManifest` comparte el selector y la resolución de rutas con el simulador.
Guarda `simPlantSource`, `patternCurvePath`, `patternCurveSHA256`, `fitC2Present` y
`curveFittingToolboxPresent`, además de ruta/hash de límites, ruta fit, versión MATLAB y fecha UTC.
La presencia de CFT sólo se registra. El manifiesto tampoco lee fit_C2 ni inspecciona cfit.

Toda futura ejecución paired-reference debe guardar este manifiesto junto a sus resultados,
usando las mismas opciones efectivas de fuente y rutas que el simulador. El runner E0P ya lo
hace automáticamente y guarda los tests y el veredicto del gate; los workflows EMG cerrados y
el entrenamiento no se ejecutan ni se modifican.

Desde `EMG_Prosthesis_TD3/matlab_code`:

```matlab
addpath(genpath('src')); addpath('config'); addpath('analysis/paired_reference');
summary = runPairedReferenceE0P();
```

Resultados en `analysis/paired_reference/e0p_results/`:

- `plant_manifest.json`, `e0p_summary.json` y `test_results.csv` (24 tests).
- Dos tablas `pwm_destination_diagnostics*.csv`, con 56 filas cada una.
- `operational_cases*.csv` y `stress_cases*.csv`, 1176 casos por archivo y rejilla.
- `operational_trajectories*.csv`, 2352 filas por rejilla, incluida q inicial.
- `stress_trajectories*.csv`, 25872 filas por rejilla, incluida q inicial.
- `e0_regression_results.csv` (784 filas) y `e0_regression_trajectories.csv` (9408 filas).

| Artefacto congelado | SHA-256 |
|---|---|
| pattern_curve.mat | `a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590` |
| plant_limits_canonical.csv | `dc643b5a656e5e9e21de6b61f0d2a614aafcfbca452c3e15acc14cbe448e9dc2` |
| plant_e0_regression_cases.csv | `203847041ebc00e83c1785b6a2a92ad2eaf33c8c730c2f95ec3f3da7a0d9da3e` |
| fit_C2.mat, sólo legado | `16382ec6f79228f9d0cfd80a59e2a8a094c65566ee769ece986c0c81af334030` |

`.gitattributes` usa `-text` para conservar bytes de los CSV/JSON versionados; no fuerza LF.
Los MAT reales y el oráculo original se conservaron. Las trayectorias, resúmenes y tests
exportados son verificaciones nuevas, no reemplazos del oráculo.

## 7. Gate y asuntos pendientes

| Criterio | Resultado |
|---|---|
| CANONICAL_SOURCE_EXPLICIT | YES |
| CFT_INDEPENDENT | YES |
| FIT_C2_NOT_USED_BY_CANONICAL_PATH | YES |
| E0_REGRESSION_PASS | YES |
| OPERATIONAL_MONOTONICITY_FAILURES | 0 en ambas rejillas de 1176 |
| OUT_OF_DOMAIN_HOLD_PASS | YES |
| LEGACY_ROUTE_PRESERVED | YES |
| TESTS_PASS | YES, 24/24 |
| E0P_RESULT | **PASS** |

Siguen sin resolverse la concentración de endpoints, las irregularidades largas M3, los saltos
al entrar en una curva desde fuera de su recorrido empírico y la interpretación de campañas
históricas sin fuente registrada. No se ha probado TD3 en esta línea nueva. No se ejecutó
EMG, RL, hardware ni ningún controlador, y MATEO/SANDRA permanecen sellados.

La conclusión científica se conserva con su alcance exacto: con dataset Denis, ventana de
0.2 s y 40 WMoos, **no se ha demostrado** información EMG suficiente para reconstruir la
trayectoria continua del guante más allá de gesto y fase. Esto no demuestra que TD3 haya fallado.

`E1_RESULT=E1_SUBJECT_SPECIFIC_ONLY`, `E1B_RESULT=E1B_EMG_ONLY_CALIBRATION_FAIL`,
`E1C_RESULT=STOPPED_AFTER_ORACLE`, `E1D_RESULT=E1D_FAIL`.

**E2_AUTHORIZED = NO. RL_AUTHORIZED = NO.** El trabajo se detiene en E0P.
