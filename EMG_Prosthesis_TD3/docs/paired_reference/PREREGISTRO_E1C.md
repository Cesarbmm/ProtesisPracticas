# PREREGISTRO — ETAPA E1C (alineación espacial de canales EMG)

**Rama:** `experiment/no-glove-paired-reference-td3`
**Fecha de registro:** 2026-09-04 — **antes de calcular ningún resultado**
**Antecedentes congelados:** `E1 = FAIL` (`E1_SUBJECT_SPECIFIC_ONLY`) ·
`E1B = FAIL` (`E1B_EMG_ONLY_CALIBRATION_FAIL`, 0 de 8).

> **Última hipótesis EMG-only de la línea.** Si falla, no se abre otra transformación EMG-only.

---

## 1. Pregunta

¿Alinear circularmente los 8 canales **antes** de WMoos recupera una fracción material de la
transferencia entre sujetos?

## 2. Por qué E1B no podía responderla

E1B corrigió media y varianza **por feature**, después de WMoos. Una rotación del brazalete es una
**permutación de la identidad espacial de los canales**, y ninguna renormalización marginal la
corrige: cambia qué músculo alimenta cada dimensión, no su escala.

## 3. Sujetos

```
DEVELOPMENT (10) : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN, KHAROL
FINAL TEST  (2)  : MATEO, SANDRA        <- SELLADOS
```

## 4. Acciones espaciales candidatas

- **Primario:** 8 desplazamientos circulares `r = 0..7`.
- **Secundario, preregistrado:** dirección de canales invertida, con sus 8 desplazamientos.

Máximo **16 configuraciones**. No se prueban permutaciones arbitrarias (8! = 40 320): no tienen
justificación física y convertirían el oráculo en un ajuste de ruido.

## 5. Dónde se aplica el desplazamiento

```
EMG cruda N x 8  ->  shift circular de columnas  ->  WMoos historicas EXACTAS
                 ->  C/S historicos EXACTOS      ->  ridge 40 -> 4
```

`WMoos_F2` no se modifica. `C`/`S` no se recalculan. **No** se reordenan features después de WMoos.

**Nota técnica que obliga a recalcular desde la EMG cruda:** los bloques F1, F4, F5 y F13 se
calculan por canal, así que bajo un desplazamiento circular sólo se permutan. `WMoos_F2` **no**:
aplica `hilbert` y `sgolayfilt` a lo largo del eje de canales, y el filtro de Savitzky-Golay no es
circular. Por tanto F2 cambia de forma no trivial y el experimento exige recomputar las 40
features, no permutar el vector exportado.

### 5.1 Requisito de verificación previo, bloqueante

Las features se recalculan fuera de MATLAB. Antes de usar ese cálculo:

> El recálculo con `shift = 0` debe reproducir el `X` exportado por MATLAB con error relativo
> máximo **≤ 1e-10** sobre una muestra amplia de los 10 sujetos.

Si no se cumple, **E1C se aborta como no verificable** y se pide el recálculo en MATLAB. La
replicación ya se validó en E1 §1.4 sobre 30 ventanas y 3 sujetos con error ≤ 6.1e-14; aquí se
extiende la comprobación.

## 6. Oráculo diagnóstico, primero

Para cada fold LOSO de development: se entrena el ridge global con los otros 9 **sin desplazar**, y
para el sujeto dejado fuera se prueban los 8 desplazamientos, eligiendo **con los targets** el de
menor MSE.

```
ETIQUETA OBLIGATORIA = CHANNEL_ALIGNMENT_ORACLE_DIAGNOSTIC_ONLY
```

No es desplegable y no cuenta como resultado final. Su única función es medir si la hipótesis tiene
**potencial**.

`k` y `lambda` se seleccionan por folds internos de development, **por separado para cada brazo**,
sobre la misma malla que E1B, de modo que el único factor aislado sea el desplazamiento.

## 7. GATE DE POTENCIAL — fijado AHORA

```
ORACLE_ALIGNMENT_POTENTIAL = YES
```

