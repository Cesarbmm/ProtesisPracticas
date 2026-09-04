# ETAPA E0 — Resultados

**Ejecutado:** 2026-09-04 en `experiment/no-glove-paired-reference-td3`
**Salida:** `Agentes/paired_reference/stage0/stage0_audit_results.mat`
**Veredicto:** **PARA Y CORRIGE.** Gate E0.1 fallido, fix mínimo aplicado, pendiente de re-ejecución.

---

## 1. Resumen en cinco líneas

1. El gate falla: `gatePassed = 0`, con **174 fallos de monotonicidad** de 2352 casos.
2. La causa está identificada con **correlación 1:1**: cuando la posición del motor queda fuera del
   recorrido de la curva, la búsqueda de `x_0` no encuentra punto y el motor **salta al final de la
   curva, en dirección contraria al comando**. 73 de 1176 casos del paso operativo (6.2 %).
3. La hipótesis del objeto `cfit` que abrió esta etapa queda **refutada en su forma**, pero destapó
   algo peor: **la física de la planta depende de qué toolboxes tenga instalada la máquina**.
4. La planta tiene **poca resolución por paso**: un paso de control cubre entre el 12.7 % y el
   47.2 % del recorrido completo. A PWM ≥ 128 casi no hay control proporcional.
5. El dataset confirma lo esperado: 7420 pares, 12 sujetos, **sin reposo etiquetado**.

---

## 2. Predicción registrada contra resultado

El preregistro (Enmienda 1) fijó cuatro predicciones antes de ejecutar. Así quedaron:

| Predicción registrada | Resultado | |
|---|---|---|
| `nIdxCollapsed == 56` | 56 | acertada, **pero por el motivo equivocado** |
| `nCurveFallback == 0` | **56** | **fallida** |
| `nInvariantFinalPosition == nº de grupos (112)` | 76 de 112 | fallida |
| `nMonotonicityFailures > 0` | 174 | acertada |

Dos de cuatro. Según la regla que el propio preregistro fijó, **el hallazgo del `cfit` se retira**.
`02_HALLAZGO_PLANTA.md` queda marcado como refutado. Lo que sigue es lo que los datos sí dicen.

---

## 3. Por qué la hipótesis del `cfit` falló, y qué apareció en su lugar

Los hechos, que no cambian:

- `fit_C2.mat` almacena `params.(sp).(dir).(m).ws` como un objeto **MCOS de clase `cfit`**
  (verificado leyendo el archivo binario, md5 `067db7fe...`, idéntico en las tres copias del repo).

Lo que MATLAB reportó al ejecutarse:

- `nNumericWs = 56` — las 56 entradas se leyeron como **numéricas**
- `nCurveFallback = 56` — y con `numel(ws) == 0`, es decir **vacías**

Un objeto `cfit` no es numérico y su `numel` vale 1. La única explicación consistente es que
**esta instalación de MATLAB no puede instanciar la clase `cfit`**: sin Curve Fitting Toolbox,
MATLAB carga el objeto como `[]`. Por eso el respaldo a `pattern_curve` que introdujo ETAPA 8 sí se
activa, y la planta funciona con la curva media en vez de con el ajuste.

**Esto es peor que el hallazgo original, no mejor:**

> El mismo código, con los mismos datos, produce **dos físicas distintas** según las toolboxes
> instaladas. Con Curve Fitting Toolbox, `numel(ws) = 1` y la trayectoria colapsa a una constante.
> Sin ella, `ws = []`, se usa `pattern_curve` y hay movimiento real.

`Agent7250` y todas las campañas se entrenaron en **una** de las dos ramas de ese condicional, y no
está registrado en ningún sitio cuál. Reproducir cualquier resultado del proyecto exige registrar la
configuración de toolboxes junto al resultado. El bloque E0.0 ahora lo comprueba y lo avisa.

**Acción abierta:** confirmar con `ver` en MATLAB si Curve Fitting Toolbox está instalada, y anotarlo
en `DECISIONES.md`. Es una línea y cierra la ambigüedad.

---

## 4. El defecto real: arranque al final de la curva

