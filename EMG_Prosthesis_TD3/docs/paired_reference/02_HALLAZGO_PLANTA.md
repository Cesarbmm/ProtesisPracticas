# Hallazgo de planta — `ws` es un objeto `cfit`, no un vector

**Estado:** hipótesis con evidencia estructural directa. **Pendiente de confirmación empírica**
en MATLAB, que es exactamente lo que ejecuta E0.
**Fecha:** 2026-09-04. **Rama afectada:** `main` (`6b213ba5`) y, por herencia, todas las demás.

---

## 1. Qué se verificó

Se cargó `matlab_code/src/@SimController/fit_C2.mat` y se inspeccionó su contenido real:

```
keys           : params, tail_length
tail_length    : 150
params fields  : sp_3F sp_5F sp_7F sp_9F sp_BF sp_DF sp_FF     (7, NO existe sp_zeroF)
estructura     : params.(sp).(dir).(m_i).{ws, min_lim, max_lim}   -> 7 x 2 x 4 = 56 entradas
m_1 / sp_3F / closing : min_lim = 0, max_lim = 17016
ws             : objeto MCOS opaco de clase  cfit   (Curve Fitting Toolbox)
```

`ws` **no es un vector muestreado**. Es un objeto de ajuste de curva. En MATLAB,
`numel(objeto escalar) == 1`.

`pattern_curve.mat` sí contiene vectores: `avgs.(sp).(dir).(m_i).avg`, de 424 a 1576 muestras,
con `sampling_period_ms = 1`.

## 2. Qué implica en `prosthesis_simulator.m` (main)

```matlab
ws     = sim_params.(sp_txt).(dir).(m_txt).ws;   % cfit
ws_len = numel(ws);                              % L97   -> 1

useCurveFallback = ws_len == 0;                  % L106  -> FALSE
                                                 %          el respaldo NUNCA se activa

x_0 = t;                                         % L130
if ~useCurveFallback
    x_0 = tail_length + t;                       % L132  -> 150 + t
end
x_0 = max(1, min(x_0, ws_len));                  % L133  -> max(1, min(150+t, 1)) = 1

for t = 1:n_points
    idx = round(x_0 + delta_ms * t);
    idx = max(1, min(idx, ws_len));              % L139  -> 1  SIEMPRE
    t_i(t) = ws(idx);                            % L140  -> feval(ws, 1)  CONSTANTE
end
```

**Conclusión:** para cualquier comando no nulo, el motor se teletransporta a `feval(ws, 1)`, un
valor fijo que depende sólo de `(motor, dirección, velocidad cuantizada)` y **no** de la posición
inicial ni del tiempo transcurrido. La prótesis simulada no integra: es una tabla de consulta con
4 motores × 2 direcciones × 7 velocidades = **56 posiciones alcanzables**, más "mantener" con PWM 0.

El fallback a `pattern_curve` que introdujo ETAPA 8 (líneas 106-112) es **código muerto**: se
escribió asumiendo `ws` vacío, y `ws` nunca está vacío — está lleno con un objeto cuyo `numel` es 1.

## 3. Qué explica

Si se confirma, esto reinterpreta buena parte de la historia del proyecto:

| Observación histórica | Lectura bajo este hallazgo |
|---|---|
| Políticas bang-bang, `saturationFraction` ~0.4–0.7 | La única forma de alcanzar una posición es elegir la velocidad cuya constante esté más cerca. El agente no gradúa: selecciona de un catálogo de 14 destinos por motor. |
| `motor2_flat_response`, `action_no_motion` | Las constantes de M2 caen en un rango estrecho. No es un defecto del agente. |
| Meseta a partir de 8000 episodios; 12000, 20k y 50k sin mejora | No hay nada más que aprender: la política óptima es una tabla. |
| Ninguna seed superó `Agent7250` | Consistente con haber llegado ya al óptimo de una planta degenerada. |
| El control P con Kp=0.50 resultaba competitivo | Contra una planta de teletransporte, un P también acierta el destino. |
| ETAPA 12: dispersión Q espuria dentro de bins | Compatible, pero la causa es más profunda que `actionCommandScale`. |

**Lo que NO invalida:** el pipeline, la reward, el logging, las métricas, las compuertas
`ConditionA`/`ConditionB` ni la metodología de auditoría. Todo eso sigue siendo correcto. Lo que
queda en entredicho es **la física contra la que el agente aprendía**.

**Lo que sí obliga:** `Agent7250` no puede seguir presentándose como "benchmark de control
continuo" sin esta nota al pie. Es el mejor agente sobre una planta que hay que corregir.

## 4. Arreglo mínimo candidato — no aplicar todavía

La semántica que el código pretendía es evidente: `ws` es una curva ajustada que se evalúa en un
índice temporal, y `tail_length = 150` es un desplazamiento de arranque. El error es acotar ese
índice contra `numel(ws)`, que para un objeto vale 1.

```matlab
if isnumeric(ws)
    ws_len = numel(ws);        % camino historico, intacto
else
    ws_len = curve_len;        % dominio de la curva de referencia
end
```

Esto deja el camino numérico byte-idéntico y da sentido al camino `cfit`. **Pero no se aplica sin
evidencia:** E0.0 evalúa `ws` sobre `1:numel(curve)` y comprueba dos cosas antes de autorizarlo:

1. que el recorrido resultante sea monótono en la dirección correcta;
2. que cubra más de la mitad de `[min_lim, max_lim]`.

Si ambas se cumplen, el arreglo es defendible. Si no, el problema está en el propio ajuste y hay que
volver a los datos de caracterización de la prótesis.

## 5. Consecuencia para el plan

E0 deja de ser un trámite y pasa a ser la etapa más importante de la línea. El orden no cambia
—sigue siendo lo primero— pero el resultado esperado sí: **se espera que el gate E0.1 falle**.

Los tests de `testPairedReferenceStage0PlantSanity.m` están escritos para fallar en ese caso. Un
fallo ahí no es un test mal escrito: es el gate funcionando. En particular
`testTrajectoryDependsOnInitialPosition` es la prueba directa de que la planta no integra.

## 6. Qué falta para cerrarlo

Ejecutar en MATLAB:

```matlab
results = run_paired_reference_stage0_audit(part="plant");
```

y leer tres números:

- `results.dynamics.nIdxCollapsed` — debería ser 56 de 56
- `results.plant.nInvariantFinalPosition` — debería igualar el número de grupos
- `results.dynamics.nEvalMonotone` — decide si el arreglo mínimo es viable

Con eso el hallazgo pasa de hipótesis a hecho, o se cae.
