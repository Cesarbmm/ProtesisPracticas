# E2B — contrato supervisado y factibilidad de control, sin RL

Fecha: 2026-09-05. Escrito después de auditoría estática y **antes de ejecutar
inventario nuevo o comparaciones E2B**. Inicio `fc2e15bb931b79f41be6ce1c3c822dd88a8e9c40`,
origin `c08b784bf4759c70a9bc2d10f0b44f638a61526a`, distancia `1 0`.
Único residuo local previo: FUSE no rastreado, conservado. No existía preregistro
E2B posterior. Se leyeron completos E2A, E1D, E0P, DECISIONES, BACKLOG y roadmap.

## Hipótesis y límites

¿Está bien definido y es controlablemente viable el protocolo de entrenamiento
supervisado por guante que permitiría ejecutar TD3 sin guante? E2B no entrena.
La antigua E2/emgDecoder está supersedida por el cierre E1–E1D. No se reabre.
Agent7250 sólo es instrumento congelado; su rendimiento no decide el gate.
MATEO/SANDRA permanecen sellados, sin carga ni inspección de sus archivos.

Se conservan TD3/actor/críticos, markov52, features WMoos, dataset, reward y pesos,
baselineQuantized, velocidades 255, niveles [0 64 96 128 160 192 224 255], umbral
0.05, periodo 0.2 s y planta patternCurveCanonical. Sin PD, DTW nuevo, hardware,
reposo, motionPermission, normalización, decoder o escalas de acción nuevas.

## A. Contrato teacher y done

Decisión metodológica preregistrada: **conservar terminación histórica por
disponibilidad teacher** (`EMG exhausted OR glove exhausted`) como frontera del
objetivo episódico supervisado. No representa un terminal físico de la prótesis.
Reward requiere teacher válido; no se prolonga con ceros, último valor retenido,
extrapolación o teacher inventado. Reset conserva disponibilidad EMG y guante.
La ejecución sin guante E2A continúa terminando exclusivamente por EMG.

Desacoplar esos límites durante aprendizaje exigiría definir truncación con
bootstrap y tratamiento explícito del reward ausente. Cambiar sólo `done` sin
esas decisiones no es una alternativa equivalente. No se modifica reset/termination
en E2B. Se cuantifica su alcance y se testa el contrato histórico existente.

Inventario: **todas** las filas/lados de los diez sujetos development ya abiertos
(BLANCA, CECILIA, DENIS, EMILIA, GABI, GABRIEL, IVANNA, JOE, JONATHAN, KHAROL).
Carga selectiva de `emgs` y `gloves`, sin getDataset predeterminado de 12 sujetos.
Registrar longitudes, duraciones nominales a 200/10 Hz, consumo de reset,
horizontes histórico/EMG-only, agotamiento de cada lector, causa exacta, muestras
EMG sin utilizar y fracción atribuible específicamente al teacher, por episodio,
sujeto y lado. Separar el posible residuo de una muestra causado por `j>=n`.
Longitudes inválidas se registran; no se reparan ni ocultan.
Registrar también cuántos horizontes alcanzarían el tope histórico de 50 pasos
de trainOptions; éste es otra frontera de la receta, distinta de `done` de Env.

Para longitudes ordinarias, reset consume 40 EMG y 2 teacher; cada paso otros
40/2. El lector termina al consumir al menos n−1 muestras. Se validarán fórmulas
contra lectores reales, incluidas fronteras y el primer step que Env fuerza tras
reset. No se confunden muestras de reset con pasos de control.

El código TD3 local R2023b elimina bootstrap para IsDone==1. Con N=1 y gamma=.95,
el factor es gamma*(1-done). Cuantificar cuántas transiciones finales cambiarían
ese factor bajo fin EMG-only. En los episodios muestreados de Agent7250 registrar
además gamma*min(Q1,Q2) online congelados en el siguiente estado/acción, sin ruido:
**sensibilidad instrumental a done**, no el target real de training (éste usa
críticos target y smoothing), ni evidencia de calidad del checkpoint.

Se repite A/B con actor congelado en los episodios muestreados: Env teacher vs
GloveFreePolicyRuntime EMG-only. Mismas EMG, estado inicial, actor, semilla única
20260905, acción inicial cero y planta. n+1 estados/q y n acciones raw/efectivas/PWM
deben ser exactamente iguales en el horizonte común con teacher válido.

## B. Diseño de control y selección

Hasta **200 episodios**: diez filas originales equiespaciadas por sujeto, ambos
lados. Elegir `unique(round(linspace(1,N,10)))` sobre filas estructuralmente válidas
en ambos lados (EMG finita Nx8, N>=80; teacher no vacío con >=4 registros).
Si hay menos de diez filas válidas, usar todas y reportarlo. No seleccionar por
tracking ni por controlabilidad. El inventario completo conserva las exclusiones.

Cada episodio se prepara como E2A: reset cierre; para apertura, dos resets
consecutivos sin rollout de cierre previo. Guardar q0 real. Todos los controladores
usan ese mismo protocolo histórico y se evalúan en el mismo horizonte teacher.
No comparar sumas de reward entre episodios de duraciones distintas como principal.

Controladores: u=0; P con **Kp=[0.5,1,2,4,8]**, escalar común a los cuatro motores;
Agent7250 congelado determinista CPU sin exploración ni aprendizaje.

P causal puro:

    raw_k = clip(Kp * (r_before_k - h(q_before_k)), -1, 1)

