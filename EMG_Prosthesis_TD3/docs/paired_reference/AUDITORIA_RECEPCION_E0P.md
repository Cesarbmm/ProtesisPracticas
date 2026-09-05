# Auditoría de recepción de E0P

Fecha: 2026-09-05. Este documento registra el estado recibido antes de aceptar la
implementación de la IA anterior. El veredicto final y las correcciones posteriores
se documentan en `10_RESULTADOS_E0P.md`.

## Estado Git y ubicación

La ruta solicitada, `C:\Users\Cesarbmm\ProtesisPracticas\_paired\_reference`, no
estaba disponible. La copia accesible estaba en
`C:\Users\Cesarbmm\ProtesisPracticas_paired_reference`, en la rama obligatoria
`experiment/no-glove-paired-reference-td3`.

Al recibir el trabajo:

```text
HEAD = f59798acb972f95815e2499dd828c3f8725d70d7
origin/experiment/no-glove-paired-reference-td3 = f59798acb972f95815e2499dd828c3f8725d70d7
HEAD...origin/experiment/no-glove-paired-reference-td3 = 0 0
origin = https://github.com/Cesarbmm/ProtesisPracticas.git
```

El último commit era `E1D: evaluate supervised subject calibration`. Había **11
archivos en el índice**, 1927 inserciones y 11 eliminaciones, además de un archivo
no rastreado. No eran cambios remotos ni un commit E0P existente. El diff de archivos
rastreados sin preparar estaba vacío. Se conservaron todos los cambios recibidos
para auditarlos; no se hizo reset, checkout destructivo, rebase, merge ni stash.

## Clasificación de los cambios recibidos

Las rutas siguientes son relativas a la raíz del repositorio.

| Estado recibido | Archivo | Función y observación de auditoría |
|---|---|---|
| A, staged | `.gitattributes` | Desactiva conversión de finales de línea para los dos CSV. `-text` preserva bytes; no obliga a usar LF. |
| A, staged | `EMG_Prosthesis_TD3/docs/paired_reference/10_RESULTADOS_E0P.md` | Informe preliminar: declara batería MATLAB pendiente; incluye afirmaciones de resolución que requieren corrección. |
| M, staged | `EMG_Prosthesis_TD3/docs/paired_reference/BACKLOG.md` | Añade la física legacy y el diagnóstico de resolución; este último extrapola demasiado. |
| M, staged | `EMG_Prosthesis_TD3/docs/paired_reference/DECISIONES.md` | Registra implementación y gate pendiente, pero también declara cerrado el problema antes de ejecutar el gate. |
| A, staged | `EMG_Prosthesis_TD3/docs/paired_reference/PREREGISTRO_E0P.md` | Declara criterios y reconoce las mediciones Python anteriores al documento. No prueba por sí mismo el orden temporal de autoría. |
| A, staged | `EMG_Prosthesis_TD3/matlab_code/analysis/paired_reference/plant_e0_regression_cases.csv` | Oráculo de 784 casos suministrado para esta auditoría; se congela y se valida, sin regenerarlo. |
| M, staged | `EMG_Prosthesis_TD3/matlab_code/config/configurables.m` | Añade `simPlantSource = "patternCurveCanonical"`. |
| A, staged | `EMG_Prosthesis_TD3/matlab_code/src/@SimController/plant_limits_canonical.csv` | 56 pares de límites numéricos extraídos de `fit_C2`; extracción comprobada exactamente. |
| M, staged | `EMG_Prosthesis_TD3/matlab_code/src/@SimController/prosthesis_simulator.m` | Despacho canonical/legacy, fixtures por ruta y conservación del HOLD; requiere verificar contrato, cachés y equivalencia histórica. |
| A, staged | `EMG_Prosthesis_TD3/matlab_code/src/runtime/pairedReferencePlantManifest.m` | Genera fuente, rutas, hashes y diagnóstico de CFT. Su existencia sola no demuestra que cada ejecución lo guarde. |
| A, staged | `EMG_Prosthesis_TD3/matlab_code/tests/paired_reference/testPairedReferencePlantCanonicalSource.m` | Nueve tests existentes; se auditan y amplían cuando la evidencia es insuficiente. |
| ??, no rastreado | `EMG_Prosthesis_TD3/matlab_code/src/@SimController/.fuse_hidden0000000900000001` | Residuo de 3486 bytes: copia de `prosthesis_simulator.m` de `main`/`5661402e`, idéntica tras normalizar CRLF/LF. Es anterior al HOLD de E0. Se conserva y queda fuera del commit. |

