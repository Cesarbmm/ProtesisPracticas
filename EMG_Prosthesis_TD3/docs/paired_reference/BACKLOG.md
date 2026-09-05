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

### SUPERVISED_SUBJECT_CALIBRATION  -- CERRADO por E1D, ver `09_RESULTADOS_E1D.md`

- **Origen:** E1B, veredicto `E1B_EMG_ONLY_CALIBRATION_FAIL`.
- **Idea:** el usuario aporta unas pocas repeticiones **con guante** durante la calibracion inicial,
  y el decoder se adapta con esos pares supervisados.
- **Estado:** registrada, **sin implementar**.
- **Advertencia que debe ir en el preregistro si se abre:** rompe
  `NEW_USER_GLOVE_REQUIRED_FOR_CALIBRATION = NO` y cambia la promesa de la linea. El usuario
  necesitaria el guante una vez, aunque no en operacion. Eso sigue siendo defendible
  cientificamente, pero es una tesis distinta de "sin guante".

### EMG_CHANNEL_ALIGNMENT  -- CERRADO por E1C, ver `08_RESULTADOS_E1C.md`

- **Origen:** E1B, seccion 8.
- **Idea:** si los momentos marginales no explican el fallo, el candidato es la relacion EMG->guante
  en si: colocacion del Myo, rotacion del brazalete, orden de canales entre capturas. La ETAPA 2 de
  la rama antigua ya documento que la metadata no garantiza colocacion ni orden de canales.
- **Posible experimento:** buscar la rotacion ciclica de los 8 canales que maximiza la
  transferencia, estimada **solo con EMG** del sujeto nuevo.
- **Estado:** registrada, sin implementar.

### PER_SUBJECT_CHANNEL_MIXING

- **Origen:** E1C, seccion 5.
- **Hecho medido:** existe un desplazamiento de canales reproducible por sujeto (transfiere entre
  mitades, 41.9 % de sus episodios frente al 12.5 % del azar) que vale ~3 % de MSE, pero no coincide
  entre gestos (2/10) ni entre motores (0/10).
- **Lectura:** no es una rotacion del brazalete; se parece mas a que el modelo encuentra una
  recombinacion de canales algo mejor para cada sujeto.
- **Estado:** cerrado. Efecto real pero de orden equivocado. No justifica abrir etapa.

### REPRESENTATION_AND_DATA

- **Origen:** conclusion conjunta de E1, E1B, E1C y E1D.
- **Hecho medido:** en las cuatro etapas, romper el emparejamiento EMG-target dentro del mismo gesto
  y fase cuesta entre +0.3 % y +1.2 % de MSE. El oraculo gesto+fase es siempre el doble de bueno que
  el mejor decoder.
- **Lectura:** el limite no esta en el controlador ni en el algoritmo, sino en que las 40 features
  WMoos sobre ventanas de 0.2 s del dataset Denis no contienen informacion de trayectoria mas alla
  del gesto y su fase.
- **Lo que abriria la linea de nuevo, y que NO se hace ahora:** datos nuevos con protocolo de
  adquisicion controlado (colocacion, reposo etiquetado, calibracion por sesion), o una
  representacion distinta de la EMG. Ambas cosas son proyectos propios, no etapas de esta linea.
- **Estado:** cerrado.

### PLANT_LEGACY_CFIT_PHYSICS  -- ABIERTO, fuera de alcance

- **Origen:** E0P.
- **Hecho medido:** con Curve Fitting Toolbox instalada, la ruta `legacyAuto` lee `ws` como objetos
  `cfit` con `numel(ws) = 1` y la trayectoria colapsa por el clamp. Sin la toolbox, los lee como
  numericos vacios y cae a `pattern_curve`. Las dos fisicas conviven en el mismo commit historico.
- **Estado:** documentado y aislado, no reparado. `legacyAuto` se conserva **sin modificar** para
  poder reproducir corridas antiguas; la rama nueva usa `patternCurveCanonical` y no lo toca.
- **Lo que quedaria por saber, y que NO se investiga ahora:** en cual de las dos ramas se entreno
  `Agent7250` y las campanas historicas. No esta registrado y no es recuperable del repositorio.
  Solo se sabria re-ejecutando cada agente bajo las dos rutas y comparando, lo que no aporta nada a
  esta linea.

### PLANT_CONTROL_RESOLUTION — ABIERTO, DIAGNOSTIC_ONLY

- **Origen:** diagnóstico E0, auditado y corregido en E0P.
- **Medición:** en 0.2 s, PWM64 distingue 11–21 destinos (mediana 18), PWM96 5–21
  (mediana 12.5) y PWM>=128 2–20 (mediana 3.5), usando 21 posiciones globales por motor.
  En PWM alto, 18/40 combinaciones dan dos destinos; 20/21 posiciones llegan al mismo
  endpoint y una mantiene posición. Las medias de desplazamiento absoluto/carrera por
  grupo van de 7.84–33.48 %, 14.08–43.42 % y 32.51–49.48 %, respectivamente.
- **Corrección:** el anterior 12.7–47.2 % era fracción temporal, no de carrera. «Dos destinos»
  no describe todos los motores/direcciones. La rejilla por combinación da resultados distintos.
- **Alcance:** caracteriza la planta simulada congelada. No demuestra pérdida de control
  proporcional, rendimiento de TD3, física de hardware ni causas de mesetas históricas.
- **Estado:** sin cambios de periodo, action space, PWM, TD3 o reward. Tablas completas en
  `E0P_PWM_DIAGNOSTICS.md`. Cualquier intervención futura requiere otra autorización.

### PLANT_CURVE_ENTRY_AND_LONG_HORIZON — ABIERTO, CARACTERIZACIÓN

- **E0P:** los 28 fallos M3 cierre de 3 s se reproducen en la rejilla histórica. En la rejilla
  global hay 27 cierre y uno apertura M3 -192 desde 1295.5, con retroceso interno de 0.25 encoder.
- El bound heurístico 1.5×avance de curva falla en cuatro casos global11 y dos por combinación21
  porque omite la distancia desde el estado inicial al comienzo del recorrido empírico.
  Los seis coinciden con E0. No equivalen al caso de búsqueda fallida que activa HOLD.
- **Estado:** datos intactos; defectos visibles mediante trayectorias completas y tests de
  caracterización. Monotonicidad operativa 0.2 s: cero fallos en ambas rejillas de 1176.
