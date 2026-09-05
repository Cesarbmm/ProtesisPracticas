# PREREGISTRO E0P — Fuente canonica y reproducible de la planta

- **Fecha de registro:** 2026-09-05
- **Rama:** `experiment/no-glove-paired-reference-td3`
- **SHA de arranque:** `f59798acb972f95815e2499dd828c3f8725d70d7`
- **Estado de sincronizacion al abrir:** `git rev-list --left-right --count HEAD...origin/experiment/no-glove-paired-reference-td3` -> `0 0`. Local y remoto en el mismo commit. No hubo pull, merge, rebase ni reset.
- **Etapa previa cerrada:** E1D (`09_RESULTADOS_E1D.md`), veredicto `FAIL`.

---

## 1. Por que existe esta etapa

E0 dejo abierto un defecto de reproducibilidad, registrado en `04_CIERRE_E0.md` seccion 3.6 y en
`DECISIONES.md`:

> `prosthesis_simulator.m` decide la fisica en tiempo de ejecucion. Carga `fit_C2.mat`, que contiene
> objetos `cfit`. Si Curve Fitting Toolbox **no** esta instalada, MATLAB los lee como `[]` y el codigo
> cae a la rama de `pattern_curve.mat`. Si **si** lo esta, los lee como `cfit` con `numel(ws) = 1` y
> la trayectoria se colapsa.

La consecuencia es la que hay que eliminar:

> **Una misma revision de Git puede producir dos fisicas distintas segun que toolboxes tenga instaladas
> la maquina que la ejecuta.**

Los numeros de E0 se produjeron en una maquina **sin** Curve Fitting Toolbox. La toolbox se instalo
despues. Sin esta etapa, cualquier re-ejecucion futura de E0 en la maquina actual daria resultados
distintos sin que ningun commit lo explique.

E0P **no es un experimento**. No tiene hipotesis cientifica, no produce evidencia sobre la tesis y no
autoriza nada. Es un cambio de contrato de ingenieria con criterios de aceptacion fijados por
adelantado.

---

## 2. Objetivo

Que la fuente de fisica de la planta sea:

1. **Explicita**: declarada en configuracion y en el manifiesto, no inferida de lo que haya instalado.
2. **Determinista**: la misma revision de Git produce la misma trayectoria en cualquier maquina.
3. **Verificable**: hash de los archivos de datos, registrado junto a cada resultado.
4. **Retrocompatible**: la fisica historica sigue siendo reproducible bajo una etiqueta propia.

---

## 3. Alcance: lo que esta etapa NO hace

Fijado antes de escribir codigo.

| Prohibicion | Motivo |
|---|---|
| No reconstruir `fit_C2.mat` ni sus objetos `cfit` | Instruccion explicita. Los coeficientes no son recuperables sin inventar datos. |
| No modificar `pattern_curve.mat` | Es el dato de caracterizacion. Cambiarlo cambiaria la fisica que E0 valido. |
| No cambiar la fisica de la rama `pattern_curve` | El objetivo es fijarla, no mejorarla. Cualquier diferencia numerica frente a E0 es un fallo de esta etapa, no una mejora. |
| No revertir el fix de HOLD de E0 | El `return` con `repmat(pos, n_points, 1)` cuando la busqueda de `x_0` falla se conserva literal. |
| No corregir la no monotonia del motor 3 en cierre | Defecto del dato de caracterizacion, en `BACKLOG.md`. Fuera del gate. |
| No tocar `main`, no hacer push | Instruccion permanente de la linea. |
| No autorizar E2 ni entrenamiento RL | Aunque E0P pase: `E2_AUTHORIZED = NO`, `RL_AUTHORIZED = NO`. |

---

## 4. Arquitectura: alternativas consideradas y por que se descarto la mas simple

La instruccion pedia justificar la arquitectura antes de implementarla, y preferir la mas simple y
segura si existia. Se evaluaron tres.

### Alternativa A — Borrar `fit_C2.mat` y dejar solo la rama `pattern_curve`

**Descartada.** Destruye la reproducibilidad de la fisica historica y es un cambio irreversible sobre
un artefacto versionado. Ademas los limites por combinacion viven dentro de ese archivo (ver C).

### Alternativa B — Derivar los limites del propio `pattern_curve.mat`

