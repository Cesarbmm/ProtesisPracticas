# E2C — Caracterización causal de los bloqueadores de E2B

Fecha: 2026-09-06. Registrado antes de cargar los datos para el análisis causal E2C.
Rama `experiment/no-glove-paired-reference-td3`, HEAD inicial
`165be049eb41fc41254435181c9857fe0f22ed1c`, árbol inicial limpio.
Worktree real existente: `C:\Users\Cesarbmm\ProtesisPracticas_e2b_audit`.
La grafía anidada de la solicitud no corresponde a un directorio existente.
Incidencia Git pospuesta: sin reparación, publicación, cambio de rama ni commit.
No se usa código, documentación científica ni resultados de sandbox_physics.

## Preguntas y restricciones

Q1: ¿los dos ciclos P2 provienen de cuantización, tamaño del paso de planta,
referencia móvil o interacción? Q2: ¿las inversiones locales M3 son estructura
empírica repetible, efecto del promedio o baja repetibilidad?

E2B permanece FAIL. Su controlabilidad de tracking está apoyada: P2 mejora MSE
y reward, pero falla por dos alternancias preregistradas. P2 no produjo retrocesos
M3; P8 produjo 125 y Agent7250 diagnóstico 395. E2C no reevalúa ese gate.

Se congelan Kp=2, Ts=0.2 s, sampling_period=0.14 de la API operativa, velocidades
255, niveles [0 64 96 128 160 192 224 255], activación 0.05, baselineQuantized,
patternCurveCanonical, límites, markov52, WMoos, reward y pesos, TD3, teacher
termination y runtime E2A. Sin RL, hardware, decoder, nuevas soluciones ni E2D.
MATEO/SANDRA sellados: se reutilizan exclusivamente artefactos DEVELOPMENT E2B y
caracterización de motores. No se cargan archivos originales de sujetos.

## Fuentes y trazabilidad

Leer completos preregistro/resultados E2B y resultados E0P/E2A. Fuente numérica
principal: `e2b_results/trajectories.mat` (precisión MATLAB), contraste con
`step_traces.csv`, métricas y resúmenes congelados. Planta: MAT canónico y CSV
de límites; procedencia de repeticiones: scripts históricos de creación y sus
archivos de motor, nunca sandbox. Registrar SHA256 del preregistro y fuentes.
Guardar inventario SHA256 de archivos históricos usados y comprobarlo al final.
No sobrescribir e0p_results, e2a_results ni e2b_results.

## Q1 — dos casos fijados

1. BLANCA fila 1 cierre, M3, cuatro transiciones finales: q alterna entre
1541.666666666667 y 7532.5; PWM +224,-64,+224,-64.
2. IVANNA fila 104 apertura, M4, cuatro transiciones finales: q alterna entre
6049.75 y 2976.333333333333; PWM -64,+96,-64,+96.

Reconstruir el episodio y marcar la ventana final. Exportar por paso/motor
reference_before/after, h(q_before), error, raw=clip(2*error,-1,1), effective,
PWM, q_before/after, delta_q, cuantización effective-raw, y reward separado
en tracking, penalización de acción, penalización delta y total. Identificar
valores por motor y media de cuatro motores; incluir acción previa real.
Usar conversión histórica h(q), no encoder normalizado de markov52.

Replay A: referencias históricas exactas desde q de inicio de ventana, sin
consultar datos futuros para la acción. Exigir reproducción q/PWM en 1e-9 encoder
y 1e-12 acción/reward (CSV sólo diagnóstico de serialización).
Replay B: congelar, por separado, cada uno de los cuatro reference_before de la
ventana y su media aritmética. Referencia primaria: primer reference_before.
Repetir 100 pasos desde cada uno de los dos estados del par, Kp/Ts intactos.
Registrar persistencia del par original y cualquier otro par, con tolerancia
1e-9 encoder, durante al menos las últimas 20 transiciones y amplitud h>0.05.
No llamar ciclo infinito a 100 pasos; si la referencia fija hace regresar
exactamente A→B→A, identificar además esa órbita del mapa determinista.

Mapa local: para cada estado histórico de la ventana, q+offset con offsets
[-128,-64,-16,-1,0,1,16,64,128] encoder y reference_before+linspace(-.04,.04,81).
No recortar la referencia diagnóstica; registrar si sale del rango [0,1].
Añadir barrido entre ambos estados (1001 puntos, referencia primaria fija).
Evaluar raw, effective, PWM, q_next y posición relativa al teacher.

Auditar todas las fronteras analíticas de la cuantización real: umbral raw
±0.05 y puntos medios entre niveles activos divididos por 255; el empate conserva
el primer mínimo (nivel inferior). Evaluar a ambos lados con perturbación raw
1e-10, sin editar el remapeo. Reportar salto PWM, error equivalente raw/2 y salto
q_next. Comparar también diferencias grandes de raw entre los estados observados.
No presentar +224↔-64 o -64↔+96 como una sola frontera si atraviesan niveles
intermedios. No existe aquí una planta continua validada para raw sin cuantizar:
la resta raw-effective mide el efecto numérico, no una simulación desquantizada.

