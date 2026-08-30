# ETAPA 7Q — preinscripción de atribución offline de comandos

Fecha: 2026-08-30.

ETAPA 7Q es estrictamente offline. No entrena, no crea `Env`, no ejecuta la
planta, no calcula DTW y no modifica estado, reward, referencia, cuantización,
TD3, simulador, gate ni seguridad. Su objetivo es atribuir, sin contrafactuales
de estado no causales, los comandos no nulos con demanda de control cero y los
comandos dirigidos hacia fuera de los límites que ETAPA 7P dejó sin explicar.

## 1. Evidencia congelada

Padre canónico:

```text
ETAPA 7P = C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7p_artifacts\stage7p_final\2026-08-29_23-15-59-803
SHA256(manifest.json) = 9B6BC4198AE8B36C4BE062E51D82BE7709870D2DBD3C74A5F7FE68AB015034D9
scientificResult = noAblationSupported
stateDecision = intentMarkov60
```

Se congelan los checkpoints `control60` de ETAPA 7N:

| Episodio | SHA-256 |
|---:|---|
| 50 | `D697DA3BB6CE9672330A359DDE3DD43ACEECCB5E2F151EF6E13D3C8C2EC2D013` |
| 100 | `3B54D4C5122D7133E9472EE8ED641418A79E0FA7E57A6501AC1C5E611357AB3F` |
| 150 | `B760B7EE45F62D6B2E12C1B0A3281E119182CAF96653A293E07E9EFE567A7A66` |
| 200 | `440F003450A368A13A0E5DACB04FD7755BB929033EB879B217E47F32B5AA185E` |

Agent200 es primario. Agent50/100/150 son análisis secundarios de evolución; no
se seleccionará retrospectivamente el checkpoint con mejores métricas. No se
cargan el estado 62 ni Agent7250.

## 2. Cohortes

La cohorte primaria está formada por componentes motor-paso de Agent200 que
cumplen simultáneamente:

```text
gateContext in {initialRest, declaredRest}
abs(v_ref,m) < 0.005
abs(q_ref,m - q_m) <= 1e-4
```

ETAPA 7P registró 2 064 componentes y PWM no cero en todos ellos. 7Q debe
rechazar la ejecución si el conteo cambia.

La cohorte `outwardBoundary` primaria conserva la definición de 7P:

```text
q_m <= 1e-9     y PWM_m < 0
q_m >= 1-1e-9   y PWM_m > 0
```

Se analizarán dos comparaciones separadas:

1. `sharedAgent200States`: los cuatro actores reciben exactamente los mismos
   estados reales registrados por Agent200. Esto aísla evolución de política,
   pero se etiquetará como replay offline y no como trayectoria ejecutada.
2. `ownCheckpointCorpus`: cada actor se evalúa sobre sus estados reales de
   aceptación y reposo. Esto conserva validez ecológica, pero mezcla política y
   distribución de estados.

No se construyen estados híbridos, no se reemplazan bloques y no se perturba una
entrada individual para inferir causalidad.

## 3. Bloques observables

Para `intentMarkov60` se fija el mapa:

```text
EMG features          =  1:40
q                     = 41:44
deltaQ                = 45:48
previousEffectiveAction = 49:52
qRef                  = 53:56
vRef                  = 57:60
```

Las 40 features WMoos permanecen estandarizadas; no se interpretan como
amplitudes físicas `[0,1]`.

## 4. Sensibilidad local de la red

Para actor `pi`, motor `m`, estado real `s_t` e índice `j`:

```text
g_t,m,j = d pi_m(s_t) / d s_t,j
```

Por bloque `b` se reportan dos magnitudes:

```text
S_raw(t,m,b) = sqrt(mean_j_in_b(g_t,m,j^2))
S_scaled(t,m,b) = sqrt(mean_j_in_b((g_t,m,j * sigma_j)^2))
```

`sigma_j` es la desviación estándar de la dimensión `j` en las 3 410 ventanas
reales del corpus Agent200 completo, con piso `1e-6`. La fracción de sensibilidad
es `S_scaled/sum_b(S_scaled)`. La escala se congela para comparar checkpoints.

