# E1.B.2 — Procedencia de `normValues.mat` (C y S)

**Fecha:** 2026-09-04 · **Archivo:** `matlab_code/config/normValues.mat`
**MD5:** `650ac152f78b3840872aa92b3806b2aa` · **Tamaño:** 39 041 695 bytes

---

## 1. Por qué se audita

`configurables.m:257-261` carga `C` y `S` de este archivo y construye:

```matlab
params.fGetFeatures = @(x) getWmoosFeatures(x, params.norm.C, params.norm.S);
```

y `getWmoosFeatures` termina con:

```matlab
features = normalize(features, 'center', C, 'scale', S);
```

Si `C` y `S` se hubieran calculado con los 12 sujetos de Denis, incluidos los de test, cualquier
afirmación de generalización a sujetos no vistos quedaría comprometida.

## 2. Qué contiene realmente el archivo

El archivo pesa 39 MB, no los 640 bytes que costarían dos vectores de 40. Contiene el **workspace
completo** con el que se calcularon C y S:

| variable | forma | qué es |
|---|---|---|
| `C` | 40 × 1 | centro (el que usa el pipeline) |
| `S` | 40 × 1 | escala (el que usa el pipeline) |
| `F` | 40 × **45900** | matriz de features cruda |
| `N` | 40 × 45900 | la misma, ya normalizada |
| `fi` | 40 × 25 | features de un sujeto (25 repeticiones) |
| `gestures` | 6 | nombres de gesto (string, no legible fuera de MATLAB) |
| `featuresData` | struct | **`user1` … `user306`** |
| `i` | 306 | contador final del bucle |
| `ans` | `'linear'` | residuo de sesión |

**La aritmética cierra exactamente:**

```
306 usuarios × 6 gestos × 25 repeticiones = 45 900 = columnas de F
```

## 3. Conclusión

`C` y `S` **no se calcularon con el dataset Denis de 12 sujetos**. Se calcularon con un corpus de
**306 sujetos y 6 gestos**, veinticinco veces mayor, y de naturaleza distinta: gestos discretos, no
trayectorias con guante.

Lo que **no** se puede demostrar desde el archivo: si alguno de los 12 sujetos de Denis participó
también en esa recolección de 306. Los identificadores son anónimos (`user1` … `user306`) y no hay
tabla de correspondencia.

```
PREPROCESSING_LEAKAGE_STATUS = POSSIBLE_LEAKAGE
```

Se elige la etiqueta conservadora porque el solapamiento es **inverificable**, no porque haya
indicios de él.

## 4. Por qué el riesgo real es bajo, y por qué aun así se etiqueta así

Tres argumentos, que limitan pero no eliminan la reserva:

1. **La estadística es no supervisada.** `C` y `S` son centro y escala de las features de EMG. No
   intervienen el guante, `flexConverted` ni ninguna etiqueta. El mecanismo **no puede transmitir
   información del target**, que es la forma de fuga que amenazaría el gate de E1.
2. **La dilución es enorme.** Aun con solapamiento total de los 12, su peso sobre un estadístico
   calculado con 45 900 ventanas de 306 sujetos sería del orden del 4 %.
3. **El corpus es de otra tarea.** 6 gestos discretos × 25 repeticiones no es el protocolo
   `closing`/`opening` con guante del dataset Denis.

Lo que sí quedaría, en el peor caso, es una normalización ligeramente mejor ajustada a la
distribución de features de un sujeto de test. Eso puede inflar el desempeño, pero no fabrica
información EMG→guante donde no la haya — y ese es exactamente el punto que los controles de
permutación de B.7 verifican de forma independiente.

## 5. Decisión operativa

- **NO se recalculan C ni S.** Se mantiene el pipeline histórico para compatibilidad, tal como se
  pidió.
- Se documenta la etiqueta y se limitan las conclusiones en consecuencia: E1 no puede reclamar
  `KNOWN_CLEAN` hasta cerrar el punto 6.
- Si el gate de E1 se decidiera por un margen estrecho, esta reserva sería material y habría que
  repetir con C/S recalculados sólo con los 8 sujetos de train.

## 6. Comprobación pendiente, barata y decisiva

Una vez exportado el dataset de E1 se puede calcular el centro y la escala de las 40 features **con
los 12 sujetos de Denis** y compararlos con los `C` y `S` almacenados.

- Si difieren de forma clara → evidencia fuerte de que C/S no salieron de Denis, y la etiqueta puede
  pasar a `KNOWN_CLEAN`.
- Si coincidieran casi exactamente → habría que revisar la conclusión de la sección 3.

Cuesta una línea de código y se ejecuta con el resto del análisis de E1. Queda registrado aquí
**antes** de mirar el resultado.