El nombre `.fuse_hidden...` es compatible con un residuo de archivo abierto en un
montaje FUSE; el nombre no demuestra quién lo creó. Su contenido y su identidad
con la versión histórica sí se comprobaron.

## Procedencia y conservación de los datos

Se verificó que `pattern_curve.mat` y `fit_C2.mat` son idénticos byte a byte a los
blobs de `HEAD`. Los hashes de los cuatro artefactos coinciden con los registrados
por la implementación anterior.

| Archivo | SHA-256 recibido |
|---|---|
| `pattern_curve.mat` | `a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590` |
| `fit_C2.mat` | `16382ec6f79228f9d0cfd80a59e2a8a094c65566ee769ece986c0c81af334030` |
| `plant_limits_canonical.csv` | `dc643b5a656e5e9e21de6b61f0d2a614aafcfbca452c3e15acc14cbe448e9dc2` |
| `plant_e0_regression_cases.csv` | `203847041ebc00e83c1785b6a2a92ad2eaf33c8c730c2f95ec3f3da7a0d9da3e` |
| `.fuse_hidden0000000900000001` | `1bc97d0934c7de9e53e9147ddfd8ef5748e4bc882ce61acc7577ab149c221742` |

La tabla de límites se comparó directamente en MATLAB R2023b con los campos
numéricos `min_lim`/`max_lim` de las 56 combinaciones de `fit_C2.mat`:

```text
CANONICAL_LIMITS_MATCH_FIT = 56/56
CANONICAL_LIMITS_MAX_ERROR = 0
LIMITS_EQUAL_CURVE_RANGE = 0/56
MAX_ENDPOINT_DIFFERENCE = 2700 unidades de encoder
```

La diferencia máxima ocurre en motor 1, cierre, PWM 64: `max_lim = 17016` frente a
`max(curve) = 14316`. Los límites históricos no pueden sustituirse por el rango
de cada curva alegando equivalencia general. Su extracción numérica permite que
el simulador canónico use `pattern_curve.mat` y el CSV sin cargar `fit_C2.mat` en
ejecución. La carga de `fit_C2` realizada aquí fue exclusivamente una auditoría de
procedencia de la tabla, no una dependencia de la ruta canonical.

El oráculo tiene exactamente las ocho columnas solicitadas y 784 claves únicas
`(motor,pwm,pos,duration)`: 196 filas por motor; 14 comandos con signo; siete
posiciones iniciales por combinación y duración; 392 filas de 0.2 s y 392 de 3.0 s.
Las siete posiciones coinciden con `linspace(min_lim,max_lim,7)` dentro de 1e-9.
Todas las filas de 0.2 s tienen `n_points = 1`; las de 3.0 s, `n_points = 21`.

**Procedencia declarada frente a demostrada:** la instrucción de recepción aporta
este CSV como oráculo. Los documentos staged anteriores afirman que lo generó una
réplica Python validada contra E0; no había un generador identificable ni una
cadena de creación versionada del CSV que permitiera demostrar esa afirmación.
La estructura, los hashes y los datos de entrada sí se verificaron. Al redactar
esta auditoría, la reproducción independiente contra el código histórico de E0
con `ws` numéricos vacíos seguía pendiente y era necesaria para cerrar la
procedencia conductual. Una comparación del CSV únicamente contra el código nuevo
no bastaba para demostrarla. Su resultado posterior corresponde al informe final.

El CSV no contiene las muestras interiores. La monotonicidad de 3.0 s necesita las
trayectorias completas y debe registrarse por separado del gate de 0.2 s.

## Evidencia histórica disponible y límites de cronología

Existen localmente, fuera de los 11 cambios staged:

- `Agentes/paired_reference/stage0/stage0_audit_results.mat`, de 429407 bytes.
- `Agentes/paired_reference/stage0/stage0_toolbox_manifest.mat` y `.txt`.

El manifiesto de texto declara generación `2026-09-04 07:19:34`, MATLAB R2023b
Update 11, PCWIN64, CFT presente, licencia disponible, clase `cfit`, cero `ws`
vacíos de 56 y fuente histórica efectiva `ws`. Sus hashes MD5 de los archivos de
planta coinciden con los documentados en E0. Es evidencia local de la instalación
con CFT; la fecha de instalación anterior/posterior a E0 se apoya también en el
relato documentado del usuario.

El encabezado binario de `stage0_audit_results.mat` dice `Thu Sep 3 23:26:37 2026`;
los informes fechan E0 como 2026-09-04. Sin un huso horario en el timestamp interno
no debe adjudicarse una contradicción científica a esa diferencia de fecha.
Tampoco debe presentarse la cronología del preregistro local no committeado como
si Git certificara su hora de autoría. El texto del preregistro reconoce que la
extracción de límites y la réplica Python antecedieron a su escritura.