Seria la mas simple: la ruta canonica no necesitaria ningun archivo nuevo. Se comprobo
**antes** de implementar, sobre las 56 combinaciones (7 PWM x 2 direcciones x 4 motores):

> Los limites almacenados en `fit_C2.mat` **no** coinciden con el rango de la curva correspondiente en
> **0 de 56** combinaciones. Las diferencias llegan a ~2700 unidades de encoder.

**Descartada por evidencia.** Derivarlos habria cambiado la fisica, que es exactamente lo que esta
etapa prohibe.

### Alternativa C — Extraer los limites a una tabla versionada (ELEGIDA)

Los limites se extraen **literalmente** de los campos numericos de `fit_C2.mat` (no se recalculan, no
se reconstruyen, no se ajusta ningun modelo) y se guardan en un CSV versionado. La ruta canonica
carga entonces solo dos archivos:

- `pattern_curve.mat`
- `plant_limits_canonical.csv`

y **no carga `fit_C2.mat` en ningun caso**. Esto satisface la condicion mas fuerte que pedia la
instruccion (`idealmente ni siquiera debe necesitar cargar fit_C2.mat`): la independencia de Curve
Fitting Toolbox no se consigue detectando la toolbox, sino no tocando nunca el archivo que la
requiere. No se llama a `license`, no se inspecciona `class(ws)`, no hay `try/catch` sobre la carga.

---

## 5. Contrato

```matlab
params.simPlantSource = "patternCurveCanonical";   % por defecto en esta rama
% params.simPlantSource = "legacyAuto";            % solo para reproducir corridas historicas
```

| Valor | Semantica |
|---|---|
| `"patternCurveCanonical"` | Carga `pattern_curve.mat` + `plant_limits_canonical.csv`. Nunca abre `fit_C2.mat`. Independiente de las toolboxes instaladas. |
| `"legacyAuto"` | Comportamiento historico literal, incluida la deteccion en tiempo de ejecucion de `fit_C2.mat`. Se conserva **sin modificar** para poder reproducir corridas antiguas. |

Resolucion cuando el campo no existe (por ejemplo al ejecutar codigo de `main`): `"legacyAuto"`. Asi
la semantica de `main` queda intacta y esta etapa no altera ninguna rama que no la declare.

---

## 6. Criterios de aceptacion (gate E0P)

Fijados antes de ejecutar la bateria en MATLAB. Todos son de tipo "cero fallos" o "igualdad exacta":
no hay ningun umbral que pueda moverse despues de ver datos.

| # | Criterio | Condicion de aprobado |
|---|---|---|
| G1 | La fuente canonica es explicita | `manifest.simPlantSource == "patternCurveCanonical"` con la configuracion de la rama |
| G2 | La ruta canonica no usa `fit_C2.mat` | Pasar una ruta inexistente a `fitC2Path` no cambia ni un digito de la salida |
| G3 | La salida canonica no depende de Curve Fitting Toolbox | Forzar la carga de la clase `cfit` antes de simular no cambia la salida |
| G4 | Se conserva el fix de HOLD | Fuera del dominio de la curva, la trayectoria es constante e igual a la posicion inicial |
| G5 | Monotonia operativa en unidades reales de encoder | `OPERATIONAL_MONOTONICITY_FAILURES = 0` sobre la rejilla de 1176 casos del paso de 0.2 s |
| G6 | Regresion contra la fisica de E0 | `E0_REGRESSION_MAX_ERROR < 1e-9` sobre los 784 casos de `plant_e0_regression_cases.csv` |
| G7 | La tabla de limites coincide con `fit_C2.mat` | 56/56 combinaciones identicas |
| G8 | Los hashes del manifiesto coinciden con los literales registrados | SHA-256 exactos |
| G9 | La ruta `legacyAuto` sigue existiendo y es alcanzable | El despacho la selecciona cuando se pide explicitamente |

**Fuera del gate, por instruccion:**

- El caso de estres de 3.0 s del motor 3 en cierre (28 fallos residuales). Es un defecto del dato de
  caracterizacion, ya registrado. Se reporta como `M3_LONG_HORIZON_FAILURES` pero no decide.
- Los diagnosticos de resolucion de la seccion 9. Son descriptivos.

**Baseline de la regresion G6:** la fisica **sin** Curve Fitting Toolbox, es decir la rama
`pattern_curve` tal como se ejecuto en E0, con el fix de HOLD aplicado. Se prohibe expresamente usar
como baseline la ruta actual `ws`/`cfit`, porque es precisamente la que esta etapa declara no
canonica.

