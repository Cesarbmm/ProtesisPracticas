# Residual Lift Pausado

Contiene launchers para entrenar una rama residual sobre `Agent7250`
congelado. La politica residual se mantiene como referencia futura:

```text
a(s) = clip(a_base(s) + alpha_res * a_res(s, a_base), -1, 1)
```

Motivo de pausa: las corridas residuales redujeron esfuerzo y saturacion
en algunos casos, pero no superaron de forma robusta al benchmark y los
test visuales mostraron una falla recurrente en el motor 2.

Para retomarlo, primero ejecutar la fase activa de benchmark base y revisar
si el problema del motor 2 viene del entrenamiento o del entorno/simulador.
