# E2E — Confirmación de reversión con un paso neutro

2026-09-06. Registrado antes de ejecutar comparaciones E2E. Worktree existente:
`C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`, rama
`experiment/no-glove-paired-reference-td3`, HEAD
`165be049eb41fc41254435181c9857fe0f22ed1c`. La grafía anidada de la solicitud no
es la carpeta existente. Los archivos locales E2C/E2D recibidos se conservan;
la verificación independiente E2D pasa con 107 tests y 539 hashes históricos.
No reparación Git, cambio de rama, commit ni push; sandbox fuera del alcance.

## Hipótesis e intervención única

¿Un paso neutro de confirmación antes de una inversión inmediata evita las
órbitas P2 con menor pérdida de movimiento que la zona muerta E2D? E2D permanece
DEADBAND_NOT_SUFFICIENT, E2C CHARACTERIZED, E2B FAIL y RL no autorizado.

Se compara únicamente OFF frente a ON, sin parámetros ajustables. P2 genera
raw=clip(2*(reference_before-h(q_before)),-1,1) y el remapeo histórico produce
desiredEffective/desiredPWM. El guard se sitúa DESPUÉS del remapeo y sólo puede
copiar desiredPWM o sustituirlo por cero. AppliedEffective=appliedPWM/255.
El raw registrado sigue siendo el raw deseado P2; no se inventa una acción raw
del guard ni se modifica baselineQuantized.

Kp=2, Ts=.2, muestreo de API=.14, niveles [0,64,96,128,160,192,224,255],
velocidades, planta patternCurveCanonical/límites, h(q), teacher/reset/done,
reward/pesos, markov52, WMoos, runtime E2A y TD3 quedan intactos. No deadband,
histéresis de error, rate limiter, otro dwell, ganancia o intervención.

## Autómata por motor y contrato causal

Entradas exclusivas del helper: desiredPWM actual, previousAppliedPWM, pendingSign
y enabled. Estado inicial: previousAppliedPWM=0 y pendingSign=0. Ningún acceso a
glove, teacher, reference, error, reward, encoder, Env ni configuración global.

1. OFF: copiar desiredPWM, borrar pendingSign. Se puede registrar la solicitud
   de reversión, pero no neutralizar, confirmar ni cancelar.
2. NORMAL (pendingSign=0): request si desired!=0, previousApplied!=0 y signos
   distintos. Si request: applied=0 y pendingSign=sign(desired). Si no: copiar.
3. PENDING (la aplicación anterior fue cero): si el nuevo desired conserva
   pendingSign, confirmar y copiar el desired recalculado, incluida su magnitud.
   Si desired es cero o tiene otro signo, cancelar y copiar ese desired, sin
   forzar inversión. En ambos casos volver a NORMAL (pendingSign=0).

Una neutralización dura exactamente una decisión; el paso siguiente confirma o
cancela. No se guarda el teacher ni el error que originó P2. Se registra pending
antes/después, request, neutralized, confirmed, cancelled, previousApplied,
desired y applied. Un pending al terminar un episodio se reporta como pendiente
sin resolver; no se cuenta artificialmente como cancelación ni se alarga done.

Este helper sólo demuestra disponibilidad causal de sus entradas en ejecución
sin guante. El controlador P2 que lo alimenta sigue siendo privilegiado. No se
integra en Env/TD3; una futura integración tendría que representar su memoria
explícitamente. No se afirma que markov52 ya contenga esa memoria de confirmación.

## Muestra, secuencia y basal

Mismos 200 episodios DEVELOPMENT del MAT E2B, mismos q0, reference_before/after,
horizonte teacher y acción previa inicial cero. No abrir archivos originales de
sujetos para las nuevas comparaciones. Regresiones históricas BLANCA/fixtures
intactas; MATEO/SANDRA rechazados antes de I/O, sin comparaciones finales.

Primero reproducir los dos episodios conocidos, OFF y ON: BLANCA fila1 cierre M3
e IVANNA fila104 apertura M4, exportando pasos de todos los motores y detalle de
los motores de interés. Después, los mismos 20 replays fijos E2C (cinco teachers,
dos estados iniciales por par, dos casos, 100 pasos) y los 200 episodios OFF/ON.
Nada se selecciona tras observar rendimiento. Se conserva la API canónica real
y el remapeo histórico de la fixture E2C; reward con la función original.

OFF debe reproducir exactamente q/raw/effective/PWM en los 200 episodios E2B;
reward y resúmenes macro en 1e-12. MSE esperado .025400336373607925, reward
-.03272837710980499, dos ciclos finales y cero retrocesos M3. El teacher posterior
sólo se usa para tracking/reward; el previo genera P2 fuera del guard.

## Métricas y denominadores

Reutilizar e2bControlMetrics: MSE, MAE, reward total/media, tracking term,
action penalty .01*effective^2, delta-action penalty .05*deltaEffective^2,
actionL2, deltaActionL2, saturationFraction, PWM, responseRange, flat_response,
action_no_motion, ciclos y errores de dirección. La penalización incluye la
acción inicial desde cero y usa la acción APLICADA, también después de un neutro.

Agregación E2B: tiempo por episodio, episodios por sujeto/lado, media de los
20 grupos. Resúmenes por sujeto, motor y dirección con la misma ponderación.
Conteos de eventos se suman; no se confunden con medias macro.

MSE deterioro=100*(M_ON-M_OFF)/M_OFF; reward deterioro=100*(R_OFF-R_ON)/abs(R_OFF).
Positivo es empeoramiento. Denominador <=1e-12: sólo mejora/no deterioro absoluto
en 1e-12 es aceptable. Grupo degradado si MSE O reward empeora >5 %.

Eventos, global/motor/dirección y también motor×dirección:

- REVERSAL_REQUESTS: fórmula desired/previousApplied, incluida la rama OFF.
- NEUTRALIZED_REVERSALS: request ON que se sustituye por cero.
- CONFIRMED_REVERSALS / CANCELLED_REVERSALS: resolución del pending anterior.
- NEUTRAL_STEP_FRACTION: neutralizaciones / todos los comandos motor-paso.
- NEUTRAL_STEP_FRACTION_OF_ACTIVE_BASELINE: TODAS las neutralizaciones / comandos
  originalmente activos de OFF. Éste es el denominador fijo del gate H. Se
  incluyen neutralizaciones incluso cuando OFF era cero en el paso alineado;
  por ello es conservador respecto a contar sólo esa intersección.
- Guardar además neutralizaciones con OFF activo, y todos los pasos donde OFF
  activo termina con applied=0, con ambos denominadores; este último incluye
  cambios indirectos de trayectoria y permite comparar exactamente con E2D.
- MAX_CONSECUTIVE_NEUTRAL_STEPS: máximo por motor dentro de un episodio de
  flags neutralized consecutivos. No confundir con ceros naturales; registrar
  también rachas totales PWM0 separadamente. No concatenar episodios/motores.

Conservar NaN no-motion sin comandos activos, contar episodios/motor inactivos;
un agregado necesario indefinido no pasa. PWM0 no se cuenta como action_no_motion.

## Gates congelados y decisión

Tolerancia aritmética para umbrales: 1e-12. Candidato ON debe cumplir TODOS:

A. Cero ciclos finales con detector E2B histórico exacto.
B. Cero nuevos ciclos finales frente a OFF (clave episodio/motor o par distinto).
C. Deterioro MSE macro <=5 %.
D. Deterioro reward macro <=5 %.
E. Como máximo 2/10 sujetos, 1/4 motores y 0/2 direcciones degradados >5 %.
F. Aumento flat_response <=.02, global y cada motor/dirección.
G. Aumento action_no_motion <=.05, global y cada motor/dirección.
H. NEUTRAL_STEP_FRACTION_OF_ACTIVE_BASELINE <=.10.
I. Cero retrocesos M3 con PWM positivo y delta_q<0, igual que OFF.
J. Cero movimiento con PWM0: |delta_q|<=1e-9 encoder en cada comando cero.
K. 107 tests históricos y todos los nuevos pasan; hashes históricos intactos.

Si todos pasan: REVERSAL_GUARD_SUPPORTED. Si alguno falla:
REVERSAL_GUARD_NOT_SUFFICIENT. No cambiar gates después de medir ni probar otra
intervención. Ambos resultados mantienen RL_AUTHORIZED=NO, E3_PREPARED=NO.

## Detectores y referencia fija: evitar un falso diagnóstico de estabilidad

El detector E2B exige últimas cuatro transiciones/cinco q, A≈A≈A y B≈B en 1e-9
encoder, amplitud h>.05 y cuatro PWM consecutivos alternos no cero. Se conserva
como gate y se aplica además a todos los prefijos como diagnóstico transitorio.
NEW_CYCLES_FOUND distingue finales de nuevas ventanas transitorias y conserva
comparación con OFF en la misma ventana y par. No cambiar el detector.

El guard puede convertir A→B→A en A→B→B→A→A: el detector histórico no ve esa
órbita con pausas. ANTES de medir se define por ello un diagnóstico fijo adicional:
en las últimas 32 decisiones, buscar el menor periodo p=1..8 del estado aumentado
(q_before, previousAppliedPWM, pendingSign_before), repetido al menos cuatro
veces, con q en 1e-9 y PWM/pending exactos, amplitud h>.05 y movimiento real.
Excluir puntos fijos/HOLD. La referencia fija hace esta periodicidad del estado
aumentado causalmente interpretable; no se atribuye estabilidad universal.
FIXED_REFERENCE_CYCLES contará estas órbitas, y se reportará por separado el
detector histórico. No es otro controlador ni un cambio retrospectivo de gate.

Registrar además confirmaciones en las últimas 20 decisiones y si los comandos
no cero de esa cola alternan al menos cuatro veces (persistent reversals), pasos
neutros y sus rachas. Conservar todas las trazas para auditar otros periodos no
cubiertos. No declarar órbitas eliminadas basándose sólo en ceros del detector.

## Comparación E2D, integridad y entrega

Comparación descriptiva exclusivamente con epsilon .08 de E2D ya cerrado: MSE,
reward, flat/no-motion, ciclos y fracción directa/pareada de acciones a cero con
denominadores explícitos. No regenerar E2D ni seleccionar nuevos epsilon.

Capturar una vez hashes de fuentes/artefactos E0P–E2D recibidos, sin sandbox;
verificar antes y después. Guardar manifiesto E0P, hash de este preregistro y de
fuente E2B, CSV/MAT/JSON de trazas/métricas/gates, tests e integridad en e2e_results.
Los tests anteriores escriben sólo bajo e2e_results mediante directorios de
salida inyectados; no sobrescribir informes, resultados ni fuentes anteriores.

Tests nuevos: OFF exacto, detección, un paso neutro, confirmación/cancelación,
independencia de teacher por interfaz/ejecución, dos casos E2C, ciclos originales
y órbita sintética con pausas, gates, no nuevas inversiones M3, PWM0 sin movimiento,
determinismo, hashes intactos. No se confunde un gate científico fallido con un
test roto: las pruebas de conteos contrastan mediciones sin ocultar fallos.

Entregar RESULTADOS_E2E.md y dejar todo local. No tocar MATEO/SANDRA, no RL,
no integración en Env, no siguiente etapa, no reparación Git, commit ni push.
