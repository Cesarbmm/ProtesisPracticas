# PREREGISTRO — ETAPA E1 (guante virtual offline)

**Rama:** `experiment/no-glove-paired-reference-td3`
**Fecha de registro:** 2026-09-04 — **antes de ajustar ningún modelo**
**Estado:** registrado; export del dataset pendiente de ejecución en MATLAB

> Escrito antes de ver un solo número de regresión. Los umbrales de la sección 8 no se modifican
> después; si hay que cambiarlos, se añade una enmienda fechada, como en E0.

---

## 1. Pregunta

¿Aportan las señales EMG información suficiente para estimar la trayectoria continua del guante en
**sujetos no vistos**?

## 2. Hipótesis

- **H1** — Un ridge lineal `40 → 4` sobre las features WMoos históricas predice `flexConverted`
  mejor que los baselines diagnósticos, en sujetos que no ha visto, y esa ventaja se degrada al
  romper la asociación EMG–target.
- **H0** — La ventaja del ridge, si existe, es atribuible a la estructura temporal del gesto y no a
  la EMG; al barajar la EMG dentro de la misma fase, el desempeño no se degrada.

## 3. Split congelado (Enmienda 3 de E0)

```
TRAIN      : BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE
VALIDATION : JONATHAN, KHAROL
TEST       : MATEO, SANDRA
```

Disjuntos **por sujeto**. Nada de ventanas aleatorias. `k`, `lambda` y la selección de modelo se
resuelven **sólo** con train + validation. El test se ejecuta **una vez**, al final.

## 4. Construcción del dataset

- **Target:** `flexConverted ∈ R⁴`, exactamente las coordenadas que usa la reward hoy
  (`flexJoined_scale(reduceFlexDimension(gloveWindow))`, última fila de la ventana).
- **Features:** las 40 WMoos que usa `Env`, vía `configs.fGetFeatures` con los `C`/`S` históricos.
  **No se crea otra definición de features.**
- **Timing:** reproducido con los componentes reales, no por emparejamiento de índices.
  `RecordedMyo.readEmg(0.2)` → 40 muestras a 200 Hz. `RecordedGlove.read(0.2)` → 2 muestras a 10 Hz.
  El episodio termina cuando cualquiera de los dos se agota.
- **Pares:** `phi_t → y_{t+k}` con `k ∈ {-2,-1,0,+1,+2}`, aplicado dentro de cada episodio; los
  pasos sin contraparte se descartan.
- **Ejecutor:** `workflows/published/run_paired_reference_stage1_export_dataset.m`.

`PLANT_SOURCE` no interviene: E1 no usa la planta.

## 5. Baselines obligatorios, con su etiqueta

- **BASELINE A — hold causal.** Predecir `y_{t-1}` (última observación de guante disponible).
  Requiere guante en tiempo de ejecución, que es justo lo que la línea quiere eliminar.
  → **`DIAGNOSTIC_ONLY`**, no desplegable.
- **BASELINE B — trayectoria media por gesto y fase.** Media de `y` sobre train, condicionada a
  (`closing`/`opening`, índice de paso normalizado). Necesita conocer de antemano el gesto y la fase
  temporal del episodio. → **`DIAGNOSTIC_ORACLE`**, no desplegable.

Su función no es competir por el despliegue. Es responder: **¿se puede obtener buen MSE sin mirar la
EMG?** Si B iguala al ridge, el ridge no está leyendo EMG.

## 6. Modelo

- **Primario:** ridge `40 → 4`, con intercepto, ajustado en TRAIN.
- Barrido de `k ∈ [-2, +2]` y de `lambda` en malla logarítmica; selección **sólo por VALIDATION**.
- **Contexto temporal** (`ridge 120 → 4` con `[φ_t, φ_{t-1}, φ_{t-2}]`) sólo si se cumple la
  condición registrada aquí: que ridge40 **ya muestre** información EMG real (ablaciones positivas) y
  quede error temporal material. **No se usa para rescatar un ridge40 fallido.**
- **MLP fuera de E1**, salvo autorización explícita posterior.

## 7. Métricas

MSE · MAE · Pearson y Spearman · sign accuracy de `Δy` · desglose por motor · desglose
`closing`/`opening` · DTW **sólo** como métrica secundaria offline.

DTW no entra en la loss, no entra en ninguna reward y no altera la causalidad.

## 8. Ablaciones (controles de permutación)

- **ABLACIÓN 1 — global.** Barajar las ventanas EMG entre episodios manteniendo los targets.
- **ABLACIÓN 2 — condicionada.** Barajar EMG **sólo entre muestras del mismo gesto y de fase
  temporal comparable** (mismo bin de paso normalizado).

La segunda es la decisiva: responde si, conocida la fase de `closing`/`opening`, la EMG sigue
aportando información continua.