`r_before` es la última referencia ya leída en reset o paso anterior; primera
acción usa el registro 2, NO el 4 futuro. `h(q)=flexJoined_scale(encoder2Flex(q))`
es la conversión histórica de reward, distinta del encoder normalizado del estado.
Se usa el remapeo real de Env. No se reutiliza referenceQuantizedController, que
incorpora bins y limitador de variación y no equivale a este P. P accede al teacher
como diagnóstico de controlabilidad privilegiado, no como política desplegable
sin guante. Su éxito no demostraría que EMG permite aprender ese comportamiento.

Seleccionar **un único Kp** minimizando MSE macro: media temporal por episodio,
media de episodios por sujeto/lado y media de los 20 grupos. Desempate dentro de
1e-12: mayor reward medio; después menor Kp. Sin ganancias por motor/dirección.
Aplicar todos los gates al mismo Kp, sin elegir otro si algún criterio falla.
La selección y evaluación son development descriptivas; no final test ni estimación
de generalización sin sesgo de selección.

## Métricas y artefactos

En el mismo espacio normalizado de reward: trackingMSE, MAE y correlación Pearson
por motor/episodio (NaN si cualquiera es constante; reportar cantidad válida).
Registrar responseRange=max(h(q))−min(h(q)) incluyendo q0; referencia y encoder
crudo también. `flat_response`: rango <=1e-9. `action_no_motion`: proporción de
comandos no nulos con abs(delta_q)<=1e-9 encoder; NaN si no hubo comandos activos.

actionL2=media(effective^2); deltaActionL2 incluye el salto inicial desde cero y
usa media por motor, coherente con reward. saturationFraction=media(abs(effective)
>=.95), conforme al helper de reward, distinta de frecuencia abs(PWM)>=128.
Exportar distribución PWM firmada y por magnitud, cambios de signo y overshoot.
Cambios de signo: pares consecutivos con ambos comandos no nulos; overshoot:
cruce de h(q_before) a h(q_after) respecto a la misma referencia posterior al paso.
Este último es sólo una métrica, no una entrada futura de P. Para saltos se registra
el bound heurístico E0P 1.5 veces el máximo avance de curva en 200 índices: separar
excesos explicados por q inicial anterior al primer punto de la curva en dirección
del comando de excesos no explicados. No llamarlo límite físico validado.

Descomposición exacta por paso y motor: reward=−error²−.01*effective²
−.05*(effective−previousEffective)². Guardar reward total, tracking term,
action penalty, delta-action penalty; contrastar contra reward real de Env.
Resumir por controlador/Kp, sujeto, lado y motor con denominadores explícitos.

Guardar CSV/MAT/JSON: inventario y distribución de disponibilidad, selección y
procedencia, manifiesto E0P, checkpoint/hash, configuración efectiva, métricas de
episodios/subgrupos, todas las trayectorias, PWM, A/B, sensibilidad done y tests.
Guardar hash del preregistro usado. Verificación independiente de artefactos.

## Gate fijado antes de medir

1. Ausencia de guante de observación/actor/planta; semántica teacher/reward/done
   documentada y testeada; A/B exactamente igual en horizonte común válido.
2. Los 37 tests previos E2A/E0P y los nuevos pasan, sin modificar datos congelados.
3. P elegido reduce MSE macro **al menos 10 %** frente a cero y aumenta reward
   macro más de 1e-12. El 10 % exige una ganancia material, no sólo redondeo.
4. P mejora estrictamente MSE y reward en ambas direcciones y al menos 8/10 sujetos;
   mejora MSE en al menos 3/4 motores y ninguno empeora más del 5 %. Si MSE de cero
   <=1e-12, exigir MSE de P <=1e-12 en ese motor. Son criterios de coherencia
   descriptiva, no pruebas estadísticas ni precisión suficiente para hardware.
5. Cero errores de dirección respecto al PWM, cero movimiento con PWM cero,
   cero discrepancias con trayectoria E0 congelada para las transiciones ensayadas.
   Reportar saltos de entrada a curva conocidos en E0P; no inventar un bound de
   velocidad física que E0P no demostró. Un salto nuevo no explicado por esa
   caracterización bloquea PASS. Revisar trayectorias completas, no sólo MSE.
6. Para el P elegido, ausencia de ciclos persistentes de dos estados en los cuatro
   últimos pasos: alternancia q0≈q2≈q4, q1≈q3 (1e-9 encoder) y amplitud >0.05 en
   espacio reward, con signos alternos no nulos. Se registra como patología nueva
   de cuantización si aparece; no se rescata cambiando niveles o periodo.
7. MATEO/SANDRA siguen sellados. Agent7250 no determina ningún criterio de rendimiento.

Si falla cualquier condición: **E2B_RESULT=FAIL, RL_AUTHORIZED=NO**. Documentar
causas sin más barridos, controladores ni modificaciones para rescatar el gate.
Si todas pasan: **E2B_RESULT=PASS, RL_AUTHORIZED=YES**, pero no ejecutar training.
Sólo entonces preparar E3 manual: TD3 feedforward histórico, receta compatible
Agent7250, piloto <=600 episodios, checkpoints frecuentes, selección sólo validation,
final test sellado y comparación cero/P/TD3 con roles de información explícitos.

Entrega: RESULTADOS_E2B.md, artefactos, tests, actualización mínima del roadmap y
DECISIONES, un commit local E2B. **PUSH=NO, E3_EXECUTED=NO.**
