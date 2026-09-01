# ETAPA 7R — preinscripción de atribución EMG con pares reales

Fecha: 2026-08-31.

ETAPA 7R es estrictamente offline. No entrena, no crea `Env`, no ejecuta planta
o simulador, no calcula DTW y no modifica referencia, estado, reward, TD3,
cuantización, gate ni seguridad. Su objetivo es comprobar si las diferencias de
features EMG explican diferencias de acción una vez restringido el contexto
mecánico, usando únicamente estados completos observados.

## 1. Evidencia congelada

Padre canónico:

```text
ETAPA 7Q = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7q_artifacts\stage7q_final\2026-08-30_16-44-30-296
SHA256(manifest.json) = 4ECA54839AC8CF60A48B5F6E13ABDEB386BEDA9A851C7421EE782F50D6EDF57F
scientificResult = distributedOrUnresolved
stateDecision = intentMarkov60
```

Se congelan Agent50/100/150/200 de `control60`, con los mismos SHA-256
registrados en 7Q. Agent200 es primario; los demás checkpoints solo prueban
estabilidad. No se carga el estado 62 ni Agent7250.

El corpus compartido contiene 3 410 estados reales Agent200. La cohorte primaria
mantiene los 2 064 componentes motor-paso de 7Q:

```text
gateContext in {initialRest, declaredRest}
abs(v_ref,m) < 0.005
abs(q_ref,m-q_m) <= 1e-4
```

La ejecución debe cerrarse si cambian manifiestos, checkpoints, estados,
acciones o conteos.

## 2. Contrato WMoos de 40 features

`getWmoosFeatures` concatena cinco familias de ocho canales:

| Familia | Función publicada | Índices del estado |
|---|---|---|
| `standardDeviation` | `WMoos_F1` | 1:8 |
| `absoluteEnvelopeIntegral` | `WMoos_F2` | 9:16 |
| `meanAbsoluteValue` | `WMoos_F4` | 17:24 |
| `energy` | `WMoos_F5` | 25:32 |
| `rootMeanSquare` | `WMoos_F13` | 33:40 |

Para canal `c`, los índices son `c+[0,8,16,24,32]`. Se añadirá una prueba que
compare este mapa contra la salida directa de las cinco funciones sobre EMG
sintética determinista.

Las features en el estado ya están estandarizadas con `C/S` de la sesión
sintética. No se interpretarán como activación física, energía comparable entre
sesiones ni valores `[0,1]`.

## 3. Escalas y contexto de emparejamiento

Se fija:

```text
EMG     = s(1:40)
context = s(41:60) = [q, deltaQ, u_eff,t-1, q_ref, v_ref]
```

Por dimensión se calcula una desviación estándar usando las 3 410 ventanas del
corpus compartido. Se aplica piso `1e-6`. Las mismas escalas se usan para todos
los motores y checkpoints.

Entre query `i` y donor `j`:

```text
deltaContext = (context_i-context_j)./sigma_context
contextRms   = sqrt(mean(deltaContext.^2))
contextMax   = max(abs(deltaContext))

deltaEmg   = (EMG_i-EMG_j)./sigma_emg
emgRms     = sqrt(mean(deltaEmg.^2))
```

El par primario exige `contextMax<=0.25` y `emgRms>=0.50`. Entre candidatos
elegibles se escoge el menor `contextRms`; empates usan el menor índice de fila.

Se reportará aparte una cuadrícula de soporte, sin cambiar la decisión:

```text
contextMax in [0.15, 0.25, 0.50]
emgRms     in [0.25, 0.50, 0.75]
```

## 4. Pares reales y separación por episodios

El emparejamiento es dirigido: cada query puede seleccionar como máximo un
donor. Ambos estados son filas completas reales; el actor se evalúa solo en esas
filas. No se reemplazan features ni se construyen híbridos.

Se crean dos modos:

1. `withinEpisode`: mismo `source`, episodio y `gateContext`, distinto paso;
2. `crossEpisode`: mismo `source`, `gateContext` y fold, distinto episodio.

Los episodios se asignan a cinco folds, separadamente por source, ordenando su
identificador y aplicando `fold=1+mod(rank-1,5)`. En `crossEpisode` el donor debe
estar en el mismo fold que el query. Así ningún episodio aparece a la vez en
entrenamiento y prueba del modelo incremental.

