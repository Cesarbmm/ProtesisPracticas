# E2D — Intervención mínima mediante zona muerta de error

2026-09-06. Registrado antes de medir comparaciones E2D. Worktree real existente
`C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`, rama
`experiment/no-glove-paired-reference-td3`, HEAD
`165be049eb41fc41254435181c9857fe0f22ed1c`. Los archivos locales E2C recibidos
fueron auditados y su comprobador de artefactos pasó. Se conservan sin modificar.
No reparación Git, cambio de rama, commit ni push. Sandbox queda fuera.

## Hipótesis e intervención única

¿Puede una zona muerta alrededor del teacher eliminar las órbitas P2 sin degradar
materialmente tracking/reward? E2B permanece FAIL, E2C CHARACTERIZED, RL no autorizado.
No se afirma que la cuantización sea causa exclusiva: Kp, Ts y tamaño del paso
no fueron aislados en E2C. No se intenta corregir la planta M3.

Para cada motor, e=reference_before-h(q_before):

```text
rawHistórico = clip(2*e,-1,1)
rawE2D = 0 si abs(e)<=epsilon; rawHistórico en otro caso
effective/PWM = remapeo histórico baselineQuantized(rawE2D)
```

Rejilla única y fija: **epsilon=[0,0.03,0.05,0.08,0.12]**. No barrido adicional,
interpolación, ajuste por sujeto/motor ni elección continua. Epsilon=0 debe
reproducir exactamente P2; en e=0 el raw histórico ya es cero.

Interpretación: epsilon .03 significa tres puntos porcentuales de la escala
unitaria h/teacher, no 3 % de encoder ni de su carrera. h usa la conversión y
divisores históricos [4092,2046,1023,2046]; gaps/saturaciones permanecen intactos.
La activación raw .05 equivale a abs(e)=.025. Por ello .01/.02 no cambiarían el
PWM respecto a P2 y se omiten como comparaciones redundantes. Los errores de
corrección conocidos E2C son aproximadamente .051–.072 (M4) y .078–.108 (M3,
incluyendo referencia fija primaria). .08 y .12 cubren ese soporte ya observado;
no se eligieron tras medir E2D. .12 es un diagnóstico amplio, sujeto a los mismos
gates de degradación/inactividad, no una aceptación anticipada.

Congelados: Kp=2, Ts=.2, muestreo API=.14, velocidades255, niveles históricos,
activación .05, baselineQuantized, patternCurveCanonical/límites, h(q), teacher,
reward/pesos, markov52, WMoos, runtime E2A, TD3 y actor/críticos. No histéresis,
limitador de acción, otro controlador ni nuevos datos. No RL/hardware/decoder.

## Muestra, ejecución y causalidad

Mismos **200 episodios DEVELOPMENT** y horizonte teacher de E2B; mismos q0,
referencias previas/posteriores y acción previa inicial cero. Reutilizar el MAT
de trayectorias E2B, seleccionando P_2, sin abrir archivos originales de sujetos
para el análisis nuevo. Las regresiones históricas conservan sus pruebas BLANCA
y fixtures; MATEO/SANDRA sólo se mencionan en tests que rechazan antes de I/O.

Ejecutar la API canónica real y el remapeo histórico intacto con la fixture E2C.
Evaluar el reward mediante trackingMseActionRateReward original con un contexto
de sólo sus datos necesarios (teacher posterior, h(q_after), acción efectiva
previa), sin editarlo. No construir un modo de entrenamiento ni reward cero.
La duración se toma del episodio E2B ya terminado por teacher; no prolongarlo ni
reinterpretar done. Epsilon=0 debe igualar q/raw/effective/PWM exactamente y reward
en 1e-12, y reproducir MSE/reward macro en 1e-12 y los dos ciclos originales.

## Métricas y comparaciones

Reutilizar e2bControlMetrics: trackingMSE, MAE, rewardMean/rewardTotal, actionL2,
deltaActionL2 (incluye salto inicial), saturationFraction, PWM, responseRange,
flat_response y action_no_motion. Separar tracking term, action penalty y
delta-action penalty. Por episodio/motor, sujeto, lado, motor y macro global.
Agregación idéntica a E2B: tiempo dentro del episodio; episodios dentro de cada
sujeto/lado; media de los 20 grupos. Sujetos promedian ambos lados; direcciones
promedian diez sujetos; motores mantienen la misma ponderación de 20 grupos.
Conteos de ciclos se suman, no se convierten en una media macro ambigua.

Deterioro MSE (%) = 100*(M_e-M_0)/M_0.
Deterioro reward (%) = 100*(R_0-R_e)/abs(R_0), pues mayor reward es mejor aunque
sea negativo. Positivo significa empeoramiento en ambas métricas. Denominadores
de magnitud <=1e-12: sólo aceptar incremento absoluto <=1e-12; documentar el caso.

Un sujeto/motor/dirección cuenta como degradado si **cualquiera** de MSE o reward
empeora >5 %. No promediar deterioros para ocultar una métrica peor.

## Gates fijados antes de medir y selección

Un candidato epsilon>0 debe cumplir simultáneamente:

