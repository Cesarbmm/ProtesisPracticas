# Backlog

Hipótesis aparcadas. **No se abre etapa por ninguna de ellas sin discutirlo primero.**
Este archivo existe para que una idea buena no se convierta en una sub-etapa improvisada.

| # | Idea | Origen | Condición para reconsiderarla |
|---|---|---|---|
| 1 | Ablación de niveles de cuantización con TD3 (8 vs 4 vs 2 niveles) | alternativa correcta al pivote DQN de ETAPA 12 | sólo si reaparece aliasing de acción en E3 |
| 2 | Reposo / abstención en reposo | ETAPAS 07c–07u | sólo con un dataset que contenga reposo etiquetado |
| 3 | Validación con Myo real | avance de julio 2026 | después de E3, y sólo si E3 sale (a) |
| 4 | Oposición y liberación | ETAPA 2 | requiere datos que no existen |
| 5 | DTW como término de reward | ETAPA 7 | rechazado con umbral preregistrado del 5 % (1.07 % / 3.50 %) |
| 6 | Línea residual y stop-band | `main` | no se mezcla con esta línea |
| 7 | Campañas multiseed 20k/50k | avance de julio 2026 | sólo después de que E3 salga (a) |
| 8 | Motor 2: respuesta plana | diagnóstico histórico | se vigila con los flags por motor, no se abre etapa |
| 9 | Curva de referencia no monótona en motor 3 / cierre (28 fallos residuales, sólo en estrés de 3.0 s) | E0 | si aparece en el paso operativo, o antes de usar duraciones > period |
| 10 | Cobertura de `pattern_curve`: motor 2 / apertura / PWM 64 no cubre posiciones altas (2 saltos residuales, 0.17 %) | E0 | si el porcentaje sube al re-ejecutar E0 |
| 11 | Nivel PWM 255 se ajusta a `SIM_SPEEDS` 256; único nivel no exacto | E0 | irrelevante hoy; revisar si se cambian los niveles |

## Elementos con identificador formal

### MOTOR3_LONG_HORIZON_NONMONOTONIC_CHARACTERIZATION

- **Origen:** E0, Enmienda 2.
- **Hecho medido:** 28 fallos de monotonicidad, todos en motor 3, `closing`, únicamente con la
  duración de estrés de 3.0 s. Cero en el paso operativo de 0.2 s.
- **Causa:** la curva de caracterización de motor 3 en cierre no es monótona.
- **Estado:** abierto. **No se modifica la curva experimental.**
- **Condición para reabrir:** que aparezcan fallos de monotonicidad en el paso operativo, o antes
  de usar cualquier duración mayor que `params.period`.

### E1_SUBJECT_SPECIFIC_DECODER

- **Origen:** E1, veredicto `E1_SUBJECT_SPECIFIC_ONLY`.
- **Hecho medido:** dentro de sujeto el ridge mejora un 42 % sobre la media, la ablacion global lo
  degrada +80.9 % y la condicionada +6.4 %, positiva en los 8 sujetos. Entre sujetos no transfiere.
- **Pregunta que abriria:** .puede quitarse el guante para un usuario que aporta unos minutos de
  calibracion propia? Es como funcionan las protesis mioelectricas reales.
- **Estado:** cerrado. Cambia la pregunta cientifica de la linea y necesita su propio preregistro.

### E1_NORMALIZATION_RECOMPUTE

- **Origen:** E1, seccion 1.7.
- **Hecho medido:** los C/S historicos vienen de un corpus de 306 sujetos con otra longitud de
  ventana; F2 y F5 difieren 17x y 33x de los estadisticos de Denis.
- **Estado:** cerrado. Recalcular C/S solo con los 8 sujetos de train es una variante razonable,
  pero rompe compatibilidad con el pipeline historico. El control de escala de la seccion 4 ya
  mostro que no explica el fracaso de E1.

### WMOOS_F2_AXIS_SEMANTICS

- **Origen:** E1, seccion 1.4.
- **Hecho medido:** `hilbert` y `sgolayfilt` se aplican a lo largo de los 8 canales, no del tiempo.
- **Estado:** cerrado. **No se corrige.** Cambiarlo invalidaria la comparabilidad con `Agent7250` y
  con todas las campanas historicas.