Se guardan reutilización de donor, episodios únicos, fuente, contexto, distancias
y diferencias mecánicas/EMG. `crossEpisode` es la evidencia primaria;
`withinEpisode` es corroboración temporal.

## 5. Modelos incrementales

Para checkpoint `k`, motor `m` y par `(i,j)`:

```text
y = pi_k,m(s_i)-pi_k,m(s_j)
X_context = deltaContext
X_family  = deltaEmg(indices_family)
X_channel = deltaEmg(indices_channel)
```

Con ridge `lambda=1` y cinco folds por episodio se comparan:

```text
M0: y ~ X_context
M1: y ~ [X_context, X_family]
deltaR2 = R2(M1)-R2(M0)
```

Se reportan `R2` fuera de muestra, correlación, error absoluto, exactitud del
signo para `abs(y)>=1e-3` y ganancia de exactitud frente a `M0`. El modelo
`allEmg` usa las 40 features; familias y canales se reportan por separado para
no equiparar modelos con distinta semántica.

Control negativo: dentro de cada combinación source/motor/modo/fold, las filas
de `deltaEmg` se rotan una posición en orden de query. Se ajusta el mismo `M1` y
se calcula `deltaR2Permuted`. La evidencia EMG debe superar este control, no solo
obtener un `R2` positivo.

## 6. Soporte mínimo

Un modo/motor es soportado si tiene:

- al menos 100 pares;
- al menos 20 episodios query únicos;
- los cinco folds no vacíos;
- fracción máxima de reutilización de un único donor `<=0.10`.

El gate global de soporte exige estas condiciones en al menos tres motores tanto
para `crossEpisode` como para `withinEpisode`. Si falla, el resultado será
`insufficientMatchedSupport` y no se interpretarán los modelos.

## 7. Regla preinscrita de atribución

Una familia pasa para Agent200 si:

1. en `crossEpisode/ALL`, `deltaR2>=0.10` y ganancia de signo `>=0.05` en al
   menos tres motores;
2. repite esos límites en `withinEpisode/ALL` en al menos tres motores;
3. en `crossEpisode`, supera `deltaR2Permuted` por al menos 0.05 en tres motores;
4. mantiene `deltaR2>=0.05` en tres motores para al menos tres de los cuatro
   checkpoints, incluyendo Agent200;
5. conserva `deltaR2>0` por separado en `acceptance` y `steadyRest` en al menos
   tres motores.

Clasificación excluyente:

- una sola familia pasa: `singleFamilySupported:<family>`;
- dos o más familias pasan: `multiFamilyEmgAssociation`;
- ninguna familia pasa, pero `allEmg` satisface 1–4:
  `distributedEmgAssociation`;
- soporte suficiente sin lo anterior: `emgNotIdentifiedUnderMatching`;
- soporte insuficiente: `insufficientMatchedSupport`.

No se redondearán resultados para superar gates. Una asociación no demuestra
intención muscular física ni independencia de canales.

## 8. Interpretación permitida

- `singleFamilySupported` permite proponer en otra etapa una auditoría offline
  más fina de esa familia; no autoriza eliminar features ni entrenar.
- `multiFamilyEmgAssociation` o `distributedEmgAssociation` indican información
  EMG redundante/distribuida, no una familia causal única.
- `emgNotIdentifiedUnderMatching` indica que 7Q no puede atribuirse a EMG bajo
  soporte mecánico comparable.
- `insufficientMatchedSupport` obliga a recolectar mejor evidencia simulada o
  diseñar otra auditoría; no permite relajar el matching retrospectivamente.

## 9. Validación y entregables

- pruebas deterministas del orden WMoos, folds, matching, ausencia de híbridos,
  modelos, control permutado y cinco clasificaciones;
- `checkcode` sin diagnósticos;
- regresión no-glove completa;
- CSV de pares, soporte, cuadrícula, modelos por familia/canal/checkpoint y
  decisión;
- MAT, JSON, manifiesto, hashes y comando reproducible;
- informe `07r_real_state_emg_attribution.md`.

ETAPA 7R se detiene tras documentar y crear commits. No autoriza entrenamiento,
smoke de 200, piloto de 2 000 ni campaña. No se hará push salvo orden explícita.