El gradiente mide sensibilidad diferencial de la red. No demuestra que el bloque
cause por sí solo el PWM observado ni autoriza alterar sensores o seguridad.
Ocho estados deterministas comprobarán el gradiente analítico contra diferencia
finita central con paso `1e-3`, tolerancia absoluta `2e-4` o relativa 5%.

## 5. Evidencia empírica usando solo estados reales

### 5.1 Asociación por bloque

En la cohorte primaria se ajustará, por motor y bloque, una regresión ridge
determinista con `lambda=1`. La validación usa cinco folds agrupados por
`source+episode`; ninguna ventana del mismo episodio aparece simultáneamente en
entrenamiento y prueba. Se reportará `R2` fuera de muestra y correlación de
Pearson entre predicción y acción. Es asociación predictiva, no intervención.

### 5.2 Transiciones observadas

Solo para pares consecutivos del mismo episodio se calculará:

```text
C_t,m,b = sum_j_in_b(g_t-1,m,j * (s_t,j - s_t-1,j))
deltaU_t,m = pi_m(s_t) - pi_m(s_t-1)
```

Se reportará la contribución absoluta por bloque y el error de la aproximación
lineal `abs(deltaU-sum_b(C))`. No se evaluará el actor sobre un estado sintético.

### 5.3 Acción efectiva previa

Por motor y checkpoint se medirán por separado:

- `d u_m / d u_eff_prev,m` y sensibilidad cruzada a los otros motores;
- correlación `u_m` frente a `u_eff_prev,m`;
- coincidencia de signo;
- diferencia `u_m-u_eff_prev,m`;
- PWM no cero, saturación y comando hacia fuera del límite.

## 6. Regla preinscrita de atribución

Un único bloque `b` se clasificará como `uniqueUpstreamBlock:b` únicamente si,
en Agent200 y la cohorte primaria:

1. es el bloque con mayor mediana de fracción `S_scaled` en al menos tres de los
   cuatro motores;
2. en esos motores la mediana es al menos 0.50 y al menos dos veces el segundo
   bloque;
3. también obtiene el mayor `R2` agrupado en al menos tres motores, con
   `R2>=0.25` y margen mínimo 0.10 sobre el segundo bloque;
4. el mismo bloque lidera la contribución temporal absoluta en al menos tres
   motores con fracción mínima 0.50.

Si no existe bloque único, se clasificará:

- `lateTrainingEmergence` si, sobre los mismos estados Agent200, Agent200 aumenta
  al menos 25% el PWM absoluto medio frente al máximo de Agent50/100/150 y
  aumenta al menos 10 puntos porcentuales el PWM no cero o los comandos hacia
  fuera;
- `distributedOrUnresolved` en cualquier otro caso.

Los umbrales son gates experimentales, no límites clínicos. No se redondearán
resultados para hacerlos pasar.

## 7. Interpretación y siguiente decisión

- `uniqueUpstreamBlock` permite proponer, en otra etapa, una única ablación
  offline sobre ese bloque; no autoriza implementarla en 7Q.
- `lateTrainingEmergence` permite proponer una auditoría del objetivo/replay de
  entrenamiento, sin entrenar aún.
- `distributedOrUnresolved` obliga a mantener `intentMarkov60`, conservar la
  seguridad y no escoger una intervención conductual sin nueva evidencia.

La elevada cantidad de intervenciones se interpreta como acción protectora de
la capa de seguridad, no como autorización para reducirla.

## 8. Validación y entregables

- pruebas deterministas de mapa de índices, gradientes, folds, cohortes,
  atribución y regla de decisión;
- `checkcode` sin diagnósticos;
- regresión no-glove completa;
- CSV de componentes primarios, sensibilidad, asociaciones, transiciones,
  evolución de checkpoints y decisión;
- MAT, JSON, manifiesto, hashes y comando reproducible;
- informe `07q_command_attribution.md`.

ETAPA 7Q se detendrá tras documentar y crear commits. No autoriza smoke de 200,
piloto de 2 000 ni campaña. No se hará push salvo orden explícita.
