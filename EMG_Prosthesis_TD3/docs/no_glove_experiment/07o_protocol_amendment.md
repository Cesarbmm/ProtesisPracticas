# ETAPA 7O — enmienda de validación numérica del gradiente

Fecha: 2026-08-29. Esta enmienda se registró después del primer intento técnico
de ejecución y antes de observar o clasificar los efectos contrafactuales de los
bits 61/62. No cambia el corpus, los contrastes, las métricas, los umbrales de
clasificación ni la recomendación preinscrita.

## Motivo

La preinscripción fijó una diferencia central con `h=1e-4` y tolerancia
`max(1e-5,1e-3*abs(gradiente))`. Los actores congelados se evalúan en precisión
simple. El primer launcher se detuvo por su gate de gradiente antes de ejecutar
la clasificación:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7o_artifacts\stage7o_final\2026-08-29_22-10-43-085
```

El intento no entrenó, no instanció `Env`, no simuló y no usó hardware. El
launcher no escribió ni mostró las tablas de efectos antes del error, por lo que
la clasificación científica aún no había sido observada.

Se hizo un diagnóstico determinista sobre las mismas ocho filas por checkpoint,
comparando exclusivamente `dlgradient` con diferencias centrales. El error
máximo absoluto fue:

| checkpoint | `h=1e-4` | `h=1e-2` |
|---:|---:|---:|
| 50  | 0.00606919080 | 0.00005091727 |
| 100 | 0.00517956167 | 0.00008302927 |
| 150 | 0.00658342242 | 0.00033264607 |
| 200 | 0.00610943884 | 0.00006321073 |

El crecimiento del error al reducir `h` es consistente con cancelación por
precisión finita, no con una discrepancia del gradiente analítico. Con `h=1e-2`,
los cuatro checkpoints satisfacen `max(1e-4,0.05*abs(gradiente))` elemento a
elemento.

## Enmienda acotada

La auditoría numérica del gradiente usa desde este punto:

```text
h = 1e-2
tolerancia = max(1e-4, 0.05*abs(gradiente))
```

Los gradientes publicados siguen siendo los analíticos de `dlgradient`; la
diferencia central solo verifica su implementación. La clasificación continúa
usando el umbral preinscrito `abs(gradiente)>1e-6`. No se seleccionó `h` para
mejorar ningún resultado de PWM ni de beneficio, que permanecían sin observar.

## Segunda detención: equivalencia serial/batch

La siguiente ejecución también se detuvo antes de clasificar:

```text
C:\Users\Cesarbmm\ProtesisPracticas_no_glove_stage7o_artifacts\stage7o_final\2026-08-29_22-15-30-187
```

El replay serial de Agent200 reprodujo `actionLog` exactamente
(`maxAbsError=0`). La evaluación por lotes del mismo modelo difirió de la serial
en `1.50501728057861e-6`, sin ningún cambio de PWM en 725 filas. El gate inicial
de `1e-6` confundía esa diferencia de redondeo de precisión simple con una
discrepancia conductual.

Se conserva el requisito exacto serial-versus-log (`<=1e-12`) y cero diferencias
de PWM. Solo la equivalencia numérica batch-versus-serial pasa a `<=1e-5`. Esta
enmienda no cambia las acciones seriales guardadas, la cuantización ni las
métricas contrafactuales. Ninguna tabla de efectos ni clasificación había sido
escrita o mostrada al hacer la enmienda.