---

## 7. Bateria de tests

Archivo: `matlab_code/tests/paired_reference/testPairedReferencePlantCanonicalSource.m`.
Lista explicita en `functiontests({...})`, nunca `localfunctions`.

| Test | Criterio |
|---|---|
| `testCanonicalSourceIsExplicit` | G1 |
| `testCanonicalDoesNotUseFitC2` | G2 |
| `testCanonicalUnchangedAfterLoadingCfit` | G3 |
| `testOutOfDomainHolds` | G4 |
| `testOperationalMonotonicity` | G5 |
| `testE0Regression` | G6 |
| `testLimitsTableMatchesFitC2` | G7 |
| `testManifestHashes` | G8 |
| `testLegacyRoutePreserved` | G9 |

Restricciones de los tests, fijadas de antemano:

- La independencia de `fit_C2.mat` se comprueba **pasando una ruta de fixture inexistente**
  (`tempdir`). **Prohibido** renombrar, mover o borrar archivos reales del repositorio durante los
  tests.
- La monotonia operativa usa **posiciones reales de encoder** tomadas de la tabla de limites de cada
  combinacion. **Prohibido** usar `[0,1]` normalizado como posicion de entrada: fuera del dominio la
  planta hace HOLD y el test seria vacio.

---

## 8. Manifiesto

`matlab_code/src/runtime/pairedReferencePlantManifest.m` devuelve, para acompanar todo resultado
futuro:

`simPlantSource`, `patternCurvePath`, `patternCurveSHA256`, `limitsPath`, `limitsSHA256`,
`fitC2Present`, `fitC2SHA256`, `curveFittingToolboxPresent`, `cfitClassExists`, `matlabVersion`,
`timestamp`.

`curveFittingToolboxPresent` y `cfitClassExists` son **puramente informativos**: quedan registrados
para poder auditar el entorno, pero ninguna decision del codigo canonico los consulta. Esa es la
diferencia con `legacyAuto`.

Hashes registrados en el momento del preregistro:

| Archivo | SHA-256 |
|---|---|
| `pattern_curve.mat` | `a519555bcfcbbc7b140843d6fc1240118738cd3a6ca69f6f5517617372073590` |
| `plant_limits_canonical.csv` | `dc643b5a656e5e9e21de6b61f0d2a614aafcfbca452c3e15acc14cbe448e9dc2` |
| `plant_e0_regression_cases.csv` | `203847041ebc00e83c1785b6a2a92ad2eaf33c8c730c2f95ec3f3da7a0d9da3e` |
| `fit_C2.mat` (solo referencia, no usado por la ruta canonica) | `16382ec6f79228f9d0cfd80a59e2a8a094c65566ee769ece986c0c81af334030` |

---

## 9. Diagnosticos de resolucion — DIAGNOSTIC_ONLY

Se reporta, sin efecto sobre el gate, cuanto recorrido cubre un paso de control de 0.2 s y cuantos
destinos distintos alcanza. No se propone ningun cambio de periodo de control ni de niveles de
comando en esta etapa.

---

## 10. Declaracion de orden temporal

Por honestidad del registro, lo que ya se habia ejecutado **antes** de escribir este documento:

1. La comprobacion de la alternativa B (limites frente a rango de curva, 0/56). Se ejecuto
   precisamente para poder justificar la arquitectura antes de implementarla, como pedia la
   instruccion.
2. Una replica en Python de la rama `pattern_curve` con el fix de HOLD, usada para **generar** el
   archivo de casos de regresion y para pre-verificar la monotonia operativa y los diagnosticos de
   resolucion.

Ninguno de los criterios del gate se fijo a la vista de esos numeros: G1-G9 son cero fallos o
igualdad exacta, no umbrales elegibles. La replica en Python es el **generador** del baseline, no un
resultado del gate; la verificacion que decide es la ejecucion en MATLAB.

**Lo que queda pendiente de ejecucion en MATLAB en el momento de este registro:** la bateria completa
de 9 tests y la llamada a `pairedReferencePlantManifest()`. `E0P_RESULT` no puede declararse hasta
entonces.

---

## 11. Consecuencia declarada de antemano

Pase o no pase E0P:

- `E2_AUTHORIZED = NO`
- `RL_AUTHORIZED = NO`

E0P repara reproducibilidad. No cambia ninguna de las conclusiones de E1, E1B, E1C ni E1D, que se
obtuvieron **offline**, sin simulador y sin planta: ningun numero de esas cuatro etapas pasa por
`prosthesis_simulator.m`.

---

## 12. Enmienda de auditoria de recepcion (2026-09-05)

Se conserva arriba el registro recibido, incluidos sus errores, para distinguirlo de esta
auditoria. Esta enmienda aplica las instrucciones de Cesar al relevo de IA; no cambia la
tolerancia de regresion (error absoluto < 1e-9), los datos de planta ni el gate operativo.

- En las secciones 4 y 10, «no coinciden en 0 de 56» es una negacion equivocada: **coinciden
  en 0/56 y difieren en 56/56**. La extraccion de limites coincide exactamente con los campos
  numericos historicos en 56/56; diferencia maxima frente al rango de curvas: 2700 encoder.
- El oraculo CSV se recibe congelado del usuario, con el hash ya registrado. El documento
  anterior atribuye su generacion a Python, pero no adjunta ese generador. Su procedencia
  conductual se contrasta ahora contra el codigo MATLAB de `f59798ac` con una fixture temporal
  `ws=[]`. No se vuelve a generar el oraculo usando la implementacion que se evalua.
- G2/G3 se refuerzan con una copia aislada del simulador sin `fit_C2.mat`, perfiles de llamadas
  y exclusion temporal de CFT del path de prueba. Ningun archivo real se renombra o elimina.
- G9 exige igualdad de trayectorias completas frente a la implementacion congelada de
  `f59798ac`, tanto con el fit real como con la fixture numerica `ws=[]`.
- Se comprueban fuente invalida y cambios de configuracion sin limpiar caches. El manifiesto
  comparte el selector y acepta las mismas rutas explicitas; `outputPath` guarda JSON. Se
  retiran `fitC2SHA256` y `cfitClassExists`: ni siquiera el manifiesto necesita leer fit ni
  inspeccionar cfit. La presencia del archivo y de CFT sigue registrada como diagnostico.
- La rejilla global de 21 posiciones por motor y la rejilla de limites por combinacion se
  reportan por separado. Los 28 fallos historicos de estres no se trasladan a otra rejilla.
  La monotonicidad usa la trayectoria completa, incluida la posicion inicial. Los casos de
  3 s conservan la etiqueta `MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION`.
- El porcentaje historico `200/numel(curve)` mide duracion, no desplazamiento/carrera. Los
  diagnosticos nuevos calculan desplazamiento en encoder y lo dividen por una carrera
  declarada. «2 destinos de 21» debe describir un subconjunto o estadistico concreto.
- `.gitattributes` con `-text` conserva los bytes de los CSV; no fuerza LF.

La primera bateria recibida se ejecuto antes de editar codigo: 8/9 tests aprobaron; HOLD dio
error por `Diagnostic=` no admitido en MATLAB R2023b. El resultado definitivo y las tablas se
registran en `10_RESULTADOS_E0P.md`. Esta enmienda no convierte aquel primer fallo en aprobado.


### Cierre de la enmienda tras ejecución

La auditoría completa terminó con 24/24 tests y E0P PASS. Se añadieron fixtures para cambios
relativos de directorio: la resolución usa `pwd` de MATLAB, porque el directorio base de Java
no sigue necesariamente `cd`. Simulador y manifiesto comparten esta resolución.

Los tests históricos de estrés y bound se clasificaron conforme al gate operativo autorizado.
La rejilla por combinación reproduce 28 M3 cierre; la global, 27 cierre y 1 apertura M3 de 0.25
encoder. El antiguo bound de 1.5×avance de curva omite la distancia de entrada a la curva:
cuatro excesos global11 y dos por combinación21 se conservan como caracterización, con el
mismo factor y resultados idénticos al código E0 congelado. No se presentan como cero fallos
del bound original. La suposición provisional de que todos estaban fuera de min_lim/max_lim
fue refutada; están antes del recorrido empírico, y algunos dentro de los límites numéricos.

Esta clasificación queda registrada después de medirla, no como un criterio previo inventado.
La regresión y la monotonicidad exigidas por Cesar mantienen sus criterios originales.