Los documentos E0 que aún dicen «manifiesto pendiente» representan un estado
histórico anterior: el archivo sí está disponible en esta recepción. No se
ejecutaron los workflows integrados de E0 ni se inspeccionaron registros EMG o
datos de los sujetos sellados durante esta auditoría.

## Fallos y excesos detectados en los documentos recibidos

1. `10_RESULTADOS_E0P.md`, `PREREGISTRO_E0P.md` y `DECISIONES.md` dicen que los
   límites «no coinciden en 0 de 56». La medición correcta es **coinciden en 0 de
   56; difieren en 56 de 56**, con diferencia máxima de 2700.
2. El intervalo histórico 12.7–47.2 % se calcula en el workflow E0 como
   `periodMs / numel(curve)`. Es una **fracción temporal de la curva muestreada**,
   no una medición del desplazamiento de encoder dividido por la carrera.
   Llamarlo «porcentaje de carrera recorrida» requiere otra métrica explícita.
3. «Dos destinos de 21 a PWM >=128» aparece como mediana agregada, sin tabla que
   muestre motor, dirección y PWM. No significa dos destinos en cada combinación,
   ni mide por sí solo el número de acciones distinguibles desde un mismo estado.
   Deben publicarse los 56 grupos y definir la tolerancia de igualdad.
4. Los endpoints publicados inicialmente en E0 incluyen resultados anteriores al
   HOLD. La sección 6 de `03_RESULTADOS_E0.md` declara que los grupos invariantes
   cambian de 76 a cero tras el fix. Mezclar ambas condiciones falsearía el
   diagnóstico E0P. Los recuentos finales deben usar la física post-HOLD.
5. Afirmar que desaparece el control proporcional, que esto prueba la física del
   hardware o que explica las mesetas de agentes históricos excede lo observado.
   El barrido caracteriza la planta simulada congelada y la concentración de sus
   endpoints; no es una prueba de control cerrado, RL ni hardware.
6. La conclusión científica autorizada es que **no se ha demostrado** información
   EMG suficiente más allá de gesto y fase bajo dataset Denis, ventana de 0.2 s y
   40 WMoos. La frase recibida «la EMG no aporta información» es más fuerte y debe
   corregirse sin reabrir E1/E1B/E1C/E1D.
7. «Cerrado por E0P, pendiente de batería» no es un veredicto de gate válido. La
   declaración final debe esperar la ejecución, revisión de artefactos y tests.

## Primera ejecución de los tests recibidos

La primera batería MATLAB de esta auditoría encontró ocho tests aprobados y uno
incompleto/fallido: `testOutOfDomainHolds` utiliza `Diagnostic=` como parámetro de
`verifyEqual`, que esta API no reconoce. Esto impide aceptar `TESTS_PASS` aunque el
HOLD del simulador pueda ser correcto. La comparación de regresión sí informó
`1.164e-10` de error máximo sobre los 784 casos, inferior al umbral recibido de
1e-9; sigue siendo necesario comprobar su equivalencia con E0 de forma
independiente.

Las pruebas iniciales de independencia de CFT y legado eran limitadas: cargar
`cfit` antes de una llamada no reproduce una instalación conceptualmente sin CFT,
y comprobar tamaño/ausencia de NaN en `legacyAuto` no demuestra equivalencia con
el código histórico. Esas carencias, el estrés M3 separado y el guardado efectivo
del manifiesto deben resolverse antes del veredicto final. Este documento conserva
el estado de recepción; no sustituye el informe de cierre.


## Nota de cierre posterior a la recepción

El estado inicial descrito arriba se conserva. Su validación pendiente ya se completó:
784 trayectorias canónicas son idénticas al código MATLAB f59798ac con la condición E0 ws=[];
1568 trayectorias legacy coinciden con la referencia congelada; 24/24 tests finales pasan.
La referencia sólo cambia nombre y rutas, verificado contra Git. La prueba independiente
establece la equivalencia conductual del oráculo, sin atribuirle una cronología de generación
no certificada. El informe final, la corrección de los diagnósticos y sus límites están en
`10_RESULTADOS_E0P.md` y `E0P_PWM_DIAGNOSTICS.md`.

Al preparar el commit apareció un `index.lock` vacío, fechado 2026-09-04 23:34:32
local, anterior a esta preparación. Se verificó dos veces que no había procesos
git/git-lfs y se pudo abrir el lock de forma exclusiva. Se conservó renombrándolo
a `index.lock.e0p-audit-preserved-20260905` dentro del gitdir de este worktree.
No se eliminó el archivo ni se alteraron índices o datos para resolver el bloqueo.