sólo si se cumplen las tres:

| # | condición | umbral |
|---|---|---|
| 1 | reducción media de MSE frente al ridge sin alinear | **≥ 15 %** |
| 2 | sujetos que mejoran | **≥ 7 de 10** |
| 3 | motores que mejoran | **≥ 3 de 4** |

**Si no pasa: E1C termina de inmediato.**

```
CHANNEL_ALIGNMENT_HYPOTHESIS = REFUTED
E1C_RESULT = STOPPED_AFTER_ORACLE
```

No se desarrolla selector EMG-only, no MLP, no E2, no RL.

## 8. Sólo si el oráculo pasa

Selector de desplazamiento **exclusivamente EMG**. No puede leer guante, `flexConverted`, `y`,
reward, `q` ni información de test. Sí puede usar la etiqueta de instrucción `Opening`/`Closing`,
porque la calibración operacional puede pedir al usuario varias aperturas y cierres sin guante.

Regla candidata: comparar la firma estadística por canal del sujeto de calibración contra
*templates* construidos **sólo con sujetos de train**. La regla exacta se define con folds internos
de development. **Nunca** se usa el MSE contra guante para elegir el desplazamiento del sujeto
evaluado.

Presupuestos de calibración, por episodios completos: **2, 5, 10 repeticiones por gesto**, con su
equivalente en segundos de EMG. La calibración contiene sólo EMG y la etiqueta de instrucción.

## 9. Evaluación honesta

LOSO sobre los 10 de development. Por sujeto dejado fuera: train → templates y ridge; subconjunto de
calibración → elección del desplazamiento sólo con EMG; subconjunto de evaluación disjunto por
episodios → medición contra guante. Sin ventanas compartidas. `k` y `lambda` por folds internos.

## 10. Brazos comparados

| | |
|---|---|
| A | ridge global de E1, sin alineación |
| B | ridge + z-normalización de E1B |
| C | ridge + desplazamiento oráculo — `DIAGNOSTIC_ONLY` |
| D | ridge + desplazamiento elegido sólo con EMG — candidato real |
| E | baseline gesto+fase — `DIAGNOSTIC_ORACLE` |

Para D, además: shuffle global y shuffle condicionado por gesto y fase.

## 11. Pregunta adicional sobre la interpretación física

Se analizan los desplazamientos del oráculo por sujeto: si aparece un desplazamiento estable por
sujeto, si `Closing` y `Opening` prefieren el mismo, si es consistente entre repeticiones y si los
cuatro motores coinciden.

> Si el mejor desplazamiento cambia de forma caótica según gesto, motor o repetición, la
> explicación de "rotación del brazalete" queda debilitada **aunque el MSE medio mejore**, y así
> debe reportarse.

## 12. GATE FINAL E1C

El método EMG-only pasa sólo si: el oráculo demostró potencial ≥ 15 % · el selector EMG-only
recupera una fracción material de ese potencial · mejora de MSE ≥ 15 % frente al ridge de E1 ·
≥ 7/10 sujetos · ≥ 3/4 motores · sign accuracy aumenta · shuffle global degrada · shuffle
condicionado degrada > 5 % · los desplazamientos son físicamente interpretables y estables.

En cualquier otro caso `E1C_RESULT = FAIL` y **se cierra la línea de adaptación EMG-only entre
sujetos**.

## 13. Fuera de alcance

MATEO/SANDRA · E2 · `Env` · `SimController` · planta · RL · TD3 · MLP · LSTM · contexto 120 ·
reward · espacio de acción · corregir WMoos · recalcular `C`/`S` · `git push`.

## 14. Siguiente decisión si falla

No se abre otra transformación EMG-only. La siguiente opción a discutir será
`SUPERVISED_SUBJECT_CALIBRATION`. **No se implementa.**

## 15. Resultado

Ejecutado 2026-09-04. Detalle en `08_RESULTADOS_E1C.md`.