## 9. Gate de E1 — fijado ANTES de correr

E1 pasa **sólo** si se cumplen las siete condiciones:

1. ridge40 supera a los baselines diagnósticos relevantes en sujetos no vistos, o aporta una mejora
   material claramente atribuible a EMG;
2. mejora MSE;
3. mejora sign accuracy;
4. la ablación global degrada el resultado;
5. la ablación condicionada **también** muestra pérdida de información;
6. el comportamiento es consistente por motor y no lo genera un único motor fácil;
7. no depende del test para seleccionar `k` ni `lambda`.

**Umbrales concretos**, para que el juicio no sea narrativo:

| condición | umbral |
|---|---|
| 2 — MSE | ridge40 < BASELINE_B en validation **y** en test |
| 3 — sign accuracy | ridge40 > 0.55 y > BASELINE_B |
| 4 — ablación global | MSE sube ≥ 20 % respecto a ridge40 |
| 5 — ablación condicionada | MSE sube ≥ 10 % respecto a ridge40 |
| 6 — consistencia | al menos 3 de 4 motores baten a BASELINE_B en MSE |

### Clasificación final

```
E1_GENERALIZATION_PASS
E1_SUBJECT_SPECIFIC_ONLY
E1_NO_EMG_INFORMATION
E1_INCONCLUSIVE_PREPROCESSING_LEAKAGE
```

**Si falla la generalización: PARA.** No se escala a MLP, no se toca TD3, no se toca la reward, no
se intenta reposo. Un resultado negativo se acepta como resultado científico.

## 10. Modelo final

Sólo si E1 pasa: reentrenar el ridge elegido con train + validation, con el `k` y `lambda` ya
fijados, sin tocar el test. **Un único** pase de test.

Congelar: pesos, bias, `lambda`, `k`, definición exacta de features, `C`/`S` usados, split, hashes
de los datasets y checksum del decoder, en un manifiesto reproducible.

## 11. Reserva declarada

`PREPROCESSING_LEAKAGE_STATUS = POSSIBLE_LEAKAGE` (ver `05_AUDITORIA_NORMALIZACION.md`). Las
conclusiones de generalización quedan limitadas por esa reserva mientras no se cierre la
comprobación registrada allí.

## 12. Fuera de alcance

E2 · RL · TD3 · controlador P · hardware · Myo real · reposo · oposición · `intentMarkov60` ·
`motionPermission` · `actionCommandScale` · `actionCommandLevels` · DTW como reward · MLP para
rescatar un resultado negativo · `git push`.

## 13. Resultado

Ejecutado 2026-09-04. Detalle completo en `06_RESULTADOS_E1.md`.

```
BEST_K                          = +1
LAMBDA                          = 3.162e5   (en el extremo del rango: el ridge casi colapsa a la media)
RIDGE40_VALIDATION_MSE          = 0.052142
MEDIA_DE_TRAIN_MSE              = 0.055592   -> el ridge solo mejora 6.2%
BASELINE_A_MSE (k=+1)           = 0.016095   DIAGNOSTIC_ONLY
BASELINE_B_MSE (k=+1)           = 0.027180   DIAGNOSTIC_ORACLE
RIDGE40_SIGN_ACCURACY           = 0.557      (baseline B: 0.560)
SHUFFLE_GLOBAL_DEGRADATION      = +6.3%      entre sujetos  /  +80.9% dentro de sujeto
SHUFFLE_CONDITIONED_DEGRADATION = -2.7%      entre sujetos  /  +6.4%  dentro de sujeto
MOTORES_A_FAVOR_DEL_RIDGE       = 0 de 4
```

Gate: falla 6 de las 7 condiciones. Solo se cumple la 7 (ni `k` ni `lambda` se eligieron con test).

## 14. Veredicto

**`E1_SUBJECT_SPECIFIC_ONLY`. El gate NO pasa. PARA.**

Dentro de un sujeto la asociacion EMG-guante es fuerte (+80.9% de degradacion al barajar) y
sobrevive al control condicionado (+6.4%, positiva en los 8 sujetos). Entre sujetos no transfiere:
barajar la EMG dentro del mismo gesto y fase **mejora** el resultado un 2.7%.

Conforme a la seccion 9: no se escala a MLP, no se abre el ridge de contexto (su condicion de
apertura no se cumple), no se toca TD3 ni la reward.

**El test final NO se ejecuto.** La seccion 10 lo condiciona a que E1 pase. MATEO y SANDRA quedan
intactos y disponibles para una linea corregida.

El confound de escala derivado del desajuste de C/S se controlo explicitamente (estandarizacion con
estadisticos solo de train): 0.052580 frente a 0.052142. No explica el fracaso.