Clasificación determinista: MOVING_REFERENCE sólo si no persiste ningún par con
los contrafactuales fijos y no hay retorno autónomo medido; QUANTIZATION_OVERSHOOT
si hay órbita fija, ambos pasos cruzan teacher y el mapa confirma fronteras
discretas con cambio de destino que cruzan teacher; PLANT_STEP_SIZE si hay órbita
y overshoot pero no esa evidencia de frontera; MIXED si hay evidencia de más de
un mecanismo sin poder aislar predominio; UNRESOLVED si no se reproduce o falta
evidencia. Estas etiquetas describen suficiencia/estructura; no atribuyen un
porcentaje causal exclusivo a Kp, Ts o cuantización, que no se manipulan.

## Q2 — mapa M3 y repeticiones

Mapa a Ts=.2 para PWM positivos 64,96,128,160,192,224,255. Envolvente empírica:
unión de q_before/q_after de todos los controladores E2B y posiciones avg/data
M3 en ambas direcciones, incluyendo q inicial. Rejilla base de un encoder;
añadir todos los valores observados y almacenados, endpoints y vecinos de las
fronteras. Exportar q_before, PWM, q_after, delta_q; reversal definido estrictamente
delta_q<0, y contar también magnitudes >1e-9 para distinguir redondeo.

Obtener además intervalos exactos del mapa de primer cruce: closing busca el
primer índice i con avg(i)>=clamp(q,min_lim,max_lim), y devuelve avg(min(i+200,N)).
Los récords crecientes del prefijo delimitan celdas; intersectarlas con
q>q_next y con la envolvente para obtener intervalos abiertos/cerrados explícitos.
Respetar clamp y HOLD, sin reemplazarlos por límites del dato. Validar fronteras,
interiores y posiciones observadas contra SimController real. Si se usa un
evaluador acelerado, debe coincidir con la API en esa validación y en todos los
estados observados, sin modificar la fuente canónica.

Comparar con ambas rejillas operativas E0P de 21 posiciones y el oráculo de 7:
contar puntos q-PWM que caen en intervalos y regiones que contienen algún punto
ensayado. Distinguir cobertura de puntos de cobertura de intervalos; una rejilla
finita no prueba monotonicidad universal. No invalidar el PASS histórico E0P.

Auditar avg/std/data sin alinear, DTW ni suavizar. Verificar dimensiones, promedio
y desviación frente a data, y procedencia de columnas. Si data ya está cortada
históricamente, declararlo: no llamarla adquisición cruda. Buscar archivo original
de motor y comprobar correspondencia con el recorte guardado, sin nueva alineación.
Para cada celda de reversión: (a) deltas individuales a los mismos índices i e
i+200 de data, y (b) primer cruce individual del mismo q representativo y +200.
Registrar x/N, negativos/ceros/positivos, media, desviación muestral, rango y
repeticiones sin soporte. No contar HOLD sin cruce como evidencia contra reversión.
Registrar soporte de ambos índices y procedencia; no atribuirlo a ruido sin prueba.

REPEATABLE_EMPIRICAL_STRUCTURE si todas las regiones tienen mayoría estricta de
repeticiones negativas con soporte y no dependen exclusivamente de padding;
AVERAGING_ARTIFACT si hay reversión promedio y ninguna repetición negativa con
soporte en ambas comparaciones; LOW_REPEATABILITY si predominan regiones con
negativos minoritarios sin regiones de mayoría; MIXED si coexisten patrones o
las dos comparaciones difieren; UNRESOLVED si falta procedencia/soporte suficiente.
OUT_OF_PREVIOUS_GRID se reporta como cobertura adicional, no como causa física.

Visitación usando sólo trazas E2B: denominador principal estados q_before por
paso/controlador; añadir estados únicos y q final como descripción separada.
Contar pertenencia a unión de intervalos de cualquier PWM, pertenencia al intervalo
del PWM realmente mandado, signo/nivel dentro de región y retroceso ejecutado.
Así se distingue visitar q problemático de mandar allí un PWM que retrocede.

## Validación y entrega

Conservar 59 tests (13 E2A +24 E0P +22 E2B). Añadir pruebas deterministas de ciclos
con P2 real, intervalos exactos/clamp/HOLD, clasificación y SHA de fuentes históricas.
Los tests de caracterización preservan fallos; no convierten E2B en PASS.
Artefactos nuevos únicamente en e2c_results: CSV, MAT, JSON, manifiesto E0P,
resúmenes, hashes y resultados de tests. Script reproducible sin entrenamiento.
Informe RESULTADOS_E2C.md con límites y una sola hipótesis futura E2D, sin ejecutarla.
E2C_RESULT=CHARACTERIZED sólo si ambos casos y M3 quedan reproducidos, intervalos,
repetibilidad y visitación quedan medidos y tests/inmutabilidad pasan; en otro
caso INCONCLUSIVE, conservando lo aprendido y las incertidumbres.
RL_AUTHORIZED=NO, E3_PREPARED=NO, E3_EXECUTED=NO, PUSH=NO siempre.