```
verificacion 5.1        : PASA con el criterio de la Enmienda 1 (error absoluto max 2.7e-15)
oraculo, letra de la §6 : +21.9 %  <- conjuntos de evaluacion de distinto tamano, no pareado
oraculo, config comun   : +15.5 %  <- dominado por el fold de DENIS con lambda = 0.01
oraculo, lambda modal   : +3.5 %   (mediana por sujeto +1.0 %)
transferencia mitades   : +3.3 %   <- el techo honesto del metodo
sujetos que mejoran     : 7/10, tres de ellos por <= 1.1 % y tres por 0.0 %
motores que mejoran     : 4/4, por margenes minimos
sign accuracy           : 0.539 -> 0.541
closing == opening      : 2/10 sujetos
los 4 motores coinciden : 0/10 sujetos
```

## 16. Veredicto

```
ORACLE_ALIGNMENT_POTENTIAL   = NO
CHANNEL_ALIGNMENT_HYPOTHESIS = REFUTED
E1C_RESULT                   = STOPPED_AFTER_ORACLE
```

El desplazamiento **si** es una propiedad reproducible del sujeto: transfiere entre mitades casi
intacto. Pero vale ~3 %, no 15 %, y no se comporta como una rotacion del brazalete (los gestos
coinciden en 2/10 sujetos y los motores en 0/10).

El paro es forzado, no una opinion: el selector EMG-only **no puede superar al oraculo**, cuyo techo
honesto es +3.3 %, y el gate final de §12 exige >= 15 %. E1C no puede pasar aunque el selector fuera
perfecto.

## Enmienda 2 - 2026-09-04, DESPUES de ver los datos

La condicion 1 del gate de potencial, leida al pie de la letra sobre el estimador anidado con
configuracion comun, da +15.5 % y **pasaria**. No se declara `POTENTIAL = YES` porque se demuestra
que ese numero no mide alineacion: fijando `lambda` al valor modal el mismo oraculo da +3.5 %, y la
transferencia por mitades da +3.3 %.

Es una **anulacion de un aprobado nominal**, no una relajacion de umbral, y queda registrada como
tal. Es revisable: atenerse a la letra del preregistro implicaria construir el selector EMG-only
sabiendo que su techo es +3.3 % frente a un gate final del 15 %.

---

## Enmienda 1 - 2026-09-04, **DESPUES de ejecutar la verificacion 5.1**

> Posterior a ver el dato. Se registra como tal. **No cambia ningun umbral de resultado**: corrige
> el instrumento de medida de la verificacion previa, no el gate cientifico.

El criterio de 5.1 se escribio como error **relativo** maximo <= 1e-10. Al ejecutarlo:

| sujeto | error rel. max | error abs. max | celdas con rel > 1e-10 |
|---|---|---|---|
| BLANCA | 3.209e-10 | 2.665e-15 | **1** de 383 520 |
| EMILIA | 4.617e-10 | 1.776e-15 | **1** de 365 200 |
| los otros 8 | <= 9.7e-12 | <= 3e-15 | 0 |

Diagnostico de las dos celdas: valor exportado 6.771e-07 y 6.076e-07, diferencia absoluta 2.173e-16
y 2.805e-16. Es ruido de coma flotante sobre una feature practicamente nula; el error relativo se
dispara porque el denominador tiende a cero, no porque el calculo difiera.

**Criterio corregido, aplicado desde ahora:**

> El recalculo con `shift = 0` reproduce el `X` exportado si, para cada celda, el error relativo es
> <= 1e-10 **o** el error absoluto es <= 1e-12.

Con ese criterio: **PASA en los 10 sujetos** (peor error absoluto global 2.7e-15).

Se deja constancia de que un hallazgo previo de esta misma verificacion **si** era real y se
corrigio antes: la primera reconstruccion rellenaba con ceros la ultima ventana de cada episodio,
cuando `RecordedMyo.readEmg` devuelve una ventana parcial. Ese error producia desviaciones de hasta
2.3e+01 en 5 sujetos. La verificacion 5.1 hizo exactamente el trabajo para el que se escribio.