Mecanismo, en `prosthesis_simulator.m` (main, líneas 114-128):

```matlab
t = numel(curve);                 % <- valor por defecto: el FINAL de la curva
for t_search = 1:numel(curve)
    if dir == "closing"
        if curve(t_search) >= y_sat, t = t_search; break; end
    else
        if y_sat >= curve(t_search), t = t_search; break; end
    end
end
```

Si la posición actual queda más allá del extremo lejano de la curva en la dirección pedida, la
búsqueda no encuentra punto, `t` conserva `numel(curve)` y el motor arranca **al final del
recorrido**, saltando hacia atrás.

**Correlación 1:1 verificada.** Búsquedas sin punto encontrado en el paso operativo: 73 de 1176.
Fallos de monotonicidad en el paso operativo: 73 de 1176. Misma distribución exacta:

| motor | opening | closing |
|---|---|---|
| 1 | 7 | 10 |
| 2 | 7 | **17** |
| 3 | 7 | 11 |
| 4 | 7 | 7 |

Motor 2 es el peor en cierre — consistente con los flags históricos `motor2_flat_response` y
`motor2_action_no_motion`, que hasta ahora se atribuían al agente.

---

## 5. Resolución de control: la planta gradúa poco

`pattern_curve` está muestreada a 1 ms. Un paso de control avanza `delta_ms = 200` índices.
Con curvas de 424 a 1576 ms, un solo paso cubre:

| PWM | closing | opening |
|---|---|---|
| 64 | 12.7 % | 24.8 % |
| 96 | 19.1 % | 31.1 % |
| 128 | 33.6 % | 38.2 % |
| 160 | 35.1 % | 44.3 % |
| 192 | 32.3 % | 42.7 % |
| 224 | 43.6 % | 43.9 % |
| 255 | **44.0 %** | **47.2 %** |

A PWM 255 **dos pasos de control recorren la mano entera**. Los episodios duran ~16 pasos.

Consecuencia medida: destinos distintos alcanzables desde 21 posiciones iniciales, en un paso.

| motor | mín | mediana | máx |
|---|---|---|---|
| 1 | 9 | 12.5 | 21 |
| 2 | 1 | **2** | 20 |
| 3 | 1 | 6 | 20 |
| 4 | 1 | **1** | 19 |

En la mitad de las combinaciones de los motores 2 y 4, **todas** las posiciones iniciales terminan
en el mismo sitio. Y las 20 combinaciones invariantes del paso operativo son todas de PWM ≥ 128.

**Lectura:** el control proporcional sólo existe a PWM 64 y 96. Y los agentes históricos aprendieron
políticas con `saturationFraction` entre 0.39 y 0.61, es decir, **operaban predominantemente en el
régimen donde la planta no gradúa**. La meseta a partir de 8000 episodios no era falta de
presupuesto: en ese régimen no queda nada que graduar.

Esto no es un bug del simulador. Con un periodo de control de 0.2 s y carreras de 0.42–1.58 s, es
la física de estos motores. Se corrige bajando el periodo de control o restringiendo los niveles
—decisiones de diseño del experimento— no parcheando el simulador.

---

## 6. Fix aplicado

En `prosthesis_simulator.m`, cambio mínimo: si la búsqueda no encuentra punto, **mantener posición**.

```matlab
if ~foundStart
    t_i = repmat(pos, n_points, 1);
    return
end
```

Es la respuesta física: el motor está más allá del recorrido, no puede avanzar más en esa dirección.
Se verificó que el fallo siempre ocurre en el extremo lejano, nunca en el cercano, así que "mantener"
es correcto en los dos sentidos.

**Efecto medido** (replicando el simulador con los datos reales, réplica validada porque reproduce
exactamente 2352 / 174 / 6 / 1757 / 76 del resultado de MATLAB):

| | antes | después |
|---|---|---|
| fallos de monotonicidad, paso operativo | **73** | **0** |
| fallos de monotonicidad, total del barrido | 174 | 28 |
| saltos, paso operativo | 4 | 2 |
| grupos con posición final invariante | 76 | 0 |
| casos cuyo resultado cambia | — | 146 de 2352 (6.2 %) |