A. Cero ciclos finales en los 200 episodios/800 episodio-motor con el detector
E2B exacto: últimas cuatro transiciones/cinco q, q0≈q2≈q4 y q1≈q3 (1e-9 encoder),
amplitud h>0.05 y cuatro PWM con signos alternos no nulos. Se reutiliza el helper
de métricas histórico para el gate y se valida el detector diagnóstico contra él.
B. Deterioro MSE macro <=5 %.
C. Deterioro reward macro <=5 % según la fórmula anterior.
D. Como máximo 2/10 sujetos y 1/4 motores degradados; **0/2 direcciones** degradadas.
E. Cero nuevas inversiones M3 con PWM positivo y delta_q<0 (P2 basal tiene cero).
   Registrar otros errores de dirección y movimiento con PWM0, sin modificar planta.
F. Materialidad explícita: aumento flat_response <=**2 puntos porcentuales** y
   action_no_motion <=**5 puntos porcentuales**, globalmente y en cada motor y
   dirección. Son límites absolutos de proporción, no porcentajes relativos.
   Conservar NaN de no-motion cuando no existen comandos activos y registrar
   cuántos episodios/motores quedan sin acción; un agregado indefinido no pasa.
   Guard adicional de movimiento: como máximo **20 % de comandos originalmente
   activos de P2** terminan en PWM0 al comparar las trayectorias paso a paso,
   agrupando todos los comandos motor-paso. Así no se acepta apagar gran parte
   del episodio para eliminar ciclos. Este límite se declara antes de medir.
G. Las 81 regresiones anteriores y todos los tests nuevos pasan; hashes históricos
   intactos. Tolerancia aritmética de comparación de umbrales: 1e-12.

Seleccionar **el menor epsilon positivo que pase todos los gates**; no seleccionar
sólo por los dos casos conocidos ni por MSE mínimo. Si ninguno pasa:
SELECTED_EPSILON=null; métricas seleccionadas no aplicables, tabla completa de
todos los valores; E2D_RESULT=DEADBAND_NOT_SUFFICIENT. No nombrar un fallido como
seleccionado ni añadir valores. Si alguno pasa: MINIMAL_ANTI_CHATTERING_SUPPORTED.
Ambos resultados mantienen RL_AUTHORIZED=NO y no abren la siguiente etapa.

## Ciclos y contrafactual local

Guardar todas las trazas de los dos casos E2C, para cada epsilon, con teacher
antes/después, h(q), error, raw histórico en ese mismo estado, raw intervenido,
effective, PWM y q antes/después. Identificar nuevas parejas, no sólo desaparición
de las originales. NEW_CYCLES_FOUND cuenta ciclos finales en nuevas claves
episodio-motor o con un par de estados distinto (tolerancia1e-9) del basal.

Diagnósticos adicionales, separados del gate A: aplicar el mismo detector de
cuatro transiciones a cada prefijo de todos los episodios (ciclos transitorios)
y repetir los 20 contrafactuales fijos E2C por epsilon (cinco teachers ×dos estados
×dos casos, 100 pasos). Reportar cualquier nuevo par, parada en uno de los estados
y PWM0. No sustituir el gate final E2B por un detector nuevo después de medir.

Reutilizar los 5832 pares q/reference del mapa local E2C, mismos estados y teacher,
para comparar raw/PWM/q_next antes/después del deadband. Añadir puntos en error
±.025 y ±epsilon con perturbación1e-10 para mostrar la frontera raw±.05 y la
frontera inclusiva de la intervención. No modificar el remapeo.

## Cuánto movimiento se elimina

Guardar dos estimandos con numeradores y denominadores, global, por motor y lado:

1. Inhibición directa en el **mismo estado intervenido**: PWM que P2 sin deadband
   mandaría !=0 y PWM con deadband=0. Dividir por todos los comandos motor-paso y
   por los comandos activos de ese P2 contrafactual; esto aísla el efecto local.
2. Diferencia frente a la **trayectoria original P2**: PWM basal !=0 y PWM actual=0
   en el mismo paso. Incluye cambios indirectos porque q puede divergir. Dividir
   por todos los comandos y por comandos basales activos. El segundo denominador
   determina el guard20%; ZEROED_ACTION_FRACTION principal usa todos los comandos
   del primer estimando y se acompaña de los demás para evitar ambigüedad.

No confundir PWM0 con acción activa que no mueve, ni NaN con cero no-motion.

## Integridad, tests y entrega

Antes de medir, inventario SHA256 de fuentes históricas incluidas las locales E2C;
comparar al final. Artefactos nuevos sólo e2d_results, sin sobrescribir E0P–E2C.
Guardar manifiesto E0P, preregistro/hash, configuración, CSV/MAT/JSON de trazas,
resúmenes y gates por epsilon, todos los grupos, PWM, ciclos y efectos de cero.

Tests: epsilon0 exacto en200; umbral inclusivo; fuera banda idéntico; remapeo,
planta y reward históricos; detector igual; guard nuevas reversiones; determinismo;
hashes intactos; gates sintéticos y selección nula si todos fallan. Las regresiones
que caracterizan fallos previos deben seguir pasando sin cambiar sus expectativas.

RESULTADOS_E2D.md con resultados medidos y límites. Sin implementación en Env/TD3,
sin otra intervención. E2B=FAIL y E2C=CHARACTERIZED permanecen congelados.
MATEO_SANDRA_SEALED=YES, RL_AUTHORIZED=NO, E3_PREPARED=NO, E3_EXECUTED=NO.
GIT_REPAIR_ATTEMPTED=NO, COMMIT=NO, PUSH=NO.
