# E2A — GLOVE-FREE EXECUTION CAUSAL AUDIT

Registro 2026-09-05, después de auditoría estática y carga de metadatos del actor,
antes de implementar o ejecutar las comparaciones causales. Arranque y remoto:
`c08b784bf4759c70a9bc2d10f0b44f638a61526a`, rama
`experiment/no-glove-paired-reference-td3`, sincronización `0 0`.

## Alcance y arquitectura decididos desde el código

`@Env`, reward y `agentTd3.m` no difieren de main `6b213ba5`. El estado es
`[40 EMG; 4 encoder normalizado; 4 delta encoder recortado; 4 acciones efectivas previas]`.
El actor recibe sólo ese estado; los críticos reciben estado y acción. El guante
alimenta reward/tracking, logs, terminación y disponibilidad de datos en reset.
Los valores del guante no forman numéricamente el estado inicial. En aprendizaje,
reward y terminación sí afectan las actualizaciones de la política.

Se implementará una clase de ejecución separada de `rl.env.MATLABEnvironment`,
sin guante ni salida reward, con `advance` y guard explícito contra entrenamiento.
Se conservarán íntegros `Env`, `calculateState`, `step`, `reset`, `checkEndEpisode`,
reward, actor, críticos y configuración histórica. La pequeña composición de
markov52 y el remapeo de acción de la clase nueva se contrastarán exactamente con
la ruta histórica real. No se introduce un modo RL con reward cero.

## Instrumento y selección fijados

Actor congelado de Agent7250, CPU, determinista 52→4, sin estado recurrente.
Se usa `getAction(actor,{state})`, sin exploración ni aprendizaje. No se evalúa
su calidad ni se compara MSE con campañas históricas: su fuente de planta de
entrenamiento es desconocida.

20 episodios: fila 1, cierre y apertura, de BLANCA, CECILIA, DENIS, EMILIA,
GABI, GABRIEL, IVANNA, JOE, JONATHAN y KHAROL. Son los diez sujetos development
ya abiertos. MATEO/SANDRA se rechazan antes de cualquier carga. Una única semilla
fija para emparejar resets; no es un experimento multisemilla.

A: `Env` histórico con teacher real. B: runtime sin guante, loader selectivo
de EMG. C: mismo `Env` con guante temporalmente invertido, misma longitud y EMG.
Se congelan actor, estado inicial de encoder, acción previa cero, planta canónica,
periodo 0.2 s y `baselineQuantized` con los niveles existentes.

Se comparan también resets A/C y se registra el encoder inicial; B recibe ese
estado inicial explícito. La prueba es condicional a iguales EMG/estado inicial.
La ruta B no recibe ni abre la variable del guante.

## Gate

En cada horizonte común se exige igualdad exacta (`isequal`) de estados, acciones
raw, efectivas, PWM y encoder. Se reportan también errores absolutos máximos.
El contrafactual debe cambiar reward en al menos un caso y no cambiar acciones.
B termina sólo por agotamiento EMG; A conserva EMG OR glove. Se añade una fixture
teacher más corta para comprobar horizontes distintos sin exigir igual duración.

La ausencia se demuestra mediante constructor sin guante, loader instrumentado
que sólo permite EMG, inspección de propiedades y perfil de llamadas sin clases
Glove/RecordedGlove/FakeGlove durante B. El guard debe impedir entrenamiento
antes de cualquier actualización. Se mantienen los 24 tests de planta E0P.

Se exportan manifiesto E0P, hash del checkpoint y de las EMG seleccionadas,
teacherSteps/gloveFreeSteps/commonHorizon, trayectorias y comparación causal,
distribución PWM y frecuencia |PWM|>=128. Ninguna métrica autoriza conclusiones
de control. Si algún estado, acción o q depende del guante, E2A falla.

Nombre y conclusión permitidos: **glove-supervised training + glove-free execution**.
No es fully glove-free learning. E1–E1D permanecen cerrados.

`E2B_AUTHORIZED=NO`, `RL_AUTHORIZED=NO`. Sin hardware ni push automático.