Test de regresión añadido: `tests/paired_reference/testPairedReferencePlantHoldOutsideCurve.m`.
Localiza por sí mismo los casos fuera del dominio, así que sigue siendo válido si cambian las curvas.

---

## 7. Lo que el fix no arregla

**28 fallos de monotonicidad restantes**, todos en motor 3, cierre, sólo en el caso de estrés de
3.0 s. El desplazamiento neto es correcto (+4086), pero hay un tramo no monótono dentro de la
trayectoria. La causa es que **la propia curva de referencia de motor 3 no es monótona** — es un
defecto del dato de caracterización, no del código, y no aparece nunca en el paso operativo (donde
`n_points = 1`). A `BACKLOG.md`.

**2 saltos residuales**, motor 2, apertura, PWM 64, desde posiciones por encima del dominio de esa
curva. El movimiento va en la dirección correcta; el salto es la proyección de la posición sobre el
inicio de la curva. Limitación de cobertura de `pattern_curve`. 0.17 % de los casos operativos.

---

## 8. Decisión pendiente: alcance del gate

El gate preregistrado evalúa **todo** el barrido, incluidas las duraciones de 3.0 s. Pero el entorno
sólo produce pasos de `params.period = 0.2 s`: la duración de 3.0 s es un caso de estrés que añadí
yo al diseñar el barrido, no un régimen real.

Con el fix, el paso operativo queda limpio (0 fallos) y el gate global sigue fallando por los 28
casos de motor 3 a 3.0 s.

Hay dos salidas honestas, y la elección es tuya porque toca el registro científico:

- **A — Enmienda 2, gate restringido al régimen operativo.** Se justifica: es el único que el entorno
  produce. Los casos de 3.0 s pasan a diagnóstico. Queda documentado como enmienda posterior a ver
  los datos, que es exactamente lo que el preregistro existe para hacer visible.
- **B — Gate global intacto.** Entonces E0 no se cierra hasta arreglar la curva no monótona de motor
  3, que es un problema de datos de caracterización y puede llevar tiempo.

Mi recomendación es **A**, con la enmienda escrita y fechada. Pero no la aplico sin tu palabra.

---

## 9. Dataset (E0.2) y lag (E0.3)

| | |
|---|---|
| Sujetos | 12 |
| Estructura | `emg` y `glove`, ambas 3710 × 2 cell |
| Pares gesto/lado | **7420** |
| Reposo etiquetado / MVC / calibración | **no existe** (`hasLabelledRest = 0`) |

Confirma lo que la rama anterior tuvo que suplir con un fixture sintético. El alcance
OPENING/CLOSING de esta línea se sostiene sobre este dato.

**Lag EMG → movimiento**, 400 de 400 registros usables, en pasos de control de 0.2 s:

| p10 | p25 | p50 | p75 | p90 |
|---|---|---|---|---|
| −1.5 | −0.5 | **0.0** | +1.0 | +2.0 |

Mediana exactamente 0, con dispersión simétrica de ±2 pasos y valores negativos (el guante
"adelantándose" al EMG) que son no físicos. Lectura honesta: **no hay evidencia de un retardo
estable** a esta resolución. Los registros duran ~2 s y el guante va a 10 Hz; la resolución es de
medio paso de control.

**Consecuencia para E1:** barrer `k ∈ [-2, 2]` con `k = 0` como valor por defecto, y **no construir
nada sobre el lag**. Si el barrido de E1 muestra un óptimo claro, será evidencia mejor que ésta.

---

## 10. Siguiente

1. Confirmar con `ver` si Curve Fitting Toolbox está instalada → una línea en `DECISIONES.md`.
2. Decidir A o B sobre el alcance del gate.
3. Re-ejecutar E0 con el fix:
   ```matlab
   runtests("tests/paired_reference/testPairedReferencePlantHoldOutsideCurve")
   results = run_paired_reference_stage0_audit(part="plant");
   ```
   Esperado: `nMonotonicityFailures` en el paso operativo = 0.
4. Con eso, E0 cierra y E1 puede abrir.
